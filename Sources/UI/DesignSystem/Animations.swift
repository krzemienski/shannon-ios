//
//  Animations.swift
//  ClaudeCode
//
//  Reusable animation curves and effects
//

import SwiftUI

/// Animation system with reusable curves and effects
public struct Animations {
    
    // MARK: - Spring Animations
    public struct Spring {
        /// Smooth spring animation
        public static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.8)
        
        /// Bouncy spring animation
        public static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
        
        /// Stiff spring animation
        public static let stiff = Animation.spring(response: 0.3, dampingFraction: 0.9)
        
        /// Slow spring animation
        public static let slow = Animation.spring(response: 0.7, dampingFraction: 0.7)
        
        /// Quick spring animation
        public static let quick = Animation.spring(response: 0.2, dampingFraction: 0.85)
    }
    
    // MARK: - Easing Animations
    public struct Easing {
        /// Ease in animation
        public static let easeIn = Animation.easeIn(duration: 0.3)
        
        /// Ease out animation
        public static let easeOut = Animation.easeOut(duration: 0.3)
        
        /// Ease in-out animation
        public static let easeInOut = Animation.easeInOut(duration: 0.3)
        
        /// Linear animation
        public static let linear = Animation.linear(duration: 0.3)
        
        /// Custom timing curve
        public static func custom(duration: Double, curve: UnitCurve) -> Animation {
            Animation.timingCurve(
                curve.value(at: 0.25),
                curve.value(at: 0.5),
                curve.value(at: 0.75),
                curve.value(at: 1.0),
                duration: duration
            )
        }
    }
    
    // MARK: - Interactive Animations
    public struct Interactive {
        /// Tap animation
        public static let tap = Animation.spring(response: 0.15, dampingFraction: 0.8)
        
        /// Drag animation
        public static let drag = Animation.interactiveSpring(response: 0.3, dampingFraction: 0.7)
        
        /// Swipe animation
        public static let swipe = Animation.spring(response: 0.4, dampingFraction: 0.75)
        
        /// Long press animation
        public static let longPress = Animation.easeInOut(duration: 0.4)
    }
    
    // MARK: - Transition Animations
    public struct Transitions {
        /// Slide transition
        nonisolated(unsafe) public static let slide = AnyTransition.slide.combined(with: .opacity)
        
        /// Scale transition
        nonisolated(unsafe) public static let scale = AnyTransition.scale.combined(with: .opacity)
        
        /// Move and fade transition
        public static func moveAndFade(edge: Edge) -> AnyTransition {
            AnyTransition.move(edge: edge).combined(with: .opacity)
        }
        
        /// Asymmetric transition
        public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition {
            .asymmetric(insertion: insertion, removal: removal)
        }
        
        /// Custom transition
        nonisolated(unsafe) public static let custom = AnyTransition.modifier(
            active: CustomTransitionModifier(progress: 0),
            identity: CustomTransitionModifier(progress: 1)
        )
    }
    
    // MARK: - Durations
    public struct Duration {
        public static let instant: Double = 0.1
        public static let fast: Double = 0.2
        public static let normal: Double = 0.3
        public static let slow: Double = 0.5
        public static let verySlow: Double = 0.8
    }
}

// MARK: - Custom Transition Modifier
private struct CustomTransitionModifier: ViewModifier {
    let progress: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(progress)
            .opacity(progress)
            .rotation3DEffect(
                .degrees((1 - progress) * 90),
                axis: (x: 0, y: 1, z: 0)
            )
    }
}

// MARK: - Animation Effects
// Note: View extension methods are defined in ViewExtensions.swift

// MARK: - Pulse Effect
private struct PulseEffect: ViewModifier {
    let duration: Double
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = 1.1
                }
            }
    }
}

// MARK: - Shake Effect
private struct ShakeEffect: ViewModifier {
    let amount: CGFloat
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onAppear {
                withAnimation(
                    .linear(duration: 0.1)
                    .repeatCount(5, autoreverses: true)
                ) {
                    offset = amount
                }
            }
    }
}

// MARK: - Bounce Effect
private struct BounceEffect: ViewModifier {
    let height: CGFloat
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(
                    .spring(response: 0.3, dampingFraction: 0.3)
                    .repeatForever(autoreverses: false)
                ) {
                    offset = -height
                }
            }
    }
}

// MARK: - Glow Effect
private struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var opacity: Double = 0.5
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: radius)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Shimmer Effect
private struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 200)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2
                }
            }
    }
}