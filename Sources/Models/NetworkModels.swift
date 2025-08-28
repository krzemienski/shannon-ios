import Foundation

// Type alias for compatibility with streaming chunk
public typealias ChatCompletionChunk = ChatStreamChunk
public typealias ToolFunction = ChatFunction

// MARK: - Chat Completion Models (Tasks 401-410)

/// OpenAI-compatible chat completion request
public struct ChatCompletionRequest: Codable {
    public let model: String
    public let messages: [ChatMessage]
    public let temperature: Double?
    public let maxTokens: Int?
    public let topP: Double?
    public let frequencyPenalty: Double?
    public let presencePenalty: Double?
    public let stream: Bool?
    public let stop: [String]?
    public let user: String?
    public let tools: [ChatTool]?
    public let toolChoice: ToolChoice?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
        case stream
        case stop
        case user
        case tools
        case toolChoice = "tool_choice"
    }
    
    public init(
        model: String,
        messages: [ChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        stream: Bool? = false,
        stop: [String]? = nil,
        user: String? = nil,
        tools: [ChatTool]? = nil,
        toolChoice: ToolChoice? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stream = stream
        self.stop = stop
        self.user = user
        self.tools = tools
        self.toolChoice = toolChoice
    }
}

/// Chat message in OpenAI format
public struct ChatMessage: Codable {
    public let role: String
    public let content: String?
    public let name: String?
    public let toolCalls: [ChatToolCall]?
    public let toolCallId: String?
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
        case name
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
    
    public init(
        role: String,
        content: String? = nil,
        name: String? = nil,
        toolCalls: [ChatToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}

/// Tool definition for chat
public struct ChatTool: Codable {
    public let type: String
    public let function: ChatFunction
    
    public init(function: ChatFunction) {
        self.type = "function"
        self.function = function
    }
}

/// Function definition for tools
public struct ChatFunction: Codable {
    public let name: String
    public let description: String?
    public let parameters: [String: Any]?
    
    public init(name: String, description: String? = nil, parameters: [String: Any]? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        if let params = try container.decodeIfPresent([String: AnyCodable].self, forKey: .parameters) {
            parameters = params.mapValues { $0.value }
        } else {
            parameters = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        if let params = parameters {
            try container.encode(params.mapValues { AnyCodable($0) }, forKey: .parameters)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case parameters
    }
}

/// Tool choice configuration
public enum ToolChoice: Codable {
    case none
    case auto
    case function(name: String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            switch string {
            case "none": self = .none
            case "auto": self = .auto
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown tool choice")
            }
        } else if let dict = try? container.decode([String: String].self), let name = dict["name"] {
            self = .function(name: name)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode ToolChoice")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .function(let name):
            try container.encode(["type": "function", "name": name])
        }
    }
}

/// Tool call in chat message
public struct ChatToolCall: Codable {
    public let id: String
    public let type: String
    public let function: ChatFunctionCall
    
    public init(id: String, function: ChatFunctionCall) {
        self.id = id
        self.type = "function"
        self.function = function
    }
}

/// Function call details
public struct ChatFunctionCall: Codable {
    public let name: String
    public let arguments: String
    
    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

/// Chat completion response
public struct ChatCompletionResponse: Codable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [ChatChoice]
    public let usage: ChatUsage?
    public let systemFingerprint: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case model
        case choices
        case usage
        case systemFingerprint = "system_fingerprint"
    }
}

/// Chat choice in response
public struct ChatChoice: Codable {
    public let index: Int
    public let message: ChatMessage
    public let finishReason: String?
    public let logprobs: Logprobs?
    
    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
        case logprobs
    }
}

/// Log probabilities
public struct Logprobs: Codable {
    public let content: [LogprobContent]?
}

/// Logprob content
public struct LogprobContent: Codable {
    public let token: String
    public let logprob: Double
    public let bytes: [Int]?
    public let topLogprobs: [TopLogprob]?
    
    enum CodingKeys: String, CodingKey {
        case token
        case logprob
        case bytes
        case topLogprobs = "top_logprobs"
    }
}

/// Top logprob entry
public struct TopLogprob: Codable {
    public let token: String
    public let logprob: Double
    public let bytes: [Int]?
}

/// Usage statistics
public struct ChatUsage: Codable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

/// Alternative Usage type for compatibility
public typealias Usage = ChatUsage

// MARK: - Model Information (Tasks 411-420)

/// Model information
public struct APIModel: Codable, Identifiable {
    public let id: String
    public let object: String
    public let created: Int
    public let ownedBy: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case ownedBy = "owned_by"
    }
}

