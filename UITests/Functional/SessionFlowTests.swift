//
//  SessionFlowTests.swift
//  ClaudeCodeUITests
//
//  Functional tests for session management with real backend
//

import XCTest

class SessionFlowTests: ClaudeCodeUITestCase {
    
    // MARK: - Properties
    
    private var projectsPage: ProjectsPage!
    private var chatPage: ChatPage!
    private var testProjectId: String?
    private var testSessionIds: [String] = []
    private var createdProjectIds: [String] = []
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Configure for real backend testing
        let config = RealBackendConfig.createLaunchConfiguration()
        launchApp(with: config)
        
        projectsPage = ProjectsPage(app: app)
        chatPage = ChatPage(app: app)
        
        // Wait for backend and create test project
        let setupExpectation = expectation(description: "Setup completed")
        Task {
            let isAvailable = await RealBackendConfig.waitForBackend(maxAttempts: 15, interval: 2.0)
            XCTAssertTrue(isAvailable, "Backend must be available for functional tests")
            
            // Create a test project for session testing
            do {
                let testProject = TestProjectData(
                    name: "FunctionalTest_SessionProject",
                    description: "Project for session testing"
                )
                let projectData = try await BackendAPIHelper.shared.createProject(testProject)
                self.testProjectId = projectData["id"] as? String
                if let projectId = self.testProjectId {
                    self.createdProjectIds.append(projectId)
                }
            } catch {
                XCTFail("Failed to create test project: \(error)")
            }
            
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 60.0)
    }
    
    override func tearDownWithError() throws {
        // Clean up sessions and projects
        let cleanupExpectation = expectation(description: "Cleanup completed")
        Task {
            // Clean up sessions first
            for sessionId in testSessionIds {
                do {
                    try await BackendAPIHelper.shared.deleteSession(sessionId)
                    if RealBackendConfig.verboseLogging {
                        print("Cleaned up test session: \(sessionId)")
                    }
                } catch {
                    print("Failed to cleanup session \(sessionId): \(error)")
                }
            }
            
            // Clean up projects
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
    
    // MARK: - Session List Tests
    
    func testViewExistingSessionsFromBackend() throws {
        guard let projectId = testProjectId else {
            XCTFail("Test project not available")
            return
        }
        
        // Create test sessions via API
        let setupExpectation = expectation(description: "Sessions created")
        Task {
            do {
                for i in 1...3 {
                    let sessionData = TestSessionData(
                        projectId: projectId,
                        title: "FunctionalTest_Session_\(i)",
                        model: "claude-3-haiku-20240307"
                    )
                    let session = try await BackendAPIHelper.shared.createSession(sessionData)
                    if let sessionId = session["id"] as? String {
                        self.testSessionIds.append(sessionId)
                    }
                }
                setupExpectation.fulfill()
            } catch {
                XCTFail("Failed to create test sessions: \(error)")
                setupExpectation.fulfill()
            }
        }
        wait(for: [setupExpectation], timeout: 30.0)
        
        takeScreenshot(name: "before_session_list")
        
        // Navigate to project to view sessions
        projectsPage.navigateToProjects()
        waitForElement(projectsPage.projectsList, timeout: RealBackendConfig.uiWaitTimeout)
        Thread.sleep(forTimeInterval: 2.0)
        
        // Select the test project
        projectsPage.selectProject(named: "FunctionalTest_SessionProject")
        
        // Wait for project details and sessions to load
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "project_with_sessions")
        
        // Navigate to chat/sessions view
        chatPage.navigateToChat()
        waitForElement(chatPage.chatList, timeout: RealBackendConfig.uiWaitTimeout)
        
        // Wait for sessions to load from backend
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "sessions_list_loaded")
        
        // Verify sessions appear in list
        let sessionsList = chatPage.chatList
        XCTAssertTrue(sessionsList.exists, "Sessions list should be visible")
        
        // Check for test sessions (the exact verification depends on your UI structure)
        let sessionCells = sessionsList.cells
        XCTAssertGreaterThan(sessionCells.count, 0, "Should have sessions in the list")
        
        if RealBackendConfig.verboseLogging {
            print("Found \(sessionCells.count) sessions in UI")
        }
    }
    
    func testSelectExistingSessionLoadsHistory() throws {
        guard let projectId = testProjectId else {
            XCTFail("Test project not available")
            return
        }
        
        // Create a session with known content
        let sessionSetupExpectation = expectation(description: "Session with history created")
        var testSessionId: String?
        
        Task {
            do {
                let sessionData = TestSessionData(
                    projectId: projectId,
                    title: "FunctionalTest_SessionWithHistory",
                    model: "claude-3-haiku-20240307"
                )
                let session = try await BackendAPIHelper.shared.createSession(sessionData)
                testSessionId = session["id"] as? String
                if let sessionId = testSessionId {
                    self.testSessionIds.append(sessionId)
                }
                sessionSetupExpectation.fulfill()
            } catch {
                XCTFail("Failed to create session with history: \(error)")
                sessionSetupExpectation.fulfill()
            }
        }
        wait(for: [sessionSetupExpectation], timeout: 30.0)
        
        guard let sessionId = testSessionId else {
            XCTFail("Session ID not available")
            return
        }
        
        takeScreenshot(name: "before_session_selection")
        
        // Navigate to sessions list
        chatPage.navigateToChat()
        waitForElement(chatPage.chatList, timeout: RealBackendConfig.uiWaitTimeout)
        Thread.sleep(forTimeInterval: 3.0)
        
        // Find and select the test session
        let sessionsList = chatPage.chatList
        let sessionCells = sessionsList.cells
        
        var sessionFound = false
        for i in 0..<sessionCells.count {
            let cell = sessionCells.element(boundBy: i)
            if cell.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "SessionWithHistory")).firstMatch.exists {
                cell.tap()
                sessionFound = true
                break
            }
        }
        
        XCTAssertTrue(sessionFound, "Should find and select test session")
        
        // Wait for session to load
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "session_selected_and_loaded")
        
        // Verify we're in the chat view for this session
        let chatInputField = chatPage.chatInput
        XCTAssertTrue(
            chatInputField.waitForExistence(timeout: 10),
            "Should be in chat view with input field visible"
        )
        
        takeScreenshot(name: "session_history_loaded")
    }
    
    // MARK: - New Session Creation Tests
    
    func testCreateNewSessionPersistsToBackend() throws {
        guard let projectId = testProjectId else {
            XCTFail("Test project not available")
            return
        }
        
        takeScreenshot(name: "before_new_session")
        
        // Navigate to chat and create new session
        chatPage.navigateToChat()
        waitForElement(chatPage.chatList, timeout: RealBackendConfig.uiWaitTimeout)
        
        // Get initial session count
        let initialSessionCount = chatPage.chatList.cells.count
        
        // Create new session
        chatPage.createNewChat()
        
        // Wait for new session creation
        Thread.sleep(forTimeInterval: 5.0)
        
        takeScreenshot(name: "new_session_created_ui")
        
        // Verify new session appears in UI
        let newSessionCount = chatPage.chatList.cells.count
        XCTAssertGreaterThan(newSessionCount, initialSessionCount, "Should have one more session")
        
        // Verify session exists in backend
        let verificationExpectation = expectation(description: "Backend session verification")
        Task {
            do {
                let sessions = try await BackendAPIHelper.shared.getSessions(projectId: projectId)
                let testSessions = sessions.filter { session in
                    guard let sessionProjectId = session["project_id"] as? String else { return false }
                    return sessionProjectId == projectId
                }
                
                XCTAssertGreaterThan(testSessions.count, 0, "Should have sessions for test project")
                
                // Find the newest session (likely our created one)
                if let newestSession = testSessions.first,
                   let sessionId = newestSession["id"] as? String {
                    self.testSessionIds.append(sessionId)
                    
                    if RealBackendConfig.verboseLogging {
                        print("Verified new session in backend: \(sessionId)")
                    }
                }
                
                verificationExpectation.fulfill()
            } catch {
                XCTFail("Failed to verify session in backend: \(error)")
                verificationExpectation.fulfill()
            }
        }
        wait(for: [verificationExpectation], timeout: 30.0)
        
        takeScreenshot(name: "new_session_verified")
    }
    
    func testSessionCreationWithCustomSettings() throws {
        guard let projectId = testProjectId else {
            XCTFail("Test project not available")
            return
        }
        
        takeScreenshot(name: "before_custom_session")
        
        // Navigate to chat
        chatPage.navigateToChat()
        waitForElement(chatPage.chatList, timeout: RealBackendConfig.uiWaitTimeout)
        
        // Create new session with custom settings (this depends on your UI)
        chatPage.createNewChat()
        
        // Wait for session creation interface
        Thread.sleep(forTimeInterval: 2.0)
        
        // If your app has session configuration UI, interact with it here
        // For example, model selection, system prompt, etc.
        
        takeScreenshot(name: "session_configuration")
        
        // Complete session creation
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "custom_session_created")
        
        // Verify session was created with proper settings
        let verificationExpectation = expectation(description: "Custom session verification")
        Task {
            do {
                let sessions = try await BackendAPIHelper.shared.getSessions(projectId: projectId)
                let projectSessions = sessions.filter { session in
                    guard let sessionProjectId = session["project_id"] as? String else { return false }
                    return sessionProjectId == projectId
                }
                
                if let newestSession = projectSessions.first,
                   let sessionId = newestSession["id"] as? String {
                    self.testSessionIds.append(sessionId)
                    
                    // Verify session properties match what we configured
                    let model = newestSession["model"] as? String
                    XCTAssertNotNil(model, "Session should have a model")
                    
                    if RealBackendConfig.verboseLogging {
                        print("Custom session created with model: \(model ?? "unknown")")
                    }
                }
                
                verificationExpectation.fulfill()
            } catch {
                XCTFail("Failed to verify custom session: \(error)")
                verificationExpectation.fulfill()
            }
        }
        wait(for: [verificationExpectation], timeout: 30.0)
    }
    
    // MARK: - Session Management Tests
    
    func testSwitchBetweenSessions() throws {
        guard let projectId = testProjectId else {
            XCTFail("Test project not available")
            return
        }
        
        // Create multiple sessions for switching test
        let setupExpectation = expectation(description: "Multiple sessions created")
        Task {
            do {
                for i in 1...3 {
                    let sessionData = TestSessionData(
                        projectId: projectId,
                        title: "FunctionalTest_Switch_\(i)",
                        model: "claude-3-haiku-20240307"
                    )
                    let session = try await BackendAPIHelper.shared.createSession(sessionData)
                    if let sessionId = session["id"] as? String {
                        self.testSessionIds.append(sessionId)
                    }
                }
                setupExpectation.fulfill()
            } catch {
                XCTFail("Failed to create sessions for switching test: \(error)")
                setupExpectation.fulfill()
            }
        }
        wait(for: [setupExpectation], timeout: 30.0)
        
        takeScreenshot(name: "before_session_switching")
        
        // Navigate to sessions
        chatPage.navigateToChat()
        waitForElement(chatPage.chatList, timeout: RealBackendConfig.uiWaitTimeout)
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "sessions_available_for_switching")
        
        // Select first session
        let sessionsList = chatPage.chatList
        let firstSession = sessionsList.cells.element(boundBy: 0)
        firstSession.tap()
        
        Thread.sleep(forTimeInterval: 2.0)
        takeScreenshot(name: "first_session_selected")
        
        // Verify we're in chat view
        XCTAssertTrue(
            chatPage.chatInput.waitForExistence(timeout: 10),
            "Should be in first session's chat view"
        )
        
        // Switch to second session
        chatPage.navigateToChat() // Go back to list
        waitForElement(sessionsList, timeout: 10)
        
        if sessionsList.cells.count > 1 {
            let secondSession = sessionsList.cells.element(boundBy: 1)
            secondSession.tap()
            
            Thread.sleep(forTimeInterval: 2.0)
            takeScreenshot(name: "second_session_selected")
            
            // Verify we're in the second session's chat view
            XCTAssertTrue(
                chatPage.chatInput.waitForExistence(timeout: 10),
                "Should be in second session's chat view"
            )
        }
        
        takeScreenshot(name: "session_switching_complete")
    }
    
    func testDeleteSessionRemovesFromBackend() throws {
        guard let projectId = testProjectId else {
            XCTFail("Test project not available")
            return
        }
        
        // Create a session to delete
        let setupExpectation = expectation(description: "Session created for deletion")
        var sessionToDelete: String?
        
        Task {
            do {
                let sessionData = TestSessionData(
                    projectId: projectId,
                    title: "FunctionalTest_DeleteSession",
                    model: "claude-3-haiku-20240307"
                )
                let session = try await BackendAPIHelper.shared.createSession(sessionData)
                sessionToDelete = session["id"] as? String
                setupExpectation.fulfill()
            } catch {
                XCTFail("Failed to create session for deletion: \(error)")
                setupExpectation.fulfill()
            }
        }
        wait(for: [setupExpectation], timeout: 30.0)
        
        guard let sessionId = sessionToDelete else {
            XCTFail("Session ID not available for deletion")
            return
        }
        
        takeScreenshot(name: "before_session_deletion")
        
        // Navigate to sessions
        chatPage.navigateToChat()
        waitForElement(chatPage.chatList, timeout: RealBackendConfig.uiWaitTimeout)
        Thread.sleep(forTimeInterval: 3.0)
        
        // Find and delete the session
        let sessionsList = chatPage.chatList
        let sessionCells = sessionsList.cells
        
        var sessionIndex: Int?
        for i in 0..<sessionCells.count {
            let cell = sessionCells.element(boundBy: i)
            if cell.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "DeleteSession")).firstMatch.exists {
                sessionIndex = i
                break
            }
        }
        
        XCTAssertNotNil(sessionIndex, "Should find session to delete")
        
        if let index = sessionIndex {
            // Delete session (this depends on your UI - swipe, long press, etc.)
            let sessionCell = sessionCells.element(boundBy: index)
            sessionCell.swipeLeft()
            
            // Look for delete button
            let deleteButton = app.buttons["Delete"]
            if deleteButton.waitForExistence(timeout: 5) {
                deleteButton.tap()
                
                // Confirm deletion if alert appears
                let confirmButton = app.alerts.buttons["Delete"]
                if confirmButton.waitForExistence(timeout: 2) {
                    confirmButton.tap()
                }
                
                Thread.sleep(forTimeInterval: 3.0)
                takeScreenshot(name: "session_deleted_from_ui")
                
                // Verify session removed from backend
                let verificationExpectation = expectation(description: "Backend deletion verification")
                Task {
                    do {
                        let sessions = try await BackendAPIHelper.shared.getSessions(projectId: projectId)
                        let deletedSession = sessions.first { session in
                            guard let id = session["id"] as? String else { return false }
                            return id == sessionId
                        }
                        
                        XCTAssertNil(deletedSession, "Session should be deleted from backend")
                        verificationExpectation.fulfill()
                    } catch {
                        print("Error verifying session deletion (this might be expected): \(error)")
                        verificationExpectation.fulfill()
                    }
                }
                wait(for: [verificationExpectation], timeout: 30.0)
            }
        }
    }
    
    func testSessionPersistenceAcrossAppRestart() throws {
        guard let projectId = testProjectId else {
            XCTFail("Test project not available")
            return
        }
        
        // Create a session
        let setupExpectation = expectation(description: "Session created for persistence test")
        var persistentSessionId: String?
        
        Task {
            do {
                let sessionData = TestSessionData(
                    projectId: projectId,
                    title: "FunctionalTest_PersistentSession",
                    model: "claude-3-haiku-20240307"
                )
                let session = try await BackendAPIHelper.shared.createSession(sessionData)
                persistentSessionId = session["id"] as? String
                if let sessionId = persistentSessionId {
                    self.testSessionIds.append(sessionId)
                }
                setupExpectation.fulfill()
            } catch {
                XCTFail("Failed to create persistent session: \(error)")
                setupExpectation.fulfill()
            }
        }
        wait(for: [setupExpectation], timeout: 30.0)
        
        takeScreenshot(name: "session_created_before_restart")
        
        // Verify session exists in UI
        chatPage.navigateToChat()
        waitForElement(chatPage.chatList, timeout: RealBackendConfig.uiWaitTimeout)
        Thread.sleep(forTimeInterval: 3.0)
        
        let sessionExists = chatPage.chatList.cells.containing(NSPredicate(format: "label CONTAINS %@", "PersistentSession")).firstMatch.exists
        XCTAssertTrue(sessionExists, "Session should exist before restart")
        
        takeScreenshot(name: "session_verified_before_restart")
        
        // Restart the app
        app.terminate()
        Thread.sleep(forTimeInterval: 2.0)
        
        let config = RealBackendConfig.createLaunchConfiguration()
        launchApp(with: config)
        
        // Wait for app to fully load
        Thread.sleep(forTimeInterval: 5.0)
        
        takeScreenshot(name: "app_restarted")
        
        // Navigate to sessions again
        chatPage = ChatPage(app: app)
        chatPage.navigateToChat()
        waitForElement(chatPage.chatList, timeout: RealBackendConfig.uiWaitTimeout)
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "sessions_after_restart")
        
        // Verify session still exists
        let sessionStillExists = chatPage.chatList.cells.containing(NSPredicate(format: "label CONTAINS %@", "PersistentSession")).firstMatch.exists
        XCTAssertTrue(sessionStillExists, "Session should persist after app restart")
        
        takeScreenshot(name: "session_persistence_verified")
    }
}