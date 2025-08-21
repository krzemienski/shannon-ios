import Foundation
import OSLog

/// Mock API client for testing without backend (Task 332)
/// Provides realistic responses and simulated streaming for development
@MainActor
class MockAPIClient: ObservableObject {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "MockAPIClient")
    @Published var isLoading = false
    @Published var lastError: APIConfig.APIError?
    
    // Simulated network delay
    private let mockDelay: TimeInterval = 0.5
    
    // Simulated streaming speed (characters per second)
    private let streamingSpeed: Double = 30.0
    
    // MARK: - Initialization
    
    init() {
        logger.info("MockAPIClient initialized - Backend simulation mode")
    }
    
    // MARK: - Health Check
    
    func checkHealth() async -> Bool {
        logger.info("Mock: Health check - always returns true")
        try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        return true
    }
    
    // MARK: - Models API
    
    func fetchModels() async throws -> [APIModel] {
        logger.info("Mock: Fetching models")
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        return [
            APIModel(
                id: "claude-sonnet-4",
                object: "model",
                created: Int(Date().timeIntervalSince1970),
                ownedBy: "anthropic",
                capabilities: ModelCapabilities(
                    contextWindow: 200000,
                    maxOutputTokens: 8192,
                    supportsFunctions: true,
                    supportsVision: true,
                    supportsStreaming: true,
                    supportsSystemMessage: true,
                    supportsToolUse: true,
                    supportedModalities: ["text", "image"]
                ),
                pricing: ModelPricing(
                    promptTokenPrice: 0.003,
                    completionTokenPrice: 0.015,
                    currency: "USD"
                )
            ),
            APIModel(
                id: "claude-opus-4",
                object: "model",
                created: Int(Date().timeIntervalSince1970),
                ownedBy: "anthropic",
                capabilities: ModelCapabilities(
                    contextWindow: 200000,
                    maxOutputTokens: 8192,
                    supportsFunctions: true,
                    supportsVision: true,
                    supportsStreaming: true,
                    supportsSystemMessage: true,
                    supportsToolUse: true,
                    supportedModalities: ["text", "image"]
                ),
                pricing: ModelPricing(
                    promptTokenPrice: 0.015,
                    completionTokenPrice: 0.075,
                    currency: "USD"
                )
            ),
            APIModel(
                id: "claude-3-5-haiku",
                object: "model",
                created: Int(Date().timeIntervalSince1970),
                ownedBy: "anthropic",
                capabilities: ModelCapabilities(
                    contextWindow: 100000,
                    maxOutputTokens: 4096,
                    supportsFunctions: false,
                    supportsVision: false,
                    supportsStreaming: true,
                    supportsSystemMessage: true,
                    supportsToolUse: false,
                    supportedModalities: ["text"]
                ),
                pricing: ModelPricing(
                    promptTokenPrice: 0.001,
                    completionTokenPrice: 0.005,
                    currency: "USD"
                )
            )
        ]
    }
    
    // MARK: - Chat Completion
    
    func createChatCompletion(request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        logger.info("Mock: Creating chat completion")
        isLoading = true
        defer { isLoading = false }
        
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 2 * 1_000_000_000))
        
        // Generate mock response based on last user message
        let lastUserMessage = request.messages.last { $0.role == .user }
        let responseContent = generateMockResponse(for: lastUserMessage)
        
        return ChatCompletionResponse(
            id: "chatcmpl-\(UUID().uuidString)",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: request.model,
            choices: [
                ChatChoice(
                    index: 0,
                    message: ChatMessage(
                        role: .assistant,
                        content: .text(responseContent)
                    ),
                    logprobs: nil,
                    finishReason: "stop"
                )
            ],
            usage: Usage(
                promptTokens: calculateTokens(for: request.messages),
                completionTokens: calculateTokens(for: responseContent),
                totalTokens: calculateTokens(for: request.messages) + calculateTokens(for: responseContent)
            ),
            systemFingerprint: "mock-\(UUID().uuidString)"
        )
    }
    
    // MARK: - Streaming Chat
    
    func streamChat(
        request: ChatCompletionRequest,
        onChunk: @escaping (ChatStreamChunk) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        logger.info("Mock: Starting streaming chat")
        isLoading = true
        defer { isLoading = false }
        
        // Generate response content
        let lastUserMessage = request.messages.last { $0.role == .user }
        let responseContent = generateMockResponse(for: lastUserMessage)
        
        // Simulate streaming by sending chunks
        let words = responseContent.split(separator: " ")
        let chunkId = "chatcmpl-\(UUID().uuidString)"
        
        for (index, word) in words.enumerated() {
            // Calculate delay based on streaming speed
            let chunkContent = index == 0 ? String(word) : " " + String(word)
            let delay = Double(chunkContent.count) / streamingSpeed
            
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            let chunk = ChatStreamChunk(
                id: chunkId,
                object: "chat.completion.chunk",
                created: Int(Date().timeIntervalSince1970),
                model: request.model,
                choices: [
                    ChatStreamChunk.StreamChoice(
                        index: 0,
                        delta: ChatStreamChunk.StreamDelta(
                            role: index == 0 ? "assistant" : nil,
                            content: chunkContent,
                            toolCalls: nil
                        ),
                        finishReason: nil
                    )
                ]
            )
            
            onChunk(chunk)
        }
        
        // Send final chunk
        let finalChunk = ChatStreamChunk(
            id: chunkId,
            object: "chat.completion.chunk",
            created: Int(Date().timeIntervalSince1970),
            model: request.model,
            choices: [
                ChatStreamChunk.StreamChoice(
                    index: 0,
                    delta: ChatStreamChunk.StreamDelta(
                        role: nil,
                        content: nil,
                        toolCalls: nil
                    ),
                    finishReason: "stop"
                )
            ]
        )
        
        onChunk(finalChunk)
        onComplete()
    }
    
    // MARK: - Session Management
    
    private var mockSessions: [SessionInfo] = []
    
    func listSessions() async throws -> [SessionInfo] {
        logger.info("Mock: Listing sessions")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if mockSessions.isEmpty {
            // Create some default sessions
            mockSessions = [
                SessionInfo(
                    id: UUID().uuidString,
                    name: "Welcome Session",
                    messages: [
                        ChatMessage(role: .system, content: "You are Claude, a helpful AI assistant."),
                        ChatMessage(role: .user, content: "Hello! Can you help me get started?"),
                        ChatMessage(role: .assistant, content: "Hello! I'd be happy to help you get started with Claude Code. This is a mock session for testing. What would you like to know?")
                    ],
                    metadata: SessionMetadata(
                        model: "claude-sonnet-4",
                        temperature: 0.7,
                        maxTokens: 2048
                    ),
                    stats: SessionStats(
                        messageCount: 3,
                        totalTokens: 50,
                        inputTokens: 20,
                        outputTokens: 30,
                        totalCost: 0.0002
                    ),
                    isPinned: true
                ),
                SessionInfo(
                    id: UUID().uuidString,
                    name: "Code Review Session",
                    messages: [
                        ChatMessage(role: .system, content: "You are an expert code reviewer."),
                        ChatMessage(role: .user, content: "Can you review this Swift code?"),
                        ChatMessage(role: .assistant, content: "I'd be happy to review your Swift code. Please share the code you'd like me to analyze.")
                    ],
                    metadata: SessionMetadata(
                        model: "claude-opus-4",
                        temperature: 0.3
                    ),
                    stats: SessionStats(
                        messageCount: 3,
                        totalTokens: 35,
                        inputTokens: 15,
                        outputTokens: 20,
                        totalCost: 0.0001
                    )
                )
            ]
        }
        
        return mockSessions
    }
    
    func getSession(id: String) async throws -> SessionInfo {
        logger.info("Mock: Getting session \(id)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        guard let session = mockSessions.first(where: { $0.id == id }) else {
            throw APIConfig.APIError.serverError(statusCode: 404, message: "Session not found")
        }
        
        return session
    }
    
    func createSession(_ request: CreateSessionRequest) async throws -> SessionInfo {
        logger.info("Mock: Creating session")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        let newSession = SessionInfo(
            id: UUID().uuidString,
            name: request.name,
            projectId: request.projectId,
            messages: [],
            metadata: request.metadata
        )
        
        mockSessions.append(newSession)
        return newSession
    }
    
    func updateSession(id: String, request: CreateSessionRequest) async throws -> SessionInfo {
        logger.info("Mock: Updating session \(id)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        guard let index = mockSessions.firstIndex(where: { $0.id == id }) else {
            throw APIConfig.APIError.serverError(statusCode: 404, message: "Session not found")
        }
        
        mockSessions[index].name = request.name
        if let projectId = request.projectId {
            mockSessions[index].projectId = projectId
        }
        if let metadata = request.metadata {
            mockSessions[index].metadata = metadata
        }
        mockSessions[index].updatedAt = Date()
        
        return mockSessions[index]
    }
    
    func deleteSession(id: String) async throws -> Bool {
        logger.info("Mock: Deleting session \(id)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        mockSessions.removeAll { $0.id == id }
        return true
    }
    
    // MARK: - Helper Methods
    
    private func generateMockResponse(for message: ChatMessage?) -> String {
        guard let message = message else {
            return "I'm ready to help! This is a mock response from the simulated backend."
        }
        
        let messageText: String
        switch message.content {
        case .text(let text):
            messageText = text
        case .array(let parts):
            messageText = parts.compactMap { $0.text }.joined(separator: " ")
        case .none:
            messageText = ""
        }
        
        // Generate contextual responses based on keywords
        let lowercased = messageText.lowercased()
        
        if lowercased.contains("hello") || lowercased.contains("hi") {
            return "Hello! I'm Claude, your AI assistant. This is a mock response for testing. How can I help you today?"
        } else if lowercased.contains("code") || lowercased.contains("programming") {
            return "I'd be happy to help with coding! I can assist with Swift, iOS development, and many other programming languages. This is a mock response demonstrating the streaming capability."
        } else if lowercased.contains("test") {
            return "This is a test response from the mock API client. The streaming functionality is working correctly, and you're seeing this message being delivered chunk by chunk to simulate real API behavior."
        } else if lowercased.contains("help") {
            return "I'm here to help! I can assist with:\n• Code writing and review\n• Debugging and problem-solving\n• Documentation and explanations\n• Architecture and design decisions\n\nThis is a mock response for testing purposes."
        } else {
            return "I understand you're asking about: \"\(messageText)\". This is a mock response generated for testing. In a real scenario, I would provide a detailed and helpful response based on your query."
        }
    }
    
    private func calculateTokens(for messages: [ChatMessage]) -> Int {
        // Simple token estimation (4 characters = 1 token)
        var totalChars = 0
        for message in messages {
            switch message.content {
            case .text(let text):
                totalChars += text.count
            case .array(let parts):
                totalChars += parts.compactMap { $0.text?.count }.reduce(0, +)
            case .none:
                break
            }
        }
        return totalChars / 4
    }
    
    private func calculateTokens(for text: String) -> Int {
        return text.count / 4
    }
}

