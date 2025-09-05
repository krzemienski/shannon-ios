// MVP: Simplified API settings view to avoid compilation errors
import SwiftUI

struct APISettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var apiKey: String = ""
    @State private var baseURL: String = "http://localhost:8000"
    @State private var showingAPIKeySheet = false
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    
    var body: some View {
        List {
            // API Endpoint Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("API Endpoint", systemImage: "network")
                        .foregroundColor(Theme.primary)
                    
                    TextField("Enter API URL", text: $baseURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // API Key Management
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("API Key", systemImage: "key.fill")
                            .foregroundColor(Theme.primary)
                        
                        Spacer()
                        
                        if !apiKey.isEmpty {
                            Text("••••••" + String(apiKey.suffix(4)))
                                .font(.footnote)
                                .foregroundColor(Theme.mutedForeground)
                        } else {
                            Text("Not Set")
                                .font(.footnote)
                                .foregroundColor(Theme.destructive)
                        }
                    }
                    
                    Button {
                        showingAPIKeySheet = true
                    } label: {
                        Text(apiKey.isEmpty ? "Set API Key" : "Update API Key")
                            .foregroundColor(Theme.primary)
                    }
                }
            } header: {
                Text("CONNECTION")
                    .font(.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            // Connection Testing
            Section {
                Button {
                    testConnection()
                } label: {
                    HStack {
                        Label(isTestingConnection ? "Testing..." : "Test Connection", systemImage: "wifi")
                            .foregroundColor(Theme.foreground)
                        
                        Spacer()
                        
                        if let result = connectionTestResult {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? Theme.success : Theme.destructive)
                        }
                    }
                }
                .disabled(isTestingConnection || apiKey.isEmpty)
                
                if let result = connectionTestResult {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.message)
                            .font(.footnote)
                            .foregroundColor(result.success ? Theme.success : Theme.destructive)
                        
                        if let details = result.details {
                            Text(details)
                                .font(.caption)
                                .foregroundColor(Theme.mutedForeground)
                        }
                    }
                }
            } header: {
                Text("DIAGNOSTICS")
                    .font(.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
        }
        .navigationTitle("API Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAPIKeySheet) {
            APIKeyInputSheet(apiKey: $apiKey) { newKey in
                apiKey = newKey
                // MVP: Save to settings store if needed
                Task {
                    settingsStore.apiKey = newKey
                    await settingsStore.saveSettings()
                }
            }
        }
        .onAppear {
            apiKey = settingsStore.apiKey ?? ""
            baseURL = settingsStore.baseURL
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        
        Task {
            // MVP: Simulate connection test
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                isTestingConnection = false
                connectionTestResult = ConnectionTestResult(
                    success: true,
                    message: "Connection successful!",
                    details: "MVP: Ready to connect to \(baseURL)"
                )
            }
        }
    }
}

// MVP: Simplified API Key Input Sheet
struct APIKeyInputSheet: View {
    @Binding var apiKey: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tempKey = ""
    @State private var isSecure = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.primary)
                    
                    Text("Enter API Key")
                        .font(.title2)
                        .foregroundColor(Theme.foreground)
                    
                    Text("Your API key will be stored securely")
                        .font(.footnote)
                        .foregroundColor(Theme.mutedForeground)
                }
                .padding(.top, 40)
                
                // Input Field
                HStack {
                    if isSecure {
                        SecureField("sk-ant-api03-...", text: $tempKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        TextField("sk-ant-api03-...", text: $tempKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Button {
                        isSecure.toggle()
                    } label: {
                        Image(systemName: isSecure ? "eye.slash" : "eye")
                            .foregroundColor(Theme.secondary)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    Button {
                        onSave(tempKey)
                        dismiss()
                    } label: {
                        Text("Save API Key")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primary)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(tempKey.isEmpty)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(Theme.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Theme.background)
            .navigationBarHidden(true)
        }
        .onAppear {
            tempKey = apiKey
        }
    }
}

#Preview {
    NavigationStack {
        APISettingsView()
            .environmentObject(SettingsStore())
    }
}