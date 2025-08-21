# Claude Code iOS - Theme System Design Document
## Agent E (UI/UX Designer) - Wave 2 Preparation

---

## 1. Color System Architecture

### 1.1 HSL-Based Token System

We'll implement an HSL-based color system for better programmatic control of colors, with fallback to the specified RGB values from the spec.

```swift
// Core HSL Token Definitions (from TASK_PLAN.md)
struct HSLTokens {
    // Dark backgrounds
    static let background = HSL(h: 240, s: 10, l: 5)     // hsl(240, 10%, 5%)
    static let card = HSL(h: 240, s: 10, l: 8)           // hsl(240, 10%, 8%)
    static let input = HSL(h: 240, s: 10, l: 12)         // hsl(240, 10%, 12%)
    
    // Borders and secondary
    static let border = HSL(h: 240, s: 10, l: 20)        // hsl(240, 10%, 20%)
    static let secondary = HSL(h: 240, s: 10, l: 20)     // hsl(240, 10%, 20%)
    
    // Text colors
    static let foreground = HSL(h: 0, s: 0, l: 95)       // hsl(0, 0%, 95%)
    static let mutedForeground = HSL(h: 0, s: 0, l: 60)  // hsl(0, 0%, 60%)
    
    // Accent colors (cyberpunk theme)
    static let primary = HSL(h: 142, s: 70, l: 45)       // Green accent
    static let accent = HSL(h: 280, s: 70, l: 50)        // Purple accent
    static let destructive = HSL(h: 0, s: 80, l: 60)     // Red for errors
    
    // Additional cyberpunk accents (mapped from spec)
    static let neonCyan = HSL(h: 174, s: 100, l: 50)     // Maps to #00FFE1
    static let neonMagenta = HSL(h: 341, s: 100, l: 58)  // Maps to #FF2A6D
    static let signalLime = HSL(h: 86, s: 100, l: 50)    // Maps to #7CFF00
    static let warning = HSL(h: 39, s: 100, l: 56)       // Maps to #FFB020
}
```

### 1.2 Color Conversion Utilities

```swift
struct HSL {
    let hue: Double        // 0-360
    let saturation: Double // 0-100
    let lightness: Double  // 0-100
    
    func toColor() -> Color {
        // HSL to RGB conversion
        let h = hue / 360.0
        let s = saturation / 100.0
        let l = lightness / 100.0
        
        // Conversion algorithm
        // ... implementation details
        
        return Color(red: r, green: g, blue: b)
    }
    
    // Utility functions for color manipulation
    func lighter(by percent: Double) -> HSL
    func darker(by percent: Double) -> HSL
    func withSaturation(_ saturation: Double) -> HSL
    func withAlpha(_ alpha: Double) -> Color
}
```

### 1.3 Theme Protocol

```swift
protocol ThemeProtocol {
    // Core colors
    var background: Color { get }
    var foreground: Color { get }
    var card: Color { get }
    var border: Color { get }
    
    // Semantic colors
    var primary: Color { get }
    var secondary: Color { get }
    var accent: Color { get }
    var destructive: Color { get }
    var warning: Color { get }
    var success: Color { get }
    
    // Typography
    var fontFamily: String { get }
    var monospacedFont: String { get }
    
    // Spacing
    var spacing: SpacingScale { get }
    
    // Corner radii
    var cornerRadius: CornerRadiusScale { get }
    
    // Shadows
    var shadows: ShadowScale { get }
    
    // Animations
    var animations: AnimationScale { get }
}
```

## 2. Typography System

### 2.1 Font Scales

```swift
struct Typography {
    enum TextStyle {
        case largeTitle    // 34pt, Bold
        case title        // 24pt, Semibold
        case subtitle     // 18pt, Medium
        case body         // 16pt, Regular
        case callout      // 15pt, Regular
        case footnote     // 13pt, Regular
        case caption      // 12pt, Regular
        
        var size: CGFloat {
            switch self {
            case .largeTitle: return 34
            case .title: return 24
            case .subtitle: return 18
            case .body: return 16
            case .callout: return 15
            case .footnote: return 13
            case .caption: return 12
            }
        }
        
        var weight: Font.Weight {
            switch self {
            case .largeTitle: return .bold
            case .title: return .semibold
            case .subtitle: return .medium
            default: return .regular
            }
        }
    }
    
    static let uiFont = "SF Pro Text"
    static let monospacedFont = "JetBrains Mono"
}
```

### 2.2 Dynamic Type Support

```swift
extension Font {
    static func themed(_ style: Typography.TextStyle) -> Font {
        switch style {
        case .largeTitle:
            return .system(size: style.size, weight: style.weight, design: .default)
                .dynamicTypeSize(...DynamicTypeSize.accessibility5)
        // ... other cases
        }
    }
    
    static func themedMonospaced(_ size: CGFloat) -> Font {
        return Font.custom("JetBrains Mono", size: size)
            .dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }
}
```

## 3. Component Design System

### 3.1 Button Styles

```swift
struct CyberpunkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    let variant: ButtonVariant
    
    enum ButtonVariant {
        case primary    // Neon cyan background
        case secondary  // Neon magenta accent
        case ghost      // Transparent with border
        case danger     // Red destructive
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundView(configuration))
            .foregroundColor(foregroundColor)
            .cornerRadius(12)
            .overlay(overlayView(configuration))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
            .shadow(color: shadowColor.opacity(0.3), radius: 8)
    }
}
```

### 3.2 Card Components

```swift
struct CyberpunkCard<Content: View>: View {
    let content: Content
    var glowColor: Color = Theme.neonCyan
    var showGrid: Bool = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(
                ZStack {
                    Theme.card
                    if showGrid {
                        GridOverlay()
                            .opacity(0.05)
                    }
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: glowColor.opacity(0.1), radius: 16)
    }
}
```

