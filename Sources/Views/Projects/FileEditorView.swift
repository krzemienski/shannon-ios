//
//  FileEditorView.swift
//  ClaudeCode
//
//  File editor view for project files
//

import SwiftUI

struct FileEditorView: View {
    let projectId: String
    let filePath: String
    @EnvironmentObject var coordinator: ProjectsCoordinator
    @State private var fileContent = ""
    @State private var isEditing = false
    
    var body: some View {
        VStack {
            ScrollView {
                TextEditor(text: $fileContent)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Theme.foreground)
                    .disabled(!isEditing)
                    .scrollContentBackground(.hidden)
                    .background(Theme.card)
                    .cornerRadius(Theme.smallRadius)
                    .padding()
            }
        }
        .navigationTitle(URL(fileURLWithPath: filePath).lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                    if !isEditing {
                        // TODO: Save file
                    }
                }
            }
        }
        .onAppear {
            loadFile()
        }
    }
    
    private func loadFile() {
        // TODO: Load file from project
        fileContent = "// File: \(filePath)\n// Project: \(projectId)\n\n// File content will be loaded here"
    }
}