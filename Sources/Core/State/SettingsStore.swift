//
//  SettingsStore.swift
//  ClaudeCode
//
//  Centralized settings management with UserDefaults and Keychain
//

import SwiftUI
import Combine

/// Manages application settings with UserDefaults and Keychain integration
@MainActor
final class SettingsStore: ObservableObject {
    
    // MARK: - API Settings
    @Published var apiKey: String? {
        didSet {
            Task {
                await saveAPIKey()
            }
        }
    }
    
    @Published var baseURL: String = APIConfig.defaultBaseURL {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: Keys.baseURL)
        }
    }
    
    /// Computed property for API base URL compatibility
    var apiBaseURL: String? {
        return baseURL
    }
    
    @Published var selectedModel: String = "claude-3-5-haiku-20241022" {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: Keys.selectedModel)
        }
    }
    
    // MARK: - SSH Settings
    @Published var sshEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(sshEnabled, forKey: Keys.sshEnabled)
        }
    }
    
    @Published var sshHost: String = "" {
        didSet {
            UserDefaults.standard.set(sshHost, forKey: Keys.sshHost)
        }
    }
    
    @Published var sshPort: Int = 22 {
        didSet {
            UserDefaults.standard.set(sshPort, forKey: Keys.sshPort)
        }
    }
    
    @Published var sshUsername: String = "" {
        didSet {
            UserDefaults.standard.set(sshUsername, forKey: Keys.sshUsername)
        }
    }
    
    @Published var sshPrivateKey: String? {
        didSet {
            Task {
                await saveSSHPrivateKey()
            }
        }
    }
    
    @Published var sshPassphrase: String? {
        didSet {
            Task {
                await saveSSHPassphrase()
            }
        }
    }
    
    // MARK: - App Preferences
    @Published var theme: AppTheme = .system {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme)
            applyTheme()
        }
    }
    
    @Published var fontSize: FontSize = .medium {
        didSet {
            UserDefaults.standard.set(fontSize.rawValue, forKey: Keys.fontSize)
        }
    }
    
    @Published var enableHaptics: Bool = true {
        didSet {
            UserDefaults.standard.set(enableHaptics, forKey: Keys.enableHaptics)
        }
    }
    
    @Published var enableSounds: Bool = true {
        didSet {
            UserDefaults.standard.set(enableSounds, forKey: Keys.enableSounds)
        }
    }
    
    // MARK: - Chat Settings
    @Published var temperature: Double = 0.7 {
        didSet {
            UserDefaults.standard.set(temperature, forKey: Keys.temperature)
        }
    }
    
    @Published var maxTokens: Int = 4096 {
        didSet {
            UserDefaults.standard.set(maxTokens, forKey: Keys.maxTokens)
        }
    }
    
    @Published var streamResponses: Bool = true {
        didSet {
            UserDefaults.standard.set(streamResponses, forKey: Keys.streamResponses)
        }
    }
    
    @Published var saveHistory: Bool = true {
        didSet {
            UserDefaults.standard.set(saveHistory, forKey: Keys.saveHistory)
        }
    }
    
    // MARK: - Background Settings
    @Published var enableBackgroundRefresh: Bool = true {
        didSet {
            UserDefaults.standard.set(enableBackgroundRefresh, forKey: Keys.enableBackgroundRefresh)
        }
    }
    
    @Published var enableTelemetry: Bool = false {
        didSet {
            UserDefaults.standard.set(enableTelemetry, forKey: Keys.enableTelemetry)
        }
    }
    
    // MARK: - Developer Settings
    @Published var debugMode: Bool = false {
        didSet {
            UserDefaults.standard.set(debugMode, forKey: Keys.debugMode)
        }
    }
    
    @Published var showNetworkActivity: Bool = false {
        didSet {
            UserDefaults.standard.set(showNetworkActivity, forKey: Keys.showNetworkActivity)
        }
    }
    
    // MARK: - Accessibility Settings
    @Published var useBoldText: Bool = false {
        didSet {
            UserDefaults.standard.set(useBoldText, forKey: Keys.useBoldText)
        }
    }
    
    @Published var useMonospaceCode: Bool = true {
        didSet {
            UserDefaults.standard.set(useMonospaceCode, forKey: Keys.useMonospaceCode)
        }
    }
    
    @Published var highContrast: Bool = false {
        didSet {
            UserDefaults.standard.set(highContrast, forKey: Keys.highContrast)
        }
    }
    
    @Published var reduceTransparency: Bool = false {
        didSet {
            UserDefaults.standard.set(reduceTransparency, forKey: Keys.reduceTransparency)
        }
    }
    
    @Published var enableAnimations: Bool = true {
        didSet {
            UserDefaults.standard.set(enableAnimations, forKey: Keys.enableAnimations)
        }
    }
    
    @Published var reduceMotion: Bool = false {
        didSet {
            UserDefaults.standard.set(reduceMotion, forKey: Keys.reduceMotion)
        }
    }
    
    @Published var animationSpeed: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(animationSpeed, forKey: Keys.animationSpeed)
        }
    }
    
    @Published var smartInvert: Bool = false {
        didSet {
            UserDefaults.standard.set(smartInvert, forKey: Keys.smartInvert)
        }
    }
    
    @Published var buttonShapes: Bool = false {
        didSet {
            UserDefaults.standard.set(buttonShapes, forKey: Keys.buttonShapes)
        }
    }
    
    @Published var differentiateWithoutColor: Bool = false {
        didSet {
            UserDefaults.standard.set(differentiateWithoutColor, forKey: Keys.differentiateWithoutColor)
        }
    }
    
    // MARK: - Chat UI Settings
    @Published var showTokenUsage: Bool = true {
        didSet {
            UserDefaults.standard.set(showTokenUsage, forKey: Keys.showTokenUsage)
        }
    }
    
    @Published var enableCodeHighlighting: Bool = true {
        didSet {
            UserDefaults.standard.set(enableCodeHighlighting, forKey: Keys.enableCodeHighlighting)
        }
    }
    
    @Published var systemPrompt: String = "You are a helpful, harmless, and honest AI assistant." {
        didSet {
            UserDefaults.standard.set(systemPrompt, forKey: Keys.systemPrompt)
        }
    }
    
    // MARK: - Private Properties
    private let keychainManager = KeychainManager.shared
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadSettings()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load all settings from UserDefaults and Keychain
    func loadSettings() async {
        // Load API settings
        baseURL = userDefaults.string(forKey: Keys.baseURL) ?? APIConfig.defaultBaseURL
        selectedModel = userDefaults.string(forKey: Keys.selectedModel) ?? "claude-3-5-haiku-20241022"
        apiKey = try? await keychainManager.loadString(for: KeychainManager.Keys.apiKey)
        
        // Load SSH settings
        sshEnabled = userDefaults.bool(forKey: Keys.sshEnabled)
        sshHost = userDefaults.string(forKey: Keys.sshHost) ?? ""
        sshPort = userDefaults.integer(forKey: Keys.sshPort)
        if sshPort == 0 { sshPort = 22 }
        sshUsername = userDefaults.string(forKey: Keys.sshUsername) ?? ""
        sshPrivateKey = try? await keychainManager.loadString(for: KeychainManager.Keys.sshPrivateKey)
        sshPassphrase = try? await keychainManager.loadString(for: KeychainManager.Keys.sshPassphrase)
        
        // Load app preferences
        if let themeValue = userDefaults.string(forKey: Keys.theme),
           let theme = AppTheme(rawValue: themeValue) {
            self.theme = theme
        }
        
        if let fontSizeValue = userDefaults.string(forKey: Keys.fontSize),
           let fontSize = FontSize(rawValue: fontSizeValue) {
            self.fontSize = fontSize
        }
        
        enableHaptics = userDefaults.bool(forKey: Keys.enableHaptics)
        enableSounds = userDefaults.bool(forKey: Keys.enableSounds)
        
        // Load chat settings
        temperature = userDefaults.double(forKey: Keys.temperature)
        if temperature == 0 { temperature = 0.7 }
        
        maxTokens = userDefaults.integer(forKey: Keys.maxTokens)
        if maxTokens == 0 { maxTokens = 4096 }
        
        streamResponses = userDefaults.bool(forKey: Keys.streamResponses)
        saveHistory = userDefaults.bool(forKey: Keys.saveHistory)
        
        // Load background settings
        enableBackgroundRefresh = userDefaults.bool(forKey: Keys.enableBackgroundRefresh)
        enableTelemetry = userDefaults.bool(forKey: Keys.enableTelemetry)
        
        // Load developer settings
        debugMode = userDefaults.bool(forKey: Keys.debugMode)
        showNetworkActivity = userDefaults.bool(forKey: Keys.showNetworkActivity)
        
        // Apply theme
        applyTheme()
    }
    
    /// Save all settings
    func saveSettings() async {
        // Keychain items are saved automatically via didSet
        // UserDefaults are also saved automatically via didSet
        
        // Ensure synchronization
        userDefaults.synchronize()
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() async {
        // Clear keychain items
        try? await keychainManager.delete(for: KeychainManager.Keys.apiKey)
        try? await keychainManager.delete(for: KeychainManager.Keys.sshPrivateKey)
        try? await keychainManager.delete(for: KeychainManager.Keys.sshPassphrase)
        
        // Reset UserDefaults
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
        userDefaults.synchronize()
        
        // Reset published properties to defaults
        apiKey = nil
        baseURL = APIConfig.defaultBaseURL
        selectedModel = "claude-3-5-haiku-20241022"
        sshEnabled = false
        sshHost = ""
        sshPort = 22
        sshUsername = ""
        sshPrivateKey = nil
        sshPassphrase = nil
        theme = .system
        fontSize = .medium
        enableHaptics = true
        enableSounds = true
        temperature = 0.7
        maxTokens = 4096
        streamResponses = true
        saveHistory = true
        enableBackgroundRefresh = true
        enableTelemetry = false
        debugMode = false
        showNetworkActivity = false
    }
    
    // MARK: - Private Methods
    
    private func saveAPIKey() async {
        if let apiKey = apiKey, !apiKey.isEmpty {
            try? await keychainManager.saveString(apiKey, for: KeychainManager.Keys.apiKey)
        } else {
            try? await keychainManager.delete(for: KeychainManager.Keys.apiKey)
        }
    }
    
    private func saveSSHPrivateKey() async {
        if let key = sshPrivateKey, !key.isEmpty {
            try? await keychainManager.saveString(key, for: KeychainManager.Keys.sshPrivateKey)
        } else {
            try? await keychainManager.delete(for: KeychainManager.Keys.sshPrivateKey)
        }
    }
    
    private func saveSSHPassphrase() async {
        if let passphrase = sshPassphrase, !passphrase.isEmpty {
            try? await keychainManager.saveString(passphrase, for: KeychainManager.Keys.sshPassphrase)
        } else {
            try? await keychainManager.delete(for: KeychainManager.Keys.sshPassphrase)
        }
    }
    
    private func applyTheme() {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first
        
        switch theme {
        case .light:
            window?.overrideUserInterfaceStyle = .light
        case .dark, .cyberpunk:
            window?.overrideUserInterfaceStyle = .dark
        case .system:
            window?.overrideUserInterfaceStyle = .unspecified
        }
    }
    
    // MARK: - Keys
    
    private enum Keys {
        // API
        static let baseURL = "settings.baseURL"
        static let selectedModel = "settings.selectedModel"
        
        // SSH
        static let sshEnabled = "settings.sshEnabled"
        static let sshHost = "settings.sshHost"
        static let sshPort = "settings.sshPort"
        static let sshUsername = "settings.sshUsername"
        
        // Preferences
        static let theme = "settings.theme"
        static let fontSize = "settings.fontSize"
        static let enableHaptics = "settings.enableHaptics"
        static let enableSounds = "settings.enableSounds"
        
        // Chat
        static let temperature = "settings.temperature"
        static let maxTokens = "settings.maxTokens"
        static let streamResponses = "settings.streamResponses"
        static let saveHistory = "settings.saveHistory"
        
        // Background
        static let enableBackgroundRefresh = "settings.enableBackgroundRefresh"
        static let enableTelemetry = "settings.enableTelemetry"
        
        // Developer
        static let debugMode = "settings.debugMode"
        static let showNetworkActivity = "settings.showNetworkActivity"
        
        // Accessibility
        static let useBoldText = "settings.useBoldText"
        static let useMonospaceCode = "settings.useMonospaceCode"
        static let highContrast = "settings.highContrast"
        static let reduceTransparency = "settings.reduceTransparency"
        static let enableAnimations = "settings.enableAnimations"
        static let reduceMotion = "settings.reduceMotion"
        static let animationSpeed = "settings.animationSpeed"
        static let smartInvert = "settings.smartInvert"
        static let buttonShapes = "settings.buttonShapes"
        static let differentiateWithoutColor = "settings.differentiateWithoutColor"
        
        // Chat UI
        static let showTokenUsage = "settings.showTokenUsage"
        static let enableCodeHighlighting = "settings.enableCodeHighlighting"
        static let systemPrompt = "settings.systemPrompt"
    }
    
    // MARK: - Public Methods
    
    func updateAPIConfiguration(apiKey: String, baseURL: String?) {
        // Store API configuration
        self.apiKey = apiKey
        if let baseURL = baseURL {
            self.baseURL = baseURL
        }
    }
    
    func updateSSHConfiguration(_ config: AppSSHConfig) {
        // Store SSH configuration
        sshEnabled = true
        sshHost = config.host
        sshPort = Int(config.port)
        sshUsername = config.username
    }
    
    var sshConfiguration: AppSSHConfig? {
        guard sshEnabled else { return nil }
        return AppSSHConfig(
            name: "SSH Connection",
            host: sshHost,
            port: UInt16(sshPort),
            username: sshUsername
        )
    }
    
    func updateTheme(_ newTheme: AppTheme) {
        theme = newTheme
    }
    
    func updateFontSize(_ size: FontSize) {
        fontSize = size
    }
    
    func toggleReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
    }
    
    func exportSettings() async throws -> URL {
        // Export settings as JSON
        let settings: [String: Any] = [
            "theme": theme.rawValue,
            "fontSize": fontSize.rawValue,
            "enableHaptics": enableHaptics,
            "enableSounds": enableSounds,
            "temperature": temperature,
            "maxTokens": maxTokens,
            "streamResponses": streamResponses,
            "saveHistory": saveHistory
        ]
        
        let data = try JSONSerialization.data(withJSONObject: settings)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("settings_\(Date().timeIntervalSince1970).json")
        try data.write(to: fileURL)
        return fileURL
    }
    
    func importSettings(from url: URL) async throws {
        // Import settings from JSON
        let data = try Data(contentsOf: url)
        guard let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        if let themeRaw = settings["theme"] as? String,
           let theme = AppTheme(rawValue: themeRaw) {
            self.theme = theme
        }
        
        if let fontSizeRaw = settings["fontSize"] as? String,
           let fontSize = FontSize(rawValue: fontSizeRaw) {
            self.fontSize = fontSize
        }
        
        if let enableHaptics = settings["enableHaptics"] as? Bool {
            self.enableHaptics = enableHaptics
        }
        
        if let enableSounds = settings["enableSounds"] as? Bool {
            self.enableSounds = enableSounds
        }
        
        if let temperature = settings["temperature"] as? Double {
            self.temperature = temperature
        }
        
        if let maxTokens = settings["maxTokens"] as? Int {
            self.maxTokens = maxTokens
        }
    }
    
    func updateNotificationSettings(_ settings: NotificationSettings) {
        // Update notification settings
        UserDefaults.standard.set(settings.enabled, forKey: "notifications.enabled")
        UserDefaults.standard.set(settings.soundEnabled, forKey: "notifications.soundEnabled")
        UserDefaults.standard.set(settings.vibrationEnabled, forKey: "notifications.vibrationEnabled")
        UserDefaults.standard.set(settings.showPreviews, forKey: "notifications.showPreviews")
    }
    
    func updatePrivacySettings(_ settings: PrivacySettings) {
        // Update privacy settings
        enableTelemetry = settings.telemetryEnabled
        UserDefaults.standard.set(settings.analyticsEnabled, forKey: "privacy.analyticsEnabled")
        UserDefaults.standard.set(settings.crashReportingEnabled, forKey: "privacy.crashReportingEnabled")
        UserDefaults.standard.set(settings.shareUsageData, forKey: "privacy.shareUsageData")
    }
    
    func toggleAnalytics(_ enabled: Bool) {
        enableTelemetry = enabled
    }
}

// MARK: - Supporting Types

// AppTheme is defined in ThemeManager.swift
// Type alias for compatibility
// Removed typealias to avoid conflict with Theme struct
// Use AppTheme directly instead

enum FontSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"
    
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
    
    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.15
        case .extraLarge: return 1.3
        }
    }
}