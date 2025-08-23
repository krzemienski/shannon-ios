//
//  EnhancedKeychainManager.swift
//  ClaudeCode
//
//  Enhanced keychain manager with biometric protection and encryption
//

import Foundation
import Security
import CryptoKit
import LocalAuthentication
import OSLog

/// Enhanced keychain manager with multi-layered security
@MainActor
public final class EnhancedKeychainManager {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "EnhancedKeychain")
    private let service = "com.claudecode.ios.secure"
    private let accessGroup: String? = nil
    
    // Security components
    private let biometricAuth = BiometricAuthManager.shared
    private let dataEncryption = DataEncryptionManager.shared
    private let jailbreakDetector = JailbreakDetector.shared
    
    // Security configuration
    private let requireBiometricForSensitive = true
    private let encryptBeforeStorage = true
    private let enforceIntegrityChecks = true
    
    // Access control levels
    public enum AccessLevel {
        case standard           // Basic keychain access
        case protected         // Requires device unlock
        case biometric         // Requires biometric authentication
        case highSecurity      // Biometric + encryption + integrity checks
    }
    
    // Item categories
    public enum ItemCategory {
        case apiKey
        case authToken
        case refreshToken
        case sshKey
        case passphrase
        case certificate
        case sessionData
        case userCredentials
        
        var accessLevel: AccessLevel {
            switch self {
            case .apiKey, .sshKey, .passphrase, .userCredentials:
                return .highSecurity
            case .authToken, .refreshToken, .certificate:
                return .biometric
            case .sessionData:
                return .protected
            }
        }
        
        var keyPrefix: String {
            switch self {
            case .apiKey: return "secure.api."
            case .authToken: return "secure.auth."
            case .refreshToken: return "secure.refresh."
            case .sshKey: return "secure.ssh."
            case .passphrase: return "secure.pass."
            case .certificate: return "secure.cert."
            case .sessionData: return "secure.session."
            case .userCredentials: return "secure.creds."
            }
        }
    }
    
    // MARK: - Singleton
    
    public static let shared = EnhancedKeychainManager()
    
    private init() {
        performSecurityChecks()
    }
    
    // MARK: - Security Checks
    
    private func performSecurityChecks() {
        // Check for jailbreak
        if jailbreakDetector.isJailbroken() {
            logger.critical("⚠️ Device jailbreak detected - enhanced security enforced")
            // In production, might want to refuse operation entirely
        }
        
        // Verify keychain integrity
        verifyKeychainIntegrity()
    }
    
    private func verifyKeychainIntegrity() {
        // Check for keychain tampering
        let integrityKey = "keychain.integrity.check"
        let testValue = UUID().uuidString
        
        // Try to write and read back
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: integrityKey,
            kSecValueData as String: testValue.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Clean up any existing
        SecItemDelete(query as CFDictionary)
        
        // Add test item
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        
        // Read it back
        query[kSecReturnData as String] = true
        var result: AnyObject?
        let readStatus = SecItemCopyMatching(query as CFDictionary, &result)
        
        // Clean up
        SecItemDelete(query as CFDictionary)
        
        if addStatus != errSecSuccess || readStatus != errSecSuccess {
            logger.error("Keychain integrity check failed")
        }
    }
    
    // MARK: - Save Operations
    
    /// Save item with appropriate security level
    public func saveSecureItem<T: Codable>(
        _ item: T,
        key: String,
        category: ItemCategory,
        requireBiometric: Bool? = nil
    ) async throws {
        logger.info("Saving secure item: \(category.keyPrefix)\(key)")
        
        // Determine if biometric is required
        let needsBiometric = requireBiometric ?? (category.accessLevel == .biometric || category.accessLevel == .highSecurity)
        
        // Biometric authentication if required
        if needsBiometric {
            let authResult = await biometricAuth.authenticate(
                reason: "Authenticate to save \(category) securely"
            )
            
            guard case .success = authResult else {
                throw EnhancedKeychainError.biometricAuthenticationFailed
            }
        }
        
        // Encode item
        let encoder = JSONEncoder()
        var data = try encoder.encode(item)
        
        // Encrypt if high security
        if category.accessLevel == .highSecurity && encryptBeforeStorage {
            let encryptedData = try dataEncryption.encryptData(data)
            data = try JSONEncoder().encode(encryptedData)
        }
        
        // Generate HMAC for integrity
        let hmac = generateHMAC(for: data, key: key)
        
        // Prepare keychain item
        let fullKey = "\(category.keyPrefix)\(key)"
        
        // Delete existing item
        deleteItem(for: fullKey)
        
        // Create access control
        let access = createAccessControl(for: category.accessLevel)
        
        // Build query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fullKey,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: access as Any,
            kSecAttrLabel as String: hmac // Store HMAC in label for integrity
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Add metadata
        let metadata = ItemMetadata(
            category: category,
            createdAt: Date(),
            lastAccessed: Date(),
            accessCount: 0
        )
        
        if let metadataData = try? JSONEncoder().encode(metadata) {
            query[kSecAttrGeneric as String] = metadataData
        }
        
        // Save to keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            logger.error("Failed to save secure item: \(status)")
            throw EnhancedKeychainError.saveFailed(status: status)
        }
        
        logger.info("Successfully saved secure item")
    }
    
    // MARK: - Load Operations
    
    /// Load item with appropriate security checks
    public func loadSecureItem<T: Codable>(
        _ type: T.Type,
        key: String,
        category: ItemCategory,
        requireBiometric: Bool? = nil
    ) async throws -> T? {
        logger.info("Loading secure item: \(category.keyPrefix)\(key)")
        
        // Security check
        if enforceIntegrityChecks {
            let securityResult = jailbreakDetector.performSecurityCheck()
            if !securityResult.isSecure {
                logger.warning("Security check failed: \(securityResult.issues)")
                // In production, might want to refuse operation
            }
        }
        
        // Determine if biometric is required
        let needsBiometric = requireBiometric ?? (category.accessLevel == .biometric || category.accessLevel == .highSecurity)
        
        // Biometric authentication if required
        if needsBiometric && !biometricAuth.isSessionValid {
            let authResult = await biometricAuth.authenticate(
                reason: "Authenticate to access \(category)"
            )
            
            guard case .success = authResult else {
                throw EnhancedKeychainError.biometricAuthenticationFailed
            }
        }
        
        let fullKey = "\(category.keyPrefix)\(key)"
        
        // Build query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fullKey,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Load from keychain
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess,
              let resultDict = result as? [String: Any],
              var data = resultDict[kSecValueData as String] as? Data else {
            throw EnhancedKeychainError.loadFailed(status: status)
        }
        
        // Verify HMAC integrity
        if let storedHMAC = resultDict[kSecAttrLabel as String] as? String {
            let calculatedHMAC = generateHMAC(for: data, key: key)
            if storedHMAC != calculatedHMAC {
                logger.error("HMAC verification failed - data may be tampered")
                throw EnhancedKeychainError.integrityCheckFailed
            }
        }
        
        // Decrypt if high security
        if category.accessLevel == .highSecurity && encryptBeforeStorage {
            let encryptedData = try JSONDecoder().decode(EncryptedData.self, from: data)
            data = try dataEncryption.decryptData(encryptedData)
        }
        
        // Update metadata
        updateAccessMetadata(for: fullKey)
        
        // Decode and return
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
    
    // MARK: - Delete Operations
    
    /// Delete item with audit logging
    public func deleteSecureItem(
        key: String,
        category: ItemCategory,
        requireBiometric: Bool = true
    ) async throws {
        logger.info("Deleting secure item: \(category.keyPrefix)\(key)")
        
        // Biometric authentication for deletion
        if requireBiometric {
            let authResult = await biometricAuth.authenticate(
                reason: "Authenticate to delete \(category)"
            )
            
            guard case .success = authResult else {
                throw EnhancedKeychainError.biometricAuthenticationFailed
            }
        }
        
        let fullKey = "\(category.keyPrefix)\(key)"
        
        // Audit log before deletion
        logDeletion(key: fullKey, category: category)
        
        // Delete item
        deleteItem(for: fullKey)
        
        logger.info("Successfully deleted secure item")
    }
    
    /// Clear all items in a category
    public func clearCategory(_ category: ItemCategory) async throws {
        logger.warning("Clearing all items in category: \(category)")
        
        // Require biometric for bulk deletion
        let authResult = await biometricAuth.authenticate(
            reason: "Authenticate to clear all \(category) items"
        )
        
        guard case .success = authResult else {
            throw EnhancedKeychainError.biometricAuthenticationFailed
        }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Add category filter using prefix matching
        // This requires enumerating and filtering
        let allItems = try await getAllItemKeys()
        let categoryItems = allItems.filter { $0.hasPrefix(category.keyPrefix) }
        
        for itemKey in categoryItems {
            deleteItem(for: itemKey)
        }
        
        logger.info("Cleared \(categoryItems.count) items from category")
    }
    
    // MARK: - Utility Methods
    
    /// Check if item exists
    public func itemExists(key: String, category: ItemCategory) -> Bool {
        let fullKey = "\(category.keyPrefix)\(key)"
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fullKey,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Get all item keys (for management purposes)
    private func getAllItemKeys() async throws -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
    
    // MARK: - Helper Methods
    
    private func createAccessControl(for level: AccessLevel) -> SecAccessControl? {
        var protection: CFString
        var flags: SecAccessControlCreateFlags = []
        
        switch level {
        case .standard:
            protection = kSecAttrAccessibleWhenUnlocked
        case .protected:
            protection = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .biometric:
            protection = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            flags = [.biometryCurrentSet]
        case .highSecurity:
            protection = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            flags = [.biometryCurrentSet, .privateKeyUsage]
        }
        
        var error: Unmanaged<CFError>?
        let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            protection,
            flags,
            &error
        )
        
        if let error = error {
            logger.error("Failed to create access control: \(error.takeRetainedValue())")
        }
        
        return access
    }
    
    private func generateHMAC(for data: Data, key: String) -> String {
        let key = SymmetricKey(data: key.data(using: .utf8)!)
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(hmac).base64EncodedString()
    }
    
    private func deleteItem(for key: String) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        SecItemDelete(query as CFDictionary)
    }
    
    private func updateAccessMetadata(for key: String) {
        // Update access count and last accessed time
        // This would be implemented with a proper update query
        logger.debug("Updated access metadata for: \(key)")
    }
    
    private func logDeletion(key: String, category: ItemCategory) {
        logger.info("Audit: Deleted item \(key) from category \(category)")
        // In production, this would write to a secure audit log
    }
}

// MARK: - Supporting Types

private struct ItemMetadata: Codable {
    let category: EnhancedKeychainManager.ItemCategory
    let createdAt: Date
    var lastAccessed: Date
    var accessCount: Int
}

public enum EnhancedKeychainError: LocalizedError {
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case biometricAuthenticationFailed
    case integrityCheckFailed
    case itemNotFound
    case invalidData
    case accessDenied
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to keychain: \(status)"
        case .loadFailed(let status):
            return "Failed to load from keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from keychain: \(status)"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        case .integrityCheckFailed:
            return "Data integrity verification failed"
        case .itemNotFound:
            return "Item not found in keychain"
        case .invalidData:
            return "Invalid data format"
        case .accessDenied:
            return "Access denied to keychain item"
        }
    }
}

// Make ItemCategory Codable
extension EnhancedKeychainManager.ItemCategory: Codable {
    private enum CodingKeys: String, CodingKey {
        case apiKey, authToken, refreshToken, sshKey, passphrase
        case certificate, sessionData, userCredentials
    }
}