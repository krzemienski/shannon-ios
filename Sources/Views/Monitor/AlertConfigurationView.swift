//
//  AlertConfigurationView.swift
//  ClaudeCode
//
//  Configure monitoring alerts
//

import SwiftUI

struct AlertConfigurationView: View {
    let metricType: AlertMetricType
    @EnvironmentObject var coordinator: MonitorCoordinator
    @State private var isEnabled = true
    @State private var threshold = 80.0
    @State private var duration = 60.0
    @State private var notificationType = NotificationType.push
    
    var body: some View {
        Form {
            Section("Alert Settings") {
                Toggle("Enable Alert", isOn: $isEnabled)
                
                if isEnabled {
                    HStack {
                        Text("Threshold")
                        Spacer()
                        Text("\(Int(threshold))%")
                            .foregroundColor(Theme.mutedForeground)
                    }
                    Slider(value: $threshold, in: 50...100, step: 5)
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(Int(duration))s")
                            .foregroundColor(Theme.mutedForeground)
                    }
                    Slider(value: $duration, in: 10...300, step: 10)
                }
            }
            
            Section("Notification") {
                Picker("Type", selection: $notificationType) {
                    ForEach(NotificationType.allCases, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
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
        .navigationTitle("\(metricType.title) Alert")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func saveConfiguration() {
        // TODO: Save alert configuration
        print("Saving alert configuration for \(metricType.rawValue)")
    }
}

// Note: AlertMetricType is now defined in Models/ViewModels.swift

enum NotificationType: CaseIterable {
    case push
    case email
    case sms
    case none
    
    var title: String {
        switch self {
        case .push: return "Push Notification"
        case .email: return "Email"
        case .sms: return "SMS"
        case .none: return "None"
        }
    }
}