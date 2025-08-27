//
//  SettingsSectionView.swift
//  ClaudeCode
//
//  Settings section detail view
//

import SwiftUI

struct SettingsSectionView: View {
    let section: SettingsSectionType
    @EnvironmentObject var coordinator: SettingsCoordinator
    
    var body: some View {
        Form {
            switch section {
            case .general:
                generalSettings
            case .appearance:
                appearanceSettings
            case .api:
                apiSettings
            case .ssh:
                sshSettings
            case .data:
                dataSettings
            case .notifications:
                notificationSettings
            case .privacy:
                privacySettings
            case .about:
                aboutSection
            }
        }
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private var generalSettings: some View {
        Section("General") {
            Toggle("Enable Analytics", isOn: .constant(true))
            Toggle("Background Refresh", isOn: .constant(true))
        }
    }
    
    @ViewBuilder
    private var appearanceSettings: some View {
        Section("Appearance") {
            Picker("Theme", selection: .constant("Dark")) {
                Text("Light").tag("Light")
                Text("Dark").tag("Dark")
                Text("System").tag("System")
            }
        }
    }
    
    @ViewBuilder
    private var apiSettings: some View {
        Section("API") {
            Text("API Configuration")
        }
    }
    
    @ViewBuilder
    private var sshSettings: some View {
        Section("SSH") {
            Text("SSH Configuration")
        }
    }
    
    @ViewBuilder
    private var dataSettings: some View {
        Section("Data") {
            Text("Data Management")
        }
    }
    
    @ViewBuilder
    private var notificationSettings: some View {
        Section("Notifications") {
            Toggle("Push Notifications", isOn: .constant(true))
        }
    }
    
    @ViewBuilder
    private var privacySettings: some View {
        Section("Privacy") {
            Toggle("Share Analytics", isOn: .constant(false))
        }
    }
    
    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(Theme.mutedForeground)
            }
        }
    }
}

enum SettingsSectionType: String, CaseIterable {
    case general
    case appearance
    case api
    case ssh
    case data
    case notifications
    case privacy
    case about
    
    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .api: return "API"
        case .ssh: return "SSH"
        case .data: return "Data"
        case .notifications: return "Notifications"
        case .privacy: return "Privacy"
        case .about: return "About"
        }
    }
}