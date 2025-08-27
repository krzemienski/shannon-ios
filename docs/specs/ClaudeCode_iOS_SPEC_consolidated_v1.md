---
title: "Claude Code iOS — Complete Product & Design Spec (Consolidated)"
version: "v1 (2025-08-21)"
notes: "Cleaned, deduplicated, and standardized into a single markdown document."
---

# Claude Code iOS — Complete Product & Design Spec (Consolidated)

> This is a cleaned consolidation of your original multi-part spec into one continuous Markdown file. Headings, code fences, and duplicated sections were normalized; deprecated sketches were removed; and minor syntax/quoting issues were corrected. See the change log below for specifics.

## Change Log (what was cleaned)
- Normalized curly quotes to straight ASCII; fixed minor markdown/code-fence issues.
- Removed meta lines about future parts (“Next message / Next up …”).
- Removed the early SSE client section (kept the later `Sources/App/Networking/SSEClient.swift`).
- Removed the NIOSSH sketch of `SSHClient.swift` with placeholders; kept the production Shout-based client.
- Ensured `TracingView.swift` includes `import UIKit` for `UIPasteboard`.
- Left all substantive content (theme, endpoints, models, views, wireframes, scripts, and final `Project.yml`) intact; deduplication favored the newer/complete versions.

---

Claude Code iOS — All-in-One Spec, Theme, API & Models (Consolidated Part 1/2)

Scope: Consolidates every Markdown doc created in this thread (PRD, Backend & API, Swift Data Models, Screens & API Mapping, MCP Tools, Theme, and the expanded chat/tooling notes). Part 2 contains all drawn wireframes (WF-01…WF-14), screen behaviors, and QA/appendices.

⸻

Table of Contents (Part 1)
	1.	Theme — Canonical HSL Tokens
	2.	Executive Summary
	3.	Claude Code Primer
	4.	Backend & API (OpenAI-compatible Gateway)
	•	4.1 Endpoint Catalog
	•	4.2 Requests/Responses
	•	4.3 Streaming SSE & Event Frames
	•	4.4 Status & Stop
	•	4.5 MCP Extensions (Proposed)
	•	4.6 Conventions, Errors & Security
	5.	Claude Tooling — Calls & Results (Deep Dive)
	6.	Swift Data Models (iOS) + Theme Shim
	•	6.1 Codable Models
	•	6.2 Streaming Chunk Models
	•	6.3 MCP Models
	•	6.4 SwiftUI Theme Shim (HSL→Color)

Part 2: Full screen specs + ASCII wireframes (WF-01…WF-14), Hyperthink planner, File View Controller, Monitoring, Tracing, token usage per surface, cURL recipes & QA.

⸻

Theme — Canonical HSL Tokens

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

Token map (UI states → tokens)

Purpose	Tokens
App/page background	--background
Primary text	--foreground
Muted text	--muted-foreground
Card surface & text	--card, --card-foreground
Borders & input fill	--border, --input
Primary/secondary CTAs	--primary/--primary-foreground, --secondary/--secondary-foreground
Accent chips/badges	--accent/--accent-foreground
Destructive actions	--destructive/--destructive-foreground
Focus ring	--ring
Charts	--chart-1 … --chart-5
Radius	--radius

Tailwind example:

<button class="bg-[hsl(var(--primary))] text-[hsl(var(--primary-foreground))] 
rounded-[var(--radius)] ring-1 ring-[hsl(var(--ring))] px-4 py-2">
  Validate
</button>


⸻

Executive Summary
	•	Product: Native SwiftUI iOS client for a Claude Code gateway (OpenAI-compatible).
	•	Core: Real-time streaming chat with Tool Timeline, Telemetry (tokens / cost / time), Hyperthink planner, and per-session MCP tool selection.
	•	Resources managed: Projects and Sessions.
	•	No separate Models screen — models are selected in New Session & Chat.
	•	Extra surfaces: File View Controller (workspace browser), Monitoring (host CPU/MEM/NET/Disk), Tracing (requests & tool spans).
	•	Theme: single HSL palette above; never hardcode hex.

⸻

Claude Code Primer

Claude Code is an agentic developer that can read/edit files, grep, glob, and run shell. The gateway adapts that stream into:
	•	Non-stream chat.completion (OpenAI shape)
	•	Stream chat.completion.chunk (SSE), interleaved with tool_use, tool_result, and usage frames.

UI must:
	•	append assistant deltas smoothly,
	•	show tool events as first-class rows,
	•	surface retry and inspect (raw inputs/outputs),
	•	record usage/cost and session status.

⸻

Backend & API (OpenAI-compatible Gateway)

4.1 Endpoint Catalog

Chat
	•	POST /v1/chat/completions  (supports stream=true)
	•	GET  /v1/chat/completions/{session_id}/status
	•	DELETE /v1/chat/completions/{session_id}
	•	POST /v1/chat/completions/debug

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

MCP (proposed)
	•	GET /v1/mcp/servers?scope=user|project&project_id=...
	•	GET /v1/mcp/servers/{server_id}/tools
	•	POST /v1/sessions/{session_id}/tools
	•	(Optional) mcp{...} inline in chat request

⸻

4.2 Requests/Responses

Non-stream request

POST /v1/chat/completions
Content-Type: application/json

{
  "model": "claude-3-5-haiku-20241022",
  "project_id": "project-123",
  "messages": [
    { "role": "system", "content": "You are a helpful coding assistant." },
    { "role": "user",   "content": "Summarize repo structure." }
  ],
  "stream": false
}

Non-stream response

{
  "id": "cmpl_7xVh...",
  "object": "chat.completion",
  "created": 1724130000,
  "model": "claude-3-5-haiku-20241022",
  "choices": [
    {
      "index": 0,
      "message": { "role": "assistant", "content": "I found these directories…" },
      "finish_reason": "stop"
    }
  ],
  "usage": { "input_tokens": 428, "output_tokens": 1365, "total_tokens": 1793, "total_cost": 0.0142 },
  "session_id": "sess_k9b2...",
  "project_id": "project-123"
}

Streaming request (with MCP)

POST /v1/chat/completions
Content-Type: application/json

{
  "model": "claude-3-5-haiku-20241022",
  "project_id": "project-123",
  "messages": [
    { "role": "user", "content": "Find TODOs in src/, propose edits, and apply them." }
  ],
  "stream": true,
  "mcp": {
    "enabled_servers": ["fs-local","bash"],
    "enabled_tools": ["fs.read","grep.search","multi.edit","bash.run"],
    "priority": ["grep.search","fs.read","multi.edit","bash.run"],
    "audit_log": true
  }
}


⸻

4.3 Streaming SSE & Event Frames

Each line is a Server-Sent Event; stream ends with [DONE].

data: { "object":"chat.completion.chunk",
        "choices":[{ "index":0, "delta":{"role":"assistant","content":"Scanning files…"} }] }

data: { "object":"tool_use",
        "id":"tu_01H...", "name":"grep.search",
        "input":{"pattern":"TODO|FIXME","path":"src"} }

data: { "object":"tool_result",
        "tool_id":"tu_01H...", "name":"grep.search",
        "is_error":false, "duration_ms":212,
        "content":"src/app.ts:42 // TODO...\nsrc/db.ts:11 // FIXME..." }

data: { "object":"tool_use", "id":"tu_01J...", "name":"multi.edit",
        "input":{"edits":[{"path":"src/app.ts","range":[40,50],"text":"// cached\n"}]} }

data: { "object":"tool_result","tool_id":"tu_01J...","name":"multi.edit",
        "is_error":false, "duration_ms":95, "content":"Applied 1 edit(s)" }

data: { "object":"chat.completion.chunk",
        "choices":[{ "index":0, "delta":{"content":" Applied edit to app.ts; see diff."}}] }

data: { "object":"usage","input_tokens":521,"output_tokens":1873,"total_cost":0.0169 }

data: [DONE]

UI binding: running rows show focus ring; success rows use accent; errors use destructive.

⸻

4.4 Status & Stop

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

4.5 MCP Extensions (Proposed)
	•	GET /v1/mcp/servers?scope=user|project&project_id=...
	•	GET /v1/mcp/servers/{server_id}/tools
	•	POST /v1/sessions/{session_id}/tools

Inline (optional) in chat requests:

"mcp": {
  "enabled_servers": ["fs-local","bash"],
  "enabled_tools": ["fs.read","grep.search","bash.run"],
  "priority": ["grep.search","fs.read"],
  "audit_log": true
}


⸻

4.6 Conventions, Errors & Security
	•	Auth (optional): Authorization: Bearer <token> or x-api-key: <key>
	•	Headers: Content-Type: application/json (SSE → text/event-stream)
	•	Error envelope

{ "error": { "code": "bad_request", "message": "Details...", "status": 400 } }

	•	Security: Use HTTPS remote; store API key in Keychain; redact in logs.
	•	CORS: allow GET,POST,DELETE and Authorization,Content-Type.

⸻

Claude Tooling — Calls & Results (Deep Dive)

Tool	Input	Output	UX Notes
fs.read	{ "path": "string", "encoding?": "utf8" }	file contents	Show in Preview pane; copy button.
fs.write	{ "path": "string", "content": "string", "create?": true }	summary	Destructive; confirm on first use.
multi.edit	{ "edits":[{path,range,text}], "dry_run?":false }	"Applied N edit(s)"	Preferred to many writes.
grep.search	`{ "pattern":"regex", "path":"dir	file" }`	multiline hit list
glob	{ "pattern": "src/**/*.ts" }	list of files	Use monospace.
ls	{ "path":"dir" }	file listing	Pair with File View Controller.
bash.run	{ "cmd":"string", "timeout_ms?":30000 }	stdout/err, exit_code	Stream if available; show exit code.
multi.write	{ "files":[{path,content}], "overwrite?":true }	summary	Batch creation.
edit.file	{ "path":"", "instructions": "patch/codex" }	diff text	Present side-by-side diff if long.

Event envelopes (streamed):

{ "object": "tool_use", "id": "tu_...", "name": "grep.search", "input": { "pattern": "TODO", "path":"src" } }

{ "object": "tool_result", "tool_id":"tu_...", "name":"grep.search",
  "is_error": false, "duration_ms": 212, "content": "src/app.ts:42 // TODO ..." }

{ "object": "tool_result", "tool_id":"tu_...", "name":"bash.run",
  "is_error": true, "exit_code": 127, "content": "yarn: command not found" }

Concurrency & ordering
Multiple tools may run in parallel. Group rows by tool_id; order by ts. On result:
	•	mark success/error style,
	•	attach metrics (duration/exit),
	•	offer Retry (prepopulated input JSON).

⸻

Swift Data Models (iOS) + Theme Shim

6.1 Codable Models

public struct ChatContent: Codable, Equatable {
    public let type: String      // "text", "code", etc.
    public let text: String?
}

public struct ChatMessage: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public let role: String      // "user" | "assistant" | "system"
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
    public let mcp: MCPConfig?
}

public struct ChatChoice: Codable { public let index: Int; public let message: ChatMessage; public let finishReason: String? }

public struct Usage: Codable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?
    public let totalCost: Double?
}

public struct ChatCompletion: Codable {
    public let id: String
    public let object: String    // "chat.completion"
    public let created: Int
    public let model: String
    public let choices: [ChatChoice]
    public let usage: Usage?
    public let sessionId: String?
    public let projectId: String?
}

6.2 Streaming Chunk Models

public struct ChatDelta: Codable { public let role: String?; public let content: String? }

public struct ChatChunk: Codable {
    public let id: String?
    public let object: String            // "chat.completion.chunk" | "tool_use" | "tool_result" | "usage"
    public let created: Int?
    public let model: String?
    public let choices: [ChunkChoice]?

    public struct ChunkChoice: Codable {
        public let index: Int
        public let delta: ChatDelta
        public let finishReason: String?
    }

    // tool frames (when object == "tool_use"/"tool_result")
    public let name: String?
    public let input: [String: JSONAny]?
    public let tool_id: String?
    public let is_error: Bool?
    public let content: String?
    public let duration_ms: Int?
    public let exit_code: Int?

    // usage frame (when object == "usage")
    public let input_tokens: Int?
    public let output_tokens: Int?
    public let total_cost: Double?
}

// flexible JSON node for tool input schemas
public enum JSONAny: Codable, Equatable {
    case string(String), number(Double), bool(Bool), object([String: JSONAny]), array([JSONAny]), null
    // ... standard encode/decode implementation ...
}

6.3 MCP Models

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

6.4 SwiftUI Theme Shim (HSL→Color)

import SwiftUI

private func hslToRGB(h: Double, s: Double, l: Double) -> (Double,Double,Double) {
    let C = (1 - abs(2*l - 1)) * s
    let X = C * (1 - abs(((h/60).truncatingRemainder(dividingBy: 2)) - 1))
    let m = l - C/2
    let (r1,g1,b1):(Double,Double,Double)
    switch h {
    case 0..<60:   (r1,g1,b1) = (C,X,0)
    case 60..<120: (r1,g1,b1) = (X,C,0)
    case 120..<180:(r1,g1,b1) = (0,C,X)
    case 180..<240:(r1,g1,b1) = (0,X,C)
    case 240..<300:(r1,g1,b1) = (X,0,C)
    default:       (r1,g1,b1) = (C,0,X)
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
    public static let background = Color(h: 0,   s: 0,  l: 0)
    public static let foreground = Color(h: 0,   s: 0,  l: 73)
    public static let muted      = Color(h: 0,   s: 12, l: 15)
    public static let mutedFg    = Color(h: 0,   s: 12, l: 65)
    public static let card       = Color(h: 0,   s: 0,  l: 0)
    public static let cardFg     = Color(h: 0,   s: 0,  l: 78)
    public static let border     = Color(h: 0,   s: 0,  l: 5)
    public static let input      = Color(h: 0,   s: 0,  l: 8)
    public static let primary    = Color(h: 220, s: 13, l: 86)
    public static let primaryFg  = Color(h: 220, s: 13, l: 26)
    public static let secondary  = Color(h: 220, s: 3,  l: 25)
    public static let secondaryFg= Color(h: 220, s: 3,  l: 85)
    public static let accent     = Color(h: 0,   s: 0,  l: 15)
    public static let accentFg   = Color(h: 0,   s: 0,  l: 75)
    public static let destructive= Color(h: 8,   s: 89, l: 47)
    public static let destructiveFg = Color(h: 0, s: 0, l: 100)
    public static let ring       = Color(h: 220, s: 13, l: 86)
}

Usage
Text("Validate") .padding(.vertical, 10) .frame(maxWidth: .infinity) .background(Theme.primary) .foregroundColor(Theme.primaryFg) .clipShape(RoundedRectangle(cornerRadius: 12))

⸻

Claude Code iOS — All-in-One Spec, Theme, API & Models (Consolidated Part 2/2)

This part includes: all drawn wireframes (WF-01…WF-14), per-screen behaviors, build & bootstrap commands, project structure, Swift packages to use (SSE, SSH, metrics, charts, logging), and concrete monitoring via SSH plans & code sketches.

Models are chosen inside New Session & Chat (no separate Models screen).

⸻

0) Fast Bootstrap — Xcode Project, Workspace, File Tree, and Dependencies

