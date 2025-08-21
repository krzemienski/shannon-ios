import Foundation

// MARK: - Task 170: Tool Model for MCP
/// Tool definition for chat completions
public struct ChatTool: Codable, Equatable {
    public let type: ToolType
    public let function: ToolFunction
    
    public enum ToolType: String, Codable {
        case function
    }
    
    public init(function: ToolFunction) {
        self.type = .function
        self.function = function
    }
}

/// Tool function definition
public struct ToolFunction: Codable, Equatable {
    public let name: String
    public let description: String?
    public let parameters: ToolParameters?
    
    public init(
        name: String,
        description: String? = nil,
        parameters: ToolParameters? = nil
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Tool parameters schema
public struct ToolParameters: Codable, Equatable {
    public let type: String
    public let properties: [String: PropertySchema]?
    public let required: [String]?
    public let additionalProperties: Bool?
    
    enum CodingKeys: String, CodingKey {
        case type
        case properties
        case required
        case additionalProperties = "additionalProperties"
    }
    
    public init(
        type: String = "object",
        properties: [String: PropertySchema]? = nil,
        required: [String]? = nil,
        additionalProperties: Bool? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }
}

/// Property schema for tool parameters
public struct PropertySchema: Codable, Equatable {
    public let type: String
    public let description: String?
    public let enumValues: [String]?
    public let items: ItemSchema?
    public let properties: [String: PropertySchema]?
    public let required: [String]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
        case items
        case properties
        case required
    }
}

/// Item schema for arrays
public struct ItemSchema: Codable, Equatable {
    public let type: String
    public let description: String?
    public let properties: [String: PropertySchema]?
}

// MARK: - Task 171: ToolUse Event Model
/// Tool call in a message
public struct ToolCall: Codable, Equatable, Identifiable {
    public let id: String
    public let type: ToolCallType
    public let function: FunctionCall
    
    public enum ToolCallType: String, Codable {
        case function
    }
    
    public struct FunctionCall: Codable, Equatable {
        public let name: String
        public let arguments: String // JSON string
    }
}

/// Tool use event for streaming
public struct ToolUseEvent: Codable, Equatable {
    public let id: String
    public let type: String
    public let name: String
    public let input: String // JSON string representing the input
    public let timestamp: Date?
    
    public init(
        id: String,
        type: String = "tool_use",
        name: String,
        input: String,
        timestamp: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.input = input
        self.timestamp = timestamp
    }
}

// MARK: - Task 172: ToolResult Event Model
/// Tool result event
public struct ToolResultEvent: Codable, Equatable {
    public let id: String
    public let type: String
    public let toolUseId: String
    public let content: String
    public let isError: Bool
    public let timestamp: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
        case timestamp
    }
    
    public init(
        id: String,
        type: String = "tool_result",
        toolUseId: String,
        content: String,
        isError: Bool = false,
        timestamp: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
        self.timestamp = timestamp
    }
}

// MARK: - MCP Tool Models
/// MCP tool information
public struct ToolInfo: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let category: String?
    public let version: String?
    public let author: String?
    public let inputSchema: ToolParameters?
    public let outputSchema: ToolParameters?
    public let examples: [ToolExample]?
    public let isEnabled: Bool
    public let requiredPermissions: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case category
        case version
        case author
        case inputSchema = "input_schema"
        case outputSchema = "output_schema"
        case examples
        case isEnabled = "is_enabled"
        case requiredPermissions = "required_permissions"
    }
}

/// Tool example
public struct ToolExample: Codable, Equatable {
    public let name: String
    public let description: String?
    public let input: String // JSON string
    public let output: String // JSON string
}

/// Tool execution request
public struct ToolExecutionRequest: Codable {
    public let toolId: String
    public let input: [String: Any]
    public let sessionId: String?
    public let timeout: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case toolId = "tool_id"
        case input
        case sessionId = "session_id"
        case timeout
    }
    
    public init(
        toolId: String,
        input: [String: Any],
        sessionId: String? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.toolId = toolId
        self.input = input
        self.sessionId = sessionId
        self.timeout = timeout
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toolId = try container.decode(String.self, forKey: .toolId)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        timeout = try container.decodeIfPresent(TimeInterval.self, forKey: .timeout)
        
        // Decode input as AnyCodable dictionary
        let inputDict = try container.decode([String: AnyCodable].self, forKey: .input)
        input = inputDict.mapValues { $0.value }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toolId, forKey: .toolId)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(timeout, forKey: .timeout)
        
        // Encode input as AnyCodable dictionary
        let inputDict = input.mapValues { AnyCodable($0) }
        try container.encode(inputDict, forKey: .input)
    }
}

/// Tool execution response
public struct ToolExecutionResponse: Codable {
    public let id: String
    public let toolId: String
    public let status: ToolExecutionStatus
    public let output: [String: Any]?
    public let error: String?
    public let executionTime: TimeInterval?
    public let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case toolId = "tool_id"
        case status
        case output
        case error
        case executionTime = "execution_time"
        case timestamp
    }
    
    public enum ToolExecutionStatus: String, Codable {
        case pending
        case running
        case success
        case failed
        case timeout
        case cancelled
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        toolId = try container.decode(String.self, forKey: .toolId)
        status = try container.decode(ToolExecutionStatus.self, forKey: .status)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        executionTime = try container.decodeIfPresent(TimeInterval.self, forKey: .executionTime)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // Decode output as AnyCodable dictionary if present
        if let outputDict = try container.decodeIfPresent([String: AnyCodable].self, forKey: .output) {
            output = outputDict.mapValues { $0.value }
        } else {
            output = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(toolId, forKey: .toolId)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(executionTime, forKey: .executionTime)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Encode output as AnyCodable dictionary if present
        if let output = output {
            let outputDict = output.mapValues { AnyCodable($0) }
            try container.encode(outputDict, forKey: .output)
        }
    }
}

/// Tools list response
public struct ToolsResponse: Codable {
    public let tools: [ToolInfo]
    public let totalCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case tools
        case totalCount = "total_count"
    }
}