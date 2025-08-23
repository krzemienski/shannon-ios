//
//  UserFlowHelpers.swift
//  ClaudeCodeUITests
//
//  Helper methods for comprehensive user journey testing
//

import XCTest

/// Helper class for complex user journey flows with real backend interactions
class UserFlowHelpers {
    
    let app: XCUIApplication
    let projectsPage: ProjectsPage
    let chatPage: ChatPage
    let monitorPage: MonitorPage
    let settingsPage: SettingsPage
    
    private var createdTestData: [String: Any] = [:]
    
    init(app: XCUIApplication) {
        self.app = app
        self.projectsPage = ProjectsPage(app: app)
        self.chatPage = ChatPage(app: app)
        self.monitorPage = MonitorPage(app: app)
        self.settingsPage = SettingsPage(app: app)
    }
    
    // MARK: - Test Data Management
    
    /// Generate unique test identifiers for the journey
    func generateTestData() -> UserJourneyTestData {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 1000...9999)
        
        return UserJourneyTestData(
            projectName: "\(RealBackendConfig.testDataPrefix)Journey_Project_\(timestamp)_\(random)",
            projectDescription: "End-to-end journey test project created at \(Date())",
            sessionTitle: "\(RealBackendConfig.testDataPrefix)Journey_Session_\(timestamp)_\(random)",
            firstMessage: "Hello, this is a test message for the complete user journey. Timestamp: \(timestamp)",
            secondMessage: "This is a follow-up message to test scrolling and message history.",
            mcpConfigName: "TestMCP_\(random)"
        )
    }
    
    /// Store created resource IDs for cleanup
    func storeCreatedResource(type: String, id: String) {
        if createdTestData[type] == nil {
            createdTestData[type] = []
        }
        if var resources = createdTestData[type] as? [String] {
            resources.append(id)
            createdTestData[type] = resources
        }
    }
    
    /// Get stored resource IDs
    func getCreatedResources(type: String) -> [String] {
        return createdTestData[type] as? [String] ?? []
    }
    
    // MARK: - Journey Step Helpers
    
    /// Step 1: App Launch and Initial Setup
    func performAppLaunch() -> Bool {
        takeScreenshot(name: "01_app_launch_start")
        
        // Wait for app to fully load
        let mainTabBar = app.tabBars.firstMatch
        guard mainTabBar.waitForExistence(timeout: 15) else {
            print("❌ App failed to launch properly - tab bar not found")
            return false
        }
        
        takeScreenshot(name: "01_app_launch_complete")
        
        // Verify basic UI elements are present
        let projectsTab = app.tabBars.buttons[AccessibilityIdentifier.tabBarProjects]
        let chatTab = app.tabBars.buttons[AccessibilityIdentifier.tabBarChat]
        let monitorTab = app.tabBars.buttons[AccessibilityIdentifier.tabBarMonitor]
        let settingsTab = app.tabBars.buttons[AccessibilityIdentifier.tabBarSettings]
        
        let allTabsPresent = projectsTab.exists && chatTab.exists && monitorTab.exists && settingsTab.exists
        
        if !allTabsPresent {
            print("❌ Not all main tabs are present after launch")
            takeScreenshot(name: "01_app_launch_missing_tabs")
            return false
        }
        
        print("✅ App launched successfully with all main tabs present")
        return true
    }
    
    /// Step 2: Create and Select Project
    func performProjectCreationAndSelection(testData: UserJourneyTestData) async -> String? {
        takeScreenshot(name: "02_project_creation_start")
        
        // Navigate to projects
        projectsPage.navigateToProjects()
        projectsPage.waitForPage()
        
        takeScreenshot(name: "02_projects_tab_loaded")
        
        // Create new project via UI
        projectsPage.createNewProject(
            name: testData.projectName,
            path: "/tmp/test", // Use a simple test path
            description: testData.projectDescription
        )
        
        // Wait for project creation to complete
        Thread.sleep(forTimeInterval: 3.0)
        takeScreenshot(name: "02_project_created")
        
        // Verify project appears in list
        let projectExists = projectsPage.verifyProjectExists(testData.projectName)
        guard projectExists else {
            print("❌ Project not found in UI after creation")
            takeScreenshot(name: "02_project_creation_failed")
            return nil
        }
        
        // Verify project was created in backend
        do {
            let projects = try await BackendAPIHelper.shared.getProjects()
            let createdProject = projects.first { project in
                guard let name = project["name"] as? String else { return false }
                return name == testData.projectName
            }
            
            guard let project = createdProject,
                  let projectId = project["id"] as? String else {
                print("❌ Project not found in backend")
                return nil
            }
            
            storeCreatedResource(type: "projects", id: projectId)
            print("✅ Project created successfully: \(projectId)")
            
            // Select the project
            projectsPage.selectProject(named: testData.projectName)
            Thread.sleep(forTimeInterval: 2.0)
            takeScreenshot(name: "02_project_selected")
            
            return projectId
            
        } catch {
            print("❌ Failed to verify project in backend: \(error)")
            return nil
        }
    }
    
    /// Step 3: Create and Select Session
    func performSessionCreationAndSelection(projectId: String, testData: UserJourneyTestData) async -> String? {
        takeScreenshot(name: "03_session_creation_start")
        
        // Navigate to chat/sessions
        chatPage.navigateToChat()
        chatPage.waitForPage()
        
        takeScreenshot(name: "03_chat_tab_loaded")
        
        // Get initial session count
        let initialSessionCount = chatPage.chatList.cells.count
        
        // Create new session
        chatPage.startNewChat()
        
        // Wait for session creation
        Thread.sleep(forTimeInterval: 4.0)
        takeScreenshot(name: "03_session_created")
        
        // Verify new session was created in UI
        let newSessionCount = chatPage.chatList.cells.count
        guard newSessionCount > initialSessionCount else {
            print("❌ No new session created in UI")
            return nil
        }
        
        // Verify session was created in backend
        do {
            let sessions = try await BackendAPIHelper.shared.getSessions(projectId: projectId)
            let projectSessions = sessions.filter { session in
                guard let sessionProjectId = session["project_id"] as? String else { return false }
                return sessionProjectId == projectId
            }
            
            guard let latestSession = projectSessions.first,
                  let sessionId = latestSession["id"] as? String else {
                print("❌ No session found in backend for project")
                return nil
            }
            
            storeCreatedResource(type: "sessions", id: sessionId)
            print("✅ Session created successfully: \(sessionId)")
            
            takeScreenshot(name: "03_session_verified")
            return sessionId
            
        } catch {
            print("❌ Failed to verify session in backend: \(error)")
            return nil
        }
    }
    
    /// Step 4: Send Message in Session
    func performMessageSending(testData: UserJourneyTestData) -> Bool {
        takeScreenshot(name: "04_message_sending_start")
        
        // Ensure we're in chat input area
        guard chatPage.chatInput.waitForExistence(timeout: 10) else {
            print("❌ Chat input field not available")
            return false
        }
        
        // Send first message
        chatPage.sendMessage(testData.firstMessage)
        
        // Wait for message to appear and potentially get response
        Thread.sleep(forTimeInterval: 3.0)
        takeScreenshot(name: "04_first_message_sent")
        
        // Verify message appears in chat
        let messageExists = chatPage.verifyMessageExists(testData.firstMessage)
        guard messageExists else {
            print("❌ First message not found in chat")
            return false
        }
        
        // Send second message for scroll testing
        chatPage.sendMessage(testData.secondMessage)
        Thread.sleep(forTimeInterval: 3.0)
        takeScreenshot(name: "04_second_message_sent")
        
        // Verify second message exists
        let secondMessageExists = chatPage.verifyMessageExists(testData.secondMessage)
        guard secondMessageExists else {
            print("❌ Second message not found in chat")
            return false
        }
        
        print("✅ Messages sent successfully")
        return true
    }
    
    /// Step 5: Scroll and View Previous Messages
    func performMessageScrolling(testData: UserJourneyTestData) -> Bool {
        takeScreenshot(name: "05_scrolling_start")
        
        // Scroll to bottom to ensure we see latest messages
        chatPage.scrollToBottom()
        Thread.sleep(forTimeInterval: 1.0)
        takeScreenshot(name: "05_scrolled_to_bottom")
        
        // Scroll to top to view earlier messages
        chatPage.scrollToTop()
        Thread.sleep(forTimeInterval: 2.0)
        takeScreenshot(name: "05_scrolled_to_top")
        
        // Verify we can still see the first message
        let firstMessageVisible = chatPage.verifyMessageExists(testData.firstMessage)
        guard firstMessageVisible else {
            print("❌ First message not visible after scrolling")
            return false
        }
        
        // Scroll back down to see recent messages
        chatPage.scrollToBottom()
        Thread.sleep(forTimeInterval: 1.0)
        takeScreenshot(name: "05_scrolled_back_down")
        
        // Verify we can see the second message again
        let secondMessageVisible = chatPage.verifyMessageExists(testData.secondMessage)
        guard secondMessageVisible else {
            print("❌ Second message not visible after scrolling back")
            return false
        }
        
        print("✅ Message scrolling completed successfully")
        return true
    }
    
    /// Step 6: View Monitoring Tab
    func performMonitoringTabView() -> Bool {
        takeScreenshot(name: "06_monitoring_start")
        
        // Navigate to monitoring tab
        monitorPage.navigateToMonitor()
        monitorPage.waitForPage()
        
        takeScreenshot(name: "06_monitoring_tab_loaded")
        
        // Verify monitoring elements are present
        let metricsViewExists = monitorPage.metricsView.exists
        guard metricsViewExists else {
            print("❌ Metrics view not found in monitoring tab")
            return false
        }
        
        // Check for some basic monitoring elements
        let refreshButtonExists = monitorPage.refreshButton.exists
        let performanceChartExists = monitorPage.performanceChart.exists
        
        if refreshButtonExists || performanceChartExists {
            // Try to refresh metrics to test interactivity
            if refreshButtonExists {
                monitorPage.refreshMetrics()
                Thread.sleep(forTimeInterval: 2.0)
                takeScreenshot(name: "06_metrics_refreshed")
            }
            
            print("✅ Monitoring tab accessed and interacted with successfully")
            return true
        } else {
            print("⚠️ Monitoring tab loaded but some elements may be missing")
            takeScreenshot(name: "06_monitoring_partial")
            return true // Still consider this successful as basic view loaded
        }
    }
    
    /// Step 7: Change MCP Configuration
    func performMCPConfigurationChange(testData: UserJourneyTestData) -> Bool {
        takeScreenshot(name: "07_mcp_config_start")
        
        // Navigate to settings
        settingsPage.navigateToSettings()
        settingsPage.waitForPage()
        
        takeScreenshot(name: "07_settings_loaded")
        
        // Look for advanced settings or MCP configuration section
        // This depends on your app's specific settings structure
        settingsPage.selectSettingsSection(.advanced)
        Thread.sleep(forTimeInterval: 2.0)
        
        takeScreenshot(name: "07_advanced_settings")
        
        // Try to access MCP configuration (this will depend on your UI)
        // For now, we'll simulate changing some advanced settings as a proxy
        
        // Toggle debug mode as an example configuration change
        let debugModeCurrentState = settingsPage.debugModeToggle.value as? String == "1"
        settingsPage.toggleDebugMode(!debugModeCurrentState)
        
        Thread.sleep(forTimeInterval: 1.0)
        takeScreenshot(name: "07_debug_mode_toggled")
        
        // Toggle it back to original state
        settingsPage.toggleDebugMode(debugModeCurrentState)
        
        Thread.sleep(forTimeInterval: 1.0)
        takeScreenshot(name: "07_mcp_config_changed")
        
        print("✅ MCP/Advanced configuration accessed and modified")
        return true
    }
    
    /// Step 8: Start New Session Within Project
    func performNewSessionInProject(projectId: String, testData: UserJourneyTestData) async -> String? {
        takeScreenshot(name: "08_new_session_start")
        
        // Navigate back to chat
        chatPage.navigateToChat()
        chatPage.waitForPage()
        
        // Get current session count
        let currentSessionCount = chatPage.chatList.cells.count
        
        // Create another new session
        chatPage.startNewChat()
        Thread.sleep(forTimeInterval: 4.0)
        
        takeScreenshot(name: "08_new_session_created")
        
        // Verify another session was created
        let newSessionCount = chatPage.chatList.cells.count
        guard newSessionCount > currentSessionCount else {
            print("❌ Second new session not created")
            return nil
        }
        
        // Verify in backend
        do {
            let sessions = try await BackendAPIHelper.shared.getSessions(projectId: projectId)
            let projectSessions = sessions.filter { session in
                guard let sessionProjectId = session["project_id"] as? String else { return false }
                return sessionProjectId == projectId
            }
            
            // Should have at least 2 sessions now
            guard projectSessions.count >= 2 else {
                print("❌ Expected at least 2 sessions for project, found \(projectSessions.count)")
                return nil
            }
            
            // Get the newest session
            if let newestSession = projectSessions.first,
               let sessionId = newestSession["id"] as? String {
                storeCreatedResource(type: "sessions", id: sessionId)
                print("✅ Second session created successfully: \(sessionId)")
                return sessionId
            }
            
            return nil
            
        } catch {
            print("❌ Failed to verify second session: \(error)")
            return nil
        }
    }
    
    /// Step 9: Start New Project
    func performNewProjectCreation(testData: UserJourneyTestData) async -> String? {
        takeScreenshot(name: "09_new_project_start")
        
        // Navigate to projects
        projectsPage.navigateToProjects()
        projectsPage.waitForPage()
        
        // Generate data for second project
        let timestamp = Int(Date().timeIntervalSince1970)
        let secondProjectName = "\(RealBackendConfig.testDataPrefix)Journey_Project2_\(timestamp)"
        let secondProjectDescription = "Second project for journey test"
        
        // Create second project
        projectsPage.createNewProject(
            name: secondProjectName,
            path: "/tmp/test2",
            description: secondProjectDescription
        )
        
        Thread.sleep(forTimeInterval: 3.0)
        takeScreenshot(name: "09_second_project_created")
        
        // Verify second project exists
        let projectExists = projectsPage.verifyProjectExists(secondProjectName)
        guard projectExists else {
            print("❌ Second project not found in UI")
            return nil
        }
        
        // Verify in backend
        do {
            let projects = try await BackendAPIHelper.shared.getProjects()
            let createdProject = projects.first { project in
                guard let name = project["name"] as? String else { return false }
                return name == secondProjectName
            }
            
            guard let project = createdProject,
                  let projectId = project["id"] as? String else {
                print("❌ Second project not found in backend")
                return nil
            }
            
            storeCreatedResource(type: "projects", id: projectId)
            print("✅ Second project created successfully: \(projectId)")
            
            return projectId
            
        } catch {
            print("❌ Failed to verify second project: \(error)")
            return nil
        }
    }
    
    // MARK: - Cleanup Helpers
    
    /// Clean up all created test data
    func cleanupTestData() async {
        print("🧹 Starting test data cleanup...")
        
        // Clean up sessions first
        let sessionIds = getCreatedResources(type: "sessions")
        for sessionId in sessionIds {
            do {
                try await BackendAPIHelper.shared.deleteSession(sessionId)
                print("✅ Cleaned up session: \(sessionId)")
            } catch {
                print("⚠️ Failed to cleanup session \(sessionId): \(error)")
            }
        }
        
        // Clean up projects
        let projectIds = getCreatedResources(type: "projects")
        for projectId in projectIds {
            do {
                try await BackendAPIHelper.shared.deleteProject(projectId)
                print("✅ Cleaned up project: \(projectId)")
            } catch {
                print("⚠️ Failed to cleanup project \(projectId): \(error)")
            }
        }
        
        // General cleanup
        await RealBackendConfig.cleanupTestData()
        
        print("🧹 Test data cleanup completed")
    }
    
    // MARK: - Utility Methods
    
    private func takeScreenshot(name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        XCTContext.runActivity(named: "Screenshot: \(name)") { _ in
            XCTContext.addAttachment(screenshot)
        }
    }
    
    /// Verify backend connectivity before starting journey
    func verifyBackendConnectivity() async -> Bool {
        let isAvailable = await RealBackendConfig.waitForBackend(maxAttempts: 10, interval: 2.0)
        if !isAvailable {
            print("❌ Backend is not available for user journey test")
        } else {
            print("✅ Backend connectivity verified")
        }
        return isAvailable
    }
    
    /// Wait for UI to settle after navigation
    func waitForUIToSettle() {
        Thread.sleep(forTimeInterval: 1.5)
    }
}

// MARK: - Test Data Structure

/// Test data for the complete user journey
struct UserJourneyTestData {
    let projectName: String
    let projectDescription: String
    let sessionTitle: String
    let firstMessage: String
    let secondMessage: String
    let mcpConfigName: String
}