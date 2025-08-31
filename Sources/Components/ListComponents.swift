//
//  ListComponents.swift
//  ClaudeCode
//
//  Reusable list components with various styles
//

import SwiftUI

// MARK: - List Row

struct ListRow<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let leading: Leading?
    let trailing: Trailing?
    let action: (() -> Void)?
    
    @State private var isPressed = false
    
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading? = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing? = { EmptyView() },
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
        self.action = action
    }
    
    var body: some View {
        HStack(spacing: ThemeSpacing.md) {
            // Leading content
            if leading != nil {
                leading
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.bodyFont)
                    .foregroundColor(Theme.foreground)
                    .lineLimit(1)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.captionFont)
                        .foregroundColor(Theme.mutedForeground)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Trailing content
            if trailing != nil {
                trailing
            } else if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.mutedForeground)
            }
        }
        .padding(.horizontal, ThemeSpacing.md)
        .padding(.vertical, ThemeSpacing.sm)
        .background(isPressed ? Theme.primary.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if let action = action {
                Theme.Haptics.selection()
                action()
            }
        }
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in
                if action != nil {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Tool List Item

struct ToolListItem: View {
    let name: String
    let description: String
    let icon: String
    let status: ToolStatus
    let executionTime: String?
    let action: () -> Void
    
    var body: some View {
        ListRow(
            title: name,
            subtitle: description,
            leading: {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(statusColor)
                        .frame(width: 36, height: 36)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(Theme.Radius.sm)
                    
                    // Status overlay
                    if status == .running {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                            .scaleEffect(0.7)
                    }
                }
            },
            trailing: {
                VStack(alignment: .trailing, spacing: 2) {
                    StatusBadge(status: status)
                    
                    if let time = executionTime {
                        Text(time)
                            .font(Theme.Typography.caption2Font)
                            .foregroundColor(Theme.mutedForeground)
                    }
                }
            },
            action: action
        )
    }
    
    private var statusColor: Color {
        switch status {
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
}

// MARK: - Conversation List Item

struct ConversationListItem: View {
    let title: String
    let lastMessage: String
    let timestamp: Date
    let unreadCount: Int
    let isPinned: Bool
    let tags: [String]
    let action: () -> Void
    
    var body: some View {
        CardView(variant: .interactive) {
            HStack(spacing: ThemeSpacing.md) {
                // Avatar
                Circle()
                    .fill(Theme.primary.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "message.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.primary)
                    )
                
                // Content
                VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                    // Title row
                    HStack {
                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.primary)
                        }
                        
                        Text(title)
                            .font(Theme.Typography.headlineFont)
                            .foregroundColor(Theme.foreground)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(formattedTime)
                            .font(Theme.Typography.captionFont)
                            .foregroundColor(Theme.mutedForeground)
                    }
                    
                    // Message preview
                    Text(lastMessage)
                        .font(Theme.Typography.subheadlineFont)
                        .foregroundColor(Theme.mutedForeground)
                        .lineLimit(2)
                    
                    // Tags
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: ThemeSpacing.xs) {
                                ForEach(tags, id: \.self) { tag in
                                    TagView(text: tag, style: .small)
                                }
                            }
                        }
                    }
                }
                
                // Unread indicator
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(Theme.Typography.captionFont)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Theme.primary)
                        .clipShape(Circle())
                        .frame(minWidth: 20)
                }
            }
        }
        .onTapGesture {
            action()
        }
    }
    
    private var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Section Header

struct ListSectionHeader: View {
    let title: String
    let action: (() -> Void)?
    let actionLabel: String?
    
