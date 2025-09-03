import SwiftUI

/// Border radius values for consistent rounded corners
@MainActor
public struct ThemeRadius {
    /// 0px - No radius (sharp corners)
    public static let none: CGFloat = 0
    
    /// 2px - Minimal radius
    public static let xs: CGFloat = 2
    
    /// 4px - Small radius
    public static let sm: CGFloat = 4
    
    /// 8px - Medium radius (default)
    public static let md: CGFloat = 8
    
    /// 12px - Large radius
    public static let lg: CGFloat = 12
    
    /// 16px - Extra large radius
    public static let xl: CGFloat = 16
    
    /// 20px - Extra extra large radius
    public static let xxl: CGFloat = 20
    
    /// 24px - Huge radius
    public static let huge: CGFloat = 24
    
    /// 9999px - Full radius (pill shape)
    public static let full: CGFloat = 9999
    
    // MARK: - Component Specific Radii
    
    /// Standard radii for components
    public struct Component {
        public static let button: CGFloat = 8
        public static let buttonSmall: CGFloat = 4
        public static let buttonLarge: CGFloat = 12
        public static let buttonPill: CGFloat = 9999
        
        public static let card: CGFloat = 12
        public static let cardSmall: CGFloat = 8
        public static let cardLarge: CGFloat = 16
        
        public static let input: CGFloat = 8
        public static let inputSmall: CGFloat = 4
        public static let inputLarge: CGFloat = 12
        
        public static let chip: CGFloat = 9999
        public static let badge: CGFloat = 4
        public static let avatar: CGFloat = 9999
        
        public static let dialog: CGFloat = 16
        public static let popover: CGFloat = 12
        public static let tooltip: CGFloat = 4
        
        public static let codeBlock: CGFloat = 8
        public static let messageBubble: CGFloat = 12
        public static let sidebar: CGFloat = 0
    }
    
    // MARK: - Shape Styles
    
    /// Create a rounded rectangle shape with theme radius
    public static func roundedRectangle(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
    
    /// Create a rounded rectangle with specific corners
    public static func customRoundedRectangle(
        topLeading: CGFloat = 0,
        topTrailing: CGFloat = 0,
        bottomLeading: CGFloat = 0,
        bottomTrailing: CGFloat = 0
    ) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: topLeading,
            bottomLeadingRadius: bottomLeading,
            bottomTrailingRadius: bottomTrailing,
            topTrailingRadius: topTrailing
        )
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply theme corner radius
    func themeCornerRadius(_ radius: CGFloat) -> some View {
        self.clipShape(ThemeRadius.roundedRectangle(radius))
    }
    
    /// Apply theme corner radius with border
    func themeCornerRadius(_ radius: CGFloat, border: HSLColor, width: CGFloat = 1) -> some View {
        self
            .clipShape(ThemeRadius.roundedRectangle(radius))
            .overlay(
                ThemeRadius.roundedRectangle(radius)
                    .stroke(border.color, lineWidth: width)
            )
    }
    
    /// Apply custom corner radius
    func themeCustomCornerRadius(
        topLeading: CGFloat = 0,
        topTrailing: CGFloat = 0,
        bottomLeading: CGFloat = 0,
        bottomTrailing: CGFloat = 0
    ) -> some View {
        self.clipShape(
            ThemeRadius.customRoundedRectangle(
                topLeading: topLeading,
                topTrailing: topTrailing,
                bottomLeading: bottomLeading,
                bottomTrailing: bottomTrailing
            )
        )
    }
}