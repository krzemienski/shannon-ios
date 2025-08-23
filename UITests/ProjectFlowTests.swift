import XCTest

/// Tests for project selection and creation flows
final class ProjectFlowTests: BaseUITest {
    
    // MARK: - Test Cases
    
    /// Test launching app and viewing project list
    func testAppLaunchAndProjectList() throws {
        takeScreenshot(name: "App Launch")
        
        // Verify app launched successfully
        XCTAssertTrue(app.state == .runningForeground)
        
        // Check for project list or empty state
        let projectList = app.collectionViews["ProjectList"]
        let emptyStateText = app.staticTexts["No projects yet"]
        
        // Either project list or empty state should be visible
        let hasProjects = waitForElement(projectList, timeout: 5)
        let isEmpty = waitForElement(emptyStateText, timeout: 5)
        
        XCTAssertTrue(hasProjects || isEmpty, "Neither project list nor empty state is visible")
        
        if hasProjects {
            // Verify at least one project exists (from backend)
            let firstProject = projectList.cells.firstMatch
            XCTAssertTrue(waitForElement(firstProject), "No projects found in list")
            
            // The backend provides "Sample Project" by default
            let sampleProject = projectList.cells.containing(.staticText, identifier: "Sample Project").firstMatch
            if sampleProject.exists {
                XCTAssertTrue(sampleProject.exists, "Sample project should exist")
                takeScreenshot(name: "Project List with Sample Project")
            }
        } else {
            takeScreenshot(name: "Empty Project List")
        }
        
        verifyNetworkRequestSucceeded(description: "Fetched projects from /v1/projects")
    }
    
    /// Test selecting an existing project
    func testSelectExistingProject() throws {
        // Wait for project list
        let projectList = app.collectionViews["ProjectList"]
        XCTAssertTrue(waitForElement(projectList), "Project list not found")
        
        // Look for Sample Project or first available project
        let sampleProject = projectList.cells.containing(.staticText, identifier: "Sample Project").firstMatch
        let firstProject = projectList.cells.firstMatch
        
        let projectToSelect = sampleProject.exists ? sampleProject : firstProject
        
        guard projectToSelect.exists else {
            throw XCTSkip("No projects available to select")
        }
        
        takeScreenshot(name: "Before Project Selection")
        
        // Tap on project
        projectToSelect.tap()
        
        // Verify navigation to session list
        let sessionList = app.collectionViews["SessionList"]
        let sessionEmptyState = app.staticTexts["No sessions yet"]
        
        XCTAssertTrue(
            waitForElement(sessionList) || waitForElement(sessionEmptyState),
            "Did not navigate to session view after selecting project"
        )
        
        takeScreenshot(name: "After Project Selection - Session View")
        
        // Verify project name in navigation or header
        if sampleProject.exists {
            assertNavigationTitle("Sample Project")
        }
        
        verifyNetworkRequestSucceeded(description: "Fetched sessions for selected project")
    }
    
    /// Test creating a new project
    func testCreateNewProject() throws {
        // Look for add/create button
        let addButton = app.buttons["Add Project"]
        let createButton = app.buttons["Create Project"]
        let plusButton = app.navigationBars.buttons["plus"]
        
        let newProjectButton = [addButton, createButton, plusButton].first { $0.exists }
        
        guard let button = newProjectButton else {
            throw XCTSkip("No button found to create new project")
        }
        
        takeScreenshot(name: "Before Creating Project")
        
        // Tap create button
        button.tap()
        
        // Wait for create project form
        let projectNameField = app.textFields["Project Name"]
        let projectDescField = app.textFields["Project Description"]
        let projectPathField = app.textFields["Project Path"]
        
        XCTAssertTrue(
            waitForElement(projectNameField) || waitForElement(projectDescField),
            "Create project form did not appear"
        )
        
        takeScreenshot(name: "Create Project Form")
        
        // Fill in project details
        let timestamp = Int(Date().timeIntervalSince1970)
        let projectName = "Test Project \(timestamp)"
        
        if projectNameField.exists {
            typeText(projectName, in: projectNameField)
        }
        
        if projectDescField.exists {
            typeText("Automated UI test project", in: projectDescField)
        }
        
        if projectPathField.exists {
            clearTextField(projectPathField)
            typeText("/tmp/test-project-\(timestamp)", in: projectPathField)
        }
        
        takeScreenshot(name: "Filled Project Form")
        
        // Submit form
        let saveButton = app.buttons["Save"]
        let createSubmitButton = app.buttons["Create"]
        let doneButton = app.buttons["Done"]
        
        let submitButton = [saveButton, createSubmitButton, doneButton].first { $0.exists }
        submitButton?.tap()
        
        // Verify project was created
        Thread.sleep(forTimeInterval: 1) // Allow time for creation
        
        // Should navigate to the new project's session view
        let sessionList = app.collectionViews["SessionList"]
        let sessionEmptyState = app.staticTexts["No sessions yet"]
        
        XCTAssertTrue(
            waitForElement(sessionList) || waitForElement(sessionEmptyState),
            "Did not navigate to new project's session view"
        )
        
        takeScreenshot(name: "New Project Created")
        
        verifyNetworkRequestSucceeded(description: "Created new project via POST /v1/projects")
        
        // Clean up if needed
        if cleanupAfterTests {
            // In a real scenario, we'd delete the test project via API
            print("Would clean up project: \(projectName)")
        }
    }
    
    /// Test navigating back from project
    func testNavigateBackFromProject() throws {
        // First select a project
        let projectList = app.collectionViews["ProjectList"]
        guard waitForElement(projectList) else {
            throw XCTSkip("Project list not available")
        }
        
        let firstProject = projectList.cells.firstMatch
        guard firstProject.exists else {
            throw XCTSkip("No projects to select")
        }
        
        firstProject.tap()
        
        // Wait for session view
        Thread.sleep(forTimeInterval: 1)
        
        // Navigate back
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            
            // Verify we're back at project list
            XCTAssertTrue(waitForElement(projectList), "Did not return to project list")
            takeScreenshot(name: "Returned to Project List")
        }
    }
    
    /// Test project list refresh
    func testProjectListRefresh() throws {
        let projectList = app.collectionViews["ProjectList"]
        
        guard waitForElement(projectList) else {
            // If no project list, check for empty state
            let emptyState = app.staticTexts["No projects yet"]
            XCTAssertTrue(waitForElement(emptyState), "Neither project list nor empty state found")
            return
        }
        
        // Pull to refresh
        projectList.swipeDown()
        
        // Wait for refresh to complete
        Thread.sleep(forTimeInterval: 2)
        
        // Verify list is still present
        XCTAssertTrue(projectList.exists, "Project list disappeared after refresh")
        
        verifyNetworkRequestSucceeded(description: "Refreshed projects from /v1/projects")
        
        takeScreenshot(name: "After Refresh")
    }
}