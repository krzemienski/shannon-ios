//
//  ViewExtensions.swift
//  ClaudeCode
//
//  SwiftUI view modifiers and helpers
//

import SwiftUI
import Combine

// MARK: - Keyboard Handling

public extension View {
    /// Hide keyboard when tapped
    func hideKeyboard() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                           to: nil, from: nil, for: nil)
        }
    }
    
    /// Dismiss keyboard on drag
    func dismissKeyboardOnDrag() -> some View {
        self.onAppear {
            UIScrollView.appearance().keyboardDismissMode = .onDrag
        }
    }
    
    /// Move view up when keyboard appears
    func keyboardAdaptive() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAdaptive())
    }
}

struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(Publishers.keyboardHeight) { height in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = height
                }
            }
    }
}

extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification -> CGFloat in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            }
        
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ -> CGFloat in 0 }
        
        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

// MARK: - Safe Area Helpers

public extension View {
    /// Get safe area insets
    func readSafeArea() -> some View {
        self.background(SafeAreaInsetsKey())
    }
}

struct SafeAreaInsetsKey: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: SafeAreaInsetsPreferenceKey.self, 
                          value: geometry.safeAreaInsets)
        }
    }
}

struct SafeAreaInsetsPreferenceKey: PreferenceKey {
    static let defaultValue: EdgeInsets = EdgeInsets()
    static func reduce(value: inout EdgeInsets, nextValue: () -> EdgeInsets) {
        value = nextValue()
    }
}

// MARK: - Conditional Modifiers

public extension View {
    /// Apply modifier conditionally
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, 
                               transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply one of two modifiers based on condition
    @ViewBuilder
    func ifElse<TrueTransform: View, FalseTransform: View>(
        _ condition: Bool,
        ifTrue: (Self) -> TrueTransform,
        ifFalse: (Self) -> FalseTransform
    ) -> some View {
        if condition {
            ifTrue(self)
        } else {
            ifFalse(self)
        }
    }
}

// MARK: - Loading Overlay

public extension View {
    /// Show loading overlay
    func loadingOverlay(_ isLoading: Bool, message: String? = nil) -> some View {
        self.overlay(
            Group {
                if isLoading {
                    LoadingIndicator(message: message, style: .overlay)
                }
            }
        )
        .allowsHitTesting(!isLoading)
    }
}

// MARK: - Error Handling

public extension View {
    /// Show error banner
    func errorBanner(_ error: Binding<Error?>) -> some View {
        self.overlay(
            Group {
                if let error = error.wrappedValue {
                    VStack {
                        ErrorBanner(error: error) {
                            error.wrappedValue = nil
                        }
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: error.wrappedValue)
                }
            }
        )
    }
}

struct ErrorBanner: View {
    let error: Error
    let dismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Theme.destructive)
            
            Text(error.localizedDescription)
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.foreground)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Theme.mutedForeground)
            }
        }
        .padding(ThemeSpacing.md)
        .background(Theme.card)
        .cornerRadius(Theme.Radius.md)
        .shadow(color: Theme.Shadows.medium.color,
               radius: Theme.Shadows.medium.radius,
               x: Theme.Shadows.medium.x,
               y: Theme.Shadows.medium.y)
        .padding(.horizontal, ThemeSpacing.lg)
        .padding(.top, ThemeSpacing.md)
    }
}

// MARK: - Shimmer Effect

public extension View {
    /// Add shimmer loading effect
    func shimmer(_ isActive: Bool = true) -> some View {
        self.modifier(ShimmerModifier(isActive: isActive))
    }
}

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
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
                        .animation(
                            Animation.linear(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: phase
                        )
                        .onAppear {
                            phase = 1
                        }
                    }
                }
            )
    }
}

// MARK: - Card Style

public extension View {
    /// Apply card styling
    func card(padding: CGFloat = ThemeSpacing.lg) -> some View {
        self
            .padding(padding)
            .background(Theme.card)
            .cornerRadius(Theme.Radius.lg)
            .shadow(color: Theme.Shadows.small.color,
                   radius: Theme.Shadows.small.radius,
                   x: Theme.Shadows.small.x,
                   y: Theme.Shadows.small.y)
    }
}

// MARK: - Glow Effect

public extension View {
    /// Add glow effect
    func glow(color: Color = Theme.primary, radius: CGFloat = 10) -> some View {
        self
            .shadow(color: color.opacity(0.3), radius: radius)
            .shadow(color: color.opacity(0.2), radius: radius * 1.5)
            .shadow(color: color.opacity(0.1), radius: radius * 2)
    }
}

// MARK: - Haptic Feedback

public extension View {
    /// Add haptic feedback to tap
    func hapticTap(style: UIImpactFeedbackGenerator.FeedbackStyle = .light, 
                   action: @escaping () -> Void) -> some View {
        self.onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
            action()
        }
    }
}

// MARK: - Redacted Placeholder

public extension View {
    /// Show redacted placeholder while loading
    func placeholder(when isLoading: Bool) -> some View {
        self
            .redacted(reason: isLoading ? .placeholder : [])
            .shimmer(isLoading)
    }
}

// MARK: - Navigation Bar Styling

public extension View {
    /// Style navigation bar
    func navigationBarStyle(
        backgroundColor: Color = Theme.card,
        foregroundColor: Color = Theme.foreground,
        hideBackButton: Bool = false
    ) -> some View {
        self
            .navigationBarBackButtonHidden(hideBackButton)
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Corner Radius with Specific Corners

public extension View {
    /// Apply corner radius to specific corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Animated Gradient

public extension View {
    /// Add animated gradient background
    func animatedGradient(colors: [Color], 
                         animation: Animation = .linear(duration: 3).repeatForever(autoreverses: true)) -> some View {
        self.modifier(AnimatedGradientModifier(colors: colors, animation: animation))
    }
}

struct AnimatedGradientModifier: ViewModifier {
    let colors: [Color]
    let animation: Animation
    @State private var startPoint = UnitPoint.topLeading
    @State private var endPoint = UnitPoint.bottomTrailing
    
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            )
            .onAppear {
                withAnimation(animation) {
                    startPoint = .bottomTrailing
                    endPoint = .topLeading
                }
            }
    }
}

// MARK: - Pulse Animation

public extension View {
    /// Add pulse animation
    func pulse(duration: Double = 1.5) -> some View {
        self.modifier(PulseModifier(duration: duration))
    }
}

struct PulseModifier: ViewModifier {
    let duration: Double
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: duration)
                        .repeatForever(autoreverses: true)
                ) {
                    scale = 1.05
                }
            }
    }
}