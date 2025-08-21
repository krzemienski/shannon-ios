//
//  MockAPIClient.swift
//  ClaudeCodeTests
//
//  Mock API client for testing
//

import Foundation
import Combine
@testable import ClaudeCode

/// Mock API client for testing
class MockAPIClient: APIClientProtocol {
    
    // MARK: - Properties
    
    var shouldSucceed = true
    var responseDelay: TimeInterval = 0.1
    var mockResponses: [String: Any] = [:]
    var recordedRequests: [URLRequest] = []
    
    // Error to throw when shouldSucceed is false
    var mockError: Error = AppError.networkError("Mock network error")
    
    // MARK: - APIClientProtocol
    
    var baseURL: String = "https://mock.api.com"
    var apiKey: String? = "mock-api-key"
    
    func setBaseURL(_ url: String) {
        baseURL = url
    }
    
    func setAPIKey(_ key: String) {
        apiKey = key
    }
    
    func testConnection() async throws -> Bool {
        try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        
        if !shouldSucceed {
            throw mockError
        }
        
        return true
    }
    
    func sendMessage(_ message: Message, in conversationId: String) async throws -> Message {
        recordRequest(endpoint: "/messages", method: "POST")
        
        try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        
        if !shouldSucceed {
            throw mockError
        }
        
        // Return a mock assistant response
        return Message(
            id: UUID().uuidString,
            role: .assistant,
            content: mockResponses["message"] as? String ?? "Mock response",
            timestamp: Date()
        )
    }
    
    func streamMessage(_ message: Message, in conversationId: String) -> AsyncThrowingStream<StreamEvent, Error> {
        recordRequest(endpoint: "/messages/stream", method: "POST")
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
                    
                    if !shouldSucceed {
                        continuation.finish(throwing: mockError)
                        return
                    }
                    
                    // Simulate streaming response
                    let content = mockResponses["stream"] as? String ?? "Mock streaming response"
                    let chunks = content.split(separator: " ")
                    
                    for chunk in chunks {
                        continuation.yield(.contentDelta(String(chunk) + " "))
                        try await Task.sleep(nanoseconds: 50_000_000) // 50ms between chunks
                    }
                    
                    continuation.yield(.messageComplete)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func getConversations() async throws -> [Conversation] {
        recordRequest(endpoint: "/conversations", method: "GET")
        
        try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        
        if !shouldSucceed {
            throw mockError
        }
        
        if let conversations = mockResponses["conversations"] as? [Conversation] {
            return conversations
        }
        
        // Return mock conversations
        return [
            TestDataFactory.makeConversation(id: "1", title: "Mock Conversation 1"),
            TestDataFactory.makeConversation(id: "2", title: "Mock Conversation 2")
        ]
    }
    
    func getTools() async throws -> [Tool] {
        recordRequest(endpoint: "/tools", method: "GET")
        
        try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        
        if !shouldSucceed {
            throw mockError
        }
        
        if let tools = mockResponses["tools"] as? [Tool] {
            return tools
        }
        
        // Return mock tools
        return [
            TestDataFactory.makeTool(name: "mock_tool_1", description: "Mock Tool 1"),
            TestDataFactory.makeTool(name: "mock_tool_2", description: "Mock Tool 2")
        ]
    }
    
    func executeTool(_ tool: Tool, with input: [String: Any]) async throws -> ToolExecutionResult {
        recordRequest(endpoint: "/tools/execute", method: "POST")
        
        try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        
        if !shouldSucceed {
            throw mockError
        }
        
        if let result = mockResponses["toolResult"] as? ToolExecutionResult {
            return result
        }
        
        // Return mock result
        return ToolExecutionResult(
            toolName: tool.name,
            status: .success,
            output: ["result": "Mock tool execution successful"],
            executionTime: responseDelay,
            error: nil
        )
    }
    
    func getProjects() async throws -> [Project] {
        recordRequest(endpoint: "/projects", method: "GET")
        
        try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        
        if !shouldSucceed {
            throw mockError
        }
        
        if let projects = mockResponses["projects"] as? [Project] {
            return projects
        }
        
        // Return mock projects
        return [
            TestDataFactory.makeProject(id: "1", name: "Mock Project 1"),
            TestDataFactory.makeProject(id: "2", name: "Mock Project 2")
        ]
    }
    
    func clearCache() async {
        mockResponses.removeAll()
        recordedRequests.removeAll()
    }
    
    // MARK: - Helper Methods
    
    private func recordRequest(endpoint: String, method: String) {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        recordedRequests.append(request)
    }
    
    /// Configure a specific mock response
    func setMockResponse<T>(_ response: T, for key: String) {
        mockResponses[key] = response
    }
    
    /// Verify a request was made
    func verifyRequest(endpoint: String, method: String) -> Bool {
        return recordedRequests.contains { request in
            request.url?.path == endpoint && request.httpMethod == method
        }
    }
    
    /// Reset all mock state
    func reset() {
        shouldSucceed = true
        responseDelay = 0.1
        mockResponses.removeAll()
        recordedRequests.removeAll()
        mockError = AppError.networkError("Mock network error")
    }
}