You have two solid generators for a reproducible, reviewable iOS workspace. Pick XcodeGen (YAML → .xcodeproj) or Tuist (Swift DSL). I recommend XcodeGen for its simple YAML + first-class SPM support.

0.1 Install Tooling (macOS)

# Homebrew (if needed)
which brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew update

# Project generators
brew install xcodegen
brew install tuist

# Helpful CLIs
brew install jq yq ripgrep gnu-sed

0.2 Repository Layout (authoritative)

claude-code-ios/
├─ Project.yml                    # XcodeGen project spec (authoritative)
├─ Workspace.xcworkspace/        # Generated by Xcode on first open
├─ Config/
│  ├─ AppConfigDebug.xcconfig
│  ├─ AppConfigRelease.xcconfig
│  └─ Secrets.example.plist
├─ Sources/
│  ├─ App/
│  │  ├─ ClaudeCodeApp.swift
│  │  ├─ Theme/
│  │  │  ├─ Theme.swift           # HSL→Color shim (from Part 1)
│  │  │  └─ Tokens.css            # the HSL CSS token block (for docs/web parity)
│  │  └─ Core/
│  │     ├─ Logging/Logger.swift  # timestamped structured logs
│  │     ├─ Networking/
│  │     │  ├─ APIClient.swift    # REST
│  │     │  ├─ SSEClient.swift    # Event-Source (SSE)
│  │     │  └─ Uploads.swift
│  │     ├─ SSH/
│  │     │  ├─ SSHClient.swift    # NIOSSH client
│  │     │  └─ HostStats.swift    # parsers for cpu/mem/net/disk
│  │     ├─ MCP/
│  │     │  ├─ MCPModels.swift
│  │     │  └─ MCPService.swift
│  │     ├─ Models/               # Codable models (Part 1 §6)
│  │     └─ Utils/
│  │        └─ JSONAny.swift
│  ├─ Features/
│  │  ├─ Settings/
│  │  │  └─ SettingsView.swift
│  │  ├─ Home/
│  │  │  └─ HomeView.swift
│  │  ├─ Projects/
│  │  │  ├─ ProjectsListView.swift
│  │  │  └─ ProjectDetailView.swift
│  │  ├─ Sessions/
│  │  │  ├─ NewSessionView.swift
│  │  │  └─ ChatConsoleView.swift
│  │  ├─ Files/
│  │  │  ├─ FileBrowserView.swift
│  │  │  └─ FilePreviewView.swift
│  │  ├─ Monitoring/
│  │  │  └─ MonitoringView.swift
│  │  ├─ Tracing/
│  │  │  └─ TracingView.swift
│  │  └─ MCP/
│  │     ├─ MCPSettingsView.swift
│  │     └─ SessionToolPickerView.swift
│  └─ Components/                 # Reusable SwiftUI widgets (chips, badges, tiles)
├─ Tests/
│  └─ AppTests.swift
├─ Scripts/
│  ├─ bootstrap.sh                # installs SPM deps via XcodeGen, opens workspace
│  ├─ format.sh                   # swift-format (optional)
│  └─ mock_sse_server.py          # local SSE tester (optional)
└─ README.md

0.3 XcodeGen Project (drop-in Project.yml)

name: ClaudeCode
options:
  minimumXcodeGenVersion: 2.39.1
  deploymentTarget:
    iOS: "17.0"
configs:
  Debug: debug
  Release: release

packages:
  # Core
  swift-log:         { url: "https://github.com/apple/swift-log.git",        from: "1.5.3" }
  swift-metrics:     { url: "https://github.com/apple/swift-metrics.git",    from: "2.5.0" }
  swift-collections: { url: "https://github.com/apple/swift-collections.git",from: "1.0.6" }

  # Networking/SSE (use URLSession + our SSEClient; optional EventSource lib shown here)
  eventsource:       { url: "https://github.com/LaunchDarkly/swift-eventsource.git", from: "3.0.0" }

  # SSH client
  nio:               { url: "https://github.com/apple/swift-nio.git",        from: "2.60.0" }
  nio-ssh:           { url: "https://github.com/apple/swift-nio-ssh.git",    from: "0.5.0" }

  # Charts (first choice: Apple's Swift Charts built-in for iOS16+; add fallback if needed)
  Charts:            { url: "https://github.com/danielgindi/Charts.git",     from: "5.1.0" }

  # Keychain helper (optional)
  KeychainAccess:    { url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2" }

targets:
  ClaudeCode:
    type: application
    platform: iOS
    sources: [Sources]
    resources:
      - path: Sources/App/Theme/Tokens.css
    settings:
      base:
        INFOPLIST_FILE: Sources/App/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.yourorg.claudecode
        SWIFT_VERSION: 5.10
    dependencies:
      - package: swift-log
      - package: swift-metrics
      - package: swift-collections
      - package: nio
      - package: nio-ssh
      - package: eventsource
      - package: KeychainAccess
      - package: Charts

  ClaudeCodeTests:
    type: bundle.unit-test
    platform: iOS
    sources: [Tests]
    dependencies:
      - target: ClaudeCode

Generate & open

xcodegen
open ClaudeCode.xcodeproj

Prefer a workspace with additional utility packages? Add them to Project.yml and regenerate.

0.4 Alternative: Tuist (if you prefer Swift DSL projects)

tuist init --platform ios
tuist edit     # author your Project.swift (mirror the same deps as above)
tuist generate


⸻

1) Third-Party Libraries & Why
	•	EventSource (SSE): We implement SSE with URLSession and/or wrap with LaunchDarkly/swift-eventsource for robust reconnects/heartbeats.
	•	Apple Swift Charts: first choice for Analytics (iOS 16+). Fallback to danielgindi/Charts when needed.
	•	Logging & Metrics: swift-log + swift-metrics — consistent across layers and easy to export later.
	•	Swift Collections: deques/ordered sets for efficient streaming buffers.
	•	KeychainAccess: safe storage for API keys.
	•	SwiftNIO + NIOSSH: SSH client to run remote commands for Monitoring (CPU/MEM/NET/Disk) and Tracing helpers on a host when REST is insufficient or undesired.
	•	(Optional) OpenTelemetry-Swift later for cross-process tracing once the backend exposes an OTLP collector.

We intentionally avoid heavy HTTP frameworks (Alamofire) — URLSession + Codable suffices and is lean.

⸻


⸻

3) SSH Monitoring — Using SwiftNIO + NIOSSH
 SSH Monitoring — Using SwiftNIO + NIOSSH

3.1 Remote command sets (Linux/macOS)

Linux (install sysstat where needed):
	•	CPU: mpstat 1 1 || top -b -n 1 | head -5
	•	MEM: free -m or cat /proc/meminfo
	•	DISK: df -hT and iostat -x 1 1
	•	NET: ss -s && ip -s link
	•	PROC: ps -eo pid,ppid,pcpu,pmem,args --sort=-pcpu | head -15

macOS host:
	•	CPU: top -l 1 -s 0 | head -10
	•	MEM: vm_stat
	•	DISK: df -h and iostat -w 1 -c 2
	•	NET: netstat -ibn
	•	PROC: ps -A -o pid,ppid,pcpu,pmem,comm -r | head -15

3\.3 HostStats aggregator



// Sources/App/SSH/HostStats.swift
struct CPU: Codable { let usage: Double }
struct Memory: Codable { let totalMB: Int; let usedMB: Int; let freeMB: Int }
struct Disk: Codable { let fs: String; let usedPct: Double }
struct Net: Codable { let txMBs: Double; let rxMBs: Double }

struct HostSnapshot: Codable {
    let ts: Date
    let cpu: CPU
    let mem: Memory
    let disks: [Disk]
    let net: Net
    let top: [String]  // top processes lines
}

final class HostStatsService {
    let ssh: SSHClient
    init(ssh: SSHClient) { self.ssh = ssh }

    func snapshotLinux(host: SSHClient.Host) async throws -> HostSnapshot {
        async let cpu = ssh.run("mpstat 1 1", on: host)
        async let mem = ssh.run("free -m", on: host)
        async let disk = ssh.run("df -hT", on: host)
        async let iox = ssh.run("iostat -x 1 1", on: host)
        async let net = ssh.run("ss -s && ip -s link", on: host)
        async let pro = ssh.run("ps -eo pid,ppid,pcpu,pmem,args --sort=-pcpu | head -15", on: host)

        let (cpuS, memS, diskS, _, netS, proS) = try await (cpu, mem, disk, iox, net, pro)
        // TODO: parse into the Codable structs above (simple regex/split)
        return HostSnapshot(ts: .init(),
                            cpu: CPU(usage: 37.0),
                            mem: Memory(totalMB: 32000, usedMB: 12000, freeMB: 20000),
                            disks: [], net: Net(txMBs: 12, rxMBs: 45),
                            top: proS.components(separatedBy: "\n"))
    }
}

UI: MonitoringView polls every 5–10s with a Combine Timer.publish and renders Swift Charts areas/bars using --chart-1 … --chart-5.

⸻

4) Tracing (Client-Side)
	•	Add span breadcrumbs around chat calls, SSE connect/disconnect, tool events, and SSH snapshots using swift-log.
	•	Provide a "Export Trace" button on the Tracing tab to dump NDJSON for later OTLP ingestion.
	•	Future: wire OpenTelemetry-Swift exporter (OTLP/HTTP) when your backend is ready.

⸻

5) Per-Screen Mapping + Commands

Settings (WF-01)
	•	API: GET /health
	•	Save base URL & key in KeychainAccess.
	•	Command: (local dev) run your gateway at :8000, then:

curl -sS http://localhost:8000/health | jq



Home (WF-02)
	•	API: GET /v1/projects, GET /v1/sessions, GET /v1/sessions/stats
	•	Command:

curl -sS http://localhost:8000/v1/sessions/stats | jq



Projects (WF-03)
	•	GET/POST /v1/projects

curl -sS -X POST http://localhost:8000/v1/projects \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alpha","description":"Demo","path":"/usr/local/alpha"}' | jq



Project Detail (WF-04)
	•	GET /v1/projects/{id}, GET /v1/sessions?project_id=

New Session (WF-05)
	•	GET /v1/models, GET /v1/models/capabilities, POST /v1/sessions

Chat Console (WF-06)
	•	SSE: POST /v1/chat/completions ("stream": true)
	•	Status/Stop: GET/DELETE /v1/chat/completions/{id}

File View (WF-12)
	•	Uses gateway file APIs when available, otherwise SSH (read-only via cat, ls, grep).

Monitoring (WF-13)
	•	SSH snapshots, not REST. Commands listed above.

Tracing (WF-14)
	•	Client-only NDJSON; export to disk and share.

⸻

6) Build, Run, and Test

# Generate project from Project.yml
xcodegen

# Build in Debug
xcodebuild -project ClaudeCode.xcodeproj \
  -scheme ClaudeCode -configuration Debug -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run unit tests
xcodebuild -project ClaudeCode.xcodeproj \
  -scheme ClaudeCodeTests -destination 'platform=iOS Simulator,name=iPhone 15' test

Open in Xcode and run on iPhone 15 simulator.
For CLI streaming tests, create a minimal SSE mock:

# Scripts/mock_sse_server.py
from time import sleep
print("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n\r\n")
for line in [
  'data: { "object":"chat.completion.chunk", "choices":[{"index":0,"delta":{"content":"Hello"}}] }\n',
  'data: { "object":"usage", "input_tokens":10, "output_tokens":20, "total_cost":0.0001 }\n',
  'data: [DONE]\n'
]:
  print(line, flush=True); sleep(1)

Serve with a tiny HTTP shim (or just hit your real gateway).

⸻

7) All Drawn Wireframes (ASCII)

Style uses our theme semantics: --background page, --card panels, --border rules, primary/secondary/destructive/accent where noted.

WF-01 Settings

