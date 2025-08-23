//
//  ToolsPage.swift
//  ClaudeCodeUITests
//
//  Page object for Tools screens
//

import XCTest

/// Page object for Tools functionality
class ToolsPage: BasePage {
    
    // MARK: - Elements
    
    var toolsTab: XCUIElement {
        app.tabBars.buttons[AccessibilityIdentifier.tabBarTools]
    }
    
    var toolsList: XCUIElement {
        app.tables[AccessibilityIdentifier.toolsList]
    }
    
    var searchField: XCUIElement {
        app.searchFields[AccessibilityIdentifier.toolSearchField]
    }
    
    var categorySegmentedControl: XCUIElement {
        app.segmentedControls["tools.categories"]
    }
    
    var executeButton: XCUIElement {
        app.buttons[AccessibilityIdentifier.toolExecuteButton]
    }
    
    var favoriteButton: XCUIElement {
        app.buttons["tool.favorite"]
    }
    
    var historyButton: XCUIElement {
        app.buttons["tools.history"]
    }
    
    var parametersContainer: XCUIElement {
        app.scrollViews["tool.parameters"]
    }
    
    var outputView: XCUIElement {
        app.textViews["tool.output"]
    }
    
    var stopButton: XCUIElement {
        app.buttons["tool.stop"]
    }
    
    var clearButton: XCUIElement {
        app.buttons["tool.clear"]
    }
    
    var copyOutputButton: XCUIElement {
        app.buttons["tool.copy.output"]
    }
    
    var shareButton: XCUIElement {
        app.buttons["tool.share"]
    }
    
    // Tool Categories
    enum ToolCategory: String, CaseIterable {
        case all = "All"
        case file = "File"
        case system = "System"
        case network = "Network"
        case analysis = "Analysis"
        case security = "Security"
        case custom = "Custom"
    }
    
    // MARK: - Actions
    
    func navigateToTools() {
        toolsTab.tap()
        waitForPage()
    }
    
    func searchTools(_ query: String) {
        searchField.tap()
        searchField.typeText(query)
    }
    
    func selectCategory(_ category: ToolCategory) {
        categorySegmentedControl.buttons[category.rawValue].tap()
    }
    
    func selectTool(at index: Int) {
        let tool = toolsList.cells.element(boundBy: index)
        tool.tap()
    }
    
    func selectTool(named name: String) {
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        let tool = toolsList.cells.matching(predicate).firstMatch
        if tool.exists {
            tool.tap()
        }
    }
    
    func setParameter(name: String, value: String) {
        let paramField = app.textFields["param.\(name)"]
        if paramField.exists {
            paramField.tap()
            paramField.clearAndType(value)
        }
    }
    
    func setToggleParameter(name: String, enabled: Bool) {
        let toggle = app.switches["param.\(name)"]
        if toggle.exists {
            let currentValue = toggle.value as? String == "1"
            if currentValue != enabled {
                toggle.tap()
            }
        }
    }
    
    func selectDropdownParameter(name: String, option: String) {
        let dropdown = app.buttons["param.\(name)"]
        if dropdown.exists {
            dropdown.tap()
            
            let optionButton = app.buttons[option]
            if optionButton.waitForExistence(timeout: 2) {
                optionButton.tap()
            }
        }
    }
    
    func executeTool() {
        executeButton.tap()
    }
    
    func stopExecution() {
        if stopButton.exists && stopButton.isEnabled {
            stopButton.tap()
        }
    }
    
    func clearOutput() {
        clearButton.tap()
    }
    
    func copyOutput() {
        copyOutputButton.tap()
    }
    
    func shareTool() {
        shareButton.tap()
    }
    
    func favoriteTool() {
        favoriteButton.tap()
    }
    
    func openHistory() {
        historyButton.tap()
    }
    
    func selectHistoryItem(at index: Int) {
        let historyList = app.tables["tools.history.list"]
        let item = historyList.cells.element(boundBy: index)
        item.tap()
    }
    
    func rerunFromHistory(at index: Int) {
        let historyList = app.tables["tools.history.list"]
        let item = historyList.cells.element(boundBy: index)
        item.swipeLeft()
        
        let rerunButton = app.buttons["Rerun"]
        if rerunButton.waitForExistence(timeout: 2) {
            rerunButton.tap()
        }
    }
    
    // MARK: - Advanced Tool Actions
    
