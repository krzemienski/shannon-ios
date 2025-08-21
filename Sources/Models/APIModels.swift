import Foundation

// MARK: - API Health Models

public struct APIHealth: Codable {
    public let status: String
    public let version: String
    public let timestamp: Date
    public let services: [String: ServiceStatus]
    
    public init(status: String, version: String, timestamp: Date, services: [String: ServiceStatus]) {
        self.status = status
        self.version = version
        self.timestamp = timestamp
        self.services = services
    }
}

public struct ServiceStatus: Codable {
    public let status: String
    public let latency: Double?
    public let message: String?
    
    public init(status: String, latency: Double? = nil, message: String? = nil) {
        self.status = status
        self.latency = latency
        self.message = message
    }
}

// MARK: - API Configuration

/// Configuration for API requests
public struct APIConfiguration: Codable, Equatable {
    public let baseURL: String
    public let apiKey: String
    public let organizationID: String?
    public let timeout: TimeInterval
    public let maxRetries: Int
    
    public init(
        baseURL: String = "https://api.anthropic.com/v1",
        apiKey: String,
        organizationID: String? = nil,
        timeout: TimeInterval = 30,
        maxRetries: Int = 3
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.organizationID = organizationID
        self.timeout = timeout
        self.maxRetries = maxRetries
    }
}

// MARK: - API Request Models

/// Request body for creating a message
public struct CreateMessageRequest: Codable {
    public let model: String
    public let messages: [APIMessage]
    public let maxTokens: Int
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let stopSequences: [String]?
    public let stream: Bool
    public let system: String?
    public let metadata: [String: String]?
    public let tools: [APITool]?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case stopSequences = "stop_sequences"
        case stream
        case system
        case metadata
        case tools
    }
    
    public init(
        model: String,
        messages: [APIMessage],
        maxTokens: Int,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stopSequences: [String]? = nil,
        stream: Bool = false,
        system: String? = nil,
        metadata: [String: String]? = nil,
        tools: [APITool]? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stopSequences = stopSequences
        self.stream = stream
        self.system = system
        self.metadata = metadata
        self.tools = tools
    }
}

/// API message format
public struct APIMessage: Codable {
    public let role: String
    public let content: APIContent
    
    public init(role: String, content: APIContent) {
        self.role = role
        self.content = content
    }
    
    public init(role: String, text: String) {
        self.role = role
        self.content = .text(text)
    }
}

/// API content types
public enum APIContent: Codable {
    case text(String)
    case multipart([ContentPart])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let parts = try? container.decode([ContentPart].self) {
            self = .multipart(parts)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode APIContent"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .multipart(let parts):
            try container.encode(parts)
        }
    }
}

/// Content part for multipart messages
public struct ContentPart: Codable {
    public let type: ContentType
    public let text: String?
    public let source: ImageSource?
    
    public enum ContentType: String, Codable {
        case text
        case image
    }
    
    public init(text: String) {
        self.type = .text
        self.text = text
        self.source = nil
    }
    
    public init(imageSource: ImageSource) {
        self.type = .image
        self.text = nil
        self.source = imageSource
    }
}

/// Image source for content parts
public struct ImageSource: Codable {
    public let type: String
    public let mediaType: String
    public let data: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
    
    public init(mediaType: String, data: String) {
        self.type = "base64"
        self.mediaType = mediaType
        self.data = data
    }
}

// MARK: - API Response Models

/// Response from creating a message
public struct CreateMessageResponse: Codable {
    public let id: String
    public let type: String
    public let role: String
    public let content: [ResponseContent]
    public let model: String
    public let stopReason: String?
    public let stopSequence: String?
    public let usage: APIUsage
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}

/// Response content
public struct ResponseContent: Codable {
    public let type: String
    public let text: String?
    public let toolUse: ToolUse?
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case toolUse = "tool_use"
    }
}

/// Tool use in response
public struct ToolUse: Codable {
    public let id: String
    public let name: String
    public let input: [String: AnyCodable]
}

/// API usage information
public struct APIUsage: Codable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

// MARK: - Streaming Response Models

/// Server-sent event for streaming responses
public struct StreamEvent: Codable {
    public let type: StreamEventType
    public let message: StreamMessage?
    public let index: Int?
    public let delta: ContentDelta?
    
    public enum StreamEventType: String, Codable {
        case messageStart = "message_start"
        case contentBlockStart = "content_block_start"
        case contentBlockDelta = "content_block_delta"
        case contentBlockStop = "content_block_stop"
        case messageDelta = "message_delta"
        case messageStop = "message_stop"
        case ping
        case error
    }
}

/// Stream message
public struct StreamMessage: Codable {
    public let id: String
    public let type: String
    public let role: String
    public let content: [ResponseContent]
    public let model: String
    public let usage: APIUsage?
}

/// Content delta for streaming
public struct ContentDelta: Codable {
    public let type: String
    public let text: String?
    public let partialJson: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case partialJson = "partial_json"
    }
}

// MARK: - API Tools

/// Tool definition for API
public struct APITool: Codable {
    public let name: String
    public let description: String
    public let inputSchema: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }
    
    public init(name: String, description: String, inputSchema: [String: Any]) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        inputSchema = try container.decode([String: AnyCodable].self, forKey: .inputSchema)
            .mapValues { $0.value }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(
            inputSchema.mapValues { AnyCodable($0) },
            forKey: .inputSchema
        )
    }
}

// MARK: - API Errors

/// Errors that can occur during API operations
public enum APIError: LocalizedError {
    case invalidURL
    case invalidAPIKey
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String?)
    case rateLimitExceeded
    case unauthorized
    case invalidRequest(String)
    case timeout
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidAPIKey:
            return "Invalid API key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .unauthorized:
            return "Unauthorized access"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .timeout:
            return "Request timeout"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}