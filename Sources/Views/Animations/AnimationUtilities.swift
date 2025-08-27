//
//  AnimationUtilities.swift
//  ClaudeCode
//
//  Custom animations and transition utilities
//

import SwiftUI

// MARK: - Animation Extensions

extension Animation {
    /// Smooth spring animation with cyberpunk feel
    static let cyberpunkSpring = Animation.spring(
        response: 0.4,
        dampingFraction: 0.8,
        blendDuration: 0
    )
    
    /// Quick bounce animation
    static let cyberpunkBounce = Animation.spring(
        response: 0.3,
        dampingFraction: 0.6,
        blendDuration: 0
    )
    
    /// Smooth fade animation
    static let cyberpunkFade = Animation.easeInOut(duration: 0.3)
    
    /// Glitch-style animation
    static let glitch = Animation.easeInOut(duration: 0.1)
        .repeatCount(3, autoreverses: true)
}

// MARK: - Custom Transitions

extension AnyTransition {
    /// Slide and fade transition
    static var slideAndFade: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    /// Scale and fade transition
    static var scaleAndFade: AnyTransition {
        AnyTransition.scale(scale: 0.8).combined(with: .opacity)
    }
    
    /// Cyberpunk glitch transition
    static var glitch: AnyTransition {
        AnyTransition.modifier(
            active: GlitchModifier(progress: 0),
            identity: GlitchModifier(progress: 1)
        )
    }
    
    /// Neon glow transition
    static var neonGlow: AnyTransition {
        AnyTransition.modifier(
            active: NeonGlowModifier(intensity: 0),
            identity: NeonGlowModifier(intensity: 1)
        )
    }
}

// MARK: - Custom View Modifiers

/// Pulsing animation modifier
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    let duration: Double
    let scale: CGFloat
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? scale : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

/// Shimmer loading effect modifier
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 400 - 200)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

/// Glitch effect modifier
struct GlitchModifier: ViewModifier {
    let progress: Double
    
    func body(content: Content) -> some View {
        content
            .overlay(
                content
                    .foregroundColor(Color.hsl(142, 70, 45))
                    .offset(x: progress * 2, y: 0)
                    .opacity(1 - progress)
            )
            .overlay(
                content
                    .foregroundColor(Color.hsl(280, 70, 50))
                    .offset(x: -progress * 2, y: 0)
                    .opacity(1 - progress)
            )
    }
}

/// Neon glow effect modifier
struct NeonGlowModifier: ViewModifier {
    let intensity: Double
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: Color.hsl(142, 70, 45).opacity(intensity * 0.8),
                radius: 10 * intensity,
                x: 0,
                y: 0
            )
            .shadow(
                color: Color.hsl(142, 70, 45).opacity(intensity * 0.4),
                radius: 20 * intensity,
                x: 0,
                y: 0
            )
    }
}

/// Typing animation modifier
struct TypewriterModifier: ViewModifier {
    let text: String
    @State private var displayedText = ""
    @State private var currentIndex = 0
    let speed: Double
    
    func body(content: Content) -> some View {
        Text(displayedText)
            .onAppear {
                typeText()
            }
    }
    
    private func typeText() {
        guard currentIndex < text.count else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            let index = text.index(text.startIndex, offsetBy: currentIndex)
            displayedText.append(text[index])
            currentIndex += 1
            typeText()
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply pulse animation
    func pulse(duration: Double = 1.5, scale: CGFloat = 1.05) -> some View {
        modifier(PulseModifier(duration: duration, scale: scale))
    }
    
    /// Apply shimmer effect
    func shimmer(duration: Double = 1.5) -> some View {
        modifier(ShimmerModifier(duration: duration))
    }
    
    /// Apply typewriter animation
    func typewriter(_ text: String, speed: Double = 0.05) -> some View {
        modifier(TypewriterModifier(text: text, speed: speed))
    }
    
    /// Apply neon glow
    func neonGlow(intensity: Double = 1.0) -> some View {
        modifier(NeonGlowModifier(intensity: intensity))
    }
    
    /// Animate on appear with custom animation
    func animateOnAppear<V: Equatable>(
        _ animation: Animation = .cyberpunkSpring,
        value: V,
        delay: Double = 0
    ) -> some View {
        self.animation(animation.delay(delay), value: value)
    }
}

// MARK: - Loading Animations

struct LoadingDots: View {
    @State private var isAnimating = [false, false, false]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating[index] ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: isAnimating[index]
                    )
            }
        }
        .onAppear {
            for index in 0..<3 {
                isAnimating[index] = true
            }
        }
    }
}

struct PulsingCircle: View {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Circle()
            .stroke(Theme.primary, lineWidth: 2)
            .frame(width: 40, height: 40)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.0)
                    .repeatForever(autoreverses: false)
                ) {
                    scale = 2.0
                    opacity = 0.0
                }
            }
    }
}

struct SpinningRing: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Theme.primary,
                        Theme.primary.opacity(0.5),
                        Theme.primary.opacity(0)
                    ]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 30, height: 30)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(
                    .linear(duration: 1.0)
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Page Transition Manager

class PageTransitionManager: ObservableObject {
    @Published var currentPage = 0
    @Published var transition: AnyTransition = .slideAndFade
    
    func nextPage(with transition: AnyTransition = .slideAndFade) {
        self.transition = transition
        withAnimation(.cyberpunkSpring) {
            currentPage += 1
        }
    }
    
    func previousPage(with transition: AnyTransition = .slideAndFade) {
        self.transition = transition
        withAnimation(.cyberpunkSpring) {
            currentPage -= 1
        }
    }
    
    func setPage(_ page: Int, with transition: AnyTransition = .slideAndFade) {
        self.transition = transition
        withAnimation(.cyberpunkSpring) {
            currentPage = page
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Loading animations
        HStack(spacing: 40) {
            LoadingDots()
            PulsingCircle()
            SpinningRing()
        }
        
        // Text animations
        SwiftUI.Text("Cyberpunk UI")
            .font(Theme.Typography.title as Font)
            .foregroundColor(Theme.primary)
            .pulse()
        
        SwiftUI.Text("Loading...")
            .font(Theme.Typography.body)
            .foregroundColor(Theme.foreground)
            .shimmer()
        
        // Button with animation
        Button {
            // Action
        } label: {
            Text("Glowing Button")
                .padding()
                .background(Theme.primary)
                .cornerRadius(ThemeRadius.md)
        }
        .neonGlow()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
}