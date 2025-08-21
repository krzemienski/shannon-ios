# Claude Code API Reference

## Base Information

- **Base URL**: `http://localhost:8000`
- **API Version**: `v1`
- **Protocol**: REST/HTTP
- **Content Type**: `application/json`
- **Authentication**: Optional (disabled by default)

## Endpoints

### Health Check

#### GET /health
Check API server health status and Claude CLI availability.

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
  "active_sessions": 0
}
```

**Status Codes:**
- `200 OK` - Service is healthy
- `503 Service Unavailable` - Claude CLI not available

---

### Models

#### GET /v1/models
List all available Claude models.

**Request:**
```http
GET /v1/models HTTP/1.1
Host: localhost:8000
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
      "owned_by": "anthropic-claude-1.x.x"
    },
    {
      "id": "claude-sonnet-4-20250514",
      "object": "model",
      "created": 1704067201,
      "owned_by": "anthropic-claude-1.x.x"
    },
    {
      "id": "claude-3-7-sonnet-20250219",
      "object": "model",
      "created": 1704067202,
      "owned_by": "anthropic-claude-1.x.x"
    },
    {
      "id": "claude-3-5-haiku-20241022",
      "object": "model",
      "created": 1704067203,
      "owned_by": "anthropic-claude-1.x.x"
    }
  ]
}
```

#### GET /v1/models/{model_id}
Get specific model information.

**Request:**
```http
GET /v1/models/claude-3-5-haiku-20241022 HTTP/1.1
Host: localhost:8000
```

**Response:**
```json
{
  "id": "claude-3-5-haiku-20241022",
  "object": "model",
  "created": 1704067200,
  "owned_by": "anthropic-claude-1.x.x"
}
```

**Status Codes:**
- `200 OK` - Model found
- `404 Not Found` - Model not found

#### GET /v1/models/capabilities
Get detailed model capabilities (extended endpoint).

**Response:**
```json
{
  "models": [
    {
      "id": "claude-3-5-haiku-20241022",
      "name": "Claude Haiku 3.5",
      "description": "Fast and cost-effective model for quick tasks",
      "max_tokens": 200000,
      "supports_streaming": true,
      "supports_tools": true,
      "pricing": {
        "input_cost_per_1k_tokens": 0.25,
        "output_cost_per_1k_tokens": 1.25,
        "currency": "USD"
      },
      "features": [
        "text_generation",
        "conversation",
        "code_generation",
        "analysis",
        "reasoning",
        "file_operations",
        "bash_execution",
        "project_management"
      ]
    }
  ],
  "total": 4,
  "provider": "anthropic",
  "adapter": "claude-code-api"
}
```

---

### Chat Completions

#### POST /v1/chat/completions
Create a chat completion with Claude.

**Request:**
```http
POST /v1/chat/completions HTTP/1.1
Host: localhost:8000
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
      "content": "Hello, how are you?"
    }
  ],
  "stream": false,
  "temperature": 0.7,
  "max_tokens": 1000,
  "project_id": "my-project",
  "session_id": null,
  "system_prompt": "Optional system prompt override"
}
```

**Request Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| model | string | Yes | Model ID to use |
| messages | array | Yes | Array of message objects |
| stream | boolean | No | Enable streaming (default: false) |
| temperature | float | No | Sampling temperature (0-1) |
| max_tokens | integer | No | Maximum tokens to generate |
| project_id | string | No | Project identifier |
| session_id | string | No | Session ID to resume |
| system_prompt | string | No | Override system prompt |

**Message Object:**

| Field | Type | Description |
|-------|------|-------------|
| role | string | "system", "user", or "assistant" |
| content | string | Message content |

**Non-Streaming Response:**
```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1704067200,
  "model": "claude-3-5-haiku-20241022",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hello! I'm doing well, thank you for asking. How can I help you today?"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 20,
    "completion_tokens": 15,
    "total_tokens": 35
  },
  "project_id": "my-project"
}
```

**Streaming Response:**
```
data: {"id":"chatcmpl-abc123","object":"chat.completion.chunk","created":1704067200,"model":"claude-3-5-haiku-20241022","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}

data: {"id":"chatcmpl-abc123","object":"chat.completion.chunk","created":1704067200,"model":"claude-3-5-haiku-20241022","choices":[{"index":0,"delta":{"content":"!"},"finish_reason":null}]}

data: {"id":"chatcmpl-abc123","object":"chat.completion.chunk","created":1704067200,"model":"claude-3-5-haiku-20241022","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

data: [DONE]
```

**Response Headers (Streaming):**
- `Cache-Control: no-cache`
- `Connection: keep-alive`
- `X-Session-ID: <session_id>`
- `X-Project-ID: <project_id>`

**Status Codes:**
- `200 OK` - Success
- `400 Bad Request` - Invalid request format
- `404 Not Found` - Session not found
- `422 Unprocessable Entity` - Validation error
- `503 Service Unavailable` - Claude CLI unavailable

#### GET /v1/chat/completions/{session_id}/status
Get status of a chat completion session.

**Response:**
```json
{
  "session_id": "abc-123-def",
  "project_id": "my-project",
  "model": "claude-3-5-haiku-20241022",
  "is_running": true,
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:01:00Z",
  "total_tokens": 100,
  "total_cost": 0.001,
  "message_count": 5
}
```

#### DELETE /v1/chat/completions/{session_id}
Stop a running chat completion session.

**Response:**
```json
{
  "session_id": "abc-123-def",
  "status": "stopped"
}
```

---

### Projects (Extended API)

#### GET /v1/projects
List all projects.

#### POST /v1/projects
Create a new project.

#### GET /v1/projects/{project_id}
Get project details.

#### DELETE /v1/projects/{project_id}
Delete a project.

---

### Sessions (Extended API)

#### GET /v1/sessions
List active sessions.

#### GET /v1/sessions/{session_id}
Get session details.

#### DELETE /v1/sessions/{session_id}
End a session.

---

## Error Responses

All error responses follow this format:

```json
{
  "error": {
    "message": "Human-readable error message",
    "type": "error_type",
    "code": "error_code",
    "details": {} // Optional additional details
  }
}
```

### Common Error Types

| Type | Code | Description |
|------|------|-------------|
| invalid_request_error | missing_messages | No messages provided |
| invalid_request_error | missing_user_message | No user message found |
| invalid_request_error | session_not_found | Session ID not found |
| service_unavailable | claude_unavailable | Claude CLI not responding |
| internal_error | unexpected_error | Unexpected server error |

---

## cURL Examples

### Basic Chat Request
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-haiku-20241022",
    "messages": [
      {"role": "user", "content": "What is the weather like?"}
    ]
  }'
```

### Streaming Chat Request
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-haiku-20241022",
    "messages": [
      {"role": "user", "content": "Tell me a story"}
    ],
    "stream": true
  }'
```

### With System Prompt
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "messages": [
      {"role": "system", "content": "You are a Python expert."},
      {"role": "user", "content": "How do I read a CSV file?"}
    ]
  }'
```

### Resume Session
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-haiku-20241022",
    "session_id": "existing-session-id",
    "messages": [
      {"role": "user", "content": "Continue our conversation"}
    ]
  }'
```

---

## Rate Limits

Default rate limits (configurable):
- 100 requests per minute per IP
- Burst allowance: 10 requests
- Streaming timeout: 300 seconds

---

## WebSocket Support

Not currently implemented. All communication is via REST HTTP.

---

## SDK Support

### OpenAI Python SDK
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed"  # No auth required by default
)

response = client.chat.completions.create(
    model="claude-3-5-haiku-20241022",
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)
```

### Swift/iOS
See iOS integration examples in the Backend Integration Guide.