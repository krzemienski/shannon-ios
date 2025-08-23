import XCTest

/// Tests for session selection and creation flows
final class SessionFlowTests: BaseUITest {
    
    // MARK: - Setup
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Navigate to a project first
        navigateToFirstProject()
    }
    
    // MARK: - Helper Methods
    
    private func navigateToFirstProject() {
        let projectList = app.collectionViews["ProjectList"]
        if waitForElement(projectList, timeout: 5) {
            let firstProject = projectList.cells.firstMatch
            if firstProject.exists {
                firstProject.tap()
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }
    
    // MARK: - Test Cases
    
    /// Test viewing session list
    func testViewSessionList() throws {
        takeScreenshot(name: "Session List View")
        
        // Check for session list or empty state
        let sessionList = app.collectionViews["SessionList"]
        let emptyStateText = app.staticTexts["No sessions yet"]
        let newSessionButton = app.buttons["New Session"]
        
        let hasSessions = waitForElement(sessionList, timeout: 5)
        let isEmpty = waitForElement(emptyStateText, timeout: 5)
        
        XCTAssertTrue(
            hasSessions || isEmpty,
            "Neither session list nor empty state is visible"
        )
        
        // Verify new session button is available
        XCTAssertTrue(
            newSessionButton.exists || app.navigationBars.buttons["plus"].exists,
            "No way to create new session found"
        )
        
        if hasSessions {
            // Check if there are any sessions
            let firstSession = sessionList.cells.firstMatch
            if firstSession.exists {
                takeScreenshot(name: "Session List with Sessions")
                
                // Verify session has expected elements
                let sessionTitle = firstSession.staticTexts.firstMatch
                XCTAssertTrue(sessionTitle.exists, "Session title not found")
            }
        } else {
            takeScreenshot(name: "Empty Session List")
        }
        
        verifyNetworkRequestSucceeded(description: "Fetched sessions from /v1/sessions")
    }
    
    /// Test selecting an existing session
    func testSelectExistingSession() throws {
        let sessionList = app.collectionViews["SessionList"]
        
        // First create a session if none exist
        if !waitForElement(sessionList, timeout: 3) || sessionList.cells.count == 0 {
            try createNewSession()
        }
        
        // Now select the session
        guard waitForElement(sessionList) else {
            throw XCTSkip("Session list not available")
        }
        
        let firstSession = sessionList.cells.firstMatch
        guard firstSession.exists else {
            throw XCTSkip("No sessions available to select")
        }
        
        takeScreenshot(name: "Before Session Selection")
        
        // Tap on session
        firstSession.tap()
        
        // Verify navigation to chat view
        let messageInput = app.textFields["Message"]
        let messageTextView = app.textViews["MessageInput"]
        let sendButton = app.buttons["Send"]
        
        XCTAssertTrue(
            waitForElement(messageInput) || waitForElement(messageTextView) || waitForElement(sendButton),
            "Did not navigate to chat view after selecting session"
        )
        
        takeScreenshot(name: "Chat View After Session Selection")
        
        // Check for message history
        let messageList = app.scrollViews["MessageList"]
        let messagesTable = app.tables["MessagesTable"]
        
        if messageList.exists || messagesTable.exists {
            takeScreenshot(name: "Chat with Message History")
        }
        
        verifyNetworkRequestSucceeded(description: "Loaded session messages")
    }
    
    /// Test creating a new session
    func testCreateNewSession() throws {
        try createNewSession()
    }
    
    private func createNewSession() throws {
        // Look for new session button
        let newSessionButton = app.buttons["New Session"]
        let createButton = app.buttons["Create Session"]
        let plusButton = app.navigationBars.buttons["plus"]
        
        let button = [newSessionButton, createButton, plusButton].first { $0.exists }
        
        guard let createSessionButton = button else {
            throw XCTSkip("No button found to create new session")
        }
        
        takeScreenshot(name: "Before Creating Session")
        
        // Tap create button
        createSessionButton.tap()
        
        // Handle different UI patterns for session creation
        
        // Pattern 1: Direct creation (no form)
        if !app.textFields["Session Name"].exists && !app.textFields["Session Title"].exists {
            // Session might be created directly
            Thread.sleep(forTimeInterval: 1)
            
            // Verify we're in chat view
            let messageInput = app.textFields["Message"]
            let messageTextView = app.textViews["MessageInput"]
            
            if waitForElement(messageInput, timeout: 3) || waitForElement(messageTextView, timeout: 3) {
                takeScreenshot(name: "New Session Created - Chat View")
                verifyNetworkRequestSucceeded(description: "Created new session via POST /v1/sessions")
                return
            }
        }
        
        // Pattern 2: Session creation form
        let sessionNameField = app.textFields["Session Name"]
        let sessionTitleField = app.textFields["Session Title"]
        
        if waitForElement(sessionNameField, timeout: 3) || waitForElement(sessionTitleField, timeout: 3) {
            takeScreenshot(name: "Create Session Form")
            
            // Fill in session details
            let timestamp = Int(Date().timeIntervalSince1970)
            let sessionName = "Test Session \(timestamp)"
            
            if sessionNameField.exists {
                typeText(sessionName, in: sessionNameField)
            } else if sessionTitleField.exists {
                typeText(sessionName, in: sessionTitleField)
            }
            
            // Look for model selection if available
            let modelPicker = app.pickers["ModelPicker"]
            let modelButton = app.buttons.matching(identifier: "ModelSelection").firstMatch
            
            if modelPicker.exists {
                // Select a model
                let firstModel = modelPicker.pickerWheels.firstMatch
                if firstModel.exists {
                    firstModel.adjust(toPickerWheelValue: "Claude Sonnet 4")
                }
            } else if modelButton.exists {
                modelButton.tap()
                // Select from modal or dropdown
                let sonnetOption = app.staticTexts["Claude Sonnet 4"]
                if waitForElement(sonnetOption, timeout: 2) {
                    sonnetOption.tap()
                }
            }
            
            takeScreenshot(name: "Filled Session Form")
            
            // Submit form
            let saveButton = app.buttons["Save"]
            let createSubmitButton = app.buttons["Create"]
            let doneButton = app.buttons["Done"]
            
            let submitButton = [saveButton, createSubmitButton, doneButton].first { $0.exists }
            submitButton?.tap()
        }
        
        // Verify session was created
        Thread.sleep(forTimeInterval: 1)
        
        // Should be in chat view now
        let messageInput = app.textFields["Message"]
        let messageTextView = app.textViews["MessageInput"]
        
        XCTAssertTrue(
            waitForElement(messageInput) || waitForElement(messageTextView),
            "Did not navigate to chat view after creating session"
        )
        
        takeScreenshot(name: "New Session Created")
        
        verifyNetworkRequestSucceeded(description: "Created new session via POST /v1/sessions")
    }
    
    /// Test switching between sessions
    func testSwitchBetweenSessions() throws {
        // Ensure we have at least 2 sessions
        let sessionList = app.collectionViews["SessionList"]
        
        if !waitForElement(sessionList, timeout: 3) || sessionList.cells.count < 2 {
            // Create sessions if needed
            try createNewSession()
            
            // Navigate back to session list
            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
                Thread.sleep(forTimeInterval: 1)
            }
            
            try createNewSession()
            
            // Navigate back again
            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
                Thread.sleep(forTimeInterval: 1)
            }
        }
        
        guard waitForElement(sessionList) && sessionList.cells.count >= 2 else {
            throw XCTSkip("Need at least 2 sessions for this test")
        }
        
        // Select first session
        let firstSession = sessionList.cells.element(boundBy: 0)
        firstSession.tap()
        
        takeScreenshot(name: "First Session Selected")
        
        // Navigate back
        app.navigationBars.buttons.firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)
        
        // Select second session
        let secondSession = sessionList.cells.element(boundBy: 1)
        secondSession.tap()
        
        takeScreenshot(name: "Second Session Selected")
        
        // Verify we're in a different session (would check session ID or title in real app)
        let messageInput = app.textFields["Message"]
        let messageTextView = app.textViews["MessageInput"]
        
        XCTAssertTrue(
            messageInput.exists || messageTextView.exists,
            "Chat view not available in second session"
        )
    }
    
    /// Test session list refresh
    func testSessionListRefresh() throws {
        let sessionList = app.collectionViews["SessionList"]
        
        // If no session list, check empty state
        if !waitForElement(sessionList, timeout: 5) {
            let emptyState = app.staticTexts["No sessions yet"]
            XCTAssertTrue(waitForElement(emptyState), "Neither session list nor empty state found")
            return
        }
        
        // Pull to refresh
        sessionList.swipeDown()
        
        // Wait for refresh
        Thread.sleep(forTimeInterval: 2)
        
        // Verify list is still present
        XCTAssertTrue(
            sessionList.exists || app.staticTexts["No sessions yet"].exists,
            "Session view disappeared after refresh"
        )
        
        verifyNetworkRequestSucceeded(description: "Refreshed sessions from /v1/sessions")
        
        takeScreenshot(name: "After Session List Refresh")
    }
}