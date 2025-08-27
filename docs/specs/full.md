Claude Code iOS — All-in-One Spec & Wireframes (Theme-Updated)

Version: v1.0 (consolidated from all Canvas docs in this chat)

This single Markdown file supersedes and merges: Backend & API, Swift Data Models, Screens & API Mapping, Theming & Typography, Wireframes, and MCP Configuration & Tools. It also deepens the tooling story—detailing every major tool call and stream response form Claude can emit—and expands the Chat wireframes to production fidelity.

⸻

0) Canonical Theme (HSL variables)

Use these tokens everywhere (Tailwind, CSS-in-JS, native theming shims).

@layer base {
  :root {
    --background: 0 0% 0%;
    --foreground: 0 0% 73%;
    --muted: 0 12% 15%;
    --muted-foreground: 0 12% 65%;
    --popover: 0 0% 0%;
    --popover-foreground: 0 0% 83%;
    --card: 0 0% 0%;
    --card-foreground: 0 0% 78%;
    --border: 0 0% 5%;
    --input: 0 0% 8%;
    --primary: 220 13% 86%;
    --primary-foreground: 220 13% 26%;
    --secondary: 220 3% 25%;
    --secondary-foreground: 220 3% 85%;
    --accent: 0 0% 15%;
    --accent-foreground: 0 0% 75%;
    --destructive: 8 89% 47%;
    --destructive-foreground: 0 0% 100%;
    --ring: 220 13% 86%;
    --chart-1: 220 13% 86%;
    --chart-2: 220 3% 25%;
    --chart-3: 0 0% 15%;
    --chart-4: 220 3% 28%;
    --chart-5: 220 16% 86%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 0 0% 0%;
    --foreground: 0 0% 73%;
    --muted: 0 12% 15%;
    --muted-foreground: 0 12% 65%;
    --popover: 0 0% 0%;
    --popover-foreground: 0 0% 83%;
    --card: 0 0% 0%;
    --card-foreground: 0 0% 78%;
    --border: 0 0% 5%;
    --input: 0 0% 8%;
    --primary: 220 13% 86%;
    --primary-foreground: 220 13% 26%;
    --secondary: 220 3% 25%;
    --secondary-foreground: 220 3% 85%;
    --accent: 0 0% 15%;
    --accent-foreground: 0 0% 75%;
    --destructive: 8 89% 47%;
    --destructive-foreground: 0 0% 100%;
    --ring: 220 13% 86%;
    --chart-1: 220 13% 86%;
    --chart-2: 220 3% 25%;
    --chart-3: 0 0% 15%;
    --chart-4: 220 3% 28%;
    --chart-5: 220 16% 86%;
  }
}

Token usage quick map

Element/State	Token(s)
App/Page background	--background
Primary text	--foreground
Muted text	--muted-foreground
Card surface	--card + border --border
Inputs	bg --input + border --border
Primary Button	--primary / --primary-foreground
Secondary Button	--secondary / --secondary-foreground
Accent chips	--accent / --accent-foreground
Destructive	--destructive / --destructive-foreground
Focus/outline	--ring
Charts	--chart-1 … --chart-5


⸻

1) Executive Summary
	•	Goal: A native SwiftUI iOS client for a Claude Code gateway (OpenAI-compatible) that supports project/session management, model browsing, and real-time streaming chat with full tooling visibility.
	•	Focus: Production-grade Chat console that renders assistant text, tools timeline, diff/outputs, and session telemetry (tokens/cost/time). MCP configuration lets users discover/enable per-project MCP servers and select per-session tools.
	•	Theme: Unified cyberpunk-dark aesthetic realized via the HSL tokens above.

⸻

2) Claude Code Primer (what we model)

Claude Code is an agentic coding system that can read/modify files, run shell commands, and reason over a workspace. The gateway adapts Claude’s streaming JSON/JSONL into OpenAI-style chat APIs, including:
	•	chat.completion (non-stream), and
	•	chat.completion.chunk (stream; line-delimited SSE).

