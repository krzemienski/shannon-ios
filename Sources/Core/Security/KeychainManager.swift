//
//  KeychainManager.swift
//  ClaudeCode
//
//  Keychain wrapper for secure credential storage
//

import Foundation
import Security

/// Manager for secure keychain storage
@MainActor
class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.shannon.ClaudeCode"
    private let accessGroup: String? = nil // Set if using app groups
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Save data to keychain
    func save<T: Codable>(_ item: T, for key: String) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(item)
        
        // Delete any existing item first
        deleteItem(for: key)
        
        // Create query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Add item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw KeychainError.unableToSave
        }
    }
    
    /// Load data from keychain
    func load<T: Codable>(_ type: T.Type, for key: String) async throws -> T? {
        // Create query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Search for item
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw KeychainError.unableToLoad
        }
        
        // Decode data
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
    
    /// Delete item from keychain
    func delete(for key: String) async throws {
        deleteItem(for: key)
    }
    
    /// Save raw string to keychain
    func saveString(_ string: String, for key: String) async throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // Delete any existing item first
        deleteItem(for: key)
        
        // Create query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Add item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw KeychainError.unableToSave
        }
    }
    
    /// Load raw string from keychain
    func loadString(for key: String) async throws -> String? {
        // Create query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Search for item
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unableToLoad
        }
        
        return string
    }
    
    /// Check if item exists in keychain
    func exists(for key: String) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Clear all items from keychain
    func clearAll() async throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unableToDelete
        }
    }
    
    // MARK: - Private Methods
    
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
}

// MARK: - Keychain Error

enum KeychainError: LocalizedError {
    case unableToSave
    case unableToLoad
    case unableToDelete
    case invalidData
    case itemNotFound
    
    var errorDescription: String? {
        switch self {
        case .unableToSave:
            return "Unable to save item to keychain"
        case .unableToLoad:
            return "Unable to load item from keychain"
        case .unableToDelete:
            return "Unable to delete item from keychain"
        case .invalidData:
            return "Invalid data format"
        case .itemNotFound:
            return "Item not found in keychain"
        }
    }
}

// MARK: - Keychain Keys

extension KeychainManager {
    enum Keys {
        static let apiKey = "api_key"
        static let authToken = "auth_token"
        static let refreshToken = "refresh_token"
        static let userCredentials = "user_credentials"
        static let sshPrivateKey = "ssh_private_key"
        static let sshPassphrase = "ssh_passphrase"
    }
    
    // MARK: - API Key Management
    
    /// Save API key to keychain
    func saveAPIKey(_ apiKey: String) async throws {
        try await saveString(apiKey, for: Keys.apiKey)
    }
    
    /// Get API key from keychain
    func getAPIKey() async throws -> String? {
        return try await loadString(for: Keys.apiKey)
    }
}