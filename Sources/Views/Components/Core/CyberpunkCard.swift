//
//  CyberpunkCard.swift
//  ClaudeCode
//
//  Card component with cyberpunk styling and interactive features
//

import SwiftUI

/// Card elevation levels
enum CardElevation {
    case flat
    case raised
    case elevated
    case floating
    
    var shadowRadius: CGFloat {
        switch self {
        case .flat: return 0
        case .raised: return 4
        case .elevated: return 8
        case .floating: return 16
        }
    }
    
    var shadowOpacity: Double {
        switch self {
        case .flat: return 0
        case .raised: return 0.1
        case .elevated: return 0.15
        case .floating: return 0.2
        }
    }
}

/// Card interaction state
enum CardInteraction {
    case none
    case hover
    case pressed
    case selected
}

/// Custom cyberpunk-styled card container
struct CyberpunkCard<Content: View>: View {
    let content: Content
    let elevation: CardElevation
    let isInteractive: Bool
    let showBorder: Bool
    let glowEffect: Bool
    let onTap: (() -> Void)?
    
    @State private var interaction: CardInteraction = .none
    @State private var glowAnimation = false
    
    init(
        elevation: CardElevation = .raised,
        isInteractive: Bool = false,
        showBorder: Bool = false,
        glowEffect: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.elevation = elevation
        self.isInteractive = isInteractive
        self.showBorder = showBorder
        self.glowEffect = glowEffect
        self.onTap = onTap
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.hsl(240, 10, 8),
                                Color.hsl(240, 10, 10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        borderColor,
                        lineWidth: showBorder ? 1 : 0
                    )
            )
            .overlay(
                // Interactive highlight overlay
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        interaction == .hover ?
                        Color.hsl(142, 70, 45).opacity(0.05) :
                        interaction == .pressed ?
                        Color.hsl(142, 70, 45).opacity(0.1) :
                        Color.clear
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(
                color: shadowColor,
                radius: elevation.shadowRadius,
                x: 0,
                y: elevation == .floating ? 8 : 4
            )
            .scaleEffect(interaction == .pressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3), value: interaction)
            .onTapGesture {
                if isInteractive {
                    withAnimation(.spring(response: 0.2)) {
                        interaction = .pressed
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        interaction = .hover
                        onTap?()
                    }
                }
            }
            .onHover { hovering in
                if isInteractive {
                    withAnimation(.spring(response: 0.3)) {
                        interaction = hovering ? .hover : .none
                    }
                }
            }
            .onAppear {
                if glowEffect {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        glowAnimation = true
                    }
                }
            }
    }
    
    private var borderColor: Color {
        if interaction == .selected {
            return Color.hsl(142, 70, 45)
        } else if showBorder {
            return Color.hsl(240, 10, 20)
        } else {
            return Color.clear
        }
    }
    
    private var shadowColor: Color {
        if glowEffect && glowAnimation {
            return Color.hsl(142, 70, 45).opacity(0.3)
        } else {
            return Color.black.opacity(elevation.shadowOpacity)
        }
    }
}

/// Pre-styled card with header
struct CyberpunkHeaderCard<Header: View, Content: View>: View {
    let header: Header
    let content: Content
    let elevation: CardElevation
    
    init(
        elevation: CardElevation = .raised,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.elevation = elevation
        self.header = header()
        self.content = content()
    }
    
    var body: some View {
        CyberpunkCard(elevation: elevation) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                header
                    .padding()
                    .background(Color.hsl(240, 10, 6))
                
                Divider()
                    .background(Color.hsl(240, 10, 20))
                
                // Content
                content
                    .padding()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 24) {
            // Basic Card
            CyberpunkCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Basic Card")
                        .font(.headline)
                        .foregroundColor(Color.hsl(0, 0, 95))
                    Text("This is a simple card with default elevation")
                        .font(.body)
                        .foregroundColor(Color.hsl(240, 10, 65))
                }
                .padding()
            }
            
            // Interactive Card
            CyberpunkCard(
                elevation: .elevated,
                isInteractive: true,
                showBorder: true,
                onTap: {
                    print("Card tapped")
                }
            ) {
                HStack {
                    Image(systemName: "cpu")
                        .font(.largeTitle)
                        .foregroundColor(Color.hsl(142, 70, 45))
                    
                    VStack(alignment: .leading) {
                        Text("Interactive Card")
                            .font(.headline)
                            .foregroundColor(Color.hsl(0, 0, 95))
                        Text("Tap to interact")
                            .font(.caption)
                            .foregroundColor(Color.hsl(240, 10, 65))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color.hsl(240, 10, 45))
                }
                .padding()
            }
            
            // Glowing Card
            CyberpunkCard(
                elevation: .floating,
                glowEffect: true
            ) {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color.hsl(142, 70, 45))
                    
                    Text("Glowing Card")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color.hsl(0, 0, 95))
                    
                    Text("This card has a pulsing glow effect")
                        .font(.body)
                        .foregroundColor(Color.hsl(240, 10, 65))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            
            // Header Card
            CyberpunkHeaderCard(elevation: .elevated) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(Color.hsl(142, 70, 45))
                    Text("Document")
                        .font(.headline)
                        .foregroundColor(Color.hsl(0, 0, 95))
                    Spacer()
                    Text("2 hours ago")
                        .font(.caption)
                        .foregroundColor(Color.hsl(240, 10, 45))
                }
            } content: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Content goes here")
                        .foregroundColor(Color.hsl(0, 0, 95))
                    Text("This card has a distinct header section")
                        .font(.caption)
                        .foregroundColor(Color.hsl(240, 10, 65))
                }
            }
        }
        .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.hsl(240, 10, 5))
}