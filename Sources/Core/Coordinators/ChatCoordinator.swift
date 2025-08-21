//
//  ChatCoordinator.swift
//  ClaudeCode
//
//  Coordinator for chat-related navigation and flow
//

import SwiftUI
import Combine

/// Coordinator managing chat navigation and flow
@MainActor
final class ChatCoordinator: BaseCoordinator, ObservableObject {
    
    // MARK: - Navigation State
    
    @Published var navigationPath = NavigationPath()
    @Published var selectedConversationId: String?
    @Published var isShowingNewConversation = false
    @Published var isShowingConversationSettings = false
    @Published var isShowingSearch = false
    @Published var isShowingExport = false
    
    // MARK: - Dependencies
    
    weak var appCoordinator: AppCoordinator?
    private let dependencyContainer: DependencyContainer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - View Models
    
    private var chatViewModels: [String: ChatViewModel] = [:]
    
    // MARK: - Initialization
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        super.init()
        observeChatStore()
    }
    
    // MARK: - Setup
    
    private func observeChatStore() {
        // Observe active conversation changes
        dependencyContainer.chatStore.$activeConversationId
            .removeDuplicates()
            .sink { [weak self] conversationId in
                self?.selectedConversationId = conversationId
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Coordinator Lifecycle
    
    override func start() {
        // Load initial conversations
        Task {
            await dependencyContainer.chatStore.loadConversations()
        }
    }
    
    // MARK: - Navigation
    
    func handleTabSelection() {
        // Called when chat tab is selected
        if selectedConversationId == nil {
            // Select most recent conversation or show new conversation
            if let mostRecent = dependencyContainer.chatStore.conversations.first {
                openConversation(id: mostRecent.id)
            } else {
                showNewConversation()
            }
        }
    }
    
    func openConversation(id: String) {
        selectedConversationId = id
        dependencyContainer.chatStore.setActiveConversation(id)
        
        // Navigate to conversation detail if needed
        navigationPath.append(ChatRoute.conversation(id))
    }
    
    func showNewConversation() {
        isShowingNewConversation = true
    }
    
    func createNewConversation(title: String? = nil) {
        isShowingNewConversation = false
        
        Task {
            let conversation = await dependencyContainer.chatStore.createConversation(title: title)
            openConversation(id: conversation.id)
        }
    }
    
    func deleteConversation(id: String) {
        Task {
            await dependencyContainer.chatStore.deleteConversation(id: id)
            
            // If deleted conversation was selected, select another
            if selectedConversationId == id {
                selectedConversationId = nil
                if let first = dependencyContainer.chatStore.conversations.first {
                    openConversation(id: first.id)
                }
            }
        }
    }
    
    // MARK: - Conversation Management
    
    func showConversationSettings(for conversationId: String) {
        isShowingConversationSettings = true
        appCoordinator?.presentSheet(.conversationSettings(conversationId))
    }
    
    func renameConversation(id: String, newTitle: String) {
        Task {
            await dependencyContainer.chatStore.renameConversation(id: id, title: newTitle)
        }
    }
    
    func duplicateConversation(id: String) {
        Task {
            let newConversation = await dependencyContainer.chatStore.duplicateConversation(id: id)
            openConversation(id: newConversation.id)
        }
    }
    
    // MARK: - Search
    
    func showSearch() {
        isShowingSearch = true
        navigationPath.append(ChatRoute.search)
    }
    
    func searchConversations(query: String) -> [Conversation] {
        dependencyContainer.chatStore.searchConversations(query: query)
    }
    
    // MARK: - Export/Import
    
    func showExport() {
        isShowingExport = true
        appCoordinator?.presentSheet(.exportData)
    }
    
    func exportConversation(id: String) async throws -> URL {
        try await dependencyContainer.chatStore.exportConversation(id: id)
    }
    
    func exportAllConversations() async throws -> URL {
        try await dependencyContainer.chatStore.exportAllConversations()
    }
    
    func importConversations(from url: URL) async throws {
        try await dependencyContainer.chatStore.importConversations(from: url)
    }
    
    // MARK: - Tool Execution
    
    func executeTool(toolId: String, in conversationId: String, parameters: [String: Any]) {
        guard let viewModel = getChatViewModel(for: conversationId) else { return }
        
        Task {
            await viewModel.executeTool(toolId: toolId, parameters: parameters)
        }
    }
    
    // MARK: - View Model Management
    
    func getChatViewModel(for conversationId: String) -> ChatViewModel {
        if let existing = chatViewModels[conversationId] {
            return existing
        }
        
        let viewModel = dependencyContainer.makeChatViewModel(conversationId: conversationId)
        chatViewModels[conversationId] = viewModel
        return viewModel
    }
    
    func cleanupViewModel(for conversationId: String) {
        chatViewModels.removeValue(forKey: conversationId)
    }
    
    // MARK: - Error Handling
    
    func handleChatError(_ error: Error) {
        appCoordinator?.showError(error) { [weak self] in
            // Retry logic
            if let conversationId = self?.selectedConversationId,
               let viewModel = self?.getChatViewModel(for: conversationId) {
                Task {
                    await viewModel.retry()
                }
            }
        }
    }
}

// MARK: - Navigation Routes

enum ChatRoute: Hashable {
    case conversation(String)
    case search
    case settings(String)
    case toolExecution(String, String) // toolId, conversationId
}