//
//  ThemeExtensions.swift
//  ClaudeCode
//
//  Theme convenience extensions for dark cyberpunk theme
//

import SwiftUI

// Import the Theme struct from Theme.swift
// This provides static color properties for the dark cyberpunk theme

// MARK: - Static Color Properties (Dark Cyberpunk Theme - EXACT SPEC VALUES)
extension Theme {
    // MARK: - Background Colors
    /// Primary background color - Very dark blue-gray
    public static var background: Color {
        Color(hsl: DarkCyberpunk.backgroundHSL.h, DarkCyberpunk.backgroundHSL.s, DarkCyberpunk.backgroundHSL.l)
    }
    
    /// Surface color - Slightly lighter than background
    public static var surface: Color {
        Color(hsl: DarkCyberpunk.surfaceHSL.h, DarkCyberpunk.surfaceHSL.s, DarkCyberpunk.surfaceHSL.l)
    }
    
    /// Elevated surfaces - Used for modals, dropdowns
    public static var elevated: Color {
        Color(hsl: DarkCyberpunk.elevatedHSL.h, DarkCyberpunk.elevatedHSL.s, DarkCyberpunk.elevatedHSL.l)
    }
    
    /// Card background color - Same as surface
    public static var card: Color {
        Color(hsl: DarkCyberpunk.cardHSL.h, DarkCyberpunk.cardHSL.s, DarkCyberpunk.cardHSL.l)
    }
    
    // MARK: - Text Colors
    /// Primary text color - Almost white
    public static var textPrimary: Color {
        Color(hsl: DarkCyberpunk.textPrimaryHSL.h, DarkCyberpunk.textPrimaryHSL.s, DarkCyberpunk.textPrimaryHSL.l)
    }
    
    /// Secondary text color - Muted gray
    public static var textSecondary: Color {
        Color(hsl: DarkCyberpunk.textSecondaryHSL.h, DarkCyberpunk.textSecondaryHSL.s, DarkCyberpunk.textSecondaryHSL.l)
    }
    
    /// Tertiary text color - Dim gray
    public static var textTertiary: Color {
        Color(hsl: DarkCyberpunk.textTertiaryHSL.h, DarkCyberpunk.textTertiaryHSL.s, DarkCyberpunk.textTertiaryHSL.l)
    }
    
    /// Foreground/text color (legacy compatibility) - Almost white
    public static var foreground: Color {
        Color(hsl: DarkCyberpunk.foregroundHSL.h, DarkCyberpunk.foregroundHSL.s, DarkCyberpunk.foregroundHSL.l)
    }
    
    // MARK: - Accent Colors (Cyberpunk Theme)
    /// Primary accent - Vibrant purple
    public static var accentPrimary: Color {
        Color(hsl: DarkCyberpunk.accentPrimaryHSL.h, DarkCyberpunk.accentPrimaryHSL.s, DarkCyberpunk.accentPrimaryHSL.l)
    }
    
    /// Secondary accent - Cyan
    public static var accentSecondary: Color {
        Color(hsl: DarkCyberpunk.accentSecondaryHSL.h, DarkCyberpunk.accentSecondaryHSL.s, DarkCyberpunk.accentSecondaryHSL.l)
    }
    
    /// Tertiary accent - Magenta
    public static var accentTertiary: Color {
        Color(hsl: DarkCyberpunk.accentTertiaryHSL.h, DarkCyberpunk.accentTertiaryHSL.s, DarkCyberpunk.accentTertiaryHSL.l)
    }
    
    /// Accent color (legacy compatibility) - Purple highlight
    public static var accent: Color {
        Color(hsl: DarkCyberpunk.accentHSL.h, DarkCyberpunk.accentHSL.s, DarkCyberpunk.accentHSL.l)
    }
    
    // MARK: - Semantic Colors
    /// Success color - Green
    public static var success: Color {
        Color(hsl: DarkCyberpunk.successHSL.h, DarkCyberpunk.successHSL.s, DarkCyberpunk.successHSL.l)
    }
    
    /// Warning color - Yellow
    public static var warning: Color {
        Color(hsl: DarkCyberpunk.warningHSL.h, DarkCyberpunk.warningHSL.s, DarkCyberpunk.warningHSL.l)
    }
    
    /// Error color - Red
    public static var error: Color {
        Color(hsl: DarkCyberpunk.errorHSL.h, DarkCyberpunk.errorHSL.s, DarkCyberpunk.errorHSL.l)
    }
    
    /// Destructive/error color (legacy compatibility) - Red
    public static var destructive: Color {
        Color(hsl: DarkCyberpunk.destructiveHSL.h, DarkCyberpunk.destructiveHSL.s, DarkCyberpunk.destructiveHSL.l)
    }
    
    /// Info color - Blue
    public static var info: Color {
        Color(hsl: DarkCyberpunk.infoHSL.h, DarkCyberpunk.infoHSL.s, DarkCyberpunk.infoHSL.l)
    }
    
    // MARK: - UI Elements
    /// Primary brand color (legacy green) - Green accent
    public static var primary: Color {
        Color(hsl: DarkCyberpunk.primaryHSL.h, DarkCyberpunk.primaryHSL.s, DarkCyberpunk.primaryHSL.l)
    }
    
    /// Border color - Subtle border
    public static var border: Color {
        Color(hsl: DarkCyberpunk.borderHSL.h, DarkCyberpunk.borderHSL.s, DarkCyberpunk.borderHSL.l)
    }
    
    /// Muted background color
    public static var muted: Color {
        Color(hsl: DarkCyberpunk.mutedHSL.h, DarkCyberpunk.mutedHSL.s, DarkCyberpunk.mutedHSL.l)
    }
    
    /// Muted foreground text
    public static var mutedForeground: Color {
        Color(hsl: DarkCyberpunk.mutedForegroundHSL.h, DarkCyberpunk.mutedForegroundHSL.s, DarkCyberpunk.mutedForegroundHSL.l)
    }
    
    /// Input border color - Same as border
    public static var inputBorder: Color {
        border
    }
    
    /// Code background color - Dark blue-gray for code display
    public static var codeBackground: Color {
        Color(hsl: 210, 12, 12)
    }
    
    // MARK: - Spacing (Reference to ThemeSpacing)
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm = Theme.Radius.sm
        static let md = Theme.Radius.md
        static let lg = Theme.Radius.lg
        static let xl = Theme.Radius.xl
        static let full = CGFloat(9999)
    }
}

// The typealias at the bottom of SettingsStore.swift creates Theme = AppTheme
// This enables us to use Theme.primary, Theme.background, etc. throughout the app