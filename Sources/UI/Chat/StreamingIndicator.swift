//
//  StreamingIndicator.swift
//  ClaudeCode
//
//  Animated streaming indicator with token count and stop button
//

import SwiftUI

/// Streaming indicator with animated dots and controls
struct StreamingIndicator: View {
    let tokenCount: Int
    let onStop: () -> Void
    
    @State private var animatingDots = 0
    @State private var pulseAnimation = false
    
    private let dotCount = 3
    
    var body: some View {
        HStack(spacing: ThemeSpacing.md) {
            // Animated dots
            HStack(spacing: ThemeSpacing.xs) {
                ForEach(0..<dotCount, id: \.self) { index in
                    Circle()
                        .fill(Theme.primary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animatingDots == index ? 1.3 : 1.0)
                        .opacity(animatingDots == index ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.5),
                            value: animatingDots
                        )
                }
            }
            
            Text("Claude is thinking...")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.mutedForeground)
            
            Spacer()
            
            // Token count
            if tokenCount > 0 {
                HStack(spacing: ThemeSpacing.xs) {
                    Image(systemName: "cube")
                        .font(.system(size: 12))
                    Text("\(tokenCount)")
                        .font(Theme.Typography.caption2)
                }
                .foregroundColor(Theme.mutedForeground)
                .padding(.horizontal, ThemeSpacing.sm)
                .padding(.vertical, ThemeSpacing.xs)
                .background(Theme.card)
                .cornerRadius(Theme.CornerRadius.xs)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.xs)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
            
            // Stop button
            Button(action: onStop) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.destructive)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ThemeSpacing.md)
        .padding(.vertical, ThemeSpacing.sm)
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.border, lineWidth: 1)
        )
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Start dot animation
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation {
                animatingDots = (animatingDots + 1) % dotCount
            }
        }
        
        // Start pulse animation
        pulseAnimation = true
    }
}

/// Enhanced streaming indicator with more details
struct DetailedStreamingIndicator: View {
    let tokenCount: Int
    let charactersPerSecond: Int
    let estimatedTimeRemaining: TimeInterval?
    let onStop: () -> Void
    let onPause: () -> Void
    
    @State private var isExpanded = false
    @State private var animationPhase = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Main indicator
            HStack(spacing: ThemeSpacing.md) {
                // Animated wave
                StreamingWaveView(phase: animationPhase)
                    .frame(width: 60, height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Streaming response...")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.foreground)
                    
                    if isExpanded {
                        HStack(spacing: ThemeSpacing.md) {
                            // Speed
                            Label("\(charactersPerSecond) c/s", systemImage: "speedometer")
                                .font(Theme.Typography.caption2)
                            
                            // Tokens
                            Label("\(tokenCount) tokens", systemImage: "cube")
                                .font(Theme.Typography.caption2)
                            
                            // Time remaining
                            if let time = estimatedTimeRemaining {
                                Label(formatTime(time), systemImage: "clock")
                                    .font(Theme.Typography.caption2)
                            }
                        }
                        .foregroundColor(Theme.mutedForeground)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: ThemeSpacing.sm) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.mutedForeground)
                    }
                    
                    Button(action: onPause) {
                        Image(systemName: "pause.circle")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.primary)
                    }
                    
                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.destructive)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ThemeSpacing.md)
            .padding(.vertical, ThemeSpacing.sm)
        }
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.primary.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

/// Animated wave view for streaming
struct StreamingWaveView: View {
    let phase: Double
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2
                let wavelength = width / 3
                
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                for x in stride(from: 0, through: width, by: 1) {
                    let relativeX = x / wavelength
                    let sine = sin(relativeX * .pi * 2 + phase)
                    let y = midHeight + sine * (height / 4)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    colors: [
                        Theme.primary.opacity(0.3),
                        Theme.primary,
                        Theme.primary.opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        StreamingIndicator(
            tokenCount: 42,
            onStop: {}
        )
        
        DetailedStreamingIndicator(
            tokenCount: 256,
            charactersPerSecond: 120,
            estimatedTimeRemaining: 15,
            onStop: {},
            onPause: {}
        )
    }
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}