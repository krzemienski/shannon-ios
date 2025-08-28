//
//  BiometricAuthManager.swift
//  ClaudeCode
//
//  Biometric authentication manager for Face ID/Touch ID support
//

import Foundation
import LocalAuthentication
import OSLog

/// Manager for biometric authentication (Face ID/Touch ID)
@MainActor
public final class BiometricAuthManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var isBiometricAuthAvailable = false
    @Published public private(set) var biometricType: LABiometryType = .none
    @Published public private(set) var isAuthenticating = false
    @Published public private(set) var lastAuthenticationTime: Date?
    
    // MARK: - Private Properties
    
    private let context = LAContext()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "BiometricAuth")
    private let sessionTimeout: TimeInterval = 300 // 5 minutes
    
    // MARK: - Singleton
    
    public static let shared = BiometricAuthManager()
    
    private init() {
        checkBiometricAvailability()
    }
    
    // MARK: - Public Methods
    
    /// Check if biometric authentication is available
    public func checkBiometricAvailability() {
        var error: NSError?
        
        // Check if biometric authentication is available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricAuthAvailable = true
            biometricType = context.biometryType
            
            logger.info("Biometric authentication available: \(self.biometricTypeString)")
        } else {
            isBiometricAuthAvailable = false
            biometricType = .none
            
            if let error = error {
                logger.error("Biometric authentication not available: \(error.localizedDescription)")
            }
        }
    }
    
    /// Authenticate using biometrics
    public func authenticate(
        reason: String = "Authenticate to access secure data",
        fallbackTitle: String? = "Use Passcode"
    ) async -> Result<Bool, BiometricError> {
        guard isBiometricAuthAvailable else {
            return .failure(.biometryNotAvailable)
        }
        
        // Check if we're within the session timeout
        if let lastAuth = lastAuthenticationTime,
           Date().timeIntervalSince(lastAuth) < sessionTimeout {
            logger.debug("Within session timeout, skipping re-authentication")
            return .success(true)
        }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        // Configure context
        context.localizedReason = reason
        if let fallbackTitle = fallbackTitle {
            context.localizedFallbackTitle = fallbackTitle
        }
        
        // Set authentication context options
        context.touchIDAuthenticationAllowableReuseDuration = 10 // Allow reuse for 10 seconds
        
        do {
            // Perform authentication
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                lastAuthenticationTime = Date()
                logger.info("Biometric authentication successful")
                return .success(true)
            } else {
                logger.error("Biometric authentication failed")
                return .failure(.authenticationFailed)
            }
        } catch let error as LAError {
            logger.error("Biometric authentication error: \(error.localizedDescription)")
            return .failure(mapLAError(error))
        } catch {
            logger.error("Unexpected authentication error: \(error.localizedDescription)")
            return .failure(.unknown(error))
        }
    }
    
    /// Authenticate with device passcode fallback
    public func authenticateWithPasscode(
        reason: String = "Enter passcode to access secure data"
    ) async -> Result<Bool, BiometricError> {
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        let context = LAContext()
        context.localizedReason = reason
        
        do {
            // Try device owner authentication (biometrics + passcode)
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            if success {
                lastAuthenticationTime = Date()
                logger.info("Device authentication successful")
                return .success(true)
            } else {
                logger.error("Device authentication failed")
                return .failure(.authenticationFailed)
            }
        } catch let error as LAError {
            logger.error("Device authentication error: \(error.localizedDescription)")
            return .failure(mapLAError(error))
        } catch {
            logger.error("Unexpected authentication error: \(error.localizedDescription)")
            return .failure(.unknown(error))
        }
    }
    
    /// Invalidate current authentication session
    public func invalidateSession() {
        lastAuthenticationTime = nil
        context.invalidate()
        logger.info("Authentication session invalidated")
    }
    
    /// Check if current session is valid
    public var isSessionValid: Bool {
        guard let lastAuth = lastAuthenticationTime else { return false }
        return Date().timeIntervalSince(lastAuth) < sessionTimeout
    }
    
    /// Get remaining session time
    public var remainingSessionTime: TimeInterval? {
        guard let lastAuth = lastAuthenticationTime else { return nil }
        let elapsed = Date().timeIntervalSince(lastAuth)
        let remaining = sessionTimeout - elapsed
        return remaining > 0 ? remaining : nil
    }
    
    // MARK: - Private Methods
    
    private func mapLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancelled
        case .userFallback:
            return .userFallback
        case .systemCancel:
            return .systemCancelled
        case .passcodeNotSet:
            return .passcodeNotSet
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .biometryLockout
        default:
            return .unknown(error)
        }
    }
    
    private var biometricTypeString: String {
        switch biometricType {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Biometric Error

public enum BiometricError: LocalizedError {
    case biometryNotAvailable
    case biometryNotEnrolled
    case biometryLockout
    case authenticationFailed
    case userCancelled
    case userFallback
    case systemCancelled
    case passcodeNotSet
    case invalidContext
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .biometryNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometryNotEnrolled:
            return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings"
        case .biometryLockout:
            return "Biometric authentication is locked due to too many failed attempts"
        case .authenticationFailed:
            return "Authentication failed. Please try again"
        case .userCancelled:
            return "Authentication was cancelled"
        case .userFallback:
            return "User chose to use fallback authentication"
        case .systemCancelled:
            return "Authentication was cancelled by the system"
        case .passcodeNotSet:
            return "Device passcode is not set"
        case .invalidContext:
            return "Invalid authentication context"
        case .unknown(let error):
            return "Authentication failed: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .biometryNotEnrolled:
            return "Go to Settings > Face ID & Passcode (or Touch ID & Passcode) to set up biometric authentication"
        case .biometryLockout:
            return "Enter your device passcode to re-enable biometric authentication"
        case .passcodeNotSet:
            return "Go to Settings > Face ID & Passcode to set up a device passcode"
        case .authenticationFailed:
            return "Make sure your face or finger is properly positioned and try again"
        default:
            return nil
        }
    }
}

// MARK: - Biometric Policy

public enum BiometricPolicy {
    case required           // Always require biometric auth
    case optional          // Allow biometric but not required
    case disabled          // Don't use biometric auth
    case afterTimeout      // Require after session timeout
    
    public var requiresBiometric: Bool {
        switch self {
        case .required, .afterTimeout:
            return true
        case .optional, .disabled:
            return false
        }
    }
}

// MARK: - Session Configuration

public struct BiometricSessionConfiguration: Sendable {
    public let timeout: TimeInterval
    public let allowPasscodeFallback: Bool
    public let requireReauthForSensitiveOperations: Bool
    public let maxFailedAttempts: Int
    
    nonisolated(unsafe) public static let `default` = BiometricSessionConfiguration(
        timeout: 300, // 5 minutes
        allowPasscodeFallback: true,
        requireReauthForSensitiveOperations: true,
        maxFailedAttempts: 3
    )
    
    nonisolated(unsafe) public static let strict = BiometricSessionConfiguration(
        timeout: 60, // 1 minute
        allowPasscodeFallback: false,
        requireReauthForSensitiveOperations: true,
        maxFailedAttempts: 1
    )
    
    nonisolated(unsafe) public static let relaxed = BiometricSessionConfiguration(
        timeout: 900, // 15 minutes
        allowPasscodeFallback: true,
        requireReauthForSensitiveOperations: false,
        maxFailedAttempts: 5
    )
}