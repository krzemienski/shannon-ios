import Foundation
import SwiftUI

// MARK: - Message

/// Represents a single message in a chat conversation
public struct Message: Identifiable, Codable, Equatable {
    public let id: String
    public let role: MessageRole
    public var content: String
    public let timestamp: Date
    public var isStreaming: Bool
    public var metadata: MessageMetadata?
    
    public init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.metadata = metadata
    }
}

// MARK: - Message Role

public enum MessageRole: String, Codable, CaseIterable {
    case system
    case user
    case assistant
    case error
    case tool
    case toolResponse = "tool_response"
    
    public var displayName: String {
        switch self {
        case .system: return "System"
        case .user: return "You"
        case .assistant: return "Claude"
        case .error: return "Error"
        case .tool: return "Tool"
        case .toolResponse: return "Tool Response"
        }
    }
    
    public var icon: String {
        switch self {
        case .system: return "gear"
        case .user: return "person.circle.fill"
        case .assistant: return "cpu"
        case .error: return "exclamationmark.triangle.fill"
        case .tool: return "wrench.and.screwdriver"
        case .toolResponse: return "checkmark.circle"
        }
    }
}

// MARK: - Message Metadata

public struct MessageMetadata: Codable, Equatable {
    public var model: String?
    public var temperature: Double?
    public var maxTokens: Int?
    public var topP: Double?
    public var topK: Int?
    public var stopSequences: [String]?
    public var toolCalls: [ToolCall]?
    public var usage: TokenUsage?
    
    public init(
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stopSequences: [String]? = nil,
        toolCalls: [ToolCall]? = nil,
        usage: TokenUsage? = nil
    ) {
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.topK = topK
        self.stopSequences = stopSequences
        self.toolCalls = toolCalls
        self.usage = usage
    }
}

// MARK: - Conversation

/// Represents a complete chat conversation
public struct Conversation: Identifiable, Codable, Equatable {
    public let id: String
    public var title: String
    public var messages: [Message]
    public let createdAt: Date
    public var updatedAt: Date
    public var metadata: ConversationMetadata?
    public var isPinned: Bool
    public var tags: [String]
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: ConversationMetadata? = nil,
        isPinned: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.isPinned = isPinned
        self.tags = tags
    }
    
    /// Get the last message in the conversation
    public var lastMessage: Message? {
        messages.last
    }
    
    /// Get a preview of the conversation
    public var preview: String {
        lastMessage?.content ?? "No messages"
    }
    
    /// Add a message to the conversation
    public mutating func addMessage(_ message: Message) {
        messages.append(message)
        updatedAt = Date()
    }
    
    /// Update message content by ID
    public mutating func updateMessage(id: String, content: String) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].content = content
            updatedAt = Date()
        }
    }
}

// MARK: - Conversation Metadata

public struct ConversationMetadata: Codable, Equatable {
    public var defaultModel: String?
    public var defaultTemperature: Double?
    public var defaultMaxTokens: Int?
    public var systemPrompt: String?
    public var totalTokensUsed: Int
    public var totalCost: Double
    
    public init(
        defaultModel: String? = nil,
        defaultTemperature: Double? = nil,
        defaultMaxTokens: Int? = nil,
        systemPrompt: String? = nil,
        totalTokensUsed: Int = 0,
        totalCost: Double = 0
    ) {
        self.defaultModel = defaultModel
        self.defaultTemperature = defaultTemperature
        self.defaultMaxTokens = defaultMaxTokens
        self.systemPrompt = systemPrompt
        self.totalTokensUsed = totalTokensUsed
        self.totalCost = totalCost
    }
}

// MARK: - Tool Call

public struct ToolCall: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let arguments: [String: AnyCodable]
    public var result: AnyCodable?
    public var status: ToolCallStatus
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        arguments: [String: AnyCodable],
        result: AnyCodable? = nil,
        status: ToolCallStatus = .pending
    ) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.result = result
        self.status = status
    }
}

public enum ToolCallStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
}

// MARK: - Token Usage

public struct TokenUsage: Codable, Equatable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    public let cachedTokens: Int?
    
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
}

// MARK: - AnyCodable Helper

// AnyCodable is imported from Utilities/AnyCodable.swift