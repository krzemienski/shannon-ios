import Foundation

// MARK: - Task 179: Model Test Utilities

// MARK: - Mock Data Generators
public struct MockDataGenerator {
    
    // MARK: - Random Data Generation
    
    /// Generate random string
    public static func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    /// Generate random email
    public static func randomEmail() -> String {
        "\(randomString(length: 8))@\(randomString(length: 6)).com"
    }
    
    /// Generate random URL
    public static func randomURL() -> String {
        "https://\(randomString(length: 8)).com/\(randomString(length: 5))"
    }
    
    /// Generate random UUID string
    public static func randomUUID() -> String {
        UUID().uuidString
    }
    
    /// Generate random date
    public static func randomDate(daysBack: Int = 30) -> Date {
        let timeInterval = TimeInterval.random(in: 0...(Double(daysBack) * 86400))
        return Date().addingTimeInterval(-timeInterval)
    }
    
    // MARK: - Chat Models
    
    /// Generate mock chat messages
    public static func mockChatMessages(count: Int = 5) -> [ChatMessage] {
        var messages: [ChatMessage] = []
        
        messages.append(.system("You are a helpful assistant for testing."))
        
        for i in 0..<count {
            if i % 2 == 0 {
                messages.append(.user("Test question \(i + 1)"))
            } else {
                messages.append(.assistant("Test response \(i + 1)"))
            }
        }
        
        return messages
    }
    
