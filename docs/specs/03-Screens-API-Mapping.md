# Claude Code iOS Spec — 03 Screens & API Mapping

This document maps each screen’s **purpose**, **wireframe ID**, **data dependencies**, **user actions**, and the **exact API calls** (curl + Swift).

---

## 1) Settings (Onboarding) — **WF‑01**
**Purpose**: Configure Base URL, API key; validate server.
**Data**: `GET /health`
**User Actions**: Enter base URL & key → Validate → Save.

**curl**
```bash
curl -sS http://localhost:8000/health
```

**Swift**
```swift
let url = URL(string: "\(base)/health")!
let (data, _) = try await URLSession.shared.data(from: url)
let health = try JSONDecoder().decode(HealthResponse.self, from: data)
```

---

## 2) Home (Command Center) — **WF‑02**
**Purpose**: Overview of projects, active sessions, KPIs.
**Data**: `GET /v1/projects`, `GET /v1/sessions`, `GET /v1/sessions/stats`

**curl**
```bash
curl -sS \(base)/v1/projects
curl -sS \(base)/v1/sessions
curl -sS \(base)/v1/sessions/stats
```

**Swift (snippet)**
```swift
async let projects: ProjectsEnvelope = client.get("/v1/projects")
async let sessions: SessionsEnvelope = client.get("/v1/sessions")
async let stats: SessionStats = client.get("/v1/sessions/stats")
```

---

## 3) Projects List — **WF‑03**
**Purpose**: Browse and create projects.
**Data**: `GET /v1/projects`, `POST /v1/projects`

**curl (create)**
```bash
curl -X POST \(base)/v1/projects -H 'Content-Type: application/json' -d '{"name":"New Project","description":"Demo"}'
```

**Swift (create)**
```swift
let body = ["name":"New Project","description":"Demo"]
let project: Project = try await client.post("/v1/projects", body: body)
```

---

## 4) Project Detail — **WF‑04**
**Purpose**: Show project info and related sessions.
**Data**: `GET /v1/projects/{id}`, `GET /v1/sessions?project_id=`

**curl**
```bash
curl -sS \(base)/v1/projects/project-123
curl -sS "\(base)/v1/sessions?project_id=project-123"
```

---

## 5) New Session — **WF‑05**
**Purpose**: Start a session with model and system prompt; pick MCP tools.
**Data**: `GET /v1/models`, `GET /v1/models/capabilities`, `POST /v1/sessions` or via first chat call.

**curl (create session)**
```bash
curl -X POST \(base)/v1/sessions -H 'Content-Type: application/json' -d '{
  "project_id":"project-123","model":"claude-3-haiku","title":"Exploration"
}'
```

**Swift (create)**
```swift
struct NewSession: Codable { let projectId: String; let model: String; let title: String? }
let created: Session = try await client.post("/v1/sessions", body: NewSession(projectId:"project-123", model:"claude-3-haiku", title:"Exploration"))
```

---

## 6) Chat Console — **WF‑06**
**Purpose**: Real-time streaming chat; tool timeline; usage.
**Data**: `POST /v1/chat/completions` (stream true/false), `GET /v1/chat/completions/{id}/status`, `DELETE /v1/chat/completions/{id}`

**curl (stream)**
```bash
curl -N -X POST \(base)/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model":"claude-3-haiku","project_id":"project-123","messages":[{"role":"user","content":"Hello"}],"stream":true
}'
```

**Swift SSE Reader (minimal)**
```swift
func streamChat(_ req: ChatRequest, base: String) async throws -> AsyncThrowingStream<String, Error> {
    var request = URLRequest(url: URL(string: "\(base)/v1/chat/completions")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(req)
    let (bytes, _) = try await URLSession.shared.bytes(for: request)
    return AsyncThrowingStream { cont in
        Task {
            do {
                for try await line in bytes.lines {
                    cont.yield(String(line))
                }
                cont.finish()
            } catch { cont.finish(throwing: error) }
        }
    }
}
```

**Status & Stop**
```bash
curl -sS \(base)/v1/chat/completions/sess_abc/status
curl -X DELETE \(base)/v1/chat/completions/sess_abc
```

---

## 7) Models Catalog — **WF‑07**
**Purpose**: Browse models and capabilities.
**Data**: `GET /v1/models`, `GET /v1/models/capabilities`, `GET /v1/models/{id}`

---

## 8) Analytics — **WF‑08**
**Purpose**: KPIs and cost/token charts.
**Data**: `GET /v1/sessions/stats`

---

## 9) Diagnostics — **WF‑09**
**Purpose**: Network logs, debug echo.
**Data**: `POST /v1/chat/completions/debug`

**curl**
```bash
curl -X POST \(base)/v1/chat/completions/debug -H 'Content-Type: application/json' -d '{"input":"test"}'
```

---

## 10) MCP Settings — **WF‑10**
**Purpose**: Discover & configure MCP servers/tools; set defaults.
**Data**: `GET /v1/mcp/servers[?scope=]`, `GET /v1/mcp/servers/{id}/tools`

---

## 11) Session Tool Picker — **WF‑11**
**Purpose**: Choose enabled servers/tools per session; set priority and audit logging.
**Data**: inline `mcp{...}` in chat request **or** `POST /v1/sessions/{id}/tools`

---

## Instrumentation & Errors (All Screens)
- Log structured events `{ts, scope, path, status, ms}`
- Show inline error toasts; expose “Retry” and “Open Diagnostics”
- For SSE stalls, retry with backoff; allow switch to non-streaming
