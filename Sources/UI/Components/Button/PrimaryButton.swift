//
//  PrimaryButton.swift
//  ClaudeCode
//
//  Main action button component
//

import SwiftUI

/// Primary button for main actions
public struct PrimaryButton: View {
    // MARK: - Properties
    let title: String
    let icon: String?
    let action: () -> Void
    let isLoading: Bool
    let isDisabled: Bool
    let size: ButtonSize
    let fullWidth: Bool
    
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Button Sizes
    public enum ButtonSize {
        case small, medium, large
        
        var padding: EdgeInsets {
            switch self {
            case .small:
                return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            case .medium:
                return EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
            case .large:
                return EdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
            }
        }
        
        var font: Font {
            switch self {
            case .small:
                return Typography.Body.small
            case .medium:
                return Typography.Body.medium
            case .large:
                return Typography.Body.large
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 16
            case .large: return 20
            }
        }
    }
    
    // MARK: - Initialization
    public init(
        _ title: String,
        icon: String? = nil,
        size: ButtonSize = .medium,
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
                        .tint(.white)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(size.font)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(size.padding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(Animations.Spring.quick, value: isPressed)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1.0)
        .accessibilityLabel(title)
        .accessibilityHint(isDisabled ? "Button is disabled" : "Double tap to activate")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Background View
    @ViewBuilder
    private var backgroundView: some View {
        LinearGradient(
            colors: [
                SemanticColors.Accents.primary,
                SemanticColors.Accents.primary.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(
                    SemanticColors.Accents.primary.opacity(0.3),
                    lineWidth: 1
                )
        )
        .shadow(
            color: SemanticColors.Accents.primary.opacity(0.3),
            radius: isPressed ? 4 : 8,
            y: isPressed ? 2 : 4
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

// MARK: - View Extension
public extension View {
    /// Apply primary button style to any view
    func primaryButtonStyle(size: PrimaryButton.ButtonSize = .medium) -> some View {
        self
            .font(size.font)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(size.padding)
            .background(
                LinearGradient(
                    colors: [
                        SemanticColors.Accents.primary,
                        SemanticColors.Accents.primary.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: Spacing.lg) {
        PrimaryButton("Get Started") {
            print("Primary tapped")
        }
        
        PrimaryButton("With Icon", icon: Icons.Actions.play) {
            print("With icon tapped")
        }
        
        PrimaryButton("Small Button", size: .small) {
            print("Small tapped")
        }
        
        PrimaryButton("Large Button", size: .large, fullWidth: true) {
            print("Large tapped")
        }
        
        PrimaryButton("Loading", isLoading: true) {
            print("Loading")
        }
        
        PrimaryButton("Disabled", isDisabled: true) {
            print("Disabled")
        }
    }
    .padding(.all)
    .background(Color(hsl: 240, 10, 5))
    .preferredColorScheme(.dark)
}