//
//  ChatView.swift
//  ClaudeCode
//
//  Main chat conversation view
//

import SwiftUI

struct ChatView: View {
    let session: ChatSession
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var showingToolTimeline = false
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Messages list with optimized scrolling
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: ThemeSpacing.md) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageView(message: message)
                                    .id(message.id)
                                    .onAppear {
                                        // Preload images when message appears
                                        viewModel.preloadMessageContent(message)
                                    }
                                    .onDisappear {
                                        // Clean up resources when message disappears
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
                        // Only scroll to bottom for new messages, not for deletions
                        if newCount > oldCount {
                            // Debounce scrolling to prevent excessive animations
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                
                // Input area
                VStack(spacing: 0) {
                    // Tool timeline button
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
                                        .font(Theme.Typography.caption)
                                    Image(systemName: "chevron.right")
                                }
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.primary)
                                .padding(.horizontal, ThemeSpacing.md)
                                .padding(.vertical, ThemeSpacing.sm)
                            }
                        }
                        .background(Theme.primary.opacity(0.1))
                    }
                    
                    Divider()
                        .background(Theme.border)
                    
                    // Message input
                    HStack(spacing: ThemeSpacing.sm) {
                        // Attach button
                        Button {
                            // Handle attachment
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.muted)
                        }
                        
                        // Text field
                        TextField("Message Claude...", text: $messageText, axis: .vertical)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.foreground)
                            .tint(Theme.primary)
                            .lineLimit(1...6)
                            .focused($isInputFocused)
                            .onSubmit {
                                sendMessage()
                            }
                        
                        // Send button
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
                .background(Theme.card)
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: ThemeSpacing.xs) {
                    // Token usage
                    if viewModel.tokenUsage > 0 {
                        Label("\(viewModel.tokenUsage)", systemImage: "cube")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.mutedForeground)
                    }
                    
                    // Options menu
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
    let message: ChatMessageUI
    
    var body: some View {
        HStack(alignment: .top, spacing: ThemeSpacing.md) {
            // Avatar
            if message.role == .user {
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
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: ThemeSpacing.xs) {
                // Message content
                Text(message.content)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.foreground)
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
                
                // Timestamp
                Text(message.formattedTime)
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.mutedForeground)
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
        withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
                dots = (dots + 1) % 3
            }
        }
    }
}

// MARK: - Chat View Model

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessageUI] = ChatMessageUI.mockData
    @Published var isLoading = false
    @Published var tokenUsage = 0
    @Published var toolUsages: [ToolUsage] = []
    
    var hasToolUsage: Bool {
        !toolUsages.isEmpty
    }
    
    var toolUsageCount: Int {
        toolUsages.count
    }
    
    func sendMessage(_ text: String) {
        let userMessage = ChatMessageUI(
            role: .user,
            content: text,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        isLoading = true
        
        // Simulate response
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            let aiMessage = ChatMessageUI(
                role: .assistant,
                content: "I understand you want help with: \(text). Let me assist you with that.",
                timestamp: Date()
            )
            self?.messages.append(aiMessage)
            self?.isLoading = false
            self?.tokenUsage += Int.random(in: 100...500)
        }
    }
}

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
    
    static let mockData: [ChatMessageUI] = [
        ChatMessageUI(
            role: .assistant,
            content: "Hello! I'm Claude Code. How can I help you with your iOS development today?",
            timestamp: Date().addingTimeInterval(-300)
        ),
        ChatMessageUI(
            role: .user,
            content: "Can you help me create a custom SwiftUI button with a gradient background?",
            timestamp: Date().addingTimeInterval(-240)
        ),
        ChatMessageUI(
            role: .assistant,
            content: "I'll help you create a custom SwiftUI button with a gradient background. Here's a complete implementation with customizable parameters and smooth animations.",
            timestamp: Date().addingTimeInterval(-180)
        )
    ]
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
        ChatView(session: ChatSession.mockData[0])
            .environmentObject(AppState())
    }
    .preferredColorScheme(.dark)
}