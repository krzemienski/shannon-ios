//
//  NetworkingTests.swift
//  ClaudeCodeTests
//
//  Comprehensive tests for networking layer
//

import XCTest
@testable import ClaudeCode

final class NetworkingTests: XCTestCase {
    
    var apiClient: APIClient!
    var sseClient: SSEClient!
    var sshManager: SSHManager!
    var mockURLSession: URLSession!
    
    override func setUp() {
        super.setUp()
        
        // Create mock URL session configuration
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockURLSession = URLSession(configuration: config)
        
        // Initialize clients with mock session
        apiClient = APIClient()
        apiClient.session = mockURLSession
        
        sseClient = SSEClient()
        sshManager = SSHManager.shared
    }
    
    override func tearDown() {
        apiClient = nil
        sseClient = nil
        sshManager = nil
        mockURLSession = nil
        super.tearDown()
    }
    
    // MARK: - APIClient Tests
    
    func testRequestPrioritization() async throws {
        // Test that high priority requests are processed first
        let expectation1 = XCTestExpectation(description: "Normal priority request")
        let expectation2 = XCTestExpectation(description: "High priority request")
        
        // Queue normal priority request first
        Task {
            do {
                let _: HealthResponse = try await apiClient.request(
                    endpoint: .health,
                    priority: .normal
                )
                expectation1.fulfill()
            } catch {
                XCTFail("Normal priority request failed: \(error)")
            }
        }
        
        // Queue high priority request second
        Task {
            do {
                let _: HealthResponse = try await apiClient.request(
                    endpoint: .health,
                    priority: .high
                )
                expectation2.fulfill()
            } catch {
                XCTFail("High priority request failed: \(error)")
            }
        }
        
        // High priority should complete first
        wait(for: [expectation2, expectation1], timeout: 5.0, enforceOrder: true)
    }
    
    func testCaching() async throws {
        // Configure mock response
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {
                "status": "healthy",
                "version": "1.0.0"
            }
            """.data(using: .utf8)!
            return (response, data)
        }
        
        // First request should hit network
        let result1: HealthResponse = try await apiClient.request(
            endpoint: .health,
            cachePolicy: .returnCacheDataElseLoad
        )
        XCTAssertEqual(result1.status, "healthy")
        
        // Second request should use cache
        let result2: HealthResponse = try await apiClient.request(
            endpoint: .health,
            cachePolicy: .returnCacheDataElseLoad
        )
        XCTAssertEqual(result2.status, "healthy")
        
        // Verify only one network request was made
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }
    
    func testCircuitBreaker() async throws {
        // Configure mock to always fail
        MockURLProtocol.requestHandler = { request in
            throw URLError(.notConnectedToInternet)
        }
        
        // Make requests until circuit opens
        for _ in 0..<5 {
            do {
                let _: HealthResponse = try await apiClient.request(endpoint: .health)
                XCTFail("Request should have failed")
            } catch {
                // Expected
            }
        }
        
        // Circuit should be open now
        do {
            let _: HealthResponse = try await apiClient.request(endpoint: .health)
            XCTFail("Circuit should be open")
        } catch APIError.circuitBreakerOpen {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRequestDeduplication() async throws {
        let expectation = XCTestExpectation(description: "Single network request")
        var requestCount = 0
        
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {
                "status": "healthy",
                "version": "1.0.0"
            }
            """.data(using: .utf8)!
            
            // Delay to simulate network latency
            Thread.sleep(forTimeInterval: 0.5)
            
            if requestCount == 1 {
                expectation.fulfill()
            }
            
            return (response, data)
        }
        
        // Make multiple identical requests simultaneously
        async let request1: HealthResponse = apiClient.request(endpoint: .health)
        async let request2: HealthResponse = apiClient.request(endpoint: .health)
        async let request3: HealthResponse = apiClient.request(endpoint: .health)
        
        let results = try await [request1, request2, request3]
        
        wait(for: [expectation], timeout: 2.0)
        