┌──────────────────────────────────────────────────────────────────────────────┐
│ Claude Code                                           Settings         9:41  │
├──────────────────────────────────────────────────────────────────────────────┤
│ Server:                                                                       │
│  Base URL  [ https://api.example.com                      ]                   │
│  API Key   [ ••••••••••••••••••••                         ] (👁)              │
│  Streaming by default  [x]      SSE Buffer [ 64 KiB ▾ ]                       │
│                                                                              │
│ Actions:  [  VALIDATE  ]                            Health: ◇ OK             │
│  Last ping 2s  | Version 1.2.3 | Active sessions 4 | Uptime 231h             │
└──────────────────────────────────────────────────────────────────────────────┘

WF-02 Home / Command Center

┌──────────────────────────────────────────────────────────────────────────────┐
│ Claude Code                                                       (⚙)  9:41  │
├──────────────────────────────────────────────────────────────────────────────┤
│ Quick Actions:   [ Start Session ] [ New Project ] [ Analytics ]             │
│                                                                              │
│ Recent Projects                                                               │
│  ▸ Project Alpha   /usr/local/alpha                          Feb 20, 2024    │
│  ▸ Beta Project    /home/user/beta                           Feb 18, 2024    │
│                                                                              │
│ Active Sessions                                                               │
│  [ Gamma Project ]  id 93RT-1B  model-x  12m   [ Project Delta ] …   5m      │
│                                                                              │
│ KPIs:  [ 10.5K Tokens ] [ 215 Sessions ] [ 8 Projects ] [ $228.50 Cost ]     │
└──────────────────────────────────────────────────────────────────────────────┘

WF-03 Projects

┌──────────────────────────────────────────────────────────────────────────────┐
│ Projects                                             (+ New)          9:41    │
├──────────────────────────────────────────────────────────────────────────────┤
│ [ Search projects… ]   Sort [ Updated ▾ ]  Filter [ All ▾ ]                  │
│ ▸ Alpha Project      /home/alpha      ◇ 12.1K tokens   2 sessions            │
│ ▸ Beta  Project      /home/beta       ◇ 11.9K tokens   1 session             │
│ ▸ Gamma Project      /opt/gamma       ◇ 13.4K tokens   4 sessions            │
└──────────────────────────────────────────────────────────────────────────────┘

WF-04 Project Detail

┌──────────────────────────────────────────────────────────────────────────────┐
│ ← Projects                     Project Alpha                        ✎  ⚙     │
├──────────────────────────────────────────────────────────────────────────────┤
│ Path /usr/local/project-alpha     Status ◇ Active     Model model-x          │
│ Created Feb 16, 2024                                                         │
│ Actions: [ New Session ] [ Debug ] [ Metrics ] [ Stop ] [ Delete ✖ ]         │
│ Endpoints: POST /projects/alpha/functions/execute  |  GET /projects/alpha/config
│ Environment: API_KEY ••••••••••   DEBUG_MODE true                             │
│ Sessions: ▸ sess 12 (93RT-1B) model-x tokens 2,043 (Feb 22)                   │
└──────────────────────────────────────────────────────────────────────────────┘

WF-05 New Session

┌──────────────────────────────────────────────────────────────────────────────┐
│ ← Project Alpha                                    New Session               │
├──────────────────────────────────────────────────────────────────────────────┤
│ Model [ claude-3-5-haiku ▾ ]    Title [ Exploration ]                        │
│ System Prompt [ You are a helpful coding assistant…                      ]   │
│ MCP Enabled [x]    [ Configure Tools… ]                                      │
│ [ START SESSION ]                                  [ Cancel ]                 │
└──────────────────────────────────────────────────────────────────────────────┘

WF-06 Chat Console + Hyperthink

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ ← Alpha / sess 93RT-1B       Model: claude-3.5-haiku        Stream ●    [ Stop ]       9:41  │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Transcript                                      │ Tools Timeline                              │
│ ─────────────────────────────────────────────── │ ─────────────────────────────────────────── │
│ User "Find TODOs in src/ and fix."             │ 09:41 grep.search •••  input {pattern:"…"}  │
│ Claude "Scanning files…" ⌶                     │ 09:41 grep.search ✓ 212ms (2 hits)          │
│ Claude "Applied edit to app.ts"                │ 09:42 multi.edit  ✓ 95ms "Applied 1 edit"   │
│                                                │ 09:43 bash.run ✖ 18ms "yarn not found" ↺    │
│ Compose [ Type prompt… ] [ Send ] (Stream ☐)   │ Telemetry: tokens 1.8K • cost $0.017 • t=12s│
├───────────────────────────────────────┬───────────────────────────────────────────────────────┤
│ Hyperthink (planner)                  │ Tool Inspector (selected row)                         │
│ Steps: 200 planned (24 done)          │ Tool: grep.search  input JSON  |  output (monospace)  │
│ Queue: read→grep→multi.edit→bash      │ duration: 212ms   [ Copy Output ] [ Re-run ↺ ]        │
└───────────────────────────────────────┴───────────────────────────────────────────────────────┘

WF-08 Analytics

┌──────────────────────────────────────────────────────────────────────────────┐
│ Analytics                                                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│ Summary: Active 4 | Tokens 43,000 | Cost $0.58 | Sessions 215                │
│ [ Area: Tokens over time ]   [ Bars: Cost by model ]  [ Tools: invocations ] │
└──────────────────────────────────────────────────────────────────────────────┘

WF-09 Diagnostics

┌──────────────────────────────────────────────────────────────────────────────┐
│ Diagnostics                                                                   │
├──────────────────────────────────────────────────────────────────────────────┤
│ Log:                                                                          │
│ 12:02:33 POST /v1/chat 200 (56ms)                                             │
│ 12:02:34 SSE line chat.completion.chunk                                        │
│ 12:02:35 tool_result bash.run ERROR exit 127                                   │
│ [ Run Debug Request ]                                                          │
└──────────────────────────────────────────────────────────────────────────────┘

WF-10 MCP Settings

┌──────────────────────────────────────────────────────────────────────────────┐
│ MCP Settings                                                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│ Scope [ All ▾ ]   Project [ Alpha ▾ ]                                        │
│ Servers: [✓] fs-local  v1.3.0 available  |  [ ] bash  v0.9.2 available       │
│ Tools(fs-local): [✓] fs.read [≡]  [✓] fs.write [≡]  [ ] fs.search [≡]        │
│ Priority: 1) fs.read  2) fs.write    Audit Log [x]  [ Save as Default ]       │
└──────────────────────────────────────────────────────────────────────────────┘

WF-11 Session Tool Picker

┌──────────────────────────────────────────────────────────────────────────────┐
│ Tools for This Session                                                        │
├──────────────────────────────────────────────────────────────────────────────┤
│ Defaults: ( ● User  ○ Project  ○ None )                                      │
│ Enabled Servers: [✓] fs-local   [✓] bash   [ ] web-scraper                   │
│ Enabled Tools:   [ fs.read ] [ fs.write ] [ bash.run ] [ grep.search ]       │
│ Priority:        1) fs.read   2) bash.run   3) fs.write (drag [≡])           │
│ [ Cancel ]                                                     [ Save ]       │
└──────────────────────────────────────────────────────────────────────────────┘

WF-12 File View Controller

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ ← Project Alpha                                   Files                                      │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Tree                                        │ Preview                                         │
│ ▸ src/                                      │ // app.ts                                       │
│   ▸ components/                             │ export function App() { return <UI/> }          │
│   • app.ts                                  │ [ Open in Editor ] [ Copy ] [ Run grep… ]       │
│   • db.ts                                   │                                                  │
│ ▸ tests/  • README.md                       │                                                  │
│ Toolbar: [ New File ] [ New Folder ] [ Upload ] [ Refresh ] [ Search ⌕ ]                      │
└──────────────────────────────────────────────────────────────────────────────────────────────┘

WF-13 Monitoring (over SSH)

┌──────────────────────────────────────────────────────────────────────────────┐
│ Monitoring (Host)                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ CPU 43% [███████……]   Top: node(22%) grep(8%)                                  │
│ MEM 12.3/32 GB [█████………………]                                                 │
│ NET ↑12 MB/s ↓45 MB/s  Errors 0                                                │
│ DISK 210/1024 GB  Inodes 72%                                                   │
│ Processes (Top 10)                                                             │
│ PID   NAME   CPU  MEM   CMD                                                    │
│ 2314  node   22%  1.3G  /usr/bin/node server.js                                │
│ ...                                                                            │
│ [ Snapshot ] [ Export CSV ] [ Auto-refresh ⟳ 5s ▾ ]                            │
└──────────────────────────────────────────────────────────────────────────────┘

WF-14 Tracing (Requests & API Calls)

┌──────────────────────────────────────────────────────────────────────────────┐
│ Tracing                                                                        │
├──────────────────────────────────────────────────────────────────────────────┤
│ 12:02:35 DELETE /v1/chat/completions/sess_abc 200 18ms                         │
│ 12:02:34 tool_result bash.run ERROR 127                                         │
│ 12:02:34 tool_use   bash.run "yarn add …"                                       │
│ 12:02:33 POST /v1/chat/completions stream=on 200 56ms                           │
│ Span Detail: id 6fd1.. parent 1b4a.. dur 18ms | logs stderr:"yarn not found"    │
│ [ Service ▾ ] [ Level ▾ ] [ Tool ▾ ]                       [ Export NDJSON ]    │
└──────────────────────────────────────────────────────────────────────────────┘


⸻

8) QA & Dev Commands (Handy)

# Lint/format (if you adopt swift-format)
brew install swift-format
swift-format format --in-place --recursive Sources Tests

# Quick simulator boot & run
xcrun simctl boot "iPhone 15" || true
open -a Simulator
xcodebuild -project ClaudeCode.xcodeproj -scheme ClaudeCode \
  -destination 'platform=iOS Simulator,name=iPhone 15' build

# Environment test (gateway)
curl -sS http://localhost:8000/health | jq

# SSE smoke via real gateway (adjust model/project)
cat > /tmp/chat.json <<'JSON'
{ "model":"claude-3-5-haiku-20241022","project_id":"project-123",
  "messages":[{"role":"user","content":"Say hello"}],"stream":true }
JSON
curl -N -sS http://localhost:8000/v1/chat/completions \
  -H 'Content-Type: application/json' -d @/tmp/chat.json


⸻

9) Final Notes
	•	Theme: use tokens only (--primary, --accent, etc.) to stay faithful to your palette.
	•	Streaming: prefer URLSession + delegate for SSE; add swift-eventsource for robust reconnection/backoff.
	•	Monitoring: use NIOSSH to avoid exposing extra REST endpoints; parse common tools' output; chart locally.
	•	Tracing: begin with swift-log lines → export NDJSON; wire OTLP later.
	•	Scaffolding: XcodeGen keeps your project diff-able and CI-friendly.
	
	
Here's a thorough, single-stop spec + design package that answers everything you asked:
	•	A clear navigation model (bottom tab bar, not a left drawer) and screen-to-screen flow.
	•	Deep, per-view requirements (inputs, state, actions, error states, empty/loading/success "primitive" designs).
	•	Exact Swift data models and how they're used across views.
	•	The SSE vs non-SSE contract and how UI state changes across both.
	•	A full tooling stack to generate the Xcode project, structure the workspace, and support streaming + SSH monitoring.
	•	Drawn wireframes & designs for every screen (see images just above: Navigation/IA + all screens you asked for).
If you want the same drawings exported as a ZIP, say the word and I'll package them.

Below is the complete, consolidated Markdown. If you'd like this as a single downloadable SPEC.md with the Project.yml, Theme.swift, SSEClient.swift, SSHClient.swift, and HostStats.swift included, I can ship a ZIP instantly.

⸻

Claude Code iOS — Complete Product & Design Spec (Navigation, Views, Data, SSE, Tooling)

1) Navigation & IA

1.1 Primary navigation (decision)
	•	Bottom Tab Bar with 4 tabs: Home, Projects, Sessions, Monitor.
	•	Overflow & one-off areas enter via secondary pushes/sheets:
	•	Settings from Home gear icon.
	•	New Session from Projects/Project Detail.
	•	MCP Settings from New Session or Chat → Session menu.
	•	Tracing & Diagnostics from Monitor's toolbar or Home's overflow.

Why a tab bar (not drawer)?
	•	You constantly bounce between Projects, Sessions, Monitor, and Home; the tab bar shortens Fitts' law distance and keeps global areas one tap away.
	•	The left drawer would bury Sessions/Monitor too deep; your IA benefits from persistent availability.

1.2 Screen flow (condensed)
	•	Settings → Home →
	•	Projects → Project Detail → New Session → Chat
	•	Sessions → Chat
	•	Monitor → Tracing
	•	Home → Diagnostics or MCP Settings (via entry points)

See the Navigation / IA images that I just generated: two variants (node flow + device cluster) showing this exact flow.

⸻

2) Per-View Requirements (primitive states, actions, errors, theme usage)

Theme tokens used everywhere: --background, --card, --border, --foreground, --muted-foreground, --primary, --secondary, --accent, --destructive, --ring.

2.1 Settings (WF-01)
	•	Inputs: Base URL, API Key, Streaming default, SSE buffer size.
	•	Actions: Validate (pings /health), Save.
	•	State:
	•	Empty: placeholders show hints, Validate disabled.
	•	Loading: Validate shows spinner ring (--ring), button disabled.
	•	Success: Health pill ◇ OK (--accent), server info filled.
	•	Error: Health pill red (--destructive), troubleshooting tips appear.
	•	Persistence: Base URL & Streaming in UserDefaults; API key in KeychainAccess.

2.2 Home (WF-02)
	•	Sections: Quick Actions, Recent Projects, Latest Sessions, KPIs.
	•	Empty: cards show "no projects/sessions yet" CTAs.
	•	Tapthrough: cards push to Projects / Sessions detail.
	•	Long-press: project quick menu (start session, open folder in Files tab, copy path).

2.3 Projects List (WF-03)
	•	Controls: Search, Sort, Filter.
	•	Rows: name, path, updated date, token count, session count pill.
	•	Empty: "Create your first project" CTA.

2.4 Project Detail (WF-04)
	•	Header: path, status, model.
	•	Actions: New Session, Debug, Metrics, Stop (secondary), Delete (destructive).
	•	Panels: Endpoints, Environment (secure values), Sessions list.
	•	Error: failed fetch shows Retry + Diagnostics link.

2.5 New Session (WF-05)
	•	Fields: Model (drop-down), Title, System prompt; MCP Enabled toggle & Configure Tools (WF-11).
	•	Start: POST /v1/sessions. If you choose to start directly in Chat, you can create the session implicitly with the first chat request (with stream true/false).
	•	Validation: model required; prompt optional; MCP config optional.

2.6 Chat Console + Hyperthink (WF-06)
	•	Transcript: role bubbles with timestamp; markdown & code styles.
	•	Tool Timeline: grouped by tool_id; running rows outlined with --ring; successes --accent; errors --destructive.
	•	Composer: multiline; Stream toggle (defaults from Settings); Model switcher.
	•	Controls: Send, Stop, "Status" refresh.
	•	Hyperthink: planner area with step queue, progress %, and scratchpad; you can Start, Pause, Reset; steps enqueue recommended tool plans.
	•	Tool Inspector: shows raw tool_use input and tool_result output; Copy, Re-run with edited JSON.
	•	Non-SSE mode differences:
	•	SSE: incremental deltas append to last assistant bubble; timeline updates live; status panel finalizes tokens/cost on [DONE].
	•	Non-SSE: a spinner shows while waiting; single final assistant bubble appears; Tool Timeline fills only after response; status fetch occurs immediately after first render.

2.7 Analytics (WF-08)
	•	Charts: Tokens (area --chart-1), Cost by model (bars --chart-2..5), Tool calls (bars).
	•	Time range: day/week/month; CSV export.

2.8 Diagnostics (WF-09)
	•	Live log: request summaries, SSE lines/second, errors; filter by level/scope.
	•	Test payload: calls /v1/chat/completions/debug.

2.9 MCP Settings (WF-10)
	•	Scope: All / User / Project.
	•	Servers: enable/disable, status; "Install…" for missing.
	•	Tools: enable per server; re-order Priority by drag (affects selection order).
	•	Audit Log: on/off; saved as default for User or Project.

2.10 Session Tool Picker (WF-11)
	•	Defaults: choose base (User, Project, None), then override per session.
	•	Save & Apply: persists via POST /v1/sessions/{id}/tools or inline mcp{...} on the first chat call.

2.11 File View Controller (WF-12)
	•	Tree: directory view with disclosure; Preview panel displays text files; actions: Open in Editor, Copy, Run grep.
	•	Data source: file API if present; or SSH commands for read-only listing and file reads.

2.12 Monitoring (WF-13) — over SSH
	•	Widgets: CPU, Memory, Network (↑/↓), Disk, Top Processes; auto-refresh (5–10s).
	•	SSH commands mapped by OS; parsing rules produce HostSnapshot for charting.
	•	Export: Snapshot to CSV/JSON.

2.13 Tracing (WF-14)
	•	Timeline: chat POST, tool_use/result, status, stop; durations and exit codes.
	•	Span detail: logs (stderr lines), attributes (session_id/model).
	•	Export: NDJSON.

⸻

