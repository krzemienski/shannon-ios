//
//  PrivacySettingsView.swift
//  ClaudeCode
//
//  Privacy and security settings view
//

import SwiftUI

struct PrivacySettingsView: View {
    @AppStorage("privacy.analytics") private var analyticsEnabled = false
    @AppStorage("privacy.crashReports") private var crashReportsEnabled = false
    @AppStorage("privacy.personalization") private var personalizationEnabled = true
    @AppStorage("privacy.dataCollection") private var dataCollectionEnabled = false
    @AppStorage("privacy.biometricAuth") private var biometricAuthEnabled = true
    
    var body: some View {
        Form {
            Section("Data & Analytics") {
                Toggle("Share Analytics", isOn: $analyticsEnabled)
                    .tint(Theme.primary)
                
                Toggle("Share Crash Reports", isOn: $crashReportsEnabled)
                    .tint(Theme.primary)
                
                Toggle("Personalized Experience", isOn: $personalizationEnabled)
                    .tint(Theme.primary)
                
                Toggle("Data Collection", isOn: $dataCollectionEnabled)
                    .tint(Theme.primary)
            }
            
            Section("Security") {
                Toggle("Biometric Authentication", isOn: $biometricAuthEnabled)
                    .tint(Theme.primary)
                
                Button(action: clearKeychainData) {
                    Label("Clear Keychain Data", systemImage: "key.fill")
                        .foregroundColor(.red)
                }
                
                Button(action: resetPrivacySettings) {
                    Label("Reset Privacy Settings", systemImage: "arrow.counterclockwise")
                        .foregroundColor(.orange)
                }
            }
            
            Section("Data Management") {
                Button(action: exportPrivacyData) {
                    Label("Export Privacy Data", systemImage: "square.and.arrow.up")
                }
                
                Button(action: deleteAllData) {
                    Label("Delete All Data", systemImage: "trash.fill")
                        .foregroundColor(.red)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Policy")
                        .font(.headline)
                    Text("Your privacy is important to us. All data is processed locally on your device unless explicitly shared.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func clearKeychainData() {
        // TODO: Implement keychain clearing
        print("Clearing keychain data...")
    }
    
    private func resetPrivacySettings() {
        analyticsEnabled = false
        crashReportsEnabled = false
        personalizationEnabled = true
        dataCollectionEnabled = false
        biometricAuthEnabled = true
    }
    
    private func exportPrivacyData() {
        // TODO: Implement privacy data export
        print("Exporting privacy data...")
    }
    
    private func deleteAllData() {
        // TODO: Implement data deletion with confirmation
        print("Deleting all data...")
    }
}

#Preview {
    NavigationView {
        PrivacySettingsView()
    }
}