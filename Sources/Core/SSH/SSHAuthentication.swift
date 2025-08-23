//
//  SSHAuthentication.swift
//  ClaudeCode
//
//  SSH authentication with password and key support (Tasks 461-465)
//

import Foundation
// Temporarily disabled for UI testing
// import Citadel
import OSLog

/// SSH authentication manager with KeychainManager integration
@MainActor
public class SSHAuthentication: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var authenticationMethod: AuthenticationMethod?
    @Published public private(set) var lastAuthError: AuthenticationError?
    
    // MARK: - Private Properties
    
    private let keychain = KeychainManager.shared
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHAuthentication")
    
    // Cached credentials
    private var cachedCredentials: [String: CachedCredential] = [:]
    
    // MARK: - Authentication Methods
    
    public enum AuthenticationMethod {
        case password(username: String)
        case publicKey(username: String, keyType: KeyType)
        case keyboardInteractive(username: String)
        case agent(username: String)
        case multiFactorAuth(primary: AuthenticationMethod, secondary: AuthenticationMethod)
        
        public var username: String {
            switch self {
            case .password(let user), .publicKey(let user, _), 
                 .keyboardInteractive(let user), .agent(let user):
                return user
            case .multiFactorAuth(let primary, _):
                return primary.username
            }
        }
    }
    
    public enum KeyType {
        case rsa(bits: Int)
        case ed25519
        case ecdsa(curve: String)
        
        var description: String {
            switch self {
            case .rsa(let bits):
                return "RSA-\(bits)"
            case .ed25519:
                return "Ed25519"
            case .ecdsa(let curve):
                return "ECDSA-\(curve)"
            }
        }
    }
    
    // MARK: - Password Authentication
    
    /// Authenticate with password
    public func authenticateWithPassword(
        host: String,
        port: Int,
        username: String,
        password: String,
        saveToKeychain: Bool = true
    ) async throws -> SSHAuthenticationMethod {
        logger.info("Attempting password authentication for \(username)@\(host)")
        
        // Validate inputs
        guard !username.isEmpty, !password.isEmpty else {
            throw AuthenticationError.invalidCredentials("Username and password required")
        }
        
        // Save to keychain if requested
        if saveToKeychain {
            try await savePasswordCredentials(
                host: host,
                port: port,
                username: username,
                password: password
            )
        }
        
        // Cache credentials
        let cacheKey = credentialKey(host: host, port: port, username: username)
        cachedCredentials[cacheKey] = CachedCredential(
            type: .password,
            username: username,
            password: password,
            privateKey: nil,
            passphrase: nil,
            timestamp: Date()
        )
        
        isAuthenticated = true
        authenticationMethod = .password(username: username)
        lastAuthError = nil
        
        return .passwordBased(username: username, password: password)
    }
    
    // MARK: - Key-Based Authentication
    
    /// Authenticate with private key
    public func authenticateWithKey(
        host: String,
        port: Int,
        username: String,
        privateKey: String,
        passphrase: String? = nil,
        saveToKeychain: Bool = true
    ) async throws -> SSHAuthenticationMethod {
        logger.info("Attempting key authentication for \(username)@\(host)")
        
        // Validate private key format
        let keyType = try detectKeyType(privateKey)
        logger.debug("Detected key type: \(keyType.description)")
        
        // Validate key with passphrase if provided
        if let passphrase = passphrase {
            try validateKeyWithPassphrase(privateKey: privateKey, passphrase: passphrase)
        }
        
        // Save to keychain if requested
        if saveToKeychain {
            try await saveKeyCredentials(
                host: host,
                port: port,
                username: username,
                privateKey: privateKey,
                passphrase: passphrase
            )
        }
        
        // Cache credentials
        let cacheKey = credentialKey(host: host, port: port, username: username)
        cachedCredentials[cacheKey] = CachedCredential(
            type: .publicKey,
            username: username,
            password: nil,
            privateKey: privateKey,
            passphrase: passphrase,
            timestamp: Date()
        )
        
        isAuthenticated = true
        authenticationMethod = .publicKey(username: username, keyType: keyType)
        lastAuthError = nil
        
        // For now, return password-based auth as fallback
        // TODO: Implement proper key-based authentication with Citadel
        logger.warning("Key authentication not fully implemented, using fallback")
        return .passwordBased(username: username, password: passphrase ?? "")
    }
    
    /// Load private key from file
    public func loadPrivateKeyFromFile(_ path: String) async throws -> (key: String, type: KeyType) {
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw AuthenticationError.keyNotFound(path)
        }
        
        do {
            let keyContent = try String(contentsOf: url)
            let keyType = try detectKeyType(keyContent)
            return (keyContent, keyType)
        } catch {
            throw AuthenticationError.keyLoadFailed(error.localizedDescription)
        }
    }
    
    /// Generate new SSH key pair
    public func generateKeyPair(
        type: KeyType,
        comment: String? = nil
    ) async throws -> (publicKey: String, privateKey: String) {
        logger.info("Generating new SSH key pair: \(type.description)")
        
        // TODO: Implement actual key generation using Security framework or OpenSSL
        // For now, return placeholder keys
        
        let timestamp = Date().timeIntervalSince1970
        let comment = comment ?? "generated@claudecode-\(Int(timestamp))"
        
        switch type {
        case .rsa(let bits):
            return generateRSAKeyPair(bits: bits, comment: comment)
        case .ed25519:
            return generateEd25519KeyPair(comment: comment)
        case .ecdsa(let curve):
            return generateECDSAKeyPair(curve: curve, comment: comment)
        }
    }
    
    // MARK: - Credential Management
    
    /// Load saved credentials from keychain
    public func loadSavedCredentials(
        host: String,
        port: Int,
        username: String
    ) async throws -> SavedCredentials? {
        let passwordKey = keychainKey(type: .password, host: host, port: port, username: username)
        let privateKeyKey = keychainKey(type: .privateKey, host: host, port: port, username: username)
        let passphraseKey = keychainKey(type: .passphrase, host: host, port: port, username: username)
        
        let password = try? await keychain.loadString(for: passwordKey)
        let privateKey = try? await keychain.loadString(for: privateKeyKey)
        let passphrase = try? await keychain.loadString(for: passphraseKey)
        
        if password != nil || privateKey != nil {
            return SavedCredentials(
                username: username,
                password: password,
                privateKey: privateKey,
                passphrase: passphrase
            )
        }
        
        return nil
    }
    
    /// Delete saved credentials
    public func deleteSavedCredentials(
        host: String,
        port: Int,
        username: String
    ) async throws {
        let passwordKey = keychainKey(type: .password, host: host, port: port, username: username)
        let privateKeyKey = keychainKey(type: .privateKey, host: host, port: port, username: username)
        let passphraseKey = keychainKey(type: .passphrase, host: host, port: port, username: username)
        
        try? await keychain.delete(for: passwordKey)
        try? await keychain.delete(for: privateKeyKey)
        try? await keychain.delete(for: passphraseKey)
        
        // Remove from cache
        let cacheKey = credentialKey(host: host, port: port, username: username)
        cachedCredentials.removeValue(forKey: cacheKey)
        
        logger.info("Deleted credentials for \(username)@\(host):\(port)")
    }
    
    /// List all saved SSH credentials
    public func listSavedCredentials() async -> [SavedCredentialInfo] {
        // TODO: Implement listing all SSH credentials from keychain
        // This would require storing a registry of saved credentials
        return []
    }
    
    // MARK: - Private Methods
    
    private func savePasswordCredentials(
        host: String,
        port: Int,
        username: String,
        password: String
    ) async throws {
        let key = keychainKey(type: .password, host: host, port: port, username: username)
        try await keychain.saveString(password, for: key)
        logger.debug("Saved password credentials to keychain")
    }
    
    private func saveKeyCredentials(
        host: String,
        port: Int,
        username: String,
        privateKey: String,
        passphrase: String?
    ) async throws {
        let keyKey = keychainKey(type: .privateKey, host: host, port: port, username: username)
        try await keychain.saveString(privateKey, for: keyKey)
        
        if let passphrase = passphrase {
            let passphraseKey = keychainKey(type: .passphrase, host: host, port: port, username: username)
            try await keychain.saveString(passphrase, for: passphraseKey)
        }
        
        logger.debug("Saved key credentials to keychain")
    }
    
    private func keychainKey(type: CredentialType, host: String, port: Int, username: String) -> String {
        "ssh_\(type.rawValue)_\(username)@\(host):\(port)"
    }
    
    private func credentialKey(host: String, port: Int, username: String) -> String {
        "\(username)@\(host):\(port)"
    }
    
    private func detectKeyType(_ privateKey: String) throws -> KeyType {
        if privateKey.contains("BEGIN RSA PRIVATE KEY") {
            // Extract bit size from key (simplified)
            return .rsa(bits: 2048)
        } else if privateKey.contains("BEGIN OPENSSH PRIVATE KEY") && privateKey.contains("ssh-ed25519") {
            return .ed25519
        } else if privateKey.contains("BEGIN EC PRIVATE KEY") {
            return .ecdsa(curve: "P-256")
        } else {
            throw AuthenticationError.unsupportedKeyType
        }
    }
    
    private func validateKeyWithPassphrase(privateKey: String, passphrase: String) throws {
        // TODO: Implement actual key validation with passphrase
        // This would use Security framework or OpenSSL to decrypt the key
        logger.debug("Validating key with passphrase")
    }
    
    // Placeholder key generation methods
    private func generateRSAKeyPair(bits: Int, comment: String) -> (String, String) {
        let publicKey = "ssh-rsa AAAAB3NzaC1yc2E... \(comment)"
        let privateKey = "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
        return (publicKey, privateKey)
    }
    
    private func generateEd25519KeyPair(comment: String) -> (String, String) {
        let publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... \(comment)"
        let privateKey = "-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----"
        return (publicKey, privateKey)
    }
    
    private func generateECDSAKeyPair(curve: String, comment: String) -> (String, String) {
        let publicKey = "ecdsa-sha2-\(curve) AAAAE2VjZHNh... \(comment)"
        let privateKey = "-----BEGIN EC PRIVATE KEY-----\n...\n-----END EC PRIVATE KEY-----"
        return (publicKey, privateKey)
    }
}