// MARK: - Mock SSE Client for Testing

class MockSSEClient {
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "MockSSEClient")
    
    func simulateStreaming(
        response: String,
        onMessage: @escaping (SSEMessage) -> Void,
        onComplete: @escaping () -> Void
    ) async {
        logger.info("Mock SSE: Starting simulated streaming")
        
        // Split response into words for chunking
        let words = response.split(separator: " ")
        let chunkId = "mock-stream-\(UUID().uuidString)"
        
        for (index, word) in words.enumerated() {
            let content = index == 0 ? String(word) : " " + String(word)
            
            // Create SSE message
            let messageData = """
            {"id":"\(chunkId)","object":"chat.completion.chunk","created":\(Int(Date().timeIntervalSince1970)),"model":"claude-sonnet-4","choices":[{"index":0,"delta":{"content":"\(content)"},"finish_reason":null}]}
            """
            
            let message = SSEMessage(
                id: UUID().uuidString,
                event: "message",
                data: messageData,
                retry: nil
            )
            
            // Simulate network delay
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms per chunk
            
            onMessage(message)
        }
        
        // Send completion signal
        let doneMessage = SSEMessage(
            id: nil,
            event: "message",
            data: "[DONE]",
            retry: nil
        )
        
        onMessage(doneMessage)
        onComplete()
    }
}