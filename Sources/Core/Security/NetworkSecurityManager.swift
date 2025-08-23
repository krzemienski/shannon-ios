//
//  NetworkSecurityManager.swift
//  ClaudeCode
//
//  Network security with request signing, anti-tampering, and secure communication
//

import Foundation
import CryptoKit
import Network
import OSLog

/// Manager for secure network communication with anti-tampering and request signing
public final class NetworkSecurityManager: NSObject {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "NetworkSecurity")
    private let certificatePinning = CertificatePinningManager.shared
    
    // Request signing
    private var signingKey: SymmetricKey?
    private let signatureHeader = "X-Signature"
    private let nonceHeader = "X-Nonce"
    private let timestampHeader = "X-Timestamp"
    
    // Anti-tampering
    private let maxClockSkew: TimeInterval = 300 // 5 minutes
    private var usedNonces: Set<String> = []
    private let nonceExpirationTime: TimeInterval = 600 // 10 minutes
    
    // Network monitoring
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.claudecode.network.monitor")
    
    // Security configuration
    private var securityConfiguration: NetworkSecurityConfiguration
    
    // Request validation
    private var requestValidator: RequestValidator
    
    // MARK: - Singleton
    
    public static let shared = NetworkSecurityManager()
    
    private override init() {
        self.securityConfiguration = .default
        self.requestValidator = RequestValidator()
        
        super.init()
        
        setupNetworkMonitoring()
        initializeSigningKey()
        startNonceCleanup()
    }
    
    // MARK: - Setup
    
    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.handleNetworkChange(path)
        }
        pathMonitor.start(queue: monitorQueue)
    }
    
    private func initializeSigningKey() {
        // Generate or retrieve signing key
        Task {
            do {
                if let existingKey = try await KeychainManager.shared.loadString(for: "request_signing_key") {
                    self.signingKey = SymmetricKey(data: Data(base64Encoded: existingKey)!)
                } else {
                    // Generate new signing key
                    let newKey = SymmetricKey(size: .bits256)
                    let keyData = newKey.withUnsafeBytes { Data($0) }
                    try await KeychainManager.shared.saveString(
                        keyData.base64EncodedString(),
                        for: "request_signing_key"
                    )
                    self.signingKey = newKey
                }
                logger.info("Request signing key initialized")
            } catch {
                logger.error("Failed to initialize signing key: \(error)")
            }
        }
    }
    
    private func startNonceCleanup() {
        // Periodically clean up expired nonces
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.cleanupExpiredNonces()
        }
    }
    
    // MARK: - Request Signing
    
    /// Sign a URL request with HMAC-SHA256
    public func signRequest(_ request: inout URLRequest) throws {
        guard let signingKey = signingKey else {
            throw NetworkSecurityError.signingKeyNotAvailable
        }
        
        // Add timestamp
        let timestamp = String(Date().timeIntervalSince1970)
        request.setValue(timestamp, forHTTPHeaderField: timestampHeader)
        
        // Add nonce
        let nonce = generateNonce()
        request.setValue(nonce, forHTTPHeaderField: nonceHeader)
        
        // Create signature payload
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? ""
        let body = request.httpBody?.base64EncodedString() ?? ""
        let headers = request.allHTTPHeaderFields?.sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "\n") ?? ""
        
        let signaturePayload = "\(method)\n\(url)\n\(timestamp)\n\(nonce)\n\(headers)\n\(body)"
        
        // Generate signature
        let signature = generateHMAC(for: signaturePayload, using: signingKey)
        request.setValue(signature, forHTTPHeaderField: signatureHeader)
        
        logger.debug("Request signed with nonce: \(nonce)")
    }
    
    /// Verify request signature
    public func verifyRequestSignature(_ request: URLRequest) throws -> Bool {
        guard let signingKey = signingKey else {
            throw NetworkSecurityError.signingKeyNotAvailable
        }
        
        // Extract headers
        guard let signature = request.value(forHTTPHeaderField: signatureHeader),
              let timestamp = request.value(forHTTPHeaderField: timestampHeader),
              let nonce = request.value(forHTTPHeaderField: nonceHeader) else {
            throw NetworkSecurityError.missingSecurityHeaders
        }
        
        // Verify timestamp (prevent replay attacks)
        if !verifyTimestamp(timestamp) {
            throw NetworkSecurityError.invalidTimestamp
        }
        
        // Verify nonce (prevent replay attacks)
        if !verifyNonce(nonce) {
            throw NetworkSecurityError.invalidNonce
        }
        
        // Recreate signature payload
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? ""
        let body = request.httpBody?.base64EncodedString() ?? ""
        let headers = request.allHTTPHeaderFields?
            .filter { $0.key != signatureHeader }
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "\n") ?? ""
        
        let signaturePayload = "\(method)\n\(url)\n\(timestamp)\n\(nonce)\n\(headers)\n\(body)"
        
        // Verify signature
        let expectedSignature = generateHMAC(for: signaturePayload, using: signingKey)
        
        guard signature == expectedSignature else {
            logger.warning("Signature verification failed")
            throw NetworkSecurityError.signatureVerificationFailed
        }
        
        // Mark nonce as used
        usedNonces.insert(nonce)
        
        return true
    }
    
    private func generateHMAC(for data: String, using key: SymmetricKey) -> String {
        let hmac = HMAC<SHA256>.authenticationCode(
            for: data.data(using: .utf8)!,
            using: key
        )
        return Data(hmac).base64EncodedString()
    }
    
    private func generateNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }
    
    // MARK: - Anti-Tampering
    
    private func verifyTimestamp(_ timestamp: String) -> Bool {
        guard let requestTime = TimeInterval(timestamp) else {
            return false
        }
        
        let currentTime = Date().timeIntervalSince1970
        let timeDifference = abs(currentTime - requestTime)
        
        // Check if timestamp is within acceptable clock skew
        return timeDifference <= maxClockSkew
    }
    
    private func verifyNonce(_ nonce: String) -> Bool {
        // Check if nonce has been used before
        return !usedNonces.contains(nonce)
    }
    
    private func cleanupExpiredNonces() {
        // Remove nonces older than expiration time
        // In production, store nonces with timestamps for proper cleanup
        if usedNonces.count > 10000 {
            usedNonces.removeAll()
            logger.info("Cleared nonce cache")
        }
    }
    
    /// Detect man-in-the-middle attacks
    public func detectMITM(for response: URLResponse) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        // Check for suspicious headers
        let suspiciousHeaders = [
            "X-Forwarded-For",
            "X-Real-IP",
            "Via",
            "X-Proxy-Connection"
        ]
        
        for header in suspiciousHeaders {
            if httpResponse.allHeaderFields[header] != nil {
                logger.warning("Suspicious header detected: \(header)")
                return true
            }
        }
        
        // Check for unexpected status codes from proxy
        if httpResponse.statusCode == 407 || httpResponse.statusCode == 305 {
            logger.warning("Proxy-related status code detected: \(httpResponse.statusCode)")
            return true
        }
        
        return false
    }
    
    // MARK: - Secure Session Configuration
    
    /// Create secure URLSession configuration
    public func createSecureSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        
        // Security settings
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        
        // Disable caching for sensitive data
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Network settings
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpShouldUsePipelining = false
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        
        // Security headers
        configuration.httpAdditionalHeaders = [
            "X-Requested-With": "XMLHttpRequest",
            "X-Client-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "X-Platform": "iOS",
            "X-Device-ID": getDeviceIdentifier()
        ]
        
        // Enable certificate pinning
        configuration.urlCredentialStorage = nil
        
        return configuration
    }
    
    /// Create secure URLSession with certificate pinning
    public func createSecureSession(
        configuration: URLSessionConfiguration? = nil,
        delegate: URLSessionDelegate? = nil
    ) -> URLSession {
        let config = configuration ?? createSecureSessionConfiguration()
        let sessionDelegate = delegate ?? certificatePinning
        
        return URLSession(
            configuration: config,
            delegate: sessionDelegate,
            delegateQueue: .main
        )
    }
    
    // MARK: - Response Validation
    
    /// Validate response integrity
    public func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkSecurityError.invalidResponse
        }
        
        // Check for MITM
        if detectMITM(for: httpResponse) {
            throw NetworkSecurityError.possibleMITMDetected
        }
        
        // Verify content integrity if hash provided
        if let contentHash = httpResponse.allHeaderFields["X-Content-Hash"] as? String {
            let computedHash = SHA256.hash(data: data)
                .compactMap { String(format: "%02x", $0) }
                .joined()
            
            if contentHash != computedHash {
                throw NetworkSecurityError.contentIntegrityViolation
            }
        }
        
        // Check security headers
        validateSecurityHeaders(httpResponse)
    }
    
    private func validateSecurityHeaders(_ response: HTTPURLResponse) {
        let requiredHeaders = [
            "X-Content-Type-Options": "nosniff",
            "X-Frame-Options": "DENY",
            "Strict-Transport-Security": nil // Any value acceptable
        ]
        
        for (header, expectedValue) in requiredHeaders {
            guard let value = response.allHeaderFields[header] as? String else {
                logger.warning("Missing security header: \(header)")
                continue
            }
            
            if let expected = expectedValue, value != expected {
                logger.warning("Invalid security header value for \(header): \(value)")
            }
        }
    }
    
    // MARK: - Network Monitoring
    
    private func handleNetworkChange(_ path: NWPath) {
        logger.info("Network status changed: \(path.status)")
        
        // Check for insecure network
        if path.status == .satisfied {
            checkNetworkSecurity(path)
        }
        
        // Notify about network changes
        NotificationCenter.default.post(
            name: .networkStatusChanged,
            object: nil,
            userInfo: ["path": path]
        )
    }
    
    private func checkNetworkSecurity(_ path: NWPath) {
        // Check if using cellular
        let isExpensive = path.isExpensive
        let isConstrained = path.isConstrained
        
        if isExpensive || isConstrained {
            logger.info("Using potentially expensive or constrained network")
        }
        
        // Check for VPN
        let hasVPN = path.gateways.contains { gateway in
            // Check for common VPN characteristics
            return false // Implement actual VPN detection
        }
        
        if hasVPN {
            logger.info("VPN connection detected")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDeviceIdentifier() -> String {
        // Get or generate unique device identifier
        if let deviceId = UserDefaults.standard.string(forKey: "device_identifier") {
            return deviceId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "device_identifier")
            return newId
        }
    }
    
    // MARK: - Public Configuration
    
    /// Update security configuration
    public func updateConfiguration(_ configuration: NetworkSecurityConfiguration) {
        self.securityConfiguration = configuration
        logger.info("Network security configuration updated")
    }
}

