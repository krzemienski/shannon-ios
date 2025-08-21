//
//  APIClientTests.swift
//  ClaudeCodeTests
//
//  Unit tests for APIClient service
//

import XCTest
@testable import ClaudeCode

final class APIClientTests: XCTestCase {
    
    var apiClient: APIClient!
    var mockSession: URLSession!
    
    override func setUp() {
        super.setUp()
        
        // Create mock URL session
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        
        // Initialize API client with mock session
        apiClient = APIClient()
        apiClient.session = mockSession
        
        // Reset mock protocol
        MockURLProtocol.reset()
    }
    
    override func tearDown() {
        apiClient = nil
        mockSession = nil
        MockURLProtocol.reset()
        super.tearDown()
    }
    
    // MARK: - Request Building Tests
    
    func testRequestBuilder() throws {
        let endpoint = APIEndpoint.chat
        let method = HTTPMethod.post
        let body = ["test": "data"]
        
        let request = try apiClient.buildRequest(
            endpoint: endpoint,
            method: method,
            body: body
        )
        
        XCTAssertEqual(request.url?.path, "/v1/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNotNil(request.httpBody)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    
    func testAuthorizationHeader() throws {
        APIConfig.shared.apiKey = "test-api-key"
        
        let request = try apiClient.buildRequest(
            endpoint: .models,
            method: .get
        )
        
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")
    }
    
    func testCustomHeaders() throws {
        let headers = ["X-Custom": "Value"]
        
        let request = try apiClient.buildRequest(
            endpoint: .health,
            method: .get,
            headers: headers
        )
        
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom"), "Value")
    }
    
    // MARK: - Response Handling Tests
    
    func testSuccessfulResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = """
            {
                "data": [
                    {"id": "model-1", "object": "model"},
                    {"id": "model-2", "object": "model"}
                ]
            }
            """.data(using: .utf8)!
            return (response, data)
        }
        
        let models: ModelsResponse = try await apiClient.request(
            endpoint: .models,
            method: .get
        )
        
        XCTAssertEqual(models.data.count, 2)
        XCTAssertEqual(models.data[0].id, "model-1")
    }
    
