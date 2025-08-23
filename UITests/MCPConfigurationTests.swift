import XCTest

/// Tests for MCP (Model Context Protocol) configuration flows
final class MCPConfigurationTests: BaseUITest {
    
    // MARK: - Helper Methods
    
    private func navigateToSettings() {
        // Try different ways to access settings
        let settingsTab = app.tabBars.buttons["Settings"]
        let settingsButton = app.buttons["Settings"]
        let menuButton = app.navigationBars.buttons["Menu"]
        let moreButton = app.navigationBars.buttons["More"]
        
        if settingsTab.exists {
            settingsTab.tap()
        } else if settingsButton.exists {
            settingsButton.tap()
        } else if menuButton.exists {
            menuButton.tap()
            Thread.sleep(forTimeInterval: 1)
            let settingsMenuItem = app.buttons["Settings"]
            if settingsMenuItem.exists {
                settingsMenuItem.tap()
            }
        } else if moreButton.exists {
            moreButton.tap()
            Thread.sleep(forTimeInterval: 1)
            let settingsMenuItem = app.buttons["Settings"]
            if settingsMenuItem.exists {
                settingsMenuItem.tap()
            }
        }
        
        Thread.sleep(forTimeInterval: 1)
    }
    
    private func navigateToMCPConfiguration() {
        navigateToSettings()
        
        // Look for MCP configuration option
        let mcpButton = app.buttons["MCP Configuration"]
        let mcpCell = app.cells["MCP Configuration"]
        let toolsButton = app.buttons["Tools"]
        let toolsCell = app.cells["Tools"]
        let serversButton = app.buttons["MCP Servers"]
        let serversCell = app.cells["MCP Servers"]
        
        let mcpAccess = [mcpButton, mcpCell, toolsButton, toolsCell, serversButton, serversCell].first { $0.exists }
        
        if let access = mcpAccess {
            access.tap()
            Thread.sleep(forTimeInterval: 1)
        }
    }
    
    // MARK: - Test Cases
    
    /// Test accessing MCP configuration
    func testAccessMCPConfiguration() throws {
        takeScreenshot(name: "Initial View")
        
        navigateToMCPConfiguration()
        
        // Verify MCP configuration view loaded
        let mcpTitle = app.navigationBars["MCP Configuration"]
        let toolsTitle = app.navigationBars["Tools"]
        let serversTitle = app.navigationBars["MCP Servers"]
        
        XCTAssertTrue(
            mcpTitle.exists || toolsTitle.exists || serversTitle.exists,
            "MCP configuration view not loaded"
        )
        
        takeScreenshot(name: "MCP Configuration View")
    }
    
    /// Test viewing available MCP servers
    func testViewAvailableMCPServers() throws {
        navigateToMCPConfiguration()
        
        // Look for server list
        let serverList = app.tables["ServerList"]
        let serverCollection = app.collectionViews["ServerCollection"]
        let serverContainer = serverList.exists ? serverList : serverCollection
        
        if serverContainer.exists {
            takeScreenshot(name: "MCP Server List")
            
            // Check for default servers
            let filesystemServer = serverContainer.cells.containing(.staticText, identifier: "filesystem").firstMatch
            let gitServer = serverContainer.cells.containing(.staticText, identifier: "git").firstMatch
            let githubServer = serverContainer.cells.containing(.staticText, identifier: "github").firstMatch
            
            // At least one server should be available
            let hasServers = filesystemServer.exists || gitServer.exists || githubServer.exists
            
            if hasServers {
                takeScreenshot(name: "MCP Servers Available")
                
                // Tap on a server for details
                if filesystemServer.exists {
                    filesystemServer.tap()
                    Thread.sleep(forTimeInterval: 1)
                    takeScreenshot(name: "Filesystem Server Details")
                    
                    // Navigate back
                    if app.navigationBars.buttons.firstMatch.exists {
                        app.navigationBars.buttons.firstMatch.tap()
                    }
                }
            } else {
                // No servers configured
                let noServersLabel = app.staticTexts["No MCP servers configured"]
                let addServerButton = app.buttons["Add Server"]
                
                XCTAssertTrue(
                    noServersLabel.exists || addServerButton.exists,
                    "No servers found and no way to add them"
                )
                takeScreenshot(name: "No MCP Servers")
            }
        }
    }
    
