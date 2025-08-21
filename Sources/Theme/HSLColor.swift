import SwiftUI

/// HSL color representation for the theme system
public struct HSLColor: Equatable, Hashable, Codable {
    /// Hue component (0-360 degrees)
    public let hue: Double
    /// Saturation component (0-100%)
    public let saturation: Double
    /// Lightness component (0-100%)
    public let lightness: Double
    /// Alpha component (0-1)
    public let alpha: Double
    
    public init(hue: Double, saturation: Double, lightness: Double, alpha: Double = 1.0) {
        self.hue = min(max(hue, 0), 360)
        self.saturation = min(max(saturation, 0), 100)
        self.lightness = min(max(lightness, 0), 100)
        self.alpha = min(max(alpha, 0), 1)
    }
    
    /// Convert HSL to SwiftUI Color
    public var color: Color {
        let h = hue / 360.0
        let s = saturation / 100.0
        let l = lightness / 100.0
        
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
        
        return Color(
            red: r + m,
            green: g + m,
            blue: b + m,
            opacity: alpha
        )
    }
    
    /// Create from hex string
    public static func fromHex(_ hex: String) -> HSLColor? {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        
        return fromRGB(r: r, g: g, b: b)
    }
    
    /// Create from RGB values
    public static func fromRGB(r: Double, g: Double, b: Double, a: Double = 1.0) -> HSLColor {
        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        let delta = maxVal - minVal
        
        var h: Double = 0
        var s: Double = 0
        let l = (maxVal + minVal) / 2
        
        if delta != 0 {
            s = delta / (1 - abs(2 * l - 1))
            
            switch maxVal {
            case r:
                h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            case g:
                h = (b - r) / delta + 2
            case b:
                h = (r - g) / delta + 4
            default:
                break
            }
            
            h = h / 6
            if h < 0 { h += 1 }
        }
        
        return HSLColor(
            hue: h * 360,
            saturation: s * 100,
            lightness: l * 100,
            alpha: a
        )
    }
}