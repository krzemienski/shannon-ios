//
//  ChatUITests.swift
//  ClaudeCodeUITests
//
//  Comprehensive UI tests for Chat functionality
//

import XCTest

class ChatUITests: ClaudeCodeUITestCase {
    
    var chatPage: ChatPage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize page object
        chatPage = ChatPage(app: app)
        
        // Launch app in authenticated state
        app.terminate()
        launchApp(with: .authenticated)
        
        // Navigate to chat
        chatPage.navigateToChat()
    }
    
    // MARK: - Basic Chat Tests
    
    func testStartNewChat() {
        // Start new chat
        chatPage.startNewChat()
        
        // Verify input is enabled
        XCTAssertTrue(chatPage.verifyInputIsEnabled())
        
        // Take screenshot
        takeScreenshot(name: "New-Chat-Started")
    }
    
    func testSendMessage() {
        // Start new chat
        chatPage.startNewChat()
        
        // Send a message
        let testMessage = "Hello, Claude! This is a test message."
        chatPage.sendMessage(testMessage)
        
        // Wait for response
        XCTAssertTrue(chatPage.waitForResponse())
        
        // Verify message was sent
        XCTAssertTrue(chatPage.verifyMessageExists(testMessage))
        
        // Verify response was received
        XCTAssertTrue(chatPage.getMessageCount() > 1)
        
        takeScreenshot(name: "Message-Sent-Response-Received")
    }
    
    func testMultipleMessages() {
        chatPage.startNewChat()
        
        // Send multiple messages
        let messages = [
            "First message",
            "Second message with more content",
            "Third message to test conversation flow"
        ]
        
        for message in messages {
            chatPage.sendMessage(message)
            XCTAssertTrue(chatPage.waitForResponse(timeout: 20))
            XCTAssertTrue(chatPage.verifyMessageExists(message))
        }
        
        // Verify all messages exist
        XCTAssertTrue(chatPage.getMessageCount() >= messages.count * 2) // User + assistant messages
        
        takeScreenshot(name: "Multiple-Messages-Conversation")
    }
    
    func testStopGeneration() {
        chatPage.startNewChat()
        
        // Send a message that would generate a long response
        chatPage.sendMessage("Write a very long essay about the history of computing")
        
        // Wait a moment for generation to start
        Thread.sleep(forTimeInterval: 2)
        
        // Stop generation
        chatPage.stopGenerating()
        
        // Verify generation stopped
        XCTAssertFalse(chatPage.verifyToolIsExecuting())
        
        takeScreenshot(name: "Generation-Stopped")
    }
    
    // MARK: - Conversation Management Tests
    
    func testSearchConversations() {
        // Create multiple conversations first
        for i in 1...3 {
            chatPage.startNewChat()
            chatPage.sendMessage("Test conversation \(i)")
            XCTAssertTrue(chatPage.waitForResponse(timeout: 15))
        }
        
        // Go back to chat list
        chatPage.navigateToChat()
        
        // Search for specific conversation
        chatPage.searchConversations("conversation 2")
        
        // Verify search results
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(chatPage.verifyConversationExists("conversation 2"))
        
        takeScreenshot(name: "Conversation-Search")
    }
    
    func testDeleteConversation() {
        // Create a conversation
        chatPage.startNewChat()
        chatPage.sendMessage("Conversation to delete")
        XCTAssertTrue(chatPage.waitForResponse())
        
        // Go back to chat list
        chatPage.navigateToChat()
        
        // Delete the conversation
        chatPage.deleteConversation(at: 0)
        
        // Verify conversation was deleted
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(chatPage.verifyConversationExists("Conversation to delete"))
        
        takeScreenshot(name: "Conversation-Deleted")
    }
    
    func testConversationSettings() {
        chatPage.startNewChat()
        chatPage.sendMessage("Test message")
        XCTAssertTrue(chatPage.waitForResponse())
        
        // Open conversation settings
        chatPage.openConversationSettings()
        
        // Verify settings opened
        waitForElement(app.navigationBars["Conversation Settings"])
        
        takeScreenshot(name: "Conversation-Settings")
        
        // Go back
        app.navigationBars.buttons.firstMatch.tap()
    }
    
    // MARK: - Tool Timeline Tests
    
    func testToolTimeline() {
        chatPage.startNewChat()
        
        // Send a message that would trigger tool use
        chatPage.sendMessage("What files are in the current directory?")
        XCTAssertTrue(chatPage.waitForResponse())
        
        // Open tool timeline
        chatPage.openToolTimeline()
        
        // Verify timeline opened
        waitForElement(app.navigationBars["Tool Timeline"])
        
        takeScreenshot(name: "Tool-Timeline")
        
        // Go back
        app.navigationBars.buttons.firstMatch.tap()
    }
    
    // MARK: - Message Actions Tests
    
    func testEditMessage() {
        chatPage.startNewChat()
        chatPage.sendMessage("Original message")
        XCTAssertTrue(chatPage.waitForResponse())
        
        // Edit the message
        chatPage.editMessage(at: 0, newText: "Edited message")
        
        // Verify message was edited
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(chatPage.verifyMessageExists("Edited message"))
        XCTAssertFalse(chatPage.verifyMessageExists("Original message"))
        
        takeScreenshot(name: "Message-Edited")
    }
    
    func testCopyMessage() {
        chatPage.startNewChat()
        chatPage.sendMessage("Message to copy")
        XCTAssertTrue(chatPage.waitForResponse())
        
        // Copy the message
        chatPage.copyMessage(at: 0)
        
        // Verify copy action (check for system feedback)
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Message-Copied")
    }
    
    func testRegenerateResponse() {
        chatPage.startNewChat()
        chatPage.sendMessage("Generate a random number")
        XCTAssertTrue(chatPage.waitForResponse())
        
        // Get initial response
        let initialMessageCount = chatPage.getMessageCount()
        
        // Regenerate response
        chatPage.regenerateResponse(at: 1)
        XCTAssertTrue(chatPage.waitForResponse())
        
        // Verify new response was generated
        XCTAssertTrue(chatPage.getMessageCount() > initialMessageCount)
        
        takeScreenshot(name: "Response-Regenerated")
    }
    
    // MARK: - Attachment Tests
    
    func testAttachFile() {
        chatPage.startNewChat()
        
        // Tap attachment button
        chatPage.attachFile()
        
        // Verify file picker opened
        waitForElement(app.navigationBars["Choose File"])
        
        takeScreenshot(name: "File-Attachment-Picker")
        
        // Cancel
        app.buttons["Cancel"].tap()
    }
    
    // MARK: - Voice Input Tests
    
    func testVoiceInput() {
        chatPage.startNewChat()
        
        // Start voice input
        chatPage.startVoiceInput()
        
        // Verify voice input UI appears
        waitForElement(app.otherElements["voice.input.indicator"])
        
        takeScreenshot(name: "Voice-Input-Active")
        
        // Stop voice input
        app.buttons["voice.stop"].tap()
    }
    
    // MARK: - Scrolling Tests
    
    func testScrollToBottom() {
        chatPage.startNewChat()
        
        // Send multiple messages to create scrollable content
        for i in 1...10 {
            chatPage.sendMessage("Message \(i)")
            Thread.sleep(forTimeInterval: 0.5) // Quick responses in test mode
        }
        
        // Scroll to top first
        chatPage.scrollToTop()
        Thread.sleep(forTimeInterval: 0.5)
        
        // Scroll to bottom
        chatPage.scrollToBottom()
        
        // Verify we're at bottom (last message visible)
        let lastMessage = chatPage.getChatMessage(at: 19) // 10 user + 10 assistant messages
        XCTAssertTrue(lastMessage.isVisible)
        
        takeScreenshot(name: "Scrolled-To-Bottom")
    }
    
    // MARK: - Export/Share Tests
    
    func testShareConversation() {
        chatPage.startNewChat()
        chatPage.sendMessage("Conversation to share")
        XCTAssertTrue(chatPage.waitForResponse())
        
        // Share conversation
        chatPage.shareConversation()
        
        // Verify share sheet appears
        waitForElement(app.otherElements["ActivityListView"])
        
        takeScreenshot(name: "Share-Conversation")
        
        // Cancel share
        app.buttons["Close"].tap()
    }
    
    func testExportConversation() {
        chatPage.startNewChat()
        chatPage.sendMessage("Conversation to export")
        XCTAssertTrue(chatPage.waitForResponse())
        
        // Export conversation
        chatPage.exportConversation()
        
        // Verify export options appear
        waitForElement(app.sheets["Export Format"])
        
        takeScreenshot(name: "Export-Conversation")
        
        // Cancel export
        app.buttons["Cancel"].tap()
    }
    
    // MARK: - Error Handling Tests
    
    func testSendEmptyMessage() {
        chatPage.startNewChat()
        
        // Try to send empty message
        chatPage.sendButton.tap()
        
        // Verify send button is disabled or error appears
        XCTAssertFalse(chatPage.verifySendButtonIsEnabled())
        
        takeScreenshot(name: "Empty-Message-Prevented")
    }
    
    func testLongMessage() {
        chatPage.startNewChat()
        
        // Send a very long message
        let longMessage = String(repeating: "This is a long message. ", count: 100)
        chatPage.sendMessage(longMessage)
        
        // Verify message was sent and response received
        XCTAssertTrue(chatPage.waitForResponse(timeout: 30))
        
        takeScreenshot(name: "Long-Message-Handled")
    }
    
    // MARK: - Performance Tests
    
    func testChatResponseTime() {
        measure {
            chatPage.startNewChat()
            chatPage.sendMessage("Quick test")
            _ = chatPage.waitForResponse(timeout: 10)
        }
    }
    
    func testScrollingPerformance() {
        chatPage.startNewChat()
        
        // Create many messages
        for i in 1...20 {
            chatPage.sendMessage("Message \(i)")
            Thread.sleep(forTimeInterval: 0.2)
        }
        
        measure {
            // Scroll up and down
            chatPage.scrollToTop()
            chatPage.scrollToBottom()
        }
    }
    
    func testSearchPerformance() {
        // Create many conversations
        for i in 1...10 {
            chatPage.startNewChat()
            chatPage.sendMessage("Conversation \(i)")
            Thread.sleep(forTimeInterval: 0.2)
        }
        
        chatPage.navigateToChat()
        
        measure {
            chatPage.searchConversations("Conversation")
            Thread.sleep(forTimeInterval: 0.5)
            chatPage.searchField.clearAndType("")
        }
    }
}