3) App-wide State, Swift Models, and Usage

3.1 Core store (simplified concerns)
	•	AppConfig: baseURL, apiKey (Keychain), streaming default, SSE buffer KiB.
	•	ProjectStore: [Project]; selected project; cached Project Detail; fetch & create actions.
	•	SessionStore: [Session]; active session id; create/list/end/status actions.
	•	ChatStore (per session):
	•	messages: [ChatMessage]
	•	timeline: [ToolEventRow]  // normalized from stream frames
	•	isStreaming: Bool, streamTask: SSEClient?
	•	usage: Usage?, stats: ChatStatus?
	•	mcpConfig: MCPConfig?
	•	hyperthink: PlannerState  // steps, queue, running

3.2 Exact Swift models

Use the full model set from Part 1 §6 (Codable: ChatMessage, ChatRequest, ChatCompletion, ChatChunk, ModelObject, Project, Session, MCP*, etc.).

	•	Across screens:
	•	Projects List uses [Project].
	•	Project Detail uses Project, list of Session.
	•	New Session uses ModelCapability to populate pickers.
	•	Chat uses ChatRequest/ChatCompletion (non-SSE) and ChatChunk (SSE).
	•	MCP uses MCPServer, MCPTool, and MCPConfig.
	•	Monitoring uses HostSnapshot.
	•	Tracing reads a ring buffer of structured log entries.

3.3 SSE vs Non-SSE behaviors (UI & VM)

Concern	SSE (stream=true)	Non-SSE
Transport	URLSession delegate parsing line breaks; data: framing	single URLSession.dataTask
Transcript	appends deltas to last assistant bubble; cursor shimmer	waits; renders final bubble
Tools	tool_use/result rows appear live	whole Tool Timeline fills at end
Usage	stream may emit usage; fetch /status at end for certainty	usage in response; still GET /status to sync
Stop	DELETE /v1/chat/completions/{id} interrupts	cancel URLSessionTask (local)
Errors	disconnected → backoff & reconnect; visual heartbeat	single alert with Retry


⸻

4) Build & Tooling (end-to-end)
	•	Project generation: XcodeGen (Project.yml from earlier) for reproducible .xcodeproj.
	•	Dependency mgmt: SPM only; no CocoaPods.
	•	Streaming: native URLSession SSE client (provided) plus optional LaunchDarkly/swift-eventsource if you want automatic backoff & jitter.
	•	SSH: SwiftNIO + NIOSSH (async handlers).
	•	Charts: Swift Charts (prefer) or danielgindi/Charts fallback.
	•	Logging/Metrics: swift-log, swift-metrics.
	•	Keychain: KeychainAccess.
	•	Formatting: swift-format (optional).
	•	CI (optional): xcodebuild + xcbeautify or xcpretty.

Bootstrap commands

# Install tools
brew install xcodegen swift-format

# Generate project & open
xcodegen
open ClaudeCode.xcodeproj

# Build & run tests (simulator)
xcodebuild -project ClaudeCode.xcodeproj \
  -scheme ClaudeCode -destination 'platform=iOS Simulator,name=iPhone 15' build
xcodebuild -project ClaudeCode.xcodeproj \
  -scheme ClaudeCodeTests -destination 'platform=iOS Simulator,name=iPhone 15' test


⸻

5) Designs — Primitive States (Theme-faithful)

You asked for primitive (empty/loading/error/success) states. The wireframes I generated reflect:
	•	Empty: placeholders, muted (--muted-foreground), CTAs highlighted (--primary).
	•	Loading: spinners with --ring outline and disabled buttons.
	•	Error: bars/rows --destructive with explicit action ("Retry / Copy cURL").
	•	Success: subtle accent chips for status.

Each image shows the bottom Tab Bar (Home, Projects, Sessions, Monitor) to settle navigation.

⸻

6) What remains to hook up
	•	Paste your gateway base URL and API key in Settings, hit Validate.
	•	Confirm SSE works (you'll see live timeline updates).
	•	Add SSH host creds in Monitor (user/password for first cut; public-key auth next).
	•	If you want a packaged deliverable: I can produce a ZIP that includes:
	•	SPEC.md (this doc),
	•	Project.yml (ready to xcodegen),
	•	Theme.swift, SSEClient.swift, SSHClient.swift, HostStats.swift,
	•	a Scripts/ folder (bootstrap + mock SSE),
	•	and all WF PNGs.

⸻

Quick reminders
	•	No separate models screen — choose models in New Session or Chat.
	•	MCP: configure defaults in MCP Settings; per-session overrides in Session Tool Picker.
	•	Monitoring: goes over SSH, not REST, for CPU/MEM/NET/Disk and top procs.
	•	Tracing: aggregates client spans and tool events; export NDJSON.

If you want the downloadable ZIP with code scaffolds and this full spec already embedded, tell me "ZIP it," and I'll ship it immediately.

⸻

Project.yml (XcodeGen)

name: ClaudeCode
options:
  minimumXcodeGenVersion: 2.39.1
  deploymentTarget:
    iOS: "17.0"
configs:
  Debug: debug
  Release: release

packages:
  swift-log:         { url: "https://github.com/apple/swift-log.git",        from: "1.5.3" }
  swift-metrics:     { url: "https://github.com/apple/swift-metrics.git",    from: "2.5.0" }
  swift-collections: { url: "https://github.com/apple/swift-collections.git",from: "1.0.6" }
  eventsource:       { url: "https://github.com/LaunchDarkly/swift-eventsource.git", from: "3.0.0" }
  KeychainAccess:    { url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2" }
  Charts:            { url: "https://github.com/danielgindi/Charts.git",     from: "5.1.0" }
  Shout:             { url: "https://github.com/jakeheis/Shout.git",         from: "0.6.5" }

targets:
  ClaudeCode:
    type: application
    platform: iOS
    sources: [Sources]
    resources:
      - path: Sources/App/Theme/Tokens.css
    settings:
      base:
        INFOPLIST_FILE: Sources/App/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.yourorg.claudecode
        SWIFT_VERSION: 5.10
    dependencies:
      - package: swift-log
      - package: swift-metrics
      - package: swift-collections
      - package: eventsource
      - package: KeychainAccess
      - package: Charts
      - package: Shout

  ClaudeCodeTests:
    type: bundle.unit-test
    platform: iOS
    sources: [Tests]
    dependencies:
      - target: ClaudeCode


⸻

Sources/App/Info.plist

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>ClaudeCode</string>
  <key>CFBundleIdentifier</key><string>com.yourorg.claudecode</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSRequiresIPhoneOS</key><true/>
  <key>UIApplicationSceneManifest</key>
  <dict>
    <key>UIApplicationSupportsMultipleScenes</key><false/>
  </dict>
</dict>
</plist>


⸻

Sources/App/Theme/Theme.swift (HSL palette → SwiftUI Color)

import SwiftUI

private func hslToRGB(h: Double, s: Double, l: Double) -> (Double, Double, Double) {
    let C = (1 - abs(2*l - 1)) * s
    let X = C * (1 - abs(((h/60).truncatingRemainder(dividingBy: 2)) - 1))
    let m = l - C/2
    let (r1,g1,b1):(Double,Double,Double)
    switch h {
    case 0..<60:   (r1,g1,b1) = (C,X,0)
    case 60..<120: (r1,g1,b1) = (X,C,0)
    case 120..<180:(r1,g1,b1) = (0,C,X)
    case 180..<240:(r1,g1,b1) = (0,X,C)
    case 240..<300:(r1,g1,b1) = (X,0,C)
    default:       (r1,g1,b1) = (C,0,X)
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
    public static let background = Color(h: 0,   s: 0,  l: 0)
    public static let foreground = Color(h: 0,   s: 0,  l: 73)
    public static let muted      = Color(h: 0,   s: 12, l: 15)
    public static let mutedFg    = Color(h: 0,   s: 12, l: 65)
    public static let card       = Color(h: 0,   s: 0,  l: 0)
    public static let cardFg     = Color(h: 0,   s: 0,  l: 78)
    public static let border     = Color(h: 0,   s: 0,  l: 5)
    public static let input      = Color(h: 0,   s: 0,  l: 8)
    public static let primary    = Color(h: 220, s: 13, l: 86)
    public static let primaryFg  = Color(h: 220, s: 13, l: 26)
    public static let secondary  = Color(h: 220, s: 3,  l: 25)
    public static let secondaryFg= Color(h: 220, s: 3,  l: 85)
    public static let accent     = Color(h: 0,   s: 0,  l: 15)
    public static let accentFg   = Color(h: 0,   s: 0,  l: 75)
    public static let destructive= Color(h: 8,   s: 89, l: 47)
    public static let destructiveFg = Color(h: 0, s: 0, l: 100)
    public static let ring       = Color(h: 220, s: 13, l: 86)
}


⸻

Sources/App/ClaudeCodeApp.swift (Tab Bar + stubs)

import SwiftUI

@main
struct ClaudeCodeApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            ProjectsListView()
                .tabItem { Label("Projects", systemImage: "folder") }

            SessionsView()
                .tabItem { Label("Sessions", systemImage: "bubble.left.and.bubble.right") }

            MonitoringView()
                .tabItem { Label("Monitor", systemImage: "gauge") }
        }
        .tint(Theme.primary)
        .background(Theme.background)
    }
}


⸻


	•	Sources/App/Networking/SSEClient.swift
	•	Sources/App/SSH/SSHClient.swift (Shout)
	•	Sources/App/SSH/HostStats.swift

Then Part 3/4 will have the SwiftUI feature views + Tokens.css.
Part 4/4 will include Scripts/bootstrap.sh, Scripts/mock_sse_server.py, and SPEC.md.


Part 2/4 — Networking + SSH Monitoring core

⸻

Sources/App/Networking/SSEClient.swift

import Foundation
import os.log

/// Lightweight Server-Sent Events (SSE) client using URLSession delegate streaming.
/// Emits raw JSON payloads from lines prefixed with `data: ` and terminates on `[DONE]`.
public final class SSEClient: NSObject, URLSessionDataDelegate {
    public struct Event { public let raw: String }

    public var onEvent: ((Event) -> Void)?
    public var onDone: (() -> Void)?
    public var onError: ((Error) -> Void)?

    private var buffer = Data()
    private var task: URLSessionDataTask?
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()
    private let log = Logger(subsystem: "com.yourorg.claudecode", category: "SSE")

    /// Begin a streaming POST to an SSE endpoint (e.g., /v1/chat/completions with stream=true).
    public func connect(url: URL, body: Data, headers: [String: String] = [:]) {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { k, v in req.setValue(v, forHTTPHeaderField: k) }

        log.info("SSE connect %{public}@", url.absoluteString)
        task = session.dataTask(with: req)
        task?.resume()
    }

    /// Stop the current stream (client-side cancel).
    public func stop() {
        log.info("SSE stop")
        task?.cancel()
        task = nil
    }

    // MARK: - URLSessionDataDelegate

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        let newline = Data("\n".utf8)

        while let r = buffer.range(of: newline) {
            let line = buffer.subdata(in: buffer.startIndex..<r.lowerBound)
            buffer.removeSubrange(buffer.startIndex...r.lowerBound)
            guard !line.isEmpty, let s = String(data: line, encoding: .utf8) else { continue }

            // Expect lines like:  "data: {...json...}"
            if s.hasPrefix("data: ") {
                let payload = String(s.dropFirst(6))
                if payload == "[DONE]" {
                    log.debug("SSE received [DONE]")
                    onDone?()
                    return
                }
                onEvent?(Event(raw: payload))
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            log.error("SSE error: %{public}@", error.localizedDescription)
            onError?(error)
        }
    }
}


⸻

Sources/App/SSH/SSHClient.swift

import Foundation
import Shout   // SPM: jakeheis/Shout (libssh2-based)

public struct SSHHost {
    public let hostname: String
    public let port: Int
    public let username: String
    public let password: String
    public init(hostname: String, port: Int = 22, username: String, password: String) {
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
    }
}

/// Thin wrapper over Shout to execute commands and capture exit status + output.
public final class SSHClient {
    public init() {}

    /// Execute a single command on the remote host.
    /// - Returns: (exitStatus, stdout) — stderr is typically merged by the remote shell
    public func run(_ cmd: String, on host: SSHHost) throws -> (status: Int32, output: String) {
        let ssh = try SSH(host: host.hostname, port: host.port)
        try ssh.authenticate(username: host.username, password: host.password)
        // Shout returns (status, output). If you need strict stderr, split using "2>&1" in cmd.
        return try ssh.execute(cmd)
    }

    /// Execute a command with `2>&1` to capture stderr into output.
    public func runCaptureAll(_ cmd: String, on host: SSHHost) throws -> (status: Int32, output: String) {
        try run(cmd + " 2>&1", on: host)
    }
}


⸻

Sources/App/SSH/HostStats.swift

import Foundation

public struct CPU: Codable { public let usagePercent: Double }
public struct Memory: Codable { public let totalMB: Int; public let usedMB: Int; public let freeMB: Int }
public struct Disk: Codable { public let fs: String; public let usedPercent: Double; public let size: String; public let used: String; public let avail: String; public let mount: String }
public struct Net: Codable { public let txMBs: Double; public let rxMBs: Double }

public struct HostSnapshot: Codable {
    public let ts: Date
    public let cpu: CPU
    public let mem: Memory
    public let disks: [Disk]
    public let net: Net
    public let top: [String]  // raw top processes lines
}

/// Naive text parsers for common CLI outputs (Linux/macOS).
/// These are conservative and won't crash on unexpected formats.
public final class HostStatsParser {
    public init() {}

    // MARK: - CPU

    /// Parse `mpstat 1 1` (Linux). Fallback: parse "Cpu(s): xx%us, ..." from `top -b -n 1 | head -5`.
    public func parseCPU(_ text: String) -> CPU {
        // Try to find an "all" line like: "all  1.00 0.00 98.00 ..."
        if let line = text
            .components(separatedBy: .newlines)
            .first(where: { $0.lowercased().contains("all") && $0.contains(".") }) {

            // A crude approach: pick last number as idle% (often last column), cpu% = 100 - idle
            let nums = line
                .split { !$0.isNumber && $0 != "." }
                .compactMap { Double($0) }
            if let idle = nums.last, idle >= 0, idle <= 100 {
                return CPU(usagePercent: max(0, min(100, 100 - idle)))
            }
        }

        // Fallback: try to parse "Cpu(s):  7.3%us,  1.0%sy, ..."
        if let cpuLine = text.components(separatedBy: .newlines).first(where: { $0.lowercased().contains("cpu(s)") }) {
            // Find "xx.x%id" (idle) or sum of us+sy+ni+... percentages.
            if let idleMatch = cpuLine.components(separatedBy: .whitespaces).first(where: { $0.hasSuffix("%id") || $0.hasSuffix("%idle") }) {
                let digits = idleMatch.filter { ("0"..."9").contains($0) || $0 == "." }
                if let idle = Double(digits) {
                    return CPU(usagePercent: max(0, min(100, 100 - idle)))
                }
            }
        }

        return CPU(usagePercent: 0.0)
    }

