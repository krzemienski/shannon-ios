//
//  SettingsPage.swift
//  ClaudeCodeUITests
//
//  Page object for Settings screens
//

import XCTest

/// Page object for Settings functionality
class SettingsPage: BasePage {
    
    // MARK: - Elements
    
    var settingsTab: XCUIElement {
        app.tabBars.buttons[AccessibilityIdentifier.tabBarSettings]
    }
    
    var settingsList: XCUIElement {
        app.tables["settings.list"]
    }
    
    // API Settings
    var apiKeyField: XCUIElement {
        app.secureTextFields[AccessibilityIdentifier.settingsAPIKey]
    }
    
    var baseURLField: XCUIElement {
        app.textFields[AccessibilityIdentifier.settingsBaseURL]
    }
    
    var testConnectionButton: XCUIElement {
        app.buttons[AccessibilityIdentifier.settingsTestButton]
    }
    
    var saveButton: XCUIElement {
        app.buttons[AccessibilityIdentifier.settingsSaveButton]
    }
    
    // Appearance Settings
    var themeSelector: XCUIElement {
        app.segmentedControls["settings.theme"]
    }
    
    var accentColorPicker: XCUIElement {
        app.buttons["settings.accent.color"]
    }
    
    var fontSizeSlider: XCUIElement {
        app.sliders["settings.font.size"]
    }
    
    var codeThemeSelector: XCUIElement {
        app.buttons["settings.code.theme"]
    }
    
    // Chat Settings
    var streamingToggle: XCUIElement {
        app.switches["settings.streaming"]
    }
    
    var maxTokensField: XCUIElement {
        app.textFields["settings.max.tokens"]
    }
    
    var temperatureSlider: XCUIElement {
        app.sliders["settings.temperature"]
    }
    
    var modelSelector: XCUIElement {
        app.buttons["settings.model"]
    }
    
    var systemPromptField: XCUIElement {
        app.textViews["settings.system.prompt"]
    }
    
    // Privacy Settings
    var analyticsToggle: XCUIElement {
        app.switches["settings.analytics"]
    }
    
    var crashReportingToggle: XCUIElement {
        app.switches["settings.crash.reporting"]
    }
    
    var dataRetentionSelector: XCUIElement {
        app.buttons["settings.data.retention"]
    }
    
    // Advanced Settings
    var debugModeToggle: XCUIElement {
        app.switches["settings.debug.mode"]
    }
    
    var networkTimeoutField: XCUIElement {
        app.textFields["settings.network.timeout"]
    }
    
    var cacheToggle: XCUIElement {
        app.switches["settings.cache"]
    }
    
    var clearCacheButton: XCUIElement {
        app.buttons["settings.clear.cache"]
    }
    
    // Account Settings
    var signOutButton: XCUIElement {
        app.buttons["settings.sign.out"]
    }
    
    var deleteAccountButton: XCUIElement {
        app.buttons["settings.delete.account"]
    }
    
    var exportDataButton: XCUIElement {
        app.buttons["settings.export.data"]
    }
    
    // MARK: - Actions
    
    func navigateToSettings() {
        settingsTab.tap()
        waitForPage()
    }
    
    func selectSettingsSection(_ section: SettingsSection) {
        let cell = settingsList.cells[section.rawValue]
        if cell.exists {
            cell.tap()
        }
    }
    
    enum SettingsSection: String {
        case api = "API Configuration"
        case appearance = "Appearance"
        case chat = "Chat Settings"
        case privacy = "Privacy & Security"
        case advanced = "Advanced"
        case account = "Account"
        case about = "About"
    }
    
    // API Settings Actions
    func updateAPIKey(_ key: String) {
        selectSettingsSection(.api)
        apiKeyField.tap()
        apiKeyField.clearAndType(key)
    }
    
    func updateBaseURL(_ url: String) {
        selectSettingsSection(.api)
        baseURLField.tap()
        baseURLField.clearAndType(url)
    }
    
    func testConnection() {
        selectSettingsSection(.api)
        testConnectionButton.tap()
    }
    
    func saveAPISettings() {
        saveButton.tap()
    }
    
    // Appearance Settings Actions
    func selectTheme(_ theme: Theme) {
        selectSettingsSection(.appearance)
        themeSelector.buttons[theme.rawValue].tap()
    }
    
    enum Theme: String {
        case light = "Light"
        case dark = "Dark"
        case system = "System"
    }
    
    func selectAccentColor() {
        selectSettingsSection(.appearance)
        accentColorPicker.tap()
    }
    
    func adjustFontSize(_ value: Float) {
        selectSettingsSection(.appearance)
        fontSizeSlider.adjust(toNormalizedSliderPosition: CGFloat(value))
    }
    
    func selectCodeTheme(_ theme: String) {
        selectSettingsSection(.appearance)
        codeThemeSelector.tap()
        
        let themeOption = app.buttons[theme]
        if themeOption.waitForExistence(timeout: 2) {
            themeOption.tap()
        }
    }
    
    // Chat Settings Actions
    func toggleStreaming(_ enabled: Bool) {
        selectSettingsSection(.chat)
        let currentValue = streamingToggle.value as? String == "1"
        if currentValue != enabled {
            streamingToggle.tap()
        }
    }
    
    func setMaxTokens(_ tokens: String) {
        selectSettingsSection(.chat)
        maxTokensField.tap()
        maxTokensField.clearAndType(tokens)
    }
    
    func adjustTemperature(_ value: Float) {
        selectSettingsSection(.chat)
        temperatureSlider.adjust(toNormalizedSliderPosition: CGFloat(value))
    }
    
