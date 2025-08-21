# Claude Code iOS Spec — 06 MCP Configuration & Tools

**Purpose**: Provide a first‑class **MCP (Model Context Protocol)** experience so users can discover, configure, enable/disable, and prioritize **MCP servers** and their **tools** at both **user** and **project** scope, and selectively activate subsets per **session**.

Includes wireframes **WF‑10** (MCP Settings) and **WF‑11** (Session Tool Picker).

---

## 1) Concepts & Scope

- **MCP Server**: A process that exposes a catalog of tools (read/write/grep/glob/bash/etc.) with metadata and permissions. Servers can be installed globally (user scope) or bound to a project (project scope).
- **MCP Tool**: A callable action (e.g., `fs.read`, `fs.write`, `bash.run`) with input schema and streaming flags.
- **Scopes**:
  - **User Scope**: MCP servers for all projects (e.g., `~/.config/mcp/servers.d`).
  - **Project Scope**: MCP servers declared in repo (e.g., `./.mcp/servers.d`).
- **Session Activation**: Per chat session, choose **which servers/tools** are available to the assistant.

---

## 2) Backend Endpoints (Proposed)

### 2.1 Discover Servers
`GET /v1/mcp/servers?scope=user|project&project_id=...`

**Response**
```json
{
  "servers": [
    { "id":"fs-local","name":"Local Filesystem","scope":"project","executable":"/usr/local/bin/mcp-fs","version":"1.3.0","status":"available" },
    { "id":"bash","name":"Bash","scope":"user","executable":"/usr/local/bin/mcp-bash","version":"0.9.2","status":"available" }
  ]
}
```

### 2.2 List Tools for a Server
`GET /v1/mcp/servers/{server_id}/tools?project_id=...`

**Response**
```json
{
  "server_id": "fs-local",
  "tools": [
    {
      "name":"fs.read",
      "title":"Read File",
      "description":"Read a file from workspace",
      "input_schema":{"type":"object","properties":{"path":{"type":"string"}}},
      "supports_stream":false,"dangerous":false
    }
  ]
}
```

### 2.3 Configure Session Tooling
`POST /v1/sessions/{session_id}/tools`

**Request**
```json
{
  "enabled_servers": ["fs-local","bash"],
  "enabled_tools": ["fs.read","fs.write","bash.run"],
  "priority": ["fs.read","bash.run"],
  "audit_log": true
}
```
**Response**
```json
{ "ok": true }
```

> Alternative: pass the same structure inline in `POST /v1/chat/completions` under `mcp{...}`.

---

## 3) Swift Models (Additions)

See **02‑Swift‑Data‑Models.md** for `MCPServer`, `MCPTool`, `MCPConfig`.


---

## 4) UX Flows

### 4.1 Global MCP Settings — **WF‑10**
- **Data**: `GET /v1/mcp/servers` (user + project), then `GET /v1/mcp/servers/{id}/tools`
- **Actions**: Enable/disable servers; select tools; reorder **priority**; toggle **Audit Log**.
- **Storage**: Save **defaults** at user scope and per‑project overrides.
- **Merge Order on Session Start**: `session > project > user`.

### 4.2 Session Tool Picker — **WF‑11**
- **Placement**: New Session sheet and Chat → Session menu → “Tools for this Session”
- **Data**: Pre-populates from defaults; loads latest servers/tools.
- **Actions**: Select enabled servers/tools; reorder priority; toggle Audit Log; **Apply** to session via inline `mcp{...}` or `POST /v1/sessions/{id}/tools`.

### 4.3 Chat Console Enhancements
- **Tool Timeline** shows `server_id` and `tool` names; error badges for `is_error=true`.
- **Status** panel displays active servers/tools; **Audit Log** filter toggles only tool events.

---

## 5) Analytics & Diagnostics

- Charts: **tool invocation counts**, **errors by tool**, **latency by server**.
- Diagnostics: “Test Tool Call” invoking `/v1/chat/completions/debug` with synthetic tool events.

---

## 6) Wireframes

### **WF‑10: MCP Settings** (see 05‑Wireframes)
(Shared reference; implemented in that doc.)

### **WF‑11: Session Tool Picker**
```
+-------------- Tools for This Session --------------+
| Use defaults from: ( User • Project • None )       |
+---------------------------------------------------+
| Enabled Servers                                    |
| [✓] fs-local       [ Configure ]                   |
| [✓] bash           [ Configure ]                   |
| [ ] web-scraper                                     |
+---------------------------------------------------+
| Enabled Tools (tap to toggle)                      |
|  fs.read  fs.write  bash.run  grep.search          |
+---------------------------------------------------+
| Priority (drag to reorder)                         |
|  1) fs.read   2) bash.run   3) fs.write           |
+---------------------------------------------------+
|            [ Cancel ]   [  Save & Apply  ]         |
+---------------------------------------------------+
```

---

## 7) QA Checklist

1. Discovery returns user/project scoped servers distinctly.
2. Tools list handles missing `input_schema` gracefully.
3. Session picker persists and appears in **status**.
4. Audit Log toggles tool-only filter in timeline.
5. Priority affects tool selection order where applicable.
6. Missing server after selection → warn and degrade gracefully.

---

## 8) Security Notes

- Confirm dangerous tools (e.g., `bash.run`) with a one-time dialog per session.
- Record structured audit entries: `{ts, session_id, server, tool, args_hash, duration_ms, ok, error?}`.