    // MARK: - Memory

    /// Parse `free -m` (Linux) or `vm_stat` (macOS) into MB figures.
    public func parseMemory(linuxFreeM: String?, macVmStat: String?) -> Memory {
        if let linux = linuxFreeM {
            // Expect a line like: "Mem:  32000  12000  20000  ..."
            if let line = linux.components(separatedBy: .newlines).first(where: { $0.lowercased().starts(with: "mem:") }) {
                let nums = line.split { !$0.isNumber }.compactMap { Int($0) }
                if nums.count >= 3 {
                    return Memory(totalMB: nums[0], usedMB: nums[1], freeMB: nums[2])
                }
            }
        }

        if let mac = macVmStat {
            // vm_stat output example: "Pages free: 12345.\nPages active: 12345.\n..."
            // Each page is typically 4096 bytes
            let pageSize = 4096.0
            var total = 0.0, free = 0.0, active = 0.0, inactive = 0.0, wired = 0.0
            for line in mac.components(separatedBy: .newlines) {
                let digits = line.split { !$0.isNumber }.compactMap { Double($0) }.first ?? 0
                if line.lowercased().contains("pages free") { free = digits }
                if line.lowercased().contains("pages active") { active = digits }
                if line.lowercased().contains("pages inactive") { inactive = digits }
                if line.lowercased().contains("pages wired down") || line.lowercased().contains("pages wired") { wired = digits }
            }
            total = free + active + inactive + wired
            let totalMB = Int((total * pageSize) / 1024.0 / 1024.0)
            let freeMB  = Int((free  * pageSize) / 1024.0 / 1024.0)
            let usedMB  = max(0, totalMB - freeMB)
            return Memory(totalMB: totalMB, usedMB: usedMB, freeMB: freeMB)
        }

        return Memory(totalMB: 0, usedMB: 0, freeMB: 0)
    }

    // MARK: - Disk

    /// Parse `df -hT` (Linux) or `df -h` (macOS).
    public func parseDisks(_ text: String) -> [Disk] {
        var results: [Disk] = []
        let lines = text.components(separatedBy: .newlines)
        guard lines.count > 1 else { return results }

        // Skip header
        for line in lines.dropFirst() {
            let cols = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard cols.count >= 6 else { continue }
            // Linux (df -hT): Filesystem, Type, Size, Used, Avail, Use%, Mounted on
            // macOS (df -h):   Filesystem, Size, Used, Avail, Capacity, iused, ifree, %iused, Mounted on (varies)
            if cols[0].hasPrefix("map") || cols[0].hasPrefix("devfs") { continue }
            let fs = cols[0]
            let size = cols[2] // Linux assumption; macOS may be cols[1]
            let used = cols[3]
            let avail = cols[4]
            let usedPctStr = cols[5].trimmingCharacters(in: CharacterSet(charactersIn: "%"))
            let usedPct = Double(usedPctStr) ?? 0
            let mount = cols.last ?? "/"
            results.append(Disk(fs: fs, usedPercent: usedPct, size: size, used: used, avail: avail, mount: mount))
        }
        return results
    }

    // MARK: - Network

    /// Parse a simple "TX MB/s / RX MB/s" from sampled byte counters (caller should compute deltas).
    /// For quick display we accept precomputed numbers; this keeper just packages them.
    public func net(txMBs: Double, rxMBs: Double) -> Net { Net(txMBs: txMBs, rxMBs: rxMBs) }
}

/// Convenience snapshotter orchestrating SSH calls and parsing into a HostSnapshot.
/// You may choose the Linux or macOS path depending on the remote host.
public final class HostStatsService {
    private let ssh: SSHClient
    private let parser = HostStatsParser()

    public init(ssh: SSHClient) { self.ssh = ssh }

    // Linux snapshot: mpstat/free/df, and top processes
    public func snapshotLinux(host: SSHHost) throws -> HostSnapshot {
        let cpuOut  = try ssh.runCaptureAll("mpstat 1 1 || top -b -n 1 | head -5", on: host).output
        let memOut  = try ssh.runCaptureAll("free -m", on: host).output
        let diskOut = try ssh.runCaptureAll("df -hT", on: host).output
        let topOut  = try ssh.runCaptureAll("ps -eo pid,ppid,pcpu,pmem,args --sort=-pcpu | head -15", on: host).output

        let cpu = parser.parseCPU(cpuOut)
        let mem = parser.parseMemory(linuxFreeM: memOut, macVmStat: nil)
        let disks = parser.parseDisks(diskOut)
        let net = parser.net(txMBs: 0, rxMBs: 0) // If you want live MB/s, poll `/proc/net/dev` twice and diff.
        let top = topOut.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return HostSnapshot(ts: Date(), cpu: cpu, mem: mem, disks: disks, net: net, top: top)
    }

    // macOS snapshot: top/vm_stat/df
    public func snapshotMac(host: SSHHost) throws -> HostSnapshot {
        let cpuOut  = try ssh.runCaptureAll("top -l 1 -s 0 | head -10", on: host).output
        let memOut  = try ssh.runCaptureAll("vm_stat", on: host).output
        let diskOut = try ssh.runCaptureAll("df -h", on: host).output
        let topOut  = try ssh.runCaptureAll("ps -A -o pid,ppid,pcpu,pmem,comm -r | head -15", on: host).output

        let cpu = parser.parseCPU(cpuOut)
        let mem = parser.parseMemory(linuxFreeM: nil, macVmStat: memOut)
        let disks = parser.parseDisks(diskOut)
        let net = parser.net(txMBs: 0, rxMBs: 0) // For macOS, sample `netstat -ibn` twice and diff.
        let top = topOut.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return HostSnapshot(ts: Date(), cpu: cpu, mem: mem, disks: disks, net: net, top: top)
    }
}


⸻



Part 3/4 — Feature views (A) + App settings + API client + Tokens.css


⸻

Sources/App/Core/AppSettings.swift

import SwiftUI
import Combine

/// Centralized app settings (URL, defaults). API key is persisted via KeychainService.
@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("baseURL") public var baseURL: String = "http://localhost:8000"
    @AppStorage("streamingDefault") public var streamingDefault: Bool = true
    @AppStorage("sseBufferKiB") public var sseBufferKiB: Int = 64

    @Published public var apiKeyPlaintext: String = ""  // only bound in SettingsView (not persisted)
    private let keychain = KeychainService(service: "com.yourorg.claudecode", account: "apiKey")

    init() {
        // Preload API key from Keychain (do not mirror to @AppStorage).
        if let stored = try? keychain.get() { self.apiKeyPlaintext = stored }
    }

    public func saveAPIKey() throws {
        try keychain.set(apiKeyPlaintext)
    }

    public var baseURLValidated: URL? { URL(string: baseURL) }
}


⸻

Sources/App/Core/KeychainService.swift

import Foundation
import KeychainAccess

/// Tiny wrapper around KeychainAccess for a single string secret.
struct KeychainService {
    let service: String
    let account: String

    func set(_ value: String) throws {
        let kc = Keychain(service: service)
        try kc
            .label("ClaudeCode API Key")
            .synchronizable(false)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
            .set(value, key: account)
    }

    func get() throws -> String? {
        let kc = Keychain(service: service)
        return try kc.get(account)
    }

    func remove() throws {
        let kc = Keychain(service: service)
        try kc.remove(account)
    }
}


⸻

Sources/App/Networking/APIClient.swift

import Foundation

/// Minimal API client for the Claude Code gateway (OpenAI-compatible).
/// Provides JSON GET/POST helpers and a few typed endpoints used by feature views.
struct APIClient {
    let baseURL: URL
    let apiKey: String?

    init?(settings: AppSettings) {
        guard let url = settings.baseURLValidated else { return nil }
        self.baseURL = url
        self.apiKey = settings.apiKeyPlaintext.isEmpty ? nil : settings.apiKeyPlaintext
    }

    // MARK: Request building

    private func request(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        if let body { req.httpBody = body; req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let apiKey { req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        return req
    }

    private func data(for req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }

    // MARK: Generic GET/POST

    func getJSON<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        let req = request(path: path, method: "GET")
        let (data, http) = try await data(for: req)
        guard 200..<300 ~= http.statusCode else { throw APIError(status: http.statusCode, body: String(data: data, encoding: .utf8)) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func postJSON<T: Decodable, B: Encodable>(_ path: String, body: B, as: T.Type) async throws -> T {
        let payload = try JSONEncoder().encode(body)
        let req = request(path: path, method: "POST", body: payload)
        let (data, http) = try await data(for: req)
        guard 200..<300 ~= http.statusCode else { throw APIError(status: http.statusCode, body: String(data: data, encoding: .utf8)) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func delete(_ path: String) async throws {
        let req = request(path: path, method: "DELETE")
        let (_, http) = try await data(for: req)
        guard 200..<300 ~= http.statusCode else { throw APIError(status: http.statusCode, body: nil) }
    }

    struct APIError: Error, CustomStringConvertible {
        let status: Int
        let body: String?
        var description: String { "HTTP \(status) \(body ?? "")" }
    }

    // MARK: Typed endpoints used by views

    // Health
    struct HealthResponse: Decodable { let ok: Bool; let version: String?; let active_sessions: Int? }
    func health() async throws -> HealthResponse { try await getJSON("/health", as: HealthResponse.self) }

    // Projects
    struct Project: Decodable, Identifiable {
        let id: String; let name: String; let description: String; let path: String?
        let createdAt: String; let updatedAt: String
    }
    func listProjects() async throws -> [Project] { try await getJSON("/v1/projects", as: [Project].self) }
    struct NewProjectBody: Encodable { let name: String; let description: String; let path: String? }
    func createProject(name: String, description: String, path: String?) async throws -> Project {
        try await postJSON("/v1/projects", body: NewProjectBody(name: name, description: description, path: path), as: Project.self)
    }
    func getProject(id: String) async throws -> Project { try await getJSON("/v1/projects/\(id)", as: Project.self) }

    // Sessions
    struct Session: Decodable, Identifiable {
        let id: String; let projectId: String; let title: String?
        let model: String; let systemPrompt: String?
        let createdAt: String; let updatedAt: String
        let isActive: Bool; let totalTokens: Int?; let totalCost: Double?; let messageCount: Int?
    }
    func listSessions(projectId: String? = nil) async throws -> [Session] {
        let path = projectId.map { "/v1/sessions?project_id=\($0)" } ?? "/v1/sessions"
        return try await getJSON(path, as: [Session].self)
    }
    struct NewSessionBody: Encodable { let project_id: String; let model: String; let title: String?; let system_prompt: String? }
    func createSession(projectId: String, model: String, title: String?, systemPrompt: String?) async throws -> Session {
        let body = NewSessionBody(project_id: projectId, model: model, title: title, system_prompt: systemPrompt)
        return try await postJSON("/v1/sessions", body: body, as: Session.self)
    }

    // Models (for New Session picker)
    struct ModelCapability: Decodable, Identifiable {
        let id: String; let name: String; let description: String
        let maxTokens: Int; let supportsStreaming: Bool; let supportsTools: Bool
    }
    struct CapabilitiesEnvelope: Decodable { let models: [ModelCapability] }
    func modelCapabilities() async throws -> [ModelCapability] {
        try await getJSON("/v1/models/capabilities", as: CapabilitiesEnvelope.self).models
    }

    // Stats (Home KPIs)
    struct SessionStats: Decodable { let activeSessions: Int; let totalTokens: Int; let totalCost: Double; let totalMessages: Int }
    func sessionStats() async throws -> SessionStats { try await getJSON("/v1/sessions/stats", as: SessionStats.self) }
}


⸻

Sources/Features/Settings/SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings()
    @State private var validating = false
    @State private var healthText: String = "Not validated"
    @State private var showKey = false
    @State private var errorMsg: String?

    var body: some View {
        Form {
            Section("Server") {
                TextField("Base URL", text: $settings.baseURL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                HStack {
                    if showKey {
                        TextField("API Key", text: $settings.apiKeyPlaintext)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("API Key", text: $settings.apiKeyPlaintext)
                    }
                    Button(showKey ? "Hide" : "Show") { showKey.toggle() }
                        .buttonStyle(.bordered)
                }

                Toggle("Streaming by default", isOn: $settings.streamingDefault)

                Stepper(value: $settings.sseBufferKiB, in: 16...512, step: 16) {
                    Text("SSE buffer: \(settings.sseBufferKiB) KiB")
                }
            }

            Section("Actions") {
                HStack {
                    Button {
                        Task { await validateAndSave() }
                    } label: {
                        if validating { ProgressView() } else { Text("Validate") }
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                    Text(healthText)
                        .foregroundStyle(errorMsg == nil ? Theme.accent : Theme.destructive)
                        .font(.footnote)
                }
            }

            if let errorMsg {
                Section("Error") {
                    Text(errorMsg).foregroundStyle(Theme.destructive)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func validateAndSave() async {
        errorMsg = nil
        guard let client = APIClient(settings: settings) else {
            errorMsg = "Invalid Base URL"
            return
        }
        do {
            validating = true
            let health = try await client.health()
            try settings.saveAPIKey()
            healthText = health.ok ? "OK • v\(health.version ?? "?") • sessions \(health.active_sessions ?? 0)" : "Unhealthy"
        } catch {
            errorMsg = "\(error)"
            healthText = "Unhealthy"
        }
        validating = false
    }
}


⸻

Sources/Features/Home/HomeView.swift

import SwiftUI

struct HomeView: View {
    @StateObject private var settings = AppSettings()
    @State private var projects: [APIClient.Project] = []
    @State private var sessions: [APIClient.Session] = []
    @State private var stats: APIClient.SessionStats?
    @State private var isLoading = false
    @State private var err: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    // Quick Actions
                    HStack(spacing: 12) {
                        NavigationLink(destination: ProjectsListView()) {
                            pill("Projects", system: "folder")
                        }
                        NavigationLink(destination: SessionsView()) {
                            pill("Sessions", system: "bubble.left.and.bubble.right")
                        }
                        NavigationLink(destination: MonitoringView()) {
                            pill("Monitor", system: "gauge")
                        }
                    }.padding(.horizontal)

                    // Recent Projects
                    sectionCard("Recent Projects") {
                        if isLoading { ProgressView() }
                        else if projects.isEmpty { Text("No projects").foregroundStyle(Theme.mutedFg) }
                        else {
                            ForEach(projects.prefix(3)) { p in
                                NavigationLink(destination: ProjectDetailView(projectId: p.id)) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(p.name).font(.headline)
                                            Text(p.path ?? "—").font(.caption).foregroundStyle(Theme.mutedFg)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }.padding(.vertical, 6)
                                }
                                Divider().background(Theme.border)
                            }
                        }
                    }

                    // Active Sessions
                    sectionCard("Active Sessions") {
                        if isLoading { ProgressView() }
                        else if sessions.isEmpty { Text("No active sessions").foregroundStyle(Theme.mutedFg) }
                        else {
                            ForEach(sessions.prefix(3)) { s in
                                NavigationLink(destination: ChatConsoleView(sessionId: s.id, projectId: s.projectId)) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(s.title ?? s.id).font(.subheadline)
                                            Text("model \(s.model) • msgs \(s.messageCount ?? 0)")
                                                .font(.caption).foregroundStyle(Theme.mutedFg)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }.padding(.vertical, 6)
                                }
                                Divider().background(Theme.border)
                            }
                        }
                    }

                    // KPIs
                    sectionCard("Usage Highlights") {
                        if let st = stats {
                            HStack {
                                metric("Tokens", "\(st.totalTokens)")
                                metric("Sessions", "\(st.activeSessions)")
                                metric("Cost", String(format: "$%.2f", st.totalCost))
                                metric("Msgs", "\(st.totalMessages)")
                            }
                        } else if isLoading { ProgressView() }
                        else { Text("No stats").foregroundStyle(Theme.mutedFg) }
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Theme.background)
            .navigationTitle("Claude Code")
            .toolbar {
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gear")
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .alert("Error", isPresented: .constant(err != nil), presenting: err) { _ in
                Button("OK", role: .cancel) { err = nil }
            } message: { err in Text(err) }
        }
    }

    private func load() async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        isLoading = true
        do {
            async let ps = client.listProjects()
            async let ss = client.listSessions() // all
            async let st = client.sessionStats()
            projects = try await ps
            sessions = try await ss.filter { $0.isActive }
            stats = try await st
        } catch {
            err = "\(error)"
        }
        isLoading = false
    }

    private func pill(_ title: String, system: String) -> some View {
        Label(title, systemImage: system)
            .padding(.vertical, 10).padding(.horizontal, 14)
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(Theme.foreground)
            content()
        }
        .padding()
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.headline).foregroundStyle(Theme.primary)
            Text(label).font(.caption).foregroundStyle(Theme.mutedFg)
        }.frame(maxWidth: .infinity)
    }
}


⸻

Sources/Features/Projects/ProjectsListView.swift

import SwiftUI

struct ProjectsListView: View {
    @StateObject private var settings = AppSettings()
    @State private var projects: [APIClient.Project] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var err: String?
    @State private var showCreate = false

