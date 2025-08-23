//
//  SecondaryButton.swift
//  ClaudeCode
//
//  Secondary action button component
//

import SwiftUI

/// Secondary button for alternative actions
public struct SecondaryButton: View {
    // MARK: - Properties
    let title: String
    let icon: String?
    let action: () -> Void
    let isLoading: Bool
    let isDisabled: Bool
    let size: PrimaryButton.ButtonSize
    let fullWidth: Bool
    
    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Initialization
    public init(
        _ title: String,
        icon: String? = nil,
        size: PrimaryButton.ButtonSize = .medium,
        fullWidth: Bool = false,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.fullWidth = fullWidth
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    // MARK: - Body
    public var body: some View {
        Button(action: handleTap) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                        .tint(SemanticColors.Foregrounds.primary(colorScheme))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(size.font)
                    .fontWeight(.medium)
            }
            .foregroundColor(SemanticColors.Foregrounds.primary(colorScheme))
            .padding(size.padding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(backgroundView)
            .overlay(overlayView)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(Animations.Spring.quick, value: isPressed)
            .animation(Animations.Easing.easeInOut, value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1.0)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(title)
        .accessibilityHint(isDisabled ? "Button is disabled" : "Double tap to activate")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Background View
    @ViewBuilder
    private var backgroundView: some View {
        if isHovered {
            SemanticColors.Backgrounds.tertiary(colorScheme)
                .opacity(0.8)
        } else {
            SemanticColors.Backgrounds.secondary(colorScheme)
                .opacity(0.6)
        }
    }
    
    // MARK: - Overlay View
    @ViewBuilder
    private var overlayView: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.md)
            .stroke(
                SemanticColors.Borders.default(colorScheme),
                lineWidth: 1
            )
    }
    
    // MARK: - Actions
    private func handleTap() {
        guard !isDisabled && !isLoading else { return }
        
        withAnimation(Animations.Spring.quick) {
            isPressed = true
        }
        
        // Haptic feedback
        Theme.Haptics.impact(.light)
        
        action()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(Animations.Spring.quick) {
                isPressed = false
            }
        }
    }
}

// MARK: - Ghost Button Variant
public struct GhostButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let isLoading: Bool
    let isDisabled: Bool
    let size: PrimaryButton.ButtonSize
    
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    public init(
        _ title: String,
        icon: String? = nil,
        size: PrimaryButton.ButtonSize = .medium,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    public var body: some View {
        Button(action: handleTap) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                        .tint(SemanticColors.Accents.primary)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(size.font)
                    .fontWeight(.medium)
            }
            .foregroundColor(SemanticColors.Accents.primary)
            .padding(size.padding)
            .background(Color.clear)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(Animations.Spring.quick, value: isPressed)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1.0)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
    
    private func handleTap() {
        guard !isDisabled && !isLoading else { return }
        
        withAnimation(Animations.Spring.quick) {
            isPressed = true
        }
        
        Theme.Haptics.selection()
        action()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(Animations.Spring.quick) {
                isPressed = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: Spacing.lg) {
        SecondaryButton("Secondary Action") {
            print("Secondary tapped")
        }
        
        SecondaryButton("With Icon", icon: Icons.Actions.edit) {
            print("With icon tapped")
        }
        
        SecondaryButton("Full Width", fullWidth: true) {
            print("Full width tapped")
        }
        
        GhostButton("Ghost Button", icon: Icons.Actions.share) {
            print("Ghost tapped")
        }
        
        SecondaryButton("Loading", isLoading: true) {
            print("Loading")
        }
        
        SecondaryButton("Disabled", isDisabled: true) {
            print("Disabled")
        }
    }
    .padding()
    .background(Color(hsl: 240, 10, 5))
    .preferredColorScheme(.dark)
}