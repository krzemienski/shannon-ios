import SwiftUI

/// Main theme configuration with dark cyberpunk color system
/// Based on the Claude Code specification with HSL tokens
public struct Theme {
    
    // MARK: - Dark Cyberpunk Color Values
    // These define the dark cyberpunk theme colors to be used in ThemeExtensions
    
    struct DarkCyberpunk {
        /// Background: Deep dark blue-black - hsl(240, 10%, 5%)
        static let backgroundHSL = (h: 240.0, s: 10.0, l: 5.0)
        
        /// Foreground: Almost white text - hsl(0, 0%, 95%)
        static let foregroundHSL = (h: 0.0, s: 0.0, l: 95.0)
        
        /// Card: Slightly lighter dark for cards - hsl(240, 10%, 8%)
        static let cardHSL = (h: 240.0, s: 10.0, l: 8.0)
        
        /// Border: Subtle border - hsl(240, 10%, 20%)
        static let borderHSL = (h: 240.0, s: 10.0, l: 20.0)
        
        /// Input: Form input background - hsl(240, 10%, 12%)
        static let inputHSL = (h: 240.0, s: 10.0, l: 12.0)
        
        /// Primary: Green accent - hsl(142, 70%, 45%)
        static let primaryHSL = (h: 142.0, s: 70.0, l: 45.0)
        
        /// Secondary: Muted blue - hsl(240, 10%, 20%)
        static let secondaryHSL = (h: 240.0, s: 10.0, l: 20.0)
        
        /// Accent: Purple highlight - hsl(280, 70%, 50%)
        static let accentHSL = (h: 280.0, s: 70.0, l: 50.0)
        
        /// Destructive: Red for errors - hsl(0, 80%, 60%)
        static let destructiveHSL = (h: 0.0, s: 80.0, l: 60.0)
        
        /// Success state - green - hsl(142, 70%, 45%)
        static let successHSL = (h: 142.0, s: 70.0, l: 45.0)
        
        /// Warning state - amber - hsl(45, 80%, 60%)
        static let warningHSL = (h: 45.0, s: 80.0, l: 60.0)
        
        /// Info state - cyan - hsl(201, 70%, 50%)
        static let infoHSL = (h: 201.0, s: 70.0, l: 50.0)
        
        /// Muted foreground - hsl(240, 10%, 65%)
        static let mutedForegroundHSL = (h: 240.0, s: 10.0, l: 65.0)
        
        /// Muted background - hsl(240, 10%, 15%)
        static let mutedHSL = (h: 240.0, s: 10.0, l: 15.0)
    }
    
    // MARK: - Additional Color Properties
    
    /// Overlay for modals and loading states
    public static let overlay = Color.black.opacity(0.7)
    
    /// Ring color for focus states
    public static let ring = Color(hsl: 280, 70, 50).opacity(0.5)
    
    /// Input background
    public static let input = Color(hsl: 240, 10, 12)
    
    /// Secondary color
    public static let secondary = Color(hsl: 240, 10, 20)
    
    /// Muted foreground
    public static let mutedForeground = Color(hsl: 240, 10, 65)
    
    // MARK: - Chart Colors (5 variants as per Task 144)
    
    public static let chart1 = Color(hsl: 142, 70, 45)  // Green (matches primary)
    public static let chart2 = Color(hsl: 280, 70, 50)  // Purple (matches accent)
    public static let chart3 = Color(hsl: 201, 70, 50)  // Cyan
    public static let chart4 = Color(hsl: 45, 70, 50)   // Amber
    public static let chart5 = Color(hsl: 330, 70, 50)  // Pink
    
    // MARK: - Typography System (Task 155)
    
    public struct Typography {
        // Display
        public static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        public static let title = Font.system(size: 28, weight: .bold, design: .default)
        public static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
        public static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        
        // Body
        public static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        public static let body = Font.system(size: 17, weight: .regular, design: .default)
        public static let callout = Font.system(size: 16, weight: .regular, design: .default)
        public static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        public static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        public static let caption = Font.system(size: 12, weight: .regular, design: .default)
        public static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
        
