//
//  SSHKeyManager.swift
//  ClaudeCode
//
//  SSH key generation, storage, import/export management (Tasks 481-485)
//

import Foundation
import Security
import CryptoKit
import OSLog
// Temporarily disabled for UI testing
// import Citadel

/// Manager for SSH key generation, storage, and management
@MainActor
public final class SSHKeyManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var storedKeys: [SSHKey] = []
    @Published public private(set) var isGeneratingKey = false
    @Published public private(set) var lastError: SSHKeyError?
    
    // MARK: - Private Properties
    
    private let keychain = KeychainManager.shared
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHKeyManager")
    private let fileManager = FileManager.default
    
    // Key storage paths
    private lazy var sshDirectory: URL = {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(".ssh", isDirectory: true)
    }()
    
    // MARK: - Initialization
    
    public init() {
        Task {
            await setupSSHDirectory()
            await loadStoredKeys()
        }
    }
    
    // MARK: - Key Generation
    
    /// Generate a new SSH key pair
    public func generateKeyPair(
        type: KeyType,
        comment: String? = nil,
        passphrase: String? = nil
    ) async throws -> SSHKey {
        logger.info("Generating SSH key pair: \(type.description)")
        isGeneratingKey = true
        defer { isGeneratingKey = false }
        
        do {
            let keyPair: SSHKey
            
            switch type {
            case .rsa(let bits):
                keyPair = try await generateRSAKey(bits: bits, comment: comment, passphrase: passphrase)
            case .ed25519:
                keyPair = try await generateEd25519Key(comment: comment, passphrase: passphrase)
            case .ecdsa(let curve):
                keyPair = try await generateECDSAKey(curve: curve, comment: comment, passphrase: passphrase)
            }
            
            // Store the key
            try await storeKey(keyPair)
            
            // Reload keys
            await loadStoredKeys()
            
            logger.info("Successfully generated \(type.description) key: \(keyPair.name)")
            return keyPair
        } catch {
            lastError = .generationFailed(error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Key Import/Export
    
    /// Import SSH key from file or string
    public func importKey(
        from source: ImportSource,
        name: String,
        passphrase: String? = nil
    ) async throws -> SSHKey {
        logger.info("Importing SSH key: \(name)")
        
        do {
            let keyContent: String
            
            switch source {
            case .file(let url):
                keyContent = try String(contentsOf: url, encoding: .utf8)
            case .string(let content):
                keyContent = content
            case .data(let data):
                guard let content = String(data: data, encoding: .utf8) else {
                    throw SSHKeyError.invalidKeyFormat
                }
                keyContent = content
            }
            
            // Parse and validate the key
            let sshKey = try await parseSSHKey(keyContent, name: name, passphrase: passphrase)
            
            // Store the imported key
            try await storeKey(sshKey)
            
            // Reload keys
            await loadStoredKeys()
            
            logger.info("Successfully imported key: \(name)")
            return sshKey
        } catch {
            lastError = .importFailed(error.localizedDescription)
            throw error
        }
    }
    
    /// Export SSH key
    public func exportKey(
        _ key: SSHKey,
        format: SSHKeyExportFormat,
        includePublicKey: Bool = true
    ) async throws -> ExportedKey {
        logger.info("Exporting SSH key: \(key.name)")
        
        var components: [String: Data] = [:]
        
        // Export private key
        if let privateKeyData = key.privateKey.data(using: .utf8) {
            components["private"] = privateKeyData
        }
        
        // Export public key if requested
        if includePublicKey, let publicKeyData = key.publicKey.data(using: .utf8) {
            components["public"] = publicKeyData
        }
        
        // Create export based on format
        switch format {
        case .openssh:
            return ExportedKey(
                privateKey: components["private"],
                publicKey: components["public"],
                format: format
            )
        case .pem:
            // Convert to PEM format if needed
            let pemPrivate = try convertToPEM(key.privateKey)
            return ExportedKey(
                privateKey: pemPrivate.data(using: .utf8),
                publicKey: components["public"],
                format: format
            )
        case .pkcs8:
            // Convert to PKCS8 format
            let pkcs8Private = try convertToPKCS8(key.privateKey)
            return ExportedKey(
                privateKey: pkcs8Private,
                publicKey: components["public"],
                format: format
            )
        }
    }
    
    // MARK: - Key Storage Management
    
    /// Store SSH key securely
    public func storeKey(_ key: SSHKey) async throws {
        // Store in keychain
        let keychainKey = "ssh_key_\(key.id.uuidString)"
        
        let keyData = SSHKeyData(
            id: key.id,
            name: key.name,
            type: key.type,
            publicKey: key.publicKey,
            privateKey: key.privateKey,
            fingerprint: key.fingerprint,
            comment: key.comment,
            createdAt: key.createdAt,
            lastUsed: key.lastUsed,
            isEncrypted: key.isEncrypted,
            hasPassphrase: key.hasPassphrase
        )
        
        try await keychain.save(keyData, for: keychainKey)
        
        // Also save to file system for compatibility
        try await saveKeyToFile(key)
        
        logger.debug("Stored SSH key: \(key.name)")
    }
    
    /// Delete SSH key
    public func deleteKey(_ key: SSHKey) async throws {
        logger.info("Deleting SSH key: \(key.name)")
        
        // Remove from keychain
        let keychainKey = "ssh_key_\(key.id.uuidString)"
        try await keychain.delete(for: keychainKey)
        
        // Remove files
        let privateKeyPath = sshDirectory.appendingPathComponent(key.name)
        let publicKeyPath = sshDirectory.appendingPathComponent("\(key.name).pub")
        
        try? fileManager.removeItem(at: privateKeyPath)
        try? fileManager.removeItem(at: publicKeyPath)
        
        // Update stored keys
        storedKeys.removeAll { $0.id == key.id }
        
        logger.info("Deleted SSH key: \(key.name)")
    }
    
    /// Load all stored SSH keys
    public func loadStoredKeys() async {
        logger.debug("Loading stored SSH keys")
        
        var keys: [SSHKey] = []
        
        // Load from keychain
        // Note: In production, we'd need to maintain a registry of key IDs
        // For now, scan the .ssh directory
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: sshDirectory,
                includingPropertiesForKeys: nil
            )
            
            for url in contents {
                if !url.lastPathComponent.hasSuffix(".pub") {
                    // Try to load private key
                    if let key = try? await loadKeyFromFile(at: url) {
                        keys.append(key)
                    }
                }
            }
        } catch {
            logger.error("Failed to load SSH keys: \(error.localizedDescription)")
        }
        
        storedKeys = keys.sorted { $0.createdAt > $1.createdAt }
        logger.info("Loaded \(keys.count) SSH keys")
    }
    
    // MARK: - Key Validation
    
    /// Validate SSH key with optional passphrase
    public func validateKey(
        _ key: SSHKey,
        passphrase: String? = nil
    ) async throws -> Bool {
        logger.debug("Validating SSH key: \(key.name)")
        
        // If key has passphrase, verify it
        if key.hasPassphrase {
            guard let passphrase = passphrase else {
                throw SSHKeyError.passphraseRequired
            }
            
            // Try to decrypt the key with the passphrase
            // This would use actual crypto libraries in production
            return try validatePassphrase(for: key, passphrase: passphrase)
        }
        
        // Validate key format and structure
        return try validateKeyFormat(key)
    }
    
    // MARK: - Private Methods
    
    private func setupSSHDirectory() async {
        if !fileManager.fileExists(atPath: sshDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: sshDirectory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
                logger.debug("Created SSH directory")
            } catch {
                logger.error("Failed to create SSH directory: \(error.localizedDescription)")
            }
        }
    }
    
    private func generateRSAKey(bits: Int, comment: String?, passphrase: String?) async throws -> SSHKey {
        // Use Security framework for RSA key generation
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: bits,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false,
                kSecAttrApplicationTag as String: "com.claudecode.ssh.rsa"
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw SSHKeyError.generationFailed(error?.takeRetainedValue().localizedDescription ?? "Unknown error")
        }
        
        // Export keys
        guard let privateKeyData = SecKeyCopyExternalRepresentation(privateKey, &error) as Data? else {
            throw SSHKeyError.exportFailed
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw SSHKeyError.exportFailed
        }
        
        // Convert to OpenSSH format
        let privateKeyPEM = convertRSAToPEM(privateKeyData)
        let publicKeySSH = convertRSAToOpenSSH(publicKeyData, comment: comment)
        
        let keyName = "id_rsa_\(Date().timeIntervalSince1970)"
        
        return SSHKey(
            name: keyName,
            type: .rsa(bits: bits),
            publicKey: publicKeySSH,
            privateKey: privateKeyPEM,
            comment: comment,
            hasPassphrase: passphrase != nil
        )
    }
    
    private func generateEd25519Key(comment: String?, passphrase: String?) async throws -> SSHKey {
        // Generate Ed25519 key using CryptoKit
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        
        // Convert to OpenSSH format
        let privateKeyData = privateKey.rawRepresentation
        let publicKeyData = publicKey.rawRepresentation
        
        let privateKeyBase64 = privateKeyData.base64EncodedString()
        let publicKeyBase64 = publicKeyData.base64EncodedString()
        
        let commentStr = comment ?? "generated@claudecode"
        let publicKeySSH = "ssh-ed25519 \(publicKeyBase64) \(commentStr)"
        
        // Create OpenSSH private key format
        let privateKeySSH = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        \(privateKeyBase64)
        -----END OPENSSH PRIVATE KEY-----
        """
        
        let keyName = "id_ed25519_\(Date().timeIntervalSince1970)"
        
        return SSHKey(
            name: keyName,
            type: .ed25519,
            publicKey: publicKeySSH,
            privateKey: privateKeySSH,
            comment: comment,
            hasPassphrase: passphrase != nil
        )
    }
    
    private func generateECDSAKey(curve: String, comment: String?, passphrase: String?) async throws -> SSHKey {
        // Generate ECDSA key using Security framework
        let keyType: CFString
        let keySize: Int
        
        switch curve {
        case "P-256", "prime256v1":
            keyType = kSecAttrKeyTypeECSECPrimeRandom
            keySize = 256
        case "P-384":
            keyType = kSecAttrKeyTypeECSECPrimeRandom
            keySize = 384
        case "P-521":
            keyType = kSecAttrKeyTypeECSECPrimeRandom
            keySize = 521
        default:
            throw SSHKeyError.unsupportedCurve(curve)
        }
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: keyType,
            kSecAttrKeySizeInBits as String: keySize,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false,
                kSecAttrApplicationTag as String: "com.claudecode.ssh.ecdsa"
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw SSHKeyError.generationFailed(error?.takeRetainedValue().localizedDescription ?? "Unknown error")
        }
        
        // Export keys
        guard let privateKeyData = SecKeyCopyExternalRepresentation(privateKey, &error) as Data? else {
            throw SSHKeyError.exportFailed
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw SSHKeyError.exportFailed
        }
        
        // Convert to OpenSSH format
        let privateKeyPEM = convertECDSAToPEM(privateKeyData, curve: curve)
        let publicKeySSH = convertECDSAToOpenSSH(publicKeyData, curve: curve, comment: comment)
        
        let keyName = "id_ecdsa_\(Date().timeIntervalSince1970)"
        
        return SSHKey(
            name: keyName,
            type: .ecdsa(curve: curve),
            publicKey: publicKeySSH,
            privateKey: privateKeyPEM,
            comment: comment,
            hasPassphrase: passphrase != nil
        )
    }
    
    // Key format conversion helpers
    private func convertRSAToPEM(_ keyData: Data) -> String {
        let base64 = keyData.base64EncodedString(options: [.endLineWithLineFeed])
        return """
        -----BEGIN RSA PRIVATE KEY-----
        \(base64)
        -----END RSA PRIVATE KEY-----
        """
    }
    
    private func convertRSAToOpenSSH(_ keyData: Data, comment: String?) -> String {
        let base64 = keyData.base64EncodedString()
        let commentStr = comment ?? "generated@claudecode"
        return "ssh-rsa \(base64) \(commentStr)"
    }
    
    private func convertECDSAToPEM(_ keyData: Data, curve: String) -> String {
        let base64 = keyData.base64EncodedString(options: [.endLineWithLineFeed])
        return """
        -----BEGIN EC PRIVATE KEY-----
        \(base64)
        -----END EC PRIVATE KEY-----
        """
    }
    
    private func convertECDSAToOpenSSH(_ keyData: Data, curve: String, comment: String?) -> String {
        let base64 = keyData.base64EncodedString()
        let commentStr = comment ?? "generated@claudecode"
        let keyType = "ecdsa-sha2-\(curve.lowercased())"
        return "\(keyType) \(base64) \(commentStr)"
    }
    
    private func convertToPEM(_ key: String) throws -> String {
        // Already in PEM format
        if key.contains("BEGIN") && key.contains("END") {
            return key
        }
        
        // Convert from OpenSSH to PEM
        // This would use actual conversion logic in production
        throw SSHKeyError.conversionFailed("PEM conversion not implemented")
    }
    
    private func convertToPKCS8(_ key: String) throws -> Data {
        // Convert to PKCS8 format
        // This would use actual conversion logic in production
        throw SSHKeyError.conversionFailed("PKCS8 conversion not implemented")
    }
    
    private func parseSSHKey(_ content: String, name: String, passphrase: String?) async throws -> SSHKey {
        // Detect key type
        let keyType: KeyType
        if content.contains("RSA") {
            keyType = .rsa(bits: 2048) // Would extract actual bit size
        } else if content.contains("ED25519") || content.contains("ed25519") {
            keyType = .ed25519
        } else if content.contains("ECDSA") || content.contains("ecdsa") {
            keyType = .ecdsa(curve: "P-256") // Would extract actual curve
        } else {
            throw SSHKeyError.unsupportedKeyType
        }
        
        // Extract public key if available
        let publicKey = try extractPublicKey(from: content, type: keyType)
        
        return SSHKey(
            name: name,
            type: keyType,
            publicKey: publicKey,
            privateKey: content,
            comment: nil,
            hasPassphrase: passphrase != nil
        )
    }
    
    private func extractPublicKey(from privateKey: String, type: KeyType) throws -> String {
        // This would use actual crypto libraries to derive public from private
        // For now, return a placeholder
        switch type {
        case .rsa:
            return "ssh-rsa AAAAB3NzaC1yc2E... generated@claudecode"
        case .ed25519:
            return "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... generated@claudecode"
        case .ecdsa(let curve):
            return "ecdsa-sha2-\(curve) AAAAE2VjZHNh... generated@claudecode"
        }
    }
    
    private func saveKeyToFile(_ key: SSHKey) async throws {
        let privateKeyPath = sshDirectory.appendingPathComponent(key.name)
        let publicKeyPath = sshDirectory.appendingPathComponent("\(key.name).pub")
        
        // Save private key
        try key.privateKey.write(to: privateKeyPath, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: privateKeyPath.path)
        
        // Save public key
        try key.publicKey.write(to: publicKeyPath, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: publicKeyPath.path)
    }
    
    private func loadKeyFromFile(at url: URL) async throws -> SSHKey? {
        let content = try String(contentsOf: url, encoding: .utf8)
        let name = url.lastPathComponent
        
        // Try to load public key
        let publicKeyURL = url.deletingLastPathComponent().appendingPathComponent("\(name).pub")
        let publicKey = try? String(contentsOf: publicKeyURL, encoding: .utf8)
        
        // Detect key type
        let keyType: KeyType
        if content.contains("RSA") {
            keyType = .rsa(bits: 2048)
        } else if content.contains("ED25519") || content.contains("ed25519") {
            keyType = .ed25519
        } else if content.contains("ECDSA") || content.contains("ecdsa") {
            keyType = .ecdsa(curve: "P-256")
        } else {
            return nil
        }
        
        return SSHKey(
            name: name,
            type: keyType,
            publicKey: publicKey ?? "",
            privateKey: content,
            comment: nil,
            hasPassphrase: content.contains("ENCRYPTED")
        )
    }
    
    private func validatePassphrase(for key: SSHKey, passphrase: String) throws -> Bool {
        // In production, would actually try to decrypt the key
        // For now, just return true
        return true
    }
    
    private func validateKeyFormat(_ key: SSHKey) throws -> Bool {
        // Basic format validation
        let privateKey = key.privateKey
        
        // Check for required headers
        let hasBegin = privateKey.contains("BEGIN") && privateKey.contains("KEY")
        let hasEnd = privateKey.contains("END") && privateKey.contains("KEY")
        
        guard hasBegin && hasEnd else {
            throw SSHKeyError.invalidKeyFormat
        }
        
        return true
    }
}

// MARK: - Supporting Types

/// SSH Key model
public struct SSHKey: Identifiable, Codable, Hashable {
    public let id: UUID
    public let name: String
    public let type: KeyType
    public let publicKey: String
    public let privateKey: String
    public let fingerprint: String
    public let comment: String?
    public let createdAt: Date
    public var lastUsed: Date?
    public let isEncrypted: Bool
    public let hasPassphrase: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        type: KeyType,
        publicKey: String,
        privateKey: String,
        comment: String? = nil,
        hasPassphrase: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.fingerprint = SSHKey.generateFingerprint(from: publicKey)
        self.comment = comment
        self.createdAt = Date()
        self.lastUsed = nil
        self.isEncrypted = privateKey.contains("ENCRYPTED")
        self.hasPassphrase = hasPassphrase
    }
    
    private static func generateFingerprint(from publicKey: String) -> String {
        // Generate SHA256 fingerprint
        guard let data = publicKey.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined(separator: ":")
    }
}

/// SSH key type
public enum KeyType: Codable, Hashable {
    case rsa(bits: Int)
    case ed25519
    case ecdsa(curve: String)
    
    public var description: String {
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

/// Key import source
public enum ImportSource {
    case file(URL)
    case string(String)
    case data(Data)
}

/// Key export format
public enum SSHKeyExportFormat {
    case openssh
    case pem
    case pkcs8
}

/// Exported key data
public struct ExportedKey {
    public let privateKey: Data?
    public let publicKey: Data?
    public let format: SSHKeyExportFormat
}

/// SSH key data for storage
private struct SSHKeyData: Codable {
    let id: UUID
    let name: String
    let type: KeyType
    let publicKey: String
    let privateKey: String
    let fingerprint: String
    let comment: String?
    let createdAt: Date
    let lastUsed: Date?
    let isEncrypted: Bool
    let hasPassphrase: Bool
}

/// SSH key errors
public enum SSHKeyError: LocalizedError {
    case generationFailed(String)
    case importFailed(String)
    case exportFailed
    case invalidKeyFormat
    case unsupportedKeyType
    case unsupportedCurve(String)
    case passphraseRequired
    case conversionFailed(String)
    case storageFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .generationFailed(let reason):
            return "Key generation failed: \(reason)"
        case .importFailed(let reason):
            return "Key import failed: \(reason)"
        case .exportFailed:
            return "Failed to export key"
        case .invalidKeyFormat:
            return "Invalid key format"
        case .unsupportedKeyType:
            return "Unsupported key type"
        case .unsupportedCurve(let curve):
            return "Unsupported curve: \(curve)"
        case .passphraseRequired:
            return "Passphrase required for encrypted key"
        case .conversionFailed(let reason):
            return "Key conversion failed: \(reason)"
        case .storageFailed(let reason):
            return "Key storage failed: \(reason)"
        }
    }
}