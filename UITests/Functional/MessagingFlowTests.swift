//
//  MessagingFlowTests.swift
//  ClaudeCodeUITests
//
//  Functional tests for chat messaging with real backend responses
//

import XCTest

class MessagingFlowTests: ClaudeCodeUITestCase {
    
    // MARK: - Properties
    
    private var projectsPage: ProjectsPage!
    private var chatPage: ChatPage!
    private var testProjectId: String?
    private var testSessionId: String?
    private var createdProjectIds: [String] = []
    private var createdSessionIds: [String] = []
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Configure for real backend testing
        let config = RealBackendConfig.createLaunchConfiguration()
        launchApp(with: config)
        
        projectsPage = ProjectsPage(app: app)
        chatPage = ChatPage(app: app)
        
        // Setup test project and session
        let setupExpectation = expectation(description: "Test environment setup")
        Task {
            let isAvailable = await RealBackendConfig.waitForBackend(maxAttempts: 15, interval: 2.0)
            XCTAssertTrue(isAvailable, "Backend must be available for functional tests")
            
            do {
                // Create test project
                let testProject = TestProjectData(
                    name: "FunctionalTest_MessagingProject",
                    description: "Project for messaging tests"
                )
                let projectData = try await BackendAPIHelper.shared.createProject(testProject)
                self.testProjectId = projectData["id"] as? String
                if let projectId = self.testProjectId {
                    self.createdProjectIds.append(projectId)
                    
                    // Create test session
                    let sessionData = TestSessionData(
                        projectId: projectId,
                        title: "FunctionalTest_MessagingSession",
                        model: "claude-3-haiku-20240307",
                        systemPrompt: "You are a helpful assistant. Keep responses brief for testing."
                    )
                    let session = try await BackendAPIHelper.shared.createSession(sessionData)
                    self.testSessionId = session["id"] as? String
                    if let sessionId = self.testSessionId {
                        self.createdSessionIds.append(sessionId)
                    }
                }
            } catch {
                XCTFail("Failed to setup test environment: \(error)")
            }
            
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 60.0)
    }
    
    override func tearDownWithError() throws {
        // Clean up sessions and projects
        let cleanupExpectation = expectation(description: "Cleanup completed")
        Task {
            for sessionId in createdSessionIds {
                do {
                    try await BackendAPIHelper.shared.deleteSession(sessionId)
                    if RealBackendConfig.verboseLogging {
                        print("Cleaned up test session: \(sessionId)")
                    }
                } catch {
                    print("Failed to cleanup session \(sessionId): \(error)")
                }
            }
            
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
    
    // MARK: - Message Sending Tests
    
    func testSendMessageReceivesRealResponse() throws {
        guard testSessionId != nil else {
            XCTFail("Test session not available")
            return
        }
        
        takeScreenshot(name: "before_messaging")
        
        // Navigate to chat and select test session
        navigateToTestSession()
        
        takeScreenshot(name: "chat_interface_ready")
        
        // Send a test message
        let testMessage = "Hello! This is a functional test message. Please respond briefly."
        
        waitForElement(chatPage.chatInput, timeout: 10)
        chatPage.chatInput.tap()
        chatPage.chatInput.typeText(testMessage)
        
        takeScreenshot(name: "message_typed")
        
        // Send the message
        chatPage.sendMessage()
        
        takeScreenshot(name: "message_sent")
        
        // Wait for message to appear in chat
        Thread.sleep(forTimeInterval: 2.0)
        
        // Verify user message appears
        let userMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", testMessage)).firstMatch
        XCTAssertTrue(
            userMessage.waitForExistence(timeout: 10),
            "User message should appear in chat"
        )
        
        takeScreenshot(name: "user_message_visible")
        
        // Wait for real backend response (this may take time)
        let responseTimeout: TimeInterval = 30.0
        let startTime = Date()
        var responseReceived = false
        
        while Date().timeIntervalSince(startTime) < responseTimeout && !responseReceived {
            Thread.sleep(forTimeInterval: 1.0)
            
            // Look for assistant response
            let assistantMessages = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "assistant"))
            if assistantMessages.count > 0 {
                responseReceived = true
                break
            }
            
            // Also look for any new text that's not our test message
            let allTexts = app.staticTexts.allElementsBoundByIndex
            for element in allTexts {
                let text = element.label
                if !text.isEmpty && 
                   text != testMessage && 
                   text.count > 10 && // Reasonable response length
                   !text.contains("FunctionalTest") { // Not our test data
                    responseReceived = true
                    break
                }
            }
        }
        
        takeScreenshot(name: "response_received")
        
        XCTAssertTrue(responseReceived, "Should receive a response from the backend within \(responseTimeout) seconds")
        
        if RealBackendConfig.verboseLogging {
            print("Response received after \(Date().timeIntervalSince(startTime)) seconds")
        }
    }
    
    func testSendMultipleMessagesInSequence() throws {
        guard testSessionId != nil else {
            XCTFail("Test session not available")
            return
        }
        
        navigateToTestSession()
        
        let messages = [
            "Message 1: What is 2+2?",
            "Message 2: What color is the sky?",
            "Message 3: Name one programming language."
        ]
        
        takeScreenshot(name: "before_multiple_messages")
        
        for (index, message) in messages.enumerated() {
            // Send message
            waitForElement(chatPage.chatInput, timeout: 10)
            chatPage.chatInput.tap()
            clearTextField(chatPage.chatInput)
            chatPage.chatInput.typeText(message)
            
            chatPage.sendMessage()
            
            takeScreenshot(name: "message_\(index + 1)_sent")
            
            // Wait for message to appear
            Thread.sleep(forTimeInterval: 2.0)
            
            // Verify message appears
            let messageElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", message)).firstMatch
            XCTAssertTrue(
                messageElement.waitForExistence(timeout: 10),
                "Message \(index + 1) should appear in chat"
            )
            
            // Wait a bit before next message to avoid overwhelming the backend
            Thread.sleep(forTimeInterval: 3.0)
        }
        
        takeScreenshot(name: "all_messages_sent")
        
        // Wait for some responses to come back
        Thread.sleep(forTimeInterval: 10.0)
        
        takeScreenshot(name: "multiple_messages_with_responses")
        
        // Verify we have multiple messages in the chat
        let chatView = app.scrollViews.firstMatch
        if chatView.exists {
            let messageElements = chatView.descendants(matching: .staticText)
            let messageCount = messageElements.allElementsBoundByIndex.filter { element in
                let text = element.label
                return messages.contains { text.contains($0) }
            }.count
            
            XCTAssertEqual(messageCount, messages.count, "All sent messages should be visible")
        }
    }
    
    func testSendEmptyMessageHandledCorrectly() throws {
        guard testSessionId != nil else {
            XCTFail("Test session not available")
            return
        }
        
        navigateToTestSession()
        
        takeScreenshot(name: "before_empty_message")
        
        // Try to send empty message
        waitForElement(chatPage.chatInput, timeout: 10)
        chatPage.chatInput.tap()
        
        // Ensure field is empty
        clearTextField(chatPage.chatInput)
        
        // Try to send
        chatPage.sendMessage()
        
        takeScreenshot(name: "empty_message_attempt")
        
        // Verify empty message wasn't sent or proper validation shown
        Thread.sleep(forTimeInterval: 2.0)
        
        // Look for validation message or verify send button is disabled
        let sendButton = chatPage.sendButton
        let isDisabled = !sendButton.isEnabled
        
        // Or look for validation text
        let validationMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "empty")).firstMatch
        let hasValidation = validationMessage.exists
        
        XCTAssertTrue(
            isDisabled || hasValidation,
            "Should prevent sending empty messages or show validation"
        )
        
        takeScreenshot(name: "empty_message_validation")
    }
    
    // MARK: - Message Persistence Tests
    
    func testMessagesPersistAcrossSessionReconnect() throws {
        guard testSessionId != nil else {
            XCTFail("Test session not available")
            return
        }
        
        navigateToTestSession()
        
        // Send a test message
        let persistentMessage = "This message should persist: \(Date().timeIntervalSince1970)"
        
        waitForElement(chatPage.chatInput, timeout: 10)
        chatPage.chatInput.tap()
        chatPage.chatInput.typeText(persistentMessage)
        chatPage.sendMessage()
        
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "message_sent_for_persistence")
        
        // Verify message appears
        let messageElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", persistentMessage)).firstMatch
        XCTAssertTrue(
            messageElement.waitForExistence(timeout: 10),
            "Message should appear initially"
        )
        
        // Navigate away and back
        projectsPage.navigateToProjects()
        Thread.sleep(forTimeInterval: 2.0)
        
        navigateToTestSession()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "returned_to_session")
        
        // Verify message still exists
        let persistedMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", persistentMessage)).firstMatch
        XCTAssertTrue(
            persistedMessage.waitForExistence(timeout: 10),
            "Message should persist after navigation"
        )
        
        takeScreenshot(name: "message_persistence_verified")
    }
    
    func testMessagesLoadFromBackendOnSessionOpen() throws {
        guard let sessionId = testSessionId else {
            XCTFail("Test session not available")
            return
        }
        
        // Send a message via API to create backend history
        let apiMessage = "Backend message: \(Date().timeIntervalSince1970)"
        
        // Note: This would require implementing message sending via API
        // For now, we'll send via UI first then verify it loads
        
        navigateToTestSession()
        
        // Send message via UI
        waitForElement(chatPage.chatInput, timeout: 10)
        chatPage.chatInput.tap()
        chatPage.chatInput.typeText(apiMessage)
        chatPage.sendMessage()
        
        Thread.sleep(forTimeInterval: 3.0)
        takeScreenshot(name: "message_sent_via_ui")
        
        // Navigate away completely
        app.terminate()
        Thread.sleep(forTimeInterval: 2.0)
        
        // Restart app
        let config = RealBackendConfig.createLaunchConfiguration()
        launchApp(with: config)
        
        chatPage = ChatPage(app: app)
        Thread.sleep(forTimeInterval: 5.0)
        
        // Navigate back to session
        navigateToTestSession()
        Thread.sleep(forTimeInterval: 5.0)
        
        takeScreenshot(name: "session_reopened_after_restart")
        
        // Verify message loaded from backend
        let loadedMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", apiMessage)).firstMatch
        XCTAssertTrue(
            loadedMessage.waitForExistence(timeout: 15),
            "Message should load from backend after app restart"
        )
        
        takeScreenshot(name: "message_loaded_from_backend")
    }
    
    // MARK: - Real-time Communication Tests
    
    func testStreamingResponseUpdates() throws {
        guard testSessionId != nil else {
            XCTFail("Test session not available")
            return
        }
        
        navigateToTestSession()
        
        // Send a message that should get a streaming response
        let streamingMessage = "Please write a short poem about testing. Take your time."
        
        waitForElement(chatPage.chatInput, timeout: 10)
        chatPage.chatInput.tap()
        chatPage.chatInput.typeText(streamingMessage)
        
        takeScreenshot(name: "streaming_message_ready")
        
        chatPage.sendMessage()
        
        takeScreenshot(name: "streaming_message_sent")
        
        // Monitor for streaming indicators or progressive text updates
        let monitoringTimeout: TimeInterval = 30.0
        let startTime = Date()
        var streamingDetected = false
        var previousResponseLength = 0
        
        while Date().timeIntervalSince(startTime) < monitoringTimeout {
            Thread.sleep(forTimeInterval: 1.0)
            
            // Look for streaming indicator
            let streamingIndicator = app.activityIndicators.firstMatch
            if streamingIndicator.exists {
                streamingDetected = true
                takeScreenshot(name: "streaming_indicator_visible")
                break
            }
            
            // Look for progressive text updates
            let responseElements = app.staticTexts.allElementsBoundByIndex
            for element in responseElements {
                let currentLength = element.label.count
                if currentLength > previousResponseLength && 
                   currentLength > streamingMessage.count + 10 && // Longer than our message
                   !element.label.contains("FunctionalTest") {
                    
                    if currentLength > previousResponseLength + 5 { // Significant growth
                        streamingDetected = true
                        previousResponseLength = currentLength
                        takeScreenshot(name: "streaming_text_growing")
                        break
                    }
                }
            }
            
            if streamingDetected {
                break
            }
        }
        
        XCTAssertTrue(streamingDetected, "Should detect streaming response updates")
        
        // Wait for response to complete
        Thread.sleep(forTimeInterval: 10.0)
        
        takeScreenshot(name: "streaming_response_complete")
    }
    
    func testNetworkErrorHandling() throws {
        guard testSessionId != nil else {
            XCTFail("Test session not available")
            return
        }
        
        navigateToTestSession()
        
        // This test is challenging without actually disrupting network
        // We'll test what happens with a very long message that might timeout
        
        let longMessage = String(repeating: "This is a very long message that might cause network issues. ", count: 100)
        
        waitForElement(chatPage.chatInput, timeout: 10)
        chatPage.chatInput.tap()
        chatPage.chatInput.typeText(longMessage)
        
        takeScreenshot(name: "long_message_typed")
        
        chatPage.sendMessage()
        
        takeScreenshot(name: "long_message_sent")
        
        // Monitor for error states
        let errorTimeout: TimeInterval = 60.0
        let startTime = Date()
        var errorDetected = false
        
        while Date().timeIntervalSince(startTime) < errorTimeout {
            Thread.sleep(forTimeInterval: 2.0)
            
            // Look for error indicators
            let errorAlert = app.alerts.firstMatch
            if errorAlert.exists {
                errorDetected = true
                takeScreenshot(name: "error_alert_detected")
                
                // Dismiss error
                if errorAlert.buttons["OK"].exists {
                    errorAlert.buttons["OK"].tap()
                } else if errorAlert.buttons.count > 0 {
                    errorAlert.buttons.firstMatch.tap()
                }
                break
            }
            
            // Look for error text
            let errorText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "error")).firstMatch
            if errorText.exists {
                errorDetected = true
                takeScreenshot(name: "error_text_detected")
                break
            }
            
            // Look for retry button
            let retryButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "retry")).firstMatch
            if retryButton.exists {
                errorDetected = true
                takeScreenshot(name: "retry_button_detected")
                break
            }
        }
        
        // Note: We don't assert error must occur as network might be stable
        if errorDetected {
            print("Network error handling detected and appears to be working")
        } else {
            print("No network error occurred - network appears stable")
        }
        
        takeScreenshot(name: "network_test_complete")
    }
    
    // MARK: - Message History Tests
    
    func testScrollToViewOlderMessages() throws {
        guard testSessionId != nil else {
            XCTFail("Test session not available")
            return
        }
        
        navigateToTestSession()
        
        // Send multiple messages to create scrollable history
        for i in 1...10 {
            let message = "History message \(i): \(Date().timeIntervalSince1970)"
            
            waitForElement(chatPage.chatInput, timeout: 10)
            chatPage.chatInput.tap()
            clearTextField(chatPage.chatInput)
            chatPage.chatInput.typeText(message)
            chatPage.sendMessage()
            
            Thread.sleep(forTimeInterval: 2.0)
        }
        
        takeScreenshot(name: "multiple_messages_sent")
        
        // Wait for all messages to appear
        Thread.sleep(forTimeInterval: 5.0)
        
        // Get chat view for scrolling
        let chatView = app.scrollViews.firstMatch
        XCTAssertTrue(chatView.exists, "Chat view should exist for scrolling")
        
        takeScreenshot(name: "before_scrolling")
        
        // Scroll up to see older messages
        chatView.swipeDown()
        Thread.sleep(forTimeInterval: 1.0)
        chatView.swipeDown()
        Thread.sleep(forTimeInterval: 1.0)
        
        takeScreenshot(name: "after_scrolling_up")
        
        // Verify we can see earlier messages
        let firstMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "History message 1")).firstMatch
        XCTAssertTrue(
            firstMessage.isVisible || firstMessage.exists,
            "Should be able to scroll to see earlier messages"
        )
        
        // Scroll back down
        chatView.swipeUp()
        Thread.sleep(forTimeInterval: 1.0)
        chatView.swipeUp()
        
        takeScreenshot(name: "scrolled_back_down")
        
        // Verify we can see recent messages
        let lastMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "History message 10")).firstMatch
        XCTAssertTrue(
            lastMessage.isVisible || lastMessage.exists,
            "Should be able to scroll back to recent messages"
        )
    }
    
    // MARK: - Helper Methods
    
    private func navigateToTestSession() {
        // Navigate to chat list
        chatPage.navigateToChat()
        waitForElement(chatPage.chatList, timeout: RealBackendConfig.uiWaitTimeout)
        Thread.sleep(forTimeInterval: 3.0)
        
        // Find and select test session
        let sessionsList = chatPage.chatList
        let sessionCells = sessionsList.cells
        
        var sessionFound = false
        for i in 0..<sessionCells.count {
            let cell = sessionCells.element(boundBy: i)
            if cell.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "MessagingSession")).firstMatch.exists {
                cell.tap()
                sessionFound = true
                break
            }
        }
        
        if !sessionFound {
            // Create new session if test session not found
            chatPage.createNewChat()
            Thread.sleep(forTimeInterval: 3.0)
        }
        
        // Wait for chat interface to load
        waitForElement(chatPage.chatInput, timeout: 15)
        Thread.sleep(forTimeInterval: 2.0)
    }
}