During a turn, the assistant may emit:
	•	assistant text deltas,
	•	tool_use (start tool call),
	•	tool_result (completion/result or error),
	•	usage summaries,
	•	errors.

We render all of these in the Chat console.

⸻

3) Backend & API (OpenAI-compatible Gateway)

3.1 Endpoints

Chat
	•	POST /v1/chat/completions (supports stream=true)
	•	GET /v1/chat/completions/{session_id}/status
	•	DELETE /v1/chat/completions/{session_id}
	•	POST /v1/chat/completions/debug (echo/validator)

Models
	•	GET /v1/models
	•	GET /v1/models/{model_id}
	•	GET /v1/models/capabilities

Projects
	•	GET /v1/projects
	•	POST /v1/projects
	•	GET /v1/projects/{project_id}
	•	DELETE /v1/projects/{project_id}

Sessions
	•	GET /v1/sessions[?project_id]
	•	POST /v1/sessions
	•	GET /v1/sessions/{session_id}
	•	DELETE /v1/sessions/{session_id}
	•	GET /v1/sessions/stats

Health
	•	GET /health

MCP (proposed additions)
	•	GET /v1/mcp/servers?scope=user|project&project_id=...
	•	GET /v1/mcp/servers/{server_id}/tools
	•	POST /v1/sessions/{session_id}/tools (enable/priority/audit)
	•	(Optional) include mcp{...} in POST /v1/chat/completions.

⸻

3.2 Chat — Requests

Non-streaming

POST /v1/chat/completions
Content-Type: application/json

{
  "model": "claude-3-5-haiku-20241022",
  "project_id": "project-123",
  "session_id": "optional-existing-session",
  "messages": [
    { "role": "system", "content": "You are a helpful coding assistant." },
    { "role": "user", "content": "Summarize repo structure." }
  ],
  "stream": false
}

Streaming (SSE)

POST /v1/chat/completions
Content-Type: application/json

{
  "model": "claude-3-5-haiku-20241022",
  "project_id": "project-123",
  "messages": [
    { "role": "user", "content": "Find TODOs in src/, then propose fixes." }
  ],
  "stream": true,
  "mcp": {
    "enabled_servers": ["fs-local","bash"],
    "enabled_tools": ["fs.read","grep.search","bash.run","fs.write","multi.edit"],
    "priority": ["grep.search","fs.read","multi.edit","bash.run"],
    "audit_log": true
  }
}


⸻

3.3 Chat — Responses

Non-streaming (OpenAI style + extensions)

{
  "id": "cmpl_7xVh...Q",
  "object": "chat.completion",
  "created": 1724130000,
  "model": "claude-3-5-haiku-20241022",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "I found 12 TODOs across 5 files..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": { "input_tokens": 428, "output_tokens": 1365, "total_tokens": 1793, "total_cost": 0.0142 },
  "session_id": "sess_k9b2...",
  "project_id": "project-123"
}

Streaming (SSE) — each line is a chunk; stream ends with [DONE]

data: { "id":"cmpl_...","object":"chat.completion.chunk",
        "choices":[{ "index":0, "delta":{"role":"assistant","content":"Scanning files..."} }] }

data: { "object":"chat.completion.chunk",
        "choices":[{ "index":0, "delta":{"content":" Found 3 candidates in src/."} }] }

data: { "object":"tool_use",
        "id":"tu_01H...", "name":"grep.search",
        "input":{"pattern":"TODO|FIXME","path":"src"} }

data: { "object":"tool_result",
        "tool_id":"tu_01H...", "name":"grep.search", "is_error":false,
        "content":"src/app.ts:42 // TODO: cache layer ...\nsrc/db.ts:11 // FIXME: ...",
        "duration_ms": 212 }

data: { "object":"tool_use",
        "id":"tu_01J...", "name":"multi.edit",
        "input":{"edits":[{"path":"src/app.ts","range":[40,50],"text":"// cached\n"}]} }

