//
//  CodeEditorView.swift
//  ClaudeCode
//
//  Code editor view placeholder
//

import SwiftUI

struct CodeEditorView: View {
    let filePath: String
    @State private var code: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    TextEditor(text: $code)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Theme.foreground)
                        .scrollContentBackground(.hidden)
                        .background(Theme.card)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("Code Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadFile()
            }
        }
    }
    
    private func loadFile() {
        // Load file content
        if let content = try? String(contentsOfFile: filePath) {
            code = content
        } else {
            code = "// File: \(filePath)\n// Unable to load file content"
        }
    }
}