//
//  Card.swift
//  ClaudeCode
//
//  Container component for content
//

import SwiftUI

/// Card container component with customizable styling
public struct Card<Content: View>: View {
    // MARK: - Properties
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    let elevation: CardElevation
    let borderColor: Color?
    let backgroundColor: Color?
    
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Elevation Levels
    public enum CardElevation {
        case none
        case low
        case medium
        case high
        
        var shadow: (color: Color, radius: CGFloat, y: CGFloat) {
            switch self {
            case .none:
                return (Color.clear, 0, 0)
            case .low:
                return (Color.black.opacity(0.1), 4, 2)
            case .medium:
                return (Color.black.opacity(0.15), 8, 4)
            case .high:
                return (Color.black.opacity(0.2), 12, 6)
            }
        }
    }
    
    // MARK: - Initialization
    public init(
        padding: CGFloat = Spacing.lg,
        cornerRadius: CGFloat = Theme.Radius.lg,
        elevation: CardElevation = .low,
        borderColor: Color? = nil,
        backgroundColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.elevation = elevation
        self.borderColor = borderColor
        self.backgroundColor = backgroundColor
        self.content = content()
    }
    
    // MARK: - Body
    public var body: some View {
        content
            .padding(padding)
            .background(
                backgroundColor ?? SemanticColors.Backgrounds.elevated(colorScheme)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        borderColor ?? SemanticColors.Borders.subtle(colorScheme),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: elevation.shadow.color,
                radius: elevation.shadow.radius,
                y: elevation.shadow.y
            )
    }
}

// MARK: - Interactive Card
public struct InteractiveCard<Content: View>: View {
    let content: Content
    let action: () -> Void
    let padding: CGFloat
    let cornerRadius: CGFloat
    
    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    public init(
        padding: CGFloat = Spacing.lg,
        cornerRadius: CGFloat = Theme.Radius.lg,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.action = action
        self.content = content()
    }
    
    public var body: some View {
        Button(action: {
            withAnimation(Animations.Spring.quick) {
                isPressed = true
            }
            Theme.Haptics.impact(.light)
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(Animations.Spring.quick) {
                    isPressed = false
                }
            }
        }) {
            content
                .padding(padding)
                .background(
                    SemanticColors.Backgrounds.elevated(colorScheme)
                        .opacity(isHovered ? 0.95 : 1.0)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            isHovered ? SemanticColors.Accents.primary.opacity(0.3) :
                            SemanticColors.Borders.subtle(colorScheme),
                            lineWidth: isHovered ? 2 : 1
                        )
                )
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .shadow(
                    color: Color.black.opacity(isPressed ? 0.05 : 0.1),
                    radius: isPressed ? 2 : 6,
                    y: isPressed ? 1 : 3
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Animations.Easing.easeInOut) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Gradient Card
public struct GradientCard<Content: View>: View {
    let content: Content
    let gradient: LinearGradient
    let padding: CGFloat
    let cornerRadius: CGFloat
    
    public init(
        gradient: LinearGradient = Theme.Gradients.accent,
        padding: CGFloat = Spacing.lg,
        cornerRadius: CGFloat = Theme.Radius.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.gradient = gradient
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(padding)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
    }
}

// MARK: - View Extension
public extension View {
    /// Wrap view in a card
    func card(
        padding: CGFloat = Spacing.lg,
        cornerRadius: CGFloat = Theme.Radius.lg,
        elevation: Card<Self>.CardElevation = .low
    ) -> some View {
        Card(
            padding: padding,
            cornerRadius: cornerRadius,
            elevation: elevation
        ) {
            self
        }
    }
    
    /// Wrap view in an interactive card
    func interactiveCard(
        padding: CGFloat = Spacing.lg,
        cornerRadius: CGFloat = Theme.Radius.lg,
        action: @escaping () -> Void
    ) -> some View {
        InteractiveCard(
            padding: padding,
            cornerRadius: cornerRadius,
            action: action
        ) {
            self
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            // Basic Card
            Card {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Basic Card")
                        .font(Typography.Heading.h4)
                    Text("This is a simple card with default styling")
                        .font(Typography.Body.medium)
                        .foregroundColor(SemanticColors.Foregrounds.secondary(.dark))
                }
            }
            
            // Interactive Card
            InteractiveCard(action: {
                print("Card tapped")
            }) {
                HStack {
                    Image(systemName: Icons.Actions.play)
                        .font(.system(size: 24))
                        .foregroundColor(SemanticColors.Accents.primary)
                    VStack(alignment: .leading) {
                        Text("Interactive Card")
                            .font(Typography.Heading.h5)
                        Text("Tap to interact")
                            .font(Typography.Body.small)
                            .foregroundColor(SemanticColors.Foregrounds.secondary(.dark))
                    }
                    Spacer()
                    Image(systemName: Icons.Navigation.forward)
                        .foregroundColor(SemanticColors.Foregrounds.tertiary(.dark))
                }
            }
            
            // Gradient Card
            GradientCard {
                VStack(spacing: Spacing.md) {
                    Image(systemName: Icons.AI.sparkles)
                        .font(.system(size: 32))
                    Text("Gradient Card")
                        .font(Typography.Heading.h4)
                    Text("With beautiful gradient background")
                        .font(Typography.Body.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
            }
            
            // Card with high elevation
            Card(elevation: .high) {
                HStack {
                    Circle()
                        .fill(SemanticColors.Accents.secondary)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading) {
                        Text("High Elevation")
                            .font(Typography.Heading.h5)
                        Text("More prominent shadow")
                            .font(Typography.Body.small)
                            .foregroundColor(SemanticColors.Foregrounds.secondary(.dark))
                    }
                    Spacer()
                }
            }
        }
        .padding()
    }
    .background(Color(hsl: 240, 10, 5))
    .preferredColorScheme(.dark)
}