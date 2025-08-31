//
//  SettingsView.swift
//  ClaudeCode
//
//  Main settings navigation hub
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            List {
                // Quick Settings Section
                Section {
                    NavigationLink {
                        APISettingsView()
                    } label: {
                        SettingsRowView(
                            icon: "network",
                            title: "API Configuration",
                            subtitle: settingsStore.baseURL,
                            iconColor: Theme.primary
                        )
                    }
                    
                    NavigationLink {
                        ChatSettingsView()
                    } label: {
                        SettingsRowView(
                            icon: "bubble.left.and.bubble.right",
                            title: "Chat Settings",
                            subtitle: settingsStore.selectedModel,
                            iconColor: Theme.accent
                        )
                    }
                    
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingsRowView(
                            icon: "paintbrush",
                            title: "Appearance",
                            subtitle: settingsStore.theme.displayName,
                            iconColor: Theme.secondary
                        )
                    }
                }
                .listRowBackground(Theme.card)
                
                // Advanced Settings Section
                Section {
                    NavigationLink {
                        SSHSettingsView()
                    } label: {
                        SettingsRowView(
                            icon: "terminal",
                            title: "SSH Configuration",
                            subtitle: settingsStore.sshEnabled ? "Enabled" : "Disabled",
                            iconColor: Theme.warning
                        )
                    }
                    
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRowView(
                            icon: "bell",
                            title: "Notifications",
                            subtitle: "Manage alerts",
                            iconColor: Theme.destructive
                        )
                    }
                    
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        SettingsRowView(
                            icon: "hand.raised",
                            title: "Privacy & Security",
                            subtitle: "Data protection",
                            iconColor: Theme.success
                        )
                    }
                } header: {
                    Text("ADVANCED")
                        .font(Theme.Typography.footnoteFont)
                        .foregroundColor(Theme.mutedForeground)
                }
                .listRowBackground(Theme.card)
                
                // Developer Section
                if settingsStore.debugMode {
                    Section {
                        NavigationLink {
                            DeveloperSettingsView()
                        } label: {
                            SettingsRowView(
                                icon: "hammer",
                                title: "Developer Options",
                                subtitle: "Debug tools",
                                iconColor: Theme.muted
                            )
                        }
                    } header: {
                        Text("DEVELOPER")
                            .font(Theme.Typography.footnoteFont)
                            .foregroundColor(Theme.mutedForeground)
                    }
                    .listRowBackground(Theme.card)
                }
                
                // About Section
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsRowView(
                            icon: "info.circle",
                            title: "About",
                            subtitle: "Version 1.0.0",
                            iconColor: Theme.primary
                        )
                    }
                    
                    Link(destination: URL(string: "https://claude.ai/help")!) {
                        SettingsRowView(
                            icon: "questionmark.circle",
                            title: "Help & Support",
                            subtitle: "Get assistance",
                            iconColor: Theme.accent,
                            showDisclosure: false
                        )
                    }
                } header: {
                    Text("INFORMATION")
                        .font(Theme.Typography.footnoteFont)
                        .foregroundColor(Theme.mutedForeground)
                }
                .listRowBackground(Theme.card)
            }
            .searchable(text: $searchText, prompt: "Search settings")
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Settings Row View

struct SettingsRowView: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    var showDisclosure: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.1))
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.bodyFont)
                    .foregroundColor(Theme.foreground)
                
                Text(subtitle)
                    .font(Theme.Typography.captionFont)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            Spacer()
            
            if showDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.muted)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Placeholder Views (to be implemented)

struct SSHSettingsView: View {
    var body: some View {
        Text("SSH Settings")
            .navigationTitle("SSH Configuration")
    }
}

struct DeveloperSettingsView: View {
    var body: some View {
        BackendTestView()
    }
}

// Note: NotificationSettingsView, PrivacySettingsView, and AboutView
// are implemented in their own separate files

#Preview {
    SettingsView()
        .environmentObject(SettingsStore())
        .preferredColorScheme(.dark)
}