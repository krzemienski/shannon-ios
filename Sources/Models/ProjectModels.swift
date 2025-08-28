//
//  ProjectModels.swift
//  ClaudeCode
//
//  Project-related models and types
//

import Foundation
import SwiftUI

// MARK: - Model Pricing

/// Pricing information for AI models
public struct ModelPricing: Codable, Hashable {
    public let modelId: String
    public let inputTokenCost: Double  // Cost per 1K tokens
    public let outputTokenCost: Double // Cost per 1K tokens
    public let contextWindow: Int
    public let maxOutputTokens: Int
    public let currency: String
    public let tier: PricingTier
    
    public enum PricingTier: String, Codable {
        case free = "free"
        case basic = "basic"
        case premium = "premium"
        case enterprise = "enterprise"
    }
    
    public init(
        modelId: String,
        inputTokenCost: Double,
        outputTokenCost: Double,
        contextWindow: Int,
        maxOutputTokens: Int,
        currency: String = "USD",
        tier: PricingTier = .basic
    ) {
        self.modelId = modelId
        self.inputTokenCost = inputTokenCost
        self.outputTokenCost = outputTokenCost
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.currency = currency
        self.tier = tier
    }
    
    /// Calculate cost for token usage
    public func calculateCost(inputTokens: Int, outputTokens: Int) -> Double {
        let inputCost = Double(inputTokens) / 1000.0 * inputTokenCost
        let outputCost = Double(outputTokens) / 1000.0 * outputTokenCost
        return inputCost + outputCost
    }
}

// MARK: - Tool Parameters

/// Parameters for tool execution
public struct ToolParameters: Codable, Hashable {
    public let name: String
    public let description: String
    public let inputSchema: PropertySchema?
    public let required: [String]
    public let examples: [String: Any]?
    
    public init(
        name: String,
        description: String,
        inputSchema: PropertySchema? = nil,
        required: [String] = [],
        examples: [String: Any]? = nil
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.required = required
        self.examples = examples
    }
    
    // Custom encoding/decoding for Any type
    enum CodingKeys: String, CodingKey {
        case name, description, inputSchema, required, examples
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(inputSchema, forKey: .inputSchema)
        try container.encode(required, forKey: .required)
        
        if let examples = examples {
            let jsonData = try JSONSerialization.data(withJSONObject: examples)
            let jsonString = String(data: jsonData, encoding: .utf8)
            try container.encodeIfPresent(jsonString, forKey: .examples)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        inputSchema = try container.decodeIfPresent(PropertySchema.self, forKey: .inputSchema)
        required = try container.decodeIfPresent([String].self, forKey: .required) ?? []
        
        if let jsonString = try container.decodeIfPresent(String.self, forKey: .examples),
           let jsonData = jsonString.data(using: .utf8) {
            examples = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        } else {
            examples = nil
        }
    }
    
    public static func == (lhs: ToolParameters, rhs: ToolParameters) -> Bool {
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.inputSchema == rhs.inputSchema &&
        lhs.required == rhs.required
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(inputSchema)
        hasher.combine(required)
    }
}

// MARK: - Property Schema

/// Schema for tool parameters
public struct PropertySchema: Codable, Hashable {
    public let type: SchemaType
    public let properties: [String: PropertyDefinition]?
    public let items: PropertyDefinition?
    public let description: String?
    public let pattern: String?
    public let minimum: Double?
    public let maximum: Double?
    public let minLength: Int?
    public let maxLength: Int?
    public let enumValues: [String]?
    public let format: String?
    
    public enum SchemaType: String, Codable {
        case string = "string"
        case number = "number"
        case integer = "integer"
        case boolean = "boolean"
        case array = "array"
        case object = "object"
        case null = "null"
    }
    
    public struct PropertyDefinition: Codable, Hashable {
        public let type: SchemaType
        public let description: String?
        public let defaultValue: String?
        public let enumValues: [String]?
        public let required: Bool
        
        public init(
            type: SchemaType,
            description: String? = nil,
            defaultValue: String? = nil,
            enumValues: [String]? = nil,
            required: Bool = false
        ) {
            self.type = type
            self.description = description
            self.defaultValue = defaultValue
            self.enumValues = enumValues
            self.required = required
        }
    }
    
