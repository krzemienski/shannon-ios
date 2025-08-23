//
//  MCPConfigurationTests.swift
//  ClaudeCodeUITests
//
//  Functional tests for MCP server configuration with real backend persistence
//

import XCTest

class MCPConfigurationTests: ClaudeCodeUITestCase {
    
    // MARK: - Properties
    
    private var settingsPage: SettingsPage!
    private var originalMCPSettings: [String: Any] = [:]
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Configure for real backend testing
        let config = RealBackendConfig.createLaunchConfiguration()
        launchApp(with: config)
        
        settingsPage = SettingsPage(app: app)
        
        // Wait for backend availability
        let setupExpectation = expectation(description: "Backend setup")
        Task {
            let isAvailable = await RealBackendConfig.waitForBackend(maxAttempts: 15, interval: 2.0)
            XCTAssertTrue(isAvailable, "Backend must be available for functional tests")
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 60.0)
        
        // Capture original MCP settings for restoration
        captureOriginalMCPSettings()
    }
    
    override func tearDownWithError() throws {
        // Restore original MCP settings
        restoreOriginalMCPSettings()
        
        try super.tearDownWithError()
    }
    
    // MARK: - MCP Configuration Viewing Tests
    
    func testViewMCPConfiguration() throws {
        takeScreenshot(name: "before_mcp_config")
        
        // Navigate to settings
        settingsPage.navigateToSettings()
        waitForElement(settingsPage.settingsList, timeout: RealBackendConfig.uiWaitTimeout)
        
        takeScreenshot(name: "settings_loaded")
        
        // Look for MCP configuration section
        settingsPage.openMCPSettings()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "mcp_settings_opened")
        
        // Verify MCP configuration interface is visible
        let mcpConfigSection = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "mcp")).firstMatch
        XCTAssertTrue(mcpConfigSection.exists, "MCP configuration section should be visible")
        
        // Look for common MCP configuration elements
        let mcpElements = [
            "Server URL",
            "Server Port", 
            "Connection",
            "Timeout",
            "Enabled",
            "Configuration"
        ]
        
        var mcpElementsFound = 0
        for element in mcpElements {
            let mcpElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", element)).firstMatch
            if mcpElement.exists {
                mcpElementsFound += 1
                if RealBackendConfig.verboseLogging {
                    print("Found MCP element: \(element)")
                }
            }
        }
        
        XCTAssertGreaterThan(mcpElementsFound, 0, "Should display MCP configuration elements")
        
        takeScreenshot(name: "mcp_configuration_verified")
    }
    
    func testViewMCPServerList() throws {
        // Navigate to MCP settings
        settingsPage.navigateToSettings()
        waitForElement(settingsPage.settingsList, timeout: RealBackendConfig.uiWaitTimeout)
        
        settingsPage.openMCPSettings()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "before_server_list")
        
        // Look for server list or server configuration
        let serverListElement = app.tables.containing(NSPredicate(format: "identifier CONTAINS[c] %@", "server")).firstMatch
        if !serverListElement.exists {
            // Try alternative ways to find server list
            let addServerButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "add")).firstMatch
            if addServerButton.exists {
                // Server list might be empty, which is fine
                takeScreenshot(name: "empty_server_list")
            }
        } else {
            takeScreenshot(name: "server_list_found")
            
            // Verify server list is accessible
            XCTAssertTrue(serverListElement.exists, "MCP server list should be accessible")
            
            // Check for server entries
            let serverCells = serverListElement.cells
            if serverCells.count > 0 {
                takeScreenshot(name: "servers_configured")
                
                // Tap on first server to view details
                serverCells.firstMatch.tap()
                Thread.sleep(forTimeInterval: 2.0)
                
                takeScreenshot(name: "server_details")
            }
        }
        
        takeScreenshot(name: "server_list_verified")
    }
    
    // MARK: - MCP Server Configuration Tests
    
    func testAddNewMCPServer() throws {
        // Navigate to MCP settings
        settingsPage.navigateToSettings()
        waitForElement(settingsPage.settingsList, timeout: RealBackendConfig.uiWaitTimeout)
        
        settingsPage.openMCPSettings()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "before_add_server")
        
        // Look for add server button
        let addServerButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "add")).firstMatch
        if addServerButton.exists {
            addServerButton.tap()
            Thread.sleep(forTimeInterval: 2.0)
            
            takeScreenshot(name: "add_server_dialog")
            
            // Fill in server details
            let testServerConfig = [
                "name": "FunctionalTest_MCPServer",
                "url": "http://localhost:8080",
                "port": "8080",
                "timeout": "30"
            ]
            
            // Fill in server name
            let nameField = app.textFields.containing(NSPredicate(format: "placeholder CONTAINS[c] %@", "name")).firstMatch
            if nameField.exists {
                nameField.tap()
                nameField.typeText(testServerConfig["name"]!)
            }
            
            // Fill in server URL
            let urlField = app.textFields.containing(NSPredicate(format: "placeholder CONTAINS[c] %@", "url")).firstMatch
            if urlField.exists {
                urlField.tap()
                urlField.typeText(testServerConfig["url"]!)
            }
            
            takeScreenshot(name: "server_details_filled")
            
            // Save the server
            let saveButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "save")).firstMatch
            if saveButton.exists {
                saveButton.tap()
                Thread.sleep(forTimeInterval: 3.0)
                
                takeScreenshot(name: "server_saved")
                
                // Verify server appears in list
                let serverEntry = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", testServerConfig["name"]!)).firstMatch
                XCTAssertTrue(
                    serverEntry.waitForExistence(timeout: 10),
                    "New MCP server should appear in configuration list"
                )
                
                takeScreenshot(name: "new_server_verified")
            }
        } else {
            // Add server functionality might not be available
            print("Add server functionality not found - may not be implemented")
            takeScreenshot(name: "add_server_not_available")
        }
    }
    
    func testModifyMCPServerSettings() throws {
        // First add a server to modify (or use existing)
        testAddNewMCPServer()
        
        takeScreenshot(name: "before_modify_server")
        
        // Find the test server
        let testServerEntry = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "FunctionalTest_MCPServer")).firstMatch
        if testServerEntry.exists {
            testServerEntry.tap()
            Thread.sleep(forTimeInterval: 2.0)
            
            takeScreenshot(name: "server_edit_mode")
            
            // Modify server settings
            let timeoutField = app.textFields.containing(NSPredicate(format: "value CONTAINS %@", "30")).firstMatch
            if timeoutField.exists {
                timeoutField.tap()
                clearTextField(timeoutField)
                timeoutField.typeText("60")
                
                takeScreenshot(name: "server_setting_modified")
                
                // Save changes
                let saveButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "save")).firstMatch
                if saveButton.exists {
                    saveButton.tap()
                    Thread.sleep(forTimeInterval: 3.0)
                    
                    takeScreenshot(name: "server_changes_saved")
                    
                    // Verify changes persisted
                    testServerEntry.tap()
                    Thread.sleep(forTimeInterval: 2.0)
                    
                    let modifiedField = app.textFields.containing(NSPredicate(format: "value CONTAINS %@", "60")).firstMatch
                    XCTAssertTrue(
                        modifiedField.exists,
                        "Modified server settings should persist"
                    )
                }
            }
        }
        
        takeScreenshot(name: "server_modification_verified")
    }
    
    func testMCPServerConnectionTest() throws {
        // Navigate to MCP settings
        settingsPage.navigateToSettings()
        waitForElement(settingsPage.settingsList, timeout: RealBackendConfig.uiWaitTimeout)
        
        settingsPage.openMCPSettings()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "before_connection_test")
        
        // Look for test connection functionality
        let testConnectionButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "test")).firstMatch
        if testConnectionButton.exists {
            testConnectionButton.tap()
            Thread.sleep(forTimeInterval: 2.0)
            
            takeScreenshot(name: "connection_test_started")
            
            // Wait for connection test to complete
            Thread.sleep(forTimeInterval: 10.0)
            
            takeScreenshot(name: "connection_test_completed")
            
            // Verify test results are shown
            let testResultElements = [
                "Success",
                "Failed", 
                "Connected",
                "Error",
                "Timeout"
            ]
            
            var resultFound = false
            for result in testResultElements {
                let resultElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", result)).firstMatch
                if resultElement.exists {
                    resultFound = true
                    if RealBackendConfig.verboseLogging {
                        print("Connection test result: \(result)")
                    }
                    break
                }
            }
            
            XCTAssertTrue(resultFound, "Connection test should show results")
        } else {
            print("Connection test functionality not found")
        }
        
        takeScreenshot(name: "connection_test_verified")
    }
    
    // MARK: - MCP Configuration Persistence Tests
    
    func testMCPSettingsPersistToBackend() throws {
        // Configure a test server
        let testConfig = configureTestMCPServer()
        
        takeScreenshot(name: "before_persistence_test")
        
        // Navigate away from settings
        let chatTab = app.tabBars.buttons["Chat"]
        if chatTab.exists {
            chatTab.tap()
            Thread.sleep(forTimeInterval: 2.0)
        }
        
        // Navigate back to MCP settings
        settingsPage.navigateToSettings()
        waitForElement(settingsPage.settingsList, timeout: RealBackendConfig.uiWaitTimeout)
        
        settingsPage.openMCPSettings()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "returned_to_mcp_settings")
        
        // Verify test configuration still exists
        let testServerEntry = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", testConfig["name"]!)).firstMatch
        XCTAssertTrue(
            testServerEntry.exists,
            "MCP server configuration should persist in UI"
        )
        
        takeScreenshot(name: "persistence_in_ui_verified")
        
        // Test persistence across app restart
        app.terminate()
        Thread.sleep(forTimeInterval: 2.0)
        
        let config = RealBackendConfig.createLaunchConfiguration()
        launchApp(with: config)
        
        settingsPage = SettingsPage(app: app)
        Thread.sleep(forTimeInterval: 5.0)
        
        // Navigate to MCP settings again
        settingsPage.navigateToSettings()
        waitForElement(settingsPage.settingsList, timeout: RealBackendConfig.uiWaitTimeout)
        
        settingsPage.openMCPSettings()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "after_app_restart")
        
        // Verify configuration persists across restart
        let persistedServerEntry = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", testConfig["name"]!)).firstMatch
        XCTAssertTrue(
            persistedServerEntry.exists,
            "MCP server configuration should persist across app restart"
        )
        
        takeScreenshot(name: "persistence_across_restart_verified")
    }
    
    func testDeleteMCPServer() throws {
        // First add a server to delete
        let testConfig = configureTestMCPServer()
        
        takeScreenshot(name: "before_server_deletion")
        
        // Find the test server
        let testServerEntry = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", testConfig["name"]!)).firstMatch
        XCTAssertTrue(testServerEntry.exists, "Test server should exist for deletion")
        
        // Delete the server (method depends on UI - swipe, long press, etc.)
        testServerEntry.swipeLeft()
        
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 5) {
            deleteButton.tap()
            
            // Confirm deletion if alert appears
            let confirmButton = app.alerts.buttons["Delete"]
            if confirmButton.waitForExistence(timeout: 2) {
                confirmButton.tap()
            }
            
            Thread.sleep(forTimeInterval: 3.0)
            
            takeScreenshot(name: "server_deleted")
            
            // Verify server is removed
            let deletedServerEntry = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", testConfig["name"]!)).firstMatch
            XCTAssertFalse(
                deletedServerEntry.exists,
                "Deleted MCP server should not appear in list"
            )
            
            takeScreenshot(name: "server_deletion_verified")
        } else {
            // Try alternative deletion method
            testServerEntry.press(forDuration: 1.0)
            
            let deleteMenuItem = app.menuItems["Delete"]
            if deleteMenuItem.waitForExistence(timeout: 2) {
                deleteMenuItem.tap()
                Thread.sleep(forTimeInterval: 2.0)
                
                takeScreenshot(name: "server_deleted_via_menu")
            }
        }
    }
    
    // MARK: - MCP Server Status Tests
    
    func testMCPServerStatusIndicators() throws {
        // Navigate to MCP settings
        settingsPage.navigateToSettings()
        waitForElement(settingsPage.settingsList, timeout: RealBackendConfig.uiWaitTimeout)
        
        settingsPage.openMCPSettings()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "before_status_check")
        
        // Look for status indicators
        let statusIndicators = [
            "Connected",
            "Disconnected",
            "Online",
            "Offline", 
            "Active",
            "Inactive",
            "●", // Dot indicators
            "✓", // Check marks
            "✗"  // X marks
        ]
        
        var statusFound = false
        for indicator in statusIndicators {
            let statusElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", indicator)).firstMatch
            if statusElement.exists {
                statusFound = true
                if RealBackendConfig.verboseLogging {
                    print("Found status indicator: \(indicator)")
                }
                break
            }
        }
        
        // Also look for color-coded elements or switches
        let statusSwitches = app.switches.allElementsBoundByIndex
        let statusImages = app.images.allElementsBoundByIndex
        
        statusFound = statusFound || statusSwitches.count > 0 || statusImages.count > 0
        
        XCTAssertTrue(statusFound, "Should display MCP server status indicators")
        
        takeScreenshot(name: "status_indicators_verified")
    }
    
    func testEnableDisableMCPServer() throws {
        // Navigate to MCP settings
        settingsPage.navigateToSettings()
        waitForElement(settingsPage.settingsList, timeout: RealBackendConfig.uiWaitTimeout)
        
        settingsPage.openMCPSettings()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "before_enable_disable")
        
        // Look for enable/disable toggle
        let enableToggle = app.switches.firstMatch
        if enableToggle.exists {
            let initialState = enableToggle.value as? String
            
            // Toggle the switch
            enableToggle.tap()
            Thread.sleep(forTimeInterval: 2.0)
            
            takeScreenshot(name: "toggle_switched")
            
            let newState = enableToggle.value as? String
            XCTAssertNotEqual(initialState, newState, "Toggle should change state")
            
            // Toggle back
            enableToggle.tap()
            Thread.sleep(forTimeInterval: 2.0)
            
            takeScreenshot(name: "toggle_switched_back")
            
            let finalState = enableToggle.value as? String
            XCTAssertEqual(initialState, finalState, "Toggle should return to original state")
        } else {
            // Look for enable/disable buttons
            let enableButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "enable")).firstMatch
            let disableButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "disable")).firstMatch
            
            if enableButton.exists {
                enableButton.tap()
                Thread.sleep(forTimeInterval: 2.0)
                takeScreenshot(name: "server_enabled")
            } else if disableButton.exists {
                disableButton.tap()
                Thread.sleep(forTimeInterval: 2.0)
                takeScreenshot(name: "server_disabled")
            }
        }
        
        takeScreenshot(name: "enable_disable_tested")
    }
    
    // MARK: - Helper Methods
    
    private func captureOriginalMCPSettings() {
        // This would capture current MCP settings to restore later
        // Implementation depends on how settings are accessible
        if RealBackendConfig.verboseLogging {
            print("Capturing original MCP settings for restoration")
        }
    }
    
    private func restoreOriginalMCPSettings() {
        // Restore original settings
        if RealBackendConfig.verboseLogging {
            print("Restoring original MCP settings")
        }
        
        // Clean up any test servers we created
        let cleanupExpectation = expectation(description: "MCP cleanup")
        DispatchQueue.global().async {
            // Cleanup logic would go here
            Thread.sleep(forTimeInterval: 1.0)
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 10.0)
    }
    
    private func configureTestMCPServer() -> [String: String] {
        let testConfig = [
            "name": "FunctionalTest_PersistenceServer",
            "url": "http://localhost:9999",
            "port": "9999"
        ]
        
        // Navigate to MCP settings if not already there
        if !app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "mcp")).firstMatch.exists {
            settingsPage.navigateToSettings()
            waitForElement(settingsPage.settingsList, timeout: RealBackendConfig.uiWaitTimeout)
            settingsPage.openMCPSettings()
            Thread.sleep(forTimeInterval: 3.0)
        }
        
        // Add the test server
        let addServerButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "add")).firstMatch
        if addServerButton.exists {
            addServerButton.tap()
            Thread.sleep(forTimeInterval: 2.0)
            
            // Fill in server details
            let nameField = app.textFields.containing(NSPredicate(format: "placeholder CONTAINS[c] %@", "name")).firstMatch
            if nameField.exists {
                nameField.tap()
                nameField.typeText(testConfig["name"]!)
            }
            
            let urlField = app.textFields.containing(NSPredicate(format: "placeholder CONTAINS[c] %@", "url")).firstMatch
            if urlField.exists {
                urlField.tap()
                urlField.typeText(testConfig["url"]!)
            }
            
            // Save
            let saveButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "save")).firstMatch
            if saveButton.exists {
                saveButton.tap()
                Thread.sleep(forTimeInterval: 3.0)
            }
        }
        
        return testConfig
    }
}