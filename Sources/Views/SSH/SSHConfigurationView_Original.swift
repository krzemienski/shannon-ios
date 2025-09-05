//
//  SSHConfigurationView.swift
//  ClaudeCode
//
//  SSH connection configuration and management UI
//

import SwiftUI

/// SSH configuration view for setting up connections
public struct SSHConfigurationView: View {
    @State private var config = AppSSHConfig.default
    @State private var password = ""
    @State private var privateKey = ""
    @State private var passphrase = ""
    @State private var saveCredentials = true
    @State private var testingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var showAdvancedOptions = false
    @State private var selectedKeyId: String?
    @State private var showKeyImporter = false
    
    @StateObject private var credentialManager = SSHCredentialManager.shared
    @StateObject private var sessionManager = SSHSessionManager.shared
    
    @Environment(\.dismiss) private var dismiss
    
    let onConnect: (AppSSHConfig) -> Void
    let onSave: ((AppSSHConfig) -> Void)?
    
    // MARK: - Body
    
    public var body: some View {
        NavigationStack {
            Form {
                connectionSection
                authenticationSection
                
                if showAdvancedOptions {
                    advancedOptionsSection
                }
                
                actionsSection
            }
            .navigationTitle("SSH Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Connect") {
                        connect()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showKeyImporter) {
                SSHKeyImporter { importedKey in
                    privateKey = importedKey
                }
            }
        }
    }
    
    // MARK: - Connection Section
    
