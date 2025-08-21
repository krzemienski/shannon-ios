import Foundation
import OSLog

// MARK: - Task 404-405, 415-416: Streaming Chat Completion
extension APIClient {
    /// Stream chat completion with Server-Sent Events
    /// Task 404: Implement /v1/chat/completions POST method
    /// Task 405: Create streaming chat completion handler
    /// Task 415: Implement chat completion streaming
    public func streamChatCompletion(
        request: ChatCompletionRequest,
        onChunk: @escaping (ChatStreamChunk) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        logger.info("Starting streaming chat completion")
        
        // Ensure stream flag is set
        var streamRequest = request
        streamRequest.stream = true
        
        // Create SSE client for streaming
        let sseClient = SSEClient(configuration: SSEConfiguration(
            reconnectTime: 3.0,
            maxReconnectAttempts: 3,
            heartbeatInterval: 30.0
        ))
        
        // Setup callbacks
        sseClient.onMessage = { message in
            Task { @MainActor in
                self.handleSSEMessage(message, onChunk: onChunk, onComplete: onComplete)
            }
        }
        
        sseClient.onError = { error in
            Task { @MainActor in
                self.logger.error("SSE streaming error: \(error.localizedDescription)")
                onError(error)
            }
        }
        
        sseClient.onComplete = {
            Task { @MainActor in
                self.logger.info("SSE streaming completed")
                onComplete()
            }
        }
        
        // Build request
        guard let url = URL(string: "\(configuration.baseURL)/chat/completions") else {
            onError(APIConfig.APIError.invalidURL)
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        if let apiKey = configuration.apiKey {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(streamRequest)
            
            // Connect SSE client
            await sseClient.connect(request: urlRequest)
        } catch {
            logger.error("Failed to encode streaming request: \(error)")
            onError(error)
        }
    }
    
    /// Handle SSE message for chat streaming
    private func handleSSEMessage(
        _ message: SSEMessage,
        onChunk: @escaping (ChatStreamChunk) -> Void,
        onComplete: @escaping () -> Void
    ) {
        // Check for [DONE] signal
        if message.data == "[DONE]" {
            onComplete()
            return
        }
        
        // Parse chunk data
        guard let data = message.data.data(using: .utf8) else {
            logger.warning("Invalid SSE data encoding")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let chunk = try decoder.decode(ChatStreamChunk.self, from: data)
            onChunk(chunk)
        } catch {
            logger.error("Failed to decode chat chunk: \(error)")
        }
    }
}

// MARK: - Tasks 417-419: Chat Management
extension APIClient {
    /// Task 417: Implement getChatStatus method
    public func getChatStatus(sessionId: String) async throws -> ChatStatus {
        let endpoint = "/chat/status/\(sessionId)"
        return try await request(
            endpoint: endpoint,
            method: .GET,
            responseType: ChatStatus.self
        )
    }
    
    /// Task 418: Create stopChat method
    public func stopChat(sessionId: String) async throws -> Bool {
        let endpoint = "/chat/stop/\(sessionId)"
        let response: GenericResponse = try await request(
            endpoint: endpoint,
            method: .POST,
            responseType: GenericResponse.self
        )
        return response.success
    }
    
    /// Task 419: Implement debugChat method
    public func debugChat(sessionId: String) async throws -> ChatDebugInfo {
        let endpoint = "/chat/debug/\(sessionId)"
        return try await request(
            endpoint: endpoint,
            method: .GET,
            responseType: ChatDebugInfo.self
        )
    }
}

// MARK: - Tasks 420-424: MCP Server Tools
extension APIClient {
    /// Task 420: Create listMCPServers method
    public func listMCPServers() async throws -> [MCPServerInfo] {
        let endpoint = "/mcp/servers"
        let response: MCPServersResponse = try await request(
            endpoint: endpoint,
            method: .GET,
            responseType: MCPServersResponse.self
        )
        return response.servers
    }
    
    /// Task 421: Implement getMCPServerTools method
    public func getMCPServerTools(serverId: String) async throws -> [ToolInfo] {
        let endpoint = "/mcp/servers/\(serverId)/tools"
        let response: ToolsResponse = try await request(
            endpoint: endpoint,
            method: .GET,
            responseType: ToolsResponse.self
        )
        return response.tools
    }
    
    /// Task 422: Create updateSessionTools method
    public func updateSessionTools(sessionId: String, toolIds: [String]) async throws -> SessionInfo {
        let endpoint = "/sessions/\(sessionId)/tools"
        let body = UpdateToolsRequest(toolIds: toolIds)
        
        return try await request(
            endpoint: endpoint,
            method: .PUT,
            body: body,
            responseType: SessionInfo.self
        )
    }
    
