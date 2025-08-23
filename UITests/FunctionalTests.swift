//
//  FunctionalTests.swift
//  ClaudeCodeUITests
//
//  Functional UI tests that connect to real backend
//

import XCTest

class FunctionalTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        continueAfterFailure = false
        
        app = XCUIApplication()
        
        // Configure for functional testing with real backend
        app.launchArguments = [
            "--uitesting",
            "--functional-test",
            "--reset-state"
        ]
        
        app.launchEnvironment = [
            "BACKEND_URL": ProcessInfo.processInfo.environment["BACKEND_URL"] ?? "http://localhost:8000",
            "NETWORK_TIMEOUT": ProcessInfo.processInfo.environment["NETWORK_TIMEOUT"] ?? "30",
            "UI_WAIT_TIMEOUT": ProcessInfo.processInfo.environment["UI_WAIT_TIMEOUT"] ?? "15",
            "VERBOSE_LOGGING": ProcessInfo.processInfo.environment["VERBOSE_LOGGING"] ?? "true",
            "CLEANUP_AFTER_TESTS": ProcessInfo.processInfo.environment["CLEANUP_AFTER_TESTS"] ?? "true"
        ]
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element \(element) did not appear within \(timeout) seconds")
    }
    
    func takeScreenshot(name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    // MARK: - Functional Tests
    
    func testLaunchAndBasicNavigation() {
        // Test app launch
        XCTAssertTrue(app.state == .runningForeground, "App should be running")
        
        // Take screenshot of initial state
        takeScreenshot(name: "App-Launch")
        
        // Check for main tab bar
        let tabBar = app.tabBars.firstMatch
        waitForElement(tabBar)
        
        // Navigate through tabs
        let chatTab = tabBar.buttons["Chat"]
        if chatTab.exists {
            chatTab.tap()
            takeScreenshot(name: "Chat-Tab")
        }
        
        let projectsTab = tabBar.buttons["Projects"]
        if projectsTab.exists {
            projectsTab.tap()
            takeScreenshot(name: "Projects-Tab")
        }
        
        let monitorTab = tabBar.buttons["Monitor"]
        if monitorTab.exists {
            monitorTab.tap()
            takeScreenshot(name: "Monitor-Tab")
        }
        
        let settingsTab = tabBar.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            takeScreenshot(name: "Settings-Tab")
        }
    }
    
    func testProjectCreationFlow() {
        // Navigate to Projects tab
        let tabBar = app.tabBars.firstMatch
        waitForElement(tabBar)
        
        let projectsTab = tabBar.buttons["Projects"]
        if projectsTab.exists {
            projectsTab.tap()
        }
        
        // Look for create project button
        let createButton = app.buttons["Create Project"].firstMatch
        if !createButton.exists {
            createButton = app.buttons["Add"].firstMatch
        }
        if !createButton.exists {
            createButton = app.navigationBars.buttons["Add"].firstMatch
        }
        
        if createButton.exists {
            createButton.tap()
            takeScreenshot(name: "Create-Project-Dialog")
            
            // Fill in project details if form exists
            let nameField = app.textFields["Project Name"].firstMatch
            if !nameField.exists {
                nameField = app.textFields.firstMatch
            }
            
            if nameField.exists {
                nameField.tap()
                nameField.typeText("Test Project \(Date().timeIntervalSince1970)")
                
                // Try to save
                let saveButton = app.buttons["Save"].firstMatch
                if !saveButton.exists {
                    saveButton = app.buttons["Create"].firstMatch
                }
                
                if saveButton.exists {
                    saveButton.tap()
                    Thread.sleep(forTimeInterval: 2)
                    takeScreenshot(name: "Project-Created")
                }
            }
        }
    }
    
    func testChatInteraction() {
        // Navigate to Chat tab
        let tabBar = app.tabBars.firstMatch
        waitForElement(tabBar)
        
        let chatTab = tabBar.buttons["Chat"]
        if chatTab.exists {
            chatTab.tap()
            Thread.sleep(forTimeInterval: 1)
            
            // Look for input field
            let inputField = app.textViews["Message"].firstMatch
            if !inputField.exists {
                inputField = app.textViews.firstMatch
            }
            if !inputField.exists {
                inputField = app.textFields["Message"].firstMatch
            }
            if !inputField.exists {
                inputField = app.textFields.firstMatch
            }
            
            if inputField.exists {
                inputField.tap()
                inputField.typeText("Hello, this is a test message from functional UI tests")
                
                // Look for send button
                let sendButton = app.buttons["Send"].firstMatch
                if !sendButton.exists {
                    sendButton = app.buttons.matching(identifier: "paperplane").firstMatch
                }
                
                if sendButton.exists {
                    takeScreenshot(name: "Chat-Before-Send")
                    sendButton.tap()
                    
                    // Wait for response
                    Thread.sleep(forTimeInterval: 3)
                    takeScreenshot(name: "Chat-After-Send")
                }
            }
        }
    }
    
    func testMonitoringTab() {
        // Navigate to Monitor tab
        let tabBar = app.tabBars.firstMatch
        waitForElement(tabBar)
        
        let monitorTab = tabBar.buttons["Monitor"]
        if monitorTab.exists {
            monitorTab.tap()
            Thread.sleep(forTimeInterval: 2)
            takeScreenshot(name: "Monitor-Dashboard")
            
            // Check for monitoring sections
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
                Thread.sleep(forTimeInterval: 1)
                takeScreenshot(name: "Monitor-Scrolled")
            }
        }
    }
    
    func testSettingsAndConfiguration() {
        // Navigate to Settings tab
        let tabBar = app.tabBars.firstMatch
        waitForElement(tabBar)
        
        let settingsTab = tabBar.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            Thread.sleep(forTimeInterval: 1)
            takeScreenshot(name: "Settings-Main")
            
            // Look for API configuration
            let apiCell = app.cells.containing(.staticText, identifier: "API").firstMatch
            if apiCell.exists {
                apiCell.tap()
                Thread.sleep(forTimeInterval: 1)
                takeScreenshot(name: "Settings-API")
                
                // Go back
                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                if backButton.exists {
                    backButton.tap()
                }
            }
            
            // Look for appearance settings
            let appearanceCell = app.cells.containing(.staticText, identifier: "Appearance").firstMatch
            if appearanceCell.exists {
                appearanceCell.tap()
                Thread.sleep(forTimeInterval: 1)
                takeScreenshot(name: "Settings-Appearance")
            }
        }
    }
    
    func testEndToEndUserJourney() {
        print("Starting end-to-end user journey test")
        print("Backend URL: \(app.launchEnvironment["BACKEND_URL"] ?? "not set")")
        
        // Step 1: Launch and verify initial state
        testLaunchAndBasicNavigation()
        
        // Step 2: Create a project
        testProjectCreationFlow()
        
        // Step 3: Test chat functionality
        testChatInteraction()
        
        // Step 4: Check monitoring
        testMonitoringTab()
        
        // Step 5: Verify settings
        testSettingsAndConfiguration()
        
        print("End-to-end user journey test completed")
    }
}

// MARK: - Performance Tests

extension FunctionalTests {
    
    func testScrollingPerformance() {
        measure {
            // Navigate to a scrollable view
            let tabBar = app.tabBars.firstMatch
            if tabBar.exists {
                let projectsTab = tabBar.buttons["Projects"]
                if projectsTab.exists {
                    projectsTab.tap()
                }
            }
            
            // Perform scroll
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
                scrollView.swipeDown()
            }
        }
    }
    
    func testNavigationPerformance() {
        measure {
            let tabBar = app.tabBars.firstMatch
            if tabBar.exists {
                // Cycle through all tabs
                for button in tabBar.buttons.allElementsBoundByIndex {
                    if button.exists {
                        button.tap()
                    }
                }
            }
        }
    }
}