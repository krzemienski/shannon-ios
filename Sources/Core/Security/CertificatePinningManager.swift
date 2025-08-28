//
//  CertificatePinningManager.swift
//  ClaudeCode
//
//  Certificate pinning for secure network communication
//

import Foundation
import CryptoKit
import Security
import OSLog

/// Manager for SSL/TLS certificate pinning
public final class CertificatePinningManager: NSObject, @unchecked Sendable {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "CertificatePinning")
    
    // Pinned certificates (SHA256 hashes of public keys)
    private let pinnedCertificates = NSLock()
    private var _pinnedCertificates: Set<String> = []
    private let pinnedPublicKeys = NSLock()
    private var _pinnedPublicKeys: Set<String> = []
    
    // Backup pins for certificate rotation
    private let backupPinsLock = NSLock()
    private var _backupPins: Set<String> = []
    
    // Configuration
    private let enforceStrictPinning: Bool
    private let allowSelfSignedCertificates: Bool
    private let validateCertificateChain: Bool
    private let checkCertificateExpiry: Bool
    
    // Certificate transparency
    private let requireCertificateTransparency: Bool
    private var trustedCTLogs: Set<String> = []
    
    // MARK: - Singleton
    
    public static let shared = CertificatePinningManager()
    
    private override init() {
        // Load configuration
        self.enforceStrictPinning = true
        self.allowSelfSignedCertificates = false
        self.validateCertificateChain = true
        self.checkCertificateExpiry = true
        self.requireCertificateTransparency = true
        
        super.init()
        
        configurePinnedCertificates()
        configureTrustedCTLogs()
    }
    
    // MARK: - Configuration
    
    private func configurePinnedCertificates() {
        // Add your server's certificate hashes here
        // These are example hashes - replace with your actual certificate hashes
        
        // Production certificates
        pinnedPublicKeys.insert("PRODUCTION_CERT_HASH_1")
        pinnedPublicKeys.insert("PRODUCTION_CERT_HASH_2")
        
        // Backup certificates for rotation
        backupPins.insert("BACKUP_CERT_HASH_1")
        backupPins.insert("BACKUP_CERT_HASH_2")
        
        // Development certificates (only in debug mode)
        #if DEBUG
        pinnedPublicKeys.insert("DEV_CERT_HASH")
        #endif
    }
    
    private func configureTrustedCTLogs() {
        // Add trusted Certificate Transparency log IDs
        trustedCTLogs = [
            "google_argon2023",
            "google_xenon2023",
            "cloudflare_nimbus2023"
        ]
    }
    
    // MARK: - Public Methods
    
    /// Add a pinned certificate hash
    public func addPinnedCertificate(_ hash: String) {
        pinnedPublicKeys.insert(hash)
        logger.info("Added pinned certificate: \(String(hash.prefix(8)))...")
    }
    
    /// Remove a pinned certificate hash
    public func removePinnedCertificate(_ hash: String) {
        pinnedPublicKeys.remove(hash)
        logger.info("Removed pinned certificate: \(String(hash.prefix(8)))...")
    }
    
    /// Update pinned certificates from remote configuration
    public func updatePinnedCertificates(from config: CertificatePinningConfig) {
        pinnedPublicKeys = Set(config.primaryPins)
        backupPins = Set(config.backupPins)
        logger.info("Updated pinned certificates from remote config")
    }
    
    // MARK: - Certificate Validation
    
    /// Validate server trust
    public func validate(
        serverTrust: SecTrust,
        host: String
    ) -> PinningValidationResult {
        logger.debug("Validating server trust for host: \(host)")
        
        // Step 1: Perform default system validation
        var error: CFError?
        let isSystemTrusted = SecTrustEvaluateWithError(serverTrust, &error)
        
        if !isSystemTrusted {
            logger.error("System trust validation failed: \(error?.localizedDescription ?? "Unknown")")
            if enforceStrictPinning {
                return .failure(.systemValidationFailed(error))
            }
        }
        
        // Step 2: Check certificate expiry
        if checkCertificateExpiry {
            if let expiryError = validateCertificateExpiry(serverTrust) {
                return .failure(expiryError)
            }
        }
        
        // Step 3: Validate certificate chain
        if validateCertificateChain {
            if let chainError = validateCertificateChain(serverTrust) {
                return .failure(chainError)
            }
        }
        
        // Step 4: Pin validation
        let pinValidation = validatePins(serverTrust)
        if case .failure(let error) = pinValidation {
            logger.error("Pin validation failed: \(error)")
            return pinValidation
        }
        
        // Step 5: Certificate Transparency (if required)
        if requireCertificateTransparency {
            if let ctError = validateCertificateTransparency(serverTrust) {
                logger.warning("Certificate transparency validation failed: \(ctError)")
                // CT validation is advisory for now
            }
        }
        
        logger.info("Certificate validation successful for host: \(host)")
        return .success
    }
    
    private func validatePins(_ serverTrust: SecTrust) -> PinningValidationResult {
        // Get certificate chain
        let certificateChainLength = SecTrustGetCertificateCount(serverTrust)
        
        guard certificateChainLength > 0 else {
            return .failure(.noCertificates)
        }
        
        // Check each certificate in the chain
        for index in 0..<certificateChainLength {
            guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, index) else {
                continue
            }
            
            // Extract public key
            guard let publicKey = SecCertificateCopyKey(certificate) else {
                continue
            }
            
            // Generate hash of public key
            guard let publicKeyHash = generatePublicKeyHash(publicKey) else {
                continue
            }
            
            // Check against pinned keys
            if pinnedPublicKeys.contains(publicKeyHash) || backupPins.contains(publicKeyHash) {
                logger.debug("Found matching pin at index \(index)")
                return .success
            }
        }
        
        // No matching pins found
        return .failure(.pinMismatch)
    }
    
    private func validateCertificateExpiry(_ serverTrust: SecTrust) -> PinningError? {
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        
        for index in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, index) else {
                continue
            }
            
            // Check certificate validity period
            if !isCertificateValid(certificate) {
                return .certificateExpired
            }
        }
        
        return nil
    }
    
    private func validateCertificateChain(_ serverTrust: SecTrust) -> PinningError? {
        // Verify the complete certificate chain
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        
        guard certificateCount >= 2 else {
            // Single certificate (might be self-signed)
            if !allowSelfSignedCertificates {
                return .invalidCertificateChain
            }
        }
        
        // Additional chain validation logic here
        return nil
    }
    
    private func validateCertificateTransparency(_ serverTrust: SecTrust) -> PinningError? {
        // Check for Certificate Transparency SCTs
        // This is a simplified implementation
        // In production, you would verify actual SCTs
        
        guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            return .noCertificates
        }
        
        // Check for SCT extension in certificate
        // OID for SCT: 1.3.6.1.4.1.11129.2.4.2
        let hasSCT = certificateHasSCTExtension(certificate)
        
        if !hasSCT {
            return .certificateTransparencyFailed
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func generatePublicKeyHash(_ publicKey: SecKey) -> String? {
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        
        // Generate SHA256 hash
        let hash = SHA256.hash(data: publicKeyData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func isCertificateValid(_ certificate: SecCertificate) -> Bool {
        // Get certificate data
        let certificateData = SecCertificateCopyData(certificate) as Data
        
        // Parse certificate to check validity
        // This is a simplified check - in production use proper X.509 parsing
        let currentDate = Date()
        
        // For now, return true if we can get the certificate data
        return !certificateData.isEmpty
    }
    
    private func certificateHasSCTExtension(_ certificate: SecCertificate) -> Bool {
        // Check for SCT extension
        // This is a simplified implementation
        return false // Implement actual SCT checking
    }
}

// MARK: - URLSession Delegate

extension CertificatePinningManager: URLSessionDelegate {
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        let validationResult = validate(serverTrust: serverTrust, host: host)
        
        switch validationResult {
        case .success:
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        case .failure(let error):
            logger.error("Certificate pinning failed for \(host): \(error)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Supporting Types

public enum PinningValidationResult {
    case success
    case failure(PinningError)
}

public enum PinningError: LocalizedError {
    case systemValidationFailed(CFError?)
    case noCertificates
    case pinMismatch
    case certificateExpired
    case invalidCertificateChain
    case certificateTransparencyFailed
    case hostnameMismatch
    case untrustedRoot
    
    public var errorDescription: String? {
        switch self {
        case .systemValidationFailed(let error):
            return "System validation failed: \(error?.localizedDescription ?? "Unknown")"
        case .noCertificates:
            return "No certificates found in trust chain"
        case .pinMismatch:
            return "Certificate pin validation failed"
        case .certificateExpired:
            return "Certificate has expired"
        case .invalidCertificateChain:
            return "Invalid certificate chain"
        case .certificateTransparencyFailed:
            return "Certificate transparency validation failed"
        case .hostnameMismatch:
            return "Certificate hostname does not match"
        case .untrustedRoot:
            return "Certificate has untrusted root"
        }
    }
}

public struct CertificatePinningConfig: Codable {
    let primaryPins: [String]
    let backupPins: [String]
    let enforceStrict: Bool
    let requireCT: Bool
    let validFrom: Date
    let validUntil: Date
}

// MARK: - URLSession Extension

extension URLSession {
    /// Create a URLSession with certificate pinning enabled
    static func pinnedSession(
        configuration: URLSessionConfiguration = .default,
        delegate: URLSessionDelegate? = nil,
        delegateQueue: OperationQueue? = nil
    ) -> URLSession {
        let pinningManager = CertificatePinningManager.shared
        
        return URLSession(
            configuration: configuration,
            delegate: delegate ?? pinningManager,
            delegateQueue: delegateQueue ?? .main
        )
    }
}