    public init(
        type: SchemaType,
        properties: [String: PropertyDefinition]? = nil,
        items: PropertyDefinition? = nil,
        description: String? = nil,
        pattern: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        enumValues: [String]? = nil,
        format: String? = nil
    ) {
        self.type = type
        self.properties = properties
        self.items = items
        self.description = description
        self.pattern = pattern
        self.minimum = minimum
        self.maximum = maximum
        self.minLength = minLength
        self.maxLength = maxLength
        self.enumValues = enumValues
        self.format = format
    }
}

// MARK: - Project Settings

/// Settings for a project
public struct ProjectSettings: Codable, Hashable {
    public var id: String
    public var name: String
    public var description: String?
    public var language: String
    public var framework: String?
    public var gitRepository: String?
    public var defaultBranch: String
    public var buildCommand: String?
    public var testCommand: String?
    public var deployCommand: String?
    public var environmentVariables: [String: String]
    public var ignoredPaths: [String]
    public var autoSave: Bool
    public var autoFormat: Bool
    public var lintOnSave: Bool
    public var tabSize: Int
    public var useTabs: Bool
    public var theme: String
    public var fontSize: Int
    public var fontFamily: String
    public var wordWrap: Bool
    public var showLineNumbers: Bool
    public var showMinimap: Bool
    public var collaborators: [String]
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var lastOpenedAt: Date?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        language: String = "JavaScript",
        framework: String? = nil,
        gitRepository: String? = nil,
        defaultBranch: String = "main",
        buildCommand: String? = nil,
        testCommand: String? = nil,
        deployCommand: String? = nil,
        environmentVariables: [String: String] = [:],
        ignoredPaths: [String] = ["node_modules", ".git", "dist", "build"],
        autoSave: Bool = true,
        autoFormat: Bool = true,
        lintOnSave: Bool = true,
        tabSize: Int = 2,
        useTabs: Bool = false,
        theme: String = "dark",
        fontSize: Int = 14,
        fontFamily: String = "SF Mono",
        wordWrap: Bool = true,
        showLineNumbers: Bool = true,
        showMinimap: Bool = true,
        collaborators: [String] = [],
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastOpenedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.language = language
        self.framework = framework
        self.gitRepository = gitRepository
        self.defaultBranch = defaultBranch
        self.buildCommand = buildCommand
        self.testCommand = testCommand
        self.deployCommand = deployCommand
        self.environmentVariables = environmentVariables
        self.ignoredPaths = ignoredPaths
        self.autoSave = autoSave
        self.autoFormat = autoFormat
        self.lintOnSave = lintOnSave
        self.tabSize = tabSize
        self.useTabs = useTabs
        self.theme = theme
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.wordWrap = wordWrap
        self.showLineNumbers = showLineNumbers
        self.showMinimap = showMinimap
        self.collaborators = collaborators
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
    }
}

// MARK: - Session Metadata

/// Metadata for a chat or work session
public struct SessionMetadata: Codable, Hashable {
    public let id: String
    public let projectId: String?
    public let userId: String
    public let title: String
    public let description: String?
    public let type: SessionType
    public let status: SessionStatus
    public let startedAt: Date
    public let endedAt: Date?
    public let duration: TimeInterval?
    public let tokensUsed: Int
    public let messagesCount: Int
    public let filesModified: [String]
    public let toolsUsed: [String]
    public let model: String
    public let temperature: Double
    public let maxTokens: Int
    public let tags: [String]
    public let metadata: [String: String]
    
    public enum SessionType: String, Codable {
        case chat = "chat"
        case coding = "coding"
        case debugging = "debugging"
        case review = "review"
        case documentation = "documentation"
        case testing = "testing"
    }
    
    public enum SessionStatus: String, Codable {
        case active = "active"
        case paused = "paused"
        case completed = "completed"
        case archived = "archived"
    }
    
    public init(
        id: String = UUID().uuidString,
        projectId: String? = nil,
        userId: String,
        title: String,
        description: String? = nil,
        type: SessionType = .chat,
        status: SessionStatus = .active,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        duration: TimeInterval? = nil,
        tokensUsed: Int = 0,
        messagesCount: Int = 0,
        filesModified: [String] = [],
        toolsUsed: [String] = [],
        model: String = "gpt-4",
        temperature: Double = 0.7,
        maxTokens: Int = 4096,
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.projectId = projectId
        self.userId = userId
        self.title = title
        self.description = description
        self.type = type
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration ?? (endedAt?.timeIntervalSince(startedAt))
        self.tokensUsed = tokensUsed
        self.messagesCount = messagesCount
        self.filesModified = filesModified
        self.toolsUsed = toolsUsed
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.tags = tags
        self.metadata = metadata
    }
    
    /// Calculate session cost based on model pricing
    public func calculateCost(with pricing: ModelPricing) -> Double {
        // Rough estimate: assume 50/50 split between input and output tokens
        let inputTokens = tokensUsed / 2
        let outputTokens = tokensUsed / 2
        return pricing.calculateCost(inputTokens: inputTokens, outputTokens: outputTokens)
    }
}