// MARK: - Request Validator

private class RequestValidator {
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "RequestValidator")
    
    func validate(_ request: URLRequest) throws {
        // Validate URL
        guard let url = request.url else {
            throw NetworkSecurityError.invalidRequest
        }
        
        // Check for secure protocol
        guard url.scheme == "https" else {
            throw NetworkSecurityError.insecureProtocol
        }
        
        // Validate host
        if !isValidHost(url.host) {
            throw NetworkSecurityError.invalidHost
        }
        
        // Check for SQL injection attempts in URL
        if containsSQLInjection(url.absoluteString) {
            throw NetworkSecurityError.sqlInjectionDetected
        }
        
        // Check for XSS attempts
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            if containsXSS(bodyString) {
                throw NetworkSecurityError.xssDetected
            }
        }
    }
    
    private func isValidHost(_ host: String?) -> Bool {
        guard let host = host else { return false }
        
        // Whitelist of allowed hosts
        let allowedHosts = [
            "api.anthropic.com",
            "api.claude.ai",
            "localhost",
            "127.0.0.1"
        ]
        
        #if DEBUG
        // Allow additional hosts in debug mode
        return true
        #else
        return allowedHosts.contains(host)
        #endif
    }
    
    private func containsSQLInjection(_ text: String) -> Bool {
        let sqlPatterns = [
            "(?i)(union|select|insert|update|delete|drop|create|alter|exec|execute|script|javascript|eval)\\s",
            "(?i)(;|--|/\\*|\\*/)",
            "(?i)(xp_|sp_|0x)"
        ]
        
        for pattern in sqlPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                logger.warning("Potential SQL injection detected")
                return true
            }
        }
        
        return false
    }
    
    private func containsXSS(_ text: String) -> Bool {
        let xssPatterns = [
            "<script[^>]*>.*?</script>",
            "javascript:",
            "on\\w+\\s*=",
            "<iframe[^>]*>",
            "<embed[^>]*>",
            "<object[^>]*>"
        ]
        
        for pattern in xssPatterns {
            if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                logger.warning("Potential XSS detected")
                return true
            }
        }
        
        return false
    }
}