// MARK: - Session Management (Tasks 421-430)

/// Session information
public struct SessionInfo: Codable, Identifiable {
    public let id: String
    public let title: String
    public let createdAt: Date
    public let updatedAt: Date
    public let messageCount: Int
    public let model: String?
    public let metadata: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case messageCount = "message_count"
        case model
        case metadata
    }
}

/// Create session request
public struct CreateSessionRequest: Codable {
    public let title: String
    public let model: String?
    public let metadata: [String: AnyCodable]?
    
    public init(title: String, model: String? = nil, metadata: [String: AnyCodable]? = nil) {
        self.title = title
        self.model = model
        self.metadata = metadata
    }
}

// MARK: - Project Management (Tasks 431-440)

/// Project information
public struct ProjectInfo: Codable, Identifiable {
    public let id: String
    public let name: String
    public let path: String
    public let language: String?
    public let framework: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let fileCount: Int
    public let metadata: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case path
        case language
        case framework
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case fileCount = "file_count"
        case metadata
    }
}

/// Create project request
public struct CreateProjectRequest: Codable {
    public let name: String
    public let path: String
    public let language: String?
    public let framework: String?
    public let metadata: [String: AnyCodable]?
    
    public init(
        name: String,
        path: String,
        language: String? = nil,
        framework: String? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.name = name
        self.path = path
        self.language = language
        self.framework = framework
        self.metadata = metadata
    }
}

// MARK: - Tool Execution (Tasks 441-450)

/// Tool execution request
public struct ToolExecutionRequest: Codable {
    public let toolName: String
    public let arguments: [String: AnyCodable]
    public let sessionId: String?
    public let timeout: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case arguments
        case sessionId = "session_id"
        case timeout
    }
    
    public init(
        toolName: String,
        arguments: [String: AnyCodable],
        sessionId: String? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.toolName = toolName
        self.arguments = arguments
        self.sessionId = sessionId
        self.timeout = timeout
    }
}

/// Tool execution response
public struct ToolExecutionResponse: Codable {
    public let success: Bool
    public let result: AnyCodable?
    public let error: String?
    public let executionTime: TimeInterval
    public let metadata: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case success
        case result
        case error
        case executionTime = "execution_time"
        case metadata
    }
}

/// Tool information
public struct ToolInfo: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let category: String
    public let parameters: [String: Any]?
    public let isAvailable: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case category
        case parameters
        case isAvailable = "is_available"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(String.self, forKey: .category)
        if let params = try container.decodeIfPresent([String: AnyCodable].self, forKey: .parameters) {
            parameters = params.mapValues { $0.value }
        } else {
            parameters = nil
        }
        isAvailable = try container.decode(Bool.self, forKey: .isAvailable)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(category, forKey: .category)
        if let params = parameters {
            try container.encode(params.mapValues { AnyCodable($0) }, forKey: .parameters)
        }
        try container.encode(isAvailable, forKey: .isAvailable)
    }
}

// MARK: - SSH Models (Tasks 451-460)

/// SSH session request
public struct SSHSessionRequest: Codable {
    public let host: String
    public let port: Int
    public let username: String
    public let authMethod: SSHAuthMethod
    public let password: String?
    public let privateKey: String?
    public let passphrase: String?
    
    enum CodingKeys: String, CodingKey {
        case host
        case port
        case username
        case authMethod = "auth_method"
        case password
        case privateKey = "private_key"
        case passphrase
    }
    
    public init(
        host: String,
        port: Int = 22,
        username: String,
        authMethod: SSHAuthMethod,
        password: String? = nil,
        privateKey: String? = nil,
        passphrase: String? = nil
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.password = password
        self.privateKey = privateKey
        self.passphrase = passphrase
    }
}

/// SSH authentication method
public enum SSHAuthMethod: String, Codable {
    case password
    case publicKey = "public_key"
    case keyboardInteractive = "keyboard_interactive"
}

/// SSH command request
public struct SSHCommandRequest: Codable {
    public let sessionId: String
    public let command: String
    public let timeout: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case command
        case timeout
    }
    
    public init(sessionId: String, command: String, timeout: TimeInterval? = nil) {
        self.sessionId = sessionId
        self.command = command
        self.timeout = timeout
    }
}