    func selectModel(_ model: String) {
        selectSettingsSection(.chat)
        modelSelector.tap()
        
        let modelOption = app.buttons[model]
        if modelOption.waitForExistence(timeout: 2) {
            modelOption.tap()
        }
    }
    
    func updateSystemPrompt(_ prompt: String) {
        selectSettingsSection(.chat)
        systemPromptField.tap()
        systemPromptField.clearAndType(prompt)
    }
    
    // Privacy Settings Actions
    func toggleAnalytics(_ enabled: Bool) {
        selectSettingsSection(.privacy)
        let currentValue = analyticsToggle.value as? String == "1"
        if currentValue != enabled {
            analyticsToggle.tap()
        }
    }
    
    func toggleCrashReporting(_ enabled: Bool) {
        selectSettingsSection(.privacy)
        let currentValue = crashReportingToggle.value as? String == "1"
        if currentValue != enabled {
            crashReportingToggle.tap()
        }
    }
    
    func selectDataRetention(_ period: String) {
        selectSettingsSection(.privacy)
        dataRetentionSelector.tap()
        
        let periodOption = app.buttons[period]
        if periodOption.waitForExistence(timeout: 2) {
            periodOption.tap()
        }
    }
    
    // Advanced Settings Actions
    func toggleDebugMode(_ enabled: Bool) {
        selectSettingsSection(.advanced)
        let currentValue = debugModeToggle.value as? String == "1"
        if currentValue != enabled {
            debugModeToggle.tap()
        }
    }
    
    func setNetworkTimeout(_ timeout: String) {
        selectSettingsSection(.advanced)
        networkTimeoutField.tap()
        networkTimeoutField.clearAndType(timeout)
    }
    
    func toggleCache(_ enabled: Bool) {
        selectSettingsSection(.advanced)
        let currentValue = cacheToggle.value as? String == "1"
        if currentValue != enabled {
            cacheToggle.tap()
        }
    }
    
    func clearCache() {
        selectSettingsSection(.advanced)
        clearCacheButton.tap()
        
        // Confirm clearing cache
        let confirmButton = app.alerts.buttons["Clear"]
        if confirmButton.waitForExistence(timeout: 2) {
            confirmButton.tap()
        }
    }
    
    // Account Settings Actions
    func signOut() {
        selectSettingsSection(.account)
        signOutButton.tap()
        
        // Confirm sign out
        let confirmButton = app.alerts.buttons["Sign Out"]
        if confirmButton.waitForExistence(timeout: 2) {
            confirmButton.tap()
        }
    }
    
    func deleteAccount() {
        selectSettingsSection(.account)
        deleteAccountButton.tap()
        
        // Confirm deletion
        let confirmButton = app.alerts.buttons["Delete"]
        if confirmButton.waitForExistence(timeout: 2) {
            confirmButton.tap()
            
            // Double confirmation
            let finalConfirmButton = app.alerts.buttons["Delete Account"]
            if finalConfirmButton.waitForExistence(timeout: 2) {
                finalConfirmButton.tap()
            }
        }
    }
    
    func exportData() {
        selectSettingsSection(.account)
        exportDataButton.tap()
    }
    
    // MARK: - Verification
    
    override func waitForPage(timeout: TimeInterval = 10) {
        _ = settingsList.waitForExistence(timeout: timeout)
    }
    
    func verifyAPIKeySet() -> Bool {
        selectSettingsSection(.api)
        return !(apiKeyField.value as? String ?? "").isEmpty
    }
    
    func verifyConnectionTestSuccess() -> Bool {
        let successIndicator = app.images["settings.connection.success"]
        return successIndicator.waitForExistence(timeout: 5)
    }
    
    func verifyThemeSelected(_ theme: Theme) -> Bool {
        selectSettingsSection(.appearance)
        return themeSelector.buttons[theme.rawValue].isSelected
    }
    
    func verifyStreamingEnabled() -> Bool {
        selectSettingsSection(.chat)
        return streamingToggle.value as? String == "1"
    }
    
    func verifyDebugModeEnabled() -> Bool {
        selectSettingsSection(.advanced)
        return debugModeToggle.value as? String == "1"
    }
    
    func verifyCacheCleared() -> Bool {
        let successMessage = app.staticTexts["Cache cleared successfully"]
        return successMessage.waitForExistence(timeout: 2)
    }
    
    // MARK: - Advanced Actions
    
    func resetToDefaults() {
        let resetButton = app.buttons["settings.reset.defaults"]
        if resetButton.exists {
            resetButton.tap()
            
            // Confirm reset
            let confirmButton = app.alerts.buttons["Reset"]
            if confirmButton.waitForExistence(timeout: 2) {
                confirmButton.tap()
            }
        }
    }
    
    func importSettings(from url: String) {
        let importButton = app.buttons["settings.import"]
        if importButton.exists {
            importButton.tap()
            
            let urlField = app.textFields["import.settings.url"]
            if urlField.waitForExistence(timeout: 2) {
                urlField.tap()
                urlField.typeText(url)
                
                let importConfirmButton = app.buttons["Import"]
                importConfirmButton.tap()
            }
        }
    }
    
    func exportSettings() {
        let exportButton = app.buttons["settings.export"]
        if exportButton.exists {
            exportButton.tap()
        }
    }
    
    func openAboutSection() {
        selectSettingsSection(.about)
    }
    
    func verifyVersion(_ expectedVersion: String) -> Bool {
        openAboutSection()
        let versionLabel = app.staticTexts["settings.version"]
        return versionLabel.label.contains(expectedVersion)
    }
}