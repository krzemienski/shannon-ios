import Foundation

// MARK: - Task 181: MCPConfig Model
/// MCP (Model Context Protocol) configuration
public struct MCPConfig: Codable, Equatable {
    public let id: String
    public let name: String
    public let enabled: Bool
    public let servers: [MCPServer]
    public let globalSettings: MCPGlobalSettings?
    public let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case enabled
        case servers
        case globalSettings = "global_settings"
        case metadata
    }
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        enabled: Bool = true,
        servers: [MCPServer] = [],
        globalSettings: MCPGlobalSettings? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.servers = servers
        self.globalSettings = globalSettings
        self.metadata = metadata
    }
}

// MARK: - Task 182: MCPServer Model
/// MCP server configuration
public struct MCPServer: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let command: String
    public let args: [String]?
    public let env: [String: String]?
    public let workingDirectory: String?
    public let enabled: Bool
    public let autoStart: Bool
    public let restartOnFailure: Bool
    public let maxRestarts: Int?
    public let timeout: TimeInterval?
    public let capabilities: MCPCapabilities?
    public let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case command
        case args
        case env
        case workingDirectory = "working_directory"
        case enabled
        case autoStart = "auto_start"
        case restartOnFailure = "restart_on_failure"
        case maxRestarts = "max_restarts"
        case timeout
        case capabilities
        case metadata
    }
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        command: String,
        args: [String]? = nil,
        env: [String: String]? = nil,
        workingDirectory: String? = nil,
        enabled: Bool = true,
        autoStart: Bool = false,
        restartOnFailure: Bool = false,
        maxRestarts: Int? = 3,
        timeout: TimeInterval? = 30,
        capabilities: MCPCapabilities? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.workingDirectory = workingDirectory
        self.enabled = enabled
        self.autoStart = autoStart
        self.restartOnFailure = restartOnFailure
        self.maxRestarts = maxRestarts
        self.timeout = timeout
        self.capabilities = capabilities
        self.metadata = metadata
    }
}

/// MCP server capabilities
public struct MCPCapabilities: Codable, Equatable {
    public let tools: Bool
    public let resources: Bool
    public let prompts: Bool
    public let sampling: Bool
    public let logging: Bool
    public let customFeatures: [String]?
    
    enum CodingKeys: String, CodingKey {
        case tools
        case resources
        case prompts
        case sampling
        case logging
        case customFeatures = "custom_features"
    }
    
    public init(
        tools: Bool = false,
        resources: Bool = false,
        prompts: Bool = false,
        sampling: Bool = false,
        logging: Bool = false,
        customFeatures: [String]? = nil
    ) {
        self.tools = tools
        self.resources = resources
        self.prompts = prompts
        self.sampling = sampling
        self.logging = logging
        self.customFeatures = customFeatures
    }
}

/// MCP global settings
public struct MCPGlobalSettings: Codable, Equatable {
    public let defaultTimeout: TimeInterval?
    public let maxConcurrentServers: Int?
    public let logLevel: String?
    public let retryPolicy: RetryPolicy?
    public let resourceLimits: ResourceLimits?
    
    enum CodingKeys: String, CodingKey {
        case defaultTimeout = "default_timeout"
        case maxConcurrentServers = "max_concurrent_servers"
        case logLevel = "log_level"
        case retryPolicy = "retry_policy"
        case resourceLimits = "resource_limits"
    }
}

/// Retry policy configuration
public struct RetryPolicy: Codable, Equatable {
    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let backoffMultiplier: Double
    
    enum CodingKeys: String, CodingKey {
        case maxAttempts = "max_attempts"
        case initialDelay = "initial_delay"
        case maxDelay = "max_delay"
        case backoffMultiplier = "backoff_multiplier"
    }
}

/// Resource limits for MCP servers
public struct ResourceLimits: Codable, Equatable {
    public let maxMemory: Int64? // in bytes
    public let maxCPU: Double? // percentage
    public let maxFileDescriptors: Int?
    public let maxProcesses: Int?
    
