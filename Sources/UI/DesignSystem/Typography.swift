//
//  Typography.swift
//  ClaudeCode
//
//  Font styles and text hierarchy
//

import SwiftUI

/// Typography system with semantic font styles
public struct Typography {
    
    // MARK: - Display Fonts
    public struct Display {
        /// Extra large display text
        public static let xl = Font.system(size: 48, weight: .bold, design: .default)
        
        /// Large display text
        public static let large = Font.system(size: 36, weight: .bold, design: .default)
        
        /// Medium display text
        public static let medium = Font.system(size: 30, weight: .semibold, design: .default)
        
        /// Small display text
        public static let small = Font.system(size: 24, weight: .semibold, design: .default)
    }
    
    // MARK: - Heading Fonts
    public struct Heading {
        /// H1 heading
        public static let h1 = Font.system(size: 32, weight: .bold, design: .default)
        
        /// H2 heading
        public static let h2 = Font.system(size: 28, weight: .bold, design: .default)
        
        /// H3 heading
        public static let h3 = Font.system(size: 24, weight: .semibold, design: .default)
        
        /// H4 heading
        public static let h4 = Font.system(size: 20, weight: .semibold, design: .default)
        
        /// H5 heading
        public static let h5 = Font.system(size: 18, weight: .medium, design: .default)
        
        /// H6 heading
        public static let h6 = Font.system(size: 16, weight: .medium, design: .default)
    }
    
    // MARK: - Body Fonts
    public struct Body {
        /// Extra large body text
        public static let xl = Font.system(size: 20, weight: .regular, design: .default)
        
        /// Large body text
        public static let large = Font.system(size: 18, weight: .regular, design: .default)
        
        /// Medium body text (default)
        public static let medium = Font.system(size: 16, weight: .regular, design: .default)
        
        /// Small body text
        public static let small = Font.system(size: 14, weight: .regular, design: .default)
        
        /// Extra small body text
        public static let xs = Font.system(size: 12, weight: .regular, design: .default)
    }
    
    // MARK: - Label Fonts
    public struct Label {
        /// Large label
        public static let large = Font.system(size: 14, weight: .medium, design: .default)
        
        /// Medium label
        public static let medium = Font.system(size: 12, weight: .medium, design: .default)
        
        /// Small label
        public static let small = Font.system(size: 11, weight: .medium, design: .default)
    }
    
    // MARK: - Code Fonts
    public struct Code {
        /// Large code text
        public static let large = Font.system(size: 16, weight: .regular, design: .monospaced)
        
        /// Medium code text
        public static let medium = Font.system(size: 14, weight: .regular, design: .monospaced)
        
        /// Small code text
        public static let small = Font.system(size: 12, weight: .regular, design: .monospaced)
        
        /// Inline code
        public static let inline = Font.system(size: 13, weight: .medium, design: .monospaced)
    }
    
    // MARK: - Dynamic Type Support
    public struct Dynamic {
        /// Large title with dynamic type
        public static let largeTitle = Font.largeTitle
        
        /// Title with dynamic type
        public static let title = Font.title
        
        /// Title 2 with dynamic type
        public static let title2 = Font.title2
        
        /// Title 3 with dynamic type
        public static let title3 = Font.title3
        
        /// Headline with dynamic type
        public static let headline = Font.headline
        
        /// Subheadline with dynamic type
        public static let subheadline = Font.subheadline
        
        /// Body with dynamic type
        public static let body = Font.body
        
        /// Callout with dynamic type
        public static let callout = Font.callout
        
        /// Caption with dynamic type
        public static let caption = Font.caption
        
        /// Caption 2 with dynamic type
        public static let caption2 = Font.caption2
        
        /// Footnote with dynamic type
        public static let footnote = Font.footnote
    }
}

// MARK: - Text Style Modifiers
public struct TextStyle: ViewModifier {
    let font: Font
    let color: Color?
    let lineSpacing: CGFloat
    let letterSpacing: CGFloat
    
    public func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
            .lineSpacing(lineSpacing)
            .tracking(letterSpacing)
    }
}

// MARK: - View Extensions
public extension View {
    /// Apply display text style
    func displayText(_ size: KeyPath<Typography.Display.Type, Font> = \.large) -> some View {
        self.font(Typography.Display.self[keyPath: size])
    }
    
    /// Apply heading text style
    func headingText(_ level: KeyPath<Typography.Heading.Type, Font> = \.h1) -> some View {
        self.font(Typography.Heading.self[keyPath: level])
    }
    
    /// Apply body text style
    func bodyText(_ size: KeyPath<Typography.Body.Type, Font> = \.medium) -> some View {
        self.font(Typography.Body.self[keyPath: size])
    }
    
    /// Apply label text style
    func labelText(_ size: KeyPath<Typography.Label.Type, Font> = \.medium) -> some View {
        self.font(Typography.Label.self[keyPath: size])
    }
    
    /// Apply code text style
    func codeText(_ size: KeyPath<Typography.Code.Type, Font> = \.medium) -> some View {
        self.font(Typography.Code.self[keyPath: size])
    }
    
    /// Apply custom text style
    func textStyle(
        font: Font,
        color: Color? = nil,
        lineSpacing: CGFloat = 0,
        letterSpacing: CGFloat = 0
    ) -> some View {
        self.modifier(TextStyle(
            font: font,
            color: color,
            lineSpacing: lineSpacing,
            letterSpacing: letterSpacing
        ))
    }
}

// MARK: - Text Alignment
public extension Text {
    /// Apply semantic text alignment
    func aligned(_ alignment: TextAlignment) -> some View {
        self.multilineTextAlignment(alignment)
    }
    
    /// Apply text truncation
    func truncated(_ lineLimit: Int = 1) -> some View {
        self
            .lineLimit(lineLimit)
            .truncationMode(.tail)
    }
}