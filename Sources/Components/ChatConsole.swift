//
//  ChatConsole.swift
//  ClaudeCode
//
//  Advanced chat console with tool execution display
//

import SwiftUI

// MARK: - Chat Console View

struct ChatConsoleView: View {
    @StateObject private var viewModel = ChatConsoleViewModel()
    @State private var inputText = ""
    @State private var showingTools = false
    @State private var selectedTool: ConsoleToolExecution?
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ConsoleHeader(
                status: viewModel.connectionStatus,
                model: viewModel.currentModel,
                showingTools: $showingTools
            )
            
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.messages) { message in
                            ConsoleMessageView(
                                message: message,
                                onToolTap: { tool in
                                    selectedTool = tool
                                }
                            )
                            .id(message.id)
                        }
                        
                        // Active tool executions
                        if !viewModel.activeTools.isEmpty {
                            ActiveToolsView(tools: viewModel.activeTools)
                                .id("active-tools")
                        }
                        
                        // Thinking indicator
                        if viewModel.isThinking {
                            ThinkingView()
                                .id("thinking")
                        }
                    }
                    .padding(.vertical, ThemeSpacing.md)
                }
                .background(Theme.background)
                .onChange(of: viewModel.messages.count) { _ in
                    withAnimation {
                        if viewModel.isThinking {
                            proxy.scrollTo("thinking", anchor: .bottom)
                        } else if !viewModel.activeTools.isEmpty {
                            proxy.scrollTo("active-tools", anchor: .bottom)
                        } else {
                            proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input area
            ConsoleInputArea(
                text: $inputText,
                isLoading: viewModel.isProcessing,
                onSend: {
                    viewModel.sendMessage(inputText)
                    inputText = ""
                },
                onAttach: {
                    // Handle attachment
                }
            )
            .focused($isInputFocused)
        }
        .sheet(isPresented: $showingTools) {
            ToolsPanelView(tools: viewModel.availableTools)
        }
        .sheet(item: $selectedTool) { tool in
            // Convert ConsoleToolExecution to PanelToolInfo for ToolDetailView
            let panelToolInfo = PanelToolInfo(
                name: tool.name,
                category: "Tool",
                icon: tool.icon,
                description: "Tool execution details",
                usage: tool.input ?? "No input",
                examples: [],
                lastUsed: Date()
            )
            ToolDetailView(tool: panelToolInfo)
        }
    }
}

// MARK: - Console Header

struct ConsoleHeader: View {
    let status: ConnectionStatus
    let model: String
    @Binding var showingTools: Bool
    
    var body: some View {
        HStack(spacing: ThemeSpacing.md) {
            // Status indicator
            HStack(spacing: ThemeSpacing.xs) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(Theme.Typography.captionFont)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            Spacer()
            
            // Model selector
            Text(model)
                .font(Theme.Typography.captionFont)
                .foregroundColor(Theme.primary)
                .padding(.horizontal, ThemeSpacing.sm)
                .padding(.vertical, 4)
                .background(Theme.primary.opacity(0.1))
                .cornerRadius(Theme.Radius.sm)
            
            // Tools button
            Button {
                showingTools = true
            } label: {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.primary)
            }
        }
        .padding(.horizontal, ThemeSpacing.md)
        .padding(.vertical, ThemeSpacing.sm)
        .background(Theme.card)
        .overlay(
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private var statusColor: Color {
        switch status {
        case .connected:
            return Theme.success
        case .connecting:
            return Theme.warning
        case .disconnected:
            return Theme.destructive
        }
    }
    
    private var statusText: String {
        switch status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        }
    }
}

// MARK: - Console Message View

struct ConsoleMessageView: View {
    let message: ConsoleMessage
    let onToolTap: (ConsoleToolExecution) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Message content
            HStack(alignment: .top, spacing: ThemeSpacing.md) {
                // Role indicator
                RoleIndicator(role: message.role)
                
                // Content
                VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                    // Text content
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(Theme.Typography.bodyFont)
                            .foregroundColor(Theme.foreground)
                            .textSelection(.enabled)
                    }
                    
                    // Tool executions
                    if !message.toolExecutions.isEmpty {
                        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                            ForEach(message.toolExecutions) { tool in
                                ToolExecutionCard(
                                    tool: tool,
                                    onTap: { onToolTap(tool) }
                                )
                            }
                        }
                    }
                    
                    // Timestamp
                    Text(message.formattedTime)
                        .font(Theme.Typography.caption2Font)
                        .foregroundColor(Theme.mutedForeground)
                }
                
                Spacer()
            }
            .padding(.horizontal, ThemeSpacing.md)
            .padding(.vertical, ThemeSpacing.sm)
            
            // Separator
            Rectangle()
                .fill(Theme.border.opacity(0.3))
                .frame(height: 1)
        }
    }
}

// MARK: - Role Indicator

struct RoleIndicator: View {
    let role: MessageRole
    
    var body: some View {
        Image(systemName: role.icon)
            .font(.system(size: 16))
            .foregroundColor(roleColor)
            .frame(width: 28, height: 28)
            .background(roleColor.opacity(0.1))
            .cornerRadius(Theme.Radius.sm)
    }
    
