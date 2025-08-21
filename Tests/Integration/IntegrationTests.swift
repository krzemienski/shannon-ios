//
//  IntegrationTests.swift
//  ClaudeCodeTests
//
//  Integration tests with actual backend
//

import XCTest
@testable import ClaudeCode

final class IntegrationTests: XCTestCase {
    
    var apiClient: APIClient!
    let baseURL = "http://localhost:8000"
    
    override func setUp() {
        super.setUp()
        
        // Initialize real API client
        apiClient = APIClient()
        
        // Configure for local backend
        APIConfig.shared.baseURL = baseURL
        APIConfig.shared.apiKey = "test-api-key"
    }
    
    override func tearDown() {
        apiClient = nil
        super.tearDown()
    }
    
    // MARK: - Health Check
    
    func testHealthEndpoint() async throws {
        // Skip if backend not running
        guard await isBackendRunning() else {
            throw XCTSkip("Backend not running at \(baseURL)")
        }
        
        let expectation = XCTestExpectation(description: "Health check")
        
        do {
            // Use direct URL since health is not under /v1
            let url = URL(string: "\(baseURL)/health")!
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                XCTFail("Invalid response type")
                return
            }
            
            XCTAssertEqual(httpResponse.statusCode, 200, "Health check should return 200")
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                XCTAssertNotNil(json["status"], "Should have status field")
                XCTAssertNotNil(json["version"], "Should have version field")
                print("Backend health: \(json)")
            }
            
