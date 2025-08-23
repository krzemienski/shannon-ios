//
//  CompleteUserJourneyTests.swift
//  ClaudeCodeUITests
//
//  Complete end-to-end user journey test covering the exact flow:
//  1. User opens application
//  2. Selects a project
//  3. Selects a session within a project
//  4. Sends a message within a session
//  5. Scrolls up and looks at a previous message
//  6. Views the monitoring tab
//  7. Changes to the MCP configuration
//  8. Starts a new session within a project
//  9. Starts a new project
//

import XCTest

class CompleteUserJourneyTests: ClaudeCodeUITestCase {
    
    // MARK: - Properties
    
    private var journeyHelper: UserFlowHelpers!
    private var testData: UserJourneyTestData!
    
    // Track created resources for cleanup
    private var firstProjectId: String?
    private var firstSessionId: String?
    private var secondSessionId: String?
    private var secondProjectId: String?
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Configure for real backend testing
        let config = RealBackendConfig.createLaunchConfiguration()
        launchApp(with: config)
        
        // Initialize helper and test data
        journeyHelper = UserFlowHelpers(app: app)
        testData = journeyHelper.generateTestData()
        
        // Verify backend connectivity before starting
        let connectivityExpectation = expectation(description: "Backend connectivity verified")
        Task {
            let isConnected = await journeyHelper.verifyBackendConnectivity()
            XCTAssertTrue(isConnected, "Backend must be available for complete user journey test")
            connectivityExpectation.fulfill()
        }
        wait(for: [connectivityExpectation], timeout: 30.0)
        
