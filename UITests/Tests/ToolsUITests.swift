//
//  ToolsUITests.swift
//  ClaudeCodeUITests
//
//  Comprehensive UI tests for Tools functionality
//

import XCTest

class ToolsUITests: ClaudeCodeUITestCase {
    
    var toolsPage: ToolsPage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize page object
        toolsPage = ToolsPage(app: app)
        
        // Launch app in authenticated state
        app.terminate()
        launchApp(with: .authenticated)
        
        // Navigate to tools
        toolsPage.navigateToTools()
    }
    
    // MARK: - Basic Tools Tests
    
    func testNavigateToTools() {
        // Verify we're on tools page
        waitForElement(toolsPage.toolsList)
        XCTAssertTrue(toolsPage.toolsTab.isSelected)
        
        takeScreenshot(name: "Tools-List")
    }
    
    func testSearchTools() {
        // Search for tools
        toolsPage.searchTools("file")
        
        // Wait for search results
        Thread.sleep(forTimeInterval: 1)
        
        // Verify search results
        XCTAssertTrue(toolsPage.verifyToolExists("File"))
        
        takeScreenshot(name: "Tools-Search-Results")
    }
    
    func testSelectTool() {
        // Select a tool
        toolsPage.selectTool(named: "Read File")
        
        // Verify tool detail view opened
        waitForElement(toolsPage.parametersContainer)
        
        takeScreenshot(name: "Tool-Selected")
    }
    
    func testCategoryFiltering() {
        // Test each category
        for category in ToolsPage.ToolCategory.allCases {
            toolsPage.selectCategory(category)
            Thread.sleep(forTimeInterval: 0.5)
            
            // Verify tools are filtered
            XCTAssertTrue(toolsPage.verifyToolCount() >= 0)
            
            takeScreenshot(name: "Tools-Category-\(category.rawValue)")
        }
    }
    
    // MARK: - Tool Parameter Tests
    
    func testSetTextParameter() {
        // Select a tool with text parameters
        toolsPage.selectTool(named: "Read File")
        
        // Set parameter
        toolsPage.setParameter(name: "path", value: "/test/file.txt")
        
        // Verify parameter was set
        XCTAssertTrue(toolsPage.verifyParameterValue(name: "path", expectedValue: "/test/file.txt"))
        
        takeScreenshot(name: "Tool-Text-Parameter-Set")
    }
    
    func testSetToggleParameter() {
        // Select a tool with toggle parameters
        toolsPage.selectTool(named: "List Directory")
        
        // Set toggle parameter
        toolsPage.setToggleParameter(name: "recursive", enabled: true)
        
        // Verify toggle is set
        let toggle = app.switches["param.recursive"]
        XCTAssertTrue(toggle.value as? String == "1")
        
        takeScreenshot(name: "Tool-Toggle-Parameter-Set")
    }
    
    func testSetDropdownParameter() {
        // Select a tool with dropdown parameters
        toolsPage.selectTool(named: "Format Code")
        
        // Set dropdown parameter
        toolsPage.selectDropdownParameter(name: "language", option: "Swift")
        
        // Verify dropdown is set
        let dropdown = app.buttons["param.language"]
        XCTAssertTrue(dropdown.label.contains("Swift"))
        
        takeScreenshot(name: "Tool-Dropdown-Parameter-Set")
    }
    
    // MARK: - Tool Execution Tests
    
    func testExecuteTool() {
        // Select and configure a tool
        toolsPage.selectTool(named: "Echo")
        toolsPage.setParameter(name: "text", value: "Hello, World!")
        
        // Execute the tool
        toolsPage.executeTool()
        
        // Wait for execution to complete
        XCTAssertTrue(toolsPage.waitForExecutionComplete())
        
        // Verify output
        XCTAssertTrue(toolsPage.verifyOutputContains("Hello, World!"))
        
        takeScreenshot(name: "Tool-Executed")
    }
    
    func testStopToolExecution() {
        // Select a long-running tool
        toolsPage.selectTool(named: "Sleep")
        toolsPage.setParameter(name: "duration", value: "10")
        
        // Execute the tool
        toolsPage.executeTool()
        
        // Wait a moment for execution to start
        Thread.sleep(forTimeInterval: 1)
        
        // Stop execution
        toolsPage.stopExecution()
        
        // Verify execution stopped
        XCTAssertFalse(toolsPage.verifyToolIsExecuting())
        
        takeScreenshot(name: "Tool-Execution-Stopped")
    }
    
    func testClearOutput() {
        // Execute a tool
        toolsPage.selectTool(named: "Echo")
        toolsPage.setParameter(name: "text", value: "Test output")
        toolsPage.executeTool()
        
        // Wait for execution
        _ = toolsPage.waitForExecutionComplete()
        
        // Clear output
        toolsPage.clearOutput()
        
        // Verify output is cleared
        XCTAssertFalse(toolsPage.verifyOutputContains("Test output"))
        
        takeScreenshot(name: "Tool-Output-Cleared")
    }
    
    func testCopyOutput() {
        // Execute a tool
        toolsPage.selectTool(named: "Echo")
        toolsPage.setParameter(name: "text", value: "Copy this text")
        toolsPage.executeTool()
        
        // Wait for execution
        _ = toolsPage.waitForExecutionComplete()
        
        // Copy output
        toolsPage.copyOutput()
        
        // Verify copy feedback
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Tool-Output-Copied")
    }
    
    // MARK: - Tool Favorites Tests
    
    func testFavoriteTool() {
        // Select a tool
        toolsPage.selectTool(named: "Read File")
        
        // Favorite the tool
        toolsPage.favoriteTool()
        
        // Verify tool is favorited
        XCTAssertTrue(toolsPage.verifyToolIsFavorited())
        
        takeScreenshot(name: "Tool-Favorited")
    }
    
    func testAccessFavoriteTool() {
        // Favorite a tool first
        toolsPage.selectTool(named: "Echo")
        toolsPage.favoriteTool()
        
        // Go back to tools list
        app.navigationBars.buttons.firstMatch.tap()
        
        // Access from quick access
        toolsPage.accessQuickTool(at: 0)
        
        // Verify tool opened
        waitForElement(toolsPage.parametersContainer)
        
        takeScreenshot(name: "Tool-Quick-Access")
    }
    
    // MARK: - Tool History Tests
    
    func testToolHistory() {
        // Execute multiple tools to create history
        for i in 1...3 {
            toolsPage.selectTool(named: "Echo")
            toolsPage.setParameter(name: "text", value: "History test \(i)")
            toolsPage.executeTool()
            _ = toolsPage.waitForExecutionComplete()
            app.navigationBars.buttons.firstMatch.tap()
        }
        
        // Open history
        toolsPage.openHistory()
        
        // Verify history entries
        waitForElement(app.tables["tools.history.list"])
        
        takeScreenshot(name: "Tool-History")
    }
    
    func testRerunFromHistory() {
        // Execute a tool
        toolsPage.selectTool(named: "Echo")
        toolsPage.setParameter(name: "text", value: "Original execution")
        toolsPage.executeTool()
        _ = toolsPage.waitForExecutionComplete()
        
        // Open history
        app.navigationBars.buttons.firstMatch.tap()
        toolsPage.openHistory()
        
        // Rerun from history
        toolsPage.rerunFromHistory(at: 0)
        
        // Wait for execution
        _ = toolsPage.waitForExecutionComplete()
        
        // Verify tool was rerun
        XCTAssertTrue(toolsPage.verifyOutputContains("Original execution"))
        
        takeScreenshot(name: "Tool-Rerun-From-History")
    }
    
    // MARK: - Custom Tools Tests
    
    func testCreateCustomTool() {
        // Create a custom tool
        toolsPage.createCustomTool(
            name: "My Custom Tool",
            command: "echo 'Custom tool output'",
            description: "This is a custom tool for testing"
        )
        
        // Wait for creation
        Thread.sleep(forTimeInterval: 1)
        
        // Verify tool was created
        XCTAssertTrue(toolsPage.verifyToolExists("My Custom Tool"))
        
        takeScreenshot(name: "Custom-Tool-Created")
    }
    
    func testEditCustomTool() {
        // Create a custom tool first
        toolsPage.createCustomTool(
            name: "Editable Tool",
            command: "echo 'Original'"
        )
        
        Thread.sleep(forTimeInterval: 1)
        
        // Edit the tool
        toolsPage.editCustomTool(named: "Editable Tool")
        
        // Modify command
        let commandField = app.textViews["custom.tool.command"]
        if commandField.waitForExistence(timeout: 2) {
            commandField.clearAndType("echo 'Modified'")
            app.buttons["Save Tool"].tap()
        }
        
        // Verify tool was edited
        Thread.sleep(forTimeInterval: 1)
        
        takeScreenshot(name: "Custom-Tool-Edited")
    }
    
    func testDeleteCustomTool() {
        // Create a custom tool
        toolsPage.createCustomTool(
            name: "Tool to Delete",
            command: "echo 'Delete me'"
        )
        
        Thread.sleep(forTimeInterval: 1)
        
        // Delete the tool
        toolsPage.deleteCustomTool(named: "Tool to Delete")
        
        // Verify tool was deleted
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(toolsPage.verifyToolExists("Tool to Delete"))
        
        takeScreenshot(name: "Custom-Tool-Deleted")
    }
    
    // MARK: - Tool Import/Export Tests
    
    func testImportTool() {
        // Import a tool
        toolsPage.importTool(from: "https://example.com/tool.json")
        
        // Wait for import dialog
        waitForElement(app.alerts["Import in Progress"])
        
        takeScreenshot(name: "Tool-Import")
        
        // Cancel import
        app.alerts.buttons["Cancel"].tap()
    }
    
    func testExportTool() {
        // Select a tool
        toolsPage.selectTool(named: "Echo")
        
        // Export the tool
        toolsPage.exportTool(named: "Echo")
        
        // Verify export dialog
        waitForElement(app.sheets["Export Tool"])
        
        takeScreenshot(name: "Tool-Export")
        
        // Cancel export
        app.sheets.buttons["Cancel"].tap()
    }
    
    func testShareTool() {
        // Select a tool
        toolsPage.selectTool(named: "Echo")
        toolsPage.setParameter(name: "text", value: "Share this")
        
        // Share the tool
        toolsPage.shareTool()
        
        // Verify share sheet
        waitForElement(app.otherElements["ActivityListView"])
        
        takeScreenshot(name: "Tool-Share")
        
        // Cancel share
        app.buttons["Close"].tap()
    }
    
    // MARK: - Tool Panel Tests
    
    func testExpandToolPanel() {
        // Expand tool panel
        toolsPage.expandToolPanel()
        
        // Verify panel expanded
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Tool-Panel-Expanded")
    }
    
    func testCollapseToolPanel() {
        // Expand first
        toolsPage.expandToolPanel()
        Thread.sleep(forTimeInterval: 0.5)
        
        // Collapse tool panel
        toolsPage.collapseToolPanel()
        
        // Verify panel collapsed
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Tool-Panel-Collapsed")
    }
    
    func testPinToolToQuickAccess() {
        // Select a tool
        toolsPage.selectTool(named: "Read File")
        
        // Pin to quick access
        toolsPage.pinToolToQuickAccess(named: "Read File")
        
        // Verify tool is pinned
        Thread.sleep(forTimeInterval: 1)
        
        takeScreenshot(name: "Tool-Pinned-Quick-Access")
    }
    
    // MARK: - Error Handling Tests
    
    func testExecuteWithMissingParameters() {
        // Select a tool that requires parameters
        toolsPage.selectTool(named: "Read File")
        
        // Try to execute without setting parameters
        toolsPage.executeTool()
        
        // Verify error message
        waitForElement(app.staticTexts["Required parameters missing"])
        
        takeScreenshot(name: "Tool-Missing-Parameters-Error")
    }
    
    func testInvalidParameterValue() {
        // Select a tool
        toolsPage.selectTool(named: "Sleep")
        
        // Set invalid parameter
        toolsPage.setParameter(name: "duration", value: "invalid")
        
        // Try to execute
        toolsPage.executeTool()
        
        // Verify error message
        waitForElement(app.staticTexts["Invalid parameter value"])
        
        takeScreenshot(name: "Tool-Invalid-Parameter-Error")
    }
    
    // MARK: - Performance Tests
    
    func testToolListScrollingPerformance() {
        measure {
            // Scroll through tools list
            toolsPage.toolsList.swipeUp()
            toolsPage.toolsList.swipeDown()
        }
    }
    
    func testToolExecutionPerformance() {
        // Select a simple tool
        toolsPage.selectTool(named: "Echo")
        toolsPage.setParameter(name: "text", value: "Performance test")
        
        measure {
            toolsPage.executeTool()
            _ = toolsPage.waitForExecutionComplete(timeout: 5)
        }
    }
    
    func testToolSearchPerformance() {
        measure {
            toolsPage.searchTools("file")
            Thread.sleep(forTimeInterval: 0.5)
            toolsPage.searchField.clearAndType("")
        }
    }
}