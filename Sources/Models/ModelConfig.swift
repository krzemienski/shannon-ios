import Foundation

// MARK: - Model Configuration

/// Configuration for AI models
public struct ModelConfig: Identifiable, Codable {
    public let id: String
    public let name: String
    public let provider: String
    public let status: ModelStatus
    public let contextWindow: Int
    public let maxTokens: Int
    public let supportedFeatures: [String]
    public let capabilities: [String]
    
    public init(
        id: String,
        name: String,
        provider: String,
        status: ModelStatus,
        contextWindow: Int,
        maxTokens: Int,
        supportedFeatures: [String],
        capabilities: [String]
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.status = status
        self.contextWindow = contextWindow
        self.maxTokens = maxTokens
        self.supportedFeatures = supportedFeatures
        self.capabilities = capabilities
    }
}

/// Model availability status
public enum ModelStatus: String, Codable {
    case available
    case unavailable
    case beta
    case deprecated
}