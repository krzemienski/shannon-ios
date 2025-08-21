//
//  GestureHandlers.swift
//  ClaudeCode
//
//  Custom gesture recognizers and interaction handlers
//

import SwiftUI

// MARK: - Custom Gesture Modifiers

/// Long press with haptic feedback
struct LongPressGesture: ViewModifier {
    let minimumDuration: Double
    let onPressingChanged: ((Bool) -> Void)?
    let onComplete: () -> Void
    
    @State private var isPressing = false
    @State private var hasCompleted = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressing ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressing)
            .onLongPressGesture(
                minimumDuration: minimumDuration,
                pressing: { pressing in
                    isPressing = pressing
                    if pressing {
                        // Start haptic
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        hasCompleted = false
                    }
                    onPressingChanged?(pressing)
                },
                perform: {
                    if !hasCompleted {
                        // Success haptic
                        let notification = UINotificationFeedbackGenerator()
                        notification.notificationOccurred(.success)
                        hasCompleted = true
                        onComplete()
                    }
                }
            )
    }
}

/// Swipe to action gesture
struct SwipeActionGesture: ViewModifier {
    let threshold: CGFloat
    let onSwipeLeft: (() -> Void)?
    let onSwipeRight: (() -> Void)?
    
    @GestureState private var dragOffset: CGSize = .zero
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset + dragOffset.width)
            .animation(.cyberpunkSpring, value: offset)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        let horizontalAmount = value.translation.width
                        
                        if abs(horizontalAmount) > threshold {
                            if horizontalAmount < 0 {
                                onSwipeLeft?()
                            } else {
                                onSwipeRight?()
                            }
                            
                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        }
                        
                        // Reset position
                        withAnimation(.cyberpunkSpring) {
                            offset = 0
                        }
                    }
            )
    }
}

/// Pinch to zoom gesture
struct PinchToZoomGesture: ViewModifier {
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    let minScale: CGFloat
    let maxScale: CGFloat
    let onScaleChanged: ((CGFloat) -> Void)?
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(finalScale + currentScale - 1)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        currentScale = value
                        let totalScale = finalScale + currentScale - 1
                        let clampedScale = min(max(totalScale, minScale), maxScale)
                        onScaleChanged?(clampedScale)
                    }
                    .onEnded { value in
                        finalScale = min(max(finalScale * value, minScale), maxScale)
                        currentScale = 1.0
                    }
            )
    }
}

/// Rotation gesture
struct RotationGestureModifier: ViewModifier {
    @State private var angle: Angle = .zero
    @State private var finalAngle: Angle = .zero
    let onRotationChanged: ((Angle) -> Void)?
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(finalAngle + angle)
            .gesture(
                RotationGesture()
                    .onChanged { value in
                        angle = value
                        onRotationChanged?(finalAngle + angle)
                    }
                    .onEnded { value in
                        finalAngle = finalAngle + value
                        angle = .zero
                    }
            )
    }
}

// MARK: - Pull to Refresh

struct PullToRefreshModifier: ViewModifier {
    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Void
    
    @State private var pullDistance: CGFloat = 0
    @State private var isPulling = false
    private let threshold: CGFloat = 80
    
    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Pull indicator
                    PullToRefreshIndicator(
                        pullDistance: pullDistance,
                        threshold: threshold,
                        isRefreshing: isRefreshing
                    )
                    .frame(height: max(0, pullDistance))
                    
                    // Content
                    content
                        .anchorPreference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: .top
                        ) { $0 }
                }
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                if !isRefreshing {
                    pullDistance = max(0, -offset)
                    
                    if pullDistance > threshold && !isPulling {
                        isPulling = true
                        triggerRefresh()
                    } else if pullDistance <= threshold {
                        isPulling = false
                    }
                }
            }
        }
    }
    
    private func triggerRefresh() {
        withAnimation(.cyberpunkSpring) {
            isRefreshing = true
            pullDistance = threshold
        }
        
        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        
        Task {
            await onRefresh()
            
            await MainActor.run {
                withAnimation(.cyberpunkSpring) {
                    isRefreshing = false
                    pullDistance = 0
                    isPulling = false
                }
            }
        }
    }
}

