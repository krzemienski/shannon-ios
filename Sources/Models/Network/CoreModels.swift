import Foundation

// MARK: - Task 168: Model (LLM) Capabilities Structure
/// AI model information
public struct APIModel: Codable, Identifiable, Equatable {
    public let id: String
    public let object: String
    public let created: Int?
    public let ownedBy: String?
    public let capabilities: ModelCapabilities?
    public let pricing: ModelPricing?
    
    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case ownedBy = "owned_by"
        case capabilities
        case pricing
    }
    
    public init(
        id: String,
        object: String = "model",
        created: Int? = nil,
        ownedBy: String? = nil,
        capabilities: ModelCapabilities? = nil,
        pricing: ModelPricing? = nil
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.ownedBy = ownedBy
        self.capabilities = capabilities
        self.pricing = pricing
    }
}

/// Model capabilities
public struct ModelCapabilities: Codable, Equatable {
    public let contextWindow: Int?
    public let maxOutputTokens: Int?
    public let supportsFunctions: Bool
    public let supportsVision: Bool
    public let supportsStreaming: Bool
    public let supportsSystemMessage: Bool
    public let supportsToolUse: Bool
    public let supportedModalities: [String]?
    public let trainingCutoff: Date?
    
    enum CodingKeys: String, CodingKey {
        case contextWindow = "context_window"
        case maxOutputTokens = "max_output_tokens"
        case supportsFunctions = "supports_functions"
        case supportsVision = "supports_vision"
        case supportsStreaming = "supports_streaming"
        case supportsSystemMessage = "supports_system_message"
        case supportsToolUse = "supports_tool_use"
        case supportedModalities = "supported_modalities"
        case trainingCutoff = "training_cutoff"
    }
    
    public init(
        contextWindow: Int? = nil,
        maxOutputTokens: Int? = nil,
        supportsFunctions: Bool = false,
        supportsVision: Bool = false,
        supportsStreaming: Bool = true,
        supportsSystemMessage: Bool = true,
        supportsToolUse: Bool = false,
        supportedModalities: [String]? = nil,
        trainingCutoff: Date? = nil
    ) {
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.supportsFunctions = supportsFunctions
        self.supportsVision = supportsVision
        self.supportsStreaming = supportsStreaming
        self.supportsSystemMessage = supportsSystemMessage
        self.supportsToolUse = supportsToolUse
        self.supportedModalities = supportedModalities
        self.trainingCutoff = trainingCutoff
    }
}

/// Model pricing information
public struct ModelPricing: Codable, Equatable {
    public let promptTokenPrice: Double? // Price per 1K tokens
    public let completionTokenPrice: Double? // Price per 1K tokens
    public let imagePrice: Double? // Price per image
    public let currency: String
    
    enum CodingKeys: String, CodingKey {
        case promptTokenPrice = "prompt_token_price"
        case completionTokenPrice = "completion_token_price"
        case imagePrice = "image_price"
        case currency
    }
    
    public init(
        promptTokenPrice: Double? = nil,
        completionTokenPrice: Double? = nil,
        imagePrice: Double? = nil,
        currency: String = "USD"
    ) {
        self.promptTokenPrice = promptTokenPrice
        self.completionTokenPrice = completionTokenPrice
        self.imagePrice = imagePrice
        self.currency = currency
    }
}

// MARK: - Task 173: Usage Model for Token Tracking
/// Token usage information
public struct Usage: Codable, Equatable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    public let cachedTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case cachedTokens = "cached_tokens"
    }
    
    public init(
        promptTokens: Int,
        completionTokens: Int,
        totalTokens: Int,
        cachedTokens: Int? = nil
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.cachedTokens = cachedTokens
    }
    
    /// Calculate cost based on model pricing
    public func calculateCost(pricing: ModelPricing) -> Double {
        let promptCost = Double(promptTokens) / 1000.0 * (pricing.promptTokenPrice ?? 0)
        let completionCost = Double(completionTokens) / 1000.0 * (pricing.completionTokenPrice ?? 0)
        return promptCost + completionCost
    }
}

// MARK: - Task 174: HealthResponse Model
/// API health check response
public struct HealthResponse: Codable, Equatable {
    public let status: String
    public let version: String?
    public let timestamp: Date
    public let services: [String: ServiceHealth]?
    public let uptime: TimeInterval?
    