data: { "object":"tool_result",
        "tool_id":"tu_01J...", "name":"multi.edit", "is_error":false,
        "content":"Applied 1 edit(s)", "duration_ms": 95 }

data: { "object":"chat.completion.chunk",
        "choices":[{ "index":0, "delta":{"content":" Applied a safe edit to app.ts; see diff below."}}] }

data: { "object":"usage",
        "input_tokens": 521, "output_tokens": 1873, "total_cost": 0.0169 }

data: [DONE]

Gateway notes: it may wrap tool_* frames inside chat.completion.chunk payloads (implementation choice). The UI should be resilient: parse by object field when available; otherwise look at choices[].delta.tool_* extensions.

⸻

3.4 Status & Stop

GET /v1/chat/completions/{session_id}/status

{
  "session_id": "sess_k9b2...",
  "project_id": "project-123",
  "model": "claude-3-5-haiku-20241022",
  "is_running": false,
  "message_count": 12,
  "total_tokens": 21930,
  "total_cost": 0.212,
  "created_at": "2025-08-18T18:30:00Z",
  "updated_at": "2025-08-18T18:42:55Z",
  "enabled_servers": ["fs-local","bash"],
  "enabled_tools": ["fs.read","grep.search","bash.run","fs.write","multi.edit"],
  "priority": ["grep.search","fs.read"]
}

DELETE /v1/chat/completions/{session_id}


⸻

4) Claude Tooling: Catalog & Wire Protocol (deep dive)

Below is a normalized tooling schema your UI can expect to see in streams. Names may vary; the gateway standardizes them.

4.1 Tool call envelope (streamed)

// tool_use
{
  "object": "tool_use",
  "id": "tu_01H...",
  "name": "grep.search",
  "input": { "pattern": "TODO|FIXME", "path": "src" },
  "ts": "2025-08-18T18:31:16.120Z"
}

// tool_result (success)
{
  "object": "tool_result",
  "tool_id": "tu_01H...",
  "name": "grep.search",
  "is_error": false,
  "content": "src/app.ts:42 // TODO:...\nsrc/db.ts:11 // FIXME:...",
  "duration_ms": 212
}

// tool_result (error)
{
  "object": "tool_result",
  "tool_id": "tu_01Z...",
  "name": "bash.run",
  "is_error": true,
  "content": "bash: yarn: command not found",
  "exit_code": 127,
  "duration_ms": 18
}

4.2 Common tools (inputs/outputs)

Tool	Input	Output	Notes
fs.read	{ "path": "string", "encoding?": "utf8" }	content (string)	Large outputs may be truncated; gateway can emit a result frame.
fs.write	{ "path": "string", "content": "string", "create?": true }	content = “bytes written: …”	Treat as destructive (confirm UI).
multi.edit	{ "edits": [{ "path":"", "range":[start,end], "text":"" }], "dry_run?":false }	“Applied N edit(s)”	Prefer this to many single writes.
grep.search	{ "pattern": "regex", "path":"dir-or-file" }	multiline content	Present as collapsible result.
glob	{ "pattern": "src/**/*.ts" }	file list text	Good precursor to read/edit.
ls	{ "path": "dir" }	file listing	Use monospace panel.
bash.run	{ "cmd": "string", "timeout_ms?": 30000 }	STDOUT/ERR, exit code	Live stream if gateway supports.
multi.write	{ "files":[{"path":"","content":""}], "overwrite?":true }	summary	Batch creation.
edit.file	{ "path":"", "instructions":"patch/codex" }	diff text	Used by some Claude skills.

UI color binding:
success row → --accent / --accent-foreground
error row → --destructive / --destructive-foreground
running row (spinner/ring) → outline --ring

4.3 Concurrency & ordering

The assistant may start multiple tools in parallel. Order by ts and group by tool_id. When a tool_result arrives:
	•	close the row,
	•	attach metrics (duration_ms, exit_code),
	•	if is_error=true emphasize with destructive styling, and
	•	optionally surface a retry action (replays last tool_use with same input).