    private var roleColor: Color {
        switch role {
        case .user:
            return Theme.foreground
        case .assistant:
            return Theme.primary
        case .system:
            return Theme.info
        case .error:
            return Theme.destructive
        case .tool, .toolResponse:
            return Theme.secondary
        }
    }
}

// MARK: - Tool Execution Card

struct ToolExecutionCard: View {
    let tool: ConsoleToolExecution
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ThemeSpacing.sm) {
                // Icon
                Image(systemName: tool.icon)
                    .font(.system(size: 14))
                    .foregroundColor(statusColor)
                    .frame(width: 24, height: 24)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(Theme.Radius.xs)
                
                // Name
                Text(tool.name)
                    .font(Theme.Typography.captionFont)
                    .foregroundColor(Theme.foreground)
                
                // Status
                switch tool.status {
                case .running:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                        .scaleEffect(0.6)
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.success)
                case .error:
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.destructive)
                default:
                    EmptyView()
                }
                
                Spacer()
                
                // Duration
                if let duration = tool.duration {
                    Text(formatDuration(duration))
                        .font(Theme.Typography.caption2Font)
                        .foregroundColor(Theme.mutedForeground)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.mutedForeground)
            }
            .padding(.horizontal, ThemeSpacing.sm)
            .padding(.vertical, ThemeSpacing.xs)
            .background(Theme.card)
            .cornerRadius(Theme.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(Theme.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusColor: Color {
        switch tool.status {
        case .idle:
            return Theme.mutedForeground
        case .running:
            return Theme.primary
        case .success:
            return Theme.success
        case .error:
            return Theme.destructive
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return "\(Int(duration * 1000))ms"
        } else {
            return String(format: "%.1fs", duration)
        }
    }
}

// MARK: - Active Tools View

struct ActiveToolsView: View {
    let tools: [ConsoleToolExecution]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
            Text("Executing tools...")
                .font(Theme.Typography.captionFont)
                .foregroundColor(Theme.mutedForeground)
            
            ForEach(tools) { tool in
                HStack(spacing: ThemeSpacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                        .scaleEffect(0.7)
                    
                    Text(tool.name)
                        .font(Theme.Typography.bodyFont)
                        .foregroundColor(Theme.foreground)
                    
                    Spacer()
                }
                .padding(.horizontal, ThemeSpacing.md)
                .padding(.vertical, ThemeSpacing.sm)
                .background(Theme.primary.opacity(0.05))
                .cornerRadius(Theme.Radius.sm)
            }
        }
        .padding(.horizontal, ThemeSpacing.md)
    }
}

// MARK: - Thinking View

struct ThinkingView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: ThemeSpacing.md) {
            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Theme.primary)
                        .frame(width: 6, height: 6)
                        .offset(y: animationOffset)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animationOffset
                        )
                }
            }
            
            Text("Claude is thinking...")
                .font(Theme.Typography.captionFont)
                .foregroundColor(Theme.mutedForeground)
            
            Spacer()
        }
        .padding(.horizontal, ThemeSpacing.md)
        .padding(.vertical, ThemeSpacing.sm)
        .onAppear {
            animationOffset = -8
        }
    }
}

// MARK: - Console Input Area

struct ConsoleInputArea: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onAttach: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Separator
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
            
            // Input field
            HStack(alignment: .bottom, spacing: ThemeSpacing.sm) {
                // Attach button
                Button(action: onAttach) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.mutedForeground)
                }
                .disabled(isLoading)
                
                // Text editor
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text("Type a message...")
                            .font(Theme.Typography.bodyFont)
                            .foregroundColor(Theme.mutedForeground)
                            .padding(.horizontal, 4)
                    }
                    
                    TextEditor(text: $text)
                        .font(Theme.Typography.bodyFont)
                        .foregroundColor(Theme.foreground)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 36, maxHeight: 120)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Send button
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(text.isEmpty || isLoading ? Theme.mutedForeground : Theme.primary)
                }
                .disabled(text.isEmpty || isLoading)
            }
            .padding(.horizontal, ThemeSpacing.md)
            .padding(.vertical, ThemeSpacing.sm)
            .background(Theme.card)
        }
    }
}

// MARK: - Supporting Types

struct ConsoleMessage: Identifiable {
    let id = UUID().uuidString
    let role: MessageRole
    let content: String
    let toolExecutions: [ConsoleToolExecution]
    let timestamp: Date
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

struct ConsoleToolExecution: Identifiable {
    let id = UUID().uuidString
    let name: String
    let icon: String
    let status: ToolStatus
    let duration: TimeInterval?
    let input: String?
    let output: String?
}


// MARK: - View Model

class ChatConsoleViewModel: ObservableObject {
    @Published var messages: [ConsoleMessage] = []
    @Published var activeTools: [ConsoleToolExecution] = []
    @Published var availableTools: [String] = ["Read", "Write", "Execute", "Search"]
    @Published var isThinking = false
    @Published var isProcessing = false
    @Published var connectionStatus: ConnectionStatus = .connected
    @Published var currentModel = "Claude 3.5 Haiku"
    
    func sendMessage(_ text: String) {
        // Implementation
    }
}

// MARK: - Preview

struct ChatConsole_Previews: PreviewProvider {
    static var previews: some View {
        ChatConsoleView()
            .preferredColorScheme(.dark)
    }
}