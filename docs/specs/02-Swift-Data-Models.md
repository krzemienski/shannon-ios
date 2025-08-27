# Claude Code iOS Spec — 02 Swift Data Models

These Swift `Codable` models mirror the backend contracts (01-Backend-API.md) and add internal types for streaming and MCP. Use **camelCase** property names with `CodingKeys` for snake_case interoperability.

---

## 1. Core Chat Types

```swift
import Foundation

public struct ChatRequest: Codable {
    public let model: String
    public let messages: [ChatMessage]
    public let stream: Bool?
    public let projectId: String?
    public let sessionId: String?
    public let systemPrompt: String?
    public let mcp: MCPConfig? // optional (see MCP section)
    
    enum CodingKeys: String, CodingKey {
        case model, messages, stream
        case projectId = "project_id"
        case sessionId = "session_id"
        case systemPrompt = "system_prompt"
        case mcp
    }
}

public struct ChatMessage: Codable, Identifiable {
    public var id: UUID = UUID()
    public let role: String // "user" | "assistant" | "system"
    public let content: ChatContentValue
    
    public init(role: String, content: ChatContentValue) {
        self.role = role
        self.content = content
    }
}

/// Supports either a simple string or an array of typed blocks.
public enum ChatContentValue: Codable {
    case text(String)
    case blocks([ChatContent])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .text(str)
        } else if let arr = try? container.decode([ChatContent].self) {
            self = .blocks(arr)
        } else {
            throw DecodingError.typeMismatch(String.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected String or [ChatContent]"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s): try container.encode(s)
        case .blocks(let b): try container.encode(b)
        }
    }
}

public struct ChatContent: Codable {
    public let type: String // "text" | "code" | etc.
    public let text: String?
}
```

### Completion & Usage

```swift
public struct ChatCompletion: Codable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [ChatChoice]
    public let usage: Usage?
    public let sessionId: String?
    public let projectId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, object, created, model, choices, usage
        case sessionId = "session_id"
        case projectId = "project_id"
    }
}

public struct ChatChoice: Codable {
    public let index: Int
    public let message: ChatMessage
    public let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

public struct Usage: Codable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?
    public let totalCost: Double?
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
        case totalCost = "total_cost"
    }
}
```

---

## 2. Streaming (SSE) Types

```swift
/// SSE frame for streaming chat deltas (OpenAI-like chunk)
public struct ChatCompletionChunk: Codable {
    public let id: String
    public let object: String // "chat.completion.chunk"
    public let created: Int
    public let model: String
    public let choices: [ChatDeltaChoice]
}

public struct ChatDeltaChoice: Codable {
    public let index: Int
    public let delta: ChatDelta
    public let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}

public struct ChatDelta: Codable {
    public let role: String?
    public let content: String?
}
```

### Internal Normalized Event (UI)

```swift
public struct ClaudeEvent: Identifiable {
    public let id = UUID()
    public let kind: String // assistant, user, tool_use, tool_result, error
    public let text: String?
    public let tool: ToolEvent?
    public let usage: Usage?
    public let timestamp: Date
}

public struct ToolEvent: Codable {
    public let id: String
    public let name: String
    public let input: String?
    public let content: String?
    public let isError: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, input, content
        case isError = "is_error"
    }
}
```

---

## 3. Models API Types

```swift
public struct ModelObject: Codable, Identifiable {
    public let id: String
    public let created: Int
    public let ownedBy: String
    
    enum CodingKeys: String, CodingKey {
        case id, created
        case ownedBy = "owned_by"
    }
}

public struct ModelCapability: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let maxTokens: Int
    public let supportsStreaming: Bool
    public let supportsTools: Bool
    public let pricing: Pricing
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, pricing
        case maxTokens = "max_tokens"
        case supportsStreaming = "supports_streaming"
        case supportsTools = "supports_tools"
    }
}

public struct Pricing: Codable {
    public let input: Double
    public let output: Double
}
```

---

## 4. Projects & Sessions Types

```swift
public struct Project: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let path: String?
    public let createdAt: String
    public let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, path
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct Session: Codable, Identifiable {
    public let id: String
    public let projectId: String
    public let title: String?
    public let model: String
    public let systemPrompt: String?
    public let createdAt: String
    public let updatedAt: String
    public let isActive: Bool
    public let totalTokens: Int?
    public let totalCost: Double?
    public let messageCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, model, isActive
        case projectId = "project_id"
        case systemPrompt = "system_prompt"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case totalTokens = "total_tokens"
        case totalCost = "total_cost"
        case messageCount = "message_count"
    }
}

public struct SessionStats: Codable {
    public let activeSessions: Int
    public let totalTokens: Int
    public let totalCost: Double
    public let totalMessages: Int
    
    enum CodingKeys: String, CodingKey {
        case activeSessions = "active_sessions"
        case totalTokens = "total_tokens"
        case totalCost = "total_cost"
        case totalMessages = "total_messages"
    }
}
```

---

## 5. Health & Error Types

```swift
public struct HealthResponse: Codable {
    public let ok: Bool
    public let version: String?
    public let activeSessions: Int?
    public let uptimeSeconds: Int?
    
    enum CodingKeys: String, CodingKey {
        case ok, version
        case activeSessions = "active_sessions"
        case uptimeSeconds = "uptime_seconds"
    }
}

public struct APIErrorEnvelope: Codable, Error {
    public let error: APIError
}

public struct APIError: Codable, Error {
    public let code: String
    public let message: String
    public let status: Int
}
```

---

## 6. MCP Types

```swift
public struct MCPServer: Codable, Identifiable {
    public let id: String
    public let name: String
    public let scope: String // "user" | "project"
    public let executable: String?
    public let version: String?
    public let status: String // available | error | missing
}

public struct MCPTool: Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let title: String?
    public let description: String?
    public let inputSchema: [String: AnyCodable]?
    public let supportsStream: Bool?
    public let dangerous: Bool?
}

public struct MCPConfig: Codable {
    public var enabledServers: [String]
    public var enabledTools: [String]
    public var priority: [String]
    public var auditLog: Bool
    
    enum CodingKeys: String, CodingKey {
        case enabledServers = "enabled_servers"
        case enabledTools = "enabled_tools"
        case priority
        case auditLog = "audit_log"
    }
}
```

### AnyCodable Helper

```swift
public struct AnyCodable: Codable {
    public let value: Any
    public init(_ value: Any) { self.value = value }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v; return }
        if let v = try? container.decode(Int.self) { value = v; return }
        if let v = try? container.decode(Double.self) { value = v; return }
        if let v = try? container.decode(String.self) { value = v; return }
        if let v = try? container.decode([String: AnyCodable].self) { value = v; return }
        if let v = try? container.decode([AnyCodable].self) { value = v; return }
        throw DecodingError.typeMismatch(AnyCodable.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [String: AnyCodable]: try container.encode(v)
        case let v as [AnyCodable]: try container.encode(v)
        default: throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
```

---

## 7. Notes

- Keep `Identifiable` for SwiftUI list diffs.
- Use `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` if you remove explicit `CodingKeys`.
- Dates as strings can be adapted with ISO8601DateFormatter where needed.