    enum CodingKeys: String, CodingKey {
        case maxMemory = "max_memory"
        case maxCPU = "max_cpu"
        case maxFileDescriptors = "max_file_descriptors"
        case maxProcesses = "max_processes"
    }
}

// MARK: - Task 183: MCPTool Detailed Model
/// Detailed MCP tool information
public struct MCPTool: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let serverId: String
    public let name: String
    public let description: String
    public let version: String?
    public let category: ToolCategory?
    public let inputSchema: JSONSchema
    public let outputSchema: JSONSchema?
    public let examples: [ToolExample]?
    public let permissions: ToolPermissions?
    public let rateLimit: RateLimit?
    public let metadata: ToolMetadata?
    public let isDeprecated: Bool
    public let replacedBy: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case serverId = "server_id"
        case name
        case description
        case version
        case category
        case inputSchema = "input_schema"
        case outputSchema = "output_schema"
        case examples
        case permissions
        case rateLimit = "rate_limit"
        case metadata
        case isDeprecated = "is_deprecated"
        case replacedBy = "replaced_by"
    }
}

/// Tool example for documentation
public struct ToolExample: Codable, Equatable, Sendable {
    public let name: String?
    public let description: String?
    public let input: [String: AnyCodable]?
    public let output: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case input
        case output
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
        input = try container.decodeIfPresent([String: AnyCodable].self, forKey: .input)
        output = try container.decodeIfPresent([String: AnyCodable].self, forKey: .output)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        
        try container.encodeIfPresent(input, forKey: .input)
        try container.encodeIfPresent(output, forKey: .output)
    }
    
    public static func == (lhs: ToolExample, rhs: ToolExample) -> Bool {
        lhs.name == rhs.name &&
        lhs.description == rhs.description
        // Note: Skipping input/output comparison since they're type Any
    }
}

/// Tool category
public enum ToolCategory: String, Codable, Sendable {
    case filesystem
    case network
    case database
    case computation
    case transformation
    case analysis
    case generation
    case validation
    case monitoring
    case debugging
    case integration
    case utility
    case custom
}

/// JSON Schema for tool input/output
public struct JSONSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: PropertyDefinition]?
    public let required: [String]?
    public let additionalProperties: Bool?
    public let description: String?
    // Note: examples field removed as [Any] cannot be Sendable
    
    enum CodingKeys: String, CodingKey {
        case type
        case properties
        case required
        case additionalProperties = "additional_properties"
        case description
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        properties = try container.decodeIfPresent([String: PropertyDefinition].self, forKey: .properties)
        required = try container.decodeIfPresent([String].self, forKey: .required)
        additionalProperties = try container.decodeIfPresent(Bool.self, forKey: .additionalProperties)
        description = try container.decodeIfPresent(String.self, forKey: .description)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(properties, forKey: .properties)
        try container.encodeIfPresent(required, forKey: .required)
        try container.encodeIfPresent(additionalProperties, forKey: .additionalProperties)
        try container.encodeIfPresent(description, forKey: .description)
    }
    
    public init(
        type: String,
        properties: [String: PropertyDefinition]? = nil,
        required: [String]? = nil,
        additionalProperties: Bool? = nil,
        description: String? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
        self.description = description
    }
}

extension JSONSchema: Equatable {
    public static func == (lhs: JSONSchema, rhs: JSONSchema) -> Bool {
        lhs.type == rhs.type &&
        lhs.properties == rhs.properties &&
        lhs.required == rhs.required &&
        lhs.additionalProperties == rhs.additionalProperties &&
        lhs.description == rhs.description
        // Note: Skipping examples comparison since it's type Any
    }
}

/// Property definition in JSON schema
public indirect enum PropertyDefinitionItems: Codable, Equatable, Sendable {
    case definition(PropertyDefinition)
}

public struct PropertyDefinition: Codable, Sendable {
    public let type: String
    public let description: String?
    public let defaultValue: AnyCodable?
    public let enumValues: [String]?
    public let minimum: Double?
    public let maximum: Double?
    public let pattern: String?
    public let format: String?
    public let items: PropertyDefinitionItems?
    
