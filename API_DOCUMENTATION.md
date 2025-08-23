# Claude Code iOS API Documentation

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [Base Configuration](#base-configuration)
4. [Core Endpoints](#core-endpoints)
5. [Streaming Endpoints](#streaming-endpoints)
6. [WebSocket Connections](#websocket-connections)
7. [Error Handling](#error-handling)
8. [Rate Limiting](#rate-limiting)
9. [Response Formats](#response-formats)
10. [Code Examples](#code-examples)

## Overview

The Claude Code iOS app communicates with a backend API server that provides OpenAI-compatible endpoints for Claude AI interactions. The API supports both REST and Server-Sent Events (SSE) for real-time streaming responses.

### API Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     iOS Application                         │
└─────────────────────────────────────────────────────────────┘
                              │
                    HTTP/HTTPS + SSE
                              │
┌─────────────────────────────────────────────────────────────┐
│                   Claude Code API Server                    │
│                    (FastAPI + Uvicorn)                      │
└─────────────────────────────────────────────────────────────┘
                              │
                         Claude CLI
                              │
┌─────────────────────────────────────────────────────────────┐
│                      Anthropic API                          │
└─────────────────────────────────────────────────────────────┘
```

## Authentication

### API Key Authentication

```swift
// Headers required for authenticated requests
{
    "Authorization": "Bearer YOUR_API_KEY",
    "Content-Type": "application/json"
}
```

### Session Management

Sessions are managed server-side with unique identifiers:

```swift
{
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "project_id": "project-123",
    "created_at": "2024-01-15T10:00:00Z"
}
```

## Base Configuration

### Environment Configuration

| Environment | Base URL | Description |
|------------|----------|-------------|
| Development | `http://localhost:8000` | Local development server |
| Staging | `https://staging-api.claudecode.app` | Staging environment |
| Production | `https://api.claudecode.app` | Production API |

### API Versioning

All endpoints are versioned under `/v1/`:
- Current Version: `v1`
- Base Path: `/v1/`
- Full URL Example: `http://localhost:8000/v1/chat/completions`

## Core Endpoints

### 1. Health Check

#### GET /health

Check API server health and Claude CLI availability.

**Request:**
```http
GET /health HTTP/1.1
Host: localhost:8000
```

**Response:**
```json
{
    "status": "healthy",
    "version": "1.0.0",
    "claude_version": "1.x.x",
    "active_sessions": 5,
    "uptime_seconds": 3600
}
```

**Status Codes:**
- `200 OK` - Service healthy
- `503 Service Unavailable` - Service degraded

---

### 2. Models

#### GET /v1/models

List all available Claude models.

**Request:**
```http
GET /v1/models HTTP/1.1
Host: localhost:8000
Authorization: Bearer YOUR_API_KEY
```

**Response:**
```json
{
    "object": "list",
    "data": [
        {
            "id": "claude-opus-4-20250514",
            "object": "model",
            "created": 1704067200,
            "owned_by": "anthropic",
            "permission": [],
            "root": "claude-opus-4",
            "parent": null
        },
        {
            "id": "claude-sonnet-4-20250514",
            "object": "model",
            "created": 1704067201,
            "owned_by": "anthropic",
            "permission": [],
            "root": "claude-sonnet-4",
            "parent": null
        },
        {
            "id": "claude-3-5-haiku-20241022",
            "object": "model",
            "created": 1704067203,
            "owned_by": "anthropic",
            "permission": [],
            "root": "claude-haiku-3.5",
            "parent": null
        }
    ]
}
```

#### GET /v1/models/{model_id}

Get specific model details.

**Request:**
```http
GET /v1/models/claude-3-5-haiku-20241022 HTTP/1.1
Host: localhost:8000
Authorization: Bearer YOUR_API_KEY
```

**Response:**
```json
{
    "id": "claude-3-5-haiku-20241022",
    "object": "model",
    "created": 1704067203,
    "owned_by": "anthropic",
    "permission": [],
    "root": "claude-haiku-3.5",
    "parent": null,
    "context_window": 200000,
    "training_data": "2024-10"
}
```

---

### 3. Chat Completions

#### POST /v1/chat/completions

Send a chat message and receive a response.

**Request:**
```http
POST /v1/chat/completions HTTP/1.1
Host: localhost:8000
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json

{
    "model": "claude-3-5-haiku-20241022",
    "messages": [
        {
            "role": "system",
            "content": "You are a helpful assistant."
        },
        {
            "role": "user",
            "content": "Explain quantum computing in simple terms."
        }
    ],
    "temperature": 0.7,
    "max_tokens": 2000,
    "stream": false,
    "project_id": "project-123",
    "session_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response:**
```json
{
    "id": "chatcmpl-123",
    "object": "chat.completion",
    "created": 1705320000,
    "model": "claude-3-5-haiku-20241022",
    "choices": [
        {
            "index": 0,
            "message": {
                "role": "assistant",
                "content": "Quantum computing is a revolutionary approach to computation..."
            },
            "finish_reason": "stop"
        }
    ],
    "usage": {
        "prompt_tokens": 25,
        "completion_tokens": 150,
        "total_tokens": 175
    }
}
```

---

### 4. Projects

#### GET /v1/projects

List all projects.

**Request:**
```http
GET /v1/projects HTTP/1.1
Host: localhost:8000
Authorization: Bearer YOUR_API_KEY
```

**Response:**
```json
{
    "projects": [
        {
            "id": "project-123",
            "name": "iOS Development",
            "description": "Claude Code iOS app development",
            "created_at": "2024-01-15T10:00:00Z",
            "updated_at": "2024-01-20T15:30:00Z",
            "session_count": 5
        }
    ]
}
```

#### POST /v1/projects

Create a new project.

**Request:**
```json
{
    "name": "New Project",
    "description": "Project description",
    "settings": {
        "default_model": "claude-3-5-haiku-20241022",
        "temperature": 0.7
    }
}
```

#### GET /v1/projects/{project_id}

Get project details.

#### PUT /v1/projects/{project_id}

Update project settings.

#### DELETE /v1/projects/{project_id}

Delete a project.

---

### 5. Sessions

#### GET /v1/sessions

List all sessions.

**Request:**
```http
GET /v1/sessions?project_id=project-123 HTTP/1.1
Host: localhost:8000
Authorization: Bearer YOUR_API_KEY
```

**Response:**
```json
{
    "sessions": [
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "project_id": "project-123",
            "name": "Feature Implementation",
            "created_at": "2024-01-20T10:00:00Z",
            "last_activity": "2024-01-20T15:30:00Z",
            "message_count": 42
        }
    ]
}
```

#### POST /v1/sessions

Create a new session.

#### GET /v1/sessions/{session_id}/messages

Get session message history.

---

### 6. Tools

#### GET /v1/tools

List available MCP tools.

**Response:**
```json
{
    "tools": [
        {
            "name": "code_analysis",
            "description": "Analyze code for issues and improvements",
            "parameters": {
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Code to analyze"
                    },
                    "language": {
                        "type": "string",
                        "description": "Programming language"
                    }
                }
            }
        }
    ]
}
```

#### POST /v1/tools/{tool_name}/execute

Execute a specific tool.

**Request:**
```json
{
    "parameters": {
        "code": "func example() { }",
        "language": "swift"
    },
    "session_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

## Streaming Endpoints

### Server-Sent Events (SSE)

For real-time streaming responses, set `stream: true` in the request:

#### POST /v1/chat/completions (Streaming)

**Request:**
```json
{
    "model": "claude-3-5-haiku-20241022",
    "messages": [...],
    "stream": true
}
```

**Response (SSE Stream):**
```
data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1705320000,"model":"claude-3-5-haiku-20241022","choices":[{"index":0,"delta":{"content":"Quantum"},"finish_reason":null}]}

data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1705320000,"model":"claude-3-5-haiku-20241022","choices":[{"index":0,"delta":{"content":" computing"},"finish_reason":null}]}

data: {"id":"chatcmpl-123","object":"chat.completion.chunk","created":1705320000,"model":"claude-3-5-haiku-20241022","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

data: [DONE]
```

### Swift Implementation

```swift
class SSEClient {
    func streamChat(request: ChatRequest) -> AsyncThrowingStream<ChatChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let url = URL(string: "\(baseURL)/v1/chat/completions")!
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                urlRequest.httpBody = try JSONEncoder().encode(request)
                
                let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                
                for try await line in bytes.lines {
                    if line.hasPrefix("data: ") {
                        let data = String(line.dropFirst(6))
                        if data == "[DONE]" {
                            continuation.finish()
                        } else if let chunk = try? JSONDecoder().decode(ChatChunk.self, from: Data(data.utf8)) {
                            continuation.yield(chunk)
                        }
                    }
                }
            }
        }
    }
}
```

## WebSocket Connections

### WebSocket Endpoint

#### WS /v1/ws

Establish WebSocket connection for bidirectional communication.

**Connection URL:**
```
ws://localhost:8000/v1/ws?session_id=550e8400-e29b-41d4-a716-446655440000
```

**Message Format:**
```json
{
    "type": "message",
    "data": {
        "content": "User message",
        "model": "claude-3-5-haiku-20241022"
    }
}
```

**Response Format:**
```json
{
    "type": "response",
    "data": {
        "content": "Assistant response",
        "tokens_used": 150
    }
}
```

## Error Handling

### Error Response Format

```json
{
    "error": {
        "message": "Invalid request",
        "type": "invalid_request_error",
        "param": "messages",
        "code": "invalid_messages"
    }
}
```

### Common Error Codes

| Status Code | Error Type | Description |
|------------|------------|-------------|
| 400 | `invalid_request_error` | Invalid request parameters |
| 401 | `authentication_error` | Invalid or missing API key |
| 403 | `permission_error` | Insufficient permissions |
| 404 | `not_found_error` | Resource not found |
| 429 | `rate_limit_error` | Rate limit exceeded |
| 500 | `internal_server_error` | Server error |
| 503 | `service_unavailable` | Service temporarily unavailable |

### Swift Error Handling

```swift
enum APIError: LocalizedError {
    case invalidRequest(String)
    case authenticationError
    case rateLimitExceeded(retryAfter: Int)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .authenticationError:
            return "Authentication failed"
        case .rateLimitExceeded(let retryAfter):
            return "Rate limit exceeded. Retry after \(retryAfter) seconds"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
```

## Rate Limiting

### Rate Limit Headers

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1705320000
X-RateLimit-Reset-After: 60
```

### Rate Limit Response

```json
{
    "error": {
        "message": "Rate limit exceeded",
        "type": "rate_limit_error",
        "retry_after": 60
    }
}
```

## Response Formats

### Standard Response

```json
{
    "data": {},
    "meta": {
        "request_id": "req_123",
        "timestamp": "2024-01-20T15:30:00Z"
    }
}
```

### Paginated Response

```json
{
    "data": [],
    "meta": {
        "page": 1,
        "per_page": 20,
        "total": 100,
        "total_pages": 5
    },
    "links": {
        "first": "/v1/sessions?page=1",
        "last": "/v1/sessions?page=5",
        "next": "/v1/sessions?page=2",
        "prev": null
    }
}
```

## Code Examples

### Complete Swift Implementation

```swift
// APIClient.swift
class APIClient {
    private let baseURL = "http://localhost:8000"
    private let session = URLSession.shared
    
    // Send chat message
    func sendMessage(_ content: String, model: String = "claude-3-5-haiku-20241022") async throws -> ChatResponse {
        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body = ChatRequest(
            model: model,
            messages: [
                Message(role: "user", content: content)
            ],
            stream: false
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(ChatResponse.self, from: data)
        case 401:
            throw APIError.authenticationError
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset-After")
            throw APIError.rateLimitExceeded(retryAfter: Int(retryAfter ?? "60") ?? 60)
        default:
            throw APIError.serverError("Status code: \(httpResponse.statusCode)")
        }
    }
    
    // Stream chat response
    func streamMessage(_ content: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = URL(string: "\(baseURL)/v1/chat/completions")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    
                    let body = ChatRequest(
                        model: "claude-3-5-haiku-20241022",
                        messages: [Message(role: "user", content: content)],
                        stream: true
                    )
                    
                    request.httpBody = try JSONEncoder().encode(body)
                    
                    let (bytes, _) = try await session.bytes(for: request)
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            if data == "[DONE]" {
                                continuation.finish()
                            } else if let json = try? JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any],
                                      let choices = json["choices"] as? [[String: Any]],
                                      let delta = choices.first?["delta"] as? [String: Any],
                                      let content = delta["content"] as? String {
                                continuation.yield(content)
                            }
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

### Usage Example

```swift
// In ViewModel
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    
    private let apiClient = APIClient()
    
    func sendMessage(_ text: String) {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                // Add user message
                let userMessage = ChatMessage(role: "user", content: text)
                messages.append(userMessage)
                
                // Get AI response
                let response = try await apiClient.sendMessage(text)
                
                if let assistantContent = response.choices.first?.message.content {
                    let assistantMessage = ChatMessage(role: "assistant", content: assistantContent)
                    messages.append(assistantMessage)
                }
            } catch {
                // Handle error
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func streamMessage(_ text: String) {
        Task {
            // Add user message
            let userMessage = ChatMessage(role: "user", content: text)
            messages.append(userMessage)
            
            // Create assistant message placeholder
            var assistantMessage = ChatMessage(role: "assistant", content: "")
            messages.append(assistantMessage)
            
            // Stream response
            for try await chunk in apiClient.streamMessage(text) {
                assistantMessage.content += chunk
                messages[messages.count - 1] = assistantMessage
            }
        }
    }
}
```

---

This comprehensive API documentation provides all the necessary information for integrating with the Claude Code backend API, including request/response formats, error handling, and complete Swift implementation examples.