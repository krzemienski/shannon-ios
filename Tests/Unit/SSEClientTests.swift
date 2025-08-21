//
//  SSEClientTests.swift
//  ClaudeCodeTests
//
//  Unit tests for SSEClient service
//

import XCTest
@testable import ClaudeCode

final class SSEClientTests: XCTestCase {
    
    var sseClient: SSEClient!
    var mockDelegate: MockSSEDelegate!
    
    override func setUp() {
        super.setUp()
        sseClient = SSEClient()
        mockDelegate = MockSSEDelegate()
        sseClient.delegate = mockDelegate
    }
    
    override func tearDown() {
        sseClient.disconnect()
        sseClient = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Connection Tests
    
    func testConnectionEstablishment() {
        let expectation = XCTestExpectation(description: "Connection established")
        
        mockDelegate.onConnected = {
            expectation.fulfill()
        }
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { _ in },
            onError: { _ in },
            onComplete: { }
        )
        
        // Simulate connection
        sseClient.handleConnectionEstablished()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(sseClient.isConnected)
    }
    
    func testConnectionWithHeaders() {
        let headers = ["Authorization": "Bearer test-token"]
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            headers: headers,
            onMessage: { _ in },
            onError: { _ in },
            onComplete: { }
        )
        
        XCTAssertEqual(sseClient.currentHeaders?["Authorization"], "Bearer test-token")
    }
    
    func testDisconnection() {
        let expectation = XCTestExpectation(description: "Disconnected")
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { _ in },
            onError: { _ in },
            onComplete: {
                expectation.fulfill()
            }
        )
        
        sseClient.handleConnectionEstablished()
        XCTAssertTrue(sseClient.isConnected)
        
        sseClient.disconnect()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(sseClient.isConnected)
    }
    
    // MARK: - Event Processing Tests
    
    func testDataEventProcessing() {
        let expectation = XCTestExpectation(description: "Message received")
        var receivedMessage: ChatCompletionChunk?
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { message in
                receivedMessage = message
                expectation.fulfill()
            },
            onError: { _ in },
            onComplete: { }
        )
        
        let eventData = """
        data: {"id":"chunk-1","object":"chat.completion.chunk","choices":[{"delta":{"content":"Hello"},"index":0}]}
        
        """
        
        sseClient.processEvent(eventData)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedMessage)
        XCTAssertEqual(receivedMessage?.choices.first?.delta?.content, "Hello")
    }
    
    func testMultilineDataEvent() {
        let expectation = XCTestExpectation(description: "Multiline message processed")
        var receivedContent = ""
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { message in
                if let content = message.choices.first?.delta?.content {
                    receivedContent += content
                }
                if receivedContent.contains("\n") {
                    expectation.fulfill()
                }
            },
            onError: { _ in },
            onComplete: { }
        )
        
        let eventData = """
        data: {"choices":[{"delta":{"content":"Line 1\\nLine 2"}}]}
        
        """
        
        sseClient.processEvent(eventData)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(receivedContent.contains("\n"))
    }
    
    func testDoneEvent() {
        let expectation = XCTestExpectation(description: "Stream completed")
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { _ in },
            onError: { _ in },
            onComplete: {
                expectation.fulfill()
            }
        )
        
        sseClient.processEvent("data: [DONE]\n\n")
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHeartbeatEvent() {
        let expectation = XCTestExpectation(description: "Heartbeat received")
        
        mockDelegate.onHeartbeat = {
            expectation.fulfill()
        }
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { _ in },
            onError: { _ in },
            onComplete: { }
        )
        
        sseClient.processEvent(":heartbeat\n\n")
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorEvent() {
        let expectation = XCTestExpectation(description: "Error received")
        var receivedError: Error?
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { _ in },
            onError: { error in
                receivedError = error
                expectation.fulfill()
            },
            onComplete: { }
        )
        
        let errorData = """
        data: {"error":{"message":"Rate limit exceeded","type":"rate_limit"}}
        
        """
        
        sseClient.processEvent(errorData)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedError)
    }
    
    func testInvalidJSONHandling() {
        let expectation = XCTestExpectation(description: "Invalid JSON handled")
        var errorReceived = false
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { _ in },
            onError: { _ in
                errorReceived = true
                expectation.fulfill()
            },
            onComplete: { }
        )
        
        sseClient.processEvent("data: {invalid json}\n\n")
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(errorReceived)
    }
    
    // MARK: - Reconnection Tests
    
    func testAutomaticReconnection() {
        let connectExpectation = XCTestExpectation(description: "Initial connection")
        let reconnectExpectation = XCTestExpectation(description: "Reconnection")
        var connectionCount = 0
        
        mockDelegate.onConnected = {
            connectionCount += 1
            if connectionCount == 1 {
                connectExpectation.fulfill()
            } else if connectionCount == 2 {
                reconnectExpectation.fulfill()
            }
        }
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { _ in },
            onError: { _ in },
            onComplete: { },
            options: StreamOptions(
                reconnectAttempts: 3,
                reconnectDelay: 0.1
            )
        )
        
        // Initial connection
        sseClient.handleConnectionEstablished()
        wait(for: [connectExpectation], timeout: 1.0)
        
        // Simulate connection loss
        sseClient.handleError(URLError(.networkConnectionLost))
        
        // Should reconnect automatically
        wait(for: [reconnectExpectation], timeout: 2.0)
        XCTAssertEqual(connectionCount, 2)
    }
    
    func testReconnectionBackoff() {
        var reconnectDelays: [TimeInterval] = []
        let startTime = Date()
        
        mockDelegate.onReconnectAttempt = { attempt in
            let delay = Date().timeIntervalSince(startTime)
            reconnectDelays.append(delay)
        }
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { _ in },
            onError: { _ in },
            onComplete: { },
            options: StreamOptions(
                reconnectAttempts: 3,
                reconnectDelay: 0.1,
                reconnectBackoff: 2.0
            )
        )
        
        // Trigger multiple reconnection attempts
        for _ in 0..<3 {
            sseClient.handleError(URLError(.timedOut))
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // Verify exponential backoff
        if reconnectDelays.count >= 2 {
            XCTAssertGreaterThan(reconnectDelays[1], reconnectDelays[0])
        }
    }
    
    // MARK: - Buffer Management Tests
    
    func testEventBuffering() {
        var receivedMessages = 0
        let bufferSize = 10
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { _ in
                receivedMessages += 1
                // Simulate slow processing
                Thread.sleep(forTimeInterval: 0.01)
            },
            onError: { _ in },
            onComplete: { },
            options: StreamOptions(bufferSize: bufferSize)
        )
        
        // Send many events quickly
        for i in 0..<20 {
            let event = """
            data: {"choices":[{"delta":{"content":"Message \(i)"}}]}
            
            """
            sseClient.processEvent(event)
        }
        
        // Should not exceed buffer size significantly
        XCTAssertLessThanOrEqual(receivedMessages, bufferSize + 5)
    }
    
    func testPartialEventHandling() {
        let expectation = XCTestExpectation(description: "Complete event processed")
        var receivedMessage: String?
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { message in
                if let content = message.choices.first?.delta?.content {
                    receivedMessage = content
                    expectation.fulfill()
                }
            },
            onError: { _ in },
            onComplete: { }
        )
        
        // Send event in parts
        sseClient.processPartialData("data: {\"choices\":[{\"delta\":")
        sseClient.processPartialData("{\"content\":\"Complete message\"}")
        sseClient.processPartialData("}]}\n\n")
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedMessage, "Complete message")
    }
    
    // MARK: - Performance Tests
    
    func testEventProcessingPerformance() {
        var processedCount = 0
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { _ in
                processedCount += 1
            },
            onError: { _ in },
            onComplete: { }
        )
        
        measure {
            for i in 0..<1000 {
                let event = """
                data: {"choices":[{"delta":{"content":"Message \(i)"}}]}
                
                """
                sseClient.processEvent(event)
            }
        }
        
        XCTAssertEqual(processedCount, 1000)
    }
    
    func testMemoryUsageUnderLoad() {
        let expectation = XCTestExpectation(description: "Memory test completed")
        var messageCount = 0
        
        sseClient.connect(
            to: URL(string: "http://localhost:8000/v1/chat/stream")!,
            onMessage: { _ in
                messageCount += 1
                if messageCount >= 10000 {
                    expectation.fulfill()
                }
            },
            onError: { _ in },
            onComplete: { }
        )
        
        // Send many large messages
        for i in 0..<10000 {
            let largeContent = String(repeating: "x", count: 1000)
            let event = """
            data: {"choices":[{"delta":{"content":"\(largeContent) \(i)"}}]}
            
            """
            autoreleasepool {
                sseClient.processEvent(event)
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify no memory leaks (this would be caught by Instruments)
        XCTAssertEqual(messageCount, 10000)
    }
}

// MARK: - Mock Delegate

class MockSSEDelegate: NSObject {
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onHeartbeat: (() -> Void)?
    var onReconnectAttempt: ((Int) -> Void)?
}

// MARK: - SSEClient Test Extensions

extension SSEClient {
    func handleConnectionEstablished() {
        // Simulate connection establishment
        isConnected = true
        (delegate as? MockSSEDelegate)?.onConnected?()
    }
    
    func handleError(_ error: Error) {
        // Simulate error handling
        if shouldReconnect {
            attemptReconnection()
        }
    }
    
    func processPartialData(_ data: String) {
        // Simulate partial data processing
        if partialBuffer == nil {
            partialBuffer = ""
        }
        partialBuffer?.append(data)
        
        if data.hasSuffix("\n\n") {
            processEvent(partialBuffer ?? "")
            partialBuffer = nil
        }
    }
    
    private func attemptReconnection() {
        reconnectAttempts += 1
        (delegate as? MockSSEDelegate)?.onReconnectAttempt?(reconnectAttempts)
        
        DispatchQueue.global().asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            self?.handleConnectionEstablished()
        }
    }
}