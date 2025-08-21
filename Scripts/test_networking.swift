#!/usr/bin/env swift

//
//  test_networking.swift
//  Quick networking test script
//
//  Usage: ./Scripts/test_networking.swift
//

import Foundation

// MARK: - Configuration

let baseURL = "http://localhost:8000"
let apiKey = "test-api-key"

// MARK: - Test Helpers

func printSection(_ title: String) {
    print("\n" + "=" * 60)
    print("  \(title)")
    print("=" * 60)
}

func printTest(_ name: String, passed: Bool, details: String = "") {
    let status = passed ? "✅ PASS" : "❌ FAIL"
    print("\(status): \(name)")
    if !details.isEmpty {
        print("         \(details)")
    }
}

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// MARK: - API Tests

func testHealthEndpoint() async -> Bool {
    do {
        let url = URL(string: "\(baseURL)/health")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            printTest("Health Check", passed: false, details: "Invalid response type")
            return false
        }
        
        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                printTest("Health Check", passed: true, details: "Status: \(status)")
                return true
            }
        }
        
        printTest("Health Check", passed: false, details: "Status code: \(httpResponse.statusCode)")
        return false
        
    } catch {
        printTest("Health Check", passed: false, details: "Error: \(error.localizedDescription)")
        return false
    }
}

func testModelsEndpoint() async -> Bool {
    do {
        let url = URL(string: "\(baseURL)/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            printTest("Models List", passed: false, details: "Invalid response type")
            return false
        }
        
        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["data"] as? [[String: Any]] {
                let modelNames = models.compactMap { $0["id"] as? String }.joined(separator: ", ")
                printTest("Models List", passed: true, details: "Found \(models.count) models: \(modelNames)")
                return true
            }
        }
        
        printTest("Models List", passed: false, details: "Status code: \(httpResponse.statusCode)")
        return false
        
    } catch {
        printTest("Models List", passed: false, details: "Error: \(error.localizedDescription)")
        return false
    }
}

func testChatCompletion() async -> Bool {
    do {
        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "messages": [
                ["role": "user", "content": "Say 'Hello, Test!' exactly."]
            ],
            "max_tokens": 20,
            "temperature": 0.1,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            printTest("Chat Completion", passed: false, details: "Invalid response type")
            return false
        }
        
        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                printTest("Chat Completion", passed: true, details: "Response: \(content)")
                return true
            }
        }
        
        printTest("Chat Completion", passed: false, details: "Status code: \(httpResponse.statusCode)")
        return false
        
    } catch {
        printTest("Chat Completion", passed: false, details: "Error: \(error.localizedDescription)")
        return false
    }
}

func testStreamingChat() async -> Bool {
    do {
        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "messages": [
                ["role": "user", "content": "Count from 1 to 3."]
            ],
            "max_tokens": 50,
            "temperature": 0.1,
            "stream": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            printTest("Streaming Chat", passed: false, details: "Invalid response type")
            return false
        }
        
        if httpResponse.statusCode == 200 {
            var chunks = 0
            var content = ""
            
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    if jsonString != "[DONE]",
                       let data = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any],
                       let deltaContent = delta["content"] as? String {
                        content += deltaContent
                        chunks += 1
                    }
                }
                
                // Stop after receiving some chunks
                if chunks >= 3 {
                    break
                }
            }
            
            printTest("Streaming Chat", passed: chunks > 0, details: "Received \(chunks) chunks, content: \(content)")
            return chunks > 0
        }
        
        printTest("Streaming Chat", passed: false, details: "Status code: \(httpResponse.statusCode)")
        return false
        
    } catch {
        printTest("Streaming Chat", passed: false, details: "Error: \(error.localizedDescription)")
        return false
    }
}

