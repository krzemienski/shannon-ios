import SwiftUI

/// Theme color definitions using HSL tokens
@MainActor
public struct ThemeColors {
    // MARK: - Brand Colors
    public static let brandPrimary = HSLColor(hue: 9, saturation: 100, lightness: 60)      // Anthropic orange
    public static let brandSecondary = HSLColor(hue: 220, saturation: 60, lightness: 50)   // Complementary blue
    public static let brandAccent = HSLColor(hue: 160, saturation: 50, lightness: 45)      // Accent teal
    
    // MARK: - Gray Scale (Using HSL for consistency)
    public static let gray0 = HSLColor(hue: 0, saturation: 0, lightness: 100)    // White
    public static let gray50 = HSLColor(hue: 0, saturation: 0, lightness: 98)
    public static let gray100 = HSLColor(hue: 0, saturation: 0, lightness: 96)
    public static let gray200 = HSLColor(hue: 0, saturation: 0, lightness: 92)
    public static let gray300 = HSLColor(hue: 0, saturation: 0, lightness: 88)
    public static let gray400 = HSLColor(hue: 0, saturation: 0, lightness: 74)
    public static let gray500 = HSLColor(hue: 0, saturation: 0, lightness: 62)
    public static let gray600 = HSLColor(hue: 0, saturation: 0, lightness: 46)
    public static let gray700 = HSLColor(hue: 0, saturation: 0, lightness: 34)
    public static let gray800 = HSLColor(hue: 0, saturation: 0, lightness: 20)
    public static let gray900 = HSLColor(hue: 0, saturation: 0, lightness: 13)
    public static let gray950 = HSLColor(hue: 0, saturation: 0, lightness: 8)
    public static let gray1000 = HSLColor(hue: 0, saturation: 0, lightness: 0)   // Black
    
    // MARK: - Semantic Colors
    public static let success = HSLColor(hue: 142, saturation: 71, lightness: 45)
    public static let warning = HSLColor(hue: 45, saturation: 100, lightness: 51)
    public static let error = HSLColor(hue: 0, saturation: 84, lightness: 60)
    public static let info = HSLColor(hue: 201, saturation: 96, lightness: 54)
    
    // MARK: - Surface Colors
    public static let surfaceBackground = HSLColor(hue: 0, saturation: 0, lightness: 100)
    public static let surfaceCard = HSLColor(hue: 0, saturation: 0, lightness: 98)
    public static let surfaceOverlay = HSLColor(hue: 0, saturation: 0, lightness: 96, alpha: 0.95)
    
    // MARK: - Text Colors
    public static let textPrimary = HSLColor(hue: 0, saturation: 0, lightness: 13)
    public static let textSecondary = HSLColor(hue: 0, saturation: 0, lightness: 46)
    public static let textTertiary = HSLColor(hue: 0, saturation: 0, lightness: 62)
    public static let textDisabled = HSLColor(hue: 0, saturation: 0, lightness: 74)
    public static let textInverse = HSLColor(hue: 0, saturation: 0, lightness: 100)
    
    // MARK: - Border Colors
    public static let borderDefault = HSLColor(hue: 0, saturation: 0, lightness: 88)
    public static let borderStrong = HSLColor(hue: 0, saturation: 0, lightness: 74)
    public static let borderSubtle = HSLColor(hue: 0, saturation: 0, lightness: 92)
    
    // MARK: - Interactive States
    public static let interactiveHover = HSLColor(hue: 0, saturation: 0, lightness: 96)
    public static let interactivePressed = HSLColor(hue: 0, saturation: 0, lightness: 92)
    public static let interactiveFocus = HSLColor(hue: 201, saturation: 96, lightness: 54, alpha: 0.2)
    public static let interactiveDisabled = HSLColor(hue: 0, saturation: 0, lightness: 96)
    
    // MARK: - Code Editor Colors
    public static let codeBackground = HSLColor(hue: 210, saturation: 12, lightness: 12)
    public static let codeText = HSLColor(hue: 0, saturation: 0, lightness: 88)
    public static let codeKeyword = HSLColor(hue: 286, saturation: 60, lightness: 67)
    public static let codeString = HSLColor(hue: 95, saturation: 38, lightness: 62)
    public static let codeComment = HSLColor(hue: 0, saturation: 0, lightness: 54)
    public static let codeFunction = HSLColor(hue: 207, saturation: 82, lightness: 66)
    public static let codeVariable = HSLColor(hue: 29, saturation: 54, lightness: 61)
    public static let codeOperator = HSLColor(hue: 0, saturation: 0, lightness: 88)
    public static let codeNumber = HSLColor(hue: 29, saturation: 54, lightness: 61)
    public static let codeSelection = HSLColor(hue: 210, saturation: 12, lightness: 25)
    public static let codeLineNumber = HSLColor(hue: 0, saturation: 0, lightness: 46)
}