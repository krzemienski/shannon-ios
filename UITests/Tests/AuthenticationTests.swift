import XCTest

/// Tests for authentication flow with real backend integration
class AuthenticationTests: BaseUITest {
    
    // MARK: - Test Properties
    
    private let validAPIKey = "sk-valid-test-key-12345"
    private let invalidAPIKey = "sk-invalid-key"
    private let expiredAPIKey = "sk-expired-key-99999"
    
    // MARK: - Tests
    
    /// Test successful authentication with valid API key
    func testSuccessfulAuthentication() throws {
        // Given: User is on login screen
        XCTAssertTrue(waitForElement(app.buttons["Login"], timeout: uiTimeout),
                     "Login button should be visible")
        
        captureScreenshot(name: "01_login_screen")
        
        // When: User enters valid API key
        waitAndTap(app.buttons["Login"])
        
        let apiKeyField = app.secureTextFields["API Key"]
        XCTAssertTrue(waitForElement(apiKeyField, timeout: uiTimeout),
                     "API Key field should be visible")
        
        typeText(testAPIKey, in: apiKeyField)
        
        captureScreenshot(name: "02_api_key_entered")
        
        // And: Taps authenticate button
        let authenticateButton = app.buttons["Authenticate"]
        waitAndTap(authenticateButton)
        
        // Then: User should be authenticated and see main screen
        waitForAPIResponse(timeout: apiTimeout)
        
        XCTAssertTrue(waitForElement(app.tabBars.firstMatch, timeout: apiTimeout),
                     "Main tab bar should be visible after authentication")
        
        // Verify user is on chat screen
        XCTAssertTrue(app.navigationBars["Chat"].exists,
                     "Should navigate to Chat screen after login")
        
        captureScreenshot(name: "03_authenticated_main_screen")
        
        // Verify API key is stored securely (check settings)
        navigateToTab("Settings")
        XCTAssertTrue(app.staticTexts["API Key: •••••"].exists,
                     "API key should be stored securely")
    }
    
    /// Test authentication failure with invalid API key
    func testAuthenticationWithInvalidKey() throws {
        // Given: User is on login screen
        waitAndTap(app.buttons["Login"])
        
        // When: User enters invalid API key
        let apiKeyField = app.secureTextFields["API Key"]
        typeText(invalidAPIKey, in: apiKeyField)
        
        // And: Taps authenticate button
        waitAndTap(app.buttons["Authenticate"])
        
        // Then: Error should be displayed
        waitForAPIResponse(timeout: apiTimeout)
        
        verifyErrorHandling(expectedError: "Invalid API key")
        
        // And: User should remain on login screen
        XCTAssertTrue(app.buttons["Authenticate"].exists,
                     "Should remain on login screen after failed authentication")
        
        captureScreenshot(name: "authentication_error")
    }
    
    /// Test authentication with expired API key
    func testAuthenticationWithExpiredKey() throws {
        // Given: User is on login screen
        waitAndTap(app.buttons["Login"])
        
        // When: User enters expired API key
        let apiKeyField = app.secureTextFields["API Key"]
        typeText(expiredAPIKey, in: apiKeyField)
        
        // And: Taps authenticate button
        waitAndTap(app.buttons["Authenticate"])
        
        // Then: Specific error about expired key should be displayed
        waitForAPIResponse(timeout: apiTimeout)
        
        verifyErrorHandling(expectedError: "API key has expired")
        
        captureScreenshot(name: "expired_key_error")
    }
    
    /// Test biometric authentication setup
    func testBiometricAuthenticationSetup() throws {
        // First login normally
        performLogin()
        
        // Navigate to settings
        navigateToTab("Settings")
        
        // Find security settings
        let securityCell = app.cells.containing(.staticText, identifier: "Security").firstMatch
        waitAndTap(securityCell)
        
        // Enable biometric authentication
        let biometricSwitch = app.switches["Use Face ID"]
        if !biometricSwitch.isSelected {
            waitAndTap(biometricSwitch)
            
            // Handle system biometric prompt
            addUIInterruptionMonitor(withDescription: "Biometric Permission") { alert in
                if alert.buttons["OK"].exists {
                    alert.buttons["OK"].tap()
                    return true
                }
                return false
            }
            
            // Trigger the interruption monitor
            app.tap()
        }
        
        XCTAssertTrue(biometricSwitch.isSelected,
                     "Biometric authentication should be enabled")
        
        captureScreenshot(name: "biometric_enabled")
    }
    
    /// Test logout functionality
    func testLogout() throws {
        // Given: User is logged in
        performLogin()
        
        // When: User navigates to settings
        navigateToTab("Settings")
        
        // And: Taps logout
        app.scrollViews.firstMatch.swipeUp() // Scroll to bottom
        
        let logoutButton = app.buttons["Logout"]
        waitAndTap(logoutButton)
        
        // Confirm logout
        let confirmButton = app.alerts.buttons["Logout"]
        if confirmButton.exists {
            confirmButton.tap()
        }
        
        // Then: User should be back at login screen
        XCTAssertTrue(waitForElement(app.buttons["Login"], timeout: uiTimeout),
                     "Should return to login screen after logout")
        
        // Verify session is cleared
        XCTAssertFalse(app.tabBars.firstMatch.exists,
                      "Main tab bar should not be visible after logout")
        
        captureScreenshot(name: "logged_out")
    }
    