    func createCustomTool(name: String, command: String, description: String? = nil) {
        let addButton = app.buttons["tools.add.custom"]
        addButton.tap()
        
        let nameField = app.textFields["custom.tool.name"]
        if nameField.waitForExistence(timeout: 2) {
            nameField.tap()
            nameField.typeText(name)
            
            let commandField = app.textViews["custom.tool.command"]
            commandField.tap()
            commandField.typeText(command)
            
            if let desc = description {
                let descField = app.textViews["custom.tool.description"]
                descField.tap()
                descField.typeText(desc)
            }
            
            let saveButton = app.buttons["Save Tool"]
            saveButton.tap()
        }
    }
    
    func editCustomTool(named name: String) {
        selectTool(named: name)
        
        let editButton = app.buttons["tool.edit"]
        if editButton.exists {
            editButton.tap()
        }
    }
    
    func deleteCustomTool(named name: String) {
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        let tool = toolsList.cells.matching(predicate).firstMatch
        
        if tool.exists {
            tool.swipeLeft()
            
            let deleteButton = app.buttons["Delete"]
            if deleteButton.waitForExistence(timeout: 2) {
                deleteButton.tap()
                
                // Confirm deletion
                let confirmButton = app.alerts.buttons["Delete"]
                if confirmButton.waitForExistence(timeout: 2) {
                    confirmButton.tap()
                }
            }
        }
    }
    
    func importTool(from url: String) {
        let importButton = app.buttons["tools.import"]
        importButton.tap()
        
        let urlField = app.textFields["import.tool.url"]
        if urlField.waitForExistence(timeout: 2) {
            urlField.tap()
            urlField.typeText(url)
            
            let importConfirmButton = app.buttons["Import"]
            importConfirmButton.tap()
        }
    }
    
    func exportTool(named name: String) {
        selectTool(named: name)
        
        let moreButton = app.buttons["tool.more"]
        if moreButton.exists {
            moreButton.tap()
            
            let exportButton = app.buttons["Export Tool"]
            if exportButton.waitForExistence(timeout: 2) {
                exportButton.tap()
            }
        }
    }
    
    // MARK: - Verification
    
    override func waitForPage(timeout: TimeInterval = 10) {
        _ = toolsList.waitForExistence(timeout: timeout)
    }
    
    func verifyToolExists(_ name: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        let tool = toolsList.cells.matching(predicate).firstMatch
        return tool.exists
    }
    
    func verifyToolCount() -> Int {
        return toolsList.cells.count
    }
    
    func verifyExecuteButtonEnabled() -> Bool {
        return executeButton.isEnabled
    }
    
    func verifyToolIsExecuting() -> Bool {
        return app.activityIndicators["tool.executing"].exists || 
               (stopButton.exists && stopButton.isEnabled)
    }
    
    func verifyOutputContains(_ text: String) -> Bool {
        let outputText = outputView.value as? String ?? ""
        return outputText.contains(text)
    }
    
    func verifyParameterValue(name: String, expectedValue: String) -> Bool {
        let paramField = app.textFields["param.\(name)"]
        if paramField.exists {
            return paramField.value as? String == expectedValue
        }
        return false
    }
    
    func verifyToolIsFavorited() -> Bool {
        return favoriteButton.isSelected
    }
    
    func waitForExecutionComplete(timeout: TimeInterval = 30) -> Bool {
        let executingIndicator = app.activityIndicators["tool.executing"]
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: executingIndicator)
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    // MARK: - Tool Panel Actions
    
    func expandToolPanel() {
        let panelHandle = app.otherElements["tools.panel.handle"]
        if panelHandle.exists {
            panelHandle.swipeUp()
        }
    }
    
    func collapseToolPanel() {
        let panelHandle = app.otherElements["tools.panel.handle"]
        if panelHandle.exists {
            panelHandle.swipeDown()
        }
    }
    
    func pinToolToQuickAccess(named name: String) {
        selectTool(named: name)
        
        let pinButton = app.buttons["tool.pin"]
        if pinButton.exists {
            pinButton.tap()
        }
    }
    
    func accessQuickTool(at index: Int) {
        let quickAccessBar = app.toolbars["tools.quick.access"]
        let tool = quickAccessBar.buttons.element(boundBy: index)
        if tool.exists {
            tool.tap()
        }
    }
}