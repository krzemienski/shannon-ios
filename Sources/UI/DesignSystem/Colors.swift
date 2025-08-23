//
//  Colors.swift
//  ClaudeCode
//
//  Semantic colors for light/dark modes
//

import SwiftUI

/// Semantic color system with support for light and dark modes
public struct SemanticColors {
    
    // MARK: - Color Scheme Detection
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Background Colors
    public struct Backgrounds {
        /// Primary background color
        public static func primary(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 240, 10, 5) : Color(hsl: 0, 0, 98)
        }
        
        /// Secondary background color
        public static func secondary(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 240, 10, 8) : Color(hsl: 0, 0, 95)
        }
        
        /// Tertiary background color
        public static func tertiary(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 240, 10, 12) : Color(hsl: 0, 0, 92)
        }
        
        /// Elevated surface color (cards, modals)
        public static func elevated(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 240, 10, 10) : Color.white
        }
        
        /// Overlay background
        public static func overlay(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.black.opacity(0.7) : Color.black.opacity(0.3)
        }
    }
    
    // MARK: - Foreground Colors
    public struct Foregrounds {
        /// Primary text color
        public static func primary(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 0, 0, 95) : Color(hsl: 0, 0, 10)
        }
        
        /// Secondary text color
        public static func secondary(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 240, 10, 70) : Color(hsl: 0, 0, 40)
        }
        
        /// Tertiary text color
        public static func tertiary(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 240, 10, 50) : Color(hsl: 0, 0, 60)
        }
        
        /// Inverted text color
        public static func inverted(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 0, 0, 10) : Color(hsl: 0, 0, 95)
        }
        
        /// On primary background text
        public static func onPrimary(_ scheme: ColorScheme) -> Color {
            Color.white
        }
    }
    
    // MARK: - Accent Colors
    public struct Accents {
        /// Primary accent (green)
        public static let primary = Color(hsl: 142, 70, 45)
        
        /// Secondary accent (purple)
        public static let secondary = Color(hsl: 280, 70, 50)
        
        /// Tertiary accent (cyan)
        public static let tertiary = Color(hsl: 201, 70, 50)
        
        /// Quaternary accent (amber)
        public static let quaternary = Color(hsl: 45, 70, 50)
    }
    
    // MARK: - State Colors
    public struct States {
        /// Success state
        public static let success = Color(hsl: 142, 70, 45)
        
        /// Warning state
        public static let warning = Color(hsl: 45, 80, 60)
        
        /// Error/Destructive state
        public static let error = Color(hsl: 0, 80, 60)
        
        /// Info state
        public static let info = Color(hsl: 201, 70, 50)
        
        /// Disabled state
        public static func disabled(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 240, 10, 30) : Color(hsl: 0, 0, 70)
        }
    }
    
    // MARK: - Border Colors
    public struct Borders {
        /// Default border
        public static func `default`(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 240, 10, 20) : Color(hsl: 0, 0, 85)
        }
        
        /// Strong border
        public static func strong(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 240, 10, 30) : Color(hsl: 0, 0, 70)
        }
        
        /// Subtle border
        public static func subtle(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 240, 10, 15) : Color(hsl: 0, 0, 92)
        }
        
        /// Focus border
        public static let focus = Color(hsl: 280, 70, 50).opacity(0.5)
    }
    
    // MARK: - Interactive States
    public struct Interactive {
        /// Hover state
        public static func hover(_ base: Color) -> Color {
            base.opacity(0.8)
        }
        
        /// Pressed state
        public static func pressed(_ base: Color) -> Color {
            base.opacity(0.6)
        }
        
        /// Selected state
        public static func selected(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(hsl: 142, 70, 45).opacity(0.2) : Color(hsl: 142, 70, 45).opacity(0.1)
        }
    }
}

// MARK: - Environment Extensions
private struct ColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .dark
}

public extension EnvironmentValues {
    var semanticColorScheme: ColorScheme {
        get { self[ColorSchemeKey.self] }
        set { self[ColorSchemeKey.self] = newValue }
    }
}

// MARK: - View Extensions
public extension View {
    /// Apply semantic color based on color scheme
    func semanticBackground(_ type: KeyPath<SemanticColors.Backgrounds.Type, (ColorScheme) -> Color>) -> some View {
        modifier(SemanticColorModifier(colorPath: type, colorType: .background))
    }
    
    /// Apply semantic foreground color
    func semanticForeground(_ type: KeyPath<SemanticColors.Foregrounds.Type, (ColorScheme) -> Color>) -> some View {
        modifier(SemanticColorModifier(colorPath: type, colorType: .foreground))
    }
}

// MARK: - Helper Modifier
private struct SemanticColorModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    enum ColorType {
        case background
        case foreground
    }
    
    let colorPath: Any
    let colorType: ColorType
    
    func body(content: Content) -> some View {
        switch colorType {
        case .background:
            if let path = colorPath as? KeyPath<SemanticColors.Backgrounds.Type, (ColorScheme) -> Color> {
                content.background(SemanticColors.Backgrounds.self[keyPath: path](colorScheme))
            } else {
                content
            }
        case .foreground:
            if let path = colorPath as? KeyPath<SemanticColors.Foregrounds.Type, (ColorScheme) -> Color> {
                content.foregroundColor(SemanticColors.Foregrounds.self[keyPath: path](colorScheme))
            } else {
                content
            }
        }
    }
}