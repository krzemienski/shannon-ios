//
//  MonitorSettingsView.swift
//  ClaudeCode
//
//  Monitor settings view
//

import SwiftUI

struct MonitorSettingsView: View {
    @EnvironmentObject var coordinator: MonitorCoordinator
    @State private var refreshInterval = 5.0
    @State private var enableAlerts = true
    @State private var cpuThreshold = 80.0
    @State private var memoryThreshold = 90.0
    
    var body: some View {
        Form {
            Section("Update Settings") {
                HStack {
                    Text("Refresh Interval")
                    Spacer()
                    Text("\(Int(refreshInterval))s")
                        .foregroundColor(Theme.mutedForeground)
                }
                Slider(value: $refreshInterval, in: 1...60, step: 1)
            }
            
            Section("Alerts") {
                Toggle("Enable Alerts", isOn: $enableAlerts)
                
                if enableAlerts {
                    HStack {
                        Text("CPU Threshold")
                        Spacer()
                        Text("\(Int(cpuThreshold))%")
                            .foregroundColor(Theme.mutedForeground)
                    }
                    Slider(value: $cpuThreshold, in: 50...100, step: 5)
                    
                    HStack {
                        Text("Memory Threshold")
                        Spacer()
                        Text("\(Int(memoryThreshold))%")
                            .foregroundColor(Theme.mutedForeground)
                    }
                    Slider(value: $memoryThreshold, in: 50...100, step: 5)
                }
            }
        }
        .navigationTitle("Monitor Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}