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
                Text(monitorType.rawValue)  // Use rawValue since MonitorType is defined in MonitorCoordinator
                    .font(Theme.Typography.titleFont)
                    .foregroundColor(Theme.foreground)
                
                Text("Detailed monitoring data for \(monitorType.rawValue)")
                    .font(Theme.Typography.bodyFont)
                    .foregroundColor(Theme.mutedForeground)
                
                // Placeholder for charts and metrics
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
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
        .navigationTitle(monitorType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}