        // Code
        public static let code = Font.system(size: 14, weight: .regular, design: .monospaced)
        public static let codeSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
        public static let codeBlock = Font.system(size: 13, weight: .regular, design: .monospaced)
    }
    
    // MARK: - Animation Constants (Task 156)
    
    public struct Animation {
        public static let easeIn = SwiftUI.Animation.easeIn(duration: 0.2)
        public static let easeOut = SwiftUI.Animation.easeOut(duration: 0.2)
        public static let easeInOut = SwiftUI.Animation.easeInOut(duration: 0.3)
        public static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        public static let bouncy = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
        
        // Durations
        public static let fast: TimeInterval = 0.15
        public static let normal: TimeInterval = 0.3
        public static let slow: TimeInterval = 0.5
    }
    
    // MARK: - Gradient Definitions (Task 151)
    
    public struct Gradients {
        public static let primary = LinearGradient(
            colors: [Theme.primary, Theme.primary.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let accent = LinearGradient(
            colors: [Theme.accent, Theme.primary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let background = LinearGradient(
            colors: [Theme.background, Theme.card],
            startPoint: .top,
            endPoint: .bottom
        )
        
        public static let card = LinearGradient(
            colors: [Theme.card, Theme.card.opacity(0.9)],
            startPoint: .top,
            endPoint: .bottom
        )
        
        public static let shimmer = LinearGradient(
            colors: [
                Theme.card,
                Theme.card.opacity(0.6),
                Theme.card
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Shadow Styles (Task 152)
    
    public struct Shadows {
        public struct ShadowStyle {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
        
        public static let small = ShadowStyle(
            color: Color.black.opacity(0.3),
            radius: 2,
            x: 0,
            y: 1
        )
        
        public static let medium = ShadowStyle(
            color: Color.black.opacity(0.4),
            radius: 4,
            x: 0,
            y: 2
        )
        
        public static let large = ShadowStyle(
            color: Color.black.opacity(0.5),
            radius: 8,
            x: 0,
            y: 4
        )
        
        public static let glow = ShadowStyle(
            color: Color(hsl: 142, 70, 45).opacity(0.3),  // Primary green glow
            radius: 10,
            x: 0,
            y: 0
        )
    }
    
    // MARK: - Corner Radius Constants (Task 153)
    
    public struct Radius {
        public static let none: CGFloat = 0
        public static let xs: CGFloat = 2
        public static let sm: CGFloat = 4
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 12
        public static let xl: CGFloat = 16
        public static let xxl: CGFloat = 24
        public static let round: CGFloat = 9999
    }
    
    // MARK: - Haptic Feedback Patterns (Task 157)
    
    @MainActor
    public struct Haptics {
        public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
        
        public static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }
        
        public static func selection() {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }
}

// MARK: - Spacing Constants (Task 154)
// Defined in separate ThemeSpacing.swift file for comprehensive implementation

// MARK: - Theme Environment Key

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.self
}

public extension EnvironmentValues {
    var theme: Theme.Type {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply theme to the view hierarchy
    func themed() -> some View {
        self
            .preferredColorScheme(.dark) // Always dark for cyberpunk theme
            .environment(\.theme, Theme.self)
    }
    
    /// Apply primary button style
    func primaryButton() -> some View {
        self
            .font(Theme.Typography.headline)
            .foregroundColor(Theme.background)
            .padding(.horizontal, ThemeSpacing.xl)
            .padding(.vertical, ThemeSpacing.md)
            .background(Theme.primary)
            .cornerRadius(Theme.Radius.md)
    }
    
    /// Apply secondary button style
    func secondaryButton() -> some View {
        self
            .font(Theme.Typography.headline)
            .foregroundColor(Theme.foreground)
            .padding(.horizontal, ThemeSpacing.xl)
            .padding(.vertical, ThemeSpacing.md)
            .background(Theme.secondary)
            .cornerRadius(Theme.Radius.md)
    }
    
    /// Apply card style
    func cardStyle() -> some View {
        self
            .padding(ThemeSpacing.lg)
            .background(Theme.card)
            .cornerRadius(Theme.Radius.lg)
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}