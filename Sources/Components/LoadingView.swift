//
//  LoadingView.swift
//  ClaudeCode
//
//  Reusable loading indicator component
//

import SwiftUI

struct LoadingView: View {
    let message: String?
    @State private var rotation: Double = 0
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: ThemeSpacing.md) {
            // Custom animated loading indicator
            ZStack {
                Circle()
                    .stroke(Theme.border, lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Theme.primary, Theme.accent]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(
                            .linear(duration: 1)
                            .repeatForever(autoreverses: false)
                        ) {
                            rotation = 360
                        }
                    }
            }
            
            if let message = message {
                Text(message)
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
        }
        .padding(ThemeSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading Overlay Modifier

struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let message: String?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)
            
            if isLoading {
                Theme.overlay
                    .ignoresSafeArea()
                
                LoadingView(message: message)
            }
        }
        .animation(Theme.Animation.easeInOut, value: isLoading)
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        self.modifier(LoadingOverlayModifier(isLoading: isLoading, message: message))
    }
}

#Preview {
    ZStack {
        Theme.background
            .ignoresSafeArea()
        
        VStack(spacing: ThemeSpacing.xl) {
            LoadingView()
            LoadingView(message: "Loading chat...")
        }
    }
}