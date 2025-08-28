//
//  NewProjectView.swift
//  ClaudeCode
//
//  Placeholder view for new project creation
//

import SwiftUI

struct NewProjectView: View {
    let onSave: (Project) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var projectName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("New Project") {
                    TextField("Project Name", text: $projectName)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let project = Project(
                            name: projectName,
                            path: "/path/to/\(projectName)",
                            type: .general,
                            description: nil,
                            isActive: true,
                            createdAt: Date()
                        )
                        onSave(project)
                        dismiss()
                    }
                    .disabled(projectName.isEmpty)
                }
            }
        }
    }
}