⸻

5) Swift Data Models (iOS)

Below are complete model types the app uses (condensed where uncritical).

import Foundation

// MARK: - Core Chat

public struct ChatContent: Codable, Equatable {
    public let type: String          // "text", "code", etc.
    public let text: String?
}

public struct ChatMessage: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public let role: String          // "user" | "assistant" | "system"
    public let content: [ChatContent]
    public let name: String?
}

public struct ChatRequest: Codable {
    public let model: String
    public let messages: [ChatMessage]
    public let stream: Bool?
    public let projectId: String?
    public let sessionId: String?
    public let systemPrompt: String?
    public let mcp: MCPConfig?       // see MCP section
}

public struct ChatChoice: Codable {
    public let index: Int
    public let message: ChatMessage
    public let finishReason: String?
}

public struct Usage: Codable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?
    public let totalCost: Double?
}

public struct ChatCompletion: Codable {
    public let id: String
    public let object: String        // "chat.completion"
    public let created: Int
    public let model: String
    public let choices: [ChatChoice]
    public let usage: Usage?
    public let sessionId: String?
    public let projectId: String?
}

// MARK: - Streaming (SSE)

public struct ChatDelta: Codable {
    public let role: String?
    public let content: String?      // appended incrementally
}

public struct ChatChunk: Codable {
    public let id: String?
    public let object: String        // "chat.completion.chunk" | "tool_use" | "tool_result" | "usage"
    public let created: Int?
    public let model: String?
    public let choices: [ChunkChoice]?

    public struct ChunkChoice: Codable {
        public let index: Int
        public let delta: ChatDelta
        public let finishReason: String?
    }

    // tool frames (optional fields present when object == "tool_*")
    public let name: String?
    public let input: [String: JSONAny]?
    public let tool_id: String?
    public let is_error: Bool?
    public let content: String?
    public let duration_ms: Int?
    public let exit_code: Int?

    // usage (object == "usage")
    public let input_tokens: Int?
    public let output_tokens: Int?
    public let total_cost: Double?
}