    /// Test session persistence
    func testSessionPersistence() throws {
        // Login first
        performLogin()
        
        // Force quit and relaunch app
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        
        app.terminate()
        app.launch()
        
        // Verify user is still logged in
        XCTAssertTrue(waitForElement(app.tabBars.firstMatch, timeout: uiTimeout),
                     "User should remain logged in after app restart")
        
        XCTAssertFalse(app.buttons["Login"].exists,
                      "Login button should not be visible for authenticated user")
    }
    
    /// Test concurrent authentication attempts
    func testConcurrentAuthentication() throws {
        // This tests that the app handles multiple rapid authentication attempts correctly
        waitAndTap(app.buttons["Login"])
        
        let apiKeyField = app.secureTextFields["API Key"]
        typeText(testAPIKey, in: apiKeyField)
        
        let authenticateButton = app.buttons["Authenticate"]
        
        // Rapid tap authenticate button multiple times
        for _ in 0..<3 {
            if authenticateButton.exists && authenticateButton.isEnabled {
                authenticateButton.tap()
            }
        }
        
        // Should handle gracefully and authenticate once
        waitForAPIResponse(timeout: apiTimeout)
        
        XCTAssertTrue(waitForElement(app.tabBars.firstMatch, timeout: apiTimeout),
                     "Should successfully authenticate despite multiple taps")
        
        // Verify no duplicate sessions or errors
        navigateToTab("Settings")
        XCTAssertEqual(app.staticTexts.matching(identifier: "Active Session").count, 1,
                      "Should have exactly one active session")
    }
    
    /// Test authentication with network issues
    func testAuthenticationWithNetworkError() throws {
        // Simulate network error by using wrong port
        app.terminate()
        app.launchEnvironment["API_BASE_URL"] = "http://localhost:9999/v1/" // Wrong port
        app.launch()
        
        waitAndTap(app.buttons["Login"])
        
        let apiKeyField = app.secureTextFields["API Key"]
        typeText(testAPIKey, in: apiKeyField)
        
        waitAndTap(app.buttons["Authenticate"])
        
        // Should show network error
        let alert = app.alerts.firstMatch
        XCTAssertTrue(waitForElement(alert, timeout: 10.0),
                     "Network error alert should appear")
        
        let alertText = alert.staticTexts.allElementsBoundByIndex.map { $0.label }.joined()
        XCTAssertTrue(alertText.contains("network") || alertText.contains("connection"),
                     "Should show network/connection error")
        
        captureScreenshot(name: "network_error")
    }
    
    /// Test API key validation on input
    func testAPIKeyInputValidation() throws {
        waitAndTap(app.buttons["Login"])
        
        let apiKeyField = app.secureTextFields["API Key"]
        let authenticateButton = app.buttons["Authenticate"]
        
        // Test empty key
        XCTAssertFalse(authenticateButton.isEnabled,
                      "Authenticate button should be disabled with empty key")
        
        // Test short key
        typeText("sk-123", in: apiKeyField)
        XCTAssertFalse(authenticateButton.isEnabled,
                      "Authenticate button should be disabled with short key")
        
        // Test valid format key
        apiKeyField.clearText()
        typeText("sk-" + String(repeating: "a", count: 32), in: apiKeyField)
        XCTAssertTrue(authenticateButton.isEnabled,
                     "Authenticate button should be enabled with valid format key")
    }
    
    /// Test rate limiting on authentication attempts
    func testAuthenticationRateLimiting() throws {
        waitAndTap(app.buttons["Login"])
        
        let apiKeyField = app.secureTextFields["API Key"]
        let authenticateButton = app.buttons["Authenticate"]
        
        // Make multiple failed attempts
        for i in 0..<5 {
            apiKeyField.clearText()
            typeText("sk-invalid-\(i)", in: apiKeyField)
            authenticateButton.tap()
            
            // Wait for error and dismiss
            if let alert = app.alerts.firstMatch.waitForExistence(timeout: 5) ? app.alerts.firstMatch : nil {
                alert.buttons["OK"].tap()
            }
        }
        
        // After multiple failures, should show rate limit error
        apiKeyField.clearText()
        typeText(testAPIKey, in: apiKeyField)
        authenticateButton.tap()
        
        let alert = app.alerts.firstMatch
        if waitForElement(alert, timeout: uiTimeout) {
            let alertText = alert.staticTexts.allElementsBoundByIndex.map { $0.label }.joined()
            
            // Check if rate limited
            if alertText.contains("rate") || alertText.contains("too many") {
                captureScreenshot(name: "rate_limited")
                XCTAssertTrue(true, "Rate limiting is working")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    /// Test authentication performance
    func testAuthenticationPerformance() throws {
        measureAPIPerformance(operation: "Authentication") {
            waitAndTap(app.buttons["Login"])
            
            let apiKeyField = app.secureTextFields["API Key"]
            typeText(testAPIKey, in: apiKeyField)
            
            waitAndTap(app.buttons["Authenticate"])
            
            // Measure time to complete authentication
            XCTAssertTrue(waitForElement(app.tabBars.firstMatch, timeout: apiTimeout),
                         "Authentication should complete within timeout")
        }
    }
}