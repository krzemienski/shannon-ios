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
        let sseConfiguration = SSEConfiguration(
            timeoutInterval: 30,
            reconnectEnabled: true,
            maxReconnectAttempts: 3,
            compressionEnabled: false,
            bufferSize: 1024 * 1024
        )
        let sseClient = SSEClient(configuration: sseConfiguration)
        
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
        let url = APIConfig.Endpoint.chatCompletions.url()
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        if let apiKey = apiKey {
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
        // TODO: Add proper endpoint to APIConfig.Endpoint enum
        // For now, using a direct URL construction
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/chat/status/\(sessionId)"))
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to get chat status"
            )
        }
        
        return try JSONDecoder().decode(ChatStatus.self, from: data)
    }
    
    /// Task 418: Create stopChat method
    public func stopChat(sessionId: String) async throws -> Bool {
        // TODO: Add proper endpoint to APIConfig.Endpoint enum
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/chat/stop/\(sessionId)"))
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to stop chat"
            )
        }
        
        let genericResponse = try JSONDecoder().decode(GenericResponse.self, from: data)
        return genericResponse.success
    }
    
    /// Task 419: Implement debugChat method
    public func debugChat(sessionId: String) async throws -> ChatDebugInfo {
        // TODO: Add proper endpoint to APIConfig.Endpoint enum
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/chat/debug/\(sessionId)"))
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to get chat debug info"
            )
        }
        
        return try JSONDecoder().decode(ChatDebugInfo.self, from: data)
    }
}

// MARK: - Tasks 420-424: MCP Server Tools
extension APIClient {
    /// Task 420: Create listMCPServers method
    public func listMCPServers() async throws -> [MCPServerInfo] {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/mcp/servers"))
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to list MCP servers"
            )
        }
        
        let mcpResponse = try JSONDecoder().decode(MCPServersResponse.self, from: data)
        return mcpResponse.servers
    }
    
    /// Task 421: Implement getMCPServerTools method
    public func getMCPServerTools(serverId: String) async throws -> [ToolInfo] {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/mcp/servers/\(serverId)/tools"))
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to get MCP server tools"
            )
        }
        
        let toolsResponse = try JSONDecoder().decode(ToolsResponse.self, from: data)
        return toolsResponse.tools
    }
    
    /// Task 422: Create updateSessionTools method
    public func updateSessionTools(sessionId: String, toolIds: [String]) async throws -> SessionInfo {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/sessions/\(sessionId)/tools"))
        request.httpMethod = "PUT"
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        
        let body = UpdateToolsRequest(toolIds: toolIds)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to update session tools"
            )
        }
        
        return try JSONDecoder().decode(SessionInfo.self, from: data)
    }
    
    /// Task 423: Implement tool execution endpoint
    public func executeMCPTool(_ toolRequest: ToolExecutionRequest) async throws -> ToolExecutionResponse {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/mcp/tools/execute"))
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        request.httpBody = try JSONEncoder().encode(toolRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to execute MCP tool"
            )
        }
        
        return try JSONDecoder().decode(ToolExecutionResponse.self, from: data)
    }
    
    /// Task 424: Create tool result submission
    public func submitToolResult(sessionId: String, toolCallId: String, result: ToolResultEvent) async throws -> Bool {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/sessions/\(sessionId)/tools/\(toolCallId)/result"))
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        request.httpBody = try JSONEncoder().encode(result)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to submit tool result"
            )
        }
        
        let genericResponse = try JSONDecoder().decode(GenericResponse.self, from: data)
        return genericResponse.success
    }
}

// MARK: - Task 425: Usage Tracking
extension APIClient {
    /// Task 425: Implement usage tracking endpoint
    public func getUsageStats(startDate: Date? = nil, endDate: Date? = nil) async throws -> UsageStats {
        var components = URLComponents(url: APIConfig.baseURL.appendingPathComponent("/usage/stats"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []
        
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: ISO8601DateFormatter().string(from: startDate)))
        }
        
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: ISO8601DateFormatter().string(from: endDate)))
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to get usage stats"
            )
        }
        
        return try JSONDecoder().decode(UsageStats.self, from: data)
    }
    
    /// Track API usage for a specific session
    public func trackUsage(sessionId: String, usage: APIUsage) async throws -> Bool {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/usage/track"))
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        
        let body = UsageTrackingRequest(sessionId: sessionId, usage: usage)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to track usage"
            )
        }
        
        let genericResponse = try JSONDecoder().decode(GenericResponse.self, from: data)
        return genericResponse.success
    }
}

// MARK: - Task 412-414: Additional Session/Model Methods
extension APIClient {
    /// Task 412: Create getSessionStats method
    public func getSessionStats(sessionId: String) async throws -> SessionStats {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/sessions/\(sessionId)/stats"))
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to get session stats"
            )
        }
        
        return try JSONDecoder().decode(SessionStats.self, from: data)
    }
    
    /// Task 414: Create getModelCapabilities method
    public func getModelCapabilities(modelId: String) async throws -> ModelCapabilities {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent("/models/\(modelId)/capabilities"))
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to get model capabilities"
            )
        }
        
        return try JSONDecoder().decode(ModelCapabilities.self, from: data)
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

// UsageStats and UsageTrackingRequest have been moved to Models/UsageModels.swift

/// Generic response for simple success/failure
public struct GenericResponse: Codable {
    public let success: Bool
    public let message: String?
}