//
//  CyberpunkProgress.swift
//  ClaudeCode
//
//  Progress indicators with cyberpunk styling
//

import SwiftUI

/// Progress bar styles
enum ProgressStyle {
    case linear
    case circular
    case segmented
}

/// Linear progress bar
struct CyberpunkProgressBar: View {
    let value: Double
    let total: Double
    let label: String?
    let showPercentage: Bool
    let height: CGFloat
    let animated: Bool
    let variant: BadgeVariant
    
    @State private var animatedValue: Double = 0
    @State private var glowAnimation = false
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }
    
    private var percentage: Int {
        Int(progress * 100)
    }
    
    init(
        value: Double,
        total: Double = 1.0,
        label: String? = nil,
        showPercentage: Bool = true,
        height: CGFloat = 8,
        animated: Bool = true,
        variant: BadgeVariant = .primary
    ) {
        self.value = value
        self.total = total
        self.label = label
        self.showPercentage = showPercentage
        self.height = height
        self.animated = animated
        self.variant = variant
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label and percentage
            if label != nil || showPercentage {
                HStack {
                    if let label = label {
                        Text(label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.hsl(0, 0, 95))
                    }
                    
                    Spacer()
                    
                    if showPercentage {
                        Text("\(percentage)%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(progressColor)
                    }
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color.hsl(240, 10, 15))
                        .overlay(
                            RoundedRectangle(cornerRadius: height / 2)
                                .stroke(Color.hsl(240, 10, 25), lineWidth: 1)
                        )
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    progressColor,
                                    progressColor.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (animated ? animatedValue : progress))
                        .shadow(
                            color: progressColor.opacity(glowAnimation ? 0.6 : 0.3),
                            radius: 4,
                            x: 0,
                            y: 0
                        )
                    
                    // Animated stripe overlay
                    if animated && animatedValue > 0 {
                        RoundedRectangle(cornerRadius: height / 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear,
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * animatedValue)
                            .mask(
                                RoundedRectangle(cornerRadius: height / 2)
                            )
                    }
                }
            }
            .frame(height: height)
            .onAppear {
                if animated {
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                        animatedValue = progress
                    }
                    
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        glowAnimation = true
                    }
                }
            }
            .onChange(of: progress) { newValue in
                if animated {
                    withAnimation(.spring(response: 0.5)) {
                        animatedValue = newValue
                    }
                }
            }
        }
    }
    
    private var progressColor: Color {
        switch variant {
        case .primary, .success:
            return Color.hsl(142, 70, 45)
        case .warning:
            return Color.hsl(45, 80, 60)
        case .error:
            return Color.hsl(0, 80, 60)
        case .info:
            return Color.hsl(201, 70, 50)
        default:
            return Color.hsl(240, 10, 65)
        }
    }
}

/// Circular progress indicator
struct CyberpunkCircularProgress: View {
    let value: Double
    let total: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let showLabel: Bool
    let animated: Bool
    let variant: BadgeVariant
    
    @State private var animatedValue: Double = 0
    @State private var rotationAnimation = false
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }
    
    private var percentage: Int {
        Int(progress * 100)
    }
    
    init(
        value: Double,
        total: Double = 1.0,
        size: CGFloat = 60,
        lineWidth: CGFloat = 4,
        showLabel: Bool = true,
        animated: Bool = true,
        variant: BadgeVariant = .primary
    ) {
        self.value = value
        self.total = total
        self.size = size
        self.lineWidth = lineWidth
        self.showLabel = showLabel
        self.animated = animated
        self.variant = variant
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    Color.hsl(240, 10, 15),
                    lineWidth: lineWidth
                )
            
            // Progress arc
            Circle()
                .trim(from: 0, to: animated ? animatedValue : progress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: progressColor.opacity(0.4),
                    radius: 4,
                    x: 0,
                    y: 0
                )
            
            // Center label
            if showLabel {
                VStack(spacing: 0) {
                    Text("\(percentage)")
                        .font(.system(size: size * 0.3, weight: .bold))
                        .foregroundColor(Color.hsl(0, 0, 95))
                    
                    Text("%")
                        .font(.system(size: size * 0.15, weight: .medium))
                        .foregroundColor(Color.hsl(240, 10, 65))
                }
            }
            
            // Rotating decoration
            if animated && animatedValue > 0 {
                Circle()
                    .fill(progressColor)
                    .frame(width: lineWidth * 2, height: lineWidth * 2)
                    .offset(y: -size / 2 + lineWidth)
                    .rotationEffect(.degrees(rotationAnimation ? 360 : 0))
                    .opacity(animatedValue > 0 ? 1 : 0)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if animated {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                    animatedValue = progress
                }
                
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotationAnimation = true
                }
            }
        }
        .onChange(of: progress) { newValue in
            if animated {
                withAnimation(.spring(response: 0.5)) {
                    animatedValue = newValue
                }
            }
        }
    }
    
    private var progressColor: Color {
        switch variant {
        case .primary, .success:
            return Color.hsl(142, 70, 45)
        case .warning:
            return Color.hsl(45, 80, 60)
        case .error:
            return Color.hsl(0, 80, 60)
        case .info:
            return Color.hsl(201, 70, 50)
        default:
            return Color.hsl(240, 10, 65)
        }
    }
}