// JSONAny helper for arbitrary tool input schemas
public enum JSONAny: Codable, Equatable {
    case string(String), number(Double), bool(Bool), object([String: JSONAny]), array([JSONAny]), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self)   { self = .bool(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([String: JSONAny].self) { self = .object(v); return }
        if let v = try? c.decode([JSONAny].self) { self = .array(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

// MARK: - Models Catalog

public struct ModelObject: Codable, Identifiable {
    public let id: String
    public let created: Int
    public let ownedBy: String
}

public struct Pricing: Codable {
    public let input: Double
    public let output: Double
}

public struct ModelCapability: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let maxTokens: Int
    public let supportsStreaming: Bool
    public let supportsTools: Bool
    public let pricing: Pricing
    public let features: [String]?
}

// MARK: - Projects & Sessions

public struct Project: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let path: String?
    public let createdAt: String
    public let updatedAt: String
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
}

public struct SessionStats: Codable {
    public let activeSessions: Int
    public let totalTokens: Int
    public let totalCost: Double
    public let totalMessages: Int
}

// MARK: - MCP Models

public struct MCPServer: Codable, Identifiable {
    public let id: String
    public let name: String
    public let scope: String         // "user" | "project"
    public let executable: String?
    public let version: String?
    public let status: String        // "available" | "error" | "missing"
}

public struct MCPTool: Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let title: String?
    public let description: String?
    public let inputSchema: [String: JSONAny]?
    public let supportsStream: Bool?
    public let dangerous: Bool?
}

public struct MCPConfig: Codable {
    public var enabledServers: [String]
    public var enabledTools: [String]
    public var priority: [String]
    public var auditLog: Bool
}

5.1 SwiftUI Theme Shim (HSL → Color)

import SwiftUI

private func hslToRGB(h: Double, s: Double, l: Double) -> (Double, Double, Double) {
    let C = (1 - abs(2*l - 1)) * s
    let X = C * (1 - abs(((h/60).truncatingRemainder(dividingBy: 2)) - 1))
    let m = l - C/2
    let (r1,g1,b1):(Double,Double,Double)
    switch h {
    case 0..<60: (r1,g1,b1) = (C,X,0)
    case 60..<120: (r1,g1,b1) = (X,C,0)
    case 120..<180: (r1,g1,b1) = (0,C,X)
    case 180..<240: (r1,g1,b1) = (0,X,C)
    case 240..<300: (r1,g1,b1) = (X,0,C)
    default: (r1,g1,b1) = (C,0,X)
    }
    return (r1+m, g1+m, b1+m)
}

public extension Color {
    init(h: Double, s: Double, l: Double, a: Double = 1) {
        let (r,g,b) = hslToRGB(h: h, s: s/100.0, l: l/100.0)
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

public enum Theme {
    public static let background = Color(h: 0, s: 0, l: 0)
    public static let foreground = Color(h: 0, s: 0, l: 73)
    public static let muted      = Color(h: 0, s: 12, l: 15)
    public static let mutedFg    = Color(h: 0, s: 12, l: 65)
    public static let card       = Color(h: 0, s: 0, l: 0)
    public static let cardFg     = Color(h: 0, s: 0, l: 78)
    public static let border     = Color(h: 0, s: 0, l: 5)
    public static let input      = Color(h: 0, s: 0, l: 8)
    public static let primary    = Color(h: 220, s: 13, l: 86)
    public static let primaryFg  = Color(h: 220, s: 13, l: 26)
    public static let secondary  = Color(h: 220, s: 3,  l: 25)
    public static let secondaryFg= Color(h: 220, s: 3,  l: 85)
    public static let accent     = Color(h: 0, s: 0, l: 15)
    public static let accentFg   = Color(h: 0, s: 0, l: 75)
    public static let destructive= Color(h: 8, s: 89, l: 47)
    public static let destructiveFg = Color(h: 0, s: 0, l: 100)
    public static let ring       = Color(h: 220, s: 13, l: 86)
}


⸻

6) Screens & API Mapping (with token usage)

WF-01 — Settings (Onboarding)
	•	Purpose: Configure Base URL, API key; validate connectivity; defaults (Streaming).
	•	API: GET /health
	•	Token usage:
page --background; titles --foreground; inputs --input/--border; Validate button --primary/--primary-foreground; health OK chip --accent; health ERR --destructive.
	•	UX details:
	•	“Validate” shows server version, active sessions, last ping.
	•	Toggle: Streaming by default (persists to UserDefaults/Keychain).

cURL

curl -sS http://localhost:8000/health


⸻

WF-02 — Home / Command Center
	•	Sections: Quick Actions, Recent Projects (GET /v1/projects), Active Sessions (GET /v1/sessions), KPIs (GET /v1/sessions/stats).
	•	Token usage: cards --card + --border; headers --foreground; stat numbers --primary; labels --muted-foreground.

⸻

WF-03 — Projects
	•	API: GET /v1/projects, POST /v1/projects
	•	UX: search/filter, sort by updated/token usage; row → Project Detail.

Create Project

curl -sS -X POST http://localhost:8000/v1/projects \
  -H 'Content-Type: application/json' \
  -d '{ "name":"My Repo","description":"Demo","path":"/Users/nick/code" }'


⸻

WF-04 — Project Detail
	•	API: GET /v1/projects/{id}, GET /v1/sessions?project_id={id}
	•	Actions: New Session, Debug, Metrics; Delete (if supported).
	•	Tokens: toolbar uses --secondary; Delete uses --destructive.

⸻

WF-05 — New Session
	•	API: GET /v1/models, GET /v1/models/capabilities, POST /v1/sessions
	•	Fields: Model picker, Title, System prompt, MCP Enabled toggle, Session Tool Picker (links to WF-11).
	•	Tokens: inputs --input; Start button --primary.

⸻

WF-06 — Chat Console  (expanded)

The Chat screen is the core. It must render: transcript, Tool Timeline, session telemetry, MCP controls, and stream status.

Layout (phone)
	•	Top: Session name, Model chip, Stream indicator (ring --ring)
	•	Body:
	•	Transcript panel (left/top): message bubbles
	•	Tool Timeline (right/bottom): per tool_id rows
	•	Telemetry: tokens/cost/ms/turns (chips)
	•	Bottom: Composer (multiline text, model switch, Stream toggle, Send, Stop)

States
	•	Streaming: typing caret shimmer; chunk rate (chars/s).
	•	Tool running: row with spinner + “sent at” timestamp.
	•	Tool success: row shifts to accent; shows summary; View Full Output (sheet).
	•	Tool error: destructive style; Retry (replays last tool_use).
	•	Concurrent tools: group rows, show parallel progress bars.
	•	Audit log on: filter chip to show only tool_* events.

API
	•	POST /v1/chat/completions (streaming SSE)
	•	GET /v1/chat/completions/{id}/status (on demand)
	•	DELETE /v1/chat/completions/{id} (Stop)

Hotkey cues
	•	⌘⏎ Send, ⎋ Stop, ⌘K clear input.

Tool Inspector (inline)
Select a tool row → panel with:
	•	raw tool_use input JSON
	•	full tool_result content (monospace)
	•	metrics (duration, exit code)
	•	Re-run with edits (prepopulates input JSON editor)

⸻

WF-07 — Models Catalog
	•	API: GET /v1/models, GET /v1/models/capabilities, GET /v1/models/{id}
	•	UX: grid/list; details page shows max tokens, streaming/tools support, indicative pricing.

⸻

WF-08 — Analytics
	•	API: GET /v1/sessions/stats
	•	Charts:
	•	Tokens over time: area using --chart-1
	•	Cost by model: bars using --chart-2..5
	•	Tool invocation counts: horizontal bars (--chart-3)

⸻

WF-09 — Diagnostics
	•	API: POST /v1/chat/completions/debug
	•	UX: Live log (requests, SSE lines, errors). Run Test button with sample payload.
	•	Tokens: results table uses --card + --border; run button --secondary.

⸻

WF-10 — MCP Settings
	•	API: GET /v1/mcp/servers?scope=user|project, GET /v1/mcp/servers/{id}/tools
	•	UX:
	•	Scope filter (All/User/Project).
	•	Server list (status: available/missing/error).
	•	Tool list per server; toggle dangerous with confirmation.
	•	Priority drag handle.
	•	Save as Default (user & per-project overrides).
	•	Tokens: enabled= --primary; dangerous=--destructive.

⸻

WF-11 — Session Tool Picker
	•	Entry: New Session sheet or Chat → Session Menu.
	•	API: POST /v1/sessions/{id}/tools (or inline mcp{...} with first chat call).
	•	UX: show defaults, choose subset, re-order priority, Save & Apply.

⸻

7) Wireframes (ASCII) with Token Notes

Each block below references tokens for quick implementation.

WF-01: Settings

┌──────────────────────────────────────────────────────────┐
│ Claude Code                                           9:41│
│ SETTINGS                                                ⚙ │
│  Base URL [ https://api.example.com      ]  (input)      │
│  API Key  [ ****************            ]  (input)       │
│  Streaming [  ON ]  SSE Buffer [  64KiB ▾ ]              │
│  [   VALIDATE   ]                                       │
│  Health:  OK • Last Ping 2s • Version 1.2.3 • Sessions 4 │
└──────────────────────────────────────────────────────────┘
Tokens: page=background; inputs=input/border; Validate=primary; Health OK=accent

WF-02: Home

Quick Actions: [ Start Session ] [ New Project ] [ Analytics ]
Recent Projects:
  ▸ Project Alpha        /usr/local/alpha            Feb 20
  ▸ Beta Project         /home/user/beta             Feb 18
Active Sessions:
  [ Gamma Project ]   model-x  12m     [ Project Delta ] model-y 5m
KPIs: [10.5K Tokens] [215 Sessions] [8 Models]

WF-03: Projects

Projects  (+ New)
[Search …]
▸ Alpha Project     /home/alpha        12.1K tokens   2 sessions
▸ Beta Project      /home/beta         11.9K tokens   1 session
▸ Gamma Project     /opt/gamma         13.4K tokens   4 sessions

WF-04: Project Detail

Project Alpha     path /usr/local/project-alpha
Status Active  •  Model model-x  •  Created Feb 16, 2024
[ Stop ] [ Debug ] [ Deploy ] [ Metrics ]  (secondary buttons)
Endpoints:
  POST /projects/.../functions/execute
  GET  /projects/.../config
Env:
  API_KEY •••••••    DEBUG_MODE true

WF-05: New Session

New Session
Project: [ Project Alpha ▾ ]
Model:   [ claude-3-5-haiku-20241022 ▾ ]
Title:   [ Exploration                 ]
System Prompt:
[ You are a helpful coding assistant...                ]
MCP Enabled [x]    [ Configure Tools… ] → WF-11
[ START SESSION ] (primary)

WF-06: Chat Console (focused)

┌───────────────────────────────────────────────────────────────────────────┐
│ Session: Alpha • Model: claude-3.5-haiku • [Streaming ●] • [Stop]         │
├───────────────────────────────────────────────────────────────────────────┤
│ Transcript                                  │ Tools Timeline               │
│ ───────────────────────────────────────────  │ ───────────────────────────  │
│ User  09:41  "Find TODOs in src/"           │ 09:41  grep.search  •••      │
│ Claude … "Scanning files..." ⌶              │        input {pattern:"…"}    │
│ Claude … "Found 3 in src/app.ts, db.ts"     │ 09:41  grep.search ✓ 212ms   │
│ ToolResult: grep → (click to view)          │        2 hits                 │
│ Claude … "Applied safe edit to app.ts"      │ 09:42  multi.edit  •••       │
│                                             │ 09:42  multi.edit  ✓ 95ms    │
│                                             │ 09:42  bash.run    ✗ 18ms    │
│                                             │        "yarn not found"      │
│                                             │  [Retry]                     │
├───────────────────────────────────────────────────────────────────────────┤
│ Telemetry:  tokens 1.8K  •  cost $0.017  •  chunks 452  •  t=12.3s        │
│ Compose:  [ Type prompt… ]  [ Model ▾ ]  [ Stream ☐ ]  [ Send ]           │
└───────────────────────────────────────────────────────────────────────────┘
Tokens: success=accent; error=destructive; focus ring=ring; buttons=primary/secondary

WF-07: Models

Models:
  ▣ claude-3-5-haiku  (STREAM, TOOLS, max 200k, $)  [Set Default]
  ▣ claude-3-sonnet   (STREAM, TOOLS, max 500k, $$)

WF-08: Analytics

Active Sessions  4    Tokens Used 43,000   Cost $0.58
[ Area: tokens over time ]  [ Bars: cost by model ]  [ Tools: invocations ]

WF-09: Diagnostics

Log:
12:02:33  POST /v1/chat 200 (56ms)
12:02:34  SSE line received (chat.completion.chunk)
12:02:35  tool_result bash.run ERROR exit 127
[ Run Test Payload ]

WF-10: MCP Settings

Scope [ All ▾ ]  Project [ Alpha ▾ ]
Servers:
  [✓] fs-local     v1.3.0  available
  [ ] bash         v0.9.2  available
  [!] web-scraper  missing  (Install…)
Tools (fs-local):
  [✓] fs.read    [≡]    [✓] fs.write [≡]    [ ] fs.search [≡]
Priority: 1) fs.read  2) fs.write
Audit Log [x]   [ Save as Default ]

