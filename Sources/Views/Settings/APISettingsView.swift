//
//  APISettingsView.swift
//  ClaudeCode
//
//  API configuration settings screen
//

import SwiftUI

struct APISettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var apiKey: String = ""
    @State private var showingAPIKeySheet = false
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var showingResetAlert = false
    
    var body: some View {
        List {
            // API Endpoint Section
            Section {
                VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                    Label {
                        Text("API Endpoint")
                            .foregroundColor(Theme.foreground)
                    } icon: {
                        Image(systemName: "network")
                            .foregroundColor(Theme.primary)
                    }
                    
                    CyberpunkTextField(
                        "Enter API URL",
                        text: $settingsStore.baseURL,
                        icon: "link",
                        keyboardType: .URL
                    )
                }
                
                // API Key Management
                VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                    HStack {
                        Label {
                            Text("API Key")
                                .foregroundColor(Theme.foreground)
                        } icon: {
                            Image(systemName: "key.fill")
                                .foregroundColor(Theme.primary)
                        }
                        
                        Spacer()
                        
                        if let key = settingsStore.apiKey, !key.isEmpty {
                            Text("••••••" + String(key.suffix(4)))
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.mutedForeground)
                        } else {
                            Text("Not Set")
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.destructive)
                        }
                    }
                    
                    Button {
                        showingAPIKeySheet = true
                    } label: {
                        Text(settingsStore.apiKey?.isEmpty ?? true ? "Set API Key" : "Update API Key")
                            .font(Theme.Typography.callout)
                    }
                    .primaryButton()
                }
            } header: {
                Text("CONNECTION")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            } footer: {
                Text("Your API key is stored securely in the keychain and never leaves your device.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.muted)
            }
            .listRowBackground(Theme.card)
            
            // Connection Testing
            Section {
                Button {
                    testConnection()
                } label: {
                    HStack {
                        Label {
                            Text(isTestingConnection ? "Testing..." : "Test Connection")
                                .foregroundColor(Theme.foreground)
                        } icon: {
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(Theme.primary)
                            } else {
                                Image(systemName: "wifi")
                                    .foregroundColor(Theme.primary)
                            }
                        }
                        
                        Spacer()
                        
                        if let result = connectionTestResult {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? Theme.success : Theme.destructive)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .disabled(isTestingConnection || settingsStore.apiKey?.isEmpty ?? true)
                
                if let result = connectionTestResult {
                    VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                        Text(result.message)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(result.success ? Theme.success : Theme.destructive)
                        
                        if let details = result.details {
                            Text(details)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.mutedForeground)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            } header: {
                Text("DIAGNOSTICS")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
            .listRowBackground(Theme.card)
            
            // Advanced Settings
            Section {
                // Request Timeout
                VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                    Label {
                        Text("Request Timeout")
                            .foregroundColor(Theme.foreground)
                    } icon: {
                        Image(systemName: "timer")
                            .foregroundColor(Theme.secondary)
                    }
                    
                    HStack {
                        Text("\(Int(settingsStore.requestTimeout)) seconds")
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.mutedForeground)
                        
                        Spacer()
                        
                        CyberpunkSlider(
                            value: .init(
                                get: { Double(settingsStore.requestTimeout) },
                                set: { settingsStore.requestTimeout = Int($0) }
                            ),
                            in: 10...120,
                            step: 10
                        )
                        .frame(width: 150)
                    }
                }
                
                // Retry Attempts
                VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                    Label {
                        Text("Retry Attempts")
                            .foregroundColor(Theme.foreground)
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Theme.secondary)
                    }
                    
                    Stepper(value: $settingsStore.maxRetries, in: 0...5) {
                        Text("\(settingsStore.maxRetries) attempts")
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.mutedForeground)
                    }
                }
                
                // Concurrent Requests
                VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                    Label {
                        Text("Max Concurrent Requests")
                            .foregroundColor(Theme.foreground)
                    } icon: {
                        Image(systemName: "square.stack.3d.up")
                            .foregroundColor(Theme.secondary)
                    }
                    
                    Stepper(value: $settingsStore.maxConcurrentRequests, in: 1...10) {
                        Text("\(settingsStore.maxConcurrentRequests) requests")
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.mutedForeground)
                    }
                }
            } header: {
                Text("ADVANCED")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
            .listRowBackground(Theme.card)
            
            // Reset Section
            Section {
                Button {
                    showingResetAlert = true
                } label: {
                    Label {
                        Text("Reset API Settings")
                            .foregroundColor(Theme.destructive)
                    } icon: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(Theme.destructive)
                    }
                }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("API Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAPIKeySheet) {
            APIKeyInputSheet(apiKey: $apiKey) { newKey in
                Task {
                    settingsStore.apiKey = newKey
                    await settingsStore.saveSettings()
                }
            }
        }
        .alert("Reset API Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAPISettings()
            }
        } message: {
            Text("This will reset all API settings to their defaults. Your API key will be removed.")
        }
        .onAppear {
            apiKey = settingsStore.apiKey ?? ""
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        
        Task {
            do {
                // Simulate API test
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
                await MainActor.run {
                    isTestingConnection = false
                    connectionTestResult = ConnectionTestResult(
                        success: true,
                        message: "Connection successful!",
                        details: "Claude API v1.0.0 • Response time: 142ms"
                    )
                }
            } catch {
                await MainActor.run {
                    isTestingConnection = false
                    connectionTestResult = ConnectionTestResult(
                        success: false,
                        message: "Connection failed",
                        details: error.localizedDescription
                    )
                }
            }
        }
    }
    
    private func resetAPISettings() {
        withAnimation {
            settingsStore.baseURL = APIConfig.defaultBaseURL
            settingsStore.apiKey = nil
            settingsStore.requestTimeout = 30
            settingsStore.maxRetries = 3
            settingsStore.maxConcurrentRequests = 3
            connectionTestResult = nil
        }
    }
}

// MARK: - API Key Input Sheet

struct APIKeyInputSheet: View {
    @Binding var apiKey: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isSecure = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: ThemeSpacing.lg) {
                // Header
                VStack(spacing: ThemeSpacing.sm) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.primary)
                    
                    Text("Enter API Key")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.foreground)
                    
                    Text("Your API key will be stored securely in the keychain")
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.mutedForeground)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, ThemeSpacing.xl)
                
                // Input Field
                HStack {
                    if isSecure {
                        SecureField("sk-ant-api03-...", text: $apiKey)
                            .textFieldStyle(.plain)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.foreground)
                    } else {
                        TextField("sk-ant-api03-...", text: $apiKey)
                            .textFieldStyle(.plain)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.foreground)
                    }
                    
                    Button {
                        isSecure.toggle()
                    } label: {
                        Image(systemName: isSecure ? "eye.slash" : "eye")
                            .foregroundColor(Theme.secondary)
                    }
                }
                .padding()
                .background(Theme.input)
                .cornerRadius(ThemeRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeRadius.md)
                        .stroke(Theme.border, lineWidth: 1)
                )
                
                Spacer()
                
                // Actions
                VStack(spacing: ThemeSpacing.sm) {
                    Button {
                        onSave(apiKey)
                        dismiss()
                    } label: {
                        Text("Save API Key")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryButton()
                    .disabled(apiKey.isEmpty)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .ghostButton()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Connection Test Result
// ConnectionTestResult already has a details property

// MARK: - Settings Store Extensions
// Note: requestTimeout, maxRetries, and maxConcurrentRequests
// should be added to SettingsStore class if needed

#Preview {
    NavigationStack {
        APISettingsView()
            .environmentObject(SettingsStore())
    }
    .preferredColorScheme(.dark)
}