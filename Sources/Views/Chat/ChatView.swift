//
//  ChatView.swift
//  ClaudeCode
//
//  Main chat conversation view
//

import SwiftUI
import Combine

// Temporary simple chat view model for compilation
class SimpleChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var streamingText = ""
    @Published var currentTool: String?
    @Published var toolExecutions: [ToolExecution] = []
    @Published var tokenUsage = 0
    @Published var toolUsages: [ToolUsage] = []
    
    var hasToolUsage: Bool {
        !toolUsages.isEmpty
    }
    
    var toolUsageCount: Int {
        toolUsages.count
    }
    
    init() {
        // Initialize with empty state
    }
    
    func sendMessage(_ text: String) {
        // Implementation pending
    }
    
    func preloadMessageContent(_ message: ChatMessage) {
        // Implementation pending
    }
    
    func cleanupMessageResources(_ message: ChatMessage) {
        // Implementation pending
    }
    
    func clearChat() {
        messages.removeAll()
    }
    
    func cancelCurrentRequest() {
        isLoading = false
    }
    
    func retryLastMessage() {
        // Implementation pending
    }
}

struct ChatView: View {
    let session: ChatSession
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SimpleChatViewModel()
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showingToolTimeline = false
    
    // MARK: - View Components
    
    @ViewBuilder
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: ThemeSpacing.md) {
                    ForEach(viewModel.messages) { message in
                        ChatMessageView(message: message)
                            .id(message.id)
                            .onAppear {
                                viewModel.preloadMessageContent(message)
                            }
                            .onDisappear {
                                viewModel.cleanupMessageResources(message)
                            }
                    }
                    
                    if viewModel.isLoading {
                        ThinkingIndicator()
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                if newCount > oldCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    @ViewBuilder
    private var toolTimelineButton: some View {
        if viewModel.hasToolUsage {
            HStack {
                Button {
                    showingToolTimeline = true
                } label: {
                    HStack(spacing: ThemeSpacing.xs) {
                        Image(systemName: "timeline.selection")
                        Text("View Tool Timeline")
                        Spacer()
                        Text("\(viewModel.toolUsageCount) tools")
                            .font(Theme.Typography.captionFont)
                        Image(systemName: "chevron.right")
                    }
                    .font(Theme.Typography.footnoteFont)
                    .foregroundColor(Theme.primary)
                    .padding(.horizontal, ThemeSpacing.md)
                    .padding(.vertical, ThemeSpacing.sm)
                }
            }
            .background(Theme.primary.opacity(0.1))
        }
    }
    
    @ViewBuilder
    private var messageInputArea: some View {
        HStack(spacing: ThemeSpacing.sm) {
            Button {
                // Handle attachment
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.muted)
            }
            
            TextField("Message Claude...", text: $messageText, axis: .vertical)
                .font(Theme.Typography.bodyFont)
                .foregroundColor(Theme.foreground)
                .tint(Theme.primary)
                .lineLimit(1...6)
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(messageText.isEmpty ? Theme.muted : Theme.primary)
            }
            .disabled(messageText.isEmpty || viewModel.isLoading)
        }
        .padding(.horizontal, ThemeSpacing.md)
        .padding(.vertical, ThemeSpacing.sm)
    }
    
    @ViewBuilder
    private var inputSection: some View {
        VStack(spacing: 0) {
            toolTimelineButton
            
            Divider()
                .background(Theme.border)
            
            messageInputArea
        }
        .background(Theme.card)
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        HStack(spacing: ThemeSpacing.xs) {
            if viewModel.tokenUsage > 0 {
                Label("\(viewModel.tokenUsage)", systemImage: "cube")
                    .font(Theme.Typography.captionFont)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            Menu {
                Button {
                    // Clear chat
                } label: {
                    Label("Clear Chat", systemImage: "trash")
                }
                
                Button {
                    // Export chat
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(Theme.primary)
            }
        }
    }
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                messagesList
                inputSection
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                toolbarContent
            }
        }
        .sheet(isPresented: $showingToolTimeline) {
            ToolTimelineView(tools: viewModel.toolUsages)
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let text = messageText
        messageText = ""
        
        viewModel.sendMessage(text)
    }
}

// MARK: - Message View

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: ThemeSpacing.md) {
            // Avatar
            if message.role == "user" {
                Spacer()
            } else {
                Image(systemName: "brain")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.primary)
                    .frame(width: 32, height: 32)
                    .background(Theme.primary.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.full)
            }
            
            // Message bubble
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: ThemeSpacing.xs) {
                // Message content
                Text(message.content ?? "")
                    .font(Theme.Typography.bodyFont)
                    .foregroundColor(Theme.foreground)
                    .padding(.horizontal, ThemeSpacing.md)
                    .padding(.vertical, ThemeSpacing.sm)
                    .background(
                        message.role == "user" ? Theme.primary : Theme.card
                    )
                    .cornerRadius(Theme.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(
                                message.role == "user" ? Color.clear : Theme.border,
                                lineWidth: 1
                            )
                    )
                
                // Timestamp - MVP: Comment out for now
                // Text(message.formattedTime)
                //     .font(Theme.Typography.caption2Font)
                //     .foregroundColor(Theme.mutedForeground)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == "user" ? .trailing : .leading)
            
            // Avatar spacer
            if message.role == "user" {
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.foreground)
                    .frame(width: 32, height: 32)
                    .background(Theme.muted)
                    .cornerRadius(Theme.CornerRadius.full)
            } else {
                Spacer()
            }
        }
    }
}

// MARK: - Thinking Indicator

struct ThinkingIndicator: View {
    @State private var dots = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: ThemeSpacing.md) {
            Image(systemName: "brain")
                .font(.system(size: 20))
                .foregroundColor(Theme.primary)
                .frame(width: 32, height: 32)
                .background(Theme.primary.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.full)
            
            HStack(spacing: ThemeSpacing.xs) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Theme.primary)
                        .frame(width: 8, height: 8)
                        .opacity(dots == index ? 1 : 0.3)
                }
            }
            .padding(.horizontal, ThemeSpacing.md)
            .padding(.vertical, ThemeSpacing.sm)
            .background(Theme.card)
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .onAppear {
                animateDots()
            }
            
            Spacer()
        }
    }
    
    private func animateDots() {
        // MVP: Simplified animation
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                self.dots = (self.dots + 1) % 3
            }
        }
    }
}

// Note: Using the SimpleChatViewModel defined at the top of the file

// MARK: - Chat Message Model

struct ChatMessageUI: Identifiable {
    let id = UUID().uuidString
    let role: MessageRoleUI
    let content: String
    let timestamp: Date
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    enum MessageRoleUI {
        case user
        case assistant
        case system
    }
    
    // Removed mock data - now using real data from ChatViewModel
}

// MARK: - Tool Usage Model

struct ToolUsage: Identifiable {
    let id = UUID().uuidString
    let name: String
    let description: String
    let timestamp: Date
    let duration: TimeInterval
    let status: Status
    
    enum Status {
        case success
        case error
        case running
    }
}

#Preview {
    NavigationStack {
        ChatView(session: ChatSession(
            title: "Preview Chat",
            lastMessage: "This is a preview message",
            timestamp: Date(),
            icon: "message.fill",
            tags: ["Preview"]
        ))
            .environmentObject(AppState())
    }
    .preferredColorScheme(.dark)
}