//
//  SettingsUITests.swift
//  ClaudeCodeUITests
//
//  Comprehensive UI tests for Settings functionality
//

import XCTest

class SettingsUITests: ClaudeCodeUITestCase {
    
    var settingsPage: SettingsPage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize page object
        settingsPage = SettingsPage(app: app)
        
        // Launch app in authenticated state
        app.terminate()
        launchApp(with: .authenticated)
        
        // Navigate to settings
        settingsPage.navigateToSettings()
    }
    
    // MARK: - Basic Settings Tests
    
    func testNavigateToSettings() {
        // Verify we're on settings page
        waitForElement(settingsPage.settingsList)
        XCTAssertTrue(settingsPage.settingsTab.isSelected)
        
        takeScreenshot(name: "Settings-Main")
    }
    
    func testSettingsSections() {
        // Verify all sections are present
        for section in SettingsPage.SettingsSection.allCases {
            let cell = settingsPage.settingsList.cells[section.rawValue]
            XCTAssertTrue(cell.exists, "Section \(section.rawValue) not found")
        }
        
        takeScreenshot(name: "Settings-All-Sections")
    }
    
    // MARK: - API Configuration Tests
    
    func testAPIKeyConfiguration() {
        // Navigate to API settings
        settingsPage.selectSettingsSection(.api)
        
        // Update API key
        let testKey = "sk-ant-api03-test-key-123456"
        settingsPage.updateAPIKey(testKey)
        
        // Save settings
        settingsPage.saveAPISettings()
        
        // Verify key was saved
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(settingsPage.verifyAPIKeySet())
        
        takeScreenshot(name: "Settings-API-Key-Updated")
    }
    
    func testBaseURLConfiguration() {
        // Navigate to API settings
        settingsPage.selectSettingsSection(.api)
        
        // Update base URL
        let testURL = "https://api.test.anthropic.com"
        settingsPage.updateBaseURL(testURL)
        
        // Save settings
        settingsPage.saveAPISettings()
        
        // Verify URL was saved
        Thread.sleep(forTimeInterval: 1)
        
        takeScreenshot(name: "Settings-Base-URL-Updated")
    }
    
    func testConnectionTest() {
        // Navigate to API settings
        settingsPage.selectSettingsSection(.api)
        
        // Set valid test credentials
        settingsPage.updateAPIKey("sk-ant-api03-valid-test-key")
        settingsPage.updateBaseURL("https://api.anthropic.com")
        
        // Test connection
        settingsPage.testConnection()
        
        // Wait for test to complete
        Thread.sleep(forTimeInterval: 3)
        
        // Verify connection test result
        XCTAssertTrue(settingsPage.verifyConnectionTestSuccess())
        
        takeScreenshot(name: "Settings-Connection-Test-Success")
    }
    
    // MARK: - Appearance Settings Tests
    
    func testThemeSelection() {
        // Navigate to appearance settings
        settingsPage.selectSettingsSection(.appearance)
        
        // Test each theme
        for theme in [SettingsPage.Theme.light, .dark, .system] {
            settingsPage.selectTheme(theme)
            Thread.sleep(forTimeInterval: 0.5)
            
            // Verify theme selected
            XCTAssertTrue(settingsPage.verifyThemeSelected(theme))
            
            takeScreenshot(name: "Settings-Theme-\(theme.rawValue)")
        }
    }
    
    func testAccentColorSelection() {
        // Navigate to appearance settings
        settingsPage.selectSettingsSection(.appearance)
        
        // Select accent color
        settingsPage.selectAccentColor()
        
        // Verify color picker opened
        waitForElement(app.otherElements["color.picker"])
        
        // Select a color
        let blueColor = app.buttons["color.blue"]
        if blueColor.exists {
            blueColor.tap()
        }
        
        takeScreenshot(name: "Settings-Accent-Color")
    }
    
    func testFontSizeAdjustment() {
        // Navigate to appearance settings
        settingsPage.selectSettingsSection(.appearance)
        
        // Adjust font size
        settingsPage.adjustFontSize(0.7)
        
        // Verify font size changed
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Settings-Font-Size-Adjusted")
    }
    
    func testCodeThemeSelection() {
        // Navigate to appearance settings
        settingsPage.selectSettingsSection(.appearance)
        
        // Select code theme
        settingsPage.selectCodeTheme("Monokai")
        
        // Verify theme selected
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Settings-Code-Theme")
    }
    
    // MARK: - Chat Settings Tests
    
    func testStreamingToggle() {
        // Navigate to chat settings
        settingsPage.selectSettingsSection(.chat)
        
        // Toggle streaming
        settingsPage.toggleStreaming(false)
        XCTAssertFalse(settingsPage.verifyStreamingEnabled())
        
        // Toggle back on
        settingsPage.toggleStreaming(true)
        XCTAssertTrue(settingsPage.verifyStreamingEnabled())
        
        takeScreenshot(name: "Settings-Streaming-Toggle")
    }
    
    func testMaxTokensConfiguration() {
        // Navigate to chat settings
        settingsPage.selectSettingsSection(.chat)
        
        // Set max tokens
        settingsPage.setMaxTokens("4096")
        
        // Verify value set
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Settings-Max-Tokens")
    }
    
    func testTemperatureAdjustment() {
        // Navigate to chat settings
        settingsPage.selectSettingsSection(.chat)
        
        // Adjust temperature
        settingsPage.adjustTemperature(0.5)
        
        // Verify temperature adjusted
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Settings-Temperature-Adjusted")
    }
    
    func testModelSelection() {
        // Navigate to chat settings
        settingsPage.selectSettingsSection(.chat)
        
        // Select model
        settingsPage.selectModel("claude-3-opus-20240229")
        
        // Verify model selected
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Settings-Model-Selected")
    }
    
    func testSystemPromptConfiguration() {
        // Navigate to chat settings
        settingsPage.selectSettingsSection(.chat)
        
        // Update system prompt
        let prompt = "You are a helpful AI assistant specialized in iOS development."
        settingsPage.updateSystemPrompt(prompt)
        
        // Verify prompt updated
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Settings-System-Prompt")
    }
    
    // MARK: - Privacy Settings Tests
    
    func testAnalyticsToggle() {
        // Navigate to privacy settings
        settingsPage.selectSettingsSection(.privacy)
        
        // Toggle analytics
        settingsPage.toggleAnalytics(false)
        
        // Verify toggle state
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Settings-Analytics-Disabled")
        
        // Toggle back on
        settingsPage.toggleAnalytics(true)
    }
    
    func testCrashReportingToggle() {
        // Navigate to privacy settings
        settingsPage.selectSettingsSection(.privacy)
        
        // Toggle crash reporting
        settingsPage.toggleCrashReporting(false)
        
        // Verify toggle state
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Settings-Crash-Reporting-Disabled")
    }
    
    func testDataRetentionSelection() {
        // Navigate to privacy settings
        settingsPage.selectSettingsSection(.privacy)
        
        // Select data retention period
        settingsPage.selectDataRetention("30 days")
        
        // Verify selection
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Settings-Data-Retention")
    }
    
    // MARK: - Advanced Settings Tests
    
    func testDebugModeToggle() {
        // Navigate to advanced settings
        settingsPage.selectSettingsSection(.advanced)
        
        // Toggle debug mode
        settingsPage.toggleDebugMode(true)
        
        // Verify debug mode enabled
        XCTAssertTrue(settingsPage.verifyDebugModeEnabled())
        
        takeScreenshot(name: "Settings-Debug-Mode-Enabled")
        
        // Toggle off
        settingsPage.toggleDebugMode(false)
    }
    
    func testNetworkTimeoutConfiguration() {
        // Navigate to advanced settings
        settingsPage.selectSettingsSection(.advanced)
        
        // Set network timeout
        settingsPage.setNetworkTimeout("30")
        
        // Verify value set
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Settings-Network-Timeout")
    }
    
    func testCacheToggle() {
        // Navigate to advanced settings
        settingsPage.selectSettingsSection(.advanced)
        
        // Toggle cache
        settingsPage.toggleCache(false)
        Thread.sleep(forTimeInterval: 0.5)
        
        // Toggle back on
        settingsPage.toggleCache(true)
        
        takeScreenshot(name: "Settings-Cache-Toggle")
    }
    
    func testClearCache() {
        // Navigate to advanced settings
        settingsPage.selectSettingsSection(.advanced)
        
        // Clear cache
        settingsPage.clearCache()
        
        // Verify cache cleared
        XCTAssertTrue(settingsPage.verifyCacheCleared())
        
        takeScreenshot(name: "Settings-Cache-Cleared")
    }
    
    // MARK: - Account Settings Tests
    
    func testSignOut() {
        // Navigate to account settings
        settingsPage.selectSettingsSection(.account)
        
        // Sign out
        settingsPage.signOut()
        
        // Verify signed out (should return to auth screen)
        waitForElement(app.staticTexts["Welcome to Claude Code"])
        
        takeScreenshot(name: "Settings-Signed-Out")
    }
    
    func testExportData() {
        // Navigate to account settings
        settingsPage.selectSettingsSection(.account)
        
        // Export data
        settingsPage.exportData()
        
        // Verify export dialog
        waitForElement(app.sheets["Export Data"])
        
        takeScreenshot(name: "Settings-Export-Data")
        
        // Cancel export
        app.sheets.buttons["Cancel"].tap()
    }
    
    // MARK: - About Section Tests
    
    func testAboutSection() {
        // Open about section
        settingsPage.openAboutSection()
        
        // Verify about information is shown
        waitForElement(app.staticTexts["Claude Code"])
        
        takeScreenshot(name: "Settings-About")
    }
    
    func testVersionInformation() {
        // Verify version information
        let expectedVersion = "1.0.0"
        XCTAssertTrue(settingsPage.verifyVersion(expectedVersion))
        
        takeScreenshot(name: "Settings-Version-Info")
    }
    
    // MARK: - Settings Management Tests
    
    func testResetToDefaults() {
        // Make some changes first
        settingsPage.selectSettingsSection(.chat)
        settingsPage.toggleStreaming(false)
        settingsPage.setMaxTokens("2048")
        
        // Reset to defaults
        app.navigationBars.buttons.firstMatch.tap()
        settingsPage.resetToDefaults()
        
        // Verify settings reset
        Thread.sleep(forTimeInterval: 1)
        settingsPage.selectSettingsSection(.chat)
        XCTAssertTrue(settingsPage.verifyStreamingEnabled())
        
        takeScreenshot(name: "Settings-Reset-To-Defaults")
    }
    
    func testImportSettings() {
        // Import settings
        settingsPage.importSettings(from: "https://example.com/settings.json")
        
        // Verify import dialog
        waitForElement(app.alerts["Import in Progress"])
        
        takeScreenshot(name: "Settings-Import")
        
        // Cancel import
        app.alerts.buttons["Cancel"].tap()
    }
    
    func testExportSettings() {
        // Export settings
        settingsPage.exportSettings()
        
        // Verify export dialog
        waitForElement(app.sheets["Export Settings"])
        
        takeScreenshot(name: "Settings-Export")
        
        // Cancel export
        app.sheets.buttons["Cancel"].tap()
    }
    
    // MARK: - Validation Tests
    
    func testInvalidAPIKey() {
        // Navigate to API settings
        settingsPage.selectSettingsSection(.api)
        
        // Enter invalid API key
        settingsPage.updateAPIKey("invalid-key")
        
        // Test connection
        settingsPage.testConnection()
        
        // Verify error message
        waitForElement(app.staticTexts["Invalid API key"])
        
        takeScreenshot(name: "Settings-Invalid-API-Key")
    }
    
    func testInvalidURL() {
        // Navigate to API settings
        settingsPage.selectSettingsSection(.api)
        
        // Enter invalid URL
        settingsPage.updateBaseURL("not-a-url")
        
        // Try to save
        settingsPage.saveAPISettings()
        
        // Verify error message
        waitForElement(app.staticTexts["Invalid URL format"])
        
        takeScreenshot(name: "Settings-Invalid-URL")
    }
    
    // MARK: - Performance Tests
    
    func testSettingsNavigationPerformance() {
        measure {
            // Navigate through all sections
            for section in SettingsPage.SettingsSection.allCases {
                settingsPage.selectSettingsSection(section)
                Thread.sleep(forTimeInterval: 0.2)
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
    }
    
    func testSettingsSavePerformance() {
        settingsPage.selectSettingsSection(.api)
        
        measure {
            settingsPage.updateAPIKey("test-key-\(Date().timeIntervalSince1970)")
            settingsPage.saveAPISettings()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}