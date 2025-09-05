//
//  SSHKeyManagementView.swift
//  ClaudeCode
//
//  SSH key management interface
//

import SwiftUI

/// SSH key management view
public struct SSHKeyManagementView: View {
    @StateObject private var credentialManager = SSHCredentialManager.shared
    @State private var showKeyGenerator = false
    @State private var showKeyImporter = false
    @State private var selectedKey: SSHKey?
    @State private var showDeleteAlert = false
    @State private var keyToDelete: SSHKey?
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationStack {
            List {
                // SSH Keys section
                Section("SSH Keys") {
                    if credentialManager.savedKeys.isEmpty {
                        emptyKeysView
                    } else {
                        ForEach(credentialManager.savedKeys) { key in
                            SSHKeyRow(key: key) {
                                selectedKey = key
                            } onDelete: {
                                keyToDelete = key
                                showDeleteAlert = true
                            }
                        }
                    }
                }
                
                // Actions section
                Section {
                    Button(action: {
                        showKeyGenerator = true
                    }) {
                        Label("Generate New Key", systemImage: "key.fill")
                            .foregroundColor(Theme.primary)
                    }
                    
                    Button(action: {
                        showKeyImporter = true
                    }) {
                        Label("Import Key", systemImage: "square.and.arrow.down")
                            .foregroundColor(Theme.primary)
                    }
                }
            }
            .navigationTitle("SSH Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showKeyGenerator) {
                SSHKeyGeneratorView()
            }
            .sheet(isPresented: $showKeyImporter) {
                SSHKeyImporter { keyContent in
                    Task {
                        await importKey(keyContent)
                    }
                }
            }
            .sheet(item: $selectedKey) { key in
                SSHKeyDetailView(key: key)
            }
            .alert("Delete SSH Key", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let key = keyToDelete {
                        Task {
                            await deleteKey(key)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this SSH key? This action cannot be undone.")
            }
        }
    }
    
    private var emptyKeysView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No SSH Keys")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Generate or import SSH keys to use for authentication")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private func importKey(_ content: String) async {
        // Parse and save the key
        do {
            let keyType = detectKeyType(from: content)
            let key = SSHKey(
                name: "Imported Key",
                type: keyType,
                publicKey: "", // Extract from private key if needed
                privateKey: content,
                passphrase: nil,
                createdAt: Date()
            )
            
            try await credentialManager.saveKey(key)
        } catch {
            print("Failed to import key: \(error)")
        }
    }
    
    private func deleteKey(_ key: SSHKey) async {
        do {
            try await credentialManager.deleteKey(id: key.id)
        } catch {
            print("Failed to delete key: \(error)")
        }
    }
    
    private func detectKeyType(from content: String) -> SSHKeyType {
        if content.contains("RSA") {
            return .rsa(4096)
        } else if content.contains("ED25519") {
            return .ed25519
        } else if content.contains("ECDSA") {
            return .ecdsa
        }
        return .rsa(4096)
    }
}

// MARK: - SSH Key Row

struct SSHKeyRow: View {
    let key: SSHKey
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "key.fill")
                .foregroundColor(Theme.primary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(key.name)
                    .font(.headline)
                
                HStack {
                    Text(key.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(key.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - SSH Key Generator View

struct SSHKeyGeneratorView: View {
    @State private var keyName = ""
    @State private var keyType: SSHKeyType = .ed25519
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var isGenerating = false
    @StateObject private var credentialManager = SSHCredentialManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Key Information") {
                    TextField("Key Name", text: $keyName)
                        .textInputAutocapitalization(.never)
                    
                    Picker("Key Type", selection: $keyType) {
                        Text("ED25519 (Recommended)").tag(SSHKeyType.ed25519)
                        Text("RSA 4096").tag(SSHKeyType.rsa(4096))
                        Text("RSA 2048").tag(SSHKeyType.rsa(2048))
                        Text("ECDSA").tag(SSHKeyType.ecdsa)
                    }
                }
                
                Section("Security") {
                    SecureField("Passphrase (Optional)", text: $passphrase)
                    
                    if !passphrase.isEmpty {
                        SecureField("Confirm Passphrase", text: $confirmPassphrase)
                    }
                }
                
                Section {
                    Text("SSH keys are used for secure authentication without passwords. ED25519 keys are recommended for their security and performance.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Generate SSH Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Generate") {
                        generateKey()
                    }
                    .disabled(keyName.isEmpty || isGenerating || !passphraseValid)
                }
            }
            .overlay {
                if isGenerating {
                    ProgressView("Generating Key...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var passphraseValid: Bool {
        passphrase.isEmpty || passphrase == confirmPassphrase
    }
    
    private func generateKey() {
        isGenerating = true
        
        Task {
            do {
                let key = try await credentialManager.generateSSHKey(
                    name: keyName,
                    type: keyType,
                    passphrase: passphrase.isEmpty ? nil : passphrase
                )
                
                try await credentialManager.saveKey(key)
                
                await MainActor.run {
                    isGenerating = false
                    dismiss()
                }
            } catch {
                print("Failed to generate key: \(error)")
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }
}

// MARK: - SSH Key Detail View

struct SSHKeyDetailView: View {
    let key: SSHKey
    @State private var showPublicKey = false
    @State private var showFingerprint = false
    @State private var copiedToClipboard = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Key Information") {
                    DetailRow(label: "Name", value: key.name)
                    DetailRow(label: "Type", value: key.type.rawValue)
                    DetailRow(label: "Created", value: key.createdAt.formatted())
                    
                    if let lastUsed = key.lastUsed {
                        DetailRow(label: "Last Used", value: lastUsed.formatted())
                    }
                }
                
                Section("Public Key") {
                    if showPublicKey {
                        Text(key.publicKey)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    } else {
                        Button("Show Public Key") {
                            showPublicKey = true
                        }
                    }
                    
                    Button(action: {
                        copyPublicKey()
                    }) {
                        Label(
                            copiedToClipboard ? "Copied!" : "Copy Public Key",
                            systemImage: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                        .foregroundColor(copiedToClipboard ? .green : Theme.primary)
                    }
                }
                
                Section("Security") {
                    if showFingerprint {
                        Text(key.fingerprint ?? "N/A")
                            .font(.system(.caption, design: .monospaced))
                    } else {
                        Button("Show Fingerprint") {
                            showFingerprint = true
                        }
                    }
                    
                    DetailRow(
                        label: "Passphrase Protected",
                        value: key.passphrase != nil ? "Yes" : "No"
                    )
                }
            }
            .navigationTitle("SSH Key Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func copyPublicKey() {
        UIPasteboard.general.string = key.publicKey
        copiedToClipboard = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}