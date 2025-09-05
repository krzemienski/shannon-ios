#!/usr/bin/env swift

import Foundation

// Simple API connection test script
class APITester {
    let baseURL = "http://localhost:8000"
    
    func testHealth() async throws {
        print("🔍 Testing /health endpoint...")
        let url = URL(string: "\(baseURL)/health")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as! HTTPURLResponse
        print("✅ Health Status: \(httpResponse.statusCode)")
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("   Response: \(json)")
        }
    }
    
    func testModels() async throws {
        print("\n🔍 Testing /v1/models endpoint...")
        let url = URL(string: "\(baseURL)/v1/models")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as! HTTPURLResponse
        print("✅ Models Status: \(httpResponse.statusCode)")
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = json["data"] as? [[String: Any]] {
            print("   Available models:")
            for model in models {
                if let id = model["id"] as? String {
                    print("   - \(id)")
                }
            }
        }
    }
    
    func testChat() async throws {
        print("\n🔍 Testing /v1/chat/completions endpoint...")
        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "claude-opus-4-20250514",
            "messages": [
                ["role": "user", "content": "Say hello in 3 words"]
            ],
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        print("✅ Chat Status: \(httpResponse.statusCode)")
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                print("   Response: \(content)")
            }
        }
    }
    
    func testSSE() async throws {
        print("\n🔍 Testing SSE streaming...")
        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "model": "claude-opus-4-20250514",
            "messages": [
                ["role": "user", "content": "Count to 3"]
            ],
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let httpResponse = response as! HTTPURLResponse
        print("✅ SSE Status: \(httpResponse.statusCode)")
        print("   Streaming response chunks:")
        
        var eventCount = 0
        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let data = String(line.dropFirst(6))
                if data != "[DONE]" {
                    eventCount += 1
                    if eventCount <= 5 {
                        print("   Chunk \(eventCount): \(data.prefix(50))...")
                    }
                }
            }
            if eventCount >= 5 && line.hasPrefix("data: [DONE]") {
                print("   Stream completed successfully!")
                break
            }
        }
    }
    
    func runAllTests() async {
        print("🚀 Claude Code iOS API Connection Test")
        print("=" * 50)
        
        do {
            try await testHealth()
            try await testModels()
            try await testChat()
            try await testSSE()
            
            print("\n✅ All API tests passed!")
            print("=" * 50)
        } catch {
            print("\n❌ Error: \(error)")
            print("=" * 50)
        }
    }
}

// Create extension for String multiplication
extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

// Run tests
let tester = APITester()
await tester.runAllTests()