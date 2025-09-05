//
//  CardView.swift
//  ClaudeCode
//
//  Reusable card component with variants
//

import SwiftUI

// MARK: - Card View

struct CardView<Content: View>: View {
    let content: Content
    var variant: CardVariant = .default
    var padding: CGFloat? = nil
    var cornerRadius: CGFloat? = nil
    
    init(
        variant: CardVariant = .default,
        padding: CGFloat? = nil,
        cornerRadius: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding ?? ThemeSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundView)
            .cornerRadius(cornerRadius ?? Theme.Radius.lg)
            .overlay(borderOverlay)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch variant {
        case .default:
            Theme.card
        case .elevated:
            LinearGradient(
                colors: [Theme.card, Theme.card.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .interactive:
            Theme.card
        case .outline:
            Theme.background
        case .gradient:
            Theme.Gradients.card
        case .glass:
            Theme.card.opacity(0.6)
                .background(.ultraThinMaterial)
        }
    }
    
    @ViewBuilder
    private var borderOverlay: some View {
        switch variant {
        case .outline:
            RoundedRectangle(cornerRadius: cornerRadius ?? Theme.Radius.lg)
                .stroke(Theme.border, lineWidth: 1)
        case .interactive:
            RoundedRectangle(cornerRadius: cornerRadius ?? Theme.Radius.lg)
                .stroke(Theme.primary.opacity(0.3), lineWidth: 1)
        default:
            EmptyView()
        }
    }
    
    private var shadowColor: Color {
        switch variant {
        case .elevated:
            return Color.black.opacity(0.4)
        case .glass:
            return Theme.primary.opacity(0.1)
        default:
            return Color.black.opacity(0.2)
        }
    }
    
    private var shadowRadius: CGFloat {
        switch variant {
        case .elevated:
            return 8
        case .glass:
            return 12
        default:
            return 4
        }
    }
    
    private var shadowY: CGFloat {
        switch variant {
        case .elevated:
            return 4
        case .glass:
            return 6
        default:
            return 2
        }
    }
}

// MARK: - Card Variants

enum CardVariant {
    case `default`
    case elevated
    case interactive
    case outline
    case gradient
    case glass
}

// MARK: - Interactive Card

struct LegacyInteractiveCard<Content: View>: View {
    let content: Content
    let action: () -> Void
    @State private var isPressed = false
    
    init(
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        CardView(variant: .interactive) {
            content
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(Theme.Animation.spring, value: isPressed)
        .onTapGesture {
            action()
            Theme.Haptics.impact(.light)
        }
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let status: StatusType
    let icon: String?
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        status: StatusType = .normal,
        icon: String? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.status = status
        self.icon = icon
    }
    
    var body: some View {
        CardView {
            HStack(spacing: ThemeSpacing.md) {
                // Icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(statusColor)
                        .frame(width: 44, height: 44)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(Theme.Radius.md)
                }
                
                // Content
                VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                    Text(title)
                        .font(Theme.Typography.captionFont)
                        .foregroundColor(Theme.mutedForeground)
                    
                    Text(value)
                        .font(Theme.Typography.title3Font)
                        .foregroundColor(Theme.foreground)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(Theme.Typography.caption2Font)
                            .foregroundColor(Theme.mutedForeground)
                    }
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .normal:
            return Theme.foreground
        case .success:
            return Theme.success
        case .warning:
            return Theme.warning
        case .error:
            return Theme.destructive
        case .info:
            return Theme.info
        }
    }
}

enum StatusType {
    case normal
    case success
    case warning
    case error
    case info
}

// MARK: - Metric Card

struct LegacyMetricCard: View {
    let title: String
    let value: String
    let change: Double?
    let sparklineData: [Double]?
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: ThemeSpacing.md) {
                // Header
                HStack {
                    Text(title)
                        .font(Theme.Typography.headlineFont)
                        .foregroundColor(Theme.foreground)
                    
                    Spacer()
                    
                    if let change = change {
                        ChangeIndicator(value: change)
                    }
                }
                
                // Value
                Text(value)
                    .font(Theme.Typography.largeTitleFont)
                    .foregroundColor(Theme.primary)
                
                // Sparkline
                if let data = sparklineData {
                    SparklineView(data: data)
                        .frame(height: 40)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ChangeIndicator: View {
    let value: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10))
            
            Text("\(abs(value), specifier: "%.1f")%")
                .font(Theme.Typography.captionFont)
        }
        .foregroundColor(value >= 0 ? Theme.success : Theme.destructive)
        .padding(.horizontal, ThemeSpacing.xs)
        .padding(.vertical, 2)
        .background((value >= 0 ? Theme.success : Theme.destructive).opacity(0.1))
        .cornerRadius(Theme.Radius.sm)
    }
}

struct SparklineView: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1,
                      let maxValue = data.max(),
                      let minValue = data.min(),
                      maxValue > minValue else { return }
                
                let xStep = geometry.size.width / CGFloat(data.count - 1)
                let yRange = maxValue - minValue
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * xStep
                    let y = geometry.size.height - ((value - minValue) / yRange) * geometry.size.height
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Theme.primary, lineWidth: 2)
        }
    }
}

// MARK: - Preview

struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: ThemeSpacing.lg) {
                    // Default card
                    CardView {
                        Text("Default Card")
                            .font(Theme.Typography.headlineFont)
                            .foregroundColor(Theme.foreground)
                    }
                    
                    // Elevated card
                    CardView(variant: .elevated) {
                        VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                            Text("Elevated Card")
                                .font(Theme.Typography.headlineFont)
                                .foregroundColor(Theme.foreground)
                            Text("With shadow and gradient background")
                                .font(Theme.Typography.bodyFont)
                                .foregroundColor(Theme.mutedForeground)
                        }
                    }
                    
                    // Interactive card
                    LegacyInteractiveCard(action: {}) {
                        HStack {
                            Image(systemName: "hand.tap.fill")
                                .foregroundColor(Theme.primary)
                            Text("Tap me!")
                                .font(Theme.Typography.headlineFont)
                                .foregroundColor(Theme.foreground)
                        }
                    }
                    
                    // Status cards
                    StatusCard(
                        title: "API Status",
                        value: "Connected",
                        subtitle: "Latency: 23ms",
                        status: .success,
                        icon: "network"
                    )
                    
                    StatusCard(
                        title: "Memory Usage",
                        value: "87%",
                        subtitle: "420 MB / 512 MB",
                        status: .warning,
                        icon: "memorychip"
                    )
                    
                    // Metric card
                    LegacyMetricCard(
                        title: "Tokens Used",
                        value: "1,234,567",
                        change: 12.5,
                        sparklineData: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
                    )
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
}