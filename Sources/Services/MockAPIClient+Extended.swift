import Foundation
import OSLog

// MARK: - Extended Mock Methods for Tasks 401-450
extension MockAPIClient {
    
    // MARK: - Chat Management (Tasks 417-419)
    
    func getChatStatus(sessionId: String) async throws -> ChatStatus {
        logger.info("Mock: Getting chat status for session \(sessionId)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        return ChatStatus(
            sessionId: sessionId,
            status: "active",
            isActive: true,
            messagesCount: Int.random(in: 1...20),
            lastActivity: Date()
        )
    }
    
    func stopChat(sessionId: String) async throws -> Bool {
        logger.info("Mock: Stopping chat for session \(sessionId)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        return true
    }
    
    func debugChat(sessionId: String) async throws -> ChatDebugInfo {
        logger.info("Mock: Getting debug info for session \(sessionId)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        return ChatDebugInfo(
            sessionId: sessionId,
            state: "streaming",
            contextTokens: 1024,
            responseTokens: 256,
            errors: [],
            performance: PerformanceMetrics(
                latency: 125.5,
                throughput: 50.0,
                requestsPerSecond: 10.0
            )
        )
    }
    
    // MARK: - MCP Server Tools (Tasks 420-424)
    
    func listMCPServers() async throws -> [MCPServerInfo] {
        logger.info("Mock: Listing MCP servers")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        return [
            MCPServerInfo(
                id: "mcp-server-1",
                name: "filesystem",
                version: "1.0.0",
                status: "connected",
                capabilities: ["read", "write", "list"],
                toolsCount: 5
            ),
            MCPServerInfo(
                id: "mcp-server-2",
                name: "git",
                version: "1.0.0",
                status: "connected",
                capabilities: ["status", "commit", "diff"],
                toolsCount: 8
            ),
            MCPServerInfo(
                id: "mcp-server-3",
                name: "web-search",
                version: "1.0.0",
                status: "disconnected",
                capabilities: ["search", "fetch"],
                toolsCount: 2
            )
        ]
    }
    
    func getMCPServerTools(serverId: String) async throws -> [ToolInfo] {
        logger.info("Mock: Getting tools for MCP server \(serverId)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        switch serverId {
        case "mcp-server-1":
            return [
                createMockTool(id: "fs-read", name: "read_file", description: "Read file contents"),
                createMockTool(id: "fs-write", name: "write_file", description: "Write file contents"),
                createMockTool(id: "fs-list", name: "list_directory", description: "List directory contents"),
                createMockTool(id: "fs-delete", name: "delete_file", description: "Delete a file"),
                createMockTool(id: "fs-move", name: "move_file", description: "Move or rename a file")
            ]
        case "mcp-server-2":
            return [
                createMockTool(id: "git-status", name: "git_status", description: "Get git status"),
                createMockTool(id: "git-diff", name: "git_diff", description: "Show git diff"),
                createMockTool(id: "git-commit", name: "git_commit", description: "Create git commit"),
                createMockTool(id: "git-push", name: "git_push", description: "Push to remote"),
                createMockTool(id: "git-pull", name: "git_pull", description: "Pull from remote"),
                createMockTool(id: "git-branch", name: "git_branch", description: "Manage branches"),
                createMockTool(id: "git-log", name: "git_log", description: "Show commit history"),
                createMockTool(id: "git-checkout", name: "git_checkout", description: "Checkout branch")
            ]
        case "mcp-server-3":
            return [
                createMockTool(id: "web-search", name: "search_web", description: "Search the web"),
                createMockTool(id: "web-fetch", name: "fetch_url", description: "Fetch URL content")
            ]
        default:
            return []
        }
    }
    
    func updateSessionTools(sessionId: String, toolIds: [String]) async throws -> SessionInfo {
        logger.info("Mock: Updating tools for session \(sessionId)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        guard let session = mockSessions.first(where: { $0.id == sessionId }) else {
            throw APIConfig.APIError.serverError(statusCode: 404, message: "Session not found")
        }
        
        // Return the session with updated metadata
        var updatedSession = session
        updatedSession.updatedAt = Date()
        return updatedSession
    }
    
    func executeMCPTool(_ toolRequest: ToolExecutionRequest) async throws -> ToolExecutionResponse {
        logger.info("Mock: Executing MCP tool \(toolRequest.toolId)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 2 * 1_000_000_000))
        
        // Simulate tool execution based on tool ID
        let mockOutput: [String: Any]
        let executionTime = Double.random(in: 0.1...2.0)
        
        switch toolRequest.toolId {
        case "fs-read":
            mockOutput = [
                "content": "Mock file content for testing",
                "encoding": "utf-8",
                "size": 1024
            ]
        case "git-status":
            mockOutput = [
                "branch": "main",
                "modified": ["file1.swift", "file2.swift"],
                "staged": ["file3.swift"],
                "untracked": ["newfile.swift"]
            ]
        case "web-search":
            mockOutput = [
                "results": [
                    ["title": "Result 1", "url": "https://example.com/1", "snippet": "First result"],
                    ["title": "Result 2", "url": "https://example.com/2", "snippet": "Second result"]
                ],
                "totalResults": 2
            ]
        default:
            mockOutput = ["result": "Mock tool execution successful"]
        }
        
        return ToolExecutionResponse(
            id: UUID().uuidString,
            toolId: toolRequest.toolId,
            status: .success,
            output: mockOutput,
            error: nil,
            executionTime: executionTime,
            timestamp: Date()
        )
    }
    
    func submitToolResult(sessionId: String, toolCallId: String, result: ToolResultEvent) async throws -> Bool {
        logger.info("Mock: Submitting tool result for session \(sessionId), tool call \(toolCallId)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        return true
    }
    
    // MARK: - Usage Tracking (Task 425)
    
    func getUsageStats(startDate: Date? = nil, endDate: Date? = nil) async throws -> UsageStats {
        logger.info("Mock: Getting usage stats")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        return UsageStats(
            totalTokens: Int.random(in: 10000...100000),
            totalCost: Double.random(in: 1.0...100.0),
            sessionsCount: Int.random(in: 10...100),
            averageTokensPerSession: Double.random(in: 100...1000),
            periodStart: startDate ?? Date().addingTimeInterval(-7 * 24 * 3600),
            periodEnd: endDate ?? Date()
        )
    }
    
    func trackUsage(sessionId: String, usage: Usage) async throws -> Bool {
        logger.info("Mock: Tracking usage for session \(sessionId)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        return true
    }
    
    // MARK: - Additional Session/Model Methods (Tasks 412-414)
    
    func getSessionStats(sessionId: String) async throws -> SessionStats {
        logger.info("Mock: Getting stats for session \(sessionId)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        return SessionStats(
            messageCount: Int.random(in: 5...50),
            totalTokens: Int.random(in: 1000...10000),
            inputTokens: Int.random(in: 500...5000),
            outputTokens: Int.random(in: 500...5000),
            totalCost: Double.random(in: 0.01...1.0),
            averageResponseTime: Double.random(in: 100...1000),
            lastActivity: Date()
        )
    }
    
    func getModelCapabilities(modelId: String) async throws -> ModelCapabilities {
        logger.info("Mock: Getting capabilities for model \(modelId)")
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        return ModelCapabilities(
            contextWindow: modelId.contains("opus") ? 200000 : 100000,
            maxOutputTokens: modelId.contains("opus") ? 8192 : 4096,
            supportsFunctions: true,
            supportsVision: modelId.contains("sonnet") || modelId.contains("opus"),
            supportsStreaming: true,
            supportsSystemMessage: true,
            supportsToolUse: true,
            supportedModalities: modelId.contains("haiku") ? ["text"] : ["text", "image"],
            supportedLanguages: ["en", "es", "fr", "de", "ja", "zh", "ko"]
        )
    }
    
    // MARK: - Helper Methods
    
    private func createMockTool(id: String, name: String, description: String) -> ToolInfo {
        return ToolInfo(
            id: id,
            name: name,
            description: description,
            category: "utility",
            version: "1.0.0",
            author: "Mock MCP Server",
            inputSchema: ToolParameters(
                type: "object",
                properties: [
                    "input": PropertySchema(
                        type: "string",
                        description: "Input parameter"
                    )
                ]
            ),
            outputSchema: ToolParameters(
                type: "object",
                properties: [
                    "result": PropertySchema(
                        type: "string",
                        description: "Result output"
                    )
                ]
            ),
            examples: nil,
            isEnabled: true,
            requiredPermissions: nil
        )
    }
}

// MARK: - Enhanced Streaming Support
extension MockAPIClient {
    /// Enhanced streaming with proper chunk types
    func streamChatCompletion(
        request: ChatCompletionRequest,
        onChunk: @escaping (ChatStreamChunk) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        logger.info("Mock: Starting enhanced streaming chat completion")
        isLoading = true
        defer { isLoading = false }
        
        // Generate response content
        let lastUserMessage = request.messages.last { $0.role == .user }
        let responseContent = generateMockResponse(for: lastUserMessage)
        
        // Check if tool use is requested
        let hasTools = request.tools != nil && !request.tools!.isEmpty
        
        if hasTools && Bool.random() {
            // Simulate tool use in streaming
            await simulateToolUseStreaming(
                request: request,
                onChunk: onChunk,
                onComplete: onComplete,
                onError: onError
            )
        } else {
            // Regular text streaming
            await simulateTextStreaming(
                content: responseContent,
                model: request.model,
                onChunk: onChunk,
                onComplete: onComplete
            )
        }
    }
    
    private func simulateToolUseStreaming(
        request: ChatCompletionRequest,
        onChunk: @escaping (ChatStreamChunk) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        let chunkId = "chatcmpl-\(UUID().uuidString)"
        
        // First chunk: tool call
        let toolCall = ToolCall(
            id: "call_\(UUID().uuidString)",
            type: .function,
            function: ToolCall.FunctionCall(
                name: request.tools?.first?.function.name ?? "mock_tool",
                arguments: "{\"input\": \"test\"}"
            )
        )
        
        let toolChunk = ChatStreamChunk(
            id: chunkId,
            object: "chat.completion.chunk",
            created: Int(Date().timeIntervalSince1970),
            model: request.model,
            choices: [
                ChatStreamChunk.StreamChoice(
                    index: 0,
                    delta: ChatStreamChunk.StreamDelta(
                        role: "assistant",
                        content: nil,
                        toolCalls: [toolCall]
                    ),
                    finishReason: nil
                )
            ]
        )
        
        onChunk(toolChunk)
        
        // Simulate delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Final chunk
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
                    finishReason: "tool_calls"
                )
            ]
        )
        
        onChunk(finalChunk)
        onComplete()
    }
    
    private func simulateTextStreaming(
        content: String,
        model: String,
        onChunk: @escaping (ChatStreamChunk) -> Void,
        onComplete: @escaping () -> Void
    ) async {
        let words = content.split(separator: " ")
        let chunkId = "chatcmpl-\(UUID().uuidString)"
        
        for (index, word) in words.enumerated() {
            let chunkContent = index == 0 ? String(word) : " " + String(word)
            let delay = Double(chunkContent.count) / streamingSpeed
            
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            let chunk = ChatStreamChunk(
                id: chunkId,
                object: "chat.completion.chunk",
                created: Int(Date().timeIntervalSince1970),
                model: model,
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
            model: model,
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
}