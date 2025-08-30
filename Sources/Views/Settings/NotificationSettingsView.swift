//
//  NotificationSettingsView.swift
//  ClaudeCode
//
//  Settings view for notification preferences
//

import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("notifications.enabled") private var notificationsEnabled = true
    @AppStorage("notifications.sounds") private var soundsEnabled = true
    @AppStorage("notifications.badges") private var badgesEnabled = true
    @AppStorage("notifications.criticalAlerts") private var criticalAlertsEnabled = false
    
    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .tint(Theme.primary)
                
                Toggle("Sounds", isOn: $soundsEnabled)
                    .disabled(!notificationsEnabled)
                    .tint(Theme.primary)
                
                Toggle("Badges", isOn: $badgesEnabled)
                    .disabled(!notificationsEnabled)
                    .tint(Theme.primary)
            }
            
            Section("Alert Types") {
                Toggle("Critical Alerts", isOn: $criticalAlertsEnabled)
                    .disabled(!notificationsEnabled)
                    .tint(Theme.primary)
                
                Text("Critical alerts will bypass Do Not Disturb and silent mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Notification Categories") {
                NotificationCategoryRow(title: "Messages", isEnabled: .constant(true))
                NotificationCategoryRow(title: "Tool Completions", isEnabled: .constant(true))
                NotificationCategoryRow(title: "SSH Connections", isEnabled: .constant(false))
                NotificationCategoryRow(title: "Monitoring Alerts", isEnabled: .constant(true))
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationCategoryRow: View {
    let title: String
    @Binding var isEnabled: Bool
    
    var body: some View {
        Toggle(title, isOn: $isEnabled)
            .tint(Theme.primary)
    }
}

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
}