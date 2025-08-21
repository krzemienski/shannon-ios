import SwiftUI

/// Typography scale and text styles for the theme system
@MainActor
public struct ThemeTypography {
    
    // MARK: - Font Families
    public enum FontFamily {
        case system
        case monospace
        case custom(String)
        
        var name: String {
            switch self {
            case .system:
                return ".AppleSystemUIFont"
            case .monospace:
                return "SF Mono"
            case .custom(let name):
                return name
            }
        }
    }
    
    // MARK: - Font Weights
    public enum FontWeightValue: CGFloat {
        case thin = 100
        case extraLight = 200
        case light = 300
        case regular = 400
        case medium = 500
        case semibold = 600
        case bold = 700
        case extraBold = 800
        case black = 900
        
        var swiftUIWeight: Font.Weight {
            switch self {
            case .thin: return .thin
            case .extraLight: return .ultraLight
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .extraBold: return .heavy
            case .black: return .black
            }
        }
    }
    
    // MARK: - Text Styles
    public struct TextStyle {
        let size: CGFloat
        let lineHeight: CGFloat
        let weight: FontWeightValue
        let letterSpacing: CGFloat
        let family: FontFamily
        
        var font: Font {
            switch family {
            case .system:
                return Font.system(size: size, weight: weight.swiftUIWeight, design: .default)
            case .monospace:
                return Font.system(size: size, weight: weight.swiftUIWeight, design: .monospaced)
            case .custom(let name):
                return Font.custom(name, size: size)
            }
        }
        
        var lineSpacing: CGFloat {
            lineHeight - size
        }
    }
    
    // MARK: - Typography Scale
    
    // Display styles
    public static let displayLarge = TextStyle(
        size: 57,
        lineHeight: 64,
        weight: .regular,
        letterSpacing: -0.25,
        family: .system
    )
    
    public static let displayMedium = TextStyle(
        size: 45,
        lineHeight: 52,
        weight: .regular,
        letterSpacing: 0,
        family: .system
    )
    
    public static let displaySmall = TextStyle(
        size: 36,
        lineHeight: 44,
        weight: .regular,
        letterSpacing: 0,
        family: .system
    )
    
    // Headline styles
    public static let headlineLarge = TextStyle(
        size: 32,
        lineHeight: 40,
        weight: .semibold,
        letterSpacing: 0,
        family: .system
    )
    
    public static let headlineMedium = TextStyle(
        size: 28,
        lineHeight: 36,
        weight: .semibold,
        letterSpacing: 0,
        family: .system
    )
    
    public static let headlineSmall = TextStyle(
        size: 24,
        lineHeight: 32,
        weight: .semibold,
        letterSpacing: 0,
        family: .system
    )
    
    // Title styles
    public static let titleLarge = TextStyle(
        size: 22,
        lineHeight: 28,
        weight: .medium,
        letterSpacing: 0,
        family: .system
    )
    
    public static let titleMedium = TextStyle(
        size: 16,
        lineHeight: 24,
        weight: .medium,
        letterSpacing: 0.15,
        family: .system
    )
    
    public static let titleSmall = TextStyle(
        size: 14,
        lineHeight: 20,
        weight: .medium,
        letterSpacing: 0.1,
        family: .system
    )
    
    // Body styles
    public static let bodyLarge = TextStyle(
        size: 16,
        lineHeight: 24,
        weight: .regular,
        letterSpacing: 0.5,
        family: .system
    )
    
    public static let bodyMedium = TextStyle(
        size: 14,
        lineHeight: 20,
        weight: .regular,
        letterSpacing: 0.25,
        family: .system
    )
    
    public static let bodySmall = TextStyle(
        size: 12,
        lineHeight: 16,
        weight: .regular,
        letterSpacing: 0.4,
        family: .system
    )
    
    // Label styles
    public static let labelLarge = TextStyle(
        size: 14,
        lineHeight: 20,
        weight: .medium,
        letterSpacing: 0.1,
        family: .system
    )
    
    public static let labelMedium = TextStyle(
        size: 12,
        lineHeight: 16,
        weight: .medium,
        letterSpacing: 0.5,
        family: .system
    )
    
    public static let labelSmall = TextStyle(
        size: 11,
        lineHeight: 16,
        weight: .medium,
        letterSpacing: 0.5,
        family: .system
    )
    
    // Code styles
    public static let codeLarge = TextStyle(
        size: 14,
        lineHeight: 20,
        weight: .regular,
        letterSpacing: 0,
        family: .monospace
    )
    
    public static let codeMedium = TextStyle(
        size: 13,
        lineHeight: 18,
        weight: .regular,
        letterSpacing: 0,
        family: .monospace
    )
    
    public static let codeSmall = TextStyle(
        size: 12,
        lineHeight: 16,
        weight: .regular,
        letterSpacing: 0,
        family: .monospace
    )
}