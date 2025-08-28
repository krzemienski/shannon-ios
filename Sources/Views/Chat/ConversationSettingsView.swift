//
//  ConversationSettingsView.swift
//  ClaudeCode
//
//  Placeholder view for conversation settings
//

import SwiftUI

struct ConversationSettingsView: View {
    let conversationId: UUID
    @ObservedObject var coordinator: ChatCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Conversation Settings") {
                    Text("Conversation ID: \(conversationId.uuidString)")
                    Text("Settings coming soon...")
                }
            }
            .navigationTitle("Conversation Settings")
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