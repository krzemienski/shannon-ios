//
//  ThemeExtensions.swift
//  ClaudeCode
//
//  Theme convenience extensions for dark cyberpunk theme
//

import SwiftUI

// MARK: - Static Color Properties (Dark Cyberpunk Theme)
extension Theme {
    /// Primary background color - Deep dark blue-black
    static var background: Color {
        Color(hsl: DarkCyberpunk.backgroundHSL.h, DarkCyberpunk.backgroundHSL.s, DarkCyberpunk.backgroundHSL.l)
    }
    
    /// Card background color - Slightly lighter dark
    static var card: Color {
        Color(hsl: DarkCyberpunk.cardHSL.h, DarkCyberpunk.cardHSL.s, DarkCyberpunk.cardHSL.l)
    }
    
    /// Primary brand color - Green accent
    static var primary: Color {
        Color(hsl: DarkCyberpunk.primaryHSL.h, DarkCyberpunk.primaryHSL.s, DarkCyberpunk.primaryHSL.l)
    }
    
    /// Muted text color
    static var muted: Color {
        Color(hsl: DarkCyberpunk.mutedHSL.h, DarkCyberpunk.mutedHSL.s, DarkCyberpunk.mutedHSL.l)
    }
    
    /// Border color - Subtle border
    static var border: Color {
        Color(hsl: DarkCyberpunk.borderHSL.h, DarkCyberpunk.borderHSL.s, DarkCyberpunk.borderHSL.l)
    }
    
    /// Foreground/text color - Almost white
    static var foreground: Color {
        Color(hsl: DarkCyberpunk.foregroundHSL.h, DarkCyberpunk.foregroundHSL.s, DarkCyberpunk.foregroundHSL.l)
    }
    
    /// Accent color - Purple highlight
    static var accent: Color {
        Color(hsl: DarkCyberpunk.accentHSL.h, DarkCyberpunk.accentHSL.s, DarkCyberpunk.accentHSL.l)
    }
    
    /// Destructive/error color - Red
    static var destructive: Color {
        Color(hsl: DarkCyberpunk.destructiveHSL.h, DarkCyberpunk.destructiveHSL.s, DarkCyberpunk.destructiveHSL.l)
    }
    
    /// Info color - Cyan
    static var info: Color {
        Color(hsl: DarkCyberpunk.infoHSL.h, DarkCyberpunk.infoHSL.s, DarkCyberpunk.infoHSL.l)
    }
    
    /// Success color - Green
    static var success: Color {
        Color(hsl: DarkCyberpunk.successHSL.h, DarkCyberpunk.successHSL.s, DarkCyberpunk.successHSL.l)
    }
    
    /// Warning color - Amber
    static var warning: Color {
        Color(hsl: DarkCyberpunk.warningHSL.h, DarkCyberpunk.warningHSL.s, DarkCyberpunk.warningHSL.l)
    }
    
    /// Input border color - Same as border
    static var inputBorder: Color {
        border
    }
    
    /// Code background color - Dark blue-gray for code display
    static var codeBackground: Color {
        Color(hsl: 210, 12, 12)
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius (Alias to ThemeRadius for compatibility)
    struct CornerRadius {
        static let sm = ThemeRadius.sm
        static let md = ThemeRadius.md
        static let lg = ThemeRadius.lg
        static let xl = ThemeRadius.xl
        static let full = CGFloat(9999)
    }
}