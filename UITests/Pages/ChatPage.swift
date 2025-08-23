//
//  ChatPage.swift
//  ClaudeCodeUITests
//
//  Page object for Chat screens
//

import XCTest

/// Page object for Chat functionality
class ChatPage: BasePage {
    
    // MARK: - Elements
    
    var chatTab: XCUIElement {
        app.tabBars.buttons[AccessibilityIdentifier.tabBarChat]
    }
    
    var chatList: XCUIElement {
        app.tables[AccessibilityIdentifier.chatList]
    }
    
    var newChatButton: XCUIElement {
        app.buttons[AccessibilityIdentifier.chatNewButton]
    }
    
    var chatInput: XCUIElement {
        app.textViews[AccessibilityIdentifier.chatInput]
    }
    
    var sendButton: XCUIElement {
        app.buttons[AccessibilityIdentifier.chatSendButton]
    }
    
    var searchField: XCUIElement {
        app.searchFields["Search conversations"]
    }
    
    var conversationSettingsButton: XCUIElement {
        app.buttons["conversation.settings"]
    }
    
    var toolTimelineButton: XCUIElement {
        app.buttons["tool.timeline"]
    }
    
    var attachmentButton: XCUIElement {
        app.buttons["chat.attachment"]
    }
    
    var voiceInputButton: XCUIElement {
        app.buttons["chat.voice"]
    }
    
    var stopGeneratingButton: XCUIElement {
        app.buttons["chat.stop"]
    }
    
    // MARK: - Actions
    
    func navigateToChat() {
        chatTab.tap()
        waitForPage()
    }
    
    func startNewChat() {
        newChatButton.tap()
        _ = chatInput.waitForExistence(timeout: 5)
    }
    
    func sendMessage(_ message: String) {
        chatInput.tap()
        chatInput.typeText(message)
        sendButton.tap()
    }
    
    func searchConversations(_ query: String) {
        searchField.tap()
        searchField.typeText(query)
    }
    
    func selectConversation(at index: Int) {
        let conversation = chatList.cells.element(boundBy: index)
        conversation.tap()
    }
    
    func openConversationSettings() {
        conversationSettingsButton.tap()
    }
    
    func openToolTimeline() {
        toolTimelineButton.tap()
    }
    
    func attachFile() {
        attachmentButton.tap()
    }
    
    func startVoiceInput() {
        voiceInputButton.tap()
    }
    
    func stopGenerating() {
        if stopGeneratingButton.exists {
            stopGeneratingButton.tap()
        }
    }
    
    func deleteConversation(at index: Int) {
        let conversation = chatList.cells.element(boundBy: index)
        conversation.swipeLeft()
        
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
            
            // Confirm deletion
            let confirmButton = app.alerts.buttons["Delete"]
            if confirmButton.waitForExistence(timeout: 2) {
                confirmButton.tap()
            }
        }
    }
    
    func getChatMessage(at index: Int) -> XCUIElement {
        return app.cells["chat.message.\(index)"]
    }
    
    func getMessageCount() -> Int {
        return app.cells.matching(identifier: AccessibilityIdentifier.chatMessage).count
    }
    
    func scrollToBottom() {
        let lastMessage = app.cells.matching(identifier: AccessibilityIdentifier.chatMessage).element(boundBy: getMessageCount() - 1)
        if lastMessage.exists {
            lastMessage.swipeUp()
        }
    }
    
    func scrollToTop() {
        if chatList.exists {
            chatList.swipeDown()
        }
    }
    
    // MARK: - Verification
    
    override func waitForPage(timeout: TimeInterval = 10) {
        _ = chatList.waitForExistence(timeout: timeout)
    }
    
    func verifyMessageExists(_ text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let message = app.cells.matching(predicate).firstMatch
        return message.exists
    }
    
    func verifyConversationExists(_ title: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", title)
        let conversation = chatList.cells.matching(predicate).firstMatch
        return conversation.exists
    }
    
    func verifyInputIsEnabled() -> Bool {
        return chatInput.isEnabled
    }
    
    func verifySendButtonIsEnabled() -> Bool {
        return sendButton.isEnabled
    }
    
    func verifyToolIsExecuting() -> Bool {
        return app.activityIndicators["tool.executing"].exists
    }
    
    func waitForResponse(timeout: TimeInterval = 30) -> Bool {
        let responseIndicator = app.activityIndicators["chat.responding"]
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: responseIndicator)
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    // MARK: - Advanced Actions
    
    func editMessage(at index: Int, newText: String) {
        let message = getChatMessage(at: index)
        message.press(forDuration: 1.0)
        
        let editButton = app.menuItems["Edit"]
        if editButton.waitForExistence(timeout: 2) {
            editButton.tap()
            
            // Clear and type new text
            let editField = app.textViews["message.edit"]
            if editField.waitForExistence(timeout: 2) {
                editField.tap()
                editField.clearAndType(newText)
                
                let saveButton = app.buttons["Save"]
                saveButton.tap()
            }
        }
    }
    
    func copyMessage(at index: Int) {
        let message = getChatMessage(at: index)
        message.press(forDuration: 1.0)
        
        let copyButton = app.menuItems["Copy"]
        if copyButton.waitForExistence(timeout: 2) {
            copyButton.tap()
        }
    }
    
    func regenerateResponse(at index: Int) {
        let message = getChatMessage(at: index)
        message.swipeLeft()
        
        let regenerateButton = app.buttons["Regenerate"]
        if regenerateButton.waitForExistence(timeout: 2) {
            regenerateButton.tap()
        }
    }
    
    func shareConversation() {
        conversationSettingsButton.tap()
        
        let shareButton = app.buttons["Share Conversation"]
        if shareButton.waitForExistence(timeout: 2) {
            shareButton.tap()
        }
    }
    
    func exportConversation() {
        conversationSettingsButton.tap()
        
        let exportButton = app.buttons["Export"]
        if exportButton.waitForExistence(timeout: 2) {
            exportButton.tap()
        }
    }
}