    enum CodingKeys: String, CodingKey {
        case type
        case description
        case defaultValue = "default"
        case enumValues = "enum"
        case minimum
        case maximum
        case pattern
        case format
        case items
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        enumValues = try container.decodeIfPresent([String].self, forKey: .enumValues)
        minimum = try container.decodeIfPresent(Double.self, forKey: .minimum)
        maximum = try container.decodeIfPresent(Double.self, forKey: .maximum)
        pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
        format = try container.decodeIfPresent(String.self, forKey: .format)
        if let itemsDef = try container.decodeIfPresent(PropertyDefinition.self, forKey: .items) {
            items = .definition(itemsDef)
        } else {
            items = nil
        }
        
        defaultValue = try container.decodeIfPresent(AnyCodable.self, forKey: .defaultValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(enumValues, forKey: .enumValues)
        try container.encodeIfPresent(minimum, forKey: .minimum)
        try container.encodeIfPresent(maximum, forKey: .maximum)
        try container.encodeIfPresent(pattern, forKey: .pattern)
        try container.encodeIfPresent(format, forKey: .format)
        if case let .definition(itemsDef)? = items {
            try container.encode(itemsDef, forKey: .items)
        }
        
        try container.encodeIfPresent(defaultValue, forKey: .defaultValue)
    }
}

extension PropertyDefinition: Equatable {
    public static func == (lhs: PropertyDefinition, rhs: PropertyDefinition) -> Bool {
        lhs.type == rhs.type &&
        lhs.description == rhs.description &&
        lhs.enumValues == rhs.enumValues &&
        lhs.minimum == rhs.minimum &&
        lhs.maximum == rhs.maximum &&
        lhs.pattern == rhs.pattern &&
        lhs.format == rhs.format &&
        lhs.items == rhs.items
        // Note: Skipping defaultValue comparison since it's type Any
    }
}

/// Tool permissions
public struct ToolPermissions: Codable, Equatable, Sendable {
    public let filesystem: FilesystemPermissions?
    public let network: NetworkPermissions?
    public let process: ProcessPermissions?
    public let custom: [String: Bool]?
}

/// Filesystem permissions
public struct FilesystemPermissions: Codable, Equatable, Sendable {
    public let read: Bool
    public let write: Bool
    public let delete: Bool
    public let allowedPaths: [String]?
    public let deniedPaths: [String]?
    
    enum CodingKeys: String, CodingKey {
        case read
        case write
        case delete
        case allowedPaths = "allowed_paths"
        case deniedPaths = "denied_paths"
    }
}

/// Network permissions
public struct NetworkPermissions: Codable, Equatable, Sendable {
    public let allowedHosts: [String]?
    public let allowedPorts: [Int]?
    public let allowedProtocols: [String]?
    
    enum CodingKeys: String, CodingKey {
        case allowedHosts = "allowed_hosts"
        case allowedPorts = "allowed_ports"
        case allowedProtocols = "allowed_protocols"
    }
}

/// Process permissions
public struct ProcessPermissions: Codable, Equatable, Sendable {
    public let spawn: Bool
    public let kill: Bool
    public let signal: Bool
}

/// Rate limit configuration
public struct RateLimit: Codable, Equatable, Sendable {
    public let requestsPerMinute: Int?
    public let requestsPerHour: Int?
    public let requestsPerDay: Int?
    public let burstLimit: Int?
    
    enum CodingKeys: String, CodingKey {
        case requestsPerMinute = "requests_per_minute"
        case requestsPerHour = "requests_per_hour"
        case requestsPerDay = "requests_per_day"
        case burstLimit = "burst_limit"
    }
}

/// Tool metadata
public struct ToolMetadata: Codable, Equatable, Sendable {
    public let author: String?
    public let license: String?
    public let homepage: String?
    public let documentation: String?
    public let tags: [String]?
    public let createdAt: Date?
    public let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case author
        case license
        case homepage
        case documentation
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}