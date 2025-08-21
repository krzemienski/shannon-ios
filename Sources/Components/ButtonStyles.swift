//
//  ButtonStyles.swift
//  ClaudeCode
//
//  Custom button styles for consistent UI
//

import SwiftUI

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.callout)
            .fontWeight(.medium)
            .foregroundColor(Theme.foreground)
            .padding(.horizontal, ThemeSpacing.lg)
            .padding(.vertical, ThemeSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(isEnabled ? Theme.primary : Theme.muted)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(Theme.Animation.spring, value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.callout)
            .fontWeight(.medium)
            .foregroundColor(isEnabled ? Theme.foreground : Theme.mutedForeground)
            .padding(.horizontal, ThemeSpacing.lg)
            .padding(.vertical, ThemeSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(Theme.Animation.spring, value: configuration.isPressed)
    }
}

// MARK: - Destructive Button Style

struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.callout)
            .fontWeight(.medium)
            .foregroundColor(Theme.foreground)
            .padding(.horizontal, ThemeSpacing.lg)
            .padding(.vertical, ThemeSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(isEnabled ? Theme.destructive : Theme.muted)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(Theme.Animation.spring, value: configuration.isPressed)
    }
}

// MARK: - Ghost Button Style (No background)

struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.callout)
            .fontWeight(.medium)
            .foregroundColor(isEnabled ? Theme.primary : Theme.mutedForeground)
            .padding(.horizontal, ThemeSpacing.md)
            .padding(.vertical, ThemeSpacing.sm)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(Theme.Animation.spring, value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let size: CGFloat
    
    init(size: CGFloat = 44) {
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.5))
            .foregroundColor(isEnabled ? Theme.foreground : Theme.mutedForeground)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Theme.card)
                    .overlay(
                        Circle()
                            .stroke(Theme.border, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(Theme.Animation.spring, value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions

extension View {
    func primaryButtonStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryButtonStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    func destructiveButtonStyle() -> some View {
        self.buttonStyle(DestructiveButtonStyle())
    }
    
    func ghostButton() -> some View {
        self.buttonStyle(GhostButtonStyle())
    }
    
    func iconButton(size: CGFloat = 44) -> some View {
        self.buttonStyle(IconButtonStyle(size: size))
    }
}

struct ButtonStylesPreview: PreviewProvider {
    static var previews: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: ThemeSpacing.lg) {
                // Primary buttons
                HStack(spacing: ThemeSpacing.md) {
                    Button("Primary") {}
                        .primaryButtonStyle()
                    
                    Button("Primary Disabled") {}
                        .primaryButtonStyle()
                        .disabled(true)
                }
                
                // Secondary buttons
                HStack(spacing: ThemeSpacing.md) {
                    Button("Secondary") {}
                        .secondaryButtonStyle()
                    
                    Button("Secondary Disabled") {}
                        .secondaryButtonStyle()
                        .disabled(true)
                }
                
                // Destructive buttons
                HStack(spacing: ThemeSpacing.md) {
                    Button("Delete") {}
                        .destructiveButtonStyle()
                    
                    Button("Delete Disabled") {}
                        .destructiveButtonStyle()
                        .disabled(true)
                }
                
                // Ghost buttons
                HStack(spacing: ThemeSpacing.md) {
                    Button("Ghost") {}
                        .ghostButton()
                    
                    Button("Ghost Disabled") {}
                        .ghostButton()
                        .disabled(true)
                }
                
                // Icon buttons
                HStack(spacing: ThemeSpacing.md) {
                    Button {
                        // Action
                    } label: {
                        Image(systemName: "plus")
                    }
                    .iconButton()
                    
                    Button {
                        // Action
                    } label: {
                        Image(systemName: "gear")
                    }
                    .iconButton(size: 36)
                    
                    Button {
                        // Action
                    } label: {
                        Image(systemName: "trash")
                    }
                    .iconButton()
                    .disabled(true)
                }
            }
            .padding()
        }
    }
}