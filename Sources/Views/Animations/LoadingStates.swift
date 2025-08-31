//
//  LoadingStates.swift
//  ClaudeCode
//
//  Loading states, skeleton screens, and progress indicators
//

import SwiftUI

// MARK: - Skeleton View

struct SkeletonView: View {
    @State private var isAnimating = false
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = ThemeRadius.sm) {
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Theme.card,
                        Theme.card.opacity(0.6),
                        Theme.card
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.3)
                        .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.3)
                        .animation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Loading Content View

struct LoadingContentView<Content: View, LoadedContent: View>: View {
    enum LoadingState: Equatable {
        case loading
        case loaded
        case error(String)  // Changed to String for Equatable conformance
        case empty
        
        static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.loaded, .loaded), (.empty, .empty):
                return true
            case let (.error(lhsError), .error(rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    let state: LoadingState
    let content: () -> Content
    let loadedContent: () -> LoadedContent
    let onRetry: (() -> Void)?
    
    init(
        state: LoadingState,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder loadedContent: @escaping () -> LoadedContent,
        onRetry: (() -> Void)? = nil
    ) {
        self.state = state
        self.content = content
        self.loadedContent = loadedContent
        self.onRetry = onRetry
    }
    
    var body: some View {
        ZStack {
            switch state {
            case .loading:
                content()
                    .transition(.opacity)
                
            case .loaded:
                loadedContent()
                    .transition(.opacity)
                
            case .error(let error):
                ErrorStateView(
                    error: error,
                    onRetry: onRetry
                )
                .transition(.opacity)
                
            case .empty:
                SimpleEmptyStateView()
                    .transition(.opacity)
            }
        }
        .animation(.cyberpunkFade, value: state)
    }
}

// MARK: - Chat Message Skeleton

struct ChatMessageSkeleton: View {
    let isUser: Bool
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                // Avatar and name
                HStack(spacing: 8) {
                    if !isUser {
                        SkeletonView()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    }
                    
                    SkeletonView()
                        .frame(width: 80, height: 12)
                    
                    if isUser {
                        SkeletonView()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    }
                }
                
                // Message content
                VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                    SkeletonView()
                        .frame(width: CGFloat.random(in: 150...250), height: 14)
                    SkeletonView()
                        .frame(width: CGFloat.random(in: 100...200), height: 14)
                    SkeletonView()
                        .frame(width: CGFloat.random(in: 80...150), height: 14)
                }
            }
            
            if !isUser { Spacer() }
        }
        .padding()
    }
}

// MARK: - List Item Skeleton

struct ListItemSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView()
                .frame(width: 48, height: 48)
                .cornerRadius(ThemeRadius.sm)
            
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView()
                    .frame(width: 120, height: 14)
                
                SkeletonView()
                    .frame(width: 180, height: 12)
            }
            
            Spacer()
            
            SkeletonView()
                .frame(width: 60, height: 24)
                .cornerRadius(ThemeRadius.xs)
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(ThemeRadius.md)
    }
}

// MARK: - Card Skeleton

struct CardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                SkeletonView()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonView()
                        .frame(width: 100, height: 12)
                    SkeletonView()
                        .frame(width: 60, height: 10)
                }
                
                Spacer()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView()
                    .frame(height: 14)
                SkeletonView()
                    .frame(height: 14)
                SkeletonView()
                    .frame(width: 200, height: 14)
            }
            
            // Footer
            HStack {
                SkeletonView()
                    .frame(width: 80, height: 28)
                    .cornerRadius(ThemeRadius.sm)
                
                SkeletonView()
                    .frame(width: 80, height: 28)
                    .cornerRadius(ThemeRadius.sm)
                
                Spacer()
            }
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(ThemeRadius.md)
    }
}

// MARK: - Progress Indicators

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    
    init(progress: Double, lineWidth: CGFloat = 4, size: CGFloat = 50) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Theme.border, lineWidth: lineWidth)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [Theme.primary, Theme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.cyberpunkSpring, value: progress)
            
            // Progress text
            Text("\(Int(progress * 100))%")
                .font(Theme.Typography.captionFont)
                .foregroundColor(Theme.foreground)
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }
}

struct LinearProgressView: View {
    let progress: Double
    let height: CGFloat
    
    init(progress: Double, height: CGFloat = 4) {
        self.progress = progress
        self.height = height
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Theme.border)
                
                // Progress
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [Theme.primary, Theme.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress)
                    .animation(.cyberpunkSpring, value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Empty State View

struct SimpleEmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(Theme.muted)
            
            Text("No Data")
                .font(Theme.Typography.title2Font)
                .foregroundColor(Theme.foreground)
            
            Text("There's nothing to show here yet")
                .font(Theme.Typography.bodyFont)
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let error: String
    let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(Theme.destructive)
            
            Text("Error")
                .font(Theme.Typography.title2Font)
                .foregroundColor(Theme.foreground)
            
            Text(error)
                .font(Theme.Typography.bodyFont)
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
            
            if let onRetry = onRetry {
                Button {
                    onRetry()
                } label: {
                    Text("Try Again")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .primaryButton()
            }
        }
        .padding()
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                SpinningRing()
                    .frame(width: 50, height: 50)
                
                if let message = message {
                    Text(message)
                        .font(Theme.Typography.bodyFont)
                        .foregroundColor(Theme.foreground)
                }
            }
            .padding(24)
            .background(Theme.card)
            .cornerRadius(ThemeRadius.lg)
            .shadow(color: Color.black.opacity(0.3), radius: 20)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Skeleton examples
            Text("Skeleton Views")
                .font(Theme.Typography.title2Font)
                .foregroundColor(Theme.foreground)
            
            ChatMessageSkeleton(isUser: false)
            ChatMessageSkeleton(isUser: true)
            
            ListItemSkeleton()
            
            CardSkeleton()
            
            // Progress indicators
            Text("Progress Indicators")
                .font(Theme.Typography.title2Font)
                .foregroundColor(Theme.foreground)
                .padding(.top)
            
            HStack(spacing: 30) {
                CircularProgressView(progress: 0.75)
                CircularProgressView(progress: 0.33, lineWidth: 8, size: 70)
            }
            
            LinearProgressView(progress: 0.6)
                .padding(.horizontal)
            
            // Loading states
            Text("Loading States")
                .font(Theme.Typography.title2Font)
                .foregroundColor(Theme.foreground)
                .padding(.top)
            
            HStack(spacing: 20) {
                LoadingDots()
                SpinningRing()
                PulsingCircle()
            }
        }
        .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
}