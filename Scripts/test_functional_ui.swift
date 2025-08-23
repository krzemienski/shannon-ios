#!/usr/bin/env swift

import Foundation

// Test script to verify backend connectivity for functional UI tests
// This simulates what the UI tests would do

let backendURL = "http://localhost:8000"
let testResults = NSMutableArray()
var testsPassed = 0
var testsFailed = 0

func testEndpoint(name: String, endpoint: String, expectedStatus: Int = 200) {
    print("\n🔍 Testing: \(name)")
    print("   URL: \(backendURL)\(endpoint)")
    
    guard let url = URL(string: "\(backendURL)\(endpoint)") else {
        print("   ❌ Invalid URL")
        testsFailed += 1
        return
    }
    
    let semaphore = DispatchSemaphore(value: 0)
    var testPassed = false
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("   ❌ Error: \(error.localizedDescription)")
        } else if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == expectedStatus {
                print("   ✅ Status: \(httpResponse.statusCode)")
                testPassed = true
            } else {
                print("   ❌ Status: \(httpResponse.statusCode) (expected \(expectedStatus))")
            }
            
            if let data = data, data.count > 0 {
                print("   📦 Response size: \(data.count) bytes")
            }
        }
        semaphore.signal()
    }
    
    task.resume()
    _ = semaphore.wait(timeout: .now() + 5)
    
    if testPassed {
        testsPassed += 1
    } else {
        testsFailed += 1
    }
}

func testWebSocket() {
    print("\n🔍 Testing: WebSocket Connection")
    print("   URL: ws://localhost:8000/v1/chat/stream")
    
    // WebSocket test would require more complex setup
    // For now, just check if the endpoint responds to HTTP upgrade
    guard let url = URL(string: "http://localhost:8000/v1/chat/stream") else {
        print("   ❌ Invalid URL")
        testsFailed += 1
        return
    }
    
    var request = URLRequest(url: url)
    request.setValue("websocket", forHTTPHeaderField: "Upgrade")
    request.setValue("Upgrade", forHTTPHeaderField: "Connection")
    
    let semaphore = DispatchSemaphore(value: 0)
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let httpResponse = response as? HTTPURLResponse {
            // WebSocket endpoints typically return 400 or 426 when accessed via HTTP
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 426 {
                print("   ✅ WebSocket endpoint exists (HTTP status: \(httpResponse.statusCode))")
                testsPassed += 1
            } else {
                print("   ⚠️  Unexpected status: \(httpResponse.statusCode)")
                testsFailed += 1
            }
        } else {
            print("   ❌ No response")
            testsFailed += 1
        }
        semaphore.signal()
    }
    
    task.resume()
    _ = semaphore.wait(timeout: .now() + 5)
}

// Main test execution
print("==========================================")
print("Claude Code iOS - Functional UI Test Suite")
print("Backend URL: \(backendURL)")
print("==========================================")

// Test user journey endpoints
print("\n📋 User Journey: App Launch & Backend Connection")

// 1. Health check
testEndpoint(name: "Health Check", endpoint: "/health")

// 2. Get models list
testEndpoint(name: "Models List", endpoint: "/v1/models")

// 3. Get projects
testEndpoint(name: "Projects List", endpoint: "/v1/projects")

// 4. Get sessions
testEndpoint(name: "Sessions List", endpoint: "/v1/sessions")

// 5. Test WebSocket
testWebSocket()

// 6. Test chat completions (might fail without API key)
print("\n📋 User Journey: Message Sending")
testEndpoint(name: "Chat Completions", endpoint: "/v1/chat/completions", expectedStatus: 503)

// Summary
print("\n==========================================")
print("Test Summary")
print("==========================================")
print("✅ Tests Passed: \(testsPassed)")
print("❌ Tests Failed: \(testsFailed)")

if testsFailed == 0 {
    print("\n🎉 All functional connectivity tests PASSED!")
    print("The backend at \(backendURL) is ready for UI testing.")
    exit(0)
} else {
    print("\n⚠️  Some tests failed. Backend may not be fully configured.")
    exit(1)
}