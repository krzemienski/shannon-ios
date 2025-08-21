//
//  ChatListView.swift
//  ClaudeCode
//
//  List of chat conversations
//

import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var showingNewChat = false
    @State private var chats: [ChatSession] = ChatSession.mockData
    
    var filteredChats: [ChatSession] {
        if searchText.isEmpty {
            return chats
        }
        return chats.filter { 
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.lastMessage.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            if chats.isEmpty {
                EmptyStateView(
                    icon: "message.fill",
                    title: "No Conversations",
                    message: "Start a new chat to begin using Claude Code",
                    action: ("New Chat", { showingNewChat = true })
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: ThemeSpacing.sm) {
                        ForEach(filteredChats) { chat in
                            NavigationLink(destination: ChatView(session: chat)) {
                                ChatRowView(chat: chat)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, ThemeSpacing.sm)
                }
                .searchable(text: $searchText, prompt: "Search conversations")
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewChat = true
                } label: {
                    Image(systemName: "plus")
                }
                .tint(Theme.primary)
            }
        }
        .sheet(isPresented: $showingNewChat) {
            NewChatView { newChat in
                chats.insert(newChat, at: 0)
            }
        }
    }
}

// MARK: - Chat Row View

struct ChatRowView: View {
    let chat: ChatSession
    
    var body: some View {
        HStack(spacing: ThemeSpacing.md) {
            // Chat icon
            Image(systemName: chat.icon)
                .font(.system(size: 24))
                .foregroundColor(Theme.primary)
                .frame(width: 40, height: 40)
                .background(Theme.primary.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.sm)
            
            // Chat details
            VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                HStack {
                    Text(chat.title)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.foreground)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(chat.formattedDate)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.mutedForeground)
                }
                
                Text(chat.lastMessage)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.mutedForeground)
                    .lineLimit(2)
                
                // Tags
                HStack(spacing: ThemeSpacing.xs) {
                    ForEach(chat.tags, id: \.self) { tag in
                        Text(tag)
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.primary)
                            .padding(.horizontal, ThemeSpacing.xs)
                            .padding(.vertical, 2)
                            .background(Theme.primary.opacity(0.1))
                            .cornerRadius(Theme.CornerRadius.sm)
                    }
                }
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(Theme.muted)
        }
        .padding(ThemeSpacing.md)
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Chat Session Model

struct ChatSession: Identifiable {
    let id = UUID().uuidString
    let title: String
    let lastMessage: String
    let timestamp: Date
    let icon: String
    let tags: [String]
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    static let mockData: [ChatSession] = [
        ChatSession(
            title: "SwiftUI Layout Help",
            lastMessage: "I've created a responsive grid layout that adapts to different screen sizes...",
            timestamp: Date().addingTimeInterval(-3600),
            icon: "square.grid.2x2",
            tags: ["SwiftUI", "Layout"]
        ),
        ChatSession(
            title: "API Integration",
            lastMessage: "The URLSession implementation with async/await is working perfectly...",
            timestamp: Date().addingTimeInterval(-7200),
            icon: "network",
            tags: ["Networking", "Async"]
        ),
        ChatSession(
            title: "Core Data Setup",
            lastMessage: "I've set up the Core Data stack with the entities you specified...",
            timestamp: Date().addingTimeInterval(-86400),
            icon: "cylinder.split.1x2",
            tags: ["CoreData", "Database"]
        )
    ]
}

// MARK: - New Chat View

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var initialMessage = ""
    @State private var selectedModel = "claude-3-5-haiku-20241022"
    
    let onSave: (ChatSession) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: ThemeSpacing.lg) {
                        CustomTextField(
                            title: "Chat Title",
                            text: $title,
                            placeholder: "Enter a title for this chat",
                            icon: "text.cursor"
                        )
                        
                        CustomTextEditor(
                            title: "Initial Message",
                            text: $initialMessage,
                            placeholder: "What would you like to work on?",
                            minHeight: 150
                        )
                        
                        // Model selection
                        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                            Text("Model")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.mutedForeground)
                            
                            Picker("Model", selection: $selectedModel) {
                                Text("Claude 3.5 Haiku").tag("claude-3-5-haiku-20241022")
                                Text("Claude 3.5 Sonnet").tag("claude-3-5-sonnet-20241022")
                                Text("Claude 3 Opus").tag("claude-3-opus-20240229")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(Theme.foreground)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let newChat = ChatSession(
                            title: title.isEmpty ? "New Chat" : title,
                            lastMessage: initialMessage,
                            timestamp: Date(),
                            icon: "message.fill",
                            tags: []
                        )
                        onSave(newChat)
                        dismiss()
                    }
                    .tint(Theme.primary)
                    .disabled(initialMessage.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatListView()
            .environmentObject(AppState())
    }
    .preferredColorScheme(.dark)
}