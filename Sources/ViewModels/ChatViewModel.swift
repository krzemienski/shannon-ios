//
//  ChatViewModel.swift
//  ClaudeCode
//
//  ViewModel for chat interface with MVVM pattern
//

import SwiftUI
import Combine
import OSLog

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
    // private var streamingService: StreamingChatService? // TODO: Implement StreamingChatService
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "ChatViewModel")
    private let conversationId: String?
    private let webSocketService = WebSocketService.shared
    
    // Performance optimizations
    private let messageDebouncer = Debouncer(delay: 0.5)
    private let scrollDebouncer = Debouncer(delay: 0.3)
    private var messageCache = LRUCache<String, Message>(maxSize: 100)
    
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
        
        // Observe WebSocket chat updates
        webSocketService.chatUpdates
            .sink { [weak self] event in
                self?.handleWebSocketChatUpdate(event)
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
        // Stop SSE client if using direct SSE
        sseClient?.disconnect()
        
        // Stop streaming service if using it
        streamingService?.stopStreaming()
        
        isStreaming = false
        
        // Finalize the streaming message
        if let messageId = streamingMessageId,
           !streamingContent.isEmpty {
            updateMessage(id: messageId, content: streamingContent)
            
            // Mark message as no longer streaming
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].isStreaming = false
            }
            
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
        
        // Initialize streaming service if needed
        if streamingService == nil {
            let settingsStore = DependencyContainer.shared.settingsStore
            streamingService = StreamingChatService(
                baseURL: settingsStore.apiBaseURL ?? APIConfig.defaultBaseURL,
                apiKey: settingsStore.apiKey
            )
        }
        
        // Prepare request
        let settingsStore = DependencyContainer.shared.settingsStore
        let request = ChatCompletionRequest(
            model: currentModel,
            messages: messages,
            temperature: settingsStore.temperature,
            maxTokens: settingsStore.maxTokens,
            stream: true
        )
        
        // Start streaming with the new service
        await streamingService?.startStreaming(
            request: request,
            onToken: { [weak self] token in
                guard let self = self else { return }
                
                Task { @MainActor in
                    // Accumulate content token by token
                    self.streamingContent += token
                    
                    // Update the message with accumulated content
                    if let messageId = self.streamingMessageId {
                        self.updateMessage(id: messageId, content: self.streamingContent)
                        
                        // Trigger scroll to bottom for new content
                        self.shouldScrollToBottom = true
                    }
                }
            },
            onComplete: { [weak self] metrics in
                guard let self = self else { return }
                
                Task { @MainActor in
                    // Finalize the streaming message
                    if let messageId = self.streamingMessageId {
                        // Mark message as no longer streaming
                        if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                            self.messages[index].isStreaming = false
                            
                            // Add usage metadata if available
                            self.messages[index].metadata = MessageMetadata(
                                model: self.currentModel,
                                usage: TokenUsage(
                                    promptTokens: 0,  // Will be updated from backend
                                    completionTokens: metrics.tokensReceived,
                                    totalTokens: metrics.tokensReceived,
                                    cachedTokens: nil
                                )
                            )
                        }
                    }
                    
                    // Log streaming metrics
                    self.logger.info("""
                        Streaming completed:
                        - Duration: \(metrics.totalDuration)s
                        - Tokens: \(metrics.tokensReceived)
                        - Time to first token: \(metrics.timeToFirstToken)s
                        - Success: \(metrics.success)
                    """)
                    
                    self.streamingMessageId = nil
                    self.streamingContent = ""
                    self.isStreaming = false
                    self.isLoading = false
                }
            }
        )
        
        // Handle errors from streaming service
        if let streamingError = streamingService?.error {
            handleError(streamingError)
            streamingMessageId = nil
            streamingContent = ""
            isStreaming = false
            isLoading = false
        }
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
    
    // MARK: - Performance Optimization Methods
    
    /// Preload message content for smooth scrolling
    func preloadMessageContent(_ message: Message) {
        // Cache message in LRU cache
        messageCache[message.id] = message
        
        // Preload any images or resources in the message
        if let imageURLs = extractImageURLs(from: message.content) {
            Task {
                for url in imageURLs {
                    _ = try? await ImageCache.shared.loadThumbnail(from: url)
                }
            }
        }
    }
    
    /// Clean up message resources when out of view
    func cleanupMessageResources(_ message: Message) {
        // Keep recent messages in cache, remove very old ones
        if messages.count > 100 {
            // Remove from cache if message is old and not visible
            if let index = messages.firstIndex(where: { $0.id == message.id }),
               index < messages.count - 50 {
                messageCache.remove(message.id)
            }
        }
    }
    
    private func extractImageURLs(from content: String) -> [URL]? {
        // Simple regex to find image URLs in markdown
        let pattern = #"!\[.*?\]\((https?://[^\s)]+)\)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: content, range: NSRange(content.startIndex..., in: content))
        
        return matches?.compactMap { match in
            guard let range = Range(match.range(at: 1), in: content) else { return nil }
            return URL(string: String(content[range]))
        }
    }
    
    // MARK: - Error Handling
    
    private func handleAPIError(_ apiError: APIError) {
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
    
    // MARK: - WebSocket Handling
    
    private func handleWebSocketChatUpdate(_ event: ChatUpdateEvent) {
        guard let conversationId = conversationId,
              event.chatId == conversationId else { return }
        
        switch event.action {
        case .messageAdded:
            if let messageData = event.data,
               let messageId = event.messageId {
                handleIncomingMessage(
                    id: messageId,
                    content: messageData.content ?? "",
                    role: messageData.role ?? "assistant"
                )
            }
            
        case .messageUpdated:
            if let messageId = event.messageId,
               let messageData = event.data {
                updateExistingMessage(
                    id: messageId,
                    content: messageData.content ?? ""
                )
            }
            
        case .streamStarted:
            if let messageId = event.messageId {
                streamingMessageId = messageId
                isStreaming = true
                streamingContent = ""
            }
            
        case .streamEnded:
            if let messageId = event.messageId,
               messageId == streamingMessageId {
                finalizeStreamingMessage()
            }
        }
    }
    
    private func handleIncomingMessage(id: String, content: String, role: String) {
        let messageRole: MessageRole
        switch role {
        case "assistant":
            messageRole = .assistant
        case "user":
            messageRole = .user
        case "system":
            messageRole = .system
        default:
            messageRole = .assistant
        }
        
        let message = Message(
            id: id,
            role: messageRole,
            content: content,
            timestamp: Date(),
            isStreaming: false
        )
        
        // Check if message already exists
        if !messages.contains(where: { $0.id == id }) {
            addMessage(message)
        }
    }
    
    private func updateExistingMessage(id: String, content: String) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].content = content
            
            // If this is the streaming message, update streaming content
            if id == streamingMessageId {
                streamingContent = content
            }
        }
    }
    
    private func finalizeStreamingMessage() {
        guard let messageId = streamingMessageId else { return }
        
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].isStreaming = false
        }
        
        streamingMessageId = nil
        isStreaming = false
        streamingContent = ""
    }
    
    /// Subscribe to WebSocket updates for this chat
    func subscribeToWebSocketUpdates() {
        guard let conversationId = conversationId else { return }
        
        Task {
            await appState.subscribeToChat(conversationId)
        }
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
// Using types from NetworkModels.swift