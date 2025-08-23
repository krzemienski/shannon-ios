//
//  Color+HSL.swift
//  ClaudeCode
//
//  Extension to support HSL color initialization
//

import SwiftUI

extension Color {
    /// Initialize a Color from HSL values
    /// - Parameters:
    ///   - hue: Hue value (0-360 degrees)
    ///   - saturation: Saturation percentage (0-100)
    ///   - lightness: Lightness percentage (0-100)
    ///   - opacity: Opacity value (0-1), default is 1
    init(hsl hue: Double, _ saturation: Double, _ lightness: Double, opacity: Double = 1.0) {
        let h = hue / 360.0
        let s = saturation / 100.0
        let l = lightness / 100.0
        
        let rgb = Self.hslToRgb(h: h, s: s, l: l)
        self.init(red: rgb.r, green: rgb.g, blue: rgb.b, opacity: opacity)
    }
    
    /// Static helper method for HSL color creation
    /// - Parameters:
    ///   - hue: Hue value (0-360 degrees)
    ///   - saturation: Saturation percentage (0-100)
    ///   - lightness: Lightness percentage (0-100)
    ///   - opacity: Opacity value (0-1), default is 1
    static func hsl(_ hue: Double, _ saturation: Double, _ lightness: Double, opacity: Double = 1.0) -> Color {
        return Color(hsl: hue, saturation, lightness, opacity: opacity)
    }
    
    /// Convert HSL to RGB values
    private static func hslToRgb(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        
        var r: Double = 0
        var g: Double = 0
        var b: Double = 0
        
        switch h * 6 {
        case 0..<1:
            r = c; g = x; b = 0
        case 1..<2:
            r = x; g = c; b = 0
        case 2..<3:
            r = 0; g = c; b = x
        case 3..<4:
            r = 0; g = x; b = c
        case 4..<5:
            r = x; g = 0; b = c
        case 5..<6:
            r = c; g = 0; b = x
        default:
            r = c; g = 0; b = x
        }
        
        return (r: r + m, g: g + m, b: b + m)
    }
}