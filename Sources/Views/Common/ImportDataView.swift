//
//  ImportDataView.swift
//  ClaudeCode
//
//  Import data view placeholder
//

import SwiftUI

struct ImportDataView: View {
    let coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.primary)
                
                Text("Import Data")
                    .font(Theme.title)
                    .foregroundColor(Theme.foreground)
                
                Text("Import functionality coming soon")
                    .font(Theme.body)
                    .foregroundColor(Theme.mutedForeground)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("Import")
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