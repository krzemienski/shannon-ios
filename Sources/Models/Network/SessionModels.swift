import Foundation

// MARK: - Task 167: Session Model
/// Session information
public struct SessionInfo: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var projectId: String?
    public var messages: [ChatMessage]
    public var createdAt: Date
    public var updatedAt: Date
    public var metadata: SessionMetadata?
    public var stats: SessionStats?
    public var isActive: Bool
    public var isPinned: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case projectId = "project_id"
        case messages
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case metadata
        case stats
        case isActive = "is_active"
        case isPinned = "is_pinned"
    }
    
    public init(
        id: String,
        name: String,
        projectId: String? = nil,
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: SessionMetadata? = nil,
        stats: SessionStats? = nil,
        isActive: Bool = true,
        isPinned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.projectId = projectId
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.stats = stats
        self.isActive = isActive
        self.isPinned = isPinned
    }
}

/// Session metadata
public struct SessionMetadata: Codable, Equatable {
    public var model: String?
    public var temperature: Double?
    public var maxTokens: Int?
    public var systemPrompt: String?
    public var tools: [String]? // Tool IDs
    public var context: SessionContext?
    
    enum CodingKeys: String, CodingKey {
        case model
        case temperature
        case maxTokens = "max_tokens"
        case systemPrompt = "system_prompt"
        case tools
        case context
    }
    
    public init(
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        systemPrompt: String? = nil,
        tools: [String]? = nil,
        context: SessionContext? = nil
    ) {
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.context = context
    }
}

/// Session context
public struct SessionContext: Codable, Equatable {
    public var files: [String]? // File paths
    public var codeSnippets: [CodeSnippet]?
    public var references: [String]? // URLs or document references
    public var customData: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case files
        case codeSnippets = "code_snippets"
        case references
        case customData = "custom_data"
    }
}

/// Code snippet in session context
public struct CodeSnippet: Codable, Equatable {
    public let id: String
    public let language: String
    public let code: String
    public let filename: String?
    public let lineNumbers: Range<Int>?
    
    enum CodingKeys: String, CodingKey {
        case id
        case language
        case code
        case filename
        case lineNumbers = "line_numbers"
    }
    
    // Custom coding for Range
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        language = try container.decode(String.self, forKey: .language)
        code = try container.decode(String.self, forKey: .code)
        filename = try container.decodeIfPresent(String.self, forKey: .filename)
        
        if let lineNumbersArray = try container.decodeIfPresent([Int].self, forKey: .lineNumbers),
           lineNumbersArray.count == 2 {
            lineNumbers = lineNumbersArray[0]..<lineNumbersArray[1]
        } else {
            lineNumbers = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(language, forKey: .language)
        try container.encode(code, forKey: .code)
        try container.encodeIfPresent(filename, forKey: .filename)
        
        if let lineNumbers = lineNumbers {
            try container.encode([lineNumbers.lowerBound, lineNumbers.upperBound], forKey: .lineNumbers)
        }
    }
}

/// Session statistics
public struct SessionStats: Codable, Equatable {
    public var messageCount: Int
    public var totalTokens: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var totalCost: Double
    public var duration: TimeInterval? // in seconds
    public var toolUsageCount: [String: Int]? // Tool ID to usage count
    
    enum CodingKeys: String, CodingKey {
        case messageCount = "message_count"
        case totalTokens = "total_tokens"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalCost = "total_cost"
        case duration
        case toolUsageCount = "tool_usage_count"
    }
    
    public init(
        messageCount: Int = 0,
        totalTokens: Int = 0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        totalCost: Double = 0,
        duration: TimeInterval? = nil,
        toolUsageCount: [String: Int]? = nil
    ) {
        self.messageCount = messageCount
        self.totalTokens = totalTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalCost = totalCost
        self.duration = duration
        self.toolUsageCount = toolUsageCount
    }
}

/// Create session request
public struct CreateSessionRequest: Codable {
    public let name: String
    public let projectId: String?
    public let metadata: SessionMetadata?
    
    enum CodingKeys: String, CodingKey {
        case name
        case projectId = "project_id"
        case metadata
    }
    
    public init(
        name: String,
        projectId: String? = nil,
        metadata: SessionMetadata? = nil
    ) {
        self.name = name
        self.projectId = projectId
        self.metadata = metadata
    }
}

/// Sessions response
public struct SessionsResponse: Codable {
    public let sessions: [SessionInfo]
    public let totalCount: Int?
    public let page: Int?
    public let pageSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case sessions
        case totalCount = "total_count"
        case page
        case pageSize = "page_size"
    }
}