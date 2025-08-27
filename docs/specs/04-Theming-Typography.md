# Claude Code iOS Spec — 04 Theming & Typography

A **cyberpunk/dark** theme with neon accents, high contrast, and motion polish.

---

## 1) Color Tokens (sRGB)

- `Background` **#0B0F17** (near-black blue)
- `Surface` **#111827** (panel)
- `AccentPrimary` **#00FFE1** (neon cyan)
- `AccentSecondary` **#FF2A6D** (neon magenta)
- `SignalLime` **#7CFF00**
- `Warning` **#FFB020**
- `Error` **#FF5C5C**
- `TextPrimary` **#E5E7EB**
- `TextSecondary` **#94A3B8**
- `Divider` rgba(255,255,255,0.08)

### Roles
- Buttons/CTAs: `AccentPrimary`
- Secondary actions: `AccentSecondary`
- Success/OK: `SignalLime`
- Errors/Warnings: `Error` / `Warning`
- Shadows: soft with accent-tinted glow

---

## 2) Typography

- **UI**: SF Pro Text (Title/Body/Caption)
- **Code/Logs**: JetBrains Mono

### Scale
- Title: 24pt / Semibold
- Subtitle: 18pt / Medium
- Body: 16pt / Regular
- Caption: 12pt / Regular

---

## 3) Swift Helpers

```swift
import SwiftUI

struct Theme {
    static let background = Color(red: 0x0B/255, green: 0x0F/255, blue: 0x17/255)
    static let surface = Color(red: 0x11/255, green: 0x18/255, blue: 0x27/255)
    static let accent = Color(red: 0x00/255, green: 0xFF/255, blue: 0xE1/255)
    static let accent2 = Color(red: 0xFF/255, green: 0x2A/255, blue: 0x6D/255)
    static let success = Color(red: 0x7C/255, green: 0xFF/255, blue: 0x00/255)
    static let warning = Color(red: 0xFF/255, green: 0xB0/255, blue: 0x20/255)
    static let error = Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255)
    static let text = Color(red: 0xE5/255, green: 0xE7/255, blue: 0xEB/255)
    static let textSecondary = Color(red: 0x94/255, green: 0xA3/255, blue: 0xB8/255)
}
```

---

## 4) Components & States

- **Buttons**: 12pt radius; neon outline on focus; pressed state darkens surface with inner glow.
- **Cards**: 12pt radius (panels), 24pt for modals; 16pt padding; faint grid overlay optional.
- **Chips/Badges**: Use AccentPrimary/AccentSecondary backgrounds with 80% opacity; white text.
- **Inputs**: Cyan focus ring; error ring in red with helper text.

---

## 5) Motion & Haptics

- Transitions: springy ease; 180–240 ms
- Live streaming cursor shimmer every 800 ms
- Haptics: selection on model pick; success on validated connection

---

## 6) Accessibility

- Text contrast ≥ WCAG AA
- Dynamic Type enabled; test with XL
- VoiceOver labels on streaming rows and tool timeline entries
