import SwiftUI

/// Spacing scale for consistent layout throughout the app
@MainActor
public struct ThemeSpacing {
    /// 0px - No spacing
    public static let none: CGFloat = 0
    
    /// 2px - Minimal spacing
    public static let xxxs: CGFloat = 2
    
    /// 4px - Extra extra small spacing
    public static let xxs: CGFloat = 4
    
    /// 8px - Extra small spacing
    public static let xs: CGFloat = 8
    
    /// 12px - Small spacing
    public static let sm: CGFloat = 12
    
    /// 16px - Medium spacing (base unit)
    public static let md: CGFloat = 16
    
    /// 20px - Medium-large spacing
    public static let ml: CGFloat = 20
    
    /// 24px - Large spacing
    public static let lg: CGFloat = 24
    
    /// 32px - Extra large spacing
    public static let xl: CGFloat = 32
    
    /// 40px - Extra extra large spacing
    public static let xxl: CGFloat = 40
    
    /// 48px - Extra extra extra large spacing
    public static let xxxl: CGFloat = 48
    
    /// 64px - Huge spacing
    public static let huge: CGFloat = 64
    
    /// 80px - Giant spacing
    public static let giant: CGFloat = 80
    
    /// 96px - Massive spacing
    public static let massive: CGFloat = 96
    
    // MARK: - Component Specific Spacing
    
    /// Standard padding for components
    public struct Padding {
        public static let button = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        public static let card = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        public static let listItem = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        public static let input = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        public static let chip = EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
        public static let dialog = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        public static let section = EdgeInsets(top: 24, leading: 12, bottom: 24, trailing: 12)
    }
    
    /// Standard margins for layout
    public struct Margin {
        public static let screen = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        public static let safeArea = EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        public static let content = EdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12)
        public static let section = EdgeInsets(top: 24, leading: 0, bottom: 24, trailing: 0)
    }
    
    /// Standard gaps for stacks and grids
    public struct Gap {
        public static let minimal: CGFloat = 2
        public static let compact: CGFloat = 4
        public static let standard: CGFloat = 8
        public static let comfortable: CGFloat = 12
        public static let spacious: CGFloat = 16
        public static let relaxed: CGFloat = 24
    }
    
    // MARK: - Responsive Spacing
    
    /// Get spacing value based on size class
    public static func responsive(
        compact: CGFloat,
        regular: CGFloat,
        sizeClass: UserInterfaceSizeClass?
    ) -> CGFloat {
        switch sizeClass {
        case .compact:
            return compact
        case .regular:
            return regular
        case .none:
            return compact
        @unknown default:
            return compact
        }
    }
}

// MARK: - Extensions for easy spacing

public extension View {
    /// Apply theme padding
    func themePadding(_ value: CGFloat) -> some View {
        self.padding(value)
    }
    
    /// Apply theme padding with edges
    func themePadding(_ edges: Edge.Set, _ value: CGFloat) -> some View {
        self.padding(edges, value)
    }
    
    /// Apply theme spacing between elements
    func themeSpacing(_ value: CGFloat) -> some View {
        self.padding(.all, value)
    }
}