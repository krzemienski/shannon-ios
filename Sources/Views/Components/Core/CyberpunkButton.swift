//
//  CyberpunkButton.swift
//  ClaudeCode
//
//  Core button component with cyberpunk styling
//

import SwiftUI

/// Button style variants
enum ButtonVariant {
    case primary
    case secondary
    case ghost
    case destructive
    case success
}

/// Button sizes
enum ButtonSize {
    case small
    case medium
    case large
    
    var padding: EdgeInsets {
        switch self {
        case .small:
            return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        case .medium:
            return EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        case .large:
            return EdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        }
    }
    
    var fontSize: Font {
        switch self {
        case .small:
            return .caption
        case .medium:
            return .body
        case .large:
            return .title3
        }
    }
}

/// Custom cyberpunk-styled button
struct CyberpunkButton: View {
    let title: String
    let icon: String?
    let variant: ButtonVariant
    let size: ButtonSize
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var glowAnimation = false
    
    init(
        _ title: String,
        icon: String? = nil,
        variant: ButtonVariant = .primary,
        size: ButtonSize = .medium,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if !isDisabled && !isLoading {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = true
                }
                action()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(size.fontSize)
                }
                
                Text(title)
                    .font(size.fontSize)
                    .fontWeight(.semibold)
            }
            .padding(size.padding)
            .frame(maxWidth: .infinity)
            .background(backgroundView)
            .foregroundColor(foregroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: variant == .ghost ? 1.5 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(color: shadowColor, radius: glowAnimation ? 12 : 6, x: 0, y: 0)
            .onAppear {
                if variant == .primary {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        glowAnimation = true
                    }
                }
            }
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch variant {
        case .primary:
            LinearGradient(
                colors: [
                    Color.hsl(142, 70, 45),
                    Color.hsl(142, 70, 35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            Color.hsl(240, 10, 20)
        case .ghost:
            Color.clear
        case .destructive:
            LinearGradient(
                colors: [
                    Color.hsl(0, 80, 60),
                    Color.hsl(0, 80, 50)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .success:
            LinearGradient(
                colors: [
                    Color.hsl(142, 70, 45),
                    Color.hsl(142, 70, 35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary, .destructive, .success:
            return .white
        case .secondary:
            return Color.hsl(0, 0, 95)
        case .ghost:
            return Color.hsl(142, 70, 45)
        }
    }
    
    private var borderColor: Color {
        switch variant {
        case .ghost:
            return Color.hsl(142, 70, 45).opacity(0.5)
        default:
            return Color.clear
        }
    }
    
    private var shadowColor: Color {
        switch variant {
        case .primary, .success:
            return Color.hsl(142, 70, 45).opacity(0.4)
        case .destructive:
            return Color.hsl(0, 80, 60).opacity(0.4)
        default:
            return Color.clear
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        CyberpunkButton("Primary Button", icon: "bolt.fill", variant: .primary) {
            print("Primary tapped")
        }
        
        CyberpunkButton("Secondary Button", variant: .secondary) {
            print("Secondary tapped")
        }
        
        CyberpunkButton("Ghost Button", icon: "star", variant: .ghost) {
            print("Ghost tapped")
        }
        
        CyberpunkButton("Destructive", icon: "trash", variant: .destructive, size: .small) {
            print("Delete tapped")
        }
        
        CyberpunkButton("Loading", variant: .primary, isLoading: true) {
            print("Loading")
        }
        
        CyberpunkButton("Disabled", variant: .primary, isDisabled: true) {
            print("Disabled")
        }
    }
    .padding()
    .background(Color.hsl(240, 10, 5))
}