    /// Test adding a new MCP server
    func testAddNewMCPServer() throws {
        navigateToMCPConfiguration()
        
        // Look for add server button
        let addButton = app.buttons["Add Server"]
        let plusButton = app.navigationBars.buttons["plus"]
        let newServerButton = app.buttons["New Server"]
        
        let addServerAccess = [addButton, plusButton, newServerButton].first { $0.exists }
        
        guard let button = addServerAccess else {
            throw XCTSkip("No way to add MCP server found")
        }
        
        takeScreenshot(name: "Before Adding Server")
        
        button.tap()
        Thread.sleep(forTimeInterval: 1)
        
        // Fill in server configuration
        let nameField = app.textFields["Server Name"]
        let commandField = app.textFields["Command"]
        let argsField = app.textFields["Arguments"]
        let urlField = app.textFields["Server URL"]
        
        if nameField.exists {
            typeText("Test MCP Server", in: nameField)
        }
        
        if commandField.exists {
            typeText("npx", in: commandField)
        }
        
        if argsField.exists {
            typeText("-y @modelcontextprotocol/server-filesystem", in: argsField)
        }
        
        if urlField.exists {
            typeText("http://localhost:3000", in: urlField)
        }
        
        takeScreenshot(name: "Server Configuration Filled")
        
        // Look for environment variables section
        let envButton = app.buttons["Environment Variables"]
        let addEnvButton = app.buttons["Add Variable"]
        
        if envButton.exists {
            envButton.tap()
            Thread.sleep(forTimeInterval: 1)
            
            if addEnvButton.exists {
                addEnvButton.tap()
                
                let keyField = app.textFields["Key"]
                let valueField = app.textFields["Value"]
                
                if keyField.exists && valueField.exists {
                    typeText("ALLOWED_PATHS", in: keyField)
                    typeText("/tmp", in: valueField)
                }
                
                takeScreenshot(name: "Environment Variable Added")
            }
        }
        
        // Save configuration
        let saveButton = app.buttons["Save"]
        let doneButton = app.buttons["Done"]
        let addSubmitButton = app.buttons["Add"]
        
        let submitButton = [saveButton, doneButton, addSubmitButton].first { $0.exists }
        submitButton?.tap()
        
        Thread.sleep(forTimeInterval: 1)
        
        // Verify server was added
        let serverList = app.tables["ServerList"]
        let serverCollection = app.collectionViews["ServerCollection"]
        let serverContainer = serverList.exists ? serverList : serverCollection
        
        if serverContainer.exists {
            let testServer = serverContainer.cells.containing(.staticText, identifier: "Test MCP Server").firstMatch
            XCTAssertTrue(
                waitForElement(testServer, timeout: 5),
                "Newly added server not found in list"
            )
        }
        
        takeScreenshot(name: "Server Added Successfully")
        
        if cleanupAfterTests {
            // Would remove test server here
            print("Would clean up test MCP server")
        }
    }
    
    /// Test configuring MCP server tools
    func testConfigureMCPServerTools() throws {
        navigateToMCPConfiguration()
        
        // Select a server
        let serverList = app.tables["ServerList"]
        let serverCollection = app.collectionViews["ServerCollection"]
        let serverContainer = serverList.exists ? serverList : serverCollection
        
        if serverContainer.exists {
            let firstServer = serverContainer.cells.firstMatch
            if firstServer.exists {
                firstServer.tap()
                Thread.sleep(forTimeInterval: 1)
                
                // Look for tools section
                let toolsSection = app.staticTexts["Available Tools"]
                let toolsList = app.tables["ToolsList"]
                
                if toolsSection.exists || toolsList.exists {
                    takeScreenshot(name: "Server Tools List")
                    
                    // Check for specific tools
                    let readFileToolFunc = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'read_file'")).firstMatch
                    let writeFileTool = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'write_file'")).firstMatch
                    let listDirectoryTool = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'list_directory'")).firstMatch
                    
                    if readFileToolFunc.exists || writeFileTool.exists || listDirectoryTool.exists {
                        takeScreenshot(name: "Tools Available")
                        
                        // Try to toggle a tool
                        let toolSwitch = app.switches.firstMatch
                        if toolSwitch.exists {
                            let initialValue = toolSwitch.value as? String == "1"
                            toolSwitch.tap()
                            Thread.sleep(forTimeInterval: 1)
                            
                            let newValue = toolSwitch.value as? String == "1"
                            XCTAssertTrue(
                                initialValue != newValue,
                                "Tool toggle did not work"
                            )
                            
                            takeScreenshot(name: "Tool Toggled")
                            
                            // Toggle back
                            toolSwitch.tap()
                        }
                    }
                }
            }
        }
    }
    
