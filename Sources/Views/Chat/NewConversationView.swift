//
//  NewConversationView.swift
//  ClaudeCode
//
//  Placeholder view for new conversation creation
//

import SwiftUI

struct NewConversationView: View {
    var coordinator: ChatCoordinator?
    @Environment(\.dismiss) private var dismiss
    @State private var conversationTitle = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("New Conversation") {
                    TextField("Title", text: $conversationTitle)
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        dismiss()
                    }
                    .disabled(conversationTitle.isEmpty)
                }
            }
        }
    }
}