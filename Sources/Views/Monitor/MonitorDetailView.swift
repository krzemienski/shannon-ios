//
//  MonitorDetailView.swift
//  ClaudeCode
//
//  Detailed monitoring view
//

import SwiftUI

struct MonitorDetailView: View {
    let monitorType: MonitorType
    @EnvironmentObject var coordinator: MonitorCoordinator
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(monitorType.title)
                    .font(Theme.title)
                    .foregroundColor(Theme.foreground)
                
                Text("Detailed monitoring data for \(monitorType.rawValue)")
                    .font(Theme.body)
                    .foregroundColor(Theme.mutedForeground)
                
                // Placeholder for charts and metrics
                RoundedRectangle(cornerRadius: Theme.smallRadius)
                    .fill(Theme.card)
                    .frame(height: 200)
                    .overlay(
                        Text("Chart Placeholder")
                            .foregroundColor(Theme.mutedForeground)
                    )
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(monitorType.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum MonitorType: String {
    case cpu = "cpu"
    case memory = "memory"
    case network = "network"
    case disk = "disk"
    case ssh = "ssh"
    
    var title: String {
        switch self {
        case .cpu: return "CPU Usage"
        case .memory: return "Memory Usage"
        case .network: return "Network Activity"
        case .disk: return "Disk Usage"
        case .ssh: return "SSH Connections"
        }
    }
}