WF-11: Session Tool Picker

Use defaults from: ( User • Project • None )
Enabled Servers: [✓] fs-local   [✓] bash   [ ] web-scraper
Enabled Tools:   [ fs.read ] [ fs.write ] [ bash.run ] [ grep.search ]
Priority:        1) fs.read   2) bash.run   3) fs.write
[ Cancel ]                          [ Save & Apply ]


⸻

8) Theming, Typography, and Tailwind examples

Typography: SF Pro Text (24/18/16/12). Monospace (JetBrains Mono) for code/logs.

Tailwind example

<div class="bg-[hsl(var(--card))] border border-[hsl(var(--border))] rounded-[var(--radius)] p-4">
  <h2 class="text-[hsl(var(--foreground))] text-xl mb-2">Chat Console</h2>
  <div class="text-[hsl(var(--muted-foreground))]">Streaming enabled</div>
  <button class="mt-4 w-full rounded-[var(--radius)]
                 bg-[hsl(var(--primary))] text-[hsl(var(--primary-foreground))] ring-1 ring-[hsl(var(--ring))] py-2">
    Send
  </button>
</div>


⸻

9) MCP Configuration & Tools (UX + API)

Discovery

GET /v1/mcp/servers?scope=user|project&project_id=...

List Tools

GET /v1/mcp/servers/{server_id}/tools

