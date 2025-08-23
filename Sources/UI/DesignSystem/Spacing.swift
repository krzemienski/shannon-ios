//
//  Spacing.swift
//  ClaudeCode
//
//  Consistent spacing values
//

import SwiftUI

/// Spacing system with consistent values
public struct Spacing {
    // MARK: - Base Spacing Values
    
    /// 0pt spacing
    public static let zero: CGFloat = 0
    
    /// 2pt spacing
    public static let xxs: CGFloat = 2
    
    /// 4pt spacing
    public static let xs: CGFloat = 4
    
    /// 8pt spacing
    public static let sm: CGFloat = 8
    
    /// 12pt spacing
    public static let md: CGFloat = 12
    
    /// 16pt spacing
    public static let lg: CGFloat = 16
    
    /// 24pt spacing
    public static let xl: CGFloat = 24
    
    /// 32pt spacing
    public static let xxl: CGFloat = 32
    
    /// 48pt spacing
    public static let xxxl: CGFloat = 48
    
    /// 64pt spacing
    public static let huge: CGFloat = 64
    
    // MARK: - Component Spacing
    
    public struct Component {
        /// Spacing between icon and text
        public static let iconText: CGFloat = 8
        
        /// Internal padding for buttons
        public static let buttonPadding: CGFloat = 12
        
        /// Internal padding for cards
        public static let cardPadding: CGFloat = 16
        
        /// Spacing between list items
        public static let listItem: CGFloat = 8
        
        /// Spacing between form fields
        public static let formField: CGFloat = 16
        
        /// Section spacing
        public static let section: CGFloat = 24
    }
    
    // MARK: - Layout Spacing
    
    public struct Layout {
        /// Safe area padding
        public static let safeArea: CGFloat = 16
        
        /// Content margins
        public static let contentMargin: CGFloat = 20
        
        /// Grid spacing
        public static let grid: CGFloat = 16
        
        /// Column spacing
        public static let column: CGFloat = 24
        
        /// Navigation bar height
        public static let navBarHeight: CGFloat = 44
        
        /// Tab bar height
        public static let tabBarHeight: CGFloat = 49
    }
    
    // MARK: - Responsive Spacing
    
    public struct Responsive {
        /// Get spacing based on size class
        public static func spacing(
            compact: CGFloat,
            regular: CGFloat,
            sizeClass: UserInterfaceSizeClass?
        ) -> CGFloat {
            sizeClass == .regular ? regular : compact
        }
        
        /// Get adaptive padding
        public static func padding(
            for sizeClass: UserInterfaceSizeClass?
        ) -> CGFloat {
            sizeClass == .regular ? Layout.contentMargin : Layout.safeArea
        }
    }
}

// MARK: - Edge Insets Extensions
public extension EdgeInsets {
    /// Uniform insets
    static func all(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
    }
    
    /// Horizontal and vertical insets
    static func symmetric(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> EdgeInsets {
        EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
    
    /// Individual insets
    static func only(
        top: CGFloat = 0,
        leading: CGFloat = 0,
        bottom: CGFloat = 0,
        trailing: CGFloat = 0
    ) -> EdgeInsets {
        EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
}

// MARK: - View Extensions
public extension View {
    /// Apply uniform padding
    func padding(_ spacing: CGFloat) -> some View {
        self.padding(EdgeInsets.all(spacing))
    }
    
    /// Apply symmetric padding
    func padding(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> some View {
        self.padding(EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical))
    }
    
    /// Apply responsive padding
    func responsivePadding() -> some View {
        self.modifier(ResponsivePaddingModifier())
    }
    
    /// Add spacing after this view
    func spacing(_ value: CGFloat) -> some View {
        VStack(spacing: 0) {
            self
            Spacer().frame(height: value)
        }
    }
}

// MARK: - Responsive Padding Modifier
private struct ResponsivePaddingModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    func body(content: Content) -> some View {
        content.padding(
            Spacing.Responsive.padding(for: horizontalSizeClass)
        )
    }
}

// MARK: - Spacer Views
public struct SpacerView: View {
    let height: CGFloat?
    let width: CGFloat?
    
    public init(height: CGFloat? = nil, width: CGFloat? = nil) {
        self.height = height
        self.width = width
    }
    
    public var body: some View {
        Spacer()
            .frame(width: width, height: height)
    }
}

// MARK: - Divider with Spacing
public struct SpacedDivider: View {
    let spacing: CGFloat
    let color: Color
    
    public init(
        spacing: CGFloat = Spacing.md,
        color: Color = Color(hsl: 240, 10, 20)
    ) {
        self.spacing = spacing
        self.color = color
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            SpacerView(height: spacing)
            Divider()
                .background(color)
            SpacerView(height: spacing)
        }
    }
}