    func testErrorResponse() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {
                "error": {
                    "message": "Bad request",
                    "type": "invalid_request",
                    "code": "bad_request"
                }
            }
            """.data(using: .utf8)!
            return (response, data)
        }
        
        do {
            let _: ModelsResponse = try await apiClient.request(
                endpoint: .models,
                method: .get
            )
            XCTFail("Should have thrown error")
        } catch APIError.serverError(let statusCode, let message) {
            XCTAssertEqual(statusCode, 400)
            XCTAssertTrue(message.contains("Bad request"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testNetworkError() async {
        MockURLProtocol.requestHandler = { request in
            throw URLError(.notConnectedToInternet)
        }
        
        do {
            let _: ModelsResponse = try await apiClient.request(
                endpoint: .models,
                method: .get
            )
            XCTFail("Should have thrown error")
        } catch APIError.networkError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Retry Logic Tests
    
    func testRetryOnTransientError() async throws {
        var attempts = 0
        
        MockURLProtocol.requestHandler = { request in
            attempts += 1
            if attempts < 3 {
                throw URLError(.timedOut)
            }
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"data": []}
            """.data(using: .utf8)!
            return (response, data)
        }
        
        let _: ModelsResponse = try await apiClient.request(
            endpoint: .models,
            method: .get,
            retryCount: 3
        )
        
        XCTAssertEqual(attempts, 3, "Should retry twice before succeeding")
    }
    
    func testNoRetryOnPermanentError() async {
        var attempts = 0
        
        MockURLProtocol.requestHandler = { request in
            attempts += 1
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"error": {"message": "Unauthorized"}}
            """.data(using: .utf8)!
            return (response, data)
        }
        
        do {
            let _: ModelsResponse = try await apiClient.request(
                endpoint: .models,
                method: .get,
                retryCount: 3
            )
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(attempts, 1, "Should not retry on permanent error")
        }
    }
    
    // MARK: - Priority Queue Tests
    
    func testRequestPriority() async throws {
        let expectation1 = XCTestExpectation(description: "Low priority")
        let expectation2 = XCTestExpectation(description: "High priority")
        
        var completionOrder: [String] = []
        
        MockURLProtocol.requestHandler = { request in
            // Add delay to simulate network
            Thread.sleep(forTimeInterval: 0.1)
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"data": []}
            """.data(using: .utf8)!
            return (response, data)
        }
        
        // Submit low priority first
        Task {
            let _: ModelsResponse = try await apiClient.request(
                endpoint: .models,
                method: .get,
                priority: .low
            )
            completionOrder.append("low")
            expectation1.fulfill()
        }
        
        // Submit high priority second
        Task {
            let _: ModelsResponse = try await apiClient.request(
                endpoint: .models,
                method: .get,
                priority: .high
            )
            completionOrder.append("high")
            expectation2.fulfill()
        }
        
        wait(for: [expectation2, expectation1], timeout: 5.0, enforceOrder: true)
        
        // High priority should complete first despite being submitted second
        XCTAssertEqual(completionOrder, ["high", "low"])
    }
    
    // MARK: - Session Management Tests
    
    func testCreateSession() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/sessions")
            XCTAssertEqual(request.httpMethod, "POST")
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {
                "id": "session-123",
                "name": "Test Session",
                "status": "active",
                "created_at": "2024-01-01T00:00:00Z"
            }
            """.data(using: .utf8)!
            return (response, data)
        }
        
        let request = CreateSessionRequest(
            projectPath: "/test/path",
            name: "Test Session"
        )
        
        let session = try await apiClient.createSession(request: request)
        
        XCTAssertEqual(session.id, "session-123")
        XCTAssertEqual(session.name, "Test Session")
        XCTAssertEqual(session.status, "active")
    }
    
    func testUpdateSession() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/sessions/session-123")
            XCTAssertEqual(request.httpMethod, "PATCH")
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {
                "id": "session-123",
                "name": "Updated Session",
                "status": "paused",
                "created_at": "2024-01-01T00:00:00Z"
            }
            """.data(using: .utf8)!
            return (response, data)
        }
        
        let request = UpdateSessionRequest(
            name: "Updated Session",
            status: "paused"
        )
        
        let session = try await apiClient.updateSession(
            sessionId: "session-123",
            request: request
        )
        
        XCTAssertEqual(session.name, "Updated Session")
        XCTAssertEqual(session.status, "paused")
    }
    
    // MARK: - Chat Completion Tests
    
    func testChatCompletion() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v1/chat/completions")
            
            // Verify request body
            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                XCTAssertEqual(json["model"] as? String, "gpt-4")
                XCTAssertEqual(json["stream"] as? Bool, false)
            }
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
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
                        "content": "Hello!"
                    },
                    "finish_reason": "stop"
                }],
                "usage": {
                    "prompt_tokens": 10,
                    "completion_tokens": 5,
                    "total_tokens": 15
                }
            }
            """.data(using: .utf8)!
            return (response, data)
        }
        
        let request = ChatCompletionRequest(
            model: "gpt-4",
            messages: [
                ChatMessage(role: .user, content: "Hi")
            ],
            stream: false
        )
        
        let completion = try await apiClient.createChatCompletion(request: request)
        
        XCTAssertEqual(completion.id, "chatcmpl-123")
        XCTAssertEqual(completion.choices.first?.message.content, "Hello!")
        XCTAssertEqual(completion.usage?.totalTokens, 15)
    }
    
    // MARK: - Performance Tests
    
    func testRequestPerformance() {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"data": []}
            """.data(using: .utf8)!
            return (response, data)
        }
        
        measure {
            let expectation = XCTestExpectation(description: "Request completes")
            
            Task {
                let _: ModelsResponse = try await apiClient.request(
                    endpoint: .models,
                    method: .get
                )
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}

// MARK: - Mock Helpers

extension APIClientTests {
    
    func testRequestCancellation() async throws {
        MockURLProtocol.requestHandler = { request in
            // Simulate slow response
            Thread.sleep(forTimeInterval: 2.0)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"data": []}
            """.data(using: .utf8)!
            return (response, data)
        }
        
        let task = Task {
            let _: ModelsResponse = try await apiClient.request(
                endpoint: .models,
                method: .get
            )
        }
        
        // Cancel after short delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        task.cancel()
        
        do {
            try await task.value
            XCTFail("Should have been cancelled")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }
    
    func testConcurrentRequests() async throws {
        var requestCount = 0
        let lock = NSLock()
        
        MockURLProtocol.requestHandler = { request in
            lock.lock()
            requestCount += 1
            let currentCount = requestCount
            lock.unlock()
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {"data": [{"id": "model-\(currentCount)", "object": "model"}]}
            """.data(using: .utf8)!
            return (response, data)
        }
        
        // Make 10 concurrent requests
        let tasks = (0..<10).map { _ in
            Task {
                let models: ModelsResponse = try await apiClient.request(
                    endpoint: .models,
                    method: .get
                )
                return models
            }
        }
        
        let results = try await withThrowingTaskGroup(of: ModelsResponse.self) { group in
            for task in tasks {
                group.addTask {
                    try await task.value
                }
            }
            
            var responses: [ModelsResponse] = []
            for try await result in group {
                responses.append(result)
            }
            return responses
        }
        
        XCTAssertEqual(results.count, 10)
        XCTAssertEqual(requestCount, 10)
    }
}