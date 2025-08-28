//
//  ToolExecutionView.swift
//  ClaudeCode
//
//  Tool execution view placeholder
//

import SwiftUI

struct ToolExecutionView: View {
    let toolId: String
    let executionId: String
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Tool Execution")
                    .font(.largeTitle)
                    .padding()
                
                Text("Tool ID: \(toolId)")
                    .font(.headline)
                
                Text("Execution ID: \(executionId)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Tool execution interface coming soon...")
                    .foregroundColor(.secondary)
                    .italic()
                
                Spacer()
            }
            .navigationTitle("Execute Tool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ToolExecutionView(toolId: "test-tool", executionId: "exec-123")
        .environmentObject(AppCoordinator())
}