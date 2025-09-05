# Backend to iOS File Mapping

## Critical Backend Files and iOS Counterparts

### 1. API Endpoints
```
Backend                                     → iOS
claude_code_api/api/chat.py               → Sources/Services/StreamingChatService.swift
                                          → Sources/Services/APIClient+Streaming.swift
                                          → Sources/ViewModels/ChatViewModel.swift

claude_code_api/api/models.py             → Sources/Models/ChatModels.swift
                                          → Sources/Core/Configuration/APIConfig.swift

claude_code_api/api/projects.py           → Sources/ViewModels/ProjectsViewModel.swift
                                          → Sources/Models/ProjectModels.swift

claude_code_api/api/sessions.py           → Sources/Core/State/ChatStore.swift
                                          → Sources/Services/SessionManager.swift (needs creation)
```

### 2. Data Models
```
Backend                                     → iOS
claude_code_api/models/openai.py          → Sources/Models/ChatModels.swift
  - ChatMessage                            → ChatMessage
  - ChatCompletionRequest                  → ChatRequest
  - ChatCompletionResponse                 → ChatResponse
  - ChatCompletionChoice                   → ChatChoice
  - ErrorResponse                          → APIError

claude_code_api/models/claude.py          → Sources/Models/ClaudeModels.swift (needs creation)
  - ClaudeModel enum                       → ClaudeModel
  - ClaudeMessageType                      → MessageType
  - ClaudeToolType                         → ToolType
  - ClaudeSessionInfo                      → SessionInfo
```

### 3. Core Services
```
Backend                                     → iOS
claude_code_api/core/claude_manager.py    → (No direct equivalent - backend only)
                                          → Interfaces via APIClient.swift

claude_code_api/core/session_manager.py   → Sources/Services/SessionManager.swift (needs creation)
                                          → Sources/Core/State/ChatStore.swift

claude_code_api/core/auth.py              → Sources/Security/AuthenticationManager.swift
                                          → Sources/Services/KeychainService.swift

claude_code_api/core/config.py            → Sources/Core/Configuration/APIConfig.swift
                                          → Sources/Core/Configuration/AppConfig.swift

claude_code_api/core/database.py          → Sources/Core/Persistence/CoreDataManager.swift
                                          → (Different approach - iOS uses Core Data)
```

### 4. Utilities
```
Backend                                     → iOS
claude_code_api/utils/streaming.py        → Sources/Services/APIClient+Streaming.swift
  - create_sse_response()                  → StreamingResponse handler
  - parse_claude_output()                   → SSEParser (needs creation)

claude_code_api/utils/parser.py           → Sources/Utils/ResponseParser.swift (needs creation)
  - ClaudeOutputParser                      → ClaudeResponseParser
  - estimate_tokens()                       → TokenEstimator
```

## New iOS Files Needed

### 1. Session Management
**File**: `Sources/Services/SessionManager.swift`
```swift
class SessionManager {
    var currentSessionId: String?
    var projectId: String?
    
    func createSession(projectId: String?) async throws -> SessionInfo
    func resumeSession(sessionId: String) async throws -> SessionInfo
    func endSession() async throws
}
```

### 2. Claude Models
**File**: `Sources/Models/ClaudeModels.swift`
```swift
enum ClaudeModel: String, CaseIterable {
    case opus4 = "claude-opus-4-20250514"
    case sonnet4 = "claude-sonnet-4-20250514"
    case sonnet37 = "claude-3-7-sonnet-20250219"
    case haiku35 = "claude-3-5-haiku-20241022"
}

enum ClaudeToolType: String {
    case bash, edit, read, write, ls, grep, glob
    case todoWrite = "todowrite"
    case multiEdit = "multiedit"
}
```

### 3. SSE Parser
**File**: `Sources/Utils/SSEParser.swift`
```swift
class SSEParser {
    func parse(data: Data) -> StreamEvent?
    func parseJSONL(line: String) -> ChatStreamChunk?
}
```

### 4. Response Parser
**File**: `Sources/Utils/ResponseParser.swift`
```swift
class ClaudeResponseParser {
    func parseToolUse(from json: [String: Any]) -> ToolUse?
    func parseUsageMetrics(from json: [String: Any]) -> UsageMetrics?
    func estimateTokens(for text: String) -> Int
}
```

## Backend Files to Copy/Adapt

### 1. Configuration Constants
From: `claude_code_api/core/config.py`
To: Update `Sources/Core/Configuration/APIConfig.swift`
- Model definitions
- Timeout values
- Rate limiting settings
- Cache configuration

### 2. Error Definitions
From: `claude_code_api/models/openai.py` (ErrorResponse)
To: Update `Sources/Models/APIError.swift`
- Error codes
- Error types
- Error messages

### 3. Streaming Logic
From: `claude_code_api/utils/streaming.py`
To: Enhance `Sources/Services/APIClient+Streaming.swift`
- SSE formatting
- Chunk handling
- Stream termination

## Backend Dependencies for iOS

### Required Backend Services Running:
1. **Claude Code CLI** - Must be installed on backend server
2. **FastAPI Server** - Running on port 8000
3. **SQLite Database** - For session persistence

### Backend Environment Variables:
```bash
ANTHROPIC_API_KEY=your_key_here
CLAUDE_BINARY_PATH=/usr/local/bin/claude
PROJECT_ROOT=/path/to/projects
DATABASE_URL=sqlite:///claude_code.db
```

## iOS Configuration Updates

### 1. Update APIConfig.swift
```swift
struct APIConfig {
    static let baseURL = "http://localhost:8000/v1"  // Development
    // static let baseURL = "https://api.claude-code.com/v1"  // Production
    
    static let supportedModels = [
        "claude-opus-4-20250514",
        "claude-sonnet-4-20250514",
        "claude-3-7-sonnet-20250219",
        "claude-3-5-haiku-20241022"
    ]
}
```

### 2. Update Info.plist for Local Development
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## Integration Testing Checklist

- [ ] Backend server starts successfully
- [ ] Health endpoint responds: `GET /health`
- [ ] Models endpoint returns list: `GET /v1/models`
- [ ] Chat completion works: `POST /v1/chat/completions`
- [ ] Streaming responses work with `stream: true`
- [ ] Session creation and persistence
- [ ] Project context switching
- [ ] Error handling for network failures
- [ ] Authentication flow (if enabled)
- [ ] Rate limiting behavior
- [ ] Cache functionality
- [ ] Background session support

## File Priority for Implementation

### Phase 1: Core Integration (Required)
1. Update `APIConfig.swift` with backend URL
2. Create `ClaudeModels.swift` for model definitions
3. Create `SSEParser.swift` for streaming
4. Update `APIClient.swift` with new endpoints

### Phase 2: Session Management
1. Create `SessionManager.swift`
2. Update `ChatStore.swift` for session tracking
3. Implement session resume in `ChatViewModel.swift`

### Phase 3: Advanced Features
1. Create `ResponseParser.swift` for tool parsing
2. Implement project context in `ProjectsViewModel.swift`
3. Add background session support
4. Implement request batching

## Notes

- Backend uses Python asyncio, iOS uses Swift async/await - patterns are similar
- Backend stores sessions in SQLite, iOS can use Core Data or UserDefaults
- Backend runs Claude Code CLI as subprocess, iOS communicates via API only
- Streaming uses SSE format in both, but parsing implementation differs
- Error handling patterns are similar but error types need mapping