/// SSH command response
public struct SSHCommandResponse: Codable {
    public let output: String
    public let exitCode: Int
    public let error: String?
    public let executionTime: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case output
        case exitCode = "exit_code"
        case error
        case executionTime = "execution_time"
    }
}

/// SSH session info
public struct SSHSessionInfo: Codable, Identifiable {
    public let id: String
    public let host: String
    public let port: Int
    public let username: String
    public let isConnected: Bool
    public let connectedAt: Date?
    public let lastActivity: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case host
        case port
        case username
        case isConnected = "is_connected"
        case connectedAt = "connected_at"
        case lastActivity = "last_activity"
    }
}

// MARK: - Response Wrappers

/// Generic delete response
public struct DeleteResponse: Codable {
    public let success: Bool
    public let message: String?
}

/// Sessions list response
public struct SessionsResponse: Codable {
    public let sessions: [SessionInfo]
    public let total: Int
    public let offset: Int
    public let limit: Int
}

/// Projects list response
public struct ProjectsResponse: Codable {
    public let projects: [ProjectInfo]
    public let total: Int
}

/// Tools list response
public struct ToolsResponse: Codable {
    public let tools: [ToolInfo]
    public let categories: [String]
}

/// SSH sessions list response
public struct SSHSessionsResponse: Codable {
    public let sessions: [SSHSessionInfo]
    public let activeCount: Int
    
    enum CodingKeys: String, CodingKey {
        case sessions
        case activeCount = "active_count"
    }
}

// MARK: - Additional Types for Compatibility

/// Tool result event for streaming
public struct ToolResultEvent: Codable {
    public let toolCallId: String
    public let result: AnyCodable
    public let error: String?
    
    enum CodingKeys: String, CodingKey {
        case toolCallId = "tool_call_id"
        case result
        case error
    }
}

/// Session statistics
public struct SessionStats: Codable {
    public let messageCount: Int
    public let tokenUsage: Int
    public let duration: TimeInterval
    public let model: String
    
    enum CodingKeys: String, CodingKey {
        case messageCount = "message_count"
        case tokenUsage = "token_usage"
        case duration
        case model
    }
}

/// Model capabilities
public struct ModelCapabilities: Codable {
    public let maxTokens: Int
    public let supportsStreaming: Bool
    public let supportsFunctions: Bool
    public let supportsVision: Bool
    
    enum CodingKeys: String, CodingKey {
        case maxTokens = "max_tokens"
        case supportsStreaming = "supports_streaming"
        case supportsFunctions = "supports_functions"
        case supportsVision = "supports_vision"
    }
}

/// Connection quality enum
public enum ConnectionQuality: String, Codable {
    case excellent
    case good
    case fair
    case poor
    case unknown
}

/// Metric type for monitoring
public enum MetricType: String, CaseIterable, Codable {
    case cpu
    case memory
    case disk
    case network
    case latency
    case performance
    
    public var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .latency: return "timer"
        case .performance: return "speedometer"
        }
    }
}

/// Time range for monitoring data
public enum TimeRange: String, CaseIterable, Identifiable, Codable {
    case oneMinute = "1m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case oneHour = "1h"
    case sixHours = "6h"
    case twelveHours = "12h"
    case oneDay = "1d"
    case oneWeek = "1w"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .oneMinute: return "1 Min"
        case .fiveMinutes: return "5 Min"
        case .fifteenMinutes: return "15 Min"
        case .thirtyMinutes: return "30 Min"
        case .oneHour: return "1 Hour"
        case .sixHours: return "6 Hours"
        case .twelveHours: return "12 Hours"
        case .oneDay: return "1 Day"
        case .oneWeek: return "1 Week"
        }
    }
}

/// Cached response for request caching
public class CachedResponse: NSObject {
    public let data: Data
    public let timestamp: Date
    public let headers: [String: String]
    
    public init(data: Data, headers: [String: String]) {
        self.data = data
        self.timestamp = Date()
        self.headers = headers
        super.init()
    }
}

/// Request metrics
public struct RequestMetrics: Codable {
    public let totalRequests: Int
    public let successfulRequests: Int
    public let failedRequests: Int
    public let averageResponseTime: TimeInterval
    public let totalBytesTransferred: Int64
}

/// Request metrics collector
public class RequestMetricsCollector: ObservableObject {
    @Published public var metrics = RequestMetrics(
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
        averageResponseTime: 0,
        totalBytesTransferred: 0
    )
    
    public init() {}
    
    public func recordRequest(success: Bool, responseTime: TimeInterval, bytes: Int64) {
        // Implementation
    }
}