/// Pull to refresh indicator view
struct PullToRefreshIndicator: View {
    let pullDistance: CGFloat
    let threshold: CGFloat
    let isRefreshing: Bool
    
    private var progress: CGFloat {
        min(pullDistance / threshold, 1.0)
    }
    
    var body: some View {
        ZStack {
            if isRefreshing {
                SpinningRing()
            } else {
                Circle()
                    .trim(from: 0, to: progress * 0.8)
                    .stroke(Theme.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90 + progress * 360))
                    .opacity(progress)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Interactive Card

struct InteractiveCard: View {
    let content: AnyView
    let onTap: () -> Void
    let onLongPress: (() -> Void)?
    let onSwipeLeft: (() -> Void)?
    let onSwipeRight: (() -> Void)?
    
    @State private var isPressed = false
    @State private var dragOffset: CGSize = .zero
    
    init<Content: View>(
        @ViewBuilder content: () -> Content,
        onTap: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil,
        onSwipeLeft: (() -> Void)? = nil,
        onSwipeRight: (() -> Void)? = nil
    ) {
        self.content = AnyView(content())
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onSwipeLeft = onSwipeLeft
        self.onSwipeRight = onSwipeRight
    }
    
    var body: some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .offset(dragOffset)
            .animation(.cyberpunkSpring, value: isPressed)
            .animation(.cyberpunkSpring, value: dragOffset)
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture(
                minimumDuration: 0.5,
                pressing: { pressing in
                    isPressed = pressing
                },
                perform: {
                    onLongPress?()
                }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        let horizontalAmount = value.translation.width
                        
                        if abs(horizontalAmount) > 100 {
                            if horizontalAmount < 0 {
                                onSwipeLeft?()
                            } else {
                                onSwipeRight?()
                            }
                        }
                        
                        dragOffset = .zero
                    }
            )
    }
}

// MARK: - View Extensions

extension View {
    func longPressGesture(
        minimumDuration: Double = 0.5,
        onPressingChanged: ((Bool) -> Void)? = nil,
        onComplete: @escaping () -> Void
    ) -> some View {
        modifier(LongPressGesture(
            minimumDuration: minimumDuration,
            onPressingChanged: onPressingChanged,
            onComplete: onComplete
        ))
    }
    
    func swipeActions(
        threshold: CGFloat = 100,
        onSwipeLeft: (() -> Void)? = nil,
        onSwipeRight: (() -> Void)? = nil
    ) -> some View {
        modifier(SwipeActionGesture(
            threshold: threshold,
            onSwipeLeft: onSwipeLeft,
            onSwipeRight: onSwipeRight
        ))
    }
    
    func pinchToZoom(
        minScale: CGFloat = 0.5,
        maxScale: CGFloat = 3.0,
        onScaleChanged: ((CGFloat) -> Void)? = nil
    ) -> some View {
        modifier(PinchToZoomGesture(
            minScale: minScale,
            maxScale: maxScale,
            onScaleChanged: onScaleChanged
        ))
    }
    
    func rotationGesture(
        onRotationChanged: ((Angle) -> Void)? = nil
    ) -> some View {
        modifier(RotationGestureModifier(
            onRotationChanged: onRotationChanged
        ))
    }
    
    func pullToRefresh(
        isRefreshing: Binding<Bool>,
        onRefresh: @escaping () async -> Void
    ) -> some View {
        modifier(PullToRefreshModifier(
            isRefreshing: isRefreshing,
            onRefresh: onRefresh
        ))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Interactive card example
        InteractiveCard(
            content: {
                VStack {
                    Text("Interactive Card")
                        .font(Theme.Typography.headline)
                    Text("Tap, long press, or swipe")
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.mutedForeground)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Theme.card)
                .cornerRadius(ThemeRadius.md)
            },
            onTap: {
                print("Tapped")
            },
            onLongPress: {
                print("Long pressed")
            },
            onSwipeLeft: {
                print("Swiped left")
            },
            onSwipeRight: {
                print("Swiped right")
            }
        )
        
        // Button with long press
        Button("Long Press Me") {
            print("Normal tap")
        }
        .padding()
        .background(Theme.primary)
        .cornerRadius(ThemeRadius.md)
        .longPressGesture {
            print("Long pressed!")
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
}