        // All should succeed but only one network request
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(requestCount, 1, "Should deduplicate to single request")
    }
    
    // MARK: - SSEClient Tests
    
    func testSSEReconnection() async throws {
        let connectExpectation = XCTestExpectation(description: "Initial connection")
        let reconnectExpectation = XCTestExpectation(description: "Reconnection")
        var connectionCount = 0
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { message in
                // Handle messages
            },
            onError: { error in
                // Trigger reconnection
            },
            onComplete: {
                // Stream completed
            },
            onReconnect: {
                connectionCount += 1
                if connectionCount == 1 {
                    connectExpectation.fulfill()
                } else if connectionCount == 2 {
                    reconnectExpectation.fulfill()
                }
            }
        )
        
        // Simulate connection failure
        sseClient.handleError(URLError(.networkConnectionLost))
        
        wait(for: [connectExpectation, reconnectExpectation], timeout: 10.0)
        XCTAssertEqual(connectionCount, 2, "Should have reconnected once")
    }
    
    func testSSEHeartbeat() async throws {
        let heartbeatExpectation = XCTestExpectation(description: "Heartbeat received")
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { _ in },
            onError: { _ in },
            onComplete: { },
            onHeartbeat: {
                heartbeatExpectation.fulfill()
            }
        )
        
        // Simulate heartbeat
        sseClient.processEvent(":heartbeat\n\n")
        
        wait(for: [heartbeatExpectation], timeout: 2.0)
    }
    
    func testSSEBackpressure() async throws {
        var messageCount = 0
        let pressureThreshold = 100
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { message in
                messageCount += 1
                // Simulate slow processing
                Thread.sleep(forTimeInterval: 0.01)
            },
            onError: { _ in },
            onComplete: { },
            options: StreamOptions(
                bufferSize: pressureThreshold,
                enableCompression: false,
                validateEvents: true
            )
        )
        
        // Send many messages quickly
        for i in 0..<200 {
            sseClient.processEvent("data: Message \(i)\n\n")
        }
        
        // Should handle backpressure without overwhelming
        XCTAssertLessThanOrEqual(messageCount, pressureThreshold + 10, "Should handle backpressure")
    }
    
    // MARK: - SSHManager Tests
    
    func testSSHConnectionPooling() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        // Create multiple connections
        let connection1 = try await sshManager.connect(config: config)
        let connection2 = try await sshManager.connect(config: config)
        
        // Should reuse from pool
        XCTAssertEqual(connection1.id, connection2.id, "Should reuse pooled connection")
        
        // Disconnect
        await sshManager.disconnect(connectionId: connection1.id)
    }
    
    func testSSHTunneling() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        // Create tunnel
        let tunnelConfig = TunnelConfiguration(
            localPort: 8080,
            remoteHost: "localhost",
            remotePort: 80,
            bindAddress: "127.0.0.1"
        )
        
        let success = await sshManager.createTunnel(
            connectionId: connection.id,
            config: tunnelConfig
        )
        
        XCTAssertTrue(success, "Tunnel creation should succeed")
        
        // Clean up
        await sshManager.closeTunnel(
            connectionId: connection.id,
            localPort: 8080
        )
        await sshManager.disconnect(connectionId: connection.id)
    }
    
    func testSFTPFileTransfer() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        var progressValues: [Double] = []
        
        // Test upload with progress
        let uploadSuccess = await sshManager.uploadFile(
            connectionId: connection.id,
            localPath: "/tmp/test.txt",
            remotePath: "/home/testuser/test.txt",
            progressHandler: { progress in
                progressValues.append(progress)
            }
        )
        
        XCTAssertTrue(uploadSuccess, "Upload should succeed")
        XCTAssertFalse(progressValues.isEmpty, "Should report progress")
        XCTAssertEqual(progressValues.last, 1.0, accuracy: 0.01, "Should complete at 100%")
        
        // Clean up
        await sshManager.disconnect(connectionId: connection.id)
    }
    
    // MARK: - Integration Tests
    
    func testChatCompletionFlow() async throws {
        // Test complete chat flow
        let request = ChatCompletionRequest(
            model: "gpt-4",
            messages: [
                ChatMessage(role: .user, content: "Hello, how are you?")
            ],
            temperature: 0.7,
            maxTokens: 100,
            stream: false
        )
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = """
            {
                "id": "chatcmpl-123",
                "object": "chat.completion",
                "created": 1234567890,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "I'm doing well, thank you!"
                    },
                    "finish_reason": "stop"
                }],
                "usage": {
                    "prompt_tokens": 10,
                    "completion_tokens": 8,
                    "total_tokens": 18
                }
            }
            """.data(using: .utf8)!
            return (response, data)
        }
        
        let completion: ChatCompletionResponse = try await apiClient.createChatCompletion(request: request)
        
        XCTAssertEqual(completion.choices.first?.message.content, "I'm doing well, thank you!")
        XCTAssertEqual(completion.usage?.totalTokens, 18)
    }
    
    func testStreamingChatCompletion() async throws {
        let messageExpectation = XCTestExpectation(description: "Receive streamed messages")
        var receivedContent = ""
        
        let request = ChatCompletionRequest(
            model: "gpt-4",
            messages: [
                ChatMessage(role: .user, content: "Tell me a story")
            ],
            stream: true
        )
        
        try await apiClient.streamChatCompletion(
            request: request,
            onMessage: { chunk in
                if let content = chunk.choices.first?.delta?.content {
                    receivedContent += content
                }
                if receivedContent.count > 10 {
                    messageExpectation.fulfill()
                }
            },
            onError: { error in
                XCTFail("Stream error: \(error)")
            },
            onComplete: {
                // Stream completed
            }
        )
        
        wait(for: [messageExpectation], timeout: 5.0)
        XCTAssertFalse(receivedContent.isEmpty, "Should receive streamed content")
    }
}

// MARK: - Mock URL Protocol

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var requestCount = 0
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        MockURLProtocol.requestCount += 1
        
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {
        // Clean up if needed
    }
}

// MARK: - Test Models

struct HealthResponse: Codable {
    let status: String
    let version: String
}