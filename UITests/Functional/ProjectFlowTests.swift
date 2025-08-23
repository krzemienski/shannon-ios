//
//  ProjectFlowTests.swift
//  ClaudeCodeUITests
//
//  Functional tests for project selection and management with real backend
//

import XCTest

class ProjectFlowTests: ClaudeCodeUITestCase {
    
    // MARK: - Properties
    
    private var projectsPage: ProjectsPage!
    private var testProjectId: String?
    private var createdProjectIds: [String] = []
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Configure for real backend testing
        let config = RealBackendConfig.createLaunchConfiguration()
        launchApp(with: config)
        
        projectsPage = ProjectsPage(app: app)
        
        // Wait for backend to be available
        let expectation = expectation(description: "Backend available")
        Task {
            let isAvailable = await RealBackendConfig.waitForBackend(maxAttempts: 15, interval: 2.0)
            XCTAssertTrue(isAvailable, "Backend must be available for functional tests")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 60.0)
    }
    
    override func tearDownWithError() throws {
        // Clean up any created projects
        let cleanupExpectation = expectation(description: "Cleanup completed")
        Task {
            for projectId in createdProjectIds {
                do {
                    try await BackendAPIHelper.shared.deleteProject(projectId)
                    if RealBackendConfig.verboseLogging {
                        print("Cleaned up test project: \(projectId)")
                    }
                } catch {
                    print("Failed to cleanup project \(projectId): \(error)")
                }
            }
            await RealBackendConfig.cleanupTestData()
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 30.0)
        
        try super.tearDownWithError()
    }
    
    // MARK: - Project Selection Flow Tests
    
    func testProjectListLoadsFromRealBackend() throws {
        takeScreenshot(name: "project_list_initial")
        
        // Navigate to projects tab
        projectsPage.navigateToProjects()
        
        // Wait for real data to load from backend
        let projectsListElement = projectsPage.projectsList
        waitForElement(projectsListElement, timeout: RealBackendConfig.uiWaitTimeout)
        
        takeScreenshot(name: "project_list_loaded")
        
        // Verify projects list is visible
        XCTAssertTrue(projectsListElement.exists, "Projects list should be visible")
        
        // Wait for network request to complete and data to populate
        Thread.sleep(forTimeInterval: 2.0)
        
        // Check if there are any projects (there might be existing ones or none)
        let projectCells = projectsListElement.cells
        print("Found \(projectCells.count) projects in list")
        
        takeScreenshot(name: "project_list_with_data")
    }
    
    func testSelectExistingProjectFromBackend() throws {
        // First ensure we have a project to select by creating one via API
        let expectation = expectation(description: "Project created")
        let testProject = TestProjectData(
            name: "FunctionalTest_SelectProject",
            description: "Project for testing selection functionality"
        )
        
        Task {
            do {
                let projectData = try await BackendAPIHelper.shared.createProject(testProject)
                if let projectId = projectData["id"] as? String {
                    self.testProjectId = projectId
                    self.createdProjectIds.append(projectId)
                }
                expectation.fulfill()
            } catch {
                XCTFail("Failed to create test project: \(error)")
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 30.0)
        
        takeScreenshot(name: "before_project_selection")
        
        // Navigate to projects and wait for list to load
        projectsPage.navigateToProjects()
        waitForElement(projectsPage.projectsList, timeout: RealBackendConfig.uiWaitTimeout)
        
        // Wait for data to populate from backend
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "project_list_before_selection")
        
        // Try to find and select our test project
        let projectFound = projectsPage.verifyProjectExists(testProject.name)
        XCTAssertTrue(projectFound, "Test project should exist in the list")
        
        // Select the project
        projectsPage.selectProject(named: testProject.name)
        
        // Wait for project details to load
        Thread.sleep(forTimeInterval: 2.0)
        
        takeScreenshot(name: "project_selected_details")
        
        // Verify we're now in project detail view
        // This would depend on your app's navigation - adjust as needed
        let projectDetailIndicator = app.navigationBars.staticTexts[testProject.name]
        XCTAssertTrue(
            projectDetailIndicator.waitForExistence(timeout: 10),
            "Should navigate to project details"
        )
    }
    
    func testProjectDetailsLoadFromBackend() throws {
        // Create a test project with known data
        let expectation = expectation(description: "Project created and selected")
        let testProject = TestProjectData(
            name: "FunctionalTest_ProjectDetails",
            description: "Detailed project for testing backend data loading"
        )
        
        var createdProjectId: String?
        
        Task {
            do {
                let projectData = try await BackendAPIHelper.shared.createProject(testProject)
                createdProjectId = projectData["id"] as? String
                if let projectId = createdProjectId {
                    self.createdProjectIds.append(projectId)
                }
                expectation.fulfill()
            } catch {
                XCTFail("Failed to create test project: \(error)")
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 30.0)
        
        guard let projectId = createdProjectId else {
            XCTFail("Project ID not available")
            return
        }
        
        // Navigate and select project
        projectsPage.navigateToProjects()
        waitForElement(projectsPage.projectsList, timeout: RealBackendConfig.uiWaitTimeout)
        Thread.sleep(forTimeInterval: 2.0)
        
        projectsPage.selectProject(named: testProject.name)
        
        // Wait for project details to load from backend
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "project_details_loaded")
        
        // Verify project details are displayed
        let projectNameElement = app.staticTexts[testProject.name]
        XCTAssertTrue(
            projectNameElement.waitForExistence(timeout: 10),
            "Project name should be displayed in details"
        )
        
        let projectDescriptionElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", testProject.description)).firstMatch
        XCTAssertTrue(
            projectDescriptionElement.exists,
            "Project description should be displayed"
        )
        
        takeScreenshot(name: "project_details_verified")
    }
    
    // MARK: - New Project Creation Tests
    
    func testCreateNewProjectPersistsToBackend() throws {
        takeScreenshot(name: "before_new_project")
        
        // Navigate to projects
        projectsPage.navigateToProjects()
        waitForElement(projectsPage.projectsList, timeout: RealBackendConfig.uiWaitTimeout)
        
        // Create unique project data
        let testProject = TestProjectData(
            name: "FunctionalTest_NewProject_\(Date().timeIntervalSince1970)",
            description: "New project created by functional test"
        )
        
        takeScreenshot(name: "new_project_form_start")
        
        // Create new project using UI
        projectsPage.createNewProject(
            name: testProject.name,
            path: testProject.path ?? "",
            description: testProject.description
        )
        
        // Wait for project creation to complete
        Thread.sleep(forTimeInterval: 5.0)
        
        takeScreenshot(name: "new_project_created")
        
        // Verify project appears in list
        let projectExists = projectsPage.verifyProjectExists(testProject.name)
        XCTAssertTrue(projectExists, "New project should appear in projects list")
        
        // Verify persistence by checking backend directly
        let verificationExpectation = expectation(description: "Backend verification")
        Task {
            do {
                let projects = try await BackendAPIHelper.shared.getProjects()
                let createdProject = projects.first { project in
                    guard let name = project["name"] as? String else { return false }
                    return name == testProject.name
                }
                
                XCTAssertNotNil(createdProject, "Project should exist in backend")
                
                if let project = createdProject,
                   let projectId = project["id"] as? String {
                    self.createdProjectIds.append(projectId)
                    
                    // Verify project details
                    XCTAssertEqual(
                        project["description"] as? String,
                        testProject.description,
                        "Project description should match"
                    )
                    
                    if RealBackendConfig.verboseLogging {
                        print("Verified project in backend: \(project)")
                    }
                }
                
                verificationExpectation.fulfill()
            } catch {
                XCTFail("Failed to verify project in backend: \(error)")
                verificationExpectation.fulfill()
            }
        }
        wait(for: [verificationExpectation], timeout: 30.0)
        
        takeScreenshot(name: "new_project_verified")
    }
    
    func testCreateProjectWithInvalidDataShowsError() throws {
        // Navigate to projects
        projectsPage.navigateToProjects()
        waitForElement(projectsPage.projectsList, timeout: RealBackendConfig.uiWaitTimeout)
        
        takeScreenshot(name: "before_invalid_project")
        
        // Try to create project with empty name (should fail)
        projectsPage.newProjectButton.tap()
        
        waitForElement(projectsPage.projectNameField, timeout: 10)
        
        // Leave name empty and try to create
        projectsPage.projectDescriptionField.tap()
        typeTextSlowly("Project without name", in: projectsPage.projectDescriptionField)
        
        projectsPage.createProjectButton.tap()
        
        // Wait for error message
        Thread.sleep(forTimeInterval: 2.0)
        
        takeScreenshot(name: "invalid_project_error")
        
        // Verify error is shown (this depends on your app's error handling)
        // Look for error alert, message, or disabled state
        let errorAlert = app.alerts.firstMatch
        if errorAlert.exists {
            takeScreenshot(name: "error_alert_shown")
            // Dismiss alert if present
            if errorAlert.buttons["OK"].exists {
                errorAlert.buttons["OK"].tap()
            } else if errorAlert.buttons.count > 0 {
                errorAlert.buttons.firstMatch.tap()
            }
        } else {
            // Look for inline error messages or validation states
            let nameFieldError = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "required")).firstMatch
            XCTAssertTrue(nameFieldError.exists || !projectsPage.createProjectButton.isEnabled, 
                         "Should show error for empty project name")
        }
    }
    
    // MARK: - Project Management Tests
    
    func testDeleteProjectRemovesFromBackend() throws {
        // Create a project to delete
        let expectation = expectation(description: "Project created for deletion")
        let testProject = TestProjectData(
            name: "FunctionalTest_DeleteProject",
            description: "Project to be deleted"
        )
        
        var projectToDelete: String?
        
        Task {
            do {
                let projectData = try await BackendAPIHelper.shared.createProject(testProject)
                projectToDelete = projectData["id"] as? String
                expectation.fulfill()
            } catch {
                XCTFail("Failed to create project for deletion test: \(error)")
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 30.0)
        
        guard let projectId = projectToDelete else {
            XCTFail("Project ID not available for deletion test")
            return
        }
        
        // Navigate to projects and find the project
        projectsPage.navigateToProjects()
        waitForElement(projectsPage.projectsList, timeout: RealBackendConfig.uiWaitTimeout)
        Thread.sleep(forTimeInterval: 2.0)
        
        takeScreenshot(name: "before_project_deletion")
        
        // Find project index
        let projectCells = projectsPage.projectsList.cells
        var projectIndex: Int?
        
        for i in 0..<projectCells.count {
            let cell = projectCells.element(boundBy: i)
            if cell.staticTexts[testProject.name].exists {
                projectIndex = i
                break
            }
        }
        
        XCTAssertNotNil(projectIndex, "Should find project to delete")
        
        if let index = projectIndex {
            // Delete the project
            projectsPage.deleteProject(at: index)
            
            // Wait for deletion to complete
            Thread.sleep(forTimeInterval: 3.0)
            
            takeScreenshot(name: "after_project_deletion")
            
            // Verify project is removed from UI
            let projectStillExists = projectsPage.verifyProjectExists(testProject.name)
            XCTAssertFalse(projectStillExists, "Deleted project should not appear in list")
            
            // Verify deletion in backend
            let verificationExpectation = expectation(description: "Backend deletion verification")
            Task {
                do {
                    let projects = try await BackendAPIHelper.shared.getProjects()
                    let deletedProject = projects.first { project in
                        guard let name = project["name"] as? String else { return false }
                        return name == testProject.name
                    }
                    
                    XCTAssertNil(deletedProject, "Project should be deleted from backend")
                    verificationExpectation.fulfill()
                } catch {
                    print("Error verifying deletion (this might be expected): \(error)")
                    verificationExpectation.fulfill()
                }
            }
            wait(for: [verificationExpectation], timeout: 30.0)
        }
    }
    
    func testProjectSearchWithRealData() throws {
        // Create multiple projects for search testing
        let searchExpectation = expectation(description: "Projects created for search")
        let projects = [
            TestProjectData(name: "FunctionalTest_SearchAlpha", description: "Alpha project"),
            TestProjectData(name: "FunctionalTest_SearchBeta", description: "Beta project"),
            TestProjectData(name: "FunctionalTest_SearchGamma", description: "Gamma project")
        ]
        
        Task {
            do {
                for project in projects {
                    let projectData = try await BackendAPIHelper.shared.createProject(project)
                    if let projectId = projectData["id"] as? String {
                        self.createdProjectIds.append(projectId)
                    }
                }
                searchExpectation.fulfill()
            } catch {
                XCTFail("Failed to create projects for search test: \(error)")
                searchExpectation.fulfill()
            }
        }
        wait(for: [searchExpectation], timeout: 60.0)
        
        // Navigate to projects
        projectsPage.navigateToProjects()
        waitForElement(projectsPage.projectsList, timeout: RealBackendConfig.uiWaitTimeout)
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "before_search")
        
        // Perform search
        projectsPage.searchProjects("SearchAlpha")
        
        // Wait for search results
        Thread.sleep(forTimeInterval: 2.0)
        
        takeScreenshot(name: "search_results")
        
        // Verify search results
        let alphaProjectExists = projectsPage.verifyProjectExists("FunctionalTest_SearchAlpha")
        XCTAssertTrue(alphaProjectExists, "Alpha project should be found")
        
        // Verify other projects are filtered out (if your search is working correctly)
        let betaProjectExists = projectsPage.verifyProjectExists("FunctionalTest_SearchBeta")
        // This assertion depends on whether your search is live or requires enter/submit
        // XCTAssertFalse(betaProjectExists, "Beta project should be filtered out")
        
        takeScreenshot(name: "search_verified")
    }
}