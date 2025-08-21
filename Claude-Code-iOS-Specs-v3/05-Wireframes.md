# Claude Code iOS Spec — 05 Wireframes

This document provides wireframe sketches (described in Markdown + ASCII/mermaid diagrams) for each major screen of the Claude Code iOS app. Other spec docs should reference these wireframe numbers.

---

## WF-01: Settings (Onboarding)
```
+--------------------------------------+
| Claude Code — Setup                  |
+--------------------------------------+
| Base URL: [___________________]      |
| API Key:  [***************]          |
|                                      |
| [ Validate Connection ]              |
+--------------------------------------+
| Status: Claude vX.Y, sessions=3      |
+--------------------------------------+
```
**References**: Backend & API §1, Screens & API Mapping §1

---

## WF-02: Home (Command Center)
```
+---------------------------------------------------+
| Quick Actions: [ New Project ] [ New Session ]    |
+---------------------------------------------------+
| Recent Projects                                   |
|  - Project A  (updated 2h ago)                    |
|  - Project B  (yesterday)                         |
+---------------------------------------------------+
| Active Sessions                                   |
|  - Session #abc  Claude-3  Running                |
|  - Session #xyz  Ended                            |
+---------------------------------------------------+
| KPIs: Active=2  Tokens=12,340  Cost=$0.12         |
+---------------------------------------------------+
```
**References**: Backend & API §2, Screens & API Mapping §2

---

## WF-03: Projects List
```
+---------------- Projects ----------------+
| [ + Create Project ]                     |
+------------------------------------------+
| Project Name       | Last Updated        |
|------------------------------------------|
| My Repo Analyzer   | Aug 18 2025         |
| iOS Client Build   | Aug 17 2025         |
+------------------------------------------+
```
**References**: Backend & API §3, Screens & API Mapping §3

---

## WF-04: Project Detail
```
+------------- Project Detail -------------+
| Project: My Repo Analyzer                |
| Desc: Demo test project                  |
| Path: /Users/nick/code                   |
+------------------------------------------+
| Sessions (related)                       |
| - Session 1: Claude-3, Active            |
| - Session 2: Claude-3.5, Ended           |
| [ + New Session ]                        |
+------------------------------------------+
```
**References**: Backend & API §3.4, Screens & API Mapping §4

---

## WF-05: New Session
```
+------------- New Session ----------------+
| Select Model: [ Claude-3-Haiku ▼ ]       |
| System Prompt: [____________________]    |
| Title (optional): [Session title]        |
|                                          |
| MCP Servers: [ Choose Servers ▼ ]        |
|                                          |
| [ Start Session ]                        |
+------------------------------------------+
```
**References**: Backend & API §3.5, Screens & API Mapping §5, MCP Config §1

---

## WF-06: Chat Console
```
+---------------- Chat Console ------------+
| Transcript (scrollable):                 |
|  [User]: Hello Claude                    |
|  [Claude]: Hi, how can I help?           |
|  [ToolUse]: grep("foo")                  |
|  [ToolResult]: lines found=3             |
+------------------------------------------+
| Tool Timeline  | Usage                   |
| - grep foo ok  | Tokens=320              |
| - edit file    | Cost=$0.01              |
+------------------------------------------+
| MCP Controls:                            |
| - Active Servers: [ServerA] [ServerB]    |
| - Toggle: [x] Use ServerA                |
|                                          |
| [Input: _____________________ ] [Send]   |
| (Streaming on ▣ Stop)                    |
+------------------------------------------+
```
**References**: Backend & API §3.6, Screens & API Mapping §6, MCP Config §2

---

## WF-07: Models Catalog
```
+--------------- Models -------------------+
| Claude-3-Haiku    | max_tokens=200k      |
| Claude-3.5-Opus   | max_tokens=1M        |
| Claude-3-Sonnet   | max_tokens=500k      |
+------------------------------------------+
| [ Tap for details → capabilities ]       |
+------------------------------------------+
```
**References**: Backend & API §3.7, Screens & API Mapping §7

---

## WF-08: Analytics
```
+--------------- Analytics ----------------+
| Active Sessions: 4                       |
| Tokens Used: 43,000                      |
| Cost: $0.58                              |
+------------------------------------------+
| [ Chart: Tokens over time ]              |
| [ Chart: Cost per model ]                |
+------------------------------------------+
```
**References**: Backend & API §3.8, Screens & API Mapping §8

---

## WF-09: Diagnostics
```
+------------- Diagnostics ----------------+
| Log Stream:                              |
| [12:02:33] POST /v1/chat OK 200          |
| [12:02:34] SSE line received             |
| [12:02:35] Error: invalid token          |
+------------------------------------------+
| [ Debug Request ]                        |
+------------------------------------------+
```
**References**: Backend & API §3.9, Screens & API Mapping §9

---

## WF-10: MCP Configuration
```
+---------- MCP Configuration -------------+
| Available Servers                        |
| - Server A (project scope) [Enable]      |
| - Server B (user scope) [Enable]         |
|                                          |
| [ Refresh List ] [ Add Custom Server ]   |
+------------------------------------------+
| Notes: Enabled servers appear in chats.  |
+------------------------------------------+
```
**References**: MCP Config §1, §2

---

## Notes
- Wireframes are intentionally minimal and dark-mode first.
- Actual app will apply theming (see Theming & Typography doc).
- All other docs should reference wireframe IDs (WF-01 … WF-10).
