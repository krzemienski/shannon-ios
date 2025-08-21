//
//  CyberpunkListItem.swift
//  ClaudeCode
//
//  List item/cell component with cyberpunk styling
//

import SwiftUI

/// List item action types
enum ListItemAction {
    case none
    case chevron
    case toggle(isOn: Binding<Bool>)
    case button(icon: String, action: () -> Void)
    case custom(view: AnyView)
}

/// Custom cyberpunk-styled list item
struct CyberpunkListItem<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let leading: Leading?
    let trailing: Trailing?
    let action: (() -> Void)?
    let isSelected: Bool
    let showDivider: Bool
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading? = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing? = { EmptyView() },
        action: (() -> Void)? = nil,
        isSelected: Bool = false,
        showDivider: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
        self.action = action
        self.isSelected = isSelected
        self.showDivider = showDivider
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Leading content
                if leading != nil {
                    leading
                        .frame(width: 40)
                }
                
                // Main content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(Color.hsl(0, 0, 95))
                        .lineLimit(1)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(Color.hsl(240, 10, 65))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Trailing content
                if trailing != nil {
                    trailing
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(
                        isSelected ? Color.hsl(142, 70, 45).opacity(0.1) :
                        isHovered ? Color.hsl(240, 10, 12) :
                        Color.clear
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if let action = action {
                    withAnimation(.spring(response: 0.2)) {
                        isPressed = true
                    }
                    
                    action()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPressed = false
                    }
                }
            }
            .onHover { hovering in
                if action != nil {
                    withAnimation(.spring(response: 0.2)) {
                        isHovered = hovering
                    }
                }
            }
            .scaleEffect(isPressed ? 0.98 : 1.0)
            
            // Divider
            if showDivider {
                Divider()
                    .background(Color.hsl(240, 10, 20))
                    .padding(.leading, leading != nil ? 68 : 16)
            }
        }
    }
}

// Extension for convenience initializers
extension CyberpunkListItem where Leading == EmptyView, Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        action: (() -> Void)? = nil,
        isSelected: Bool = false,
        showDivider: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = nil
        self.trailing = nil
        self.action = action
        self.isSelected = isSelected
        self.showDivider = showDivider
    }
}

/// Pre-configured list item with icon
struct CyberpunkIconListItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let badge: Int?
    let action: ListItemAction
    let onTap: (() -> Void)?
    
    @State private var toggleState = false
    
    init(
        icon: String,
        iconColor: Color = Color.hsl(142, 70, 45),
        title: String,
        subtitle: String? = nil,
        badge: Int? = nil,
        action: ListItemAction = .none,
        onTap: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.action = action
        self.onTap = onTap
    }
    
    var body: some View {
        CyberpunkListItem(
            title: title,
            subtitle: subtitle,
            leading: {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
            },
            trailing: {
                HStack(spacing: 8) {
                    if let badge = badge {
                        CyberpunkBadge(
                            "\(badge)",
                            variant: .error,
                            size: .small
                        )
                    }
                    
                    switch action {
                    case .none:
                        EmptyView()
                    case .chevron:
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color.hsl(240, 10, 45))
                    case .toggle(let isOn):
                        CyberpunkCompactToggle(isOn: isOn)
                    case .button(let icon, let buttonAction):
                        Button(action: buttonAction) {
                            Image(systemName: icon)
                                .font(.body)
                                .foregroundColor(Color.hsl(240, 10, 65))
                        }
                        .buttonStyle(PlainButtonStyle())
                    case .custom(let view):
                        view
                    }
                }
            },
            action: onTap
        )
    }
}

/// Section header for list
struct CyberpunkListSection: View {
    let title: String
    let action: (() -> Void)?
    
    init(
        _ title: String,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.action = action
    }
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Color.hsl(142, 70, 45))
            
            Spacer()
            
            if action != nil {
                Button(action: action!) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(Color.hsl(240, 10, 65))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.hsl(240, 10, 8))
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 0) {
            // Basic list items
            CyberpunkListSection("Basic Items")
            
            CyberpunkListItem(
                title: "Simple Item",
                action: { print("Tapped") }
            )
            
            CyberpunkListItem(
                title: "Item with Subtitle",
                subtitle: "This is a description of the item",
                action: { print("Tapped") }
            )
            
            CyberpunkListItem(
                title: "Selected Item",
                subtitle: "This item is selected",
                isSelected: true
            )
            
            // Icon list items
            CyberpunkListSection("With Icons")
            
            CyberpunkIconListItem(
                icon: "person.fill",
                iconColor: Color.hsl(201, 70, 50),
                title: "Profile",
                subtitle: "View and edit your profile",
                action: .chevron,
                onTap: { print("Profile") }
            )
            
            CyberpunkIconListItem(
                icon: "bell.fill",
                iconColor: Color.hsl(45, 80, 60),
                title: "Notifications",
                subtitle: "Manage notification preferences",
                badge: 5,
                action: .toggle(isOn: .constant(true))
            )
            
            CyberpunkIconListItem(
                icon: "lock.fill",
                iconColor: Color.hsl(0, 80, 60),
                title: "Security",
                subtitle: "Two-factor authentication enabled",
                action: .chevron,
                onTap: { print("Security") }
            )
            
            // Action items
            CyberpunkListSection("Actions")
            
            CyberpunkIconListItem(
                icon: "square.and.arrow.up",
                title: "Share",
                action: .button(icon: "ellipsis") {
                    print("More options")
                }
            )
            
            CyberpunkIconListItem(
                icon: "trash",
                iconColor: Color.hsl(0, 80, 60),
                title: "Delete Account",
                subtitle: "This action cannot be undone",
                action: .chevron
            )
            
            // Custom trailing
            CyberpunkListSection("Custom Trailing")
            
            CyberpunkListItem(
                title: "Download Progress",
                subtitle: "Downloading 5 files...",
                leading: {
                    CyberpunkCircularProgress(
                        value: 0.7,
                        size: 40,
                        lineWidth: 3,
                        showLabel: false
                    )
                },
                trailing: {
                    Text("70%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Color.hsl(142, 70, 45))
                }
            )
            
            CyberpunkListItem(
                title: "Active Task",
                subtitle: "Running for 2 hours",
                leading: {
                    CyberpunkSpinner(size: 30, lineWidth: 3)
                },
                trailing: {
                    CyberpunkButton(
                        "Stop",
                        variant: .destructive,
                        size: .small
                    ) {
                        print("Stop task")
                    }
                    .frame(width: 60)
                }
            )
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.hsl(240, 10, 5))
}