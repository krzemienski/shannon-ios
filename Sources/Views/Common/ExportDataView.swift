//
//  ExportDataView.swift
//  ClaudeCode
//
//  Export data view placeholder
//

import SwiftUI

struct ExportDataView: View {
    let coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.primary)
                
                Text("Export Data")
                    .font(Theme.Typography.titleFont)
                    .foregroundColor(Theme.foreground)
                
                Text("Export functionality coming soon")
                    .font(Theme.Typography.bodyFont)
                    .foregroundColor(Theme.mutedForeground)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}