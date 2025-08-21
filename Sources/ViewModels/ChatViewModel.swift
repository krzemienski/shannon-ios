//
//  ChatViewModel.swift
//  ClaudeCode
//
//  ViewModel for chat interface with MVVM pattern
//

import SwiftUI
import Combine

/// ViewModel for managing chat interactions
@MainActor
final class ChatViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var conversation: Conversation?
    @Published var messages: [Message] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var isStreaming = false
    @Published var error: Error?
    @Published var showError = false
    @Published var selectedMessage: Message?
    @Published var showToolDetails = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Stream Management
    
    @Published var streamingMessageId: String?
    @Published var streamingContent = ""
    
    // MARK: - UI State
    
    @Published var shouldScrollToBottom = false
    @Published var showModelPicker = false
    @Published var showSettings = false
    @Published var isComposing = false
    
    // MARK: - Private Properties
    
    private let chatStore: ChatStore
    private let apiClient: APIClient
    private let appState: AppState
    private var sseClient: SSEClient?
    private var cancellables = Set<AnyCancellable>()
    private let conversationId: String?
    
    // MARK: - Computed Properties
    
    var canSendMessage: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isLoading &&
        connectionStatus == .connected
    }
    
    var currentModel: String {
        conversation?.metadata?.defaultModel ?? appState.currentModel
    }
    
    var hasMessages: Bool {
        !messages.isEmpty
    }
    
    // MARK: - Initialization
    
    init(conversationId: String? = nil,
         chatStore: ChatStore,
         apiClient: APIClient,
         appState: AppState) {
        self.conversationId = conversationId
        self.chatStore = chatStore
        self.apiClient = apiClient
        self.appState = appState
        
        setupBindings()
        loadConversation()
        checkConnection()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe app state changes
        appState.$isConnected
            .sink { [weak self] isConnected in
                self?.connectionStatus = isConnected ? .connected : .disconnected
            }
            .store(in: &cancellables)
        
        // Observe current conversation changes
        chatStore.$currentConversation
            .sink { [weak self] conversation in
                if conversation?.id == self?.conversationId {
                    self?.conversation = conversation
                    self?.messages = conversation?.messages ?? []
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadConversation() {
        if let conversationId = conversationId {
            conversation = chatStore.conversations.first { $0.id == conversationId }
            messages = conversation?.messages ?? []
        } else if let current = chatStore.currentConversation {
            conversation = current
            messages = current.messages
        }
    }
    
    private func checkConnection() {
        Task {
            connectionStatus = .connecting
            let isHealthy = await apiClient.checkHealth()
            connectionStatus = isHealthy ? .connected : .disconnected
        }
    }
    
    // MARK: - Public Methods - Messaging
    
    /// Send a message to the API
    func sendMessage() {
        guard canSendMessage else { return }
        
        let messageContent = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        
        // Create user message
        let userMessage = Message(
            role: .user,
            content: messageContent
        )
        
        // Add to conversation
        addMessage(userMessage)
        
        // Send to API
        Task {
            await sendToAPI(userMessage: userMessage)
        }
    }
    
    /// Resend a message
    func resendMessage(_ message: Message) {
        Task {
            // Remove any error messages after this one
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                let messagesToRemove = messages[(index + 1)...]
                    .filter { $0.role == .assistant || $0.role == .error }
                
                for msg in messagesToRemove {
                    deleteMessage(msg)
                }
            }
            
            // Resend
            await sendToAPI(userMessage: message)
        }
    }
    
    /// Stop streaming response
    func stopStreaming() {
        sseClient?.disconnect()
        isStreaming = false
        
        // Finalize the streaming message
        if let messageId = streamingMessageId,
           !streamingContent.isEmpty {
            updateMessage(id: messageId, content: streamingContent)
            streamingMessageId = nil
            streamingContent = ""
        }
    }
    
    /// Clear the current conversation
    func clearConversation() {
        messages.removeAll()
        conversation = nil
        chatStore.currentConversation = nil
        error = nil
        showError = false
    }
    
    /// Start a new conversation
    func startNewConversation() {
        let newConversation = chatStore.createConversation()
        conversation = newConversation
        messages = []
        error = nil
        showError = false
    }
    
    // MARK: - Public Methods - Message Management
    
    /// Add a message to the conversation
    func addMessage(_ message: Message) {
        messages.append(message)
        
        if let conversation = conversation {
            chatStore.addMessageToConversation(message, conversation: conversation)
        } else {
            // Create new conversation if needed
            let newConversation = chatStore.createConversation()
            conversation = newConversation
            chatStore.addMessageToConversation(message, conversation: newConversation)
        }
        
        shouldScrollToBottom = true
    }
    
    /// Update a message
    func updateMessage(id: String, content: String) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].content = content
            chatStore.updateMessage(id: id, content: content)
        }
    }
    
    /// Delete a message
    func deleteMessage(_ message: Message) {
        messages.removeAll { $0.id == message.id }
        chatStore.deleteMessage(message)
    }
    
    /// Copy message content
    func copyMessage(_ message: Message) {
        UIPasteboard.general.string = message.content
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Private Methods - API Communication
    
    private func sendToAPI(userMessage: Message) async {
        isLoading = true
        error = nil
        showError = false
        
        do {
            // Prepare messages for API
            let apiMessages = prepareMessagesForAPI()
            
            // Check if streaming is enabled
            let settingsStore = DependencyContainer.shared.settingsStore
            
            if settingsStore.streamResponses {
                // Create streaming response
                await startStreamingResponse(messages: apiMessages)
            } else {
                // Create regular response
                let response = try await apiClient.createChatCompletion(
                    request: ChatCompletionRequest(
                        model: currentModel,
                        messages: apiMessages,
                        temperature: settingsStore.temperature,
                        maxTokens: settingsStore.maxTokens,
                        stream: false
                    )
                )
                
                // Add assistant message
                if let choice = response.choices.first {
                    let assistantMessage = Message(
                        role: .assistant,
                        content: choice.message.content,
                        metadata: MessageMetadata(
                            model: response.model,
                            usage: response.usage.map { TokenUsage(
                                promptTokens: $0.promptTokens,
                                completionTokens: $0.completionTokens,
                                totalTokens: $0.totalTokens,
                                cachedTokens: $0.cachedTokens
                            )}
                        )
                    )
                    addMessage(assistantMessage)
                }
            }
        } catch let apiError as APIConfig.APIError {
            handleAPIError(apiError)
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    private func startStreamingResponse(messages: [ChatMessage]) async {
        isStreaming = true
        streamingContent = ""
        
        // Create assistant message placeholder
        let assistantMessage = Message(
            role: .assistant,
            content: "",
            isStreaming: true
        )
        addMessage(assistantMessage)
        streamingMessageId = assistantMessage.id
        
        // Start SSE streaming
        let settingsStore = DependencyContainer.shared.settingsStore
        let request = ChatCompletionRequest(
            model: currentModel,
            messages: messages,
            temperature: settingsStore.temperature,
            maxTokens: settingsStore.maxTokens,
            stream: true
        )
        
        // TODO: Implement SSE streaming
        // For now, simulate with a regular request
        isStreaming = false
        
        do {
            let response = try await apiClient.createChatCompletion(request: request)
            if let choice = response.choices.first {
                updateMessage(id: assistantMessage.id, content: choice.message.content)
            }
        } catch {
            handleError(error)
        }
        
        streamingMessageId = nil
        isStreaming = false
    }
    
    private func prepareMessagesForAPI() -> [ChatMessage] {
        var apiMessages: [ChatMessage] = []
        
        // Add system prompt if available
        if let systemPrompt = conversation?.metadata?.systemPrompt {
            apiMessages.append(ChatMessage(role: "system", content: systemPrompt))
        }
        
        // Add conversation messages
        for message in messages {
            if message.role != .error {
                apiMessages.append(ChatMessage(
                    role: message.role == .user ? "user" : "assistant",
                    content: message.content
                ))
            }
        }
        
        return apiMessages
    }
    
    // MARK: - Error Handling
    
    private func handleAPIError(_ apiError: APIConfig.APIError) {
        let errorMessage: String
        
        switch apiError {
        case .backendNotRunning:
            errorMessage = "Backend server is not running. Please start the server and try again."
        case .unauthorized:
            errorMessage = "Invalid API key. Please check your settings."
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                errorMessage = "Rate limited. Please wait \(Int(retryAfter)) seconds."
            } else {
                errorMessage = "Rate limited. Please wait a moment and try again."
            }
        case .networkError(let error):
            errorMessage = "Network error: \(error.localizedDescription)"
        case .serverError(_, let message):
            errorMessage = message ?? "Server error occurred"
        case .decodingError:
            errorMessage = "Failed to process server response"
        case .invalidRequest(let message):
            errorMessage = message
        }
        
        // Add error message to conversation
        let errorMsg = Message(
            role: .error,
            content: errorMessage
        )
        addMessage(errorMsg)
        
        error = apiError
        showError = true
    }
    
    private func handleError(_ error: Error) {
        let errorMsg = Message(
            role: .error,
            content: "An error occurred: \(error.localizedDescription)"
        )
        addMessage(errorMsg)
        
        self.error = error
        showError = true
    }
}

// MARK: - Supporting Types

enum ConnectionStatus {
    case connected
    case connecting
    case disconnected
    
    var color: Color {
        switch self {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .red
        }
    }
    
    var text: String {
        switch self {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        }
    }
}

// MARK: - API Request/Response Types

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case stream
    }
}

struct ChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let index: Int
        let message: ChatMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        let cachedTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
            case cachedTokens = "cached_tokens"
        }
    }
}