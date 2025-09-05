//
//  AuthenticationView.swift
//  ClaudeCode
//
//  Authentication view for API key setup
//

import SwiftUI

struct AuthenticationView: View {
    let onSuccess: () -> Void
    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAdvancedSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.spacing.xl) {
                    // Logo
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.primary)
                        .padding()
                        .background(
                            Circle()
                                .fill(Theme.primary.opacity(0.1))
                        )
                        .padding(.top, Theme.spacing.xxl)
                    
                    // Title
                    VStack(spacing: Theme.spacing.sm) {
                        Text("Authentication Required")
                            .font(Theme.Typography.titleFont)
                            .foregroundColor(Theme.foreground)
                        
                        Text("Enter your API credentials to continue")
                            .font(Theme.Typography.bodyFont)
                            .foregroundColor(Theme.mutedForeground)
                    }
                    
                    // Form
                    VStack(alignment: .leading, spacing: Theme.spacing.lg) {
                        // API Key Field
                        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
                            Text("API Key")
                                .font(Theme.Typography.captionFont)
                                .foregroundColor(Theme.mutedForeground)
                            
                            SecureField("Enter your Claude API key", text: $apiKey)
                                .textFieldStyle(CyberpunkTextFieldStyle())
                        }
                        
                        // Advanced Settings
                        DisclosureGroup(
                            "Advanced Settings",
                            isExpanded: $showAdvancedSettings
                        ) {
                            VStack(alignment: .leading, spacing: Theme.spacing.sm) {
                                Text("Base URL (Optional)")
                                    .font(Theme.Typography.captionFont)
                                    .foregroundColor(Theme.mutedForeground)
                                
                                TextField("https://api.example.com", text: $baseURL)
                                    .textFieldStyle(CyberpunkTextFieldStyle())
                                    .autocapitalization(.none)
                                    .keyboardType(.URL)
                                
                                Text("Leave empty to use the default API endpoint")
                                    .font(Theme.Typography.caption2Font)
                                    .foregroundColor(Theme.mutedForeground)
                            }
                            .padding(.top, Theme.spacing.md)
                        }
                        .tint(Theme.primary)
                        .font(Theme.Typography.captionFont)
                        .foregroundColor(Theme.primary)
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.destructive)
                            
                            Text(errorMessage)
                                .font(Theme.Typography.caption2Font)
                                .foregroundColor(Theme.destructive)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Theme.destructive.opacity(0.1))
                        .cornerRadius(Theme.Radius.md)
                        .padding(.horizontal)
                    }
                    
                    // Buttons
                    VStack(spacing: Theme.spacing.md) {
                        CyberpunkButton(
                            "Authenticate",
                            variant: .primary,
                            isLoading: isLoading,
                            action: {
                                authenticate()
                            }
                        )
                        .disabled(apiKey.isEmpty)
                        
                        Button("Learn how to get an API key") {
                            openAPIKeyGuide()
                        }
                        .font(Theme.Typography.captionFont)
                        .foregroundColor(Theme.primary)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .background(Theme.background)
            .navigationBarHidden(true)
        }
    }
    
    private func authenticate() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Save credentials
                DependencyContainer.shared.settingsStore.updateAPIConfiguration(
                    apiKey: apiKey,
                    baseURL: baseURL.isEmpty ? nil : baseURL
                )
                
                // Configure API client
                DependencyContainer.shared.apiClient.setAPIKey(apiKey)
                if !baseURL.isEmpty, let url = URL(string: baseURL) {
                    DependencyContainer.shared.apiClient.setBaseURL(url)
                }
                
                // Test connection
                let isValid = try await DependencyContainer.shared.apiClient.testConnection()
                
                if isValid {
                    // MVP: Skip setting authenticated state
                    // await DependencyContainer.shared.appState.setAuthenticated(true)
                    
                    await MainActor.run {
                        onSuccess()
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Invalid API credentials. Please check and try again."
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func openAPIKeyGuide() {
        if let url = URL(string: "https://docs.anthropic.com/claude/docs/getting-access") {
            UIApplication.shared.open(url)
        }
    }
}

// Cyberpunk-styled text field
struct CyberpunkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.primary.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(Theme.Radius.md)
            .font(Theme.Typography.bodyFont)
            .foregroundColor(Theme.foreground)
    }
}