# Claude Code iOS Spec — 01 Backend & API

This document defines the **complete backend surface** consumed by the iOS client. It follows an OpenAI-compatible shape with **sessions**, **projects**, **models**, and **chat completions** (streaming and non-streaming). It also proposes MCP endpoints used by the MCP configuration screens.

See **WF‑IDs** in 05/06 docs for UI mapping.

---

## 1. Conventions

- **Base URL**: e.g., `http://localhost:8000`
- **Auth** (optional): 
  - `Authorization: Bearer <token>` **or** `x-api-key: <key>`
- **Headers**:
  - Requests: `Content-Type: application/json`
  - Streaming responses: `Content-Type: text/event-stream`
- **Timestamps**: ISO‑8601 strings (UTC) unless otherwise noted.
- **IDs**: Treat as opaque strings (`project_id`, `session_id`, etc.).
- **Pagination**: When present, supports `limit` and `cursor` query params.
- **Errors**: JSON envelope:
```json
{ "error": { "code": "bad_request", "message": "Details...", "status": 400 } }
```
- **Usage & Cost** (when provided):
```json
{ "usage": { "input_tokens": 52, "output_tokens": 180, "total_tokens": 232, "total_cost": 0.0011 } }
```

---

## 2. Endpoints Overview

### 2.1 Chat
- `POST /v1/chat/completions` — Start/continue chat; **SSE** when `stream=true`.
- `GET /v1/chat/completions/{session_id}/status` — Status & cumulative metrics.
- `DELETE /v1/chat/completions/{session_id}` — Cancel/stop a running session.
- `POST /v1/chat/completions/debug` — Echo/debug for diagnostics.

### 2.2 Models
- `GET /v1/models` — List models (OpenAI-style `ModelObject`).
- `GET /v1/models/{model_id}` — Fetch model.
- `GET /v1/models/capabilities` — Extended metadata (max tokens, streaming, tools, pricing).

### 2.3 Projects
- `GET /v1/projects` — List projects.
- `POST /v1/projects` — Create project.
- `GET /v1/projects/{project_id}` — Project detail.
- `DELETE /v1/projects/{project_id}` — Delete project (may be stubbed).

### 2.4 Sessions
- `GET /v1/sessions` — List sessions (`?project_id=` filter).
- `POST /v1/sessions` — Create session.
- `GET /v1/sessions/{session_id}` — Session detail.
- `DELETE /v1/sessions/{session_id}` — End session.
- `GET /v1/sessions/stats` — Aggregated stats.

### 2.5 Health
- `GET /health` — Server status, version, and quick metrics.

### 2.6 MCP (Proposed)
- `GET /v1/mcp/servers` — Discover installed MCP servers (user/project scope).
- `GET /v1/mcp/servers/{server_id}/tools` — List tools for a server.
- `POST /v1/sessions/{session_id}/tools` — Persist per-session tool activation/priority/audit.

---

## 3. Chat API Details

### 3.1 Request — Non-Streaming
```http
POST /v1/chat/completions
Content-Type: application/json

{
  "model": "claude-3-5-haiku-20241022",
  "project_id": "project-123",
  "messages": [
    { "role": "user", "content": "Initialize a Python app" }
  ],
  "stream": false,
  "system_prompt": "You are a helpful coding assistant."
}
```

### 3.2 Response — Non-Streaming
```json
{
  "id": "cmpl_123",
  "object": "chat.completion",
  "created": 1724130000,
  "model": "claude-3-5-haiku-20241022",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Here is how to initialize..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": { "input_tokens": 52, "output_tokens": 180, "total_tokens": 232, "total_cost": 0.0011 },
  "session_id": "sess_abc",
  "project_id": "project-123"
}
```

### 3.3 Request — Streaming (SSE)
```http
POST /v1/chat/completions
Content-Type: application/json

{
  "model": "claude-3-5-haiku-20241022",
  "project_id": "project-123",
  "messages": [
    { "role": "user", "content": "Open README.md and summarize it." }
  ],
  "stream": true
}
```

### 3.4 Response — Streaming Events
- `Content-Type: text/event-stream`
- Emits `chat.completion.chunk` frames and terminates with `[DONE]`:
```
data: { "id":"cmpl_123","object":"chat.completion.chunk","created":1724130100,"model":"claude-3-5-haiku-20241022","choices":[{"index":0,"delta":{"role":"assistant","content":"First..."}}] }
data: { "object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":" Then..."}}] }
data: { "object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":" Done."},"finish_reason":"stop"}] }
data: [DONE]
```

> **WF‑06** Chat Console consumes streaming and renders a live cursor; tool events appear in the **Tool Timeline**. See 03/06 specs.

