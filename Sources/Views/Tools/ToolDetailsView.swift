//
//  ToolDetailsView.swift
//  ClaudeCode
//
//  Placeholder view for tool details
//

import SwiftUI

struct ToolDetailsView: View {
    let toolId: String
    @ObservedObject var coordinator: ToolsCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Tool Details")
                    .font(.largeTitle)
                    .padding()
                Text("Tool ID: \(toolId)")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .navigationTitle("Tool Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}