            expectation.fulfill()
        } catch {
            XCTFail("Health check failed: \(error)")
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Models Endpoint
    
    func testListModels() async throws {
        guard await isBackendRunning() else {
            throw XCTSkip("Backend not running")
        }
        
        do {
            let models: ModelsResponse = try await apiClient.request(
                endpoint: .models,
                method: .get
            )
            
            XCTAssertFalse(models.data.isEmpty, "Should return available models")
            
            for model in models.data {
                XCTAssertFalse(model.id.isEmpty, "Model should have ID")
                XCTAssertEqual(model.object, "model", "Object type should be 'model'")
            }
            
            print("Available models: \(models.data.map { $0.id })")
        } catch {
            XCTFail("List models failed: \(error)")
        }
    }
    
    // MARK: - Sessions
    
    func testSessionLifecycle() async throws {
        guard await isBackendRunning() else {
            throw XCTSkip("Backend not running")
        }
        
        // Create session
        let createRequest = CreateSessionRequest(
            projectPath: "/tmp/test-project",
            name: "Test Session"
        )
        
        do {
            let session = try await apiClient.createSession(request: createRequest)
            XCTAssertFalse(session.id.isEmpty, "Session should have ID")
            XCTAssertEqual(session.name, "Test Session")
            XCTAssertEqual(session.status, "active")
            
            print("Created session: \(session.id)")
            
            // List sessions
            let sessions = try await apiClient.listSessions()
            XCTAssertTrue(sessions.contains { $0.id == session.id }, "Should find created session")
            
            // Update session
            let updateRequest = UpdateSessionRequest(
                name: "Updated Session",
                status: "paused"
            )
            
            let updated = try await apiClient.updateSession(
                sessionId: session.id,
                request: updateRequest
            )
            XCTAssertEqual(updated.name, "Updated Session")
            XCTAssertEqual(updated.status, "paused")
            
            // Delete session
            let deleted = try await apiClient.deleteSession(sessionId: session.id)
            XCTAssertTrue(deleted, "Delete should succeed")
            
            // Verify deletion
            let remainingSessions = try await apiClient.listSessions()
            XCTAssertFalse(remainingSessions.contains { $0.id == session.id }, "Session should be deleted")
            
        } catch {
            XCTFail("Session lifecycle failed: \(error)")
        }
    }
    
    // MARK: - Projects
    
    func testProjectManagement() async throws {
        guard await isBackendRunning() else {
            throw XCTSkip("Backend not running")
        }
        
        // Create project
        let createRequest = CreateProjectRequest(
            name: "Test Project",
            path: "/tmp/test-project",
            description: "Integration test project",
            sshConfig: SSHConfig(
                host: "test.example.com",
                port: 22,
                username: "testuser"
            )
        )
        
        do {
            let project = try await apiClient.createProject(request: createRequest)
            XCTAssertFalse(project.id.isEmpty, "Project should have ID")
            XCTAssertEqual(project.name, "Test Project")
            
            print("Created project: \(project.id)")
            
            // Get project
            let fetched = try await apiClient.getProject(projectId: project.id)
            XCTAssertEqual(fetched.id, project.id)
            XCTAssertEqual(fetched.path, "/tmp/test-project")
            
            // Update project
            let updateRequest = UpdateProjectRequest(
                name: "Updated Project",
                description: "Updated description",
                environment: ["TEST_VAR": "test_value"]
            )
            
            let updated = try await apiClient.updateProject(
                projectId: project.id,
                request: updateRequest
            )
            XCTAssertEqual(updated.name, "Updated Project")
            XCTAssertEqual(updated.environment?["TEST_VAR"], "test_value")
            
            // Delete project
            let deleted = try await apiClient.deleteProject(projectId: project.id)
            XCTAssertTrue(deleted, "Delete should succeed")
            
        } catch {
            XCTFail("Project management failed: \(error)")
        }
    }
    
    // MARK: - Chat Completion (Non-Streaming)
    
    func testChatCompletion() async throws {
        guard await isBackendRunning() else {
            throw XCTSkip("Backend not running")
        }
        
        let request = ChatCompletionRequest(
            model: "claude-3-5-sonnet-20241022",
            messages: [
                ChatMessage(role: .system, content: "You are a helpful assistant."),
                ChatMessage(role: .user, content: "Say 'Hello, Integration Test!' exactly.")
            ],
            temperature: 0.1,
            maxTokens: 50,
            stream: false
        )
        
        do {
            let completion: ChatCompletionResponse = try await apiClient.createChatCompletion(
                request: request
            )
            
            XCTAssertFalse(completion.id.isEmpty, "Should have completion ID")
            XCTAssertEqual(completion.object, "chat.completion")
            XCTAssertFalse(completion.choices.isEmpty, "Should have choices")
            
            if let content = completion.choices.first?.message.content {
                print("AI Response: \(content)")
                XCTAssertFalse(content.isEmpty, "Should have response content")
            }
            
            if let usage = completion.usage {
                print("Token usage - Prompt: \(usage.promptTokens), Completion: \(usage.completionTokens), Total: \(usage.totalTokens)")
                XCTAssertGreaterThan(usage.totalTokens, 0, "Should report token usage")
            }
            
        } catch {
            XCTFail("Chat completion failed: \(error)")
        }
    }
    
    // MARK: - Streaming Chat
    
    func testStreamingChat() async throws {
        guard await isBackendRunning() else {
            throw XCTSkip("Backend not running")
        }
        
        let messageExpectation = XCTestExpectation(description: "Receive stream chunks")
        var receivedChunks: [ChatCompletionChunk] = []
        var fullContent = ""
        
        let request = ChatCompletionRequest(
            model: "claude-3-5-sonnet-20241022",
            messages: [
                ChatMessage(role: .user, content: "Count from 1 to 5 slowly.")
            ],
            temperature: 0.1,
            maxTokens: 100,
            stream: true
        )
        
        do {
            try await apiClient.streamChatCompletion(
                request: request,
                onMessage: { chunk in
                    receivedChunks.append(chunk)
                    
                    if let content = chunk.choices.first?.delta?.content {
                        fullContent += content
                        print("Chunk: \(content)")
                    }
                    
                    if receivedChunks.count >= 3 {
                        messageExpectation.fulfill()
                    }
                },
                onError: { error in
                    XCTFail("Stream error: \(error)")
                },
                onComplete: {
                    print("Stream completed. Full content: \(fullContent)")
                }
            )
            
            wait(for: [messageExpectation], timeout: 10.0)
            
            XCTAssertGreaterThan(receivedChunks.count, 0, "Should receive chunks")
            XCTAssertFalse(fullContent.isEmpty, "Should accumulate content")
            
        } catch {
            XCTFail("Streaming chat failed: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentRequests() async throws {
        guard await isBackendRunning() else {
            throw XCTSkip("Backend not running")
        }
        
        let requestCount = 10
        let startTime = Date()
        
        // Make multiple concurrent requests
        let tasks = (0..<requestCount).map { index in
            Task {
                let request = ChatCompletionRequest(
                    model: "claude-3-5-sonnet-20241022",
                    messages: [
                        ChatMessage(role: .user, content: "Say the number \(index)")
                    ],
                    maxTokens: 10,
                    stream: false
                )
                
                return try await apiClient.createChatCompletion(request: request)
            }
        }
        
        // Wait for all to complete
        let results = await withTaskGroup(of: ChatCompletionResponse?.self) { group in
            for task in tasks {
                group.addTask {
                    try? await task.value
                }
            }
            
            var responses: [ChatCompletionResponse] = []
            for await result in group {
                if let response = result {
                    responses.append(response)
                }
            }
            return responses
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(results.count, requestCount, "All requests should complete")
        print("Concurrent requests completed in \(duration) seconds")
        print("Average time per request: \(duration / Double(requestCount)) seconds")
        
        // Should benefit from connection pooling
        XCTAssertLessThan(duration, Double(requestCount) * 2.0, "Should process concurrently")
    }
    
    // MARK: - Error Handling
    
    func testErrorHandling() async throws {
        guard await isBackendRunning() else {
            throw XCTSkip("Backend not running")
        }
        
        // Test with invalid model
        let request = ChatCompletionRequest(
            model: "invalid-model-name",
            messages: [
                ChatMessage(role: .user, content: "Test")
            ],
            stream: false
        )
        
        do {
            let _: ChatCompletionResponse = try await apiClient.createChatCompletion(
                request: request
            )
            XCTFail("Should throw error for invalid model")
        } catch {
            // Expected error
            print("Expected error for invalid model: \(error)")
            XCTAssertTrue(true, "Should handle error gracefully")
        }
        
        // Test with missing authentication
        let originalKey = APIConfig.shared.apiKey
        APIConfig.shared.apiKey = nil
        
        do {
            let _: ModelsResponse = try await apiClient.request(
                endpoint: .models,
                method: .get
            )
            XCTFail("Should throw error for missing auth")
        } catch {
            // Expected error
            print("Expected error for missing auth: \(error)")
            XCTAssertTrue(true, "Should handle auth error")
        }
        
        // Restore API key
        APIConfig.shared.apiKey = originalKey
    }
    
    // MARK: - Helper Methods
    
    private func isBackendRunning() async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/health")!
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("Backend not available: \(error)")
            return false
        }
    }
}

// MARK: - Performance Test Extension

extension IntegrationTests {
    
    func testRequestLatency() async throws {
        guard await isBackendRunning() else {
            throw XCTSkip("Backend not running")
        }
        
        var latencies: [TimeInterval] = []
        
        for _ in 0..<20 {
            let start = Date()
            
            let _: ModelsResponse = try await apiClient.request(
                endpoint: .models,
                method: .get
            )
            
            let latency = Date().timeIntervalSince(start)
            latencies.append(latency)
        }
        
        let averageLatency = latencies.reduce(0, +) / Double(latencies.count)
        let minLatency = latencies.min() ?? 0
        let maxLatency = latencies.max() ?? 0
        
        print("Latency Statistics:")
        print("  Average: \(averageLatency * 1000)ms")
        print("  Min: \(minLatency * 1000)ms")
        print("  Max: \(maxLatency * 1000)ms")
        
        XCTAssertLessThan(averageLatency, 0.5, "Average latency should be under 500ms")
    }
    
    func testCachePerformance() async throws {
        guard await isBackendRunning() else {
            throw XCTSkip("Backend not running")
        }
        
        // First request (cache miss)
        let start1 = Date()
        let models1: ModelsResponse = try await apiClient.request(
            endpoint: .models,
            method: .get,
            cachePolicy: .returnCacheDataElseLoad
        )
        let time1 = Date().timeIntervalSince(start1)
        
        // Second request (cache hit)
        let start2 = Date()
        let models2: ModelsResponse = try await apiClient.request(
            endpoint: .models,
            method: .get,
            cachePolicy: .returnCacheDataElseLoad
        )
        let time2 = Date().timeIntervalSince(start2)
        
        XCTAssertEqual(models1.data.count, models2.data.count, "Should return same data")
        XCTAssertLessThan(time2, time1 * 0.1, "Cache hit should be much faster")
        
        print("Cache Performance:")
        print("  First request: \(time1 * 1000)ms")
        print("  Cached request: \(time2 * 1000)ms")
        print("  Speedup: \(time1 / time2)x")
    }
}