    private var connectionSection: some View {
        Section("Connection") {
            HStack {
                Label("Name", systemImage: "tag")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                TextField("My Server", text: $config.name)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Label("Host", systemImage: "server.rack")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                TextField("example.com or 192.168.1.1", text: $config.host)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            HStack {
                Label("Port", systemImage: "number")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                TextField("22", value: $config.port, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }
            
            HStack {
                Label("Username", systemImage: "person")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                TextField("username", text: $config.username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
    }
    
    // MARK: - Authentication Section
    
    private var authenticationSection: some View {
        Section("Authentication") {
            Picker("Method", selection: $config.authMethod) {
                Text("Password").tag(AppSSHAuthMethod.password)
                Text("SSH Key").tag(AppSSHAuthMethod.publicKey)
                Text("Keyboard Interactive").tag(AppSSHAuthMethod.keyboardInteractive)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.vertical, 4)
            
            switch config.authMethod {
            case .password:
                passwordAuthFields
                
            case .publicKey:
                publicKeyAuthFields
                
            case .keyboardInteractive:
                Text("Keyboard Interactive authentication will prompt for credentials during connection")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .none:
                EmptyView()
            }
            
            Toggle("Save Credentials", isOn: $saveCredentials)
                .tint(Theme.primary)
        }
    }
    
    private var passwordAuthFields: some View {
        Group {
            HStack {
                Label("Password", systemImage: "lock")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                SecureField("Enter password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            }
        }
    }
    
    private var publicKeyAuthFields: some View {
        Group {
            // Key selection
            if !credentialManager.savedKeys.isEmpty {
                Picker("SSH Key", selection: $selectedKeyId) {
                    Text("None").tag(nil as String?)
                    
                    ForEach(credentialManager.savedKeys) { key in
                        HStack {
                            Image(systemName: "key.fill")
                            VStack(alignment: .leading) {
                                Text(key.name)
                                Text(key.type.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(key.id as String?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Import key button
            Button(action: {
                showKeyImporter = true
            }) {
                Label("Import SSH Key", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Theme.primary)
            
            // Passphrase field
            if selectedKeyId != nil || !privateKey.isEmpty {
                HStack {
                    Label("Passphrase", systemImage: "key")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    SecureField("Enter passphrase (optional)", text: $passphrase)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
    
    // MARK: - Advanced Options Section
    
    private var advancedOptionsSection: some View {
        Section("Advanced Options") {
            Toggle("Strict Host Key Checking", isOn: $config.strictHostKeyChecking)
                .tint(Theme.primary)
            
            Toggle("Enable Compression", isOn: $config.enableCompression)
                .tint(Theme.primary)
            
            Toggle("Auto Reconnect", isOn: $config.autoReconnect)
                .tint(Theme.primary)
            
            Toggle("Agent Forwarding", isOn: $config.enableAgentForwarding)
                .tint(Theme.primary)
            
            HStack {
                Text("Keep Alive Interval")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                TextField("30", value: $config.keepAliveInterval, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .keyboardType(.numberPad)
                
                Text("seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Connection Timeout")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                TextField("10", value: $config.connectionTimeout, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .keyboardType(.numberPad)
                
                Text("seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Section {
            // Advanced options toggle
            Button(action: {
                withAnimation {
                    showAdvancedOptions.toggle()
                }
            }) {
                HStack {
                    Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                    Text(showAdvancedOptions ? "Hide Advanced Options" : "Show Advanced Options")
                    Spacer()
                }
                .foregroundColor(Theme.primary)
            }
            
            // Test connection
            Button(action: testConnection) {
                HStack {
                    if testingConnection {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "network")
                    }
                    
                    Text("Test Connection")
                    
                    Spacer()
                    
                    if let result = connectionTestResult {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.success ? .green : .red)
                    }
                }
            }
            .disabled(testingConnection || !isValid)
            
            // Quick connect presets
            if !credentialManager.savedCredentials.isEmpty {
                Menu {
                    ForEach(credentialManager.savedCredentials) { credential in
                        Button(credential.name) {
                            loadPreset(credential)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Load Recent Connection")
                        Spacer()
                    }
                    .foregroundColor(Theme.primary)
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private var isValid: Bool {
        !config.host.isEmpty &&
        !config.username.isEmpty &&
        config.port > 0 &&
        config.port <= 65535 &&
        (config.authMethod == .password ? !password.isEmpty :
         config.authMethod == .publicKey ? (selectedKeyId != nil || !privateKey.isEmpty) :
         true)
    }
    
    // MARK: - Actions
    
    private func testConnection() {
        testingConnection = true
        connectionTestResult = nil
        
        Task {
            do {
                let service = SSHService()
                
                switch config.authMethod {
                case .password:
                    try await service.connect(
                        host: config.host,
                        port: config.port,
                        username: config.username,
                        password: password
                    )
                    
                case .publicKey:
                    let key: String
                    if let keyId = selectedKeyId {
                        let sshKey = try await credentialManager.loadKey(id: keyId)
                        key = sshKey.privateKey
                    } else {
                        key = privateKey
                    }
                    
                    try await service.connect(
                        host: config.host,
                        port: config.port,
                        username: config.username,
                        privateKey: key,
                        passphrase: passphrase.isEmpty ? nil : passphrase
                    )
                    
                default:
                    break
                }
                
                // Test successful
                await service.disconnect()
                
                await MainActor.run {
                    connectionTestResult = ConnectionTestResult(
                        success: true,
                        message: "Connection successful"
                    )
                }
                
            } catch {
                await MainActor.run {
                    connectionTestResult = ConnectionTestResult(
                        success: false,
                        message: error.localizedDescription
                    )
                }
            }
            
            await MainActor.run {
                testingConnection = false
            }
        }
    }
    
    private func connect() {
        guard isValid else { return }
        
        // Prepare config with credentials
        var finalConfig = config
        
        // Save credentials if requested
        if saveCredentials {
            Task {
                let credential = SSHCredential(
                    name: config.name,
                    host: config.host,
                    port: config.port,
                    username: config.username,
                    authMethod: config.authMethod,
                    password: config.authMethod == .password ? password : nil,
                    privateKey: config.authMethod == .publicKey ? privateKey : nil,
                    passphrase: config.authMethod == .publicKey && !passphrase.isEmpty ? passphrase : nil
                )
                
                try? await credentialManager.saveCredential(credential)
            }
        }
        
        onConnect(finalConfig)
        dismiss()
    }
    
    private func loadPreset(_ credential: SSHCredential) {
        config.name = credential.name
        config.host = credential.host
        config.port = credential.port
        config.username = credential.username
        config.authMethod = credential.authMethod
        
        Task {
            if let loaded = try? await credentialManager.loadCredential(id: credential.id) {
                await MainActor.run {
                    password = loaded.password ?? ""
                    privateKey = loaded.privateKey ?? ""
                    passphrase = loaded.passphrase ?? ""
                }
            }
        }
    }
}

// MARK: - SSH Connection Sheet

struct SSHConnectionSheet: View {
    let onConnect: (AppSSHConfig) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        SSHConfigurationView(
            onConnect: onConnect,
            onSave: nil
        )
    }
}

// MARK: - SSH Key Importer

struct SSHKeyImporter: View {
    let onImport: (String) -> Void
    @State private var keyText = ""
    @State private var showFilePicker = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Import SSH Key") {
                    TextEditor(text: $keyText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                    
                    Button(action: {
                        showFilePicker = true
                    }) {
                        Label("Import from File", systemImage: "doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("Import SSH Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        onImport(keyText)
                        dismiss()
                    }
                    .disabled(keyText.isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.text, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        loadKeyFromFile(url)
                    }
                case .failure(let error):
                    print("File import error: \(error)")
                }
            }
        }
    }
    
    private func loadKeyFromFile(_ url: URL) {
        do {
            keyText = try String(contentsOf: url)
        } catch {
            print("Error loading key file: \(error)")
        }
    }
}

// MARK: - Supporting Types

// ConnectionTestResult is now imported from SettingsModels

// MARK: - Preview

#Preview {
    SSHConfigurationView(
        onConnect: { _ in },
        onSave: nil
    )
}