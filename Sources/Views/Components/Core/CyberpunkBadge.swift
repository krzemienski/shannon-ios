//
//  CyberpunkBadge.swift
//  ClaudeCode
//
//  Badge and chip components with cyberpunk styling
//

import SwiftUI

/// Badge variant types
enum BadgeVariant {
    case primary
    case secondary
    case success
    case warning
    case error
    case info
    case outline
    
    var backgroundColor: Color {
        switch self {
        case .primary:
            return Color.hsl(142, 70, 45).opacity(0.2)
        case .secondary:
            return Color.hsl(240, 10, 20)
        case .success:
            return Color.hsl(142, 70, 45).opacity(0.2)
        case .warning:
            return Color.hsl(45, 80, 60).opacity(0.2)
        case .error:
            return Color.hsl(0, 80, 60).opacity(0.2)
        case .info:
            return Color.hsl(201, 70, 50).opacity(0.2)
        case .outline:
            return Color.clear
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary:
            return Color.hsl(142, 70, 55)
        case .secondary:
            return Color.hsl(0, 0, 85)
        case .success:
            return Color.hsl(142, 70, 55)
        case .warning:
            return Color.hsl(45, 80, 70)
        case .error:
            return Color.hsl(0, 80, 70)
        case .info:
            return Color.hsl(201, 70, 60)
        case .outline:
            return Color.hsl(142, 70, 45)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .outline:
            return Color.hsl(142, 70, 45).opacity(0.5)
        default:
            return Color.clear
        }
    }
}

/// Badge size options
enum BadgeSize {
    case small
    case medium
    case large
    
    var padding: EdgeInsets {
        switch self {
        case .small:
            return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
        case .medium:
            return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        case .large:
            return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        }
    }
    
    var fontSize: Font {
        switch self {
        case .small:
            return .caption2
        case .medium:
            return .caption
        case .large:
            return .footnote
        }
    }
}

/// Simple badge component
struct CyberpunkBadge: View {
    let text: String
    let icon: String?
    let variant: BadgeVariant
    let size: BadgeSize
    let animated: Bool
    
    @State private var pulseAnimation = false
    
    init(
        _ text: String,
        icon: String? = nil,
        variant: BadgeVariant = .primary,
        size: BadgeSize = .medium,
        animated: Bool = false
    ) {
        self.text = text
        self.icon = icon
        self.variant = variant
        self.size = size
        self.animated = animated
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(size.fontSize)
            }
            
            Text(text)
                .font(size.fontSize)
                .fontWeight(.semibold)
        }
        .padding(size.padding)
        .foregroundColor(variant.foregroundColor)
        .background(
            Capsule()
                .fill(variant.backgroundColor)
                .overlay(
                    Capsule()
                        .stroke(variant.borderColor, lineWidth: 1)
                )
        )
        .scaleEffect(animated && pulseAnimation ? 1.05 : 1.0)
        .opacity(animated && pulseAnimation ? 0.9 : 1.0)
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
    }
}

/// Interactive chip component with dismiss
struct CyberpunkChip: View {
    let text: String
    let icon: String?
    let variant: BadgeVariant
    let onDismiss: (() -> Void)?
    let onTap: (() -> Void)?
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    init(
        _ text: String,
        icon: String? = nil,
        variant: BadgeVariant = .secondary,
        onDismiss: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.text = text
        self.icon = icon
        self.variant = variant
        self.onDismiss = onDismiss
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
            }
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            
            if onDismiss != nil {
                Divider()
                    .frame(height: 12)
                    .background(variant.foregroundColor.opacity(0.3))
                
                Button(action: {
                    onDismiss?()
                }) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundColor(variant.foregroundColor)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(variant.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            variant == .outline ? variant.borderColor :
                            isHovered ? variant.foregroundColor.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            if let onTap = onTap {
                withAnimation(.spring(response: 0.2)) {
                    isPressed = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                    onTap()
                }
            }
        }
    }
}

/// Notification dot/counter badge
struct CyberpunkNotificationBadge: View {
    let count: Int?
    let showDot: Bool
    let variant: BadgeVariant
    
    init(
        count: Int? = nil,
        showDot: Bool = false,
        variant: BadgeVariant = .error
    ) {
        self.count = count
        self.showDot = showDot
        self.variant = variant
    }
    
    var body: some View {
        if let count = count {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, count > 9 ? 6 : 4)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(
                            variant == .error ? Color.hsl(0, 80, 60) :
                            variant == .primary ? Color.hsl(142, 70, 45) :
                            Color.hsl(201, 70, 50)
                        )
                )
        } else if showDot {
            Circle()
                .fill(
                    variant == .error ? Color.hsl(0, 80, 60) :
                    variant == .primary ? Color.hsl(142, 70, 45) :
                    Color.hsl(201, 70, 50)
                )
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 24) {
        // Badge variants
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges")
                .font(.headline)
                .foregroundColor(Color.hsl(0, 0, 95))
            
            HStack(spacing: 8) {
                CyberpunkBadge("Primary", variant: .primary)
                CyberpunkBadge("Success", icon: "checkmark", variant: .success)
                CyberpunkBadge("Warning", variant: .warning)
                CyberpunkBadge("Error", variant: .error)
            }
            
            HStack(spacing: 8) {
                CyberpunkBadge("Info", variant: .info)
                CyberpunkBadge("Secondary", variant: .secondary)
                CyberpunkBadge("Outline", variant: .outline)
                CyberpunkBadge("Live", icon: "dot.radiowaves.left.and.right", variant: .error, animated: true)
            }
            
            HStack(spacing: 8) {
                CyberpunkBadge("S", size: .small)
                CyberpunkBadge("M", size: .medium)
                CyberpunkBadge("L", size: .large)
            }
        }
        
        Divider()
            .background(Color.hsl(240, 10, 20))
        
        // Chips
        VStack(alignment: .leading, spacing: 12) {
            Text("Chips")
                .font(.headline)
                .foregroundColor(Color.hsl(0, 0, 95))
            
            HStack(spacing: 8) {
                CyberpunkChip("Swift", icon: "swift")
                CyberpunkChip("SwiftUI", icon: "sparkles")
                CyberpunkChip("iOS 18", onDismiss: {
                    print("Dismissed")
                })
            }
            
            HStack(spacing: 8) {
                CyberpunkChip("Clickable", variant: .primary) {
                    print("Tapped")
                }
                CyberpunkChip("Removable", variant: .outline, onDismiss: {
                    print("Removed")
                })
            }
        }
        
        Divider()
            .background(Color.hsl(240, 10, 20))
        
        // Notification badges
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.headline)
                .foregroundColor(Color.hsl(0, 0, 95))
            
            HStack(spacing: 20) {
                Image(systemName: "bell.fill")
                    .overlay(
                        CyberpunkNotificationBadge(showDot: true),
                        alignment: .topTrailing
                    )
                
                Image(systemName: "envelope.fill")
                    .overlay(
                        CyberpunkNotificationBadge(count: 3),
                        alignment: .topTrailing
                    )
                
                Image(systemName: "message.fill")
                    .overlay(
                        CyberpunkNotificationBadge(count: 42, variant: .primary),
                        alignment: .topTrailing
                    )
                
                Image(systemName: "tray.fill")
                    .overlay(
                        CyberpunkNotificationBadge(count: 128, variant: .info),
                        alignment: .topTrailing
                    )
            }
            .font(.title2)
            .foregroundColor(Color.hsl(240, 10, 65))
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.hsl(240, 10, 5))
}