    /// Task 423: Implement tool execution endpoint
    public func executeMCPTool(_ toolRequest: ToolExecutionRequest) async throws -> ToolExecutionResponse {
        let endpoint = "/mcp/tools/execute"
        return try await request(
            endpoint: endpoint,
            method: .POST,
            body: toolRequest,
            responseType: ToolExecutionResponse.self
        )
    }
    
    /// Task 424: Create tool result submission
    public func submitToolResult(sessionId: String, toolCallId: String, result: ToolResultEvent) async throws -> Bool {
        let endpoint = "/sessions/\(sessionId)/tools/\(toolCallId)/result"
        let response: GenericResponse = try await request(
            endpoint: endpoint,
            method: .POST,
            body: result,
            responseType: GenericResponse.self
        )
        return response.success
    }
}

// MARK: - Task 425: Usage Tracking
extension APIClient {
    /// Task 425: Implement usage tracking endpoint
    public func getUsageStats(startDate: Date? = nil, endDate: Date? = nil) async throws -> UsageStats {
        var endpoint = "/usage/stats"
        var queryItems: [URLQueryItem] = []
        
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: ISO8601DateFormatter().string(from: startDate)))
        }
        
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: ISO8601DateFormatter().string(from: endDate)))
        }
        
        if !queryItems.isEmpty {
            var components = URLComponents()
            components.queryItems = queryItems
            if let query = components.query {
                endpoint += "?\(query)"
            }
        }
        
        return try await request(
            endpoint: endpoint,
            method: .GET,
            responseType: UsageStats.self
        )
    }
    
    /// Track API usage for a specific session
    public func trackUsage(sessionId: String, usage: Usage) async throws -> Bool {
        let endpoint = "/usage/track"
        let body = UsageTrackingRequest(sessionId: sessionId, usage: usage)
        
        let response: GenericResponse = try await request(
            endpoint: endpoint,
            method: .POST,
            body: body,
            responseType: GenericResponse.self
        )
        return response.success
    }
}

// MARK: - Task 412-414: Additional Session/Model Methods
extension APIClient {
    /// Task 412: Create getSessionStats method
    public func getSessionStats(sessionId: String) async throws -> SessionStats {
        let endpoint = "/sessions/\(sessionId)/stats"
        return try await request(
            endpoint: endpoint,
            method: .GET,
            responseType: SessionStats.self
        )
    }
    
    /// Task 414: Create getModelCapabilities method
    public func getModelCapabilities(modelId: String) async throws -> ModelCapabilities {
        let endpoint = "/models/\(modelId)/capabilities"
        return try await request(
            endpoint: endpoint,
            method: .GET,
            responseType: ModelCapabilities.self
        )
    }
}

// MARK: - Supporting Models
/// Chat status response
public struct ChatStatus: Codable {
    public let sessionId: String
    public let status: String
    public let isActive: Bool
    public let messagesCount: Int
    public let lastActivity: Date?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status
        case isActive = "is_active"
        case messagesCount = "messages_count"
        case lastActivity = "last_activity"
    }
}

/// Chat debug information
public struct ChatDebugInfo: Codable {
    public let sessionId: String
    public let state: String
    public let contextTokens: Int
    public let responseTokens: Int
    public let errors: [String]
    public let performance: PerformanceMetrics
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case state
        case contextTokens = "context_tokens"
        case responseTokens = "response_tokens"
        case errors
        case performance
    }
}

/// Performance metrics
public struct PerformanceMetrics: Codable {
    public let latency: Double
    public let throughput: Double
    public let requestsPerSecond: Double
    
    enum CodingKeys: String, CodingKey {
        case latency
        case throughput
        case requestsPerSecond = "requests_per_second"
    }
}

/// MCP server information
public struct MCPServerInfo: Codable, Identifiable {
    public let id: String
    public let name: String
    public let version: String
    public let status: String
    public let capabilities: [String]
    public let toolsCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case version
        case status
        case capabilities
        case toolsCount = "tools_count"
    }
}

/// MCP servers response
public struct MCPServersResponse: Codable {
    public let servers: [MCPServerInfo]
    public let totalCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case servers
        case totalCount = "total_count"
    }
}

/// Update tools request
public struct UpdateToolsRequest: Codable {
    public let toolIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case toolIds = "tool_ids"
    }
}

/// Usage statistics
public struct UsageStats: Codable {
    public let totalTokens: Int
    public let totalCost: Double
    public let sessionsCount: Int
    public let averageTokensPerSession: Double
    public let periodStart: Date?
    public let periodEnd: Date?
    
    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
        case totalCost = "total_cost"
        case sessionsCount = "sessions_count"
        case averageTokensPerSession = "average_tokens_per_session"
        case periodStart = "period_start"
        case periodEnd = "period_end"
    }
}

/// Usage tracking request
public struct UsageTrackingRequest: Codable {
    public let sessionId: String
    public let usage: Usage
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case usage
    }
}

/// Generic response for simple success/failure
public struct GenericResponse: Codable {
    public let success: Bool
    public let message: String?
}