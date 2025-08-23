//
//  ProjectsPage.swift
//  ClaudeCodeUITests
//
//  Page object for Projects screens
//

import XCTest

/// Page object for Projects functionality
class ProjectsPage: BasePage {
    
    // MARK: - Elements
    
    var projectsTab: XCUIElement {
        app.tabBars.buttons[AccessibilityIdentifier.tabBarProjects]
    }
    
    var projectsList: XCUIElement {
        app.tables[AccessibilityIdentifier.projectsList]
    }
    
    var newProjectButton: XCUIElement {
        app.buttons[AccessibilityIdentifier.projectNewButton]
    }
    
    var projectNameField: XCUIElement {
        app.textFields[AccessibilityIdentifier.projectNameField]
    }
    
    var projectPathField: XCUIElement {
        app.textFields[AccessibilityIdentifier.projectPathField]
    }
    
    var projectDescriptionField: XCUIElement {
        app.textViews["project.description"]
    }
    
    var createProjectButton: XCUIElement {
        app.buttons[AccessibilityIdentifier.projectCreateButton]
    }
    
    var searchField: XCUIElement {
        app.searchFields["Search projects"]
    }
    
    var filterButton: XCUIElement {
        app.buttons["projects.filter"]
    }
    
    var sortButton: XCUIElement {
        app.buttons["projects.sort"]
    }
    
    var projectSettingsButton: XCUIElement {
        app.buttons["project.settings"]
    }
    
    var browseButton: XCUIElement {
        app.buttons["project.browse"]
    }
    
    var gitStatusLabel: XCUIElement {
        app.staticTexts["project.git.status"]
    }
    
    // MARK: - Actions
    
    func navigateToProjects() {
        projectsTab.tap()
        waitForPage()
    }
    
    func createNewProject(name: String, path: String, description: String? = nil) {
        newProjectButton.tap()
        
        _ = projectNameField.waitForExistence(timeout: 5)
        projectNameField.tap()
        projectNameField.typeText(name)
        
        projectPathField.tap()
        projectPathField.typeText(path)
        
        if let desc = description {
            projectDescriptionField.tap()
            projectDescriptionField.typeText(desc)
        }
        
        createProjectButton.tap()
    }
    
    func selectProject(at index: Int) {
        let project = projectsList.cells.element(boundBy: index)
        project.tap()
    }
    
    func selectProject(named name: String) {
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        let project = projectsList.cells.matching(predicate).firstMatch
        if project.exists {
            project.tap()
        }
    }
    
    func searchProjects(_ query: String) {
        searchField.tap()
        searchField.typeText(query)
    }
    
    func openFilters() {
        filterButton.tap()
    }
    
    func changeSorting() {
        sortButton.tap()
    }
    
    func openProjectSettings() {
        projectSettingsButton.tap()
    }
    
    func browseProjectFiles() {
        browseButton.tap()
    }
    
    func deleteProject(at index: Int) {
        let project = projectsList.cells.element(boundBy: index)
        project.swipeLeft()
        
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
    
    func archiveProject(at index: Int) {
        let project = projectsList.cells.element(boundBy: index)
        project.swipeLeft()
        
        let archiveButton = app.buttons["Archive"]
        if archiveButton.waitForExistence(timeout: 2) {
            archiveButton.tap()
        }
    }
    
    func favoriteProject(at index: Int) {
        let project = projectsList.cells.element(boundBy: index)
        project.swipeRight()
        
        let favoriteButton = app.buttons["Favorite"]
        if favoriteButton.waitForExistence(timeout: 2) {
            favoriteButton.tap()
        }
    }
    
    // MARK: - Project Detail Actions
    
    func openFile(named fileName: String) {
        let predicate = NSPredicate(format: "label CONTAINS %@", fileName)
        let file = app.cells.matching(predicate).firstMatch
        if file.exists {
            file.tap()
        }
    }
    
    func runCommand(_ command: String) {
        let commandField = app.textFields["project.command"]
        commandField.tap()
        commandField.typeText(command)
        
        let runButton = app.buttons["project.run"]
        runButton.tap()
    }
    
    func openTerminal() {
        let terminalButton = app.buttons["project.terminal"]
        terminalButton.tap()
    }
    
    func syncProject() {
        let syncButton = app.buttons["project.sync"]
        syncButton.tap()
    }
    
    func commitChanges(message: String) {
        let commitButton = app.buttons["project.commit"]
        commitButton.tap()
        
        let messageField = app.textViews["commit.message"]
        if messageField.waitForExistence(timeout: 2) {
            messageField.tap()
            messageField.typeText(message)
            
            let confirmButton = app.buttons["Commit"]
            confirmButton.tap()
        }
    }
    
    // MARK: - Verification
    
    override func waitForPage(timeout: TimeInterval = 10) {
        _ = projectsList.waitForExistence(timeout: timeout)
    }
    
    func verifyProjectExists(_ name: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        let project = projectsList.cells.matching(predicate).firstMatch
        return project.exists
    }
    
    func verifyProjectCount() -> Int {
        return projectsList.cells.count
    }
    
    func verifyGitStatus(_ status: String) -> Bool {
        return gitStatusLabel.label.contains(status)
    }
    
    func verifyFileExists(_ fileName: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", fileName)
        let file = app.cells.matching(predicate).firstMatch
        return file.exists
    }
    
    func verifyCommandOutput(_ expectedText: String) -> Bool {
        let outputView = app.textViews["command.output"]
        return outputView.value as? String ?? "" == expectedText
    }
    
    // MARK: - Advanced Actions
    
    func importProject(from url: String) {
        let importButton = app.buttons["projects.import"]
        importButton.tap()
        
        let urlField = app.textFields["import.url"]
        if urlField.waitForExistence(timeout: 2) {
            urlField.tap()
            urlField.typeText(url)
            
            let importConfirmButton = app.buttons["Import"]
            importConfirmButton.tap()
        }
    }
    
    func exportProject(at index: Int) {
        selectProject(at: index)
        projectSettingsButton.tap()
        
        let exportButton = app.buttons["Export Project"]
        if exportButton.waitForExistence(timeout: 2) {
            exportButton.tap()
        }
    }
    
    func shareProject(at index: Int) {
        selectProject(at: index)
        projectSettingsButton.tap()
        
        let shareButton = app.buttons["Share Project"]
        if shareButton.waitForExistence(timeout: 2) {
            shareButton.tap()
        }
    }
    
    func duplicateProject(at index: Int) {
        let project = projectsList.cells.element(boundBy: index)
        project.press(forDuration: 1.0)
        
        let duplicateButton = app.menuItems["Duplicate"]
        if duplicateButton.waitForExistence(timeout: 2) {
            duplicateButton.tap()
        }
    }
    
    func renameProject(at index: Int, newName: String) {
        let project = projectsList.cells.element(boundBy: index)
        project.press(forDuration: 1.0)
        
        let renameButton = app.menuItems["Rename"]
        if renameButton.waitForExistence(timeout: 2) {
            renameButton.tap()
            
            let nameField = app.textFields["rename.field"]
            if nameField.waitForExistence(timeout: 2) {
                nameField.clearAndType(newName)
                
                let saveButton = app.buttons["Save"]
                saveButton.tap()
            }
        }
    }
}