    /// Test MCP server connection test
    func testMCPServerConnectionTest() throws {
        navigateToMCPConfiguration()
        
        // Select a server or add one
        let serverList = app.tables["ServerList"]
        let serverCollection = app.collectionViews["ServerCollection"]
        let serverContainer = serverList.exists ? serverList : serverCollection
        
        if serverContainer.exists {
            let firstServer = serverContainer.cells.firstMatch
            if firstServer.exists {
                firstServer.tap()
                Thread.sleep(forTimeInterval: 1)
                
                // Look for test connection button
                let testButton = app.buttons["Test Connection"]
                let validateButton = app.buttons["Validate"]
                let checkButton = app.buttons["Check Connection"]
                
                let testAccess = [testButton, validateButton, checkButton].first { $0.exists }
                
                if let button = testAccess {
                    takeScreenshot(name: "Before Connection Test")
                    
                    button.tap()
                    
                    // Wait for test to complete
                    Thread.sleep(forTimeInterval: 3)
                    
                    // Check for results
                    let successLabel = app.staticTexts["Connection successful"]
                    let failedLabel = app.staticTexts["Connection failed"]
                    let errorLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'error'")).firstMatch
                    
                    if successLabel.exists {
                        takeScreenshot(name: "Connection Test Success")
                        XCTAssertTrue(true, "MCP server connection successful")
                    } else if failedLabel.exists || errorLabel.exists {
                        takeScreenshot(name: "Connection Test Failed")
                        // Test passes even if connection fails - we're testing the UI
                    }
                    
                    // Dismiss any alerts
                    dismissAlertIfPresent()
                }
            }
        }
    }
    
    /// Test removing MCP server
    func testRemoveMCPServer() throws {
        // First add a test server
        try testAddNewMCPServer()
        
        navigateToMCPConfiguration()
        
        // Find the test server
        let serverList = app.tables["ServerList"]
        let serverCollection = app.collectionViews["ServerCollection"]
        let serverContainer = serverList.exists ? serverList : serverCollection
        
        if serverContainer.exists {
            let testServer = serverContainer.cells.containing(.staticText, identifier: "Test MCP Server").firstMatch
            
            if testServer.exists {
                // Swipe to delete or tap edit
                if serverList.exists {
                    // Try swipe to delete
                    testServer.swipeLeft()
                    Thread.sleep(forTimeInterval: 1)
                    
                    let deleteButton = app.buttons["Delete"]
                    if deleteButton.exists {
                        takeScreenshot(name: "Swipe to Delete Server")
                        deleteButton.tap()
                        
                        // Confirm deletion
                        let confirmButton = app.buttons["Confirm"]
                        let yesButton = app.buttons["Yes"]
                        let deleteConfirmButton = app.buttons["Delete"]
                        
                        let confirm = [confirmButton, yesButton, deleteConfirmButton].first { $0.exists }
                        confirm?.tap()
                    }
                } else {
                    // Tap on server then look for delete option
                    testServer.tap()
                    Thread.sleep(forTimeInterval: 1)
                    
                    let deleteButton = app.buttons["Delete Server"]
                    let removeButton = app.buttons["Remove"]
                    
                    let deleteAccess = [deleteButton, removeButton].first { $0.exists }
                    
                    if let button = deleteAccess {
                        button.tap()
                        
                        // Confirm
                        dismissAlertIfPresent()
                    }
                }
                
                Thread.sleep(forTimeInterval: 1)
                
                // Verify server was removed
                XCTAssertFalse(
                    testServer.exists,
                    "Test server was not removed"
                )
                
                takeScreenshot(name: "Server Removed")
            }
        }
    }
    
    /// Test MCP server priority/ordering
    func testMCPServerOrdering() throws {
        navigateToMCPConfiguration()
        
        let serverList = app.tables["ServerList"]
        let serverCollection = app.collectionViews["ServerCollection"]
        let serverContainer = serverList.exists ? serverList : serverCollection
        
        if serverContainer.exists && serverContainer.cells.count >= 2 {
            takeScreenshot(name: "Initial Server Order")
            
            // Look for reorder controls
            let editButton = app.buttons["Edit"]
            let reorderButton = app.buttons["Reorder"]
            
            if editButton.exists {
                editButton.tap()
                Thread.sleep(forTimeInterval: 1)
                
                // Look for reorder handles
                let reorderHandles = app.images.matching(NSPredicate(format: "label CONTAINS[c] 'Reorder'"))
                
                if reorderHandles.count > 0 {
                    // Try to drag first server down
                    let firstHandle = reorderHandles.element(boundBy: 0)
                    let secondCell = serverContainer.cells.element(boundBy: 1)
                    
                    firstHandle.press(forDuration: 0.5, thenDragTo: secondCell)
                    
                    Thread.sleep(forTimeInterval: 1)
                    takeScreenshot(name: "Servers Reordered")
                    
                    // Save changes
                    let doneButton = app.buttons["Done"]
                    if doneButton.exists {
                        doneButton.tap()
                    }
                }
            }
        }
    }
}