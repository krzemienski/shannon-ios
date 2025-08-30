//
//  CommonComponents.swift
//  ClaudeCode
//
//  Common UI components for loading, errors, and empty states
//

import SwiftUI

// MARK: - Loading Indicator

public struct LoadingIndicator: View {
    public enum Style {
        case standard
        case overlay
        case inline
        case fullScreen
    }
    
    let message: String?
    let style: Style
    @State private var isAnimating = false
    
    public init(message: String? = nil, style: Style = .standard) {
        self.message = message
        self.style = style
    }
    
    public var body: some View {
        switch style {
        case .standard:
            standardView
        case .overlay:
            overlayView
        case .inline:
            inlineView
        case .fullScreen:
            fullScreenView
        }
    }
    
    private var standardView: some View {
        VStack(spacing: ThemeSpacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                .scaleEffect(1.2)
            
            if let message = message {
                Text(message)
                    .font(.callout)
                    .foregroundColor(Theme.mutedForeground)
            }
        }
        .padding(ThemeSpacing.xl)
    }
    
    private var overlayView: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: ThemeSpacing.lg) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                    .scaleEffect(1.5)
                
                if let message = message {
                    Text(message)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.foreground)
                }
            }
            .padding(ThemeSpacing.xxl)
            .background(Theme.card)
            .cornerRadius(Theme.Radius.lg)
            .shadow(color: Theme.Shadows.large.color, 
                   radius: Theme.Shadows.large.radius,
                   x: Theme.Shadows.large.x,
                   y: Theme.Shadows.large.y)
        }
    }
    
    private var inlineView: some View {
        HStack(spacing: ThemeSpacing.sm) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                .scaleEffect(0.8)
            
            if let message = message {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
        }
    }
    
    private var fullScreenView: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: ThemeSpacing.xl) {
                CyberpunkLoadingAnimation()
                    .frame(width: 100, height: 100)
                
                if let message = message {
                    Text(message)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.foreground)
                }
            }
        }
    }
}

// MARK: - Cyberpunk Loading Animation

struct CyberpunkLoadingAnimation: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.primary, Theme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(rotation + Double(index * 30)))
                    .scaleEffect(scale)
                    .opacity(0.8 - Double(index) * 0.2)
            }
        }
        .onAppear {
            withAnimation(
                Animation.linear(duration: 2)
                    .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
            
            withAnimation(
                Animation.easeInOut(duration: 1)
                    .repeatForever(autoreverses: true)
            ) {
                scale = 1.2
            }
        }
    }
}

// MARK: - Error View

public struct CommonErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    
    public init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }
    
    public var body: some View {
        VStack(spacing: ThemeSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(Theme.destructive)
            
            Text("Something went wrong")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.foreground)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ThemeSpacing.xl)
            
            if let retryAction = retryAction {
                Button(action: retryAction) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.background)
                    .padding(.horizontal, ThemeSpacing.xl)
                    .padding(.vertical, ThemeSpacing.md)
                    .background(Theme.primary)
                    .cornerRadius(Theme.Radius.md)
                }
                .padding(.top, ThemeSpacing.md)
            }
        }
        .padding(ThemeSpacing.xxl)
    }
}

// MARK: - Empty State View

public struct CommonEmptyStateView: View {
    let icon: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    public init(
        icon: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: ThemeSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(Theme.muted)
            
            Text(title)
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.foreground)
            
            if let message = message {
                Text(message)
                    .font(.body)
                    .foregroundColor(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ThemeSpacing.xl)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.background)
                        .padding(.horizontal, ThemeSpacing.xl)
                        .padding(.vertical, ThemeSpacing.md)
                        .background(Theme.primary)
                        .cornerRadius(Theme.Radius.md)
                }
                .padding(.top, ThemeSpacing.md)
            }
        }
        .padding(ThemeSpacing.xxl)
    }
}

// MARK: - Custom Button Styles

public struct CommonPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundColor(isEnabled ? Theme.background : Theme.mutedForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ThemeSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(isEnabled ? Theme.primary : Theme.muted)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

public struct CommonSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundColor(isEnabled ? Theme.primary : Theme.mutedForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ThemeSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(isEnabled ? Theme.primary : Theme.muted, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

public struct CommonGhostButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundColor(Theme.primary)
            .padding(.horizontal, ThemeSpacing.md)
            .padding(.vertical, ThemeSpacing.sm)
            .background(
                configuration.isPressed ? Theme.muted.opacity(0.2) : Color.clear
            )
            .cornerRadius(Theme.Radius.sm)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Badge View

public struct BadgeView: View {
    public enum Style {
        case primary, secondary, success, warning, danger, info
        
        var backgroundColor: Color {
            switch self {
            case .primary: return Theme.primary
            case .secondary: return Theme.secondary
            case .success: return Theme.success
            case .warning: return Theme.warning
            case .danger: return Theme.destructive
            case .info: return Theme.info
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary, .secondary, .success, .danger, .info:
                return Theme.background
            case .warning:
                return Theme.foreground
            }
        }
    }
    
    let text: String
    let style: Style
    
    public init(_ text: String, style: Style = .primary) {
        self.text = text
        self.style = style
    }
    
    public var body: some View {
        Text(text)
            .font(Theme.Typography.caption)
            .fontWeight(.semibold)
            .foregroundColor(style.foregroundColor)
            .padding(.horizontal, ThemeSpacing.sm)
            .padding(.vertical, ThemeSpacing.xs)
            .background(style.backgroundColor)
            .cornerRadius(Theme.Radius.round)
    }
}

// MARK: - Divider

public struct CustomDivider: View {
    public init() {}
    
    public var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }
}

// MARK: - Section Header

public struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let actionTitle: String?
    
    public init(
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.foreground)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.mutedForeground)
                }
            }
            
            Spacer()
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.primary)
                }
            }
        }
        .padding(.horizontal, ThemeSpacing.lg)
        .padding(.vertical, ThemeSpacing.sm)
    }
}