    /// Generate mock chat completion request
    public static func mockChatRequest() -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: ["gpt-3.5-turbo", "gpt-4", "claude-3-opus"].randomElement()!,
            messages: mockChatMessages(count: 3),
            temperature: Double.random(in: 0...1),
            maxTokens: Int.random(in: 100...2000),
            stream: Bool.random()
        )
    }
    
    /// Generate mock chat completion response
    public static func mockChatResponse() -> ChatCompletionResponse {
        let choice = ChatChoice(
            index: 0,
            message: .assistant("This is a mock response."),
            finishReason: "stop"
        )
        
        return ChatCompletionResponse(
            id: "chatcmpl-\(randomString(length: 8))",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-3.5-turbo",
            choices: [choice],
            usage: Usage(
                promptTokens: Int.random(in: 10...100),
                completionTokens: Int.random(in: 10...100),
                totalTokens: Int.random(in: 20...200)
            )
        )
    }
    
    /// Generate mock streaming chunk
    public static func mockStreamingChunk() -> ChatCompletionChunk {
        let delta = ChatCompletionDelta(
            role: .assistant,
            content: randomString(length: 20),
            toolCalls: nil
        )
        
        let choice = ChatCompletionStreamChoice(
            index: 0,
            delta: delta,
            finishReason: nil
        )
        
        return ChatCompletionChunk(
            id: "chatcmpl-\(randomString(length: 8))",
            object: "chat.completion.chunk",
            created: Int(Date().timeIntervalSince1970),
            model: "gpt-3.5-turbo",
            choices: [choice]
        )
    }
    
    // MARK: - Tool Models
    
    /// Generate mock tool
    public static func mockTool() -> ChatTool {
        ChatTool.function(
            name: "mock_tool_\(randomString(length: 5))",
            description: "A mock tool for testing",
            parameters: ToolParameters(
                type: "object",
                properties: [
                    "input": PropertySchema(
                        type: "string",
                        description: "Test input"
                    )
                ],
                required: ["input"]
            )
        )
    }
    
    /// Generate mock tool call
    public static func mockToolCall() -> ToolCall {
        ToolCall(
            id: "call_\(randomString(length: 8))",
            type: "function",
            function: FunctionCall(
                name: "mock_function",
                arguments: "{\"input\": \"test\"}"
            )
        )
    }
    
    // MARK: - Project Models
    
    /// Generate mock project
    public static func mockProject() -> ProjectInfo {
        var project = ProjectInfo.new(
            name: "Mock Project \(randomString(length: 5))",
            path: "/mock/path/\(randomString(length: 8))",
            description: "A mock project for testing"
        )
        
        project.metadata = ProjectMetadata(
            language: ["Swift", "Python", "JavaScript", "TypeScript"].randomElement()!,
            framework: ["SwiftUI", "UIKit", "React", "Vue"].randomElement()!,
            version: "\(Int.random(in: 1...3)).\(Int.random(in: 0...9)).\(Int.random(in: 0...9))",
            dependencies: (0..<Int.random(in: 1...5)).map { _ in randomString(length: 8) },
            statistics: ProjectStatistics(
                files: Int.random(in: 10...1000),
                lines: Int.random(in: 100...100000),
                size: Int64.random(in: 1024...1024*1024*100),
                lastCommit: randomDate(daysBack: 7)
            )
        )
        
        project.isActive = Bool.random()
        project.isFavorite = Bool.random()
        
        return project
    }
    
    // MARK: - Session Models
    
    /// Generate mock session
    public static func mockSession() -> SessionInfo {
        var session = SessionInfo.new(
            name: "Mock Session \(randomString(length: 5))",
            projectId: randomUUID()
        )
        
        session.messages = mockChatMessages(count: Int.random(in: 2...10))
        
        session.stats = SessionStats(
            messageCount: session.messages.count,
            totalTokens: Int.random(in: 100...10000),
            totalCost: Double.random(in: 0.01...10.0),
            averageResponseTime: Double.random(in: 0.1...5.0)
        )
        
        return session
    }
    
    // MARK: - SSH Models
    
    /// Generate mock SSH config
    public static func mockSSHConfig() -> SSHConfig {
        if Bool.random() {
            return SSHConfig.withPassword(
                name: "Mock Server \(randomString(length: 5))",
                host: "\(randomString(length: 8)).example.com",
                username: "user_\(randomString(length: 5))",
                password: randomString(length: 12),
                port: [22, 2222, 8022].randomElement()!
            )
        } else {
            return SSHConfig.withKey(
                name: "Mock Server \(randomString(length: 5))",
                host: "\(randomString(length: 8)).example.com",
                username: "user_\(randomString(length: 5))",
                privateKeyPath: "~/.ssh/id_\(randomString(length: 5))",
                port: [22, 2222, 8022].randomElement()!
            )
        }
    }
    
    /// Generate mock host snapshot
    public static func mockHostSnapshot() -> HostSnapshot {
        HostSnapshot(
            hostname: "host-\(randomString(length: 8))",
            system: SystemInfo(
                os: ["macOS", "Linux", "Ubuntu", "CentOS"].randomElement()!,
                kernel: "5.10.0-\(Int.random(in: 1...100))",
                architecture: ["x86_64", "arm64", "aarch64"].randomElement()!,
                uptime: TimeInterval.random(in: 0...86400*30),
                loadAverage: (0..<3).map { _ in Double.random(in: 0...4) }
            ),
            cpu: CPUInfo(
                model: ["Intel Core i7", "Intel Core i9", "Apple M1", "AMD Ryzen 9"].randomElement()!,
                cores: [4, 8, 16, 32].randomElement()!,
                threads: [8, 16, 32, 64].randomElement()!,
                frequency: Double.random(in: 2.0...5.0),
                usage: Double.random(in: 0...100),
                temperature: Double.random(in: 30...90)
            ),
            memory: MemoryInfo(
                total: Int64.random(in: 4...64) * 1024 * 1024 * 1024,
                used: Int64.random(in: 1...32) * 1024 * 1024 * 1024,
                free: Int64.random(in: 1...32) * 1024 * 1024 * 1024,
                available: Int64.random(in: 1...32) * 1024 * 1024 * 1024,
                cached: Int64.random(in: 0...16) * 1024 * 1024 * 1024,
                buffers: Int64.random(in: 0...8) * 1024 * 1024 * 1024,
                swapTotal: Int64.random(in: 0...16) * 1024 * 1024 * 1024,
                swapUsed: Int64.random(in: 0...8) * 1024 * 1024 * 1024
            ),
            disk: (0..<Int.random(in: 1...3)).map { i in
                DiskInfo(
                    device: "/dev/disk\(i)",
                    mountPoint: i == 0 ? "/" : "/mnt/disk\(i)",
                    filesystem: ["ext4", "xfs", "btrfs", "apfs"].randomElement()!,
                    total: Int64.random(in: 100...2000) * 1024 * 1024 * 1024,
                    used: Int64.random(in: 10...1000) * 1024 * 1024 * 1024,
                    free: Int64.random(in: 10...1000) * 1024 * 1024 * 1024,
                    usage: Double.random(in: 0...100)
                )
            },
            network: (0..<Int.random(in: 1...3)).map { i in
                NetworkInterface(
                    name: "eth\(i)",
                    ipAddress: "192.168.\(Int.random(in: 1...255)).\(Int.random(in: 1...255))",
                    macAddress: (0..<6).map { _ in String(format: "%02X", Int.random(in: 0...255)) }.joined(separator: ":"),
                    status: ["up", "down"].randomElement()!,
                    speed: [100, 1000, 10000].randomElement()!,
                    bytesReceived: Int64.random(in: 0...1024*1024*1024),
                    bytesSent: Int64.random(in: 0...1024*1024*1024),
                    packetsReceived: Int64.random(in: 0...1000000),
                    packetsSent: Int64.random(in: 0...1000000)
                )
            }
        )
    }
    
    // MARK: - MCP Models
    
    /// Generate mock MCP server
    public static func mockMCPServer() -> MCPServer {
        MCPServer(
            name: "Mock MCP Server \(randomString(length: 5))",
            command: ["/usr/bin/node", "/usr/local/bin/python3"].randomElement()!,
            args: ["server.js", "main.py"].map { [$0] }.randomElement(),
            env: Bool.random() ? ["API_KEY": randomString(length: 32)] : nil,
            enabled: Bool.random(),
            autoStart: Bool.random(),
            capabilities: MCPCapabilities(
                tools: Bool.random(),
                resources: Bool.random(),
                prompts: Bool.random(),
                sampling: Bool.random(),
                logging: Bool.random()
            )
        )
    }
    
    /// Generate mock MCP tool
    public static func mockMCPTool() -> MCPTool {
        MCPTool(
            id: randomUUID(),
            serverId: randomUUID(),
            name: "mock_tool_\(randomString(length: 5))",
            description: "A mock MCP tool for testing",
            version: "1.0.0",
            category: ToolCategory.allCases.randomElement()!,
            inputSchema: JSONSchema(
                type: "object",
                properties: [
                    "input": PropertyDefinition(
                        type: "string",
                        description: "Test input",
                        defaultValue: "default",
                        enumValues: nil,
                        minimum: nil,
                        maximum: nil,
                        pattern: nil,
                        format: nil,
                        items: nil
                    )
                ],
                required: ["input"],
                additionalProperties: false,
                description: "Input schema for mock tool",
                examples: nil
            ),
            outputSchema: nil,
            examples: nil,
            permissions: nil,
            rateLimit: nil,
            metadata: nil,
            isDeprecated: false,
            replacedBy: nil
        )
    }
}

