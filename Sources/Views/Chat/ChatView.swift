//
//  ChatView.swift
//  ClaudeCode
//
//  Main chat conversation view
//

import SwiftUI
import Combine

// This file now uses the real ChatViewModel from Sources/ViewModels/ChatViewModel.swift

struct ChatView: View {
    let session: ChatSession
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showingToolTimeline = false
    
    init(session: ChatSession) {
        self.session = session
        let container = DependencyContainer.shared
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversationId: session.id,
            chatStore: container.chatStore,
            apiClient: container.apiClient,
            appState: container.appState
        ))
    }
    
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
                    
                    if viewModel.isLoading || viewModel.isStreaming {
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
        // Tool timeline can be added in future iteration
        EmptyView()
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
            // Connection status indicator
            Circle()
                .fill(viewModel.connectionStatus.color)
                .frame(width: 8, height: 8)
            
            Menu {
                Button {
                    viewModel.clearConversation()
                } label: {
                    Label("Clear Chat", systemImage: "trash")
                }
                
                Button {
                    viewModel.startNewConversation()
                } label: {
                    Label("New Chat", systemImage: "plus")
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
        .onAppear {
            // Subscribe to WebSocket updates for real-time streaming
            viewModel.subscribeToWebSocketUpdates()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
            Button("Retry") {
                viewModel.retry()
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred")
        }
        // Tool timeline will be added in future iteration
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        viewModel.inputText = messageText
        messageText = ""
        
        viewModel.sendMessage()
    }
}

// MARK: - Message View

struct ChatMessageView: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top, spacing: ThemeSpacing.md) {
            // Avatar
            if message.role == .user {
                Spacer()
            } else if message.role != .error {
                Image(systemName: message.role == .system ? "gear" : "brain")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.primary)
                    .frame(width: 32, height: 32)
                    .background(Theme.primary.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.full)
            }
            
            // Message bubble
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: ThemeSpacing.xs) {
                // Error messages
                if message.role == .error {
                    HStack(spacing: ThemeSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(message.content)
                            .font(Theme.Typography.bodyFont)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, ThemeSpacing.md)
                    .padding(.vertical, ThemeSpacing.sm)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.md)
                } else {
                    // Regular message content with markdown support
                    if message.isStreaming && !message.content.isEmpty {
                        // Streaming message with animated cursor
                        HStack(spacing: 0) {
                            Text(message.content)
                                .font(Theme.Typography.bodyFont)
                                .foregroundColor(message.role == .user ? .white : Theme.foreground)
                            
                            if message.isStreaming {
                                BlinkingCursor()
                            }
                        }
                        .padding(.horizontal, ThemeSpacing.md)
                        .padding(.vertical, ThemeSpacing.sm)
                        .background(
                            message.role == .user ? Theme.primary : Theme.card
                        )
                        .cornerRadius(Theme.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .stroke(
                                    message.role == .user ? Color.clear : Theme.border,
                                    lineWidth: 1
                                )
                        )
                    } else {
                        Text(message.content)
                            .font(Theme.Typography.bodyFont)
                            .foregroundColor(message.role == .user ? .white : Theme.foreground)
                            .padding(.horizontal, ThemeSpacing.md)
                            .padding(.vertical, ThemeSpacing.sm)
                            .background(
                                message.role == .user ? Theme.primary : Theme.card
                            )
                            .cornerRadius(Theme.CornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .stroke(
                                        message.role == .user ? Color.clear : Theme.border,
                                        lineWidth: 1
                                    )
                            )
                    }
                }
                
                // Token usage for assistant messages
                if let usage = message.metadata?.usage,
                   message.role == .assistant {
                    HStack(spacing: ThemeSpacing.xs) {
                        Image(systemName: "cube")
                            .font(.system(size: 10))
                        Text("\(usage.totalTokens) tokens")
                            .font(Theme.Typography.caption2Font)
                    }
                    .foregroundColor(Theme.mutedForeground)
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)
            
            // Avatar spacer
            if message.role == .user {
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.foreground)
                    .frame(width: 32, height: 32)
                    .background(Theme.muted)
                    .cornerRadius(Theme.CornerRadius.full)
            } else if message.role != .error {
                Spacer()
            }
        }
    }
}

// MARK: - Blinking Cursor

struct BlinkingCursor: View {
    @State private var isVisible = true
    
    var body: some View {
        Text("▊")
            .font(Theme.Typography.bodyFont)
            .foregroundColor(Theme.primary)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isVisible.toggle()
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

// Models and types are now imported from ChatModels.swift and ChatViewModel.swift

// Tool usage and timeline functionality will be added in future iteration

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