import SwiftUI

/// Shadow definitions for depth and elevation
@MainActor
public struct ThemeShadows {
    
    /// Shadow configuration
    public struct Shadow: Sendable {
        let color: HSLColor
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        var swiftUIShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (color: color.color, radius: radius, x: x, y: y)
        }
    }
    
    // MARK: - Elevation Levels
    
    /// No shadow
    public static let none = Shadow(
        color: HSLColor(hue: 0, saturation: 0, lightness: 0, alpha: 0),
        radius: 0,
        x: 0,
        y: 0
    )
    
    /// Extra small shadow - elevation 1
    public static let xs = Shadow(
        color: HSLColor(hue: 0, saturation: 0, lightness: 0, alpha: 0.05),
        radius: 2,
        x: 0,
        y: 1
    )
    
    /// Small shadow - elevation 2
    public static let sm = Shadow(
        color: HSLColor(hue: 0, saturation: 0, lightness: 0, alpha: 0.08),
        radius: 4,
        x: 0,
        y: 2
    )
    
    /// Medium shadow - elevation 3
    public static let md = Shadow(
        color: HSLColor(hue: 0, saturation: 0, lightness: 0, alpha: 0.10),
        radius: 8,
        x: 0,
        y: 4
    )
    
    /// Large shadow - elevation 4
    public static let lg = Shadow(
        color: HSLColor(hue: 0, saturation: 0, lightness: 0, alpha: 0.12),
        radius: 12,
        x: 0,
        y: 6
    )
    
    /// Extra large shadow - elevation 5
    public static let xl = Shadow(
        color: HSLColor(hue: 0, saturation: 0, lightness: 0, alpha: 0.15),
        radius: 16,
        x: 0,
        y: 8
    )
    
    /// Extra extra large shadow - elevation 6
    public static let xxl = Shadow(
        color: HSLColor(hue: 0, saturation: 0, lightness: 0, alpha: 0.18),
        radius: 24,
        x: 0,
        y: 12
    )
    
    // MARK: - Component Specific Shadows
    
    @MainActor
    public struct Component {
        /// Card shadow
        public static var card: Shadow { md }
        
        /// Button shadow (elevated)
        public static var button: Shadow { sm }
        
        /// Button shadow (pressed)
        public static var buttonPressed: Shadow { xs }
        
        /// Floating action button
        public static var fab: Shadow { lg }
        
        /// Dialog/Modal shadow
        public static var dialog: Shadow { xxl }
        
        /// Dropdown menu shadow
        public static var dropdown: Shadow { lg }
        
        /// Tooltip shadow
        public static var tooltip: Shadow { sm }
        
        /// Navigation bar shadow
        public static var navbar: Shadow { xs }
        
        /// Sidebar shadow
        public static var sidebar: Shadow { md }
        
        /// Popover shadow
        public static var popover: Shadow { xl }
    }
    
    // MARK: - Inset Shadows
    
    /// Inner shadow for pressed/inset states
    public struct Inset: Sendable {
        public static let sm = Shadow(
            color: HSLColor(hue: 0, saturation: 0, lightness: 0, alpha: 0.06),
            radius: 2,
            x: 0,
            y: -1
        )
        
        public static let md = Shadow(
            color: HSLColor(hue: 0, saturation: 0, lightness: 0, alpha: 0.08),
            radius: 4,
            x: 0,
            y: -2
        )
        
        public static let lg = Shadow(
            color: HSLColor(hue: 0, saturation: 0, lightness: 0, alpha: 0.10),
            radius: 6,
            x: 0,
            y: -3
        )
    }
    
    // MARK: - Colored Shadows
    
    /// Create a colored shadow
    public static func colored(
        color: HSLColor,
        opacity: Double = 0.2,
        radius: CGFloat = 8,
        x: CGFloat = 0,
        y: CGFloat = 4
    ) -> Shadow {
        Shadow(
            color: HSLColor(
                hue: color.hue,
                saturation: color.saturation,
                lightness: color.lightness,
                alpha: opacity
            ),
            radius: radius,
            x: x,
            y: y
        )
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply theme shadow
    func themeShadow(_ shadow: ThemeShadows.Shadow) -> some View {
        let shadowValues = shadow.swiftUIShadow
        return self.shadow(
            color: shadowValues.color,
            radius: shadowValues.radius,
            x: shadowValues.x,
            y: shadowValues.y
        )
    }
    
    /// Apply multiple shadows for layered effect
    func themeLayeredShadow(
        _ shadows: ThemeShadows.Shadow...
    ) -> some View {
        shadows.reduce(AnyView(self)) { view, shadow in
            let shadowValues = shadow.swiftUIShadow
            return AnyView(
                view.shadow(
                    color: shadowValues.color,
                    radius: shadowValues.radius,
                    x: shadowValues.x,
                    y: shadowValues.y
                )
            )
        }
    }
}