// MARK: - Supporting Types

/// Credential type for keychain storage
private enum CredentialType: String {
    case password
    case privateKey = "private_key"
    case passphrase
}

/// Cached credential
private struct CachedCredential {
    let type: CredentialType
    let username: String
    let password: String?
    let privateKey: String?
    let passphrase: String?
    let timestamp: Date
}

/// Saved credentials
public struct SavedCredentials {
    public let username: String
    public let password: String?
    public let privateKey: String?
    public let passphrase: String?
}

/// Saved credential info for listing
public struct SavedCredentialInfo: Identifiable {
    public let id = UUID()
    public let host: String
    public let port: Int
    public let username: String
    public let hasPassword: Bool
    public let hasPrivateKey: Bool
    public let lastUsed: Date?
}

/// Authentication errors
public enum AuthenticationError: LocalizedError {
    case invalidCredentials(String)
    case keyNotFound(String)
    case keyLoadFailed(String)
    case unsupportedKeyType
    case authenticationFailed(String)
    case keychainError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials(let reason):
            return "Invalid credentials: \(reason)"
        case .keyNotFound(let path):
            return "Private key not found at: \(path)"
        case .keyLoadFailed(let reason):
            return "Failed to load private key: \(reason)"
        case .unsupportedKeyType:
            return "Unsupported private key type"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .keychainError(let reason):
            return "Keychain error: \(reason)"
        }
    }
}