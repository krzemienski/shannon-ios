//
//  DataEncryptionManager.swift
//  ClaudeCode
//
//  Comprehensive data encryption for sensitive information at rest
//

import Foundation
import CryptoKit
import Security
import OSLog
import CommonCrypto

/// Manager for encrypting and protecting sensitive data at rest
@MainActor
public final class DataEncryptionManager: ObservableObject {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "DataEncryption")
    private let keychain = KeychainManager.shared
    
    // Encryption configuration
    private let encryptionAlgorithm = EncryptionAlgorithm.aesGCM256
    private let keyDerivationIterations = 100_000
    private let saltLength = 32
    
    // Memory protection
    private var sensitiveDataReferences: Set<NSObject> = []
    
    // File encryption
    private let encryptedFileExtension = ".encrypted"
    private let metadataExtension = ".meta"
    
    // Secure storage paths
    private lazy var secureStorageDirectory: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let securePath = documentsPath.appendingPathComponent(".secure", isDirectory: true)
        try? FileManager.default.createDirectory(at: securePath, withIntermediateDirectories: true)
        return securePath
    }()
    
    // MARK: - Singleton
    
    public static let shared = DataEncryptionManager()
    
    private init() {
        setupSecureEnvironment()
    }
    
    // MARK: - Setup
    
    private func setupSecureEnvironment() {
        // Set up file protection
        setFileProtection()
        
        // Configure memory protection
        configureMemoryProtection()
        
        // Clean up any temporary files
        cleanupTemporaryFiles()
    }
    
    private func setFileProtection() {
        // Apply complete protection to secure directory
        do {
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUnlessOpen],
                ofItemAtPath: secureStorageDirectory.path
            )
        } catch {
            logger.error("Failed to set file protection: \(error)")
        }
    }
    
    private func configureMemoryProtection() {
        // Disable memory swapping for sensitive data
        #if !targetEnvironment(simulator)
        mlock(&sensitiveDataReferences, MemoryLayout<Set<NSObject>>.size)
        #endif
    }
    
    // MARK: - Data Encryption
    
    /// Encrypt data using AES-GCM
    public func encryptData(_ data: Data, withKey key: SymmetricKey? = nil) throws -> EncryptedData {
        let encryptionKey = try key ?? generateEncryptionKey()
        
        // Generate nonce
        let nonce = AES.GCM.Nonce()
        
        // Encrypt data
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey, nonce: nonce)
        
        guard let encryptedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        // Create metadata
        let metadata = EncryptionMetadata(
            algorithm: encryptionAlgorithm,
            nonce: nonce.data,
            tag: sealedBox.tag.data,
            timestamp: Date(),
            keyIdentifier: nil
        )
        
        return EncryptedData(
            ciphertext: encryptedData,
            metadata: metadata
        )
    }
    
    /// Decrypt data using AES-GCM
    public func decryptData(_ encryptedData: EncryptedData, withKey key: SymmetricKey? = nil) throws -> Data {
        let decryptionKey = try key ?? retrieveEncryptionKey()
        
        // Reconstruct sealed box
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData.ciphertext)
        
        // Decrypt
        let decryptedData = try AES.GCM.open(sealedBox, using: decryptionKey)
        
        return decryptedData
    }
    
    // MARK: - String Encryption
    
    /// Encrypt string with automatic encoding
    public func encryptString(_ string: String, withKey key: SymmetricKey? = nil) throws -> EncryptedData {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidInput
        }
        
        return try encryptData(data, withKey: key)
    }
    
    /// Decrypt string with automatic decoding
    public func decryptString(_ encryptedData: EncryptedData, withKey key: SymmetricKey? = nil) throws -> String {
        let decryptedData = try decryptData(encryptedData, withKey: key)
        
        guard let string = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decodingFailed
        }
        
        return string
    }
    
    // MARK: - File Encryption
    
    /// Encrypt file and save to secure storage
    public func encryptFile(at sourceURL: URL, filename: String? = nil) async throws -> URL {
        logger.info("Encrypting file: \(sourceURL.lastPathComponent)")
        
        // Read file data
        let fileData = try Data(contentsOf: sourceURL)
        
        // Encrypt data
        let encryptedData = try encryptData(fileData)
        
        // Generate secure filename
        let secureFilename = filename ?? UUID().uuidString
        let encryptedFileURL = secureStorageDirectory
            .appendingPathComponent(secureFilename)
            .appendingPathExtension(encryptedFileExtension)
        
        // Save encrypted data
        try encryptedData.ciphertext.write(to: encryptedFileURL)
        
        // Save metadata
        let metadataURL = encryptedFileURL.deletingPathExtension()
            .appendingPathExtension(metadataExtension)
        let metadataData = try JSONEncoder().encode(encryptedData.metadata)
        try metadataData.write(to: metadataURL)
        
        // Apply file protection
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: encryptedFileURL.path
        )
        
        // Delete original if it's in temporary directory
        if sourceURL.path.contains("tmp") || sourceURL.path.contains("Temp") {
            try? FileManager.default.removeItem(at: sourceURL)
        }
        
        logger.info("File encrypted and saved: \(secureFilename)")
        return encryptedFileURL
    }
    
    /// Decrypt file from secure storage
    public func decryptFile(at encryptedURL: URL, to destinationURL: URL? = nil) async throws -> URL {
        logger.info("Decrypting file: \(encryptedURL.lastPathComponent)")
        
        // Load encrypted data
        let encryptedFileData = try Data(contentsOf: encryptedURL)
        
        // Load metadata
        let metadataURL = encryptedURL.deletingPathExtension()
            .appendingPathExtension(metadataExtension)
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(EncryptionMetadata.self, from: metadataData)
        
        // Create encrypted data object
        let encryptedData = EncryptedData(
            ciphertext: encryptedFileData,
            metadata: metadata
        )
        
        // Decrypt data
        let decryptedData = try decryptData(encryptedData)
        
        // Save to destination
        let outputURL = destinationURL ?? FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try decryptedData.write(to: outputURL)
        
        logger.info("File decrypted successfully")
        return outputURL
    }
    
    // MARK: - Secure Field Storage
    
    /// Encrypt and store a secure field (for form inputs)
    public func storeSecureField(_ value: String, forKey key: String) async throws {
        let encryptedData = try encryptString(value)
        
        // Store in keychain with encrypted data
        let storageKey = "secure_field_\(key)"
        try await keychain.save(encryptedData, for: storageKey)
        
        logger.debug("Secure field stored: \(key)")
    }
    
    /// Retrieve and decrypt a secure field
    public func retrieveSecureField(forKey key: String) async throws -> String? {
        let storageKey = "secure_field_\(key)"
        
        guard let encryptedData: EncryptedData = try await keychain.load(
            EncryptedData.self,
            for: storageKey
        ) else {
            return nil
        }
        
        return try decryptString(encryptedData)
    }
    
    // MARK: - Memory Protection
    
    /// Mark data for memory protection
    public func protectInMemory<T: NSObject>(_ object: T) {
        sensitiveDataReferences.insert(object)
        
        #if !targetEnvironment(simulator)
        // Lock memory pages
        withUnsafePointer(to: object) { pointer in
            mlock(pointer, MemoryLayout<T>.size)
        }
        #endif
    }
    
    /// Clear sensitive data from memory
    public func clearFromMemory<T: NSObject>(_ object: T) {
        sensitiveDataReferences.remove(object)
        
        #if !targetEnvironment(simulator)
        // Unlock and clear memory
        withUnsafePointer(to: object) { pointer in
            memset(UnsafeMutableRawPointer(mutating: pointer), 0, MemoryLayout<T>.size)
            munlock(pointer, MemoryLayout<T>.size)
        }
        #endif
    }
    
    /// Secure string that clears itself from memory
    public class SecureString: NSObject {
        private var chars: [Character]
        
        init(_ string: String) {
            self.chars = Array(string)
            super.init()
            DataEncryptionManager.shared.protectInMemory(self)
        }
        
        var value: String {
            return String(chars)
        }
        
        func clear() {
            chars = Array(repeating: Character("\0"), count: chars.count)
            DataEncryptionManager.shared.clearFromMemory(self)
        }
        
        deinit {
            clear()
        }
    }
    
    // MARK: - Database Encryption
    
    /// Encrypt database at path
    public func encryptDatabase(at path: String, password: String) throws {
        // Use SQLCipher or similar for database encryption
        // This is a placeholder for actual implementation
        logger.info("Database encryption requested for: \(path)")
        
        // In production, integrate SQLCipher
        throw EncryptionError.notImplemented
    }
    
    // MARK: - Key Management
    
    private func generateEncryptionKey() throws -> SymmetricKey {
        // Generate new key
        let key = SymmetricKey(size: .bits256)
        
        // Store in keychain
        let keyData = key.withUnsafeBytes { Data($0) }
        let keyIdentifier = "encryption_key_\(Date().timeIntervalSince1970)"
        
        try keychain.saveString(
            keyData.base64EncodedString(),
            for: keyIdentifier
        )
        
        return key
    }
    
    private func retrieveEncryptionKey() throws -> SymmetricKey {
        // Retrieve the most recent key from keychain
        // In production, implement proper key rotation
        
        guard let keyString = try keychain.loadString(for: "encryption_key_latest"),
              let keyData = Data(base64Encoded: keyString) else {
            throw EncryptionError.keyNotFound
        }
        
        return SymmetricKey(data: keyData)
    }
    
    /// Derive key from password
    public func deriveKey(from password: String, salt: Data? = nil) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw EncryptionError.invalidInput
        }
        
        let salt = salt ?? generateSalt()
        
        // Use PBKDF2 for key derivation
        var derivedKey = Data(count: 32)
        
        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            passwordData.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress!.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(keyDerivationIterations),
                        derivedKeyBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }
        
        guard result == kCCSuccess else {
            throw EncryptionError.keyDerivationFailed
        }
        
        return SymmetricKey(data: derivedKey)
    }
    
    private func generateSalt() -> Data {
        var salt = Data(count: saltLength)
        _ = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, saltLength, bytes.baseAddress!)
        }
        return salt
    }
    
    // MARK: - Cleanup
    
    private func cleanupTemporaryFiles() {
        // Clean up any temporary encrypted files
        let tempDirectory = FileManager.default.temporaryDirectory
        
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: nil
            )
            
            for file in tempFiles {
                if file.pathExtension == encryptedFileExtension {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            logger.error("Failed to cleanup temporary files: \(error)")
        }
    }
    
    /// Securely wipe all encrypted data
    public func wipeAllEncryptedData() async throws {
        // Require authentication
        let authResult = await BiometricAuthManager.shared.authenticate(
            reason: "Authenticate to wipe encrypted data"
        )
        
        guard case .success = authResult else {
            throw EncryptionError.authenticationRequired
        }
        
        // Wipe secure storage directory
        try FileManager.default.removeItem(at: secureStorageDirectory)
        try FileManager.default.createDirectory(at: secureStorageDirectory, withIntermediateDirectories: true)
        
        // Clear keychain entries
        await keychain.clearAll()
        
        logger.warning("All encrypted data wiped")
    }
}