// MARK: - Model Comparison Utilities
public struct ModelComparison {
    
    /// Compare two Codable objects
    public static func areEqual<T: Codable & Equatable>(_ lhs: T, _ rhs: T) -> Bool {
        lhs == rhs
    }
    
    /// Get differences between two dictionaries
    public static func differences(
        between dict1: [String: Any],
        and dict2: [String: Any]
    ) -> [String: (Any?, Any?)] {
        var diffs: [String: (Any?, Any?)] = [:]
        
        let allKeys = Set(dict1.keys).union(Set(dict2.keys))
        
        for key in allKeys {
            let value1 = dict1[key]
            let value2 = dict2[key]
            
            if !isEqual(value1, value2) {
                diffs[key] = (value1, value2)
            }
        }
        
        return diffs
    }
    
    private static func isEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        if lhs == nil && rhs == nil {
            return true
        }
        
        if let lhs = lhs as? String, let rhs = rhs as? String {
            return lhs == rhs
        }
        
        if let lhs = lhs as? Int, let rhs = rhs as? Int {
            return lhs == rhs
        }
        
        if let lhs = lhs as? Double, let rhs = rhs as? Double {
            return abs(lhs - rhs) < 0.0001
        }
        
        if let lhs = lhs as? Bool, let rhs = rhs as? Bool {
            return lhs == rhs
        }
        
        if let lhs = lhs as? [String: Any], let rhs = rhs as? [String: Any] {
            return differences(between: lhs, and: rhs).isEmpty
        }
        
        if let lhs = lhs as? [Any], let rhs = rhs as? [Any] {
            guard lhs.count == rhs.count else { return false }
            for (l, r) in zip(lhs, rhs) {
                if !isEqual(l, r) {
                    return false
                }
            }
            return true
        }
        
        return false
    }
}

// MARK: - Model Validation Test Utilities
public struct ValidationTestUtilities {
    
    /// Test validation for a model
    public static func testValidation<T: Validatable>(
        model: T,
        shouldPass: Bool = true
    ) -> ValidationTestResult {
        do {
            try model.validate()
            return ValidationTestResult(
                passed: shouldPass,
                error: nil,
                message: shouldPass ? "Validation passed as expected" : "Validation passed but should have failed"
            )
        } catch let error as ValidationError {
            return ValidationTestResult(
                passed: !shouldPass,
                error: error,
                message: shouldPass ? "Validation failed: \(error.localizedDescription)" : "Validation failed as expected"
            )
        } catch {
            return ValidationTestResult(
                passed: false,
                error: error,
                message: "Unexpected error: \(error)"
            )
        }
    }
    
    /// Test multiple validation scenarios
    public static func testValidationScenarios<T: Validatable>(
        scenarios: [(model: T, shouldPass: Bool, description: String)]
    ) -> [ValidationTestResult] {
        scenarios.map { scenario in
            var result = testValidation(model: scenario.model, shouldPass: scenario.shouldPass)
            result.description = scenario.description
            return result
        }
    }
}

