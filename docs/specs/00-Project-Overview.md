# Claude Code iOS — Project Overview

This bundle contains the **complete specification** for a native SwiftUI iOS client that interacts with a Claude Code–compatible backend (OpenAI-style endpoints with streaming chat, sessions, models, projects). It also includes **MCP (Model Context Protocol)** configuration for enabling project/user-scoped tool servers per session.

All files are cross-referenced and mapped to **wireframe IDs (WF-01 … WF-11)**.

---

## File Index

- **01-Backend-API.md** — Full backend surface, request/response schemas, SSE streaming, error model, auth, rate limits, examples.
- **02-Swift-Data-Models.md** — Complete Swift `Codable` models (chat, models, projects, sessions, status, errors) + MCP structs and helpers.
- **03-Screens-API-Mapping.md** — Each app screen with its purpose, data dependencies, user actions, endpoint calls (curl + Swift), and error handling. Wireframe references included.
- **04-Theming-Typography.md** — Cyberpunk/dark design tokens, typography scale, component guidelines, motion, accessibility.
- **05-Wireframes.md** — ASCII/Markdown wireframes for all core screens (WF-01 … WF-10). (WF‑11 lives in the MCP spec below.)
- **06-MCP-Configuration-Tools.md** — End-to-end MCP UX and API: discovery, configuration, per-session tool selection; adds WF‑10 and WF‑11.

---

## Recommended Reading Order

1. **01 Backend & API** → Understand the service surface and contracts.
2. **02 Swift Data Models** → See how the iOS client structures map to the API (snake_case→camelCase).
3. **03 Screens & API Mapping** → Implement each UI surface with precise calls and flows.
4. **05 Wireframes** → Keep layouts, density, and control placement aligned to WF IDs.
5. **04 Theming & Typography** → Apply consistent visuals across screens and states.
6. **06 MCP Configuration & Tools** → Layer in MCP server & tool activation for advanced use.

---

## Environments

- **Base URL** (example): `http://localhost:8000`
- **Auth**: `Authorization: Bearer <token>` or `x-api-key: <key>` (if enabled on your server)
- **Streaming**: SSE for `POST /v1/chat/completions` with `stream=true`

---

## Glossary

- **Session**: A stateful chat context for a project/model; returns usage and status.
- **Project**: A logical workspace (optionally maps to a filesystem path on the server host).
- **MCP**: Model Context Protocol—servers that expose tools like `fs.read`, `bash.run`, etc.
- **SSE**: Server-Sent Events; streaming text/event-stream used for incremental assistant deltas.

---

## Wireframe Index

- **WF‑01** Settings (Onboarding)
- **WF‑02** Home (Command Center)
- **WF‑03** Projects List
- **WF‑04** Project Detail
- **WF‑05** New Session
- **WF‑06** Chat Console
- **WF‑07** Models Catalog
- **WF‑08** Analytics
- **WF‑09** Diagnostics
- **WF‑10** MCP Configuration (also referenced from MCP spec)
- **WF‑11** Session Tool Picker (in MCP spec)

---

## Change Log

- **v1 (Aug 20, 2025)**: Initial full spec set with MCP support, expanded examples, and complete wireframes.
