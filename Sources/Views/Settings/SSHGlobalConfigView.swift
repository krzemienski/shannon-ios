//
//  SSHGlobalConfigView.swift
//  ClaudeCode
//
//  Global SSH configuration settings
//

import SwiftUI

struct SSHGlobalConfigView: View {
    @EnvironmentObject var coordinator: SettingsCoordinator
    @State private var defaultPort = "22"
    @State private var connectionTimeout = 30
    @State private var keepAliveInterval = 60
    @State private var enableCompression = true
    @State private var enableStrictHostChecking = true
    
    var body: some View {
        Form {
            Section("Default Settings") {
                TextField("Default Port", text: $defaultPort)
                    .keyboardType(.numberPad)
                
                Stepper("Connection Timeout: \(connectionTimeout)s", 
                       value: $connectionTimeout, in: 10...120, step: 5)
                
                Stepper("Keep Alive: \(keepAliveInterval)s",
                       value: $keepAliveInterval, in: 0...300, step: 30)
            }
            
            Section("Security") {
                Toggle("Enable Compression", isOn: $enableCompression)
                Toggle("Strict Host Checking", isOn: $enableStrictHostChecking)
            }
            
            Section("SSH Keys") {
                Button("Manage SSH Keys") {
                    // TODO: Navigate to SSH key management
                }
                
                Button("Generate New Key") {
                    // TODO: Generate new SSH key
                }
            }
            
            Section {
                Button("Save Configuration") {
                    saveConfiguration()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("SSH Configuration")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func saveConfiguration() {
        // TODO: Save SSH configuration
    }
}