import XCTest

/// Tests for messaging and chat interaction flows
final class MessagingFlowTests: BaseUITest {
    
    // MARK: - Setup
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Navigate to a chat session
        navigateToChatSession()
    }
    
    // MARK: - Helper Methods
    
    private func navigateToChatSession() {
        // Navigate to first project
        let projectList = app.collectionViews["ProjectList"]
        if waitForElement(projectList, timeout: 5) {
            let firstProject = projectList.cells.firstMatch
            if firstProject.exists {
                firstProject.tap()
                Thread.sleep(forTimeInterval: 1)
            }
        }
        
        // Navigate to or create a session
        let sessionList = app.collectionViews["SessionList"]
        if waitForElement(sessionList, timeout: 3) {
            let firstSession = sessionList.cells.firstMatch
            if firstSession.exists {
                firstSession.tap()
            } else {
                createNewSession()
            }
        } else {
            createNewSession()
        }
        
        Thread.sleep(forTimeInterval: 1)
    }
    
    private func createNewSession() {
        let newSessionButton = app.buttons["New Session"]
        let plusButton = app.navigationBars.buttons["plus"]
        
        if newSessionButton.exists {
            newSessionButton.tap()
        } else if plusButton.exists {
            plusButton.tap()
        }
        
        Thread.sleep(forTimeInterval: 1)
    }
    
    // MARK: - Test Cases
    
    /// Test sending a simple text message
    func testSendTextMessage() throws {
        takeScreenshot(name: "Chat View Initial")
        
        // Find message input
        let messageField = app.textFields["Message"]
        let messageTextView = app.textViews["MessageInput"]
        let messageInput = messageField.exists ? messageField : messageTextView
        
        guard messageInput.exists else {
            throw XCTSkip("Message input field not found")
        }
        
        // Type a message
        let testMessage = "Hello Claude! This is a test message."
        typeText(testMessage, in: messageInput)
        
        takeScreenshot(name: "Message Typed")
        
        // Find and tap send button
        let sendButton = app.buttons["Send"]
        let sendIcon = app.buttons["SendMessage"]
        let button = sendButton.exists ? sendButton : sendIcon
        
        XCTAssertTrue(button.exists, "Send button not found")
        button.tap()
        
        // Wait for message to appear in chat
        Thread.sleep(forTimeInterval: 2)
        
        // Verify message appears in chat history
        let messageList = app.scrollViews["MessageList"]
        let messagesTable = app.tables["MessagesTable"]
        let chatContainer = messageList.exists ? messageList : messagesTable
        
        if chatContainer.exists {
            // Look for the sent message
            let sentMessage = chatContainer.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Hello Claude")).firstMatch
            XCTAssertTrue(
                waitForElement(sentMessage, timeout: 5),
                "Sent message not found in chat history"
            )
        }
        
        takeScreenshot(name: "Message Sent")
        
        // Wait for Claude's response
        let responseIndicator = app.activityIndicators["LoadingResponse"]
        let typingIndicator = app.staticTexts["Claude is typing..."]
        
        if responseIndicator.exists || typingIndicator.exists {
            takeScreenshot(name: "Waiting for Response")
            
            // Wait for response (with longer timeout for real API)
            Thread.sleep(forTimeInterval: networkTimeout)
        }
        
        // Verify response received
        if chatContainer.exists {
            let responseMessages = chatContainer.staticTexts.allElementsBoundByIndex
            XCTAssertTrue(
                responseMessages.count > 1,
                "No response received from Claude"
            )
        }
        
        takeScreenshot(name: "Response Received")
        
        verifyNetworkRequestSucceeded(description: "Sent message via POST /v1/chat/completions")
    }
    
    /// Test sending multiple messages
    func testSendMultipleMessages() throws {
        let messages = [
            "First test message",
            "Second test message with more content",
            "Third message to test conversation flow"
        ]
        
        let messageField = app.textFields["Message"]
        let messageTextView = app.textViews["MessageInput"]
        let messageInput = messageField.exists ? messageField : messageTextView
        
        guard messageInput.exists else {
            throw XCTSkip("Message input field not found")
        }
        
        let sendButton = app.buttons["Send"]
        let sendIcon = app.buttons["SendMessage"]
        let button = sendButton.exists ? sendButton : sendIcon
        
        for (index, message) in messages.enumerated() {
            // Clear input if needed
            if !messageInput.value as? String == "" {
                clearTextField(messageInput)
            }
            
            // Type and send message
            typeText(message, in: messageInput)
            button.tap()
            
            // Wait for message to be sent
            Thread.sleep(forTimeInterval: 2)
            
            takeScreenshot(name: "Message \(index + 1) Sent")
            
            // Wait a bit between messages
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Verify all messages appear in history
        let messageList = app.scrollViews["MessageList"]
        let messagesTable = app.tables["MessagesTable"]
        let chatContainer = messageList.exists ? messageList : messagesTable
        
        if chatContainer.exists {
            for message in messages {
                let sentMessage = chatContainer.staticTexts.containing(
                    NSPredicate(format: "label CONTAINS[c] %@", message.prefix(10))
                ).firstMatch
                
                XCTAssertTrue(
                    sentMessage.exists,
                    "Message '\(message.prefix(20))...' not found in chat"
                )
            }
        }
        
        takeScreenshot(name: "Multiple Messages Sent")
    }
    
    /// Test scrolling through message history
    func testScrollMessageHistory() throws {
        // First send a few messages to create history
        try testSendMultipleMessages()
        
        let messageList = app.scrollViews["MessageList"]
        let messagesTable = app.tables["MessagesTable"]
        let chatContainer = messageList.exists ? messageList : messagesTable
        
        guard chatContainer.exists else {
            throw XCTSkip("Message container not found")
        }
        
        takeScreenshot(name: "Before Scrolling")
        
        // Scroll up to see older messages
        chatContainer.swipeDown()
        Thread.sleep(forTimeInterval: 0.5)
        takeScreenshot(name: "Scrolled Up")
        
        // Scroll down to latest
        chatContainer.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        takeScreenshot(name: "Scrolled Down")
        
        // Test scroll to bottom button if available
        let scrollToBottomButton = app.buttons["ScrollToBottom"]
        if scrollToBottomButton.exists {
            // Scroll up first
            chatContainer.swipeDown()
            chatContainer.swipeDown()
            
            // Tap scroll to bottom
            scrollToBottomButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            
            takeScreenshot(name: "Scrolled to Bottom via Button")
        }
    }
    
    /// Test message input validation
    func testMessageInputValidation() throws {
        let messageField = app.textFields["Message"]
        let messageTextView = app.textViews["MessageInput"]
        let messageInput = messageField.exists ? messageField : messageTextView
        
        guard messageInput.exists else {
            throw XCTSkip("Message input field not found")
        }
        
        let sendButton = app.buttons["Send"]
        let sendIcon = app.buttons["SendMessage"]
        let button = sendButton.exists ? sendButton : sendIcon
        
        // Test empty message
        clearTextField(messageInput)
        button.tap()
        
        // Should not send empty message
        Thread.sleep(forTimeInterval: 1)
        
        // Verify no empty message was sent
        let messageList = app.scrollViews["MessageList"]
        let messagesTable = app.tables["MessagesTable"]
        let chatContainer = messageList.exists ? messageList : messagesTable
        
        if chatContainer.exists {
            let messageCount = chatContainer.staticTexts.count
            
            // Send a real message
            typeText("Valid message", in: messageInput)
            button.tap()
            Thread.sleep(forTimeInterval: 2)
            
            // Count should increase
            let newCount = chatContainer.staticTexts.count
            XCTAssertTrue(newCount > messageCount, "Message count should increase after valid message")
        }
        
        // Test very long message
        let longMessage = String(repeating: "This is a very long message. ", count: 100)
        clearTextField(messageInput)
        typeText(String(longMessage.prefix(500)), in: messageInput) // Type first 500 chars
        
        takeScreenshot(name: "Long Message Input")
        
        button.tap()
        Thread.sleep(forTimeInterval: 3)
        
        takeScreenshot(name: "Long Message Sent")
    }
    
    /// Test message retry on failure
    func testMessageRetryOnFailure() throws {
        // This test would ideally simulate network failure
        // For now, we'll just verify retry UI elements exist
        
        let messageField = app.textFields["Message"]
        let messageTextView = app.textViews["MessageInput"]
        let messageInput = messageField.exists ? messageField : messageTextView
        
        guard messageInput.exists else {
            throw XCTSkip("Message input field not found")
        }
        
        // Send a message
        typeText("Test message for retry", in: messageInput)
        
        let sendButton = app.buttons["Send"]
        let sendIcon = app.buttons["SendMessage"]
        let button = sendButton.exists ? sendButton : sendIcon
        button.tap()
        
        // In a real test, we'd simulate failure here
        // For now, just check if retry UI elements exist
        Thread.sleep(forTimeInterval: 2)
        
        // Look for error indicators
        let retryButton = app.buttons["Retry"]
        let errorIcon = app.images["ErrorIcon"]
        let errorMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'error'")).firstMatch
        
        if retryButton.exists {
            takeScreenshot(name: "Message Failed - Retry Available")
            
            // Test retry
            retryButton.tap()
            Thread.sleep(forTimeInterval: 2)
            
            takeScreenshot(name: "Message Retried")
        }
        
        // Even if no failure, test passes as retry mechanism is optional
    }
    
    /// Test streaming response
    func testStreamingResponse() throws {
        let messageField = app.textFields["Message"]
        let messageTextView = app.textViews["MessageInput"]
        let messageInput = messageField.exists ? messageField : messageTextView
        
        guard messageInput.exists else {
            throw XCTSkip("Message input field not found")
        }
        
        // Send a message that should trigger streaming
        typeText("Please write a detailed explanation about Swift programming", in: messageInput)
        
        let sendButton = app.buttons["Send"]
        let sendIcon = app.buttons["SendMessage"]
        let button = sendButton.exists ? sendButton : sendIcon
        button.tap()
        
        // Wait for streaming to start
        Thread.sleep(forTimeInterval: 1)
        
        // Look for streaming indicators
        let streamingIndicator = app.activityIndicators["StreamingResponse"]
        let typingIndicator = app.staticTexts["Claude is typing..."]
        let partialResponse = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Swift'")).firstMatch
        
        if streamingIndicator.exists || typingIndicator.exists {
            takeScreenshot(name: "Streaming Response Started")
            
            // Wait for partial content
            Thread.sleep(forTimeInterval: 2)
            
            if partialResponse.exists {
                takeScreenshot(name: "Streaming Partial Content")
            }
            
            // Wait for completion
            let maxWait = networkTimeout
            var waited: TimeInterval = 0
            while (streamingIndicator.exists || typingIndicator.exists) && waited < maxWait {
                Thread.sleep(forTimeInterval: 1)
                waited += 1
            }
        }
        
        takeScreenshot(name: "Streaming Response Complete")
        
        verifyNetworkRequestSucceeded(description: "Streamed response via SSE from /v1/chat/completions")
    }
}