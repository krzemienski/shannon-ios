import XCTest

/// Tests for project management CRUD operations with real backend
class ProjectManagementTests: BaseUITest {
    
    // MARK: - Setup
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Login before each test
        performLogin()
        
        // Navigate to Projects tab
        navigateToTab("Projects")
    }
    
    // MARK: - Project CRUD Tests
    
    /// Test creating a new project
    func testCreateProject() throws {
        // Tap new project button
        let newProjectButton = app.navigationBars["Projects"].buttons["New Project"]
        if !newProjectButton.exists {
            // Alternative: Look for plus button
            let plusButton = app.navigationBars["Projects"].buttons["plus"]
            waitAndTap(plusButton)
        } else {
            waitAndTap(newProjectButton)
        }
        
        captureScreenshot(name: "01_new_project_form")
        
        // Fill in project details
        let projectNameField = app.textFields["Project Name"]
        let projectName = "Test Project \(Date().timeIntervalSince1970)"
        typeText(projectName, in: projectNameField)
        
        let descriptionField = app.textViews["Description"]
        if descriptionField.exists {
            typeText("This is a test project created via UI tests", in: descriptionField)
        }
        
        // Select project type
        let projectTypeButton = app.buttons["Project Type"]
        if projectTypeButton.exists {
            waitAndTap(projectTypeButton)
            
            // Select iOS project type
            let iosOption = app.cells.staticTexts["iOS"]
            if iosOption.exists {
                iosOption.tap()
            }
        }
        
        // Set repository URL
        let repoField = app.textFields["Repository URL"]
        if repoField.exists {
            typeText("https://github.com/test/project.git", in: repoField)
        }
        
        captureScreenshot(name: "02_project_details_filled")
        
        // Create project
        let createButton = app.buttons["Create"]
        waitAndTap(createButton)
        
        // Wait for API response
        waitForAPIResponse(timeout: apiTimeout)
        
        // Verify project was created and we're on project detail view
        XCTAssertTrue(waitForElement(app.navigationBars[projectName], timeout: uiTimeout),
                     "Should navigate to project detail view")
        
        // Verify project appears in list
        app.navigationBars.buttons.firstMatch.tap() // Go back to list
        XCTAssertTrue(app.cells.staticTexts[projectName].exists,
                     "Created project should appear in projects list")
        
        captureScreenshot(name: "03_project_created")
    }
    
    /// Test reading/viewing project details
    func testViewProjectDetails() throws {
        // First create a project
        let projectName = createTestProject(name: "Detail Test Project")
        
        // Tap on the project to view details
        waitAndTap(app.cells.staticTexts[projectName])
        
        // Verify we're on project detail view
        XCTAssertTrue(waitForElement(app.navigationBars[projectName], timeout: uiTimeout),
                     "Should show project name in navigation bar")
        
        // Verify project information is displayed
        XCTAssertTrue(app.staticTexts["Description"].exists,
                     "Should show description label")
        
        // Check for project sections
        let sections = ["Files", "Environment", "SSH Config", "Settings"]
        for section in sections {
            XCTAssertTrue(app.buttons[section].exists || app.staticTexts[section].exists,
                         "Should have \(section) section")
        }
        
        captureScreenshot(name: "project_details_view")
        
        // Test navigation to different sections
        if app.buttons["Files"].exists {
            waitAndTap(app.buttons["Files"])
            XCTAssertTrue(waitForElement(app.navigationBars["Files"], timeout: uiTimeout),
                         "Should navigate to Files view")
            app.navigationBars.buttons.firstMatch.tap() // Go back
        }
        
        if app.buttons["Environment"].exists {
            waitAndTap(app.buttons["Environment"])
            XCTAssertTrue(waitForElement(app.navigationBars["Environment Variables"], timeout: uiTimeout),
                         "Should navigate to Environment Variables view")
            app.navigationBars.buttons.firstMatch.tap() // Go back
        }
    }
    
    /// Test updating project information
    func testUpdateProject() throws {
        // Create a project first
        let projectName = createTestProject(name: "Update Test Project")
        
        // Open project details
        waitAndTap(app.cells.staticTexts[projectName])
        
        // Navigate to settings
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            waitAndTap(settingsButton)
        } else {
            // Alternative: Look for edit button
            let editButton = app.navigationBars.buttons["Edit"]
            if editButton.exists {
                waitAndTap(editButton)
            }
        }
        
        captureScreenshot(name: "01_project_edit_mode")
        
        // Update project name
        let nameField = app.textFields.containing(.label, "Project Name").firstMatch
        if nameField.exists {
            nameField.clearText()
            let updatedName = projectName + " Updated"
            typeText(updatedName, in: nameField)
        }
        
        // Update description
        let descriptionField = app.textViews.containing(.label, "Description").firstMatch
        if descriptionField.exists {
            descriptionField.clearText()
            typeText("Updated description via UI test", in: descriptionField)
        }
        
        // Save changes
        let saveButton = app.buttons["Save"]
        waitAndTap(saveButton)
        
        // Wait for API response
        waitForAPIResponse(timeout: apiTimeout)
        
        // Verify changes were saved
        app.navigationBars.buttons.firstMatch.tap() // Go back
        
        XCTAssertTrue(app.cells.staticTexts[projectName + " Updated"].exists,
                     "Updated project name should be visible in list")
        
        captureScreenshot(name: "02_project_updated")
    }
    
    /// Test deleting a project
    func testDeleteProject() throws {
        // Create a project to delete
        let projectName = createTestProject(name: "Delete Test Project")
        
        // Method 1: Swipe to delete from list
        let projectCell = app.cells.containing(.staticText, identifier: projectName).firstMatch
        projectCell.swipeLeft()
        
        let deleteButton = app.buttons["Delete"]
        if waitForElement(deleteButton, timeout: uiTimeout) {
            deleteButton.tap()
            
            // Confirm deletion
            let confirmButton = app.alerts.buttons["Delete"]
            if confirmButton.exists {
                confirmButton.tap()
            }
            
            // Wait for API response
            waitForAPIResponse(timeout: apiTimeout)
            
            // Verify project is deleted
            XCTAssertFalse(app.cells.staticTexts[projectName].exists,
                          "Deleted project should not appear in list")
            
            captureScreenshot(name: "project_deleted")
            return
        }
        
        // Method 2: Delete from project details
        waitAndTap(app.cells.staticTexts[projectName])
        
        // Look for delete option in settings or menu
        if app.buttons["Settings"].exists {
            waitAndTap(app.buttons["Settings"])
            
            // Scroll to find delete button
            app.scrollViews.firstMatch.swipeUp()
            
            let deleteProjectButton = app.buttons["Delete Project"]
            if deleteProjectButton.exists {
                waitAndTap(deleteProjectButton)
                
                // Confirm deletion
                let confirmButton = app.alerts.buttons["Delete"]
                if confirmButton.exists {
                    confirmButton.tap()
                }
                
                // Wait for API response and navigation
                waitForAPIResponse(timeout: apiTimeout)
                
                // Should return to projects list
                XCTAssertTrue(waitForElement(app.navigationBars["Projects"], timeout: uiTimeout),
                             "Should return to projects list after deletion")
                
                // Verify project is deleted
                XCTAssertFalse(app.cells.staticTexts[projectName].exists,
                              "Deleted project should not appear in list")
            }
        }
    }
    
    /// Test adding environment variables to project
    func testAddEnvironmentVariables() throws {
        let projectName = createTestProject(name: "Env Vars Test Project")
        
        // Open project details
        waitAndTap(app.cells.staticTexts[projectName])
        
        // Navigate to Environment Variables
        waitAndTap(app.buttons["Environment"])
        
        captureScreenshot(name: "01_environment_variables_view")
        
        // Add new environment variable
        let addButton = app.buttons["Add Variable"]
        if !addButton.exists {
            // Alternative: Look for plus button
            let plusButton = app.navigationBars.buttons["plus"]
            if plusButton.exists {
                waitAndTap(plusButton)
            }
        } else {
            waitAndTap(addButton)
        }
        
        // Fill in variable details
        let keyField = app.textFields["Key"]
        typeText("API_KEY", in: keyField)
        
        let valueField = app.textFields["Value"]
        typeText("test-api-key-value", in: valueField)
        
        // Save variable
        let saveButton = app.buttons["Save"]
        if saveButton.exists {
            waitAndTap(saveButton)
        } else {
            // Alternative: Done button
            let doneButton = app.buttons["Done"]
            if doneButton.exists {
                waitAndTap(doneButton)
            }
        }
        
        // Verify variable was added
        XCTAssertTrue(app.cells.staticTexts["API_KEY"].exists,
                     "Environment variable should be added")
        
        captureScreenshot(name: "02_environment_variable_added")
        
        // Test editing environment variable
        let varCell = app.cells.containing(.staticText, identifier: "API_KEY").firstMatch
        waitAndTap(varCell)
        
        let editValueField = app.textFields.containing(.label, "Value").firstMatch
        if editValueField.exists {
            editValueField.clearText()
            typeText("updated-api-key-value", in: editValueField)
            
            waitAndTap(app.buttons["Save"])
        }
        
        // Test deleting environment variable
        varCell.swipeLeft()
        if app.buttons["Delete"].exists {
            app.buttons["Delete"].tap()
            
            // Confirm if needed
            if app.alerts.buttons["Delete"].exists {
                app.alerts.buttons["Delete"].tap()
            }
            
            XCTAssertFalse(app.cells.staticTexts["API_KEY"].exists,
                          "Deleted environment variable should not exist")
        }
    }
    
    /// Test SSH configuration for project
    func testSSHConfiguration() throws {
        let projectName = createTestProject(name: "SSH Config Test Project")
        
        // Open project details
        waitAndTap(app.cells.staticTexts[projectName])
        
        // Navigate to SSH Config
        waitAndTap(app.buttons["SSH Config"])
        
        captureScreenshot(name: "01_ssh_config_view")
        
        // Configure SSH settings
        let hostField = app.textFields["Host"]
        if hostField.exists {
            typeText("test.server.com", in: hostField)
        }
        
        let portField = app.textFields["Port"]
        if portField.exists {
            typeText("22", in: portField)
        }
        
        let usernameField = app.textFields["Username"]
        if usernameField.exists {
            typeText("testuser", in: usernameField)
        }
        
        // Select authentication type
        let authTypeSegment = app.segmentedControls.firstMatch
        if authTypeSegment.exists {
            authTypeSegment.buttons["Password"].tap()
            
            let passwordField = app.secureTextFields["Password"]
            if passwordField.exists {
                typeText("testpassword123", in: passwordField)
            }
        }
        
        // Test connection
        let testButton = app.buttons["Test Connection"]
        if testButton.exists {
            waitAndTap(testButton)
            
            // Wait for connection test
            waitForAPIResponse(timeout: apiTimeout)
            
            // Check for success or failure message
            let alert = app.alerts.firstMatch
            if waitForElement(alert, timeout: uiTimeout) {
                captureScreenshot(name: "02_ssh_connection_test_result")
                alert.buttons["OK"].tap()
            }
        }
        
        // Save SSH configuration
        let saveButton = app.buttons["Save"]
        if saveButton.exists {
            waitAndTap(saveButton)
            waitForAPIResponse(timeout: apiTimeout)
        }
        
        captureScreenshot(name: "03_ssh_config_saved")
    }
    
    /// Test project search and filtering
    func testProjectSearchAndFilter() throws {
        // Create multiple projects with different names
        let projectNames = [
            "iOS App Project",
            "Backend API Project",
            "iOS Framework Project",
            "Web Dashboard Project"
        ]
        
        for name in projectNames {
            createTestProject(name: name)
        }
        
        // Test search
        let searchField = app.searchFields.firstMatch
        if waitForElement(searchField, timeout: uiTimeout) {
            searchField.tap()
            searchField.typeText("iOS")
            
            // Verify search results
            Thread.sleep(forTimeInterval: 1.0) // Wait for search
            
            XCTAssertTrue(app.cells.staticTexts["iOS App Project"].exists,
                         "Should show iOS App Project")
            XCTAssertTrue(app.cells.staticTexts["iOS Framework Project"].exists,
                         "Should show iOS Framework Project")
            XCTAssertFalse(app.cells.staticTexts["Backend API Project"].exists,
                          "Should not show Backend API Project")
            XCTAssertFalse(app.cells.staticTexts["Web Dashboard Project"].exists,
                          "Should not show Web Dashboard Project")
            
            captureScreenshot(name: "project_search_results")
            
            // Clear search
            searchField.buttons["Clear text"].tap()
        }
        
        // Test filtering (if available)
        let filterButton = app.buttons["Filter"]
        if filterButton.exists {
            waitAndTap(filterButton)
            
            // Select filter option
            let iosFilter = app.cells.staticTexts["iOS Projects"]
            if iosFilter.exists {
                iosFilter.tap()
                waitAndTap(app.buttons["Apply"])
                
                // Verify filtered results
                XCTAssertTrue(app.cells.staticTexts["iOS App Project"].exists)
                XCTAssertTrue(app.cells.staticTexts["iOS Framework Project"].exists)
                XCTAssertFalse(app.cells.staticTexts["Backend API Project"].exists)
            }
        }
    }
    
    /// Test project duplication
    func testDuplicateProject() throws {
        let originalName = createTestProject(name: "Original Project")
        
        // Long press on project for options
        let projectCell = app.cells.containing(.staticText, identifier: originalName).firstMatch
        projectCell.press(forDuration: 1.0)
        
        // Look for duplicate option
        let duplicateButton = app.buttons["Duplicate"]
        if waitForElement(duplicateButton, timeout: uiTimeout) {
            duplicateButton.tap()
            
            // Modify duplicated project name
            let nameField = app.textFields["Project Name"]
            if nameField.exists {
                nameField.clearText()
                typeText(originalName + " Copy", in: nameField)
            }
            
            // Create duplicate
            waitAndTap(app.buttons["Create"])
            waitForAPIResponse(timeout: apiTimeout)
            
            // Verify both projects exist
            XCTAssertTrue(app.cells.staticTexts[originalName].exists,
                         "Original project should still exist")
            XCTAssertTrue(app.cells.staticTexts[originalName + " Copy"].exists,
                         "Duplicated project should exist")
            
            captureScreenshot(name: "project_duplicated")
        }
    }
    
    /// Test project import/export
    func testProjectImportExport() throws {
        let projectName = createTestProject(name: "Export Test Project")
        
        // Open project details
        waitAndTap(app.cells.staticTexts[projectName])
        
        // Navigate to settings
        waitAndTap(app.buttons["Settings"])
        
        // Test export
        let exportButton = app.buttons["Export Project"]
        if exportButton.exists {
            waitAndTap(exportButton)
            
            // Select export format
            let jsonOption = app.cells.staticTexts["JSON"]
            if jsonOption.exists {
                jsonOption.tap()
            }
            
            // Confirm export
            waitAndTap(app.buttons["Export"])
            waitForAPIResponse(timeout: apiTimeout)
            
            // Verify export success
            let successAlert = app.alerts.firstMatch
            if waitForElement(successAlert, timeout: uiTimeout) {
                XCTAssertTrue(successAlert.label.contains("exported") || 
                            successAlert.label.contains("success"),
                            "Should show export success message")
                successAlert.buttons["OK"].tap()
            }
            
            captureScreenshot(name: "project_exported")
        }
    }
    
    // MARK: - Performance Tests
    
    /// Test project list loading performance with many projects
    func testProjectListPerformance() throws {
        // Create multiple projects
        for i in 1...20 {
            createTestProject(name: "Performance Test Project \(i)")
        }
        
        measureAPIPerformance(operation: "Project List Loading") {
            // Navigate away and back
            navigateToTab("Chat")
            navigateToTab("Projects")
            
            // Verify projects are loaded
            XCTAssertGreaterThanOrEqual(app.cells.count, 20,
                                       "Should load all created projects")
        }
    }
    
    /// Test project creation performance
    func testProjectCreationPerformance() throws {
        measureAPIPerformance(operation: "Project Creation") {
            let projectName = "Performance Test \(Date().timeIntervalSince1970)"
            _ = createTestProject(name: projectName)
        }
    }
}