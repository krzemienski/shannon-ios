//
//  MessageView.swift
//  ClaudeCode
//
//  Individual message bubble with markdown and code block rendering
//

import SwiftUI

/// Individual message view with basic text support
struct MessageView: View {
    let message: Message
    let isStreaming: Bool
    let streamingContent: String
    let onCopy: () -> Void
    let onResend: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var showActions = false
    @State private var copiedCode = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var displayContent: String {
        if isStreaming && !streamingContent.isEmpty {
            return streamingContent
        }
        return message.content
    }
    
    private var messageAlignment: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: ThemeSpacing.md) {
            if message.role != .user {
                avatarView
            }
            
            VStack(alignment: messageAlignment, spacing: ThemeSpacing.xs) {
                // Message bubble
                messageBubble
                
                // Metadata
                metadataView
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .user {
                avatarView
            }
        }
        .padding(.horizontal)
        .onHover { isHovered = $0 }
        .contextMenu {
            messageContextMenu
        }
    }
    
    // MARK: - Subviews
    
    private var avatarView: some View {
        Group {
            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.primary)
                    .background(Circle().fill(Theme.card))
            } else if message.role == .assistant {
                Image(systemName: "cpu")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.primary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Theme.primary.opacity(0.1))
                            .overlay(
                                Circle()
                                    .stroke(Theme.primary.opacity(0.3), lineWidth: 1)
                            )
                    )
            } else if message.role == .error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .frame(width: 32, height: 32)
            }
        }
    }
    
    private var messageBubble: some View {
        Group {
            if message.role == .error {
                errorMessageView
            } else {
                regularMessageView
            }
        }
    }
    
    private var regularMessageView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Render text content (markdown rendering temporarily disabled)
            Text(displayContent)
                .font(Theme.Typography.body)
                .textSelection(.enabled)
                .padding(ThemeSpacing.md)
            
            // Tool calls if present
            if let toolCalls = message.metadata?.toolCalls, !toolCalls.isEmpty {
                toolCallsView(toolCalls)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(message.role == .user ? Theme.primary : Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(
                            message.role == .user ? Color.clear : Theme.border,
                            lineWidth: 1
                        )
                )
        )
        .foregroundColor(message.role == .user ? .white : Theme.foreground)
        .overlay(alignment: .topTrailing) {
            if isHovered || showActions {
                messageActionsView
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var errorMessageView: some View {
        HStack(spacing: ThemeSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(displayContent)
                .font(Theme.Typography.body)
                .foregroundColor(.red)
            
            Spacer()
            
            Button(action: onResend) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(Theme.Typography.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(ThemeSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var metadataView: some View {
        HStack(spacing: ThemeSpacing.sm) {
            // Timestamp
            Text(formatTimestamp(message.timestamp))
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.mutedForeground)
            
            // Model info
            if let model = message.metadata?.model {
                Text("• \(model)")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            // Token usage
            if let usage = message.metadata?.usage {
                Text("• \(usage.totalTokens) tokens")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            // Streaming indicator
            if isStreaming {
                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Theme.primary)
                            .frame(width: 4, height: 4)
                            .opacity(isStreaming ? 1 : 0.3)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: isStreaming
                            )
                    }
                }
            }
        }
    }
    
    private var messageActionsView: some View {
        HStack(spacing: ThemeSpacing.xs) {
            Button(action: onCopy) {
                Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            
            if message.role == .user {
                Button(action: onResend) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            
            Button(action: { showActions.toggle() }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(ThemeSpacing.xs)
    }
    
    private func toolCallsView(_ toolCalls: [ToolCall]) -> some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
            Divider()
                .background(Theme.border.opacity(0.5))
            
            ForEach(toolCalls) { toolCall in
                HStack(spacing: ThemeSpacing.sm) {
                    Image(systemName: toolCallIcon(for: toolCall.status))
                        .font(.system(size: 12))
                        .foregroundColor(toolCallColor(for: toolCall.status))
                    
                    Text(toolCall.name)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.mutedForeground)
                    
                    Spacer()
                    
                    Text(toolCall.status.rawValue.capitalized)
                        .font(Theme.Typography.caption2)
                        .foregroundColor(toolCallColor(for: toolCall.status))
                }
                .padding(.horizontal, ThemeSpacing.md)
                .padding(.vertical, ThemeSpacing.xs)
            }
        }
    }
    
    @ViewBuilder
    private var messageContextMenu: some View {
        Button(action: onCopy) {
            Label("Copy", systemImage: "doc.on.doc")
        }
        
        if message.role == .user {
            Button(action: onResend) {
                Label("Resend", systemImage: "arrow.clockwise")
            }
        }
        
        Divider()
        
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Helpers
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' HH:mm"
        } else {
            formatter.dateFormat = "MMM d, HH:mm"
        }
        
        return formatter.string(from: date)
    }
    
    private func toolCallIcon(for status: ToolCallStatus) -> String {
        switch status {
        case .pending: return "clock"
        case .running: return "arrow.clockwise.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }
    
    private func toolCallColor(for status: ToolCallStatus) -> Color {
        switch status {
        case .pending: return Theme.mutedForeground
        case .running: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Markdown Theme (Temporarily Disabled)

/*
// TODO: Re-enable when MarkdownUI is added as a dependency
extension Theme {
    static var claudeTheme: MarkdownUI.Theme {
        // Markdown theme configuration would go here
    }
}

struct CodeSyntaxHighlighter: CodeSyntaxHighlighting {
    func highlightCode(_ code: String, language: String?) -> Text {
        // Simple syntax highlighting - in production, use a proper library
        return Text(code)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(Theme.primary)
    }
}
*/

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        MessageView(
            message: Message(
                role: .user,
                content: "Can you help me create a SwiftUI button?"
            ),
            isStreaming: false,
            streamingContent: "",
            onCopy: {},
            onResend: {},
            onDelete: {}
        )
        
        MessageView(
            message: Message(
                role: .assistant,
                content: """
                Sure! Here's a SwiftUI button example:
                
                ```swift
                Button(action: {
                    print("Button tapped!")
                }) {
                    Text("Tap Me")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                ```
                
                This creates a button with:
                - Custom styling
                - Tap action
                - Rounded corners
                """
            ),
            isStreaming: false,
            streamingContent: "",
            onCopy: {},
            onResend: {},
            onDelete: {}
        )
    }
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}