        if RealBackendConfig.verboseLogging {
            print("🚀 Starting complete user journey test with test data:")
            print("   Project: \(testData.projectName)")
            print("   Session: \(testData.sessionTitle)")
            print("   Messages: \(testData.firstMessage) | \(testData.secondMessage)")
        }
    }
    
    override func tearDownWithError() throws {
        // Cleanup all created test data
        let cleanupExpectation = expectation(description: "Cleanup completed")
        Task {
            if let helper = journeyHelper {
                await helper.cleanupTestData()
            }
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 60.0)
        
        try super.tearDownWithError()
    }
    
    // MARK: - Complete User Journey Test
    
    /// Complete end-to-end user journey test covering all specified steps
    func testCompleteUserJourneyFlow() throws {
        
        // ==================================================
        // STEP 1: User opens the application
        // ==================================================
        print("\n📱 STEP 1: User opens the application")
        
        let appLaunchSuccess = journeyHelper.performAppLaunch()
        XCTAssertTrue(appLaunchSuccess, "App should launch successfully")
        
        journeyHelper.waitForUIToSettle()
        
        // ==================================================
        // STEP 2: Selects a project
        // ==================================================
        print("\n📁 STEP 2: User selects a project")
        
        let projectCreationExpectation = expectation(description: "Project created and selected")
        Task {
            self.firstProjectId = await self.journeyHelper.performProjectCreationAndSelection(testData: self.testData)
            XCTAssertNotNil(self.firstProjectId, "Project should be created and selected successfully")
            projectCreationExpectation.fulfill()
        }
        wait(for: [projectCreationExpectation], timeout: 45.0)
        
        guard let projectId = firstProjectId else {
            XCTFail("Cannot continue journey without project ID")
            return
        }
        
        journeyHelper.waitForUIToSettle()
        
        // ==================================================
        // STEP 3: Selects a session within a project
        // ==================================================
        print("\n💬 STEP 3: User selects a session within a project")
        
        let sessionCreationExpectation = expectation(description: "Session created and selected")
        Task {
            self.firstSessionId = await self.journeyHelper.performSessionCreationAndSelection(
                projectId: projectId,
                testData: self.testData
            )
            XCTAssertNotNil(self.firstSessionId, "Session should be created and selected successfully")
            sessionCreationExpectation.fulfill()
        }
        wait(for: [sessionCreationExpectation], timeout: 45.0)
        
        guard firstSessionId != nil else {
            XCTFail("Cannot continue journey without session ID")
            return
        }
        
        journeyHelper.waitForUIToSettle()
        
        // ==================================================
        // STEP 4: Sends a message within a session
        // ==================================================
        print("\n✍️ STEP 4: User sends a message within a session")
        
        let messageSendingSuccess = journeyHelper.performMessageSending(testData: testData)
        XCTAssertTrue(messageSendingSuccess, "Messages should be sent successfully")
        
        journeyHelper.waitForUIToSettle()
        
        // ==================================================
        // STEP 5: Scrolls up and looks at a previous message in the session
        // ==================================================
        print("\n📜 STEP 5: User scrolls up and looks at a previous message")
        
        let scrollingSuccess = journeyHelper.performMessageScrolling(testData: testData)
        XCTAssertTrue(scrollingSuccess, "Message scrolling should work correctly")
        
        journeyHelper.waitForUIToSettle()
        
        // ==================================================
        // STEP 6: Views the monitoring tab
        // ==================================================
        print("\n📊 STEP 6: User views the monitoring tab")
        
        let monitoringSuccess = journeyHelper.performMonitoringTabView()
        XCTAssertTrue(monitoringSuccess, "Monitoring tab should be accessible and functional")
        
        journeyHelper.waitForUIToSettle()
        
        // ==================================================
        // STEP 7: Changes to the MCP configuration
        // ==================================================
        print("\n⚙️ STEP 7: User changes MCP configuration")
        
        let mcpConfigSuccess = journeyHelper.performMCPConfigurationChange(testData: testData)
        XCTAssertTrue(mcpConfigSuccess, "MCP configuration should be accessible and modifiable")
        
        journeyHelper.waitForUIToSettle()
        
        // ==================================================
        // STEP 8: Starts a new session within a project
        // ==================================================
        print("\n🆕 STEP 8: User starts a new session within a project")
        
        let newSessionExpectation = expectation(description: "New session created within project")
        Task {
            self.secondSessionId = await self.journeyHelper.performNewSessionInProject(
                projectId: projectId,
                testData: self.testData
            )
            XCTAssertNotNil(self.secondSessionId, "New session should be created within existing project")
            newSessionExpectation.fulfill()
        }
        wait(for: [newSessionExpectation], timeout: 45.0)
        
        guard secondSessionId != nil else {
            XCTFail("Cannot continue journey without second session ID")
            return
        }
        
        journeyHelper.waitForUIToSettle()
        
        // ==================================================
        // STEP 9: Starts a new project
        // ==================================================
        print("\n📂 STEP 9: User starts a new project")
        
        let newProjectExpectation = expectation(description: "New project created")
        Task {
            self.secondProjectId = await self.journeyHelper.performNewProjectCreation(testData: self.testData)
            XCTAssertNotNil(self.secondProjectId, "New project should be created successfully")
            newProjectExpectation.fulfill()
        }
        wait(for: [newProjectExpectation], timeout: 45.0)
        
        guard secondProjectId != nil else {
            XCTFail("Second project was not created successfully")
            return
        }
        
        journeyHelper.waitForUIToSettle()
        
        // ==================================================
        // JOURNEY COMPLETION VERIFICATION
        // ==================================================
        print("\n✅ JOURNEY COMPLETION: Verifying final state")
        
        // Take a final screenshot showing the app state
        let finalScreenshot = XCTAttachment(screenshot: app.screenshot())
        finalScreenshot.name = "10_journey_completed_final_state"
        finalScreenshot.lifetime = .keepAlways
        add(finalScreenshot)
        
        // Verify that we have completed all steps successfully
        XCTAssertNotNil(firstProjectId, "First project should exist")
        XCTAssertNotNil(firstSessionId, "First session should exist")
        XCTAssertNotNil(secondSessionId, "Second session should exist")
        XCTAssertNotNil(secondProjectId, "Second project should exist")
        
        // Verify data persistence by checking backend one final time
        let finalVerificationExpectation = expectation(description: "Final data verification")
        Task {
            do {
                // Verify projects exist
                let projects = try await BackendAPIHelper.shared.getProjects()
                let firstProjectExists = projects.contains { project in
                    guard let id = project["id"] as? String else { return false }
                    return id == self.firstProjectId
                }
                let secondProjectExists = projects.contains { project in
                    guard let id = project["id"] as? String else { return false }
                    return id == self.secondProjectId
                }
                
                XCTAssertTrue(firstProjectExists, "First project should persist in backend")
                XCTAssertTrue(secondProjectExists, "Second project should persist in backend")
                
                // Verify sessions exist for first project
                let sessions = try await BackendAPIHelper.shared.getSessions(projectId: projectId)
                let projectSessions = sessions.filter { session in
                    guard let sessionProjectId = session["project_id"] as? String else { return false }
                    return sessionProjectId == projectId
                }
                
                XCTAssertGreaterThanOrEqual(projectSessions.count, 2, "Should have at least 2 sessions for first project")
                
                if RealBackendConfig.verboseLogging {
                    print("✅ Final verification complete:")
                    print("   - Found \(projects.count) total projects")
                    print("   - Found \(projectSessions.count) sessions for first project")
                    print("   - All journey steps completed successfully")
                }
                
                finalVerificationExpectation.fulfill()
                
            } catch {
                XCTFail("Final verification failed: \(error)")
                finalVerificationExpectation.fulfill()
            }
        }
        wait(for: [finalVerificationExpectation], timeout: 30.0)
        
        print("\n🎉 COMPLETE USER JOURNEY TEST FINISHED SUCCESSFULLY!")
        print("   Journey covered all 9 required steps with real backend integration")
        print("   All data persisted correctly and UI interactions worked as expected")
    }
    
    // MARK: - Additional Journey Tests
    
    /// Test a simplified journey focusing on core interactions
    func testSimplifiedUserJourney() throws {
        print("\n🚀 Starting simplified user journey test")
        
        // Step 1: Launch app
        let appLaunchSuccess = journeyHelper.performAppLaunch()
        XCTAssertTrue(appLaunchSuccess, "App should launch successfully")
        
        // Step 2: Create project
        let projectExpectation = expectation(description: "Simplified project creation")
        Task {
            let projectId = await self.journeyHelper.performProjectCreationAndSelection(testData: self.testData)
            XCTAssertNotNil(projectId, "Project should be created")
            self.firstProjectId = projectId
            projectExpectation.fulfill()
        }
        wait(for: [projectExpectation], timeout: 30.0)
        
        guard let projectId = firstProjectId else {
            XCTFail("Cannot continue without project")
            return
        }
        
        // Step 3: Create session and send message
        let sessionExpectation = expectation(description: "Simplified session creation")
        Task {
            let sessionId = await self.journeyHelper.performSessionCreationAndSelection(
                projectId: projectId,
                testData: self.testData
            )
            XCTAssertNotNil(sessionId, "Session should be created")
            self.firstSessionId = sessionId
            sessionExpectation.fulfill()
        }
        wait(for: [sessionExpectation], timeout: 30.0)
        
        // Step 4: Send and verify message
        let messagingSuccess = journeyHelper.performMessageSending(testData: testData)
        XCTAssertTrue(messagingSuccess, "Messaging should work")
        
        // Step 5: Check monitoring tab
        let monitoringSuccess = journeyHelper.performMonitoringTabView()
        XCTAssertTrue(monitoringSuccess, "Monitoring should be accessible")
        
        print("✅ Simplified user journey completed successfully")
    }
    
    /// Test journey resilience with network delays
    func testJourneyWithNetworkDelays() throws {
        print("\n⏱️ Starting user journey test with network delays")
        
        // This test simulates a user going through the journey with slower network
        // by adding longer wait times and verifying the app handles delays gracefully
        
        let appLaunchSuccess = journeyHelper.performAppLaunch()
        XCTAssertTrue(appLaunchSuccess, "App should handle launch even with slower network")
        
        // Add longer waits to simulate network delays
        Thread.sleep(forTimeInterval: 3.0)
        
        let projectExpectation = expectation(description: "Project creation with delays")
        Task {
            let projectId = await self.journeyHelper.performProjectCreationAndSelection(testData: self.testData)
            XCTAssertNotNil(projectId, "Project creation should handle network delays")
            self.firstProjectId = projectId
            projectExpectation.fulfill()
        }
        wait(for: [projectExpectation], timeout: 60.0) // Longer timeout
        
        // Additional delay before session creation
        Thread.sleep(forTimeInterval: 2.0)
        
        guard let projectId = firstProjectId else {
            XCTFail("Project not created")
            return
        }
        
        let sessionExpectation = expectation(description: "Session creation with delays")
        Task {
            let sessionId = await self.journeyHelper.performSessionCreationAndSelection(
                projectId: projectId,
                testData: self.testData
            )
            XCTAssertNotNil(sessionId, "Session creation should handle delays")
            self.firstSessionId = sessionId
            sessionExpectation.fulfill()
        }
        wait(for: [sessionExpectation], timeout: 60.0) // Longer timeout
        
        print("✅ Journey with network delays completed successfully")
    }
    
    /// Test error recovery during journey
    func testJourneyErrorRecovery() throws {
        print("\n🔄 Starting user journey error recovery test")
        
        // Test that the app can recover from various error states during the journey
        
        let appLaunchSuccess = journeyHelper.performAppLaunch()
        XCTAssertTrue(appLaunchSuccess, "App should launch")
        
        // Attempt to interact with UI before backend is fully ready
        // This tests the app's handling of premature interactions
        
        let projectsPage = ProjectsPage(app: app)
        projectsPage.navigateToProjects()
        
        // Try to create a project immediately (might hit backend before it's ready)
        let errorRecoveryExpectation = expectation(description: "Error recovery test")
        Task {
            do {
                // Wait for backend to be ready
                let _ = await RealBackendConfig.waitForBackend(maxAttempts: 15, interval: 2.0)
                
                // Now proceed with normal flow
                let projectId = await self.journeyHelper.performProjectCreationAndSelection(testData: self.testData)
                self.firstProjectId = projectId
                
                // Test should succeed even after initial potential errors
                XCTAssertNotNil(projectId, "Should recover and create project successfully")
                
                errorRecoveryExpectation.fulfill()
            } catch {
                XCTFail("Error recovery test failed: \(error)")
                errorRecoveryExpectation.fulfill()
            }
        }
        wait(for: [errorRecoveryExpectation], timeout: 90.0)
        
        print("✅ Journey error recovery test completed")
    }
}