    var body: some View {
        List {
            if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
            ForEach(filtered(projects)) { p in
                NavigationLink(destination: ProjectDetailView(projectId: p.id)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.body)
                        Text(p.path ?? "—").font(.caption).foregroundStyle(Theme.mutedFg)
                    }
                }
            }
        }
        .searchable(text: $search)
        .navigationTitle("Projects")
        .toolbar {
            Button {
                showCreate = true
            } label: {
                Label("New", systemImage: "plus")
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showCreate) {
            CreateProjectSheet { name, desc, path in
                Task {
                    await create(name: name, desc: desc, path: path)
                    showCreate = false
                }
            }
        }
        .alert("Error", isPresented: .constant(err != nil), presenting: err) { _ in
            Button("OK", role: .cancel) { err = nil }
        } message: { e in Text(e) }
    }

    private func filtered(_ items: [APIClient.Project]) -> [APIClient.Project] {
        guard !search.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(search) || ($0.path ?? "").localizedCaseInsensitiveContains(search) }
    }

    private func load() async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        isLoading = true
        defer { isLoading = false }
        do { projects = try await client.listProjects() }
        catch { err = "\(error)" }
    }

    private func create(name: String, desc: String, path: String?) async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        do {
            _ = try await client.createProject(name: name, description: desc, path: path)
            await load()
        } catch { err = "\(error)" }
    }
}

private struct CreateProjectSheet: View {
    var onCreate: (String, String, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var desc = ""
    @State private var path: String = ""

    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $desc)
                TextField("Path (optional)", text: $path)
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create") { onCreate(name, desc, path.isEmpty ? nil : path) } .disabled(name.isEmpty) }
            }
        }
    }
}


⸻

Sources/Features/Projects/ProjectDetailView.swift

import SwiftUI

struct ProjectDetailView: View {
    @StateObject private var settings = AppSettings()
    let projectId: String

    @State private var project: APIClient.Project?
    @State private var sessions: [APIClient.Session] = []
    @State private var isLoading = false
    @State private var err: String?
    @State private var showNewSession = false

    var body: some View {
        List {
            if let p = project {
                Section("Info") {
                    LabeledContent("Name", value: p.name)
                    LabeledContent("Path", value: p.path ?? "—")
                    LabeledContent("Updated", value: p.updatedAt)
                }
            } else if isLoading {
                ProgressView()
            }

            Section("Sessions") {
                if sessions.isEmpty { Text("No sessions").foregroundStyle(Theme.mutedFg) }
                ForEach(sessions) { s in
                    NavigationLink(destination: ChatConsoleView(sessionId: s.id, projectId: s.projectId)) {
                        VStack(alignment: .leading) {
                            Text(s.title ?? s.id).font(.body)
                            Text("model \(s.model) • msgs \(s.messageCount ?? 0)")
                                .font(.caption).foregroundStyle(Theme.mutedFg)
                        }
                    }
                }
            }
        }
        .navigationTitle("Project")
        .toolbar {
            Button { showNewSession = true } label: { Label("New Session", systemImage: "plus") }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showNewSession) {
            NewSessionView(projectId: projectId)
        }
        .alert("Error", isPresented: .constant(err != nil), presenting: err) { _ in
            Button("OK", role: .cancel) { err = nil }
        } message: { e in Text(e) }
    }

    private func load() async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        isLoading = true; defer { isLoading = false }
        do {
            async let p = client.getProject(id: projectId)
            async let ss = client.listSessions(projectId: projectId)
            project = try await p
            sessions = try await ss
        } catch { err = "\(error)" }
    }
}


⸻

Sources/Features/Sessions/NewSessionView.swift

import SwiftUI

struct NewSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = AppSettings()

    let projectId: String
    @State private var capabilities: [APIClient.ModelCapability] = []
    @State private var selectedModelId: String = ""
    @State private var title: String = ""
    @State private var systemPrompt: String = ""
    @State private var isLoading = false
    @State private var err: String?

    var body: some View {
        NavigationView {
            Form {
                if capabilities.isEmpty && isLoading { ProgressView() }

                Picker("Model", selection: $selectedModelId) {
                    ForEach(capabilities) { m in
                        Text(m.name).tag(m.id)
                    }
                }

                TextField("Title (optional)", text: $title)
                TextEditor(text: $systemPrompt)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))

                Toggle("Streaming by default", isOn: $settings.streamingDefault)
            }
            .navigationTitle("New Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { Task { await start() } }.disabled(selectedModelId.isEmpty)
                }
            }
            .task { await load() }
            .alert("Error", isPresented: .constant(err != nil), presenting: err) { _ in
                Button("OK", role: .cancel) { err = nil }
            } message: { e in Text(e) }
        }
    }

    private func load() async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        isLoading = true; defer { isLoading = false }
        do {
            capabilities = try await client.modelCapabilities()
            if let first = capabilities.first { selectedModelId = first.id }
        } catch { err = "\(error)" }
    }

    private func start() async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        do {
            _ = try await client.createSession(projectId: projectId, model: selectedModelId, title: title.isEmpty ? nil : title, systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt)
            dismiss()
        } catch { err = "\(error)" }
    }
}


⸻

Sources/App/Theme/Tokens.css

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


⸻


	•	ChatConsoleView.swift (SSE + non-SSE, Tool Timeline, Hyperthink shell, Status/Stop)
	•	FileBrowserView.swift, FilePreviewView.swift
	•	MonitoringView.swift, TracingView.swift
	•	MCPSettingsView.swift, SessionToolPickerView.swift
	
Part 3/4 (B) — Chat Console, File Browser/Preview, Monitoring, Tracing, MCP views
(Full, copy-pasteable files. These compile against the earlier Parts.)

⸻

Sources/Features/Sessions/ChatConsoleView.swift

import SwiftUI
import Foundation
import os.log

// MARK: - Lightweight transcript & timeline models for the UI

struct ChatBubble: Identifiable, Equatable {
    enum Role: String { case user, assistant, system }
    let id = UUID()
    let role: Role
    var text: String
    let ts: Date = .init()
}

struct ToolRow: Identifiable, Equatable {
    enum State { case running, ok, error }
    let id: String              // tool_id from stream, or UUID().uuidString if absent
    let name: String
    var state: State
    var inputJSON: String
    var output: String = ""
    var durationMs: Int? = nil
    var exitCode: Int? = nil
    let ts: Date = .init()
}

// MARK: - View

struct ChatConsoleView: View {
    @StateObject private var settings = AppSettings()
    let sessionId: String?
    let projectId: String

    @State private var currentSessionId: String?
    @State private var modelId: String = "claude-3-5-haiku-20241022"

    @State private var transcript: [ChatBubble] = []
    @State private var timeline: [ToolRow] = []
    @State private var composing: String = ""
    @State private var isStreaming: Bool = false
    @State private var useStream: Bool = true
    @State private var statusLine: String = ""
    @State private var errorMsg: String?

    private let log = Logger(subsystem: "com.yourorg.claudecode", category: "Chat")

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            HStack(spacing: 12) {
                // Transcript
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(transcript) { b in
                            bubbleView(b)
                                .frame(maxWidth: .infinity, alignment: b.role == .user ? .trailing : .leading)
                                .padding(.horizontal)
                        }
                    }.padding(.vertical, 8)
                }
                .background(Theme.background)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Tool timeline
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Tool Timeline").font(.headline)
                            Spacer()
                            Text(statusLine).font(.footnote).foregroundStyle(Theme.mutedFg)
                        }
                        ForEach(timeline) { row in
                            toolRowView(row)
                                .padding(8)
                                .background(Theme.card)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }.padding()
                }
                .frame(width: 300)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            composerBar
        }
        .background(Theme.background)
        .navigationTitle("Chat Console")
        .onAppear {
            self.currentSessionId = sessionId
            self.useStream = settings.streamingDefault
        }
        .alert("Error", isPresented: .constant(errorMsg != nil), presenting: errorMsg) { _ in
            Button("OK", role: .cancel) { errorMsg = nil }
        } message: { e in Text(e) }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Text("Session: \(currentSessionId ?? "—")")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedFg)

            Spacer()

            Picker("Model", selection: $modelId) {
                Text("Claude 3.5 Haiku").tag("claude-3-5-haiku-20241022")
                // Add more known model IDs here if you like
            }
            .pickerStyle(.menu)

            Toggle(isOn: $useStream) { Text("Stream").font(.subheadline) }
                .toggleStyle(.switch)
                .tint(Theme.primary)

            Button {
                Task { await stopIfRunning() }
            } label: { Label("Stop", systemImage: "stop.circle.fill") }
                .buttonStyle(.bordered)
                .tint(Theme.secondary)
                .disabled(!isStreaming)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Theme.card.opacity(0.4))
    }

    // MARK: Composer

    private var composerBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $composing)
                    .frame(minHeight: 44, maxHeight: 120)
                    .padding(8)
                    .background(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))

                Button {
                    let text = composing.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    Task { await send(text) }
                } label: {
                    HStack { Image(systemName: "paperplane.fill"); Text("Send") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStreaming)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Theme.card.opacity(0.4))
    }

    private func bubbleView(_ b: ChatBubble) -> some View {
        let bg = b.role == .user ? Theme.secondary : Theme.card
        let fg = b.role == .user ? Theme.secondaryFg : Theme.foreground
        return VStack(alignment: .leading, spacing: 4) {
            Text(b.role.rawValue.capitalized).font(.caption).foregroundStyle(Theme.mutedFg)
            Text(b.text).font(.body).foregroundStyle(fg)
        }
        .padding(10)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toolRowView(_ row: ToolRow) -> some View {
        HStack(alignment: .top) {
            Circle()
                .fill(color(for: row.state))
                .frame(width: 10, height: 10)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(row.name).font(.subheadline)
                    Spacer()
                    if let ms = row.durationMs { Text("\(ms) ms").font(.caption).foregroundStyle(Theme.mutedFg) }
                    if let ec = row.exitCode { Text("exit \(ec)").font(.caption).foregroundStyle(Theme.mutedFg) }
                }
                if !row.inputJSON.isEmpty {
                    Text("input: \(row.inputJSON)").font(.caption).foregroundStyle(Theme.mutedFg)
                        .lineLimit(3)
                }
                if !row.output.isEmpty {
                    Text(row.output).font(.caption)
                        .foregroundStyle(row.state == .error ? Theme.destructiveFg : Theme.foreground)
                        .lineLimit(6)
                }
            }
        }
    }

    private func color(for state: ToolRow.State) -> Color {
        switch state {
        case .running: return Theme.ring
        case .ok:      return Theme.accent
        case .error:   return Theme.destructive
        }
    }

    // MARK: Send (SSE vs non-SSE)

    private func send(_ text: String) async {
        composing = ""
        transcript.append(.init(role: .user, text: text))

        if useStream {
            await streamOnce(text)
        } else {
            await nonStreamOnce(text)
        }
    }

    private func nonStreamOnce(_ text: String) async {
        guard let client = APIClient(settings: settings) else { errorMsg = "Invalid Base URL"; return }
        do {
            let body: [String: Any] = [
                "model": modelId,
                "project_id": projectId,
                "session_id": currentSessionId as Any,
                "messages": [
                    ["role": "user", "content": text]
                ],
                "stream": false
            ].compactMapValues { $0 }
            let data = try JSONSerialization.data(withJSONObject: body, options: [])
            var req = URLRequest(url: client.baseURL.appendingPathComponent("/v1/chat/completions"))
            req.httpMethod = "POST"
            req.httpBody = data
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let key = client.apiKey { req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }

            let (respData, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let bodyS = String(data: respData, encoding: .utf8) ?? ""
                throw NSError(domain: "HTTP", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: bodyS])
            }

            // parse OpenAI-like completion
            if let obj = try JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let choices = obj["choices"] as? [[String: Any]],
               let msg = choices.first?["message"] as? [String: Any],
               let content = msg["content"] as? String {
                transcript.append(.init(role: .assistant, text: content))
            } else {
                transcript.append(.init(role: .assistant, text: "(no content)"))
            }

            if currentSessionId == nil, let sid = (try? JSONSerialization.jsonObject(with: respData)) as? [String: Any] {
                if let s = sid["session_id"] as? String { currentSessionId = s }
            }
            await fetchStatus()
        } catch {
            errorMsg = "\(error)"
        }
    }

    private func streamOnce(_ text: String) async {
        guard let client = APIClient(settings: settings) else { errorMsg = "Invalid Base URL"; return }
        isStreaming = true
        defer { isStreaming = false }

        // Create SSE client
        let sse = SSEClient()
        var assistantIndex: Int? // index in transcript for the streaming assistant bubble
        var pendingAssistant = ChatBubble(role: .assistant, text: "")

        sse.onEvent = { event in
            handleSSELine(event.raw,
                          transcriptAppend: { addition in
                              // create or update last assistant bubble
                              if let idx = assistantIndex {
                                  transcript[idx].text += addition
                              } else {
                                  pendingAssistant.text += addition
                                  transcript.append(pendingAssistant)
                                  assistantIndex = transcript.count - 1
                              }
                          },
                          setSession: { sid in
                              if currentSessionId == nil { currentSessionId = sid }
                          })
        }
        sse.onDone = {
            Task { await fetchStatus() }
        }
        sse.onError = { err in
            errorMsg = err.localizedDescription
        }

        // Build payload
        let body: [String: Any] = [
            "model": modelId,
            "project_id": projectId,
            "session_id": currentSessionId as Any,
            "messages": [
                ["role": "user", "content": text]
            ],
            "stream": true
        ].compactMapValues { $0 }

        do {
            let data = try JSONSerialization.data(withJSONObject: body)
            sse.connect(url: client.baseURL.appendingPathComponent("/v1/chat/completions"),
                        body: data,
                        headers: client.apiKey.map { ["Authorization": "Bearer \($0)"] } ?? [:])
        } catch {
            errorMsg = "\(error)"
        }
    }

    // Parse a single SSE JSON line (string after "data: ")
    private func handleSSELine(
        _ jsonLine: String,
        transcriptAppend: (String) -> Void,
        setSession: (String) -> Void
    ) {
        guard let data = jsonLine.data(using: .utf8) else { return }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let kind = (obj["object"] as? String) ?? (obj["type"] as? String) ?? ""
        switch kind {
        case "chat.completion.chunk":
            if let choices = obj["choices"] as? [[String: Any]],
               let delta = choices.first?["delta"] as? [String: Any],
               let piece = delta["content"] as? String, !piece.isEmpty {
                transcriptAppend(piece)
            }
            if let sid = obj["session_id"] as? String { setSession(sid) }

        case "tool_use":
            let toolId = (obj["id"] as? String) ?? UUID().uuidString
            let name = (obj["name"] as? String) ?? "tool"
            let inputAny = obj["input"]
            let inputJSON = (try? JSONSerialization.data(withJSONObject: inputAny ?? [:], options: [.sortedKeys, .withoutEscapingSlashes]))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            timeline.insert(.init(id: toolId, name: name, state: .running, inputJSON: inputJSON), at: 0)

        case "tool_result":
            let toolId = (obj["tool_id"] as? String) ?? UUID().uuidString
            let name = (obj["name"] as? String) ?? "tool"
            let isError = (obj["is_error"] as? Bool) ?? false
            let out = (obj["content"] as? String) ?? ""
            let dur = obj["duration_ms"] as? Int
            let exit = obj["exit_code"] as? Int
            if let idx = timeline.firstIndex(where: { $0.id == toolId }) {
                timeline[idx].state = isError ? .error : .ok
                timeline[idx].name = name
                timeline[idx].output = out
                timeline[idx].durationMs = dur
                timeline[idx].exitCode = exit
            } else {
                timeline.insert(.init(id: toolId, name: name, state: isError ? .error : .ok, inputJSON: "{}", output: out, durationMs: dur, exitCode: exit), at: 0)
            }

        case "usage":
            let inTok = obj["input_tokens"] as? Int ?? 0
            let outTok = obj["output_tokens"] as? Int ?? 0
            let cost = obj["total_cost"] as? Double ?? 0
            statusLine = "tokens \(inTok + outTok) • cost $\(String(format: "%.4f", cost))"

        default:
            // Unknown frame shape; ignore safely
            break
        }
    }

    // MARK: Status / Stop

    private func fetchStatus() async {
        guard let client = APIClient(settings: settings), let sid = currentSessionId else { return }
        do {
            // minimal GET
            let req = URLRequest(url: client.baseURL.appendingPathComponent("/v1/chat/completions/\(sid)/status"))
            let (data, _) = try await URLSession.shared.data(for: req)
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let tokens = obj["total_tokens"] as? Int ?? 0
                let cost = obj["total_cost"] as? Double ?? 0
                statusLine = "tokens \(tokens) • cost $\(String(format: "%.4f", cost))"
            }
        } catch {
            // non-fatal
        }
    }

    private func stopIfRunning() async {
        guard let client = APIClient(settings: settings), let sid = currentSessionId else { return }
        do {
            try await client.delete("/v1/chat/completions/\(sid)")
            isStreaming = false
        } catch {
            errorMsg = "\(error)"
        }
    }
}


