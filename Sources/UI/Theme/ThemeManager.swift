//
//  ThemeManager.swift
//  ClaudeCode
//
//  Theme management with light/dark mode support and persistence
//

import SwiftUI
import Combine

/// Available themes for the app
public enum AppTheme: String, CaseIterable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case cyberpunk = "Cyberpunk"
    
    var displayName: String {
        rawValue
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark, .cyberpunk:
            return .dark
        }
    }
    
    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .cyberpunk:
            return "cpu.fill"
        }
    }
}

/// Manages app theming and color scheme
@MainActor
public final class ThemeManager: ObservableObject {
    // MARK: - Singleton
    
    public static let shared = ThemeManager()
    
    // MARK: - Published Properties
    
    @AppStorage("selectedTheme") private var selectedThemeRaw: String = AppTheme.cyberpunk.rawValue
    @Published public var currentTheme: AppTheme = .cyberpunk
    @Published public var accentColor: Color = Theme.primary
    @Published public var useDynamicColors: Bool = false
    
    // MARK: - Color Customization
    
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @AppStorage("useDynamicColors") private var useDynamicColorsStored: Bool = false
    @AppStorage("useSystemFont") public var useSystemFont: Bool = false
    @AppStorage("fontSize") public var fontSize: Double = 1.0 // Scale factor
    
    // MARK: - Computed Properties
    
    public var effectiveColorScheme: ColorScheme? {
        currentTheme.colorScheme
    }
    
    public var isDarkMode: Bool {
        switch currentTheme {
        case .dark, .cyberpunk:
            return true
        case .light:
            return false
        case .system:
            return UITraitCollection.current.userInterfaceStyle == .dark
        }
    }
    
    // MARK: - Typography
    
    public var fontScale: CGFloat {
        CGFloat(fontSize)
    }
    
    public func scaledFont(_ baseSize: CGFloat) -> Font {
        let scaledSize = baseSize * fontScale
        if useSystemFont {
            return .system(size: scaledSize)
        } else {
            return .system(size: scaledSize, design: .default)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        loadTheme()
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    public func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        selectedThemeRaw = theme.rawValue
        applyTheme()
    }
    
    public func setAccentColor(_ color: Color) {
        accentColor = color
        if let hex = color.toHex() {
            customAccentColorHex = hex
        }
    }
    
    public func resetAccentColor() {
        accentColor = Theme.primary
        customAccentColorHex = ""
    }
    
    public func toggleDynamicColors() {
        useDynamicColors.toggle()
        useDynamicColorsStored = useDynamicColors
    }
    
    // MARK: - Private Methods
    
    private func loadTheme() {
        if let theme = AppTheme(rawValue: selectedThemeRaw) {
            currentTheme = theme
        }
        
        if !customAccentColorHex.isEmpty,
           let color = Color(hex: customAccentColorHex) {
            accentColor = color
        }
        
        useDynamicColors = useDynamicColorsStored
        
        applyTheme()
    }
    
    private func setupObservers() {
        // Observe system theme changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                if self?.currentTheme == .system {
                    self?.applyTheme()
                }
            }
            .store(in: &cancellables)
    }
    
    private func applyTheme() {
        // Apply theme to UI elements
        let isDark = isDarkMode
        
        // Navigation Bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(isDark ? Theme.card : Color(.systemBackground))
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(isDark ? Theme.foreground : Color(.label))
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(isDark ? Theme.foreground : Color(.label))
        ]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        
        // Tab Bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(isDark ? Theme.card : Color(.systemBackground))
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        
        // Table View
        UITableView.appearance().backgroundColor = UIColor(isDark ? Theme.background : Color(.systemGroupedBackground))
        UITableViewCell.appearance().backgroundColor = UIColor(isDark ? Theme.card : Color(.secondarySystemGroupedBackground))
        
        // Refresh the UI
        objectWillChange.send()
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Color Extensions

extension Color {
    /// Initialize from hex string
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Convert to hex string
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = components.count >= 4 ? Float(components[3]) : 1.0
        
        if a != 1.0 {
            return String(format: "%02lX%02lX%02lX%02lX",
                         lroundf(a * 255),
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255))
        } else {
            return String(format: "%02lX%02lX%02lX",
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255))
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply theme manager to view
    func withThemeManager() -> some View {
        self
            .environmentObject(ThemeManager.shared)
            .preferredColorScheme(ThemeManager.shared.effectiveColorScheme)
            .tint(ThemeManager.shared.accentColor)
    }
}