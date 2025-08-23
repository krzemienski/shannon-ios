//
//  ChatStore.swift
//  ClaudeCode
//
//  Manages chat conversations and message history
//

import SwiftUI
import Combine

/// Store for managing chat conversations and history
@MainActor
final class ChatStore: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var isLoading = false
    @Published var error: ChatError?
    @Published var searchText = ""
    
    // MARK: - Computed Properties
    
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        }
        return conversations.filter { conversation in
            // Optimize search by only checking title first, then messages if needed
            if conversation.title.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            // Limit message search to recent messages for performance
            let recentMessages = conversation.messages.suffix(20)
            return recentMessages.contains { message in
                message.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var pinnedConversations: [Conversation] {
        conversations.filter { $0.isPinned }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var recentConversations: [Conversation] {
        conversations.filter { !$0.isPinned }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    // MARK: - Private Properties
    
    private let apiClient: APIClient
    private let documentsDirectory: URL
    private let conversationsFile = "conversations.json"
    private var autoSaveTimer: Timer?
    private var pendingChanges = false
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
        
        // Get documents directory
        self.documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        
        // Load conversations on init
        Task {
            await loadConversations()
        }
        
        // Setup auto-save
        setupAutoSave()
    }
    
    // MARK: - Public Methods - Conversation Management
    
    /// Create a new conversation
    func createConversation(title: String? = nil) -> Conversation {
        let conversation = Conversation(
            title: title ?? generateConversationTitle(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        conversations.insert(conversation, at: 0)
        currentConversation = conversation
        pendingChanges = true
        
        return conversation
    }
    
    /// Delete a conversation
    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        
        if currentConversation?.id == conversation.id {
            currentConversation = conversations.first
        }
        
        pendingChanges = true
        
        // Delete associated files
        Task {
            await deleteConversationFiles(conversation)
        }
    }
    
    /// Delete multiple conversations
    func deleteConversations(_ conversationIds: Set<String>) {
        conversations.removeAll { conversationIds.contains($0.id) }
        
        if let currentId = currentConversation?.id,
           conversationIds.contains(currentId) {
            currentConversation = conversations.first
        }
        
        pendingChanges = true
    }
    
    /// Update conversation title
    func updateConversationTitle(_ conversation: Conversation, title: String) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].title = title
            conversations[index].updatedAt = Date()
            
            if currentConversation?.id == conversation.id {
                currentConversation?.title = title
            }
            
            pendingChanges = true
        }
    }
    
    /// Toggle conversation pin status
    func togglePin(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].isPinned.toggle()
            conversations[index].updatedAt = Date()
            
            if currentConversation?.id == conversation.id {
                currentConversation?.isPinned.toggle()
            }
            
            pendingChanges = true
        }
    }
    
    /// Add tags to conversation
    func addTags(_ tags: [String], to conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            let uniqueTags = Set(conversations[index].tags + tags)
            conversations[index].tags = Array(uniqueTags).sorted()
            conversations[index].updatedAt = Date()
            
            if currentConversation?.id == conversation.id {
                currentConversation?.tags = conversations[index].tags
            }
            
            pendingChanges = true
        }
    }
    
    /// Remove tag from conversation
    func removeTag(_ tag: String, from conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].tags.removeAll { $0 == tag }
            conversations[index].updatedAt = Date()
            
            if currentConversation?.id == conversation.id {
                currentConversation?.tags = conversations[index].tags
            }
            
            pendingChanges = true
        }
    }
    
    // MARK: - Public Methods - Message Management
    
    /// Add a message to the current conversation
    func addMessage(_ message: Message) {
        guard let conversation = currentConversation else {
            // Create new conversation if none exists
            let newConversation = createConversation()
            addMessageToConversation(message, conversation: newConversation)
            return
        }
        
        addMessageToConversation(message, conversation: conversation)
    }
    
    /// Add a message to a specific conversation
    func addMessageToConversation(_ message: Message, conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].addMessage(message)
            
            if currentConversation?.id == conversation.id {
                currentConversation?.addMessage(message)
            }
            
            // Update conversation title if it's the first user message
            if conversation.messages.count == 1 && message.role == .user {
                let title = generateTitleFromMessage(message.content)
                conversations[index].title = title
                
                if currentConversation?.id == conversation.id {
                    currentConversation?.title = title
                }
            }
            
            pendingChanges = true
        }
    }
    
    /// Update a message in the current conversation
    func updateMessage(id: String, content: String) {
        guard let conversation = currentConversation else { return }
        
        if let conversationIndex = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[conversationIndex].updateMessage(id: id, content: content)
            currentConversation?.updateMessage(id: id, content: content)
            pendingChanges = true
        }
    }
    
    /// Delete a message from the current conversation
    func deleteMessage(_ message: Message) {
        guard let conversation = currentConversation else { return }
        
        if let conversationIndex = conversations.firstIndex(where: { $0.id == conversation.id }),
           let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == message.id }) {
            conversations[conversationIndex].messages.remove(at: messageIndex)
            conversations[conversationIndex].updatedAt = Date()
            
            currentConversation?.messages.remove(at: messageIndex)
            currentConversation?.updatedAt = Date()
            
            pendingChanges = true
        }
    }
    
    // MARK: - Public Methods - Persistence
    
    /// Load conversations from disk
    func loadConversations() async {
        let fileURL = documentsDirectory.appendingPathComponent(conversationsFile)
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            conversations = try decoder.decode([Conversation].self, from: data)
            
            // Set current conversation to the most recent
            currentConversation = conversations.first
        } catch {
            print("Failed to load conversations: \(error)")
            // Start with empty conversations
            conversations = []
        }
    }
    
    /// Save conversations to disk
    func saveConversations() async {
        let fileURL = documentsDirectory.appendingPathComponent(conversationsFile)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(conversations)
            try data.write(to: fileURL)
            pendingChanges = false
        } catch {
            print("Failed to save conversations: \(error)")
        }
    }
    
    /// Save pending changes if any
    func savePendingChanges() async {
        if pendingChanges {
            await saveConversations()
        }
    }
    
    /// Export conversation as JSON
    func exportConversation(_ conversation: Conversation) async throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(conversation)
    }
    
    /// Import conversation from JSON
    func importConversation(from data: Data) async throws -> Conversation {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let conversation = try decoder.decode(Conversation.self, from: data)
        
        // Add to conversations if not already present
        if !conversations.contains(where: { $0.id == conversation.id }) {
            conversations.insert(conversation, at: 0)
            pendingChanges = true
        }
        
        return conversation
    }
    
    // MARK: - Private Methods
    
    private func setupAutoSave() {
        // Auto-save every 30 seconds if there are pending changes
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.savePendingChanges()
            }
        }
    }
    
    private func generateConversationTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Chat \(formatter.string(from: Date()))"
    }
    
    private func generateTitleFromMessage(_ content: String) -> String {
        // Take first 50 characters of the message as title
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 50 {
            return trimmed
        }
        
        let index = trimmed.index(trimmed.startIndex, offsetBy: 50)
        return String(trimmed[..<index]) + "..."
    }
    
    private func deleteConversationFiles(_ conversation: Conversation) async {
        // Delete any associated files (e.g., cached images, documents)
        let conversationDir = documentsDirectory
            .appendingPathComponent("conversations")
            .appendingPathComponent(conversation.id)
        
        try? FileManager.default.removeItem(at: conversationDir)
    }
    
    deinit {
        autoSaveTimer?.invalidate()
    }
}

// MARK: - Error Types

enum ChatError: LocalizedError {
    case conversationNotFound
    case messageNotFound
    case saveFailed(Error)
    case loadFailed(Error)
    case exportFailed(Error)
    case importFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .conversationNotFound:
            return "Conversation not found"
        case .messageNotFound:
            return "Message not found"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Failed to export: \(error.localizedDescription)"
        case .importFailed(let error):
            return "Failed to import: \(error.localizedDescription)"
        }
    }
}