### 3.3 Input Fields

```swift
struct CyberpunkTextField: View {
    @Binding var text: String
    let placeholder: String
    @State private var isFocused = false
    @State private var hasError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Theme.input)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(strokeColor, lineWidth: 2)
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            if hasError {
                Text("Error message")
                    .font(.caption)
                    .foregroundColor(Theme.error)
            }
        }
    }
    
    private var strokeColor: Color {
        if hasError {
            return Theme.error
        } else if isFocused {
            return Theme.neonCyan
        } else {
            return Theme.border.opacity(0.3)
        }
    }
}
```

## 4. Animation System

### 4.1 Animation Constants

```swift
struct AnimationDurations {
    static let instant: Double = 0.1
    static let fast: Double = 0.18      // 180ms
    static let normal: Double = 0.24    // 240ms  
    static let slow: Double = 0.35
    static let shimmer: Double = 0.8    // Streaming cursor
}

struct SpringAnimations {
    static let button = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let modal = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let list = Animation.spring(response: 0.35, dampingFraction: 0.75)
}
```

### 4.2 Streaming Animations

```swift
struct StreamingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Theme.neonCyan)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.6)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        Animation
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}
```

## 5. Accessibility Implementation

### 5.1 Color Contrast Compliance

```swift
extension Color {
    func meetsWCAGContrast(against background: Color, level: WCAGLevel = .AA) -> Bool {
        let ratio = contrastRatio(against: background)
        switch level {
        case .AA:
            return ratio >= 4.5  // For normal text
        case .AAA:
            return ratio >= 7.0  // For enhanced contrast
        }
    }
    
    private func contrastRatio(against background: Color) -> Double {
        // Implementation of WCAG contrast ratio calculation
        // ...
    }
}
```

### 5.2 VoiceOver Support

```swift
extension View {
    func accessibleCard(label: String, hint: String? = nil, traits: AccessibilityTraits = .isButton) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
    
    func accessibleStreamingContent(isStreaming: Bool) -> some View {
        self
            .accessibilityLabel(isStreaming ? "Content is streaming" : "Content loaded")
            .accessibilityAddTraits(isStreaming ? .updatesFrequently : [])
    }
}
```

### 5.3 Dynamic Type Support

```swift
struct ScaledFont: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    let style: Typography.TextStyle
    
    func body(content: Content) -> some View {
        content
            .font(.themed(style))
            .minimumScaleFactor(0.8)
            .lineLimit(nil)
    }
}
```

## 6. Haptic Feedback System

```swift
struct HapticManager {
    static let shared = HapticManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    
    func playSelection() {
        selection.selectionChanged()
    }
    
    func playSuccess() {
        notification.notificationOccurred(.success)
    }
    
    func playError() {
        notification.notificationOccurred(.error)
    }
    
    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        default:
            break
        }
    }
}
```

## 7. Testing Strategy

### 7.1 Theme Testing
- Verify all colors meet WCAG AA contrast requirements
- Test Dynamic Type scaling from XS to XXXL
- Validate dark mode appearance
- Test on different screen sizes (iPhone SE to iPad Pro)

### 7.2 Component Testing
- Unit tests for color conversion utilities
- Snapshot tests for all component states
- Accessibility audit with VoiceOver
- Performance testing for animations (maintain 60fps)

### 7.3 Device Matrix
- iPhone SE (3rd gen) - Smallest screen
- iPhone 15 - Standard size
- iPhone 15 Pro Max - Large screen
- iPad Air - Tablet layout
- iPad Pro 12.9" - Largest screen

## 8. Implementation Roadmap

### Phase 1: Foundation (Tasks 131-160)
1. Create HSL color system and conversion utilities
2. Implement Theme protocol and default cyberpunk theme
3. Set up typography scales with Dynamic Type
4. Create spacing and corner radius constants
5. Implement shadow and animation scales
6. Build theme preview and validation tools

### Phase 2: Core Components (Tasks 501-550)
1. Build button styles (primary, secondary, ghost, danger)
2. Create card and panel components
3. Implement text fields and form controls
4. Build navigation components
5. Create loading and error states
6. Implement modals and sheets

### Phase 3: Chat Components (Tasks 651-700)
1. Build message bubble components
2. Create streaming indicator animations
3. Implement code syntax highlighting
4. Build markdown renderer
5. Create input toolbar
6. Implement auto-scroll and selection

## 9. Code Organization

```
Sources/
├── Theme/
│   ├── Colors/
│   │   ├── HSLColor.swift
│   │   ├── ColorTokens.swift
│   │   └── ColorExtensions.swift
│   ├── Typography/
│   │   ├── FontScales.swift
│   │   └── DynamicType.swift
│   ├── Tokens/
│   │   ├── Spacing.swift
│   │   ├── CornerRadius.swift
│   │   └── Shadows.swift
│   └── CyberpunkTheme.swift
├── Components/
│   ├── Buttons/
│   ├── Cards/
│   ├── Forms/
│   ├── Navigation/
│   └── Chat/
└── Utilities/
    ├── Accessibility/
    ├── Animations/
    └── Haptics/
```

## 10. Performance Targets

- **Animation FPS**: Maintain 60fps for all animations
- **Color Calculations**: < 1ms per conversion
- **Theme Switching**: < 100ms for complete theme change
- **Component Rendering**: < 16ms per frame
- **Memory Usage**: < 10MB for theme system
- **Accessibility**: 100% VoiceOver compatible
- **Contrast**: 100% WCAG AA compliant

---

*Document prepared by Agent E (Swift UI Designer) for Wave 2 implementation*
*Ready to begin implementation once Wave 1 foundation is complete*