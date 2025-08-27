import XCTest

/// Tests for chat creation and message streaming with real backend
class ChatStreamingTests: BaseUITest {
    
    // MARK: - Setup
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Login before each test
        performLogin()
        
        // Navigate to Chat tab
        navigateToTab("Chat")
    }
    
    // MARK: - Chat Creation Tests
    
    /// Test creating a new chat conversation
    func testCreateNewChat() throws {
        // Tap new chat button
        let newChatButton = app.navigationBars["Chat"].buttons["New Chat"]
        waitAndTap(newChatButton)
        
        captureScreenshot(name: "01_new_chat_screen")
        
        // Select model
        let modelSelector = app.buttons["Model Selector"]
        if modelSelector.exists {
            waitAndTap(modelSelector)
            
            // Select Claude 3 Opus
            let claudeOpus = app.cells.staticTexts["Claude 3 Opus"]
            if claudeOpus.exists {
                claudeOpus.tap()
            }
        }
        
        // Enter chat title (optional)
        let titleField = app.textFields["Chat Title"]
        if titleField.exists {
            typeText("Test Chat - \(Date())", in: titleField)
        }
        
        // Start chat
        let startButton = app.buttons["Start Chat"]
        waitAndTap(startButton)
        
        // Verify chat was created
        XCTAssertTrue(waitForElement(app.textViews["Message Input"], timeout: uiTimeout),
                     "Message input should be visible after creating chat")
        
        captureScreenshot(name: "02_chat_created")
    }
    
    /// Test sending a message and receiving streamed response
    func testMessageStreaming() throws {
        // Create new chat first
        try testCreateNewChat()
        
        // Type a message
        let messageInput = app.textViews["Message Input"]
        let testMessage = "Hello, can you explain what Swift is in one paragraph?"
        typeText(testMessage, in: messageInput)
        
        captureScreenshot(name: "03_message_typed")
        
        // Send message
        let sendButton = app.buttons["Send"]
        waitAndTap(sendButton)
        
        // Verify message appears in chat
        XCTAssertTrue(waitForElement(app.cells.staticTexts[testMessage], timeout: uiTimeout),
                     "Sent message should appear in chat")
        
        // Wait for streaming indicator
        let streamingIndicator = app.otherElements["StreamingIndicator"]
        XCTAssertTrue(waitForElement(streamingIndicator, timeout: uiTimeout),
                     "Streaming indicator should appear")
        
        captureScreenshot(name: "04_streaming_started")
        
        // Verify response is streaming (text gradually appearing)
        let responseCell = app.cells.containing(.staticText, identifier: "Assistant").firstMatch
        verifyStreaming(in: responseCell, timeout: apiTimeout)
        
        // Wait for streaming to complete
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: streamingIndicator)
        wait(for: [expectation], timeout: apiTimeout)
        
        captureScreenshot(name: "05_response_complete")
        
        // Verify response content
        let responseText = responseCell.staticTexts.firstMatch.label
        XCTAssertTrue(responseText.contains("Swift"),
                     "Response should contain information about Swift")
        XCTAssertGreaterThan(responseText.count, 50,
                            "Response should be substantial")
    }
    
    /// Test sending multiple messages in sequence
    func testMultipleMessageExchange() throws {
        try testCreateNewChat()
        
        let messages = [
            "What is 2 + 2?",
            "Now multiply that by 10",
            "What was my first question?"
        ]
        
        for (index, message) in messages.enumerated() {
            // Send message
            let messageInput = app.textViews["Message Input"]
            typeText(message, in: messageInput)
            waitAndTap(app.buttons["Send"])
            
            // Wait for response
            waitForAPIResponse(timeout: apiTimeout)
            
            // Verify both user message and AI response are visible
            XCTAssertTrue(app.cells.staticTexts[message].exists,
                         "Message \(index + 1) should be visible")
            
            // Wait for assistant response
            let responseCells = app.cells.containing(.staticText, identifier: "Assistant")
            XCTAssertGreaterThanOrEqual(responseCells.count, index + 1,
                                       "Should have \(index + 1) assistant responses")
            
            captureScreenshot(name: "message_exchange_\(index + 1)")
        }
        
        // Verify conversation context is maintained
        let lastResponse = app.cells.containing(.staticText, identifier: "Assistant").element(boundBy: 2)
        let lastResponseText = lastResponse.staticTexts.firstMatch.label
        XCTAssertTrue(lastResponseText.contains("2 + 2") || lastResponseText.contains("first question"),
                     "AI should remember the conversation context")
    }
    
    /// Test code block rendering in responses
    func testCodeBlockRendering() throws {
        try testCreateNewChat()
        
        // Ask for code
        let messageInput = app.textViews["Message Input"]
        typeText("Show me a simple Swift function to calculate factorial", in: messageInput)
        waitAndTap(app.buttons["Send"])
        
        // Wait for response
        waitForAPIResponse(timeout: apiTimeout)
        
        // Look for code block
        let codeBlock = app.scrollViews.containing(.other, identifier: "CodeBlock").firstMatch
        XCTAssertTrue(waitForElement(codeBlock, timeout: apiTimeout),
                     "Code block should be rendered")
        
        // Verify syntax highlighting
        XCTAssertTrue(app.staticTexts["func"].exists || app.staticTexts["Swift"].exists,
                     "Code should have syntax highlighting")
        
        // Test copy code button
        let copyButton = app.buttons["Copy Code"]
        if copyButton.exists {
            copyButton.tap()
            
            // Verify copy feedback
            XCTAssertTrue(app.staticTexts["Copied!"].waitForExistence(timeout: 2.0),
                         "Should show copy confirmation")
        }
        
        captureScreenshot(name: "code_block_rendered")
    }
    
    /// Test message editing
    func testEditMessage() throws {
        try testCreateNewChat()
        
        // Send initial message
        let messageInput = app.textViews["Message Input"]
        typeText("What is the capital of France?", in: messageInput)
        waitAndTap(app.buttons["Send"])
        
        waitForAPIResponse(timeout: apiTimeout)
        
        // Long press on sent message to edit
        let sentMessage = app.cells.staticTexts["What is the capital of France?"]
        sentMessage.press(forDuration: 1.0)
        
        // Tap edit option
        let editButton = app.buttons["Edit"]
        if waitForElement(editButton, timeout: uiTimeout) {
            editButton.tap()
            
            // Edit the message
            let editField = app.textViews["Edit Message"]
            editField.clearText()
            typeText("What is the capital of Germany?", in: editField)
            
            // Save edit
            waitAndTap(app.buttons["Save"])
            
            // Verify message was edited and new response is generated
            XCTAssertTrue(app.cells.staticTexts["What is the capital of Germany?"].exists,
                         "Edited message should be visible")
            
            // Wait for new response
            waitForAPIResponse(timeout: apiTimeout)
            
            // Verify response is about Germany
            let responseCell = app.cells.containing(.staticText, identifier: "Assistant").lastMatch
            let responseText = responseCell.staticTexts.firstMatch.label
            XCTAssertTrue(responseText.contains("Berlin"),
                         "Response should be about Germany's capital")
        }
    }
    
    /// Test message deletion
    func testDeleteMessage() throws {
        try testCreateNewChat()
        
        // Send a message
        let messageInput = app.textViews["Message Input"]
        typeText("Test message to delete", in: messageInput)
        waitAndTap(app.buttons["Send"])
        
        waitForAPIResponse(timeout: apiTimeout)
        
        // Long press to show options
        let sentMessage = app.cells.staticTexts["Test message to delete"]
        sentMessage.press(forDuration: 1.0)
        
        // Delete message
        let deleteButton = app.buttons["Delete"]
        if waitForElement(deleteButton, timeout: uiTimeout) {
            deleteButton.tap()
            
            // Confirm deletion
            let confirmButton = app.alerts.buttons["Delete"]
            if confirmButton.exists {
                confirmButton.tap()
            }
            
            // Verify message is deleted
            XCTAssertFalse(app.cells.staticTexts["Test message to delete"].exists,
                          "Deleted message should not be visible")
        }
    }
    
    /// Test stop generation during streaming
    func testStopGeneration() throws {
        try testCreateNewChat()
        
        // Send a message that will generate a long response
        let messageInput = app.textViews["Message Input"]
        typeText("Write a very detailed 1000 word essay about artificial intelligence", in: messageInput)
        waitAndTap(app.buttons["Send"])
        
        // Wait for streaming to start
        let streamingIndicator = app.otherElements["StreamingIndicator"]
        XCTAssertTrue(waitForElement(streamingIndicator, timeout: uiTimeout),
                     "Streaming should start")
        
        // Stop generation
        let stopButton = app.buttons["Stop"]
        if waitForElement(stopButton, timeout: 2.0) {
            stopButton.tap()
            
            // Verify streaming stopped
            XCTAssertFalse(streamingIndicator.exists,
                          "Streaming indicator should disappear after stopping")
            
            // Verify partial response exists
            let responseCell = app.cells.containing(.staticText, identifier: "Assistant").firstMatch
            XCTAssertTrue(responseCell.exists,
                         "Partial response should be visible")
            
            captureScreenshot(name: "generation_stopped")
        }
    }
    
    /// Test chat search functionality
    func testChatSearch() throws {
        // Create multiple chats with different content
        for i in 1...3 {
            try testCreateNewChat()
            
            let messageInput = app.textViews["Message Input"]
            typeText("Test chat number \(i) with unique content", in: messageInput)
            waitAndTap(app.buttons["Send"])
            
            waitForAPIResponse(timeout: apiTimeout)
            
            // Go back to chat list
            app.navigationBars.buttons.firstMatch.tap()
        }
        
        // Use search
        let searchField = app.searchFields.firstMatch
        if waitForElement(searchField, timeout: uiTimeout) {
            searchField.tap()
            searchField.typeText("number 2")
            
            // Verify search results
            Thread.sleep(forTimeInterval: 1.0) // Wait for search
            
            XCTAssertTrue(app.cells.containing(.staticText, identifier: "number 2").firstMatch.exists,
                         "Search should find chat with 'number 2'")
            
            XCTAssertFalse(app.cells.containing(.staticText, identifier: "number 1").firstMatch.exists,
                          "Search should filter out chat without 'number 2'")
        }
    }
    
    /// Test chat persistence across sessions
    func testChatPersistence() throws {
        try testCreateNewChat()
        
        // Send a unique message
        let uniqueMessage = "Unique test message \(UUID().uuidString)"
        let messageInput = app.textViews["Message Input"]
        typeText(uniqueMessage, in: messageInput)
        waitAndTap(app.buttons["Send"])
        
        waitForAPIResponse(timeout: apiTimeout)
        
        // Force quit and relaunch
        app.terminate()
        app.launch()
        performLogin()
        navigateToTab("Chat")
        
        // Verify chat and messages are preserved
        XCTAssertTrue(app.cells.staticTexts[uniqueMessage].exists,
                     "Chat messages should persist across sessions")
    }
    
    /// Test concurrent message sending
    func testConcurrentMessages() throws {
        try testCreateNewChat()
        
        let messageInput = app.textViews["Message Input"]
        let sendButton = app.buttons["Send"]
        
        // Try to send multiple messages quickly
        typeText("First message", in: messageInput)
        sendButton.tap()
        
        // Input should be disabled while processing
        XCTAssertFalse(messageInput.isEnabled,
                      "Message input should be disabled while sending")
        
        // Wait for first message to complete
        waitForAPIResponse(timeout: apiTimeout)
        
        // Now input should be enabled again
        XCTAssertTrue(messageInput.isEnabled,
                     "Message input should be re-enabled after sending")
        
        // Send another message
        typeText("Second message", in: messageInput)
        sendButton.tap()
        
        waitForAPIResponse(timeout: apiTimeout)
        
        // Verify both messages and responses exist
        XCTAssertTrue(app.cells.staticTexts["First message"].exists)
        XCTAssertTrue(app.cells.staticTexts["Second message"].exists)
        
        let assistantCells = app.cells.containing(.staticText, identifier: "Assistant")
        XCTAssertGreaterThanOrEqual(assistantCells.count, 2,
                                   "Should have responses for both messages")
    }
    
    // MARK: - Performance Tests
    
    /// Test streaming performance
    func testStreamingPerformance() throws {
        try testCreateNewChat()
        
        measureAPIPerformance(operation: "Message Streaming") {
            let messageInput = app.textViews["Message Input"]
            typeText("Hello, how are you?", in: messageInput)
            waitAndTap(app.buttons["Send"])
            
            // Measure time to start streaming
            let streamingIndicator = app.otherElements["StreamingIndicator"]
            XCTAssertTrue(waitForElement(streamingIndicator, timeout: 5.0),
                         "Streaming should start within 5 seconds")
            
            // Measure time to complete
            let predicate = NSPredicate(format: "exists == false")
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: streamingIndicator)
            wait(for: [expectation], timeout: apiTimeout)
        }
    }
    
    /// Test chat list loading performance
    func testChatListPerformance() throws {
        // Create multiple chats first
        for _ in 1...10 {
            try testCreateNewChat()
            app.navigationBars.buttons.firstMatch.tap() // Go back
        }
        
        measureAPIPerformance(operation: "Chat List Loading") {
            // Navigate away and back
            navigateToTab("Projects")
            navigateToTab("Chat")
            
            // Verify chats are loaded
            XCTAssertGreaterThanOrEqual(app.cells.count, 10,
                                       "Should load all created chats")
        }
    }
}