Per-session selection

POST /v1/sessions/{session_id}/tools
{
  "enabled_servers": ["fs-local","bash"],
  "enabled_tools": ["fs.read","fs.write","bash.run"],
  "priority": ["fs.read","bash.run"],
  "audit_log": true
}

Inline in chat call

"mcp": {
  "enabled_servers": ["fs-local","bash"],
  "enabled_tools": ["fs.read","grep.search","bash.run"],
  "priority": ["grep.search","fs.read"],
  "audit_log": true
}

UX rules
	•	Dangerous tools flagged with --destructive; require confirmation on first use.
	•	Merge precedence when starting a session: session > project > user defaults.

⸻

10) Diagnostics, Logging & Error Handling
	•	Streaming stalls → show reconnect hint; allow fallback to non-streaming.
	•	Session not found → disable controls, prompt to start new session.
	•	CLI unavailable (503) → show actions: Check server, Switch server, Retry.
	•	Audit log emits summarized tool frames; togglable in Chat.
	•	Structured logs: {ts, scope, level, msg, meta}; redact secrets.

⸻

11) QA Checklist (key)
	1.	Settings validation (bad URL, cert issues).
	2.	Models list + capability detail.
	3.	Projects lifecycle (create/list/detail/delete).
	4.	Sessions lifecycle (create/list/detail/stop).
	5.	Chat streaming (happy path, stop mid-stream).
	6.	Tool timeline (success/error; concurrent tools).
	7.	Status endpoint during/after stream.
	8.	Analytics numbers match session history.
	9.	MCP: discovery, tool selection, audit log on/off.
	10.	Accessibility (Dynamic Type; VoiceOver reads incoming chunks).

⸻

12) Appendix — cURL Recipes

Send streaming chat

curl -N -sS http://localhost:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{ "model": "claude-3-5-haiku-20241022",
        "project_id": "project-123",
        "messages": [{"role":"user","content":"List files then open README"}],
        "stream": true,
        "mcp": {"enabled_servers":["fs-local"],"enabled_tools":["ls","fs.read"],"priority":["ls"]} }'

Poll status

curl -sS http://localhost:8000/v1/chat/completions/sess_abc/status

Stop session

curl -sS -X DELETE http://localhost:8000/v1/chat/completions/sess_abc


⸻

Final Notes
	•	Theme enforcement: follow the token table; never hardcode hex.
	•	Chat emphasis: tool visibility and retryability are first-class; streaming remains smooth under backpressure (batch deltas).
	•	MCP: make it trivial for a user to discover, enable, prioritize, and audit tools per session.