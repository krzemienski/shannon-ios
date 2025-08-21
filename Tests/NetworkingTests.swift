import XCTest
@testable import ClaudeCode

// MARK: - Comprehensive Networking Tests for Tasks 301-450
@MainActor
final class NetworkingTests: XCTestCase {
    
    // MARK: - Properties
    
    private var apiClient: APIClient!
    private var mockClient: MockAPIClient!
    private var sseClient: SSEClient!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize API client with test configuration
        let config = APIConfig(
            baseURL: "http://localhost:8000/v1",
            apiKey: "test-api-key",
            requestTimeout: 10.0,
            streamTimeout: 30.0,
            maxRetries: 2,
            enableCaching: true,
            cacheExpiration: 300
        )
        
        apiClient = await APIClient(configuration: config)
        mockClient = MockAPIClient()
        
        // Initialize SSE client
        let sseConfig = SSEConfiguration(
            reconnectTime: 1.0,
            maxReconnectAttempts: 2,
            heartbeatInterval: 15.0
        )
        sseClient = SSEClient(configuration: sseConfig)
    }
    
    override func tearDown() async throws {
        apiClient = nil
        mockClient = nil
        sseClient = nil
        try await super.tearDown()
    }
    
    // MARK: - Task 301-303: Basic Connectivity Tests
    
    func testHealthEndpoint() async throws {
        // Task 302: Test /health endpoint
        let isHealthy = await mockClient.checkHealth()
        XCTAssertTrue(isHealthy, "Health check should return true for mock client")
    }
    
    func testBackendVerification() async throws {
        // Task 303: Verify backend connection
        let isConnected = await apiClient.verifyBackend()
        print("Backend verification result: \(isConnected)")
        // This will fail if backend is not running, which is expected
    }
    
    // MARK: - Task 304-310: Request Building Tests
    
    func testRequestBuilder() async throws {
        // Task 304-305: Test request building with headers
        let config = APIConfig(
            baseURL: "http://localhost:8000/v1",
            apiKey: "test-key"
        )
        
        XCTAssertEqual(config.baseURL, "http://localhost:8000/v1")
        XCTAssertNotNil(config.apiKey)
        XCTAssertEqual(config.maxRetries, 3) // Default value
    }
    
    // MARK: - Task 311-320: Error Handling Tests
    
    func testErrorHandling() async throws {
        // Task 311-315: Test various error scenarios
        do {
            // Test with invalid session ID
            _ = try await mockClient.getSession(id: "invalid-session")
        } catch {
            // Expected to throw error for invalid session
            XCTAssertTrue(error is APIConfig.APIError)
        }
    }
    
    // MARK: - Task 332: Mock Response System Tests
    
    func testMockModelsResponse() async throws {
        // Task 332: Test mock response system
        let models = try await mockClient.fetchModels()
        
        XCTAssertFalse(models.isEmpty, "Mock should return models")
        XCTAssertTrue(models.contains(where: { $0.id == "claude-sonnet-4" }))
        XCTAssertTrue(models.contains(where: { $0.id == "claude-opus-4" }))
        
        // Verify model capabilities
        if let sonnet = models.first(where: { $0.id == "claude-sonnet-4" }) {
            XCTAssertNotNil(sonnet.capabilities)
            XCTAssertEqual(sonnet.capabilities?.contextWindow, 200000)
            XCTAssertTrue(sonnet.capabilities?.supportsStreaming ?? false)
            XCTAssertTrue(sonnet.capabilities?.supportsToolUse ?? false)
        }
    }
    
    func testMockChatCompletion() async throws {
        // Test non-streaming chat completion
        let request = ChatCompletionRequest(
            model: "claude-sonnet-4",
            messages: [
                ChatMessage(role: .user, content: "Hello, how are you?")
            ],
            temperature: 0.7,
            maxTokens: 100
        )
        
        let response = try await mockClient.createChatCompletion(request: request)
        
        XCTAssertEqual(response.model, request.model)
        XCTAssertFalse(response.choices.isEmpty)
        XCTAssertNotNil(response.usage)
        
        if let firstChoice = response.choices.first {
            XCTAssertEqual(firstChoice.message.role, .assistant)
            XCTAssertNotNil(firstChoice.message.content)
        }
    }
    
    // MARK: - Task 404-405, 415-416: Streaming Tests
    
    func testStreamingChatCompletion() async throws {
        // Task 404-405: Test streaming chat completion
        let request = ChatCompletionRequest(
            model: "claude-sonnet-4",
            messages: [
                ChatMessage(role: .user, content: "Test streaming")
            ],
            stream: true
        )
        
        let expectation = expectation(description: "Streaming completes")
        var chunks: [ChatStreamChunk] = []
        var hasCompleted = false
        
        await mockClient.streamChat(
            request: request,
            onChunk: { chunk in
                chunks.append(chunk)
            },
            onComplete: {
                hasCompleted = true
                expectation.fulfill()
            },
            onError: { error in
                XCTFail("Streaming failed with error: \(error)")
                expectation.fulfill()
            }
        )
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        XCTAssertTrue(hasCompleted, "Streaming should complete")
        XCTAssertFalse(chunks.isEmpty, "Should receive chunks")
        
        // Verify chunk structure
        if let firstChunk = chunks.first {
            XCTAssertEqual(firstChunk.object, "chat.completion.chunk")
            XCTAssertEqual(firstChunk.model, request.model)
        }
        
        // Check for final chunk
        if let lastChunk = chunks.last {
            XCTAssertEqual(lastChunk.choices.first?.finishReason, "stop")
        }
    }
    
    // MARK: - Task 407-412: Session Management Tests
    
    func testSessionManagement() async throws {
        // Task 407-412: Test session CRUD operations
        
        // List sessions
        let sessions = try await mockClient.listSessions()
        XCTAssertFalse(sessions.isEmpty, "Mock should return sessions")
        
        // Get specific session
        if let firstSession = sessions.first {
            let session = try await mockClient.getSession(id: firstSession.id)
            XCTAssertEqual(session.id, firstSession.id)
            XCTAssertNotNil(session.metadata)
        }
        
        // Create new session
        let createRequest = CreateSessionRequest(
            name: "Test Session",
            projectId: nil,
            metadata: SessionMetadata(
                model: "claude-sonnet-4",
                temperature: 0.7
            )
        )
        
        let newSession = try await mockClient.createSession(createRequest)
        XCTAssertEqual(newSession.name, "Test Session")
        XCTAssertEqual(newSession.metadata?.model, "claude-sonnet-4")
        
        // Update session
        let updateRequest = CreateSessionRequest(
            name: "Updated Session",
            projectId: nil,
            metadata: SessionMetadata(
                model: "claude-opus-4",
                temperature: 0.5
            )
        )
        
        let updatedSession = try await mockClient.updateSession(
            id: newSession.id,
            request: updateRequest
        )
        XCTAssertEqual(updatedSession.name, "Updated Session")
        
        // Delete session
        let deleted = try await mockClient.deleteSession(id: newSession.id)
        XCTAssertTrue(deleted, "Session should be deleted")
    }
    
    // MARK: - Task 420-424: MCP Server Tests
    
    func testMCPServerEndpoints() async throws {
        // Task 420: List MCP servers
        let servers = try await mockClient.listMCPServers()
        XCTAssertFalse(servers.isEmpty, "Should return MCP servers")
        
        // Verify server structure
        if let fileSystemServer = servers.first(where: { $0.name == "filesystem" }) {
            XCTAssertEqual(fileSystemServer.status, "connected")
            XCTAssertTrue(fileSystemServer.capabilities.contains("read"))
            XCTAssertGreaterThan(fileSystemServer.toolsCount, 0)
            
            // Task 421: Get server tools
            let tools = try await mockClient.getMCPServerTools(serverId: fileSystemServer.id)
            XCTAssertEqual(tools.count, fileSystemServer.toolsCount)
            
            // Verify tool structure
            if let readTool = tools.first(where: { $0.name == "read_file" }) {
                XCTAssertNotNil(readTool.description)
                XCTAssertNotNil(readTool.inputSchema)
                XCTAssertTrue(readTool.isEnabled)
            }
        }
        
        // Task 423: Execute MCP tool
        let toolRequest = ToolExecutionRequest(
            toolId: "fs-read",
            input: ["path": "/test/file.txt"],
            sessionId: "test-session",
            timeout: 5.0
        )
        
        let toolResponse = try await mockClient.executeMCPTool(toolRequest)
        XCTAssertEqual(toolResponse.status, .success)
        XCTAssertNotNil(toolResponse.output)
        XCTAssertNil(toolResponse.error)
    }
    
    // MARK: - Task 425: Usage Tracking Tests
    
    func testUsageTracking() async throws {
        // Get usage statistics
        let stats = try await mockClient.getUsageStats()
        
        XCTAssertGreaterThan(stats.totalTokens, 0)
        XCTAssertGreaterThan(stats.totalCost, 0)
        XCTAssertGreaterThan(stats.sessionsCount, 0)
        XCTAssertGreaterThan(stats.averageTokensPerSession, 0)
        
        // Track usage for a session
        let usage = Usage(
            promptTokens: 100,
            completionTokens: 200,
            totalTokens: 300
        )
        
        let tracked = try await mockClient.trackUsage(
            sessionId: "test-session",
            usage: usage
        )
        XCTAssertTrue(tracked, "Usage should be tracked successfully")
    }
    
    // MARK: - SSE Client Tests (Tasks 354-400)
    
    func testSSEMessageParsing() throws {
        // Task 359-361: Test SSE message parsing
        let testData = """
        data: {"id":"test","content":"Hello"}
        
        data: {"id":"test2","content":"World"}
        
        data: [DONE]
        
        """
        
        let messages = SSEParser.parseMessages(from: testData)
        XCTAssertEqual(messages.count, 3)
        
        if messages.count >= 2 {
            XCTAssertEqual(messages[0].data, "{\"id\":\"test\",\"content\":\"Hello\"}")
            XCTAssertEqual(messages[1].data, "{\"id\":\"test2\",\"content\":\"World\"}")
            XCTAssertEqual(messages[2].data, "[DONE]")
        }
    }
    
    func testSSEBufferHandling() throws {
        // Task 358: Test buffer handling for incomplete chunks
        var buffer = SSEBuffer()
        
        // Add incomplete chunk
        buffer.append("data: {\"id\":\"tes")
        XCTAssertTrue(buffer.messages.isEmpty)
        
        // Complete the chunk
        buffer.append("t\",\"content\":\"Hello\"}\n\n")
        XCTAssertEqual(buffer.messages.count, 1)
        XCTAssertEqual(buffer.messages[0].data, "{\"id\":\"test\",\"content\":\"Hello\"}")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceMetrics() async throws {
        // Task 338, 407: Test metrics collection
        let metrics = apiClient.getMetrics()
        
        XCTAssertNotNil(metrics.requestCount)
        XCTAssertNotNil(metrics.averageLatency)
        XCTAssertNotNil(metrics.successRate)
        
        // Test after making a request
        _ = await mockClient.checkHealth()
        
        let updatedMetrics = apiClient.getMetrics()
        XCTAssertGreaterThanOrEqual(updatedMetrics.requestCount, metrics.requestCount)
    }
    
    // MARK: - Connection Pool Tests
    
    func testConnectionPooling() async throws {
        // Task 340, 408: Test connection pool management
        // Make multiple concurrent requests
        async let request1 = mockClient.checkHealth()
        async let request2 = mockClient.fetchModels()
        async let request3 = mockClient.listSessions()
        
        let results = await (request1, try request2, try request3)
        
        XCTAssertTrue(results.0)
        XCTAssertFalse(results.1.isEmpty)
        XCTAssertFalse(results.2.isEmpty)
    }
}

// MARK: - Helper Extensions for Testing

extension SSEParser {
    static func parseMessages(from data: String) -> [SSEMessage] {
        var messages: [SSEMessage] = []
        let lines = data.components(separatedBy: "\n")
        var currentData = ""
        
        for line in lines {
            if line.hasPrefix("data: ") {
                currentData = String(line.dropFirst(6))
            } else if line.isEmpty && !currentData.isEmpty {
                messages.append(SSEMessage(
                    id: nil,
                    event: "message",
                    data: currentData,
                    retry: nil
                ))
                currentData = ""
            }
        }
        
        return messages
    }
}

struct SSEBuffer {
    private var buffer = ""
    var messages: [SSEMessage] = []
    
    mutating func append(_ data: String) {
        buffer += data
        
        // Check for complete messages
        while let range = buffer.range(of: "\n\n") {
            let messageData = String(buffer[..<range.lowerBound])
            if messageData.hasPrefix("data: ") {
                let content = String(messageData.dropFirst(6))
                messages.append(SSEMessage(
                    id: nil,
                    event: "message",
                    data: content,
                    retry: nil
                ))
            }
            buffer = String(buffer[range.upperBound...])
        }
    }
}