func testSessionManagement() async -> Bool {
    do {
        // Create session
        let createURL = URL(string: "\(baseURL)/v1/sessions")!
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let createBody: [String: Any] = [
            "project_path": "/tmp/test-project",
            "name": "Test Session"
        ]
        
        createRequest.httpBody = try JSONSerialization.data(withJSONObject: createBody)
        
        let (createData, createResponse) = try await URLSession.shared.data(for: createRequest)
        
        guard let httpCreateResponse = createResponse as? HTTPURLResponse,
              httpCreateResponse.statusCode == 200 || httpCreateResponse.statusCode == 201 else {
            printTest("Session Create", passed: false, details: "Failed to create session")
            return false
        }
        
        guard let createJson = try? JSONSerialization.jsonObject(with: createData) as? [String: Any],
              let sessionId = createJson["id"] as? String else {
            printTest("Session Create", passed: false, details: "No session ID in response")
            return false
        }
        
        printTest("Session Create", passed: true, details: "Session ID: \(sessionId)")
        
        // List sessions
        let listURL = URL(string: "\(baseURL)/v1/sessions")!
        var listRequest = URLRequest(url: listURL)
        listRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (listData, listResponse) = try await URLSession.shared.data(for: listRequest)
        
        guard let httpListResponse = listResponse as? HTTPURLResponse,
              httpListResponse.statusCode == 200 else {
            printTest("Session List", passed: false, details: "Failed to list sessions")
            return false
        }
        
        if let listJson = try? JSONSerialization.jsonObject(with: listData) as? [String: Any],
           let sessions = listJson["data"] as? [[String: Any]] ?? listJson["sessions"] as? [[String: Any]] {
            printTest("Session List", passed: true, details: "Found \(sessions.count) sessions")
        }
        
        // Delete session
        let deleteURL = URL(string: "\(baseURL)/v1/sessions/\(sessionId)")!
        var deleteRequest = URLRequest(url: deleteURL)
        deleteRequest.httpMethod = "DELETE"
        deleteRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (_, deleteResponse) = try await URLSession.shared.data(for: deleteRequest)
        
        guard let httpDeleteResponse = deleteResponse as? HTTPURLResponse,
              httpDeleteResponse.statusCode == 200 || httpDeleteResponse.statusCode == 204 else {
            printTest("Session Delete", passed: false, details: "Failed to delete session")
            return false
        }
        
        printTest("Session Delete", passed: true, details: "Session deleted successfully")
        return true
        
    } catch {
        printTest("Session Management", passed: false, details: "Error: \(error.localizedDescription)")
        return false
    }
}

// MARK: - Main Test Runner

Task {
    print("\n🚀 Claude Code iOS - Networking Test Suite")
    print("Testing backend at: \(baseURL)")
    
    var totalTests = 0
    var passedTests = 0
    
    // Test basic connectivity
    printSection("Basic Connectivity")
    
    if await testHealthEndpoint() {
        passedTests += 1
    }
    totalTests += 1
    
    // Test API endpoints
    printSection("API Endpoints")
    
    if await testModelsEndpoint() {
        passedTests += 1
    }
    totalTests += 1
    
    if await testChatCompletion() {
        passedTests += 1
    }
    totalTests += 1
    
    if await testStreamingChat() {
        passedTests += 1
    }
    totalTests += 1
    
    // Test session management
    printSection("Session Management")
    
    if await testSessionManagement() {
        passedTests += 1
    }
    totalTests += 1
    
    // Summary
    printSection("Test Summary")
    
    let percentage = Double(passedTests) / Double(totalTests) * 100
    let status = passedTests == totalTests ? "✅ ALL TESTS PASSED" : "⚠️  SOME TESTS FAILED"
    
    print("\n\(status)")
    print("Passed: \(passedTests)/\(totalTests) (\(String(format: "%.1f", percentage))%)")
    
    if passedTests < totalTests {
        print("\n⚠️  Please ensure the backend is running at \(baseURL)")
        print("   Run: cd claude-code-api && ./venv/bin/python -m claude_code_api.main")
    }
    
    print("\n" + "=" * 60 + "\n")
    
    // Exit with appropriate code
    exit(passedTests == totalTests ? 0 : 1)
}

// Keep the process alive for async operations
RunLoop.main.run()