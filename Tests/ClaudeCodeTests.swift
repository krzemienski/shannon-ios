//
//  ClaudeCodeTests.swift
//  ClaudeCodeTests
//
//  Base test configuration and shared test utilities
//

import XCTest
@testable import ClaudeCode

/// Base test case class with common setup and teardown
class ClaudeCodeTestCase: XCTestCase {
    
    // MARK: - Properties
    
    var dependencyContainer: DependencyContainer!
    var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create test dependency container
        dependencyContainer = DependencyContainer.createForTesting()
        
        // Reset cancellables
        cancellables = []
        
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
    
    override func tearDownWithError() throws {
        // Clean up
        dependencyContainer = nil
        cancellables.removeAll()
        
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    /// Wait for async expectations
    func waitForAsync(
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line,
        _ block: @escaping () async throws -> Void
    ) {
        let expectation = expectation(description: "Async operation")
        
        Task {
            do {
                try await block()
                expectation.fulfill()
            } catch {
                XCTFail("Async operation failed: \(error)", file: file, line: line)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: timeout) { error in
            if let error = error {
                XCTFail("Timeout: \(error)", file: file, line: line)
            }
        }
    }
    
    /// Wait for published value changes
    func waitForPublished<T>(
        _ publisher: Published<T>.Publisher,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line,
        validation: @escaping (T) -> Bool
    ) {
        let expectation = expectation(description: "Published value change")
        
        publisher
            .filter(validation)
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        waitForExpectations(timeout: timeout) { error in
            if let error = error {
                XCTFail("Timeout waiting for published value: \(error)", file: file, line: line)
            }
        }
    }
    
    /// Create a mock API response
    func mockAPIResponse<T: Encodable>(
        _ data: T,
        statusCode: Int = 200
    ) throws -> (Data, URLResponse) {
        let jsonData = try JSONEncoder().encode(data)
        let response = HTTPURLResponse(
            url: URL(string: "https://api.test.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (jsonData, response)
    }
    
    /// Assert no memory leaks
    func assertNoMemoryLeak(
        _ object: AnyObject,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        addTeardownBlock { [weak object] in
            XCTAssertNil(object, "Memory leak detected", file: file, line: line)
        }
    }
}

// MARK: - Test Extensions

extension XCTestCase {
    
    /// Create a test expectation with timeout
    func expectation(
        timeout: TimeInterval = 5.0,
        description: String = "Test expectation"
    ) -> XCTestExpectation {
        let exp = expectation(description: description)
        waitForExpectations(timeout: timeout)
        return exp
    }
    
    /// Measure async performance
    func measureAsync(
        metrics: [XCTMetric] = [XCTClockMetric()],
        block: @escaping () async throws -> Void
    ) {
        measure(metrics: metrics) {
            let expectation = expectation(description: "Performance measurement")
            
            Task {
                try await block()
                expectation.fulfill()
            }
            
            waitForExpectations(timeout: 60.0)
        }
    }
}

// MARK: - Test Helpers

/// Test data factory
struct TestDataFactory {
    
    static func makeConversation(
        id: String = UUID().uuidString,
        title: String = "Test Conversation"
    ) -> Conversation {
        Conversation(
            id: id,
            title: title,
            messages: [],
            createdAt: Date(),
            updatedAt: Date(),
            metadata: ConversationMetadata(
                model: "claude-3-5-haiku-20241022",
                temperature: 0.7,
                maxTokens: 4096
            )
        )
    }
    
    static func makeMessage(
        role: MessageRole = .user,
        content: String = "Test message"
    ) -> Message {
        Message(
            id: UUID().uuidString,
            role: role,
            content: content,
            timestamp: Date()
        )
    }
    
    static func makeTool(
        name: String = "test_tool",
        description: String = "Test tool"
    ) -> Tool {
        Tool(
            name: name,
            description: description,
            inputSchema: [:],
            category: .general
        )
    }
    
    static func makeProject(
        id: String = UUID().uuidString,
        name: String = "Test Project"
    ) -> Project {
        Project(
            id: id,
            name: name,
            path: "/test/path",
            createdAt: Date(),
            updatedAt: Date(),
            metadata: ProjectMetadata(
                language: "Swift",
                framework: "SwiftUI",
                dependencies: []
            )
        )
    }
}

// MARK: - Async Test Helpers

extension XCTestCase {
    
    /// Run async test with automatic cleanup
    func runAsyncTest(
        timeout: TimeInterval = 10.0,
        _ block: @escaping () async throws -> Void
    ) {
        let expectation = expectation(description: "Async test")
        
        Task { @MainActor in
            do {
                try await block()
            } catch {
                XCTFail("Test failed with error: \(error)")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout)
    }
}