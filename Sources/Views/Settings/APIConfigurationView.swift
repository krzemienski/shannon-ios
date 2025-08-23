//
//  APIConfigurationView.swift
//  ClaudeCode
//
//  API configuration settings view
//

import SwiftUI

struct APIConfigurationView: View {
    @EnvironmentObject var coordinator: SettingsCoordinator
    @State private var apiKey = ""
    @State private var baseURL = "http://localhost:8000/v1"
    @State private var timeout = 30.0
    @State private var maxRetries = 3
    @State private var isTestingConnection = false
    
    var body: some View {
        Form {
            Section("API Credentials") {
                SecureField("API Key", text: $apiKey)
                    .textContentType(.password)
                
                TextField("Base URL", text: $baseURL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
            }
            
            Section("Connection Settings") {
                HStack {
                    Text("Timeout")
                    Spacer()
                    Text("\(Int(timeout))s")
                        .foregroundColor(Theme.mutedForeground)
                }
                Slider(value: $timeout, in: 10...120, step: 5)
                
                Stepper("Max Retries: \(maxRetries)", value: $maxRetries, in: 0...10)
            }
            
            Section {
                Button(action: testConnection) {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        }
                        Text(isTestingConnection ? "Testing..." : "Test Connection")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTestingConnection)
                
                Button("Save Configuration") {
                    saveConfiguration()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)
            }
        }
        .navigationTitle("API Configuration")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func testConnection() {
        isTestingConnection = true
        
        // Simulate connection test
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isTestingConnection = false
        }
    }
    
    private func saveConfiguration() {
        // TODO: Save API configuration
    }
}