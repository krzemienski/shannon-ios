//
//  OnboardingUITests.swift
//  ClaudeCodeUITests
//
//  UI tests for onboarding flow
//

import XCTest

class OnboardingUITests: ClaudeCodeUITestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Launch app with onboarding
        app.terminate()
        launchApp(with: .onboarding)
    }
    
    func testOnboardingFlow() {
        // Welcome screen
        let welcomeTitle = app.staticTexts["Welcome to Claude Code"]
        waitForElement(welcomeTitle)
        takeScreenshot(name: "01-Welcome")
        
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.exists)
        getStartedButton.tap()
        
        // API Key setup screen
        let apiKeyTitle = app.staticTexts["Connect to Claude"]
        waitForElement(apiKeyTitle)
        takeScreenshot(name: "02-API-Setup")
        
        let apiKeyField = app.textFields[AccessibilityIdentifier.authAPIKeyField]
        XCTAssertTrue(apiKeyField.exists)
        
        // Test skip option
        let skipButton = app.buttons[AccessibilityIdentifier.authSkipButton]
        XCTAssertTrue(skipButton.exists)
        
        // Enter API key
        apiKeyField.tap()
        apiKeyField.typeText("test-api-key-12345")
        
        let continueButton = app.buttons[AccessibilityIdentifier.authContinueButton]
        XCTAssertTrue(continueButton.exists)
        continueButton.tap()
        
        // Verify we reach the main app
        let chatTab = app.tabBars.buttons[AccessibilityIdentifier.tabBarChat]
        waitForElement(chatTab)
        takeScreenshot(name: "03-Main-App")
        
        XCTAssertTrue(chatTab.isSelected)
    }
    
    func testOnboardingSkip() {
        // Welcome screen
        let welcomeTitle = app.staticTexts["Welcome to Claude Code"]
        waitForElement(welcomeTitle)
        
        let getStartedButton = app.buttons["Get Started"]
        getStartedButton.tap()
        
        // API Key setup screen - skip
        let skipButton = app.buttons[AccessibilityIdentifier.authSkipButton]
        waitForElement(skipButton)
        skipButton.tap()
        
        // Should show alert about offline mode
        verifyAlert(
            title: "Continue Without API Key?",
            message: "You can add an API key later in Settings",
            dismissButtonTitle: "Continue"
        )
        
        // Verify we reach the main app
        let chatTab = app.tabBars.buttons[AccessibilityIdentifier.tabBarChat]
        waitForElement(chatTab)
        XCTAssertTrue(chatTab.exists)
    }
    
    func testAPIKeyValidation() {
        // Navigate to API key screen
        let getStartedButton = app.buttons["Get Started"]
        waitForElement(getStartedButton)
        getStartedButton.tap()
        
        let apiKeyField = app.textFields[AccessibilityIdentifier.authAPIKeyField]
        waitForElement(apiKeyField)
        
        // Test empty API key
        let continueButton = app.buttons[AccessibilityIdentifier.authContinueButton]
        continueButton.tap()
        
        // Should show validation error
        let errorText = app.staticTexts["Please enter a valid API key"]
        waitForElement(errorText)
        
        // Test invalid format
        apiKeyField.clearAndType("invalid")
        continueButton.tap()
        
        // Should show format error
        let formatError = app.staticTexts["API key format is invalid"]
        XCTAssertTrue(formatError.exists || errorText.exists)
        
        // Test valid format
        apiKeyField.clearAndType("sk-ant-api03-valid-test-key-format")
        continueButton.tap()
        
        // Should proceed (in test mode)
        let chatTab = app.tabBars.buttons[AccessibilityIdentifier.tabBarChat]
        waitForElement(chatTab, timeout: 15)
    }
}