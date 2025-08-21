//
//  ClaudeCodeUITests.swift
//  ClaudeCodeUITests
//
//  Base UI test configuration and test suite
//

import XCTest

/// Base UI test case with common setup and utilities
class ClaudeCodeUITestCase: XCTestCase {
    
    // MARK: - Properties
    
    var app: XCUIApplication!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        // Create and launch the application
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = [
            "UITEST_DISABLE_ANIMATIONS": "1",
            "UITEST_MODE": "1"
        ]
        
        // Reset app state for testing
        resetAppState()
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    /// Reset app state for clean testing
    private func resetAppState() {
        app.launchArguments.append("--reset-state")
    }
    
    /// Wait for element to exist
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element \(element) did not appear", file: file, line: line)
    }
    
    /// Wait for element to not exist
    func waitForElementToDisappear(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = expectation(for: predicate, evaluatedWith: element, handler: nil)
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Element \(element) did not disappear", file: file, line: line)
    }
    
    /// Swipe to element if needed
    func swipeToElement(_ element: XCUIElement, maxSwipes: Int = 5) {
        var swipeCount = 0
        
        while !element.isHittable && swipeCount < maxSwipes {
            app.swipeUp()
            swipeCount += 1
        }
    }
    
    /// Take a screenshot with a descriptive name
    func takeScreenshot(name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    
    /// Type text slowly to avoid issues
    func typeTextSlowly(_ text: String, in element: XCUIElement) {
        element.tap()
        
        for character in text {
            element.typeText(String(character))
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    
    /// Clear text field
    func clearTextField(_ element: XCUIElement) {
        element.tap()
        
        // Select all text
        element.press(forDuration: 1.0)
        
        // Wait for menu to appear
        Thread.sleep(forTimeInterval: 0.5)
        
        // Try to tap "Select All" if available
        let selectAll = app.menuItems["Select All"]
        if selectAll.exists {
            selectAll.tap()
        }
        
        // Delete the text
        element.typeText(XCUIKeyboardKey.delete.rawValue)
    }
    
    /// Verify alert appears with expected text
    func verifyAlert(
        title: String? = nil,
        message: String? = nil,
        dismissButtonTitle: String = "OK",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let alert = app.alerts.firstMatch
        waitForElement(alert)
        
        if let title = title {
            XCTAssertTrue(
                alert.staticTexts[title].exists,
                "Alert title '\(title)' not found",
                file: file,
                line: line
            )
        }
        
        if let message = message {
            XCTAssertTrue(
                alert.staticTexts[message].exists,
                "Alert message '\(message)' not found",
                file: file,
                line: line
            )
        }
        
        // Dismiss the alert
        alert.buttons[dismissButtonTitle].tap()
        waitForElementToDisappear(alert)
    }
    
    /// Launch app with specific configuration
    func launchApp(with configuration: LaunchConfiguration) {
        app.launchArguments = configuration.arguments
        app.launchEnvironment = configuration.environment
        app.launch()
    }
}

// MARK: - Launch Configuration

struct LaunchConfiguration {
    var arguments: [String] = []
    var environment: [String: String] = [:]
    
    static var uiTesting: LaunchConfiguration {
        LaunchConfiguration(
            arguments: ["--uitesting"],
            environment: [
                "UITEST_DISABLE_ANIMATIONS": "1",
                "UITEST_MODE": "1"
            ]
        )
    }
    
    static var onboarding: LaunchConfiguration {
        var config = uiTesting
        config.arguments.append("--show-onboarding")
        return config
    }
    
    static var authenticated: LaunchConfiguration {
        var config = uiTesting
        config.arguments.append("--mock-auth")
        config.environment["MOCK_API_KEY"] = "test-api-key"
        return config
    }
    
    static var offline: LaunchConfiguration {
        var config = uiTesting
        config.arguments.append("--offline-mode")
        return config
    }
}

// MARK: - UI Test Helpers

extension XCUIElement {
    
    /// Check if element is visible on screen
    var isVisible: Bool {
        return exists && isHittable
    }
    
    /// Wait and tap
    func waitAndTap(timeout: TimeInterval = 10) {
        _ = waitForExistence(timeout: timeout)
        tap()
    }
    
    /// Clear and type text
    func clearAndType(_ text: String) {
        tap()
        
        // Clear existing text
        if let currentValue = value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            typeText(deleteString)
        }
        
        // Type new text
        typeText(text)
    }
}

// MARK: - Accessibility Identifiers

enum AccessibilityIdentifier {
    // Tab Bar
    static let tabBarChat = "tab.chat"
    static let tabBarProjects = "tab.projects"
    static let tabBarTools = "tab.tools"
    static let tabBarMonitor = "tab.monitor"
    static let tabBarSettings = "tab.settings"
    
    // Chat
    static let chatList = "chat.list"
    static let chatNewButton = "chat.new"
    static let chatInput = "chat.input"
    static let chatSendButton = "chat.send"
    static let chatMessage = "chat.message"
    
    // Settings
    static let settingsAPIKey = "settings.apikey"
    static let settingsBaseURL = "settings.baseurl"
    static let settingsSaveButton = "settings.save"
    static let settingsTestButton = "settings.test"
    
    // Authentication
    static let authAPIKeyField = "auth.apikey"
    static let authContinueButton = "auth.continue"
    static let authSkipButton = "auth.skip"
    
    // Projects
    static let projectsList = "projects.list"
    static let projectNewButton = "projects.new"
    static let projectNameField = "project.name"
    static let projectPathField = "project.path"
    static let projectCreateButton = "project.create"
    
    // Tools
    static let toolsList = "tools.list"
    static let toolSearchField = "tools.search"
    static let toolExecuteButton = "tool.execute"
    static let toolParameterField = "tool.parameter"
}

// MARK: - Page Objects

/// Base page object
class BasePage {
    let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    func waitForPage(timeout: TimeInterval = 10) {
        // Override in subclasses
    }
}