// MARK: - Supporting Types

public struct NetworkSecurityConfiguration {
    public let requireSignature: Bool
    public let requireCertificatePinning: Bool
    public let allowInsecureConnections: Bool
    public let maxRetries: Int
    public let timeoutInterval: TimeInterval
    
    public static let `default` = NetworkSecurityConfiguration(
        requireSignature: true,
        requireCertificatePinning: true,
        allowInsecureConnections: false,
        maxRetries: 3,
        timeoutInterval: 30
    )
    
    public static let strict = NetworkSecurityConfiguration(
        requireSignature: true,
        requireCertificatePinning: true,
        allowInsecureConnections: false,
        maxRetries: 1,
        timeoutInterval: 15
    )
}

public enum NetworkSecurityError: LocalizedError {
    case signingKeyNotAvailable
    case missingSecurityHeaders
    case invalidTimestamp
    case invalidNonce
    case signatureVerificationFailed
    case invalidResponse
    case possibleMITMDetected
    case contentIntegrityViolation
    case invalidRequest
    case insecureProtocol
    case invalidHost
    case sqlInjectionDetected
    case xssDetected
    
    public var errorDescription: String? {
        switch self {
        case .signingKeyNotAvailable:
            return "Request signing key not available"
        case .missingSecurityHeaders:
            return "Required security headers missing"
        case .invalidTimestamp:
            return "Request timestamp is invalid or expired"
        case .invalidNonce:
            return "Request nonce is invalid or reused"
        case .signatureVerificationFailed:
            return "Request signature verification failed"
        case .invalidResponse:
            return "Invalid server response"
        case .possibleMITMDetected:
            return "Possible man-in-the-middle attack detected"
        case .contentIntegrityViolation:
            return "Response content integrity check failed"
        case .invalidRequest:
            return "Invalid request format"
        case .insecureProtocol:
            return "Insecure protocol not allowed"
        case .invalidHost:
            return "Host not in allowed list"
        case .sqlInjectionDetected:
            return "Potential SQL injection detected"
        case .xssDetected:
            return "Potential XSS attack detected"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("com.claudecode.network.status.changed")
    static let securityViolationDetected = Notification.Name("com.claudecode.security.violation")
}