### 3.5 Status & Cancel
```http
GET /v1/chat/completions/sess_abc/status
```
```json
{
  "session_id": "sess_abc",
  "project_id": "project-123",
  "model": "claude-3-5-haiku-20241022",
  "is_running": false,
  "created_at": "2025-08-18T18:30:00Z",
  "updated_at": "2025-08-18T18:32:11Z",
  "total_tokens": 232,
  "total_cost": 0.0011,
  "message_count": 3
}
```
```http
DELETE /v1/chat/completions/sess_abc
```

### 3.6 MCP Inline in Chat (Optional)
You may pass an MCP configuration with the chat request:
```json
{
  "model": "claude-3-5-haiku-20241022",
  "project_id": "project-123",
  "messages": [{ "role": "user", "content": "Read ./src/index.ts" }],
  "stream": true,
  "mcp": {
    "enabled_servers": ["fs-local","bash"],
    "enabled_tools": ["fs.read","fs.write","bash.run"],
    "priority": ["fs.read","bash.run"],
    "audit_log": true
  }
}
```

---

## 4. Models API

### 4.1 List
```http
GET /v1/models
```
**Response**
```json
{
  "data": [
    { "id": "claude-3-haiku", "object": "model", "created": 1720000000, "owned_by": "anthropic" },
    { "id": "claude-3-5-haiku-20241022", "object": "model", "created": 1724100000, "owned_by": "anthropic" }
  ]
}
```

### 4.2 Capabilities
```http
GET /v1/models/capabilities
```
**Response**
```json
{
  "data": [
    {
      "id": "claude-3-haiku",
      "name": "Claude 3 Haiku",
      "description": "Fast model for coding",
      "max_tokens": 200000,
      "supports_streaming": true,
      "supports_tools": true,
      "pricing": { "input": 0.0008, "output": 0.0016 }
    }
  ]
}
```

---

## 5. Projects API

### 5.1 List
```http
GET /v1/projects
```
**Response**
```json
{
  "projects": [
    {
      "id": "project-123",
      "name": "My Repo Analyzer",
      "description": "Demo project",
      "path": "/Users/nick/code/repo",
      "created_at": "2025-08-17T10:00:00Z",
      "updated_at": "2025-08-18T16:50:00Z"
    }
  ]
}
```

### 5.2 Create
```http
POST /v1/projects
Content-Type: application/json

{ "name": "My App", "description": "Demo", "path": "/path/optional" }
```

### 5.3 Detail & Delete
```http
GET /v1/projects/project-123
DELETE /v1/projects/project-123
```

---

## 6. Sessions API

### 6.1 List / Filter
```http
GET /v1/sessions
GET /v1/sessions?project_id=project-123
```

### 6.2 Create
```http
POST /v1/sessions
Content-Type: application/json

{
  "project_id": "project-123",
  "model": "claude-3-haiku",
  "title": "Exploration",
  "system_prompt": "You are a code agent."
}
```

### 6.3 Detail / Delete
```http
GET /v1/sessions/sess_abc
DELETE /v1/sessions/sess_abc
```

### 6.4 Stats
```http
GET /v1/sessions/stats
```
**Response**
```json
{
  "active_sessions": 2,
  "total_tokens": 43000,
  "total_cost": 0.58,
  "total_messages": 120
}
```

---

## 7. Health
```http
GET /health
```
**Response**
```json
{
  "ok": true,
  "version": "1.2.3",
  "active_sessions": 2,
  "uptime_seconds": 86400
}
```

---

## 8. Errors & Status Codes

- `400` — Bad request (validation error)
- `401` — Unauthorized (missing/invalid auth)
- `403` — Forbidden
- `404` — Not found (session/project)
- `409` — Conflict (already running)
- `429` — Rate limited
- `500/503` — Server error / service unavailable

**Envelope**
```json
{ "error": { "code": "not_found", "message": "Session not found", "status": 404 } }
```

---

## 9. Security & Limits

- Prefer **HTTPS** and store secrets in Keychain on client.
- Redact tokens in logs; never print request bodies containing secrets.
- Apply CORS if exposed to browsers.
- Streaming timeouts + retry/backoff recommended on the client.

---

## 10. Wireframe References

- **WF‑01** Settings → `GET /health`
- **WF‑02** Home → `GET /v1/projects`, `GET /v1/sessions`, `GET /v1/sessions/stats`
- **WF‑03/04** Projects/Detail → `/v1/projects*`, `/v1/sessions?project_id=`
- **WF‑05** New Session → `POST /v1/sessions`, `GET /v1/models*`
- **WF‑06** Chat → `POST /v1/chat/completions` (+SSE), `GET status`, `DELETE`
- **WF‑07** Models → `/v1/models*`
- **WF‑08** Analytics → `GET /v1/sessions/stats`
- **WF‑09** Diagnostics → `POST /v1/chat/completions/debug`
- **WF‑10/11** MCP → `/v1/mcp/*` (proposed) and chat inline `mcp{...}`