    init(
        title: String,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil
    ) {
        self.title = title
        self.action = action
        self.actionLabel = actionLabel
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(Theme.Typography.headlineFont)
                .foregroundColor(Theme.foreground)
            
            Spacer()
            
            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(Theme.Typography.captionFont)
                        .foregroundColor(Theme.primary)
                }
            }
        }
        .padding(.horizontal, ThemeSpacing.md)
        .padding(.vertical, ThemeSpacing.sm)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let action: (String, () -> Void)?
    
    var body: some View {
        VStack(spacing: ThemeSpacing.lg) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Theme.mutedForeground)
                .frame(width: 80, height: 80)
                .background(Theme.card)
                .cornerRadius(Theme.Radius.xl)
            
            // Text
            VStack(spacing: ThemeSpacing.sm) {
                Text(title)
                    .font(Theme.Typography.title3Font)
                    .foregroundColor(Theme.foreground)
                
                Text(message)
                    .font(Theme.Typography.bodyFont)
                    .foregroundColor(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Action button
            if let (label, action) = action {
                Button(action: action) {
                    Text(label)
                }
                .primaryButtonStyle()
            }
        }
        .padding(ThemeSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Types

enum ToolStatus {
    case idle
    case running
    case success
    case error
}

struct StatusBadge: View {
    let status: ToolStatus
    
    var body: some View {
        Text(statusText)
            .font(Theme.Typography.caption2Font)
            .foregroundColor(statusColor)
            .padding(.horizontal, ThemeSpacing.xs)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.1))
            .cornerRadius(Theme.Radius.sm)
    }
    
    private var statusText: String {
        switch status {
        case .idle:
            return "Idle"
        case .running:
            return "Running"
        case .success:
            return "Success"
        case .error:
            return "Error"
        }
    }
    
    private var statusColor: Color {
        switch status {
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
}

struct TagView: View {
    let text: String
    let style: TagStyle
    
    enum TagStyle {
        case small
        case medium
        case large
    }
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(Theme.primary)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Theme.primary.opacity(0.1))
            .cornerRadius(Theme.Radius.sm)
    }
    
    private var font: Font {
        switch style {
        case .small:
            return Theme.Typography.caption2Font
        case .medium:
            return Theme.Typography.caption
        case .large:
            return Theme.Typography.footnote
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch style {
        case .small:
            return ThemeSpacing.xs
        case .medium:
            return ThemeSpacing.sm
        case .large:
            return ThemeSpacing.md
        }
    }
    
    private var verticalPadding: CGFloat {
        switch style {
        case .small:
            return 2
        case .medium:
            return 4
        case .large:
            return 6
        }
    }
}

// MARK: - Preview

struct ListComponents_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: ThemeSpacing.lg) {
                    // Section with tools
                    VStack(spacing: 0) {
                        ListSectionHeader(
                            title: "Available Tools",
                            action: {},
                            actionLabel: "View All"
                        )
                        
                        VStack(spacing: 0) {
                            ToolListItem(
                                name: "Read File",
                                description: "Read contents of a file",
                                icon: "doc.text",
                                status: .success,
                                executionTime: "23ms",
                                action: {}
                            )
                            
                            Divider()
                                .background(Theme.border)
                            
                            ToolListItem(
                                name: "Execute Command",
                                description: "Run shell commands",
                                icon: "terminal",
                                status: .running,
                                executionTime: nil,
                                action: {}
                            )
                            
                            Divider()
                                .background(Theme.border)
                            
                            ToolListItem(
                                name: "Write File",
                                description: "Write content to a file",
                                icon: "square.and.pencil",
                                status: .error,
                                executionTime: "Failed",
                                action: {}
                            )
                        }
                        .background(Theme.card)
                        .cornerRadius(Theme.Radius.lg)
                    }
                    
                    // Conversation items
                    VStack(spacing: ThemeSpacing.md) {
                        ConversationListItem(
                            title: "SwiftUI Help",
                            lastMessage: "Let me help you with that layout issue...",
                            timestamp: Date().addingTimeInterval(-3600),
                            unreadCount: 2,
                            isPinned: true,
                            tags: ["swift", "ios"],
                            action: {}
                        )
                        
                        ConversationListItem(
                            title: "API Integration",
                            lastMessage: "The authentication flow is now complete",
                            timestamp: Date().addingTimeInterval(-7200),
                            unreadCount: 0,
                            isPinned: false,
                            tags: ["api", "network"],
                            action: {}
                        )
                    }
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
}