// MARK: - Supporting Types

public struct EncryptedData: Codable {
    let ciphertext: Data
    let metadata: EncryptionMetadata
}

public struct EncryptionMetadata: Codable {
    let algorithm: EncryptionAlgorithm
    let nonce: Data
    let tag: Data
    let timestamp: Date
    let keyIdentifier: String?
}

public enum EncryptionAlgorithm: String, Codable {
    case aesGCM256 = "AES-GCM-256"
    case chaChaPoly = "ChaCha20-Poly1305"
}

public enum EncryptionError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keyNotFound
    case invalidInput
    case decodingFailed
    case keyDerivationFailed
    case authenticationRequired
    case notImplemented
    
    public var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .keyNotFound:
            return "Encryption key not found"
        case .invalidInput:
            return "Invalid input data"
        case .decodingFailed:
            return "Failed to decode decrypted data"
        case .keyDerivationFailed:
            return "Failed to derive encryption key"
        case .authenticationRequired:
            return "Authentication required for this operation"
        case .notImplemented:
            return "Feature not yet implemented"
        }
    }
}

// MARK: - Extensions

extension AES.GCM.Nonce {
    var data: Data {
        return self.withUnsafeBytes { Data($0) }
    }
}

extension AES.GCM.Tag {
    var data: Data {
        return self.withUnsafeBytes { Data($0) }
    }
}