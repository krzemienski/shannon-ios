//
//  SSHCredentialManager.swift
//  ClaudeCode
//
//  SSH credential management service
//

import Foundation
import SwiftUI
import KeychainAccess

@MainActor
final class SSHCredentialManager: ObservableObject {
    static let shared = SSHCredentialManager()
    
    @Published var savedKeys: [SSHKey] = []
    private let keychain = Keychain(service: "com.claudecode.ssh")
    
    private init() {
        loadSavedKeys()
    }
    
    func loadSavedKeys() {
        // Load saved SSH keys from keychain
        savedKeys = []
    }
    
    func saveKey(_ key: SSHKey) {
        savedKeys.append(key)
        // Save to keychain
    }
    
    func deleteKey(_ keyId: String) {
        savedKeys.removeAll { $0.id == keyId }
        // Remove from keychain
    }
}

struct SSHKey: Identifiable {
    let id: String
    let name: String
    let publicKey: String
    let privateKey: String
    let passphrase: String?
    let createdAt: Date
}