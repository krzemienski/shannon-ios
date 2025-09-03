//
//  SSHCredentialManager.swift
//  ClaudeCode
//
//  SSH credential management service
//

import Foundation
import SwiftUI
import KeychainAccess

/// SSH Credential structure for saved connections
public struct SSHCredential: Identifiable, Codable {
    public let id: String
    public let name: String
    public let host: String
    public let port: UInt16
    public let username: String
    public let authMethod: AppSSHAuthMethod
    public let privateKeyPath: String?
    public let passphrase: String?
    public let createdAt: Date
    public let lastUsed: Date?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        host: String,
        port: UInt16 = 22,
        username: String,
        authMethod: AppSSHAuthMethod,
        privateKeyPath: String? = nil,
        passphrase: String? = nil,
        createdAt: Date = Date(),
        lastUsed: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.privateKeyPath = privateKeyPath
        self.passphrase = passphrase
        self.createdAt = createdAt
        self.lastUsed = lastUsed
    }
}

@MainActor
public final class SSHCredentialManager: ObservableObject {
    public static let shared = SSHCredentialManager()
    
    @Published public var savedCredentials: [SSHCredential] = []
    @Published public var savedKeys: [SSHKey] = []
    private let keychain = Keychain(service: "com.claudecode.ssh")
    private let credentialsKey = "ssh_saved_credentials"
    
    private init() {
        loadSavedKeys()
        loadSavedCredentials()
    }
    
    public func loadSavedKeys() {
        // Load saved SSH keys from keychain
        savedKeys = []
    }
    
    public func loadSavedCredentials() {
        // Load saved credentials from UserDefaults
        if let data = UserDefaults.standard.data(forKey: credentialsKey),
           let credentials = try? JSONDecoder().decode([SSHCredential].self, from: data) {
            savedCredentials = credentials
        } else {
            savedCredentials = []
        }
    }
    
    public func saveCredential(_ credential: SSHCredential) {
        // Remove existing credential with same ID
        savedCredentials.removeAll { $0.id == credential.id }
        
        // Add new credential
        savedCredentials.append(credential)
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(savedCredentials) {
            UserDefaults.standard.set(data, forKey: credentialsKey)
        }
    }
    
    public func deleteCredential(_ credentialId: String) {
        savedCredentials.removeAll { $0.id == credentialId }
        
        // Save updated list
        if let data = try? JSONEncoder().encode(savedCredentials) {
            UserDefaults.standard.set(data, forKey: credentialsKey)
        }
    }
    
    public func saveKey(_ key: SSHKey) {
        savedKeys.append(key)
        // Save to keychain
    }
    
    public func deleteKey(_ keyId: String) {
        savedKeys.removeAll { $0.id == keyId }
        // Remove from keychain
    }
    
    public func deleteKey(id: String) async throws {
        savedKeys.removeAll { $0.id == id }
        // Remove from keychain
    }
    
    public func generateSSHKey(name: String, type: SSHKeyType, passphrase: String?) async throws -> SSHKey {
        // Generate SSH key pair based on type
        // This is a placeholder implementation - real implementation would use a crypto library
        let publicKey = "ssh-rsa AAAAB3... generated_public_key_\(name)"
        let privateKey = "-----BEGIN RSA PRIVATE KEY-----\ngenerated_private_key_\(name)\n-----END RSA PRIVATE KEY-----"
        
        return SSHKey(
            name: name,
            type: type,
            publicKey: publicKey,
            privateKey: privateKey,
            passphrase: passphrase,
            createdAt: Date()
        )
    }
}

public enum SSHKeyType: Codable {
    case rsa(Int)
    case ed25519
    case ecdsa
    
    var displayName: String {
        switch self {
        case .rsa(let bits):
            return "RSA \(bits)"
        case .ed25519:
            return "Ed25519"
        case .ecdsa:
            return "ECDSA"
        }
    }
}

public struct SSHKey: Identifiable, Codable {
    public let id: String
    public let name: String
    public let type: SSHKeyType
    public let publicKey: String
    public let privateKey: String
    public let passphrase: String?
    public let createdAt: Date
    
    public init(id: String = UUID().uuidString, name: String, type: SSHKeyType = .ed25519, publicKey: String, privateKey: String, passphrase: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.type = type
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.passphrase = passphrase
        self.createdAt = createdAt
    }
}