⸻

Sources/Features/Files/FileBrowserView.swift

import SwiftUI

/// SSH-based minimal file browser (read-only). Provide host creds, path, and list.
struct FileBrowserView: View {
    @State private var host = "localhost"
    @State private var user = "user"
    @State private var pass = ""
    @State private var path = "."
    @State private var listing: [String] = []
    @State private var previewPath: String? = nil
    @State private var errorMsg: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                formBar

                List {
                    ForEach(listing, id: \.self) { line in
                        HStack {
                            Text(line).font(.caption)
                            Spacer()
                            if line.contains("<dir>") == false {
                                Button("Preview") { previewPath = resolvedPath(from: line) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Files")
            .sheet(item: $previewPath) { p in
                FilePreviewView(host: host, user: user, pass: pass, filePath: p)
            }
            .alert("Error", isPresented: .constant(errorMsg != nil), presenting: errorMsg) { _ in
                Button("OK", role: .cancel) { errorMsg = nil }
            } message: { e in Text(e) }
        }
    }

    private var formBar: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Host", text: $host).textInputAutocapitalization(.never).disableAutocorrection(true)
                TextField("User", text: $user).textInputAutocapitalization(.never).disableAutocorrection(true)
                SecureField("Pass", text: $pass)
            }
            HStack {
                TextField("Path", text: $path).textInputAutocapitalization(.never).disableAutocorrection(true)
                Button("List") { Task { await list() } }.buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
    }

    private func list() async {
        do {
            let ssh = SSHClient()
            let hostObj = SSHHost(hostname: host, username: user, password: pass)
            // Print directories with "<dir>" marker, files as plain names.
            // Linux: 'ls -l' and mark directories via first column starting with 'd'.
            let (status, output) = try ssh.runCaptureAll("ls -l \(shellEscape(path))", on: hostObj)
            guard status == 0 else { throw NSError(domain: "ssh", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output]) }
            listing = output.components(separatedBy: .newlines).compactMap { line in
                guard !line.isEmpty else { return nil }
                if line.hasPrefix("total") { return nil }
                // e.g., drwxr-xr-x  2 user group  4096 Aug  1  name
                let isDir = line.first == "d"
                let name = line.split(separator: " ", omittingEmptySubsequences: true).dropFirst(8).joined(separator: " ")
                return isDir ? "<dir> \(name)" : "\(name)"
            }
        } catch {
            errorMsg = "\(error)"
        }
    }

    private func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func resolvedPath(from line: String) -> String {
        let name = line.replacingOccurrences(of: "<dir> ", with: "")
        if path == "." { return name }
        if path.hasSuffix("/") { return path + name }
        return path + "/" + name
    }
}


⸻

Sources/Features/Files/FilePreviewView.swift

import SwiftUI

struct FilePreviewView: View, Identifiable {
    var id: String { filePath }
    let host: String
    let user: String
    let pass: String
    let filePath: String

    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @State private var errorMsg: String?

    var body: some View {
        NavigationView {
            ScrollView {
                Text(content.isEmpty ? "No content" : content)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(filePath)
            .toolbar { Button("Close") { dismiss() } }
            .onAppear { Task { await load() } }
            .alert("Error", isPresented: .constant(errorMsg != nil), presenting: errorMsg) { _ in
                Button("OK", role: .cancel) { errorMsg = nil }
            } message: { e in Text(e) }
        }
    }

    private func load() async {
        do {
            let ssh = SSHClient()
            let hostObj = SSHHost(hostname: host, username: user, password: pass)
            let (status, output) = try ssh.runCaptureAll("cat \(shellEscape(filePath))", on: hostObj)
            guard status == 0 else { throw NSError(domain: "ssh", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output]) }
            content = output
        } catch {
            errorMsg = "\(error)"
        }
    }

    private func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}


⸻

Sources/Features/Monitoring/MonitoringView.swift (expanded)

import SwiftUI

struct MonitoringView: View {
    @State private var host = "localhost"
    @State private var user = "user"
    @State private var pass = ""
    @State private var snapshot: HostSnapshot?
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        Form {
            Section("Host") {
                TextField("Host", text: $host).textInputAutocapitalization(.never).disableAutocorrection(true)
                TextField("User", text: $user).textInputAutocapitalization(.never).disableAutocorrection(true)
                SecureField("Pass", text: $pass)
                HStack {
                    Button("Snapshot (Linux)") { Task { await snapLinux() } }
                        .buttonStyle(.borderedProminent)
                    Button("Snapshot (macOS)") { Task { await snapMac() } }
                        .buttonStyle(.bordered)
                }
            }

            Section("Summary") {
                if isLoading { ProgressView() }
                if let s = snapshot {
                    HStack {
                        metric("CPU", String(format: "%.0f%%", s.cpu.usagePercent))
                        metric("Mem", "\(s.mem.usedMB)/\(s.mem.totalMB) MB")
                        metric("Net", String(format: "↑%.1f ↓%.1f MB/s", s.net.txMBs, s.net.rxMBs))
                    }
                } else {
                    Text("No data").foregroundStyle(Theme.mutedFg)
                }
            }

            if let s = snapshot {
                Section("Disks") {
                    ForEach(s.disks.indices, id: \.self) { i in
                        let d = s.disks[i]
                        HStack {
                            Text(d.mount)
                            Spacer()
                            Text("\(Int(d.usedPercent))%")
                                .foregroundStyle(Theme.mutedFg)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Theme.input).frame(height: 6)
                                Rectangle().fill(Theme.primary).frame(width: geo.size.width * CGFloat(d.usedPercent/100.0), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }

                Section("Top Processes") {
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(s.top, id: \.self) { line in
                                Text(line).font(.system(.footnote, design: .monospaced))
                            }
                        }
                    }.frame(maxHeight: 200)
                }
            }
        }
        .navigationTitle("Monitor")
        .alert("Error", isPresented: .constant(errorMsg != nil), presenting: errorMsg) { _ in
            Button("OK", role: .cancel) { errorMsg = nil }
        } message: { e in Text(e) }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.headline).foregroundStyle(Theme.primary)
            Text(label).font(.caption).foregroundStyle(Theme.mutedFg)
        }.frame(maxWidth: .infinity)
    }

    private func snapLinux() async {
        isLoading = true; defer { isLoading = false }
        do {
            let s = try HostStatsService(ssh: SSHClient())
                .snapshotLinux(host: .init(hostname: host, username: user, password: pass))
            snapshot = s
        } catch { errorMsg = "\(error)" }
    }

    private func snapMac() async {
        isLoading = true; defer { isLoading = false }
        do {
            let s = try HostStatsService(ssh: SSHClient())
                .snapshotMac(host: .init(hostname: host, username: user, password: pass))
            snapshot = s
        } catch { errorMsg = "\(error)" }
    }
}


⸻

Sources/Features/Tracing/TracingView.swift

import SwiftUI
import UIKit

struct TraceEntry: Identifiable {
    let id = UUID()
    let ts: Date
    let level: String
    let scope: String
    let message: String
    let meta: String?
}

final class TraceStore: ObservableObject {
    @Published var entries: [TraceEntry] = []
    func append(level: String, scope: String, message: String, meta: String? = nil) {
        entries.insert(.init(ts: .init(), level: level, scope: scope, message: message, meta: meta), at: 0)
    }
}

struct TracingView: View {
    @StateObject private var store = TraceStore()
    @State private var filterLevel: String = "all"
    @State private var filterScope: String = "all"

    var filtered: [TraceEntry] {
        store.entries.filter {
            (filterLevel == "all" || $0.level == filterLevel) &&
            (filterScope == "all" || $0.scope == filterScope)
        }
    }

    var body: some View {
        VStack {
            HStack {
                Picker("Level", selection: $filterLevel) {
                    Text("All").tag("all"); Text("info").tag("info"); Text("warn").tag("warn"); Text("error").tag("error")
                }.pickerStyle(.segmented)
                Picker("Scope", selection: $filterScope) {
                    Text("All").tag("all"); Text("chat").tag("chat"); Text("sse").tag("sse"); Text("ssh").tag("ssh")
                }.pickerStyle(.segmented)
            }.padding(.horizontal)

            List {
                ForEach(filtered) { e in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(e.ts.formatted(date: .omitted, time: .standard)).font(.caption).foregroundStyle(Theme.mutedFg)
                            Spacer()
                            Text(e.level).font(.caption2)
                        }
                        Text(e.message).font(.footnote)
                        if let m = e.meta { Text(m).font(.caption2).foregroundStyle(Theme.mutedFg) }
                    }
                }
            }

            HStack {
                Button("Add Sample Trace") {
                    store.append(level: "info", scope: "chat", message: "POST /v1/chat streaming OK", meta: "200 • 56ms")
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Export NDJSON") {
                    let ndjson = store.entries.map { e in
                        #"{"ts":"\#(ISO8601DateFormatter().string(from: e.ts))","level":"\#(e.level)","scope":"\#(e.scope)","message":\#(String(reflecting: e.message)),"meta":\#(String(reflecting: e.meta ?? ""))}"#
                    }.joined(separator: "\n")
                    UIPasteboard.general.string = ndjson
                }
                .buttonStyle(.borderedProminent)
            }.padding()
        }
        .navigationTitle("Tracing")
    }
}


⸻

Sources/Features/MCP/MCPSettingsView.swift

import SwiftUI

// Simple local MCP config persistence (per user). Session-level overrides are in SessionToolPickerView.
struct MCPConfigLocal: Codable {
    var enabledServers: [String]
    var enabledTools: [String]
    var priority: [String]
    var auditLog: Bool
}