    public init(
        status: String,
        version: String? = nil,
        timestamp: Date = Date(),
        services: [String: ServiceHealth]? = nil,
        uptime: TimeInterval? = nil
    ) {
        self.status = status
        self.version = version
        self.timestamp = timestamp
        self.services = services
        self.uptime = uptime
    }
}

/// Service health status
public struct ServiceHealth: Codable, Equatable {
    public let status: String
    public let message: String?
    public let lastCheck: Date?
    public let responseTime: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case status
        case message
        case lastCheck = "last_check"
        case responseTime = "response_time"
    }
}

// MARK: - Task 175: Error Models with Codes
/// API error response
public struct APIErrorResponse: Codable, Equatable {
    public let error: APIErrorDetail
}

/// API error detail
public struct APIErrorDetail: Codable, Equatable {
    public let message: String
    public let type: String?
    public let code: String?
    public let param: String?
    public let details: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case message
        case type
        case code
        case param
        case details
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(String.self, forKey: .message)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        param = try container.decodeIfPresent(String.self, forKey: .param)
        
        if let detailsDict = try container.decodeIfPresent([String: AnyCodable].self, forKey: .details) {
            details = detailsDict.mapValues { $0.value }
        } else {
            details = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(code, forKey: .code)
        try container.encodeIfPresent(param, forKey: .param)
        
        if let details = details {
            let detailsDict = details.mapValues { AnyCodable($0) }
            try container.encode(detailsDict, forKey: .details)
        }
    }
}

/// Error codes enumeration
public enum APIErrorCode: String {
    case invalidRequest = "invalid_request"
    case authentication = "authentication_error"
    case permissionDenied = "permission_denied"
    case notFound = "not_found"
    case rateLimitExceeded = "rate_limit_exceeded"
    case serverError = "server_error"
    case serviceUnavailable = "service_unavailable"
    case timeout = "timeout"
    case conflict = "conflict"
    case payloadTooLarge = "payload_too_large"
    case unprocessableEntity = "unprocessable_entity"
    case quotaExceeded = "quota_exceeded"
    case invalidApiKey = "invalid_api_key"
    case modelNotFound = "model_not_found"
    case contextLengthExceeded = "context_length_exceeded"
    case contentFilter = "content_filter"
    case invalidToolUse = "invalid_tool_use"
}

// MARK: - Task 169: Stats Model for Telemetry
/// System statistics
public struct SystemStats: Codable, Equatable {
    public let requestsPerMinute: Int
    public let activeConnections: Int
    public let cpuUsage: Double
    public let memoryUsage: MemoryUsage
    public let diskUsage: DiskUsage
    public let networkStats: NetworkStats
    public let cacheStats: CacheStats?
    public let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case requestsPerMinute = "requests_per_minute"
        case activeConnections = "active_connections"
        case cpuUsage = "cpu_usage"
        case memoryUsage = "memory_usage"
        case diskUsage = "disk_usage"
        case networkStats = "network_stats"
        case cacheStats = "cache_stats"
        case timestamp
    }
}

/// Memory usage statistics
public struct MemoryUsage: Codable, Equatable {
    public let total: Int64
    public let used: Int64
    public let free: Int64
    public let percentage: Double
}

/// Disk usage statistics  
public struct DiskUsage: Codable, Equatable {
    public let total: Int64
    public let used: Int64
    public let free: Int64
    public let percentage: Double
}

/// Network statistics
public struct NetworkStats: Codable, Equatable {
    public let bytesIn: Int64
    public let bytesOut: Int64
    public let packetsIn: Int64
    public let packetsOut: Int64
    public let errors: Int
    public let dropped: Int
    
    enum CodingKeys: String, CodingKey {
        case bytesIn = "bytes_in"
        case bytesOut = "bytes_out"
        case packetsIn = "packets_in"
        case packetsOut = "packets_out"
        case errors
        case dropped
    }
}

/// Cache statistics
public struct CacheStats: Codable, Equatable {
    public let hits: Int
    public let misses: Int
    public let evictions: Int
    public let size: Int64
    public let hitRate: Double
    
    enum CodingKeys: String, CodingKey {
        case hits
        case misses
        case evictions
        case size
        case hitRate = "hit_rate"
    }
}