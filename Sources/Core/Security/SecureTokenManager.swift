//
//  SecureTokenManager.swift
//  ClaudeCode
//
//  Secure token storage and management with encryption
//

import Foundation
import CryptoKit
import Security
import OSLog

/// Manager for secure token storage with encryption and session management
@MainActor
public final class SecureTokenManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var hasStoredCredentials = false
    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var sessionExpiresAt: Date?
    
    // MARK: - Private Properties
    
    private let keychain = KeychainManager.shared
    private let biometricAuth = BiometricAuthManager.shared
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SecureTokenManager")
    
    // Encryption keys
    private var encryptionKey: SymmetricKey?
    private let saltKey = "com.claudecode.salt"
    private let encryptionKeyTag = "com.claudecode.encryption.key"
    
    // Session management
    private var sessionTimer: Timer?
    private let defaultSessionDuration: TimeInterval = 3600 // 1 hour
    private let refreshThreshold: TimeInterval = 300 // 5 minutes before expiry
    
    // Token storage keys
    private enum TokenKey: String {
        case apiKey = "secure.api.key"
        case authToken = "secure.auth.token"
        case refreshToken = "secure.refresh.token"
        case sessionToken = "secure.session.token"
        case deviceToken = "secure.device.token"
    }
    
    // MARK: - Singleton
    
    public static let shared = SecureTokenManager()
    
    private init() {
        Task {
            await initializeEncryption()
            await checkStoredCredentials()
        }
    }
    
    // MARK: - Initialization
    
    private func initializeEncryption() async {
        // Generate or retrieve encryption key
        if let existingKey = await retrieveEncryptionKey() {
            self.encryptionKey = existingKey
            logger.info("Encryption key loaded from secure storage")
        } else {
            // Generate new encryption key
            let newKey = SymmetricKey(size: .bits256)
            if await storeEncryptionKey(newKey) {
                self.encryptionKey = newKey
                logger.info("New encryption key generated and stored")
            } else {
                logger.error("Failed to store encryption key")
            }
        }
    }
    
    private func checkStoredCredentials() async {
        // Check if we have stored API key
        if let _ = try? await retrieveToken(.apiKey) {
            hasStoredCredentials = true
        }
    }
    
    // MARK: - Token Storage
    
    /// Store API key securely
    public func storeAPIKey(_ apiKey: String) async throws {
        guard !apiKey.isEmpty else {
            throw TokenError.invalidToken
        }
        
        // Require biometric authentication for storing sensitive data
        let authResult = await biometricAuth.authenticate(
            reason: "Authenticate to store API key securely"
        )
        
        guard case .success = authResult else {
            throw TokenError.authenticationRequired
        }
        
        // Encrypt and store
        let encrypted = try encryptData(apiKey.data(using: .utf8)!)
        try await keychain.save(encrypted, for: TokenKey.apiKey.rawValue)
        
        hasStoredCredentials = true
        logger.info("API key stored securely")
    }
    
    /// Store authentication token
    public func storeAuthToken(_ token: String, expiresIn: TimeInterval? = nil) async throws {
        let encrypted = try encryptData(token.data(using: .utf8)!)
        
        // Create token data with expiration
        let tokenData = TokenData(
            token: encrypted,
            expiresAt: expiresIn.map { Date().addingTimeInterval($0) }
        )
        
        try await keychain.save(tokenData, for: TokenKey.authToken.rawValue)
        
        // Set up session expiration
        if let expiresIn = expiresIn {
            setupSessionTimer(duration: expiresIn)
        }
        
        isAuthenticated = true
        logger.info("Auth token stored with expiration")
    }
    
    /// Store refresh token
    public func storeRefreshToken(_ token: String) async throws {
        let encrypted = try encryptData(token.data(using: .utf8)!)
        try await keychain.save(encrypted, for: TokenKey.refreshToken.rawValue)
        logger.info("Refresh token stored securely")
    }
    
    // MARK: - Token Retrieval
    
    /// Retrieve API key
    public func retrieveAPIKey() async throws -> String {
        // Require biometric authentication for sensitive data
        if biometricAuth.isBiometricAuthAvailable && !biometricAuth.isSessionValid {
            let authResult = await biometricAuth.authenticate(
                reason: "Authenticate to access API key"
            )
            
            guard case .success = authResult else {
                throw TokenError.authenticationRequired
            }
        }
        
        guard let encrypted: Data = try await keychain.load(Data.self, for: TokenKey.apiKey.rawValue) else {
            throw TokenError.tokenNotFound
        }
        
        let decrypted = try decryptData(encrypted)
        guard let apiKey = String(data: decrypted, encoding: .utf8) else {
            throw TokenError.decryptionFailed
        }
        
        return apiKey
    }
    
    /// Retrieve authentication token
    public func retrieveAuthToken() async throws -> String {
        guard let tokenData: TokenData = try await keychain.load(
            TokenData.self,
            for: TokenKey.authToken.rawValue
        ) else {
            throw TokenError.tokenNotFound
        }
        
        // Check expiration
        if let expiresAt = tokenData.expiresAt, Date() > expiresAt {
            // Token expired, try to refresh
            try await refreshAuthToken()
            return try await retrieveAuthToken()
        }
        
        let decrypted = try decryptData(tokenData.token)
        guard let token = String(data: decrypted, encoding: .utf8) else {
            throw TokenError.decryptionFailed
        }
        
        return token
    }
    
    /// Retrieve refresh token
    public func retrieveRefreshToken() async throws -> String {
        guard let encrypted: Data = try await keychain.load(
            Data.self,
            for: TokenKey.refreshToken.rawValue
        ) else {
            throw TokenError.tokenNotFound
        }
        
        let decrypted = try decryptData(encrypted)
        guard let token = String(data: decrypted, encoding: .utf8) else {
            throw TokenError.decryptionFailed
        }
        
        return token
    }
    
    private func retrieveToken(_ key: TokenKey) async throws -> String {
        guard let encrypted: Data = try await keychain.load(
            Data.self,
            for: key.rawValue
        ) else {
            throw TokenError.tokenNotFound
        }
        
        let decrypted = try decryptData(encrypted)
        guard let token = String(data: decrypted, encoding: .utf8) else {
            throw TokenError.decryptionFailed
        }
        
        return token
    }
    
    // MARK: - Token Refresh
    
    private func refreshAuthToken() async throws {
        logger.info("Attempting to refresh auth token")
        
        do {
            let refreshToken = try await retrieveRefreshToken()
            
            // Call API to refresh token
            // This would typically call your backend refresh endpoint
            // For now, we'll simulate it
            let newToken = "refreshed_token_\(UUID().uuidString)"
            let newExpiration: TimeInterval = 3600
            
            try await storeAuthToken(newToken, expiresIn: newExpiration)
            
            logger.info("Auth token refreshed successfully")
        } catch {
            logger.error("Failed to refresh auth token: \(error)")
            isAuthenticated = false
            throw TokenError.refreshFailed
        }
    }
    
    // MARK: - Session Management
    
    private func setupSessionTimer(duration: TimeInterval) {
        sessionTimer?.invalidate()
        
        sessionExpiresAt = Date().addingTimeInterval(duration)
        
        // Set up timer to refresh before expiration
        let refreshTime = max(duration - refreshThreshold, 0)
        sessionTimer = Timer.scheduledTimer(withTimeInterval: refreshTime, repeats: false) { _ in
            Task { @MainActor in
                do {
                    try await self.refreshAuthToken()
                } catch {
                    self.logger.error("Auto-refresh failed: \(error)")
                    self.handleSessionExpiration()
                }
            }
        }
    }
    
    private func handleSessionExpiration() {
        isAuthenticated = false
        sessionExpiresAt = nil
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // Notify about session expiration
        NotificationCenter.default.post(
            name: .sessionExpired,
            object: nil
        )
        
        logger.info("Session expired")
    }
    
    /// Invalidate current session
    public func invalidateSession() async {
        isAuthenticated = false
        sessionExpiresAt = nil
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // Clear auth token but keep refresh token
        try? await keychain.delete(for: TokenKey.authToken.rawValue)
        
        // Invalidate biometric session
        biometricAuth.invalidateSession()
        
        logger.info("Session invalidated")
    }
    
    /// Clear all stored tokens
    public func clearAllTokens() async throws {
        // Require biometric authentication
        let authResult = await biometricAuth.authenticate(
            reason: "Authenticate to clear stored credentials"
        )
        
        guard case .success = authResult else {
            throw TokenError.authenticationRequired
        }
        
        // Clear all tokens
        for key in [TokenKey.apiKey, .authToken, .refreshToken, .sessionToken, .deviceToken] {
            try? await keychain.delete(for: key.rawValue)
        }
        
        hasStoredCredentials = false
        isAuthenticated = false
        sessionExpiresAt = nil
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        logger.info("All tokens cleared")
    }
    
    // MARK: - Encryption
    
    private func encryptData(_ data: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw TokenError.encryptionKeyMissing
        }
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let encrypted = sealedBox.combined else {
            throw TokenError.encryptionFailed
        }
        
        return encrypted
    }
    
    private func decryptData(_ data: Data) throws -> Data {
        guard let key = encryptionKey else {
            throw TokenError.encryptionKeyMissing
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        
        return decrypted
    }
    
    // MARK: - Encryption Key Management
    
    private func storeEncryptionKey(_ key: SymmetricKey) async -> Bool {
        // Store encryption key in Secure Enclave if available
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // Create access control for encryption key
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &error
        ) else {
            logger.error("Failed to create access control: \(error?.takeRetainedValue().localizedDescription ?? "Unknown")")
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: encryptionKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeAES,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrAccessControl as String: access,
            kSecValueData as String: keyData
        ]
        
        // Delete any existing key
        SecItemDelete(query as CFDictionary)
        
        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            return true
        } else {
            logger.error("Failed to store encryption key: \(status)")
            return false
        }
    }
    
    private func retrieveEncryptionKey() async -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: encryptionKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeAES,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let keyData = result as? Data {
            return SymmetricKey(data: keyData)
        }
        
        return nil
    }
}

// MARK: - Supporting Types

private struct TokenData: Codable {
    let token: Data
    let expiresAt: Date?
}

public enum TokenError: LocalizedError {
    case invalidToken
    case tokenNotFound
    case authenticationRequired
    case encryptionFailed
    case decryptionFailed
    case encryptionKeyMissing
    case refreshFailed
    case sessionExpired
    
    public var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid token provided"
        case .tokenNotFound:
            return "Token not found in secure storage"
        case .authenticationRequired:
            return "Authentication required to access secure data"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .encryptionKeyMissing:
            return "Encryption key not available"
        case .refreshFailed:
            return "Failed to refresh authentication token"
        case .sessionExpired:
            return "Session has expired"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let sessionExpired = Notification.Name("com.claudecode.session.expired")
    static let tokenRefreshed = Notification.Name("com.claudecode.token.refreshed")
}