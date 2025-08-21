import Foundation

// MARK: - Task 162: ChatRequest Model
/// OpenAI-compatible chat completion request
public struct ChatCompletionRequest: Codable, Equatable {
    public let model: String
    public let messages: [ChatMessage]
    public let temperature: Double?
    public let topP: Double?
    public let n: Int?
    public let stream: Bool?
    public let stop: [String]?
    public let maxTokens: Int?
    public let presencePenalty: Double?
    public let frequencyPenalty: Double?
    public let logitBias: [String: Double]?
    public let user: String?
    public let tools: [ChatTool]?
    public let toolChoice: ToolChoice?
    public let responseFormat: ResponseFormat?
    public let seed: Int?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case topP = "top_p"
        case n
        case stream
        case stop
        case maxTokens = "max_tokens"
        case presencePenalty = "presence_penalty"
        case frequencyPenalty = "frequency_penalty"
        case logitBias = "logit_bias"
        case user
        case tools
        case toolChoice = "tool_choice"
        case responseFormat = "response_format"
        case seed
    }
    
    public init(
        model: String,
        messages: [ChatMessage],
        temperature: Double? = nil,
        topP: Double? = nil,
        n: Int? = nil,
        stream: Bool? = nil,
        stop: [String]? = nil,
        maxTokens: Int? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        logitBias: [String: Double]? = nil,
        user: String? = nil,
        tools: [ChatTool]? = nil,
        toolChoice: ToolChoice? = nil,
        responseFormat: ResponseFormat? = nil,
        seed: Int? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.topP = topP
        self.n = n
        self.stream = stream
        self.stop = stop
        self.maxTokens = maxTokens
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.logitBias = logitBias
        self.user = user
        self.tools = tools
        self.toolChoice = toolChoice
        self.responseFormat = responseFormat
        self.seed = seed
    }
}

// MARK: - Task 163: ChatResponse Model
/// OpenAI-compatible chat completion response
public struct ChatCompletionResponse: Codable, Equatable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [ChatChoice]
    public let usage: Usage?
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

// MARK: - Task 164: StreamingChunk Model
/// Server-Sent Events streaming chunk
public struct ChatCompletionChunk: Codable, Equatable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let systemFingerprint: String?
    public let choices: [StreamChoice]
    public let usage: Usage?
    
    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case model
        case systemFingerprint = "system_fingerprint"
        case choices
        case usage
    }
}

// MARK: - Task 165: Message Model with Role Enum
/// Chat message with role
public struct ChatMessage: Codable, Equatable {
    public let role: MessageRole
    public let content: MessageContent?
    public let name: String?
    public let toolCalls: [ToolCall]?
    public let toolCallId: String?
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
        case name
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
    
    public init(
        role: MessageRole,
        content: MessageContent? = nil,
        name: String? = nil,
        toolCalls: [ToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
    
    /// Convenience initializer for text messages
    public init(role: MessageRole, content: String) {
        self.init(role: role, content: .text(content))
    }
}

/// Message role enum
public enum MessageRole: String, Codable, CaseIterable {
    case system
    case user
    case assistant
    case tool
    case function // Legacy, kept for compatibility
}

/// Message content that can be text or array of content parts
public enum MessageContent: Codable, Equatable {
    case text(String)
    case array([MessageContentPart])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let array = try? container.decode([MessageContentPart].self) {
            self = .array(array)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode MessageContent"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .array(let parts):
            try container.encode(parts)
        }
    }
}

/// Content part for multi-modal messages
public struct MessageContentPart: Codable, Equatable {
    public let type: ContentPartType
    public let text: String?
    public let imageUrl: ImageUrl?
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }
    
    public enum ContentPartType: String, Codable {
        case text
        case imageUrl = "image_url"
    }
    
    public struct ImageUrl: Codable, Equatable {
        public let url: String
        public let detail: ImageDetail?
        
        public enum ImageDetail: String, Codable {
            case auto
            case low
            case high
        }
    }
}

// MARK: - Supporting Types for Chat

/// Chat choice in response
public struct ChatChoice: Codable, Equatable {
    public let index: Int
    public let message: ChatMessage
    public let logprobs: LogProbs?
    public let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index
        case message
        case logprobs
        case finishReason = "finish_reason"
    }
}

/// Stream choice for SSE
public struct StreamChoice: Codable, Equatable {
    public let index: Int
    public let delta: ChatMessage
    public let logprobs: LogProbs?
    public let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index
        case delta
        case logprobs
        case finishReason = "finish_reason"
    }
}

/// Log probabilities
public struct LogProbs: Codable, Equatable {
    public let content: [LogProbContent]?
}

public struct LogProbContent: Codable, Equatable {
    public let token: String
    public let logprob: Double
    public let bytes: [Int]?
    public let topLogprobs: [TopLogProb]?
    
    enum CodingKeys: String, CodingKey {
        case token
        case logprob
        case bytes
        case topLogprobs = "top_logprobs"
    }
}

public struct TopLogProb: Codable, Equatable {
    public let token: String
    public let logprob: Double
    public let bytes: [Int]?
}

/// Response format specification
public struct ResponseFormat: Codable, Equatable {
    public let type: ResponseFormatType
    public let jsonSchema: JSONSchema?
    
    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }
    
    public enum ResponseFormatType: String, Codable {
        case text
        case jsonObject = "json_object"
        case jsonSchema = "json_schema"
    }
    
    public struct JSONSchema: Codable, Equatable {
        public let name: String
        public let strict: Bool?
        public let schema: [String: Any]
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            strict = try container.decodeIfPresent(Bool.self, forKey: .strict)
            
            // Decode schema as AnyCodable dictionary
            let schemaDict = try container.decode([String: AnyCodable].self, forKey: .schema)
            schema = schemaDict.mapValues { $0.value }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(strict, forKey: .strict)
            
            // Encode schema as AnyCodable dictionary
            let schemaDict = schema.mapValues { AnyCodable($0) }
            try container.encode(schemaDict, forKey: .schema)
        }
        
        private enum CodingKeys: String, CodingKey {
            case name
            case strict
            case schema
        }
    }
}

/// Tool choice specification
public enum ToolChoice: Codable, Equatable {
    case none
    case auto
    case required
    case specific(ToolChoiceFunction)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            switch string {
            case "none": self = .none
            case "auto": self = .auto
            case "required": self = .required
            default: throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid tool choice string"
            )
            }
        } else if let function = try? container.decode(ToolChoiceFunction.self) {
            self = .specific(function)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode ToolChoice"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .required:
            try container.encode("required")
        case .specific(let function):
            try container.encode(function)
        }
    }
}

public struct ToolChoiceFunction: Codable, Equatable {
    public let type: String
    public let function: FunctionName
    
    public struct FunctionName: Codable, Equatable {
        public let name: String
    }
}

// MARK: - AnyCodable Helper (reused from existing code)
public struct AnyCodable: Codable, Equatable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode value"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Cannot encode value"
                )
            )
        }
    }
    
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case is (NSNull, NSNull):
            return true
        case let (lhs as Bool, rhs as Bool):
            return lhs == rhs
        case let (lhs as Int, rhs as Int):
            return lhs == rhs
        case let (lhs as Double, rhs as Double):
            return lhs == rhs
        case let (lhs as String, rhs as String):
            return lhs == rhs
        default:
            return false
        }
    }
}