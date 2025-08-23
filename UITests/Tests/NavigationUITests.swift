//
//  NavigationUITests.swift
//  ClaudeCodeUITests
//
//  UI tests for app navigation and flow
//

import XCTest

class NavigationUITests: ClaudeCodeUITestCase {
    
    var chatPage: ChatPage!
    var projectsPage: ProjectsPage!
    var toolsPage: ToolsPage!
    var monitorPage: MonitorPage!
    var settingsPage: SettingsPage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize all page objects
        chatPage = ChatPage(app: app)
        projectsPage = ProjectsPage(app: app)
        toolsPage = ToolsPage(app: app)
        monitorPage = MonitorPage(app: app)
        settingsPage = SettingsPage(app: app)
        
        // Launch app in authenticated state
        app.terminate()
        launchApp(with: .authenticated)
    }
    
    // MARK: - Tab Bar Navigation Tests
    
    func testTabBarNavigation() {
        // Test navigation to each tab
        
        // Chat tab (should be default)
        XCTAssertTrue(chatPage.chatTab.isSelected)
        waitForElement(chatPage.chatList)
        takeScreenshot(name: "Nav-Chat-Tab")
        
        // Projects tab
        projectsPage.navigateToProjects()
        XCTAssertTrue(projectsPage.projectsTab.isSelected)
        waitForElement(projectsPage.projectsList)
        takeScreenshot(name: "Nav-Projects-Tab")
        
        // Tools tab
        toolsPage.navigateToTools()
        XCTAssertTrue(toolsPage.toolsTab.isSelected)
        waitForElement(toolsPage.toolsList)
        takeScreenshot(name: "Nav-Tools-Tab")
        
        // Monitor tab
        monitorPage.navigateToMonitor()
        XCTAssertTrue(monitorPage.monitorTab.isSelected)
        waitForElement(monitorPage.metricsView)
        takeScreenshot(name: "Nav-Monitor-Tab")
        
        // Settings tab
        settingsPage.navigateToSettings()
        XCTAssertTrue(settingsPage.settingsTab.isSelected)
        waitForElement(settingsPage.settingsList)
        takeScreenshot(name: "Nav-Settings-Tab")
    }
    
    func testTabBarPersistence() {
        // Navigate to a specific tab
        projectsPage.navigateToProjects()
        
        // Go deeper into the navigation
        projectsPage.newProjectButton.tap()
        waitForElement(projectsPage.projectNameField)
        
        // Navigate to another tab
        chatPage.navigateToChat()
        
        // Go back to projects
        projectsPage.navigateToProjects()
        
        // Should return to projects list, not the new project screen
        waitForElement(projectsPage.projectsList)
        
        takeScreenshot(name: "Nav-Tab-State-Persistence")
    }
    
    func testTabBarBadges() {
        // Generate some activity to create badges
        
        // Create a notification in chat
        chatPage.navigateToChat()
        chatPage.startNewChat()
        chatPage.sendMessage("Test message")
        
        // Navigate away
        projectsPage.navigateToProjects()
        
        // Check for badge on chat tab
        let chatBadge = chatPage.chatTab.badges.firstMatch
        if chatBadge.exists {
            takeScreenshot(name: "Nav-Tab-Badge")
        }
    }
    
    // MARK: - Deep Navigation Tests
    
    func testChatDeepNavigation() {
        // Navigate through chat screens
        chatPage.navigateToChat()
        
        // Start new chat
        chatPage.startNewChat()
        waitForElement(chatPage.chatInput)
        
        // Send message
        chatPage.sendMessage("Test")
        _ = chatPage.waitForResponse()
        
        // Open conversation settings
        chatPage.openConversationSettings()
        waitForElement(app.navigationBars["Conversation Settings"])
        
        // Go back through navigation stack
        app.navigationBars.buttons.firstMatch.tap()
        waitForElement(chatPage.chatInput)
        
        app.navigationBars.buttons.firstMatch.tap()
        waitForElement(chatPage.chatList)
        
        takeScreenshot(name: "Nav-Chat-Deep")
    }
    
    func testProjectsDeepNavigation() {
        // Navigate through projects screens
        projectsPage.navigateToProjects()
        
        // Create new project
        projectsPage.newProjectButton.tap()
        waitForElement(projectsPage.projectNameField)
        
        projectsPage.projectNameField.tap()
        projectsPage.projectNameField.typeText("Nav Test Project")
        projectsPage.projectPathField.tap()
        projectsPage.projectPathField.typeText("/test/nav")
        projectsPage.createProjectButton.tap()
        
        Thread.sleep(forTimeInterval: 1)
        
        // Select the project
        projectsPage.selectProject(named: "Nav Test Project")
        waitForElement(app.navigationBars["Nav Test Project"])
        
        // Open project settings
        projectsPage.openProjectSettings()
        waitForElement(app.navigationBars["Project Settings"])
        
        // Navigate back
        app.navigationBars.buttons.firstMatch.tap()
        waitForElement(app.navigationBars["Nav Test Project"])
        
        app.navigationBars.buttons.firstMatch.tap()
        waitForElement(projectsPage.projectsList)
        
        takeScreenshot(name: "Nav-Projects-Deep")
    }
    
    func testToolsDeepNavigation() {
        // Navigate through tools screens
        toolsPage.navigateToTools()
        
        // Select a tool
        toolsPage.selectTool(named: "Echo")
        waitForElement(toolsPage.parametersContainer)
        
        // Navigate back
        app.navigationBars.buttons.firstMatch.tap()
        waitForElement(toolsPage.toolsList)
        
        // Open tool history
        toolsPage.openHistory()
        waitForElement(app.tables["tools.history.list"])
        
        // Navigate back
        app.navigationBars.buttons.firstMatch.tap()
        waitForElement(toolsPage.toolsList)
        
        takeScreenshot(name: "Nav-Tools-Deep")
    }
    
    func testSettingsDeepNavigation() {
        // Navigate through settings screens
        settingsPage.navigateToSettings()
        
        // Open API settings
        settingsPage.selectSettingsSection(.api)
        waitForElement(settingsPage.apiKeyField)
        
        // Navigate back
        app.navigationBars.buttons.firstMatch.tap()
        waitForElement(settingsPage.settingsList)
        
        // Open appearance settings
        settingsPage.selectSettingsSection(.appearance)
        waitForElement(settingsPage.themeSelector)
        
        // Navigate back
        app.navigationBars.buttons.firstMatch.tap()
        waitForElement(settingsPage.settingsList)
        
        takeScreenshot(name: "Nav-Settings-Deep")
    }
    
    // MARK: - Cross-Tab Navigation Tests
    
    func testCrossTabNavigation() {
        // Start in chat
        chatPage.navigateToChat()
        chatPage.startNewChat()
        
        // Navigate to projects
        projectsPage.navigateToProjects()
        
        // Navigate to tools
        toolsPage.navigateToTools()
        
        // Navigate back to chat
        chatPage.navigateToChat()
        
        // Should maintain chat state
        waitForElement(chatPage.chatInput)
        
        takeScreenshot(name: "Nav-Cross-Tab")
    }
    
    func testQuickActions() {
        // Test quick action shortcuts
        
        // Long press on chat tab for quick actions
        chatPage.chatTab.press(forDuration: 1.0)
        
        if app.menuItems["New Chat"].waitForExistence(timeout: 2) {
            app.menuItems["New Chat"].tap()
            waitForElement(chatPage.chatInput)
            takeScreenshot(name: "Nav-Quick-Action-Chat")
        }
        
        // Long press on projects tab
        projectsPage.projectsTab.press(forDuration: 1.0)
        
        if app.menuItems["New Project"].waitForExistence(timeout: 2) {
            app.menuItems["New Project"].tap()
            waitForElement(projectsPage.projectNameField)
            takeScreenshot(name: "Nav-Quick-Action-Project")
        }
    }
    
    // MARK: - Modal Navigation Tests
    
    func testModalPresentation() {
        // Test modal presentations
        
        // Share from chat
        chatPage.navigateToChat()
        chatPage.startNewChat()
        chatPage.sendMessage("Share test")
        _ = chatPage.waitForResponse()
        chatPage.shareConversation()
        
        // Verify share sheet (modal)
        waitForElement(app.otherElements["ActivityListView"])
        
        // Dismiss modal
        app.buttons["Close"].tap()
        
        // Should return to chat
        waitForElement(chatPage.chatInput)
        
        takeScreenshot(name: "Nav-Modal-Share")
    }
    
    func testAlertNavigation() {
        // Test alert presentations
        
        // Trigger an alert
        settingsPage.navigateToSettings()
        settingsPage.selectSettingsSection(.account)
        settingsPage.signOutButton.tap()
        
        // Verify alert appears
        waitForElement(app.alerts.firstMatch)
        
        // Cancel alert
        app.alerts.buttons["Cancel"].tap()
        
        // Should remain in settings
        waitForElement(settingsPage.settingsList)
        
        takeScreenshot(name: "Nav-Alert")
    }
    
    // MARK: - Gesture Navigation Tests
    
    func testSwipeNavigation() {
        // Test swipe gestures for navigation
        
        // Navigate to a detail view
        projectsPage.navigateToProjects()
        projectsPage.newProjectButton.tap()
        waitForElement(projectsPage.projectNameField)
        
        // Swipe from left edge to go back
        let leftEdge = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        leftEdge.press(forDuration: 0.1, thenDragTo: center)
        
        // Should navigate back
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Nav-Swipe-Back")
    }
    
    // MARK: - Navigation State Tests
    
    func testNavigationStateRestoration() {
        // Test state restoration after app backgrounding
        
        // Set up specific navigation state
        projectsPage.navigateToProjects()
        projectsPage.newProjectButton.tap()
        projectsPage.projectNameField.tap()
        projectsPage.projectNameField.typeText("State Test")
        
        // Simulate app backgrounding
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        
        // Relaunch app
        app.activate()
        
        // Verify state was restored
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(projectsPage.projectNameField.exists)
        XCTAssertEqual(projectsPage.projectNameField.value as? String, "State Test")
        
        takeScreenshot(name: "Nav-State-Restored")
    }
    
    func testDeepLinkNavigation() {
        // Test deep link navigation
        
        // Terminate app
        app.terminate()
        
        // Launch with deep link
        app.launchArguments = ["--uitesting", "--deeplink", "claudecode://chat/new"]
        app.launch()
        
        // Should open directly to new chat
        waitForElement(chatPage.chatInput)
        
        takeScreenshot(name: "Nav-Deep-Link")
    }
    
    // MARK: - Performance Tests
    
    func testTabSwitchingPerformance() {
        measure {
            // Switch through all tabs
            chatPage.navigateToChat()
            projectsPage.navigateToProjects()
            toolsPage.navigateToTools()
            monitorPage.navigateToMonitor()
            settingsPage.navigateToSettings()
        }
    }
    
    func testNavigationStackPerformance() {
        measure {
            // Push and pop navigation stack
            settingsPage.navigateToSettings()
            settingsPage.selectSettingsSection(.api)
            app.navigationBars.buttons.firstMatch.tap()
            settingsPage.selectSettingsSection(.appearance)
            app.navigationBars.buttons.firstMatch.tap()
        }
    }
    
    func testDeepNavigationPerformance() {
        projectsPage.navigateToProjects()
        
        measure {
            // Navigate deep and back
            projectsPage.newProjectButton.tap()
            _ = projectsPage.projectNameField.waitForExistence(timeout: 2)
            app.navigationBars.buttons.firstMatch.tap()
        }
    }
}