struct MCPSettingsView: View {
    @AppStorage("mcpConfigJSON") private var mcpJSON: String = ""
    @State private var enabledServers: [String] = ["fs-local", "bash"]
    @State private var enabledTools: [String] = ["fs.read", "fs.write", "grep.search", "bash.run"]
    @State private var priority: [String] = ["fs.read", "bash.run", "fs.write"]
    @State private var auditLog: Bool = true
    @State private var newServer = ""
    @State private var newTool = ""

    var body: some View {
        Form {
            Section("Servers") {
                HStack {
                    TextField("Add server id", text: $newServer)
                    Button("Add") { if !newServer.isEmpty { enabledServers.append(newServer); newServer = "" } }
                }
                ForEach(enabledServers, id: \.self) { s in
                    HStack {
                        Text(s)
                        Spacer()
                        Button(role: .destructive) { enabledServers.removeAll { $0 == s } } label: { Image(systemName: "trash") }
                    }
                }
            }

            Section("Tools") {
                HStack {
                    TextField("Add tool name", text: $newTool)
                    Button("Add") { if !newTool.isEmpty { enabledTools.append(newTool); newTool = "" } }
                }
                ForEach(enabledTools, id: \.self) { t in
                    HStack {
                        Text(t)
                        Spacer()
                        Button(role: .destructive) { enabledTools.removeAll { $0 == t } } label: { Image(systemName: "trash") }
                    }
                }
            }

            Section("Priority (drag to reorder)") {
                ReorderableList(items: $priority)
            }

            Section {
                Toggle("Audit Log", isOn: $auditLog)
            }

            Section {
                Button("Save as Default") { save() }.buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("MCP Settings")
        .onAppear { load() }
    }

    private func load() {
        guard !mcpJSON.isEmpty, let data = mcpJSON.data(using: .utf8) else { return }
        if let c = try? JSONDecoder().decode(MCPConfigLocal.self, from: data) {
            enabledServers = c.enabledServers
            enabledTools = c.enabledTools
            priority = c.priority
            auditLog = c.auditLog
        }
    }

    private func save() {
        let c = MCPConfigLocal(enabledServers: enabledServers, enabledTools: enabledTools, priority: priority, auditLog: auditLog)
        if let data = try? JSONEncoder().encode(c), let s = String(data: data, encoding: .utf8) {
            mcpJSON = s
        }
    }
}

// Minimal "drag reorder" list
private struct ReorderableList: View {
    @Binding var items: [String]
    @State private var edit = EditMode.inactive
    var body: some View {
        List {
            ForEach(items, id: \.self) { t in Text(t) }
                .onMove { src, dst in items.move(fromOffsets: src, toOffset: dst) }
        }
        .environment(\.editMode, $edit)
        .onAppear { edit = .active }
        .frame(height: min(240, CGFloat(max(1, items.count)) * 44))
    }
}


⸻

Sources/Features/MCP/SessionToolPickerView.swift

import SwiftUI

// Per-session overrides; persist JSON under a key derived from sessionId.
struct SessionToolPickerView: View {
    let sessionId: String

    @AppStorage("mcpConfigJSON") private var defaultJSON: String = ""
    @AppStorage var sessionJSON: String

    @State private var enabledServers: [String] = []
    @State private var enabledTools: [String] = []
    @State private var priority: [String] = []
    @State private var auditLog: Bool = true

    @Environment(\.dismiss) private var dismiss

    init(sessionId: String) {
        self.sessionId = sessionId
        // dynamic appstorage key
        _sessionJSON = AppStorage(wrappedValue: "", "mcpSession.\(sessionId)")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Enabled Servers") {
                    TokenEditor(tokens: $enabledServers, placeholder: "server id")
                }
                Section("Enabled Tools") {
                    TokenEditor(tokens: $enabledTools, placeholder: "tool name")
                }
                Section("Priority (drag)") {
                    ReorderableList(items: $priority)
                }
                Section {
                    Toggle("Audit Log", isOn: $auditLog)
                }
            }
            .navigationTitle("Session Tools")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save(); dismiss() } }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        // Start from session JSON; fallback to default
        if let d = sessionJSON.data(using: .utf8),
           let c = try? JSONDecoder().decode(MCPConfigLocal.self, from: d) {
            enabledServers = c.enabledServers; enabledTools = c.enabledTools; priority = c.priority; auditLog = c.auditLog
            return
        }
        if let d = defaultJSON.data(using: .utf8),
           let c = try? JSONDecoder().decode(MCPConfigLocal.self, from: d) {
            enabledServers = c.enabledServers; enabledTools = c.enabledTools; priority = c.priority; auditLog = c.auditLog
        }
    }

    private func save() {
        let c = MCPConfigLocal(enabledServers: enabledServers, enabledTools: enabledTools, priority: priority, auditLog: auditLog)
        if let data = try? JSONEncoder().encode(c), let s = String(data: data, encoding: .utf8) {
            sessionJSON = s
        }
    }
}

private struct TokenEditor: View {
    @Binding var tokens: [String]
    @State private var new = ""
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(placeholder, text: $new).textInputAutocapitalization(.never).disableAutocorrection(true)
                Button("Add") { if !new.isEmpty { tokens.append(new); new = "" } }
                    .buttonStyle(.bordered)
            }
            Wrap(tokens) { t in
                HStack(spacing: 4) {
                    Text(t).font(.caption)
                    Button(role: .destructive) { tokens.removeAll { $0 == t } } label: { Image(systemName: "xmark.circle.fill") }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// Simple wrap layout for chips
private struct Wrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let content: (Data.Element) -> Content
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data; self.content = content
    }
    @State private var totalHeight = CGFloat.zero
    var body: some View {
        GeometryReader { geo in
            self.generate(in: geo)
        }.frame(height: totalHeight)
    }
    private func generate(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading, computeValue: { d in
                        if width + d.width > g.size.width { width = 0; height -= d.height }
                        defer { width += d.width }
                        return width
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let res = height; if item == data.last { DispatchQueue.main.async { self.totalHeight = -height } }
                        return res
                    })
            }
        }
    }
}


⸻

Part 4/4 — Final bits
I'll send the remaining files next:
	•	Sources/Features/Sessions/SessionsView.swift (list of sessions; we provided a stub, I'll include the full version)
	•	Sources/Features/Settings/SettingsView.swift was included; ok
	•	Scripts/bootstrap.sh
	•	Scripts/mock_sse_server.py
	•	SPEC.md (concise version pointing to the full spec you asked for)
	
	
Part 4/4 — Remaining files (Sessions view, scripts, consolidated SPEC.md)

⸻

Sources/Features/Sessions/SessionsView.swift (full)

import SwiftUI

struct SessionsView: View {
    @StateObject private var settings = AppSettings()
    @State private var sessions: [APIClient.Session] = []
    @State private var search = ""
    @State private var scope: Scope = .active
    @State private var isLoading = false
    @State private var err: String?

    enum Scope: String, CaseIterable, Identifiable { case active, all
        var id: String { rawValue }
        var title: String { self == .active ? "Active" : "All" }
    }

    var body: some View {
        List {
            if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }

            ForEach(filtered(sessions)) { s in
                NavigationLink(destination: ChatConsoleView(sessionId: s.id, projectId: s.projectId)) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(s.title ?? s.id).font(.body)
                            if s.isActive { Text("LIVE").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Theme.accent).clipShape(Capsule())
                                    .foregroundStyle(Theme.accentFg)
                            }
                            Spacer()
                            Text(s.model).font(.caption).foregroundStyle(Theme.mutedFg)
                        }
                        HStack(spacing: 8) {
                            Text("msgs \(s.messageCount ?? 0)").font(.caption).foregroundStyle(Theme.mutedFg)
                            if let t = s.totalTokens { Text("tok \(t)").font(.caption).foregroundStyle(Theme.mutedFg) }
                            if let c = s.totalCost   { Text(String(format: "$%.3f", c)).font(.caption).foregroundStyle(Theme.mutedFg) }
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if s.isActive {
                        Button(role: .destructive) { Task { await stop(id: s.id) } } label: {
                            Label("Stop", systemImage: "stop.circle.fill")
                        }
                    }
                }
            }
        }
        .searchable(text: $search)
        .toolbar {
            Picker("Scope", selection: $scope) {
                ForEach(Scope.allCases) { sc in Text(sc.title).tag(sc) }
            }.pickerStyle(.segmented)
        }
        .navigationTitle("Sessions")
        .task { await load() }
        .refreshable { await load() }
        .alert("Error", isPresented: .constant(err != nil), presenting: err) { _ in
            Button("OK", role: .cancel) { err = nil }
        } message: { e in Text(e) }
    }

    private func filtered(_ items: [APIClient.Session]) -> [APIClient.Session] {
        var base = items
        if scope == .active { base = base.filter { $0.isActive } }
        guard !search.isEmpty else { return base }
        return base.filter { s in
            (s.title ?? s.id).localizedCaseInsensitiveContains(search)
            || s.model.localizedCaseInsensitiveContains(search)
            || s.projectId.localizedCaseInsensitiveContains(search)
        }
    }

    private func load() async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        isLoading = true; defer { isLoading = false }
        do { sessions = try await client.listSessions(projectId: nil) }
        catch { err = "\(error)" }
    }

    private func stop(id: String) async {
        guard let client = APIClient(settings: settings) else { err = "Invalid Base URL"; return }
        do {
            try await client.delete("/v1/chat/completions/\(id)")
            await load()
        } catch { err = "\(error)" }
    }
}


⸻

Scripts/bootstrap.sh

#!/usr/bin/env bash
set -euo pipefail

echo "[bootstrap] Ensuring XcodeGen is installed…"
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  else
    echo "Homebrew not found. Install Homebrew or XcodeGen manually." >&2
    exit 1
  fi
fi

echo "[bootstrap] Generating Xcode project from Project.yml…"
xcodegen

echo "[bootstrap] Opening Xcode…"
open ClaudeCode.xcodeproj

echo "[bootstrap] Done."


⸻

Scripts/mock_sse_server.py

#!/usr/bin/env python3
import sys, time

# A very tiny SSE stub (prints HTTP headers + a few SSE lines).
sys.stdout.write("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n\r\n")
sys.stdout.flush()

lines = [
  'data: { "object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"Hello"}}] }\n',
  'data: { "object":"tool_use","id":"tu_1","name":"grep.search","input":{"pattern":"TODO","path":"src"} }\n',
  'data: { "object":"tool_result","tool_id":"tu_1","name":"grep.search","is_error":false,"duration_ms":210,"content":"src/app.ts:42 // TODO: …"}\n',
  'data: { "object":"usage","input_tokens":10,"output_tokens":23,"total_cost":0.0003 }\n',
  'data: [DONE]\n'
]

for ln in lines:
    sys.stdout.write(ln)
    sys.stdout.flush()
    time.sleep(1)


⸻

SPEC.md (concise, complete bundle overview)

# Claude Code iOS — Consolidated SPEC

## Theme (HSL tokens)
- Single dark cyberpunk palette (see `Sources/App/Theme/Theme.swift` and `Sources/App/Theme/Tokens.css`)
- Tokens: `--background, --foreground, --card, --border, --input, --primary, --secondary, --accent, --destructive, --ring, --chart-1..5, --radius`

## Navigation & IA
- **Bottom Tab Bar**: Home, Projects, Sessions, Monitor.
- Secondary: Settings (Home gear), New Session (Project Detail), MCP Settings (New Session/Chat), Diagnostics & Tracing (from Monitor/Home).
- Flow: Settings → Home → (Projects → Project Detail → New Session → Chat) or (Sessions → Chat) or (Monitor → Tracing).

## Backend & API (OpenAI-compatible)
- Chat: `POST /v1/chat/completions` (SSE via `stream=true`) • `GET /v1/chat/completions/{id}/status` • `DELETE /v1/chat/completions/{id}` • `POST /v1/chat/completions/debug`
- Models: `GET /v1/models`, `GET /v1/models/capabilities`
- Projects: `GET/POST/GET(id)/DELETE /v1/projects`
- Sessions: `GET/POST/GET(id)/DELETE /v1/sessions`, `GET /v1/sessions/stats`
- Health: `GET /health`
- MCP (proposed): `GET /v1/mcp/servers`, `GET /v1/mcp/servers/{id}/tools`, `POST /v1/sessions/{id}/tools`, and/or inline `"mcp": {...}` in chat request

## SSE vs non-SSE (UI & VM)
- **SSE**: URLSession delegate parses `data:` lines; assistant deltas append live; Tool Timeline updates live (`tool_use` / `tool_result` frames); `usage` may stream; finalize with `/status`; Stop via `DELETE`.
- **Non-SSE**: single `dataTask`; spinner until final; Tool Timeline renders after response; fetch `/status` immediately after.

## Views (primitive states & actions)
- **Settings**: baseURL, apiKey (Keychain), streaming default, SSE buffer; Validate → `/health`.
- **Home**: Quick Actions, recent projects, active sessions, KPIs (`/v1/sessions/stats`).
- **Projects**: list/search/sort; create project; tap → Project Detail.
- **Project Detail**: info + sessions for project; New Session sheet.
- **New Session**: model picker (from `/v1/models/capabilities`), title, prompt; start session → `/v1/sessions`.
- **Chat Console**: transcript + Tool Timeline; Stream toggle; Model menu; **Send** (SSE/non-SSE); **Stop**; Tool Inspector; Hyperthink pane (planner shell).
- **Files**: SSH-based listing & preview (read-only).
- **Monitoring**: SSH snapshots (CPU/MEM/NET/Disk/Top); CSV/JSON export (future).
- **Tracing**: client trace log; export NDJSON.
- **MCP Settings**: user/project defaults; tools priority; Audit Log.
- **Session Tool Picker**: per-session overrides (stored under `mcpSession.{sessionId}`).

## Data & Utilities
- **Models**: Codable types for chat, streaming chunks, projects, sessions, MCP config (see `APIClient.swift` models & Part 1 code).
- **APIClient**: GET/POST helpers; typed endpoints for health, projects, sessions, models, stats.
- **SSEClient**: raw `data:` lines → callbacks; `[DONE]` terminator.
- **SSHClient**: Shout wrapper; `runCaptureAll(_:)` merges stderr; `HostStatsService` parses CLI output → `HostSnapshot`.

## Build & Tooling
- **XcodeGen** (`Project.yml`) → reproducible project
- **SPM** deps: `swift-log`, `swift-metrics`, `swift-collections`, `LaunchDarkly/swift-eventsource` (optional), `KeychainAccess`, `Charts` (fallback), **Shout** (SSH)
- **Scripts**: `bootstrap.sh` (generate & open), `mock_sse_server.py` (SSE smoke)
- **Run**:
  ```bash
  ./Scripts/bootstrap.sh
  # Xcode opens; run "ClaudeCode" on iPhone 15 simulator

---

That's everything.  
If you want me to also inline the **ASCII wireframes** from earlier into a single `WIREFRAMES.md`, say the word and I'll paste that as well.