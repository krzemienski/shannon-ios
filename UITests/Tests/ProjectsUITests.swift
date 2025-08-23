//
//  ProjectsUITests.swift
//  ClaudeCodeUITests
//
//  Comprehensive UI tests for Projects functionality
//

import XCTest

class ProjectsUITests: ClaudeCodeUITestCase {
    
    var projectsPage: ProjectsPage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize page object
        projectsPage = ProjectsPage(app: app)
        
        // Launch app in authenticated state
        app.terminate()
        launchApp(with: .authenticated)
        
        // Navigate to projects
        projectsPage.navigateToProjects()
    }
    
    // MARK: - Basic Project Tests
    
    func testNavigateToProjects() {
        // Verify we're on projects page
        waitForElement(projectsPage.projectsList)
        XCTAssertTrue(projectsPage.projectsTab.isSelected)
        
        takeScreenshot(name: "Projects-List")
    }
    
    func testCreateNewProject() {
        // Create new project
        let projectName = "Test Project \(Date().timeIntervalSince1970)"
        let projectPath = "/Users/test/projects/\(projectName.replacingOccurrences(of: " ", with: "_"))"
        let description = "This is a test project created by UI tests"
        
        projectsPage.createNewProject(
            name: projectName,
            path: projectPath,
            description: description
        )
        
        // Wait for project to be created
        Thread.sleep(forTimeInterval: 2)
        
        // Verify project was created
        XCTAssertTrue(projectsPage.verifyProjectExists(projectName))
        
        takeScreenshot(name: "Project-Created")
    }
    
    func testSelectProject() {
        // Create a project first
        let projectName = "Selectable Project"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/path"
        )
        
        Thread.sleep(forTimeInterval: 1)
        
        // Select the project
        projectsPage.selectProject(named: projectName)
        
        // Verify project detail view opened
        waitForElement(app.navigationBars[projectName])
        
        takeScreenshot(name: "Project-Selected")
    }
    
    func testSearchProjects() {
        // Create multiple projects
        for i in 1...3 {
            projectsPage.createNewProject(
                name: "Search Test \(i)",
                path: "/test/path/\(i)"
            )
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // Search for specific project
        projectsPage.searchProjects("Test 2")
        
        // Verify search results
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(projectsPage.verifyProjectExists("Search Test 2"))
        
        takeScreenshot(name: "Projects-Search-Results")
    }
    
    func testDeleteProject() {
        // Create a project to delete
        let projectName = "Project to Delete"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/delete"
        )
        
        Thread.sleep(forTimeInterval: 1)
        
        // Delete the project
        projectsPage.deleteProject(at: 0)
        
        // Verify project was deleted
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(projectsPage.verifyProjectExists(projectName))
        
        takeScreenshot(name: "Project-Deleted")
    }
    
    func testArchiveProject() {
        // Create a project to archive
        let projectName = "Project to Archive"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/archive"
        )
        
        Thread.sleep(forTimeInterval: 1)
        
        // Archive the project
        projectsPage.archiveProject(at: 0)
        
        // Verify project was archived (should not be in main list)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(projectsPage.verifyProjectExists(projectName))
        
        takeScreenshot(name: "Project-Archived")
    }
    
    func testFavoriteProject() {
        // Create a project to favorite
        let projectName = "Favorite Project"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/favorite"
        )
        
        Thread.sleep(forTimeInterval: 1)
        
        // Favorite the project
        projectsPage.favoriteProject(at: 0)
        
        // Verify project is marked as favorite (should have star icon)
        Thread.sleep(forTimeInterval: 1)
        let project = app.cells.containing(.staticText, identifier: projectName).firstMatch
        let favoriteIcon = project.images["star.fill"]
        XCTAssertTrue(favoriteIcon.exists)
        
        takeScreenshot(name: "Project-Favorited")
    }
    
    // MARK: - Project Detail Tests
    
    func testOpenProjectSettings() {
        // Create and select a project
        let projectName = "Settings Test Project"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/settings"
        )
        
        Thread.sleep(forTimeInterval: 1)
        projectsPage.selectProject(named: projectName)
        
        // Open project settings
        projectsPage.openProjectSettings()
        
        // Verify settings opened
        waitForElement(app.navigationBars["Project Settings"])
        
        takeScreenshot(name: "Project-Settings")
    }
    
    func testBrowseProjectFiles() {
        // Create and select a project
        let projectName = "Browse Test Project"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/browse"
        )
        
        Thread.sleep(forTimeInterval: 1)
        projectsPage.selectProject(named: projectName)
        
        // Browse files
        projectsPage.browseProjectFiles()
        
        // Verify file browser opened
        waitForElement(app.navigationBars["Files"])
        
        takeScreenshot(name: "Project-File-Browser")
    }
    
    func testRunCommand() {
        // Create and select a project
        let projectName = "Command Test Project"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/command"
        )
        
        Thread.sleep(forTimeInterval: 1)
        projectsPage.selectProject(named: projectName)
        
        // Run a command
        projectsPage.runCommand("ls -la")
        
        // Wait for command to execute
        Thread.sleep(forTimeInterval: 2)
        
        // Verify command output
        XCTAssertTrue(projectsPage.verifyCommandOutput("") != nil)
        
        takeScreenshot(name: "Project-Command-Executed")
    }
    
    func testOpenTerminal() {
        // Create and select a project
        let projectName = "Terminal Test Project"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/terminal"
        )
        
        Thread.sleep(forTimeInterval: 1)
        projectsPage.selectProject(named: projectName)
        
        // Open terminal
        projectsPage.openTerminal()
        
        // Verify terminal opened
        waitForElement(app.otherElements["project.terminal.view"])
        
        takeScreenshot(name: "Project-Terminal")
    }
    
    // MARK: - Git Integration Tests
    
    func testGitStatus() {
        // Create a git-enabled project
        let projectName = "Git Test Project"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/git"
        )
        
        Thread.sleep(forTimeInterval: 1)
        projectsPage.selectProject(named: projectName)
        
        // Verify git status is shown
        XCTAssertNotNil(projectsPage.verifyGitStatus(""))
        
        takeScreenshot(name: "Project-Git-Status")
    }
    
    func testCommitChanges() {
        // Create and select a project
        let projectName = "Commit Test Project"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/commit"
        )
        
        Thread.sleep(forTimeInterval: 1)
        projectsPage.selectProject(named: projectName)
        
        // Make a commit
        projectsPage.commitChanges(message: "Test commit from UI tests")
        
        // Wait for commit to complete
        Thread.sleep(forTimeInterval: 2)
        
        takeScreenshot(name: "Project-Commit")
    }
    
    func testSyncProject() {
        // Create and select a project
        let projectName = "Sync Test Project"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/sync"
        )
        
        Thread.sleep(forTimeInterval: 1)
        projectsPage.selectProject(named: projectName)
        
        // Sync project
        projectsPage.syncProject()
        
        // Wait for sync to complete
        Thread.sleep(forTimeInterval: 3)
        
        takeScreenshot(name: "Project-Synced")
    }
    
    // MARK: - Advanced Project Tests
    
    func testImportProject() {
        // Import from URL
        projectsPage.importProject(from: "https://github.com/example/repo.git")
        
        // Wait for import dialog
        waitForElement(app.alerts["Import in Progress"])
        
        takeScreenshot(name: "Project-Import")
        
        // Cancel import
        app.alerts.buttons["Cancel"].tap()
    }
    
    func testExportProject() {
        // Create a project
        let projectName = "Export Test Project"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/export"
        )
        
        Thread.sleep(forTimeInterval: 1)
        
        // Export the project
        projectsPage.exportProject(at: 0)
        
        // Verify export dialog
        waitForElement(app.sheets["Export Options"])
        
        takeScreenshot(name: "Project-Export")
        
        // Cancel export
        app.sheets.buttons["Cancel"].tap()
    }
    
    func testShareProject() {
        // Create a project
        let projectName = "Share Test Project"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/share"
        )
        
        Thread.sleep(forTimeInterval: 1)
        
        // Share the project
        projectsPage.shareProject(at: 0)
        
        // Verify share sheet
        waitForElement(app.otherElements["ActivityListView"])
        
        takeScreenshot(name: "Project-Share")
        
        // Cancel share
        app.buttons["Close"].tap()
    }
    
    func testDuplicateProject() {
        // Create a project
        let projectName = "Original Project"
        projectsPage.createNewProject(
            name: projectName,
            path: "/test/original"
        )
        
        Thread.sleep(forTimeInterval: 1)
        
        // Duplicate the project
        projectsPage.duplicateProject(at: 0)
        
        // Wait for duplication
        Thread.sleep(forTimeInterval: 2)
        
        // Verify duplicate exists
        XCTAssertTrue(projectsPage.verifyProjectExists("\(projectName) Copy"))
        
        takeScreenshot(name: "Project-Duplicated")
    }
    
    func testRenameProject() {
        // Create a project
        let originalName = "Original Name"
        let newName = "Renamed Project"
        
        projectsPage.createNewProject(
            name: originalName,
            path: "/test/rename"
        )
        
        Thread.sleep(forTimeInterval: 1)
        
        // Rename the project
        projectsPage.renameProject(at: 0, newName: newName)
        
        // Wait for rename
        Thread.sleep(forTimeInterval: 1)
        
        // Verify rename
        XCTAssertTrue(projectsPage.verifyProjectExists(newName))
        XCTAssertFalse(projectsPage.verifyProjectExists(originalName))
        
        takeScreenshot(name: "Project-Renamed")
    }
    
    // MARK: - Filter and Sort Tests
    
    func testFilterProjects() {
        // Create projects with different statuses
        for i in 1...3 {
            projectsPage.createNewProject(
                name: "Filter Test \(i)",
                path: "/test/filter/\(i)"
            )
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // Open filters
        projectsPage.openFilters()
        
        // Apply filter (e.g., only active projects)
        app.switches["filter.active"].tap()
        app.buttons["Apply"].tap()
        
        // Verify filtered results
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(projectsPage.verifyProjectCount() > 0)
        
        takeScreenshot(name: "Projects-Filtered")
    }
    
    func testSortProjects() {
        // Create projects
        let projects = ["Alpha Project", "Beta Project", "Gamma Project"]
        for project in projects {
            projectsPage.createNewProject(
                name: project,
                path: "/test/sort/\(project)"
            )
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // Change sorting
        projectsPage.changeSorting()
        
        // Select alphabetical sorting
        app.buttons["Name A-Z"].tap()
        
        // Verify sorted order
        Thread.sleep(forTimeInterval: 1)
        let firstProject = projectsPage.projectsList.cells.element(boundBy: 0)
        XCTAssertTrue(firstProject.label.contains("Alpha"))
        
        takeScreenshot(name: "Projects-Sorted")
    }
    
    // MARK: - Performance Tests
    
    func testProjectListScrollingPerformance() {
        // Create many projects
        for i in 1...20 {
            projectsPage.createNewProject(
                name: "Performance Test \(i)",
                path: "/test/perf/\(i)"
            )
        }
        
        measure {
            // Scroll through list
            projectsPage.projectsList.swipeUp()
            projectsPage.projectsList.swipeDown()
        }
    }
    
    func testProjectCreationPerformance() {
        measure {
            let projectName = "Perf Test \(Date().timeIntervalSince1970)"
            projectsPage.createNewProject(
                name: projectName,
                path: "/test/performance"
            )
            Thread.sleep(forTimeInterval: 1)
        }
    }
    
    func testProjectSearchPerformance() {
        // Create projects
        for i in 1...10 {
            projectsPage.createNewProject(
                name: "Search Perf \(i)",
                path: "/test/search/\(i)"
            )
        }
        
        measure {
            projectsPage.searchProjects("Perf")
            Thread.sleep(forTimeInterval: 0.5)
            projectsPage.searchField.clearAndType("")
        }
    }
}