/// Loading spinner
struct CyberpunkSpinner: View {
    let size: CGFloat
    let lineWidth: CGFloat
    let speed: Double
    
    @State private var rotation = 0.0
    
    init(
        size: CGFloat = 40,
        lineWidth: CGFloat = 3,
        speed: Double = 1.0
    ) {
        self.size = size
        self.lineWidth = lineWidth
        self.speed = speed
    }
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.hsl(142, 70, 45),
                        Color.hsl(142, 70, 45).opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                )
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .shadow(
                color: Color.hsl(142, 70, 45).opacity(0.4),
                radius: 4,
                x: 0,
                y: 0
            )
            .onAppear {
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 32) {
            // Linear progress bars
            VStack(spacing: 20) {
                Text("Linear Progress")
                    .font(.headline)
                    .foregroundColor(Color.hsl(0, 0, 95))
                
                CyberpunkProgressBar(
                    value: 0.7,
                    label: "Upload Progress"
                )
                
                CyberpunkProgressBar(
                    value: 0.45,
                    label: "Processing",
                    variant: .info
                )
                
                CyberpunkProgressBar(
                    value: 0.9,
                    label: "Almost Done",
                    variant: .success
                )
                
                CyberpunkProgressBar(
                    value: 0.3,
                    label: "Low Battery",
                    height: 12,
                    variant: .warning
                )
                
                CyberpunkProgressBar(
                    value: 0.15,
                    label: "Critical",
                    showPercentage: false,
                    variant: .error
                )
            }
            
            Divider()
                .background(Color.hsl(240, 10, 20))
            
            // Circular progress
            VStack(spacing: 20) {
                Text("Circular Progress")
                    .font(.headline)
                    .foregroundColor(Color.hsl(0, 0, 95))
                
                HStack(spacing: 30) {
                    CyberpunkCircularProgress(
                        value: 0.25,
                        variant: .error
                    )
                    
                    CyberpunkCircularProgress(
                        value: 0.5,
                        variant: .warning
                    )
                    
                    CyberpunkCircularProgress(
                        value: 0.75,
                        variant: .info
                    )
                    
                    CyberpunkCircularProgress(
                        value: 0.95,
                        variant: .success
                    )
                }
                
                HStack(spacing: 30) {
                    CyberpunkCircularProgress(
                        value: 0.6,
                        size: 40,
                        lineWidth: 3,
                        showLabel: false
                    )
                    
                    CyberpunkCircularProgress(
                        value: 0.8,
                        size: 80,
                        lineWidth: 6
                    )
                    
                    CyberpunkCircularProgress(
                        value: 0.4,
                        size: 100,
                        lineWidth: 8,
                        variant: .secondary
                    )
                }
            }
            
            Divider()
                .background(Color.hsl(240, 10, 20))
            
            // Spinners
            VStack(spacing: 20) {
                Text("Loading Spinners")
                    .font(.headline)
                    .foregroundColor(Color.hsl(0, 0, 95))
                
                HStack(spacing: 30) {
                    CyberpunkSpinner(size: 20)
                    CyberpunkSpinner(size: 40)
                    CyberpunkSpinner(size: 60, lineWidth: 4)
                    CyberpunkSpinner(size: 80, lineWidth: 6, speed: 0.5)
                }
            }
        }
        .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.hsl(240, 10, 5))
}