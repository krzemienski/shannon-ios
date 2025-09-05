// MVP: Simplified chat settings view to avoid compilation errors
import SwiftUI

struct ChatSettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var streamResponses = true
    @State private var messageLimit = 100.0
    @State private var autoSave = true
    @State private var showTimestamps = true
    @State private var enableMarkdown = true
    @State private var contextLength = "Standard"
    
    var body: some View {
        Form {
            Section("Response Settings") {
                Toggle("Stream Responses", isOn: $streamResponses)
                
                Picker("Context Length", selection: $contextLength) {
                    Text("Short").tag("Short")
                    Text("Standard").tag("Standard")
                    Text("Long").tag("Long")
                }
            }
            
            Section("Message Display") {
                Toggle("Show Timestamps", isOn: $showTimestamps)
                Toggle("Enable Markdown", isOn: $enableMarkdown)
                
                HStack {
                    Text("Message History Limit")
                    Spacer()
                    Text("\(Int(messageLimit))")
                        .foregroundColor(Theme.mutedForeground)
                }
                Slider(value: $messageLimit, in: 50...500, step: 50)
            }
            
            Section("Auto-Save") {
                Toggle("Auto-Save Conversations", isOn: $autoSave)
                
                if autoSave {
                    Text("Conversations are automatically saved every 30 seconds")
                        .font(.caption)
                        .foregroundColor(Theme.mutedForeground)
                }
            }
            
            Section("Shortcuts") {
                HStack {
                    Text("Send Message")
                    Spacer()
                    Text("⌘ + Return")
                        .font(.caption)
                        .foregroundColor(Theme.mutedForeground)
                }
                
                HStack {
                    Text("New Conversation")
                    Spacer()
                    Text("⌘ + N")
                        .font(.caption)
                        .foregroundColor(Theme.mutedForeground)
                }
                
                HStack {
                    Text("Clear Chat")
                    Spacer()
                    Text("⌘ + K")
                        .font(.caption)
                        .foregroundColor(Theme.mutedForeground)
                }
            }
        }
        .navigationTitle("Chat Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}