/// Validation test result
public struct ValidationTestResult {
    public var passed: Bool
    public var error: Error?
    public var message: String
    public var description: String?
    
    public var summary: String {
        let status = passed ? "✅" : "❌"
        let desc = description ?? "Test"
        return "\(status) \(desc): \(message)"
    }
}

// MARK: - Model Encoding/Decoding Test Utilities
public struct CodingTestUtilities {
    
    /// Test encoding and decoding of a model
    public static func testCodable<T: Codable & Equatable>(
        model: T,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) -> CodingTestResult {
        do {
            // Encode
            let data = try encoder.encode(model)
            
            // Decode
            let decoded = try decoder.decode(T.self, from: data)
            
            // Compare
            let equal = model == decoded
            
            return CodingTestResult(
                success: equal,
                encodedData: data,
                decodedModel: decoded,
                error: nil,
                message: equal ? "Encoding/decoding successful" : "Decoded model doesn't match original"
            )
        } catch {
            return CodingTestResult(
                success: false,
                encodedData: nil,
                decodedModel: nil,
                error: error,
                message: "Encoding/decoding failed: \(error)"
            )
        }
    }
    
    /// Test JSON string encoding/decoding
    public static func testJSONString<T: Codable>(
        model: T,
        prettyPrinted: Bool = true
    ) -> (success: Bool, json: String?) {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = .prettyPrinted
        }
        
        do {
            let data = try encoder.encode(model)
            let json = String(data: data, encoding: .utf8)
            return (true, json)
        } catch {
            return (false, nil)
        }
    }
}

/// Coding test result
public struct CodingTestResult {
    public let success: Bool
    public let encodedData: Data?
    public let decodedModel: Any?
    public let error: Error?
    public let message: String
    
    public var jsonString: String? {
        guard let data = encodedData else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Performance Test Utilities
public struct PerformanceTestUtilities {
    
    /// Measure time for an operation
    public static func measureTime<T>(
        operation: () throws -> T
    ) -> (result: T?, time: TimeInterval, error: Error?) {
        let start = Date()
        
        do {
            let result = try operation()
            let time = Date().timeIntervalSince(start)
            return (result, time, nil)
        } catch {
            let time = Date().timeIntervalSince(start)
            return (nil, time, error)
        }
    }
    
    /// Benchmark model operations
    public static func benchmark<T: Codable>(
        model: T,
        iterations: Int = 1000
    ) -> BenchmarkResult {
        var encodeTimes: [TimeInterval] = []
        var decodeTimes: [TimeInterval] = []
        var errors: [Error] = []
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for _ in 0..<iterations {
            // Benchmark encoding
            let encodeResult = measureTime {
                try encoder.encode(model)
            }
            
            if let error = encodeResult.error {
                errors.append(error)
            } else {
                encodeTimes.append(encodeResult.time)
                
                // Benchmark decoding
                if let data = encodeResult.result {
                    let decodeResult = measureTime {
                        try decoder.decode(T.self, from: data)
                    }
                    
                    if let error = decodeResult.error {
                        errors.append(error)
                    } else {
                        decodeTimes.append(decodeResult.time)
                    }
                }
            }
        }
        
        return BenchmarkResult(
            iterations: iterations,
            encodeTimes: encodeTimes,
            decodeTimes: decodeTimes,
            errors: errors
        )
    }
}

/// Benchmark result
public struct BenchmarkResult {
    public let iterations: Int
    public let encodeTimes: [TimeInterval]
    public let decodeTimes: [TimeInterval]
    public let errors: [Error]
    
    public var averageEncodeTime: TimeInterval {
        guard !encodeTimes.isEmpty else { return 0 }
        return encodeTimes.reduce(0, +) / Double(encodeTimes.count)
    }
    
    public var averageDecodeTime: TimeInterval {
        guard !decodeTimes.isEmpty else { return 0 }
        return decodeTimes.reduce(0, +) / Double(decodeTimes.count)
    }
    
    public var successRate: Double {
        let successfulOperations = encodeTimes.count + decodeTimes.count
        let totalOperations = iterations * 2
        return Double(successfulOperations) / Double(totalOperations)
    }
    
    public var summary: String {
        """
        Benchmark Results:
        - Iterations: \(iterations)
        - Average Encode Time: \(String(format: "%.6f", averageEncodeTime))s
        - Average Decode Time: \(String(format: "%.6f", averageDecodeTime))s
        - Success Rate: \(String(format: "%.1f", successRate * 100))%
        - Errors: \(errors.count)
        """
    }
}