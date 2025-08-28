//
//  ProjectSettingsView.swift
//  ClaudeCode
//
//  Placeholder view for project settings
//

import SwiftUI

struct ProjectSettingsView: View {
    let projectId: UUID
    @ObservedObject var coordinator: ProjectsCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Project Settings") {
                    Text("Project ID: \(projectId.uuidString)")
                    Text("Settings coming soon...")
                }
            }
            .navigationTitle("Project Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}