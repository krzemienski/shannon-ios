# Claude Code API Backend Integration Analysis

## Backend Overview
**Repository**: https://github.com/codingworkflow/claude-code-api
**Technology**: Python FastAPI-based OpenAI-compatible API gateway
**Purpose**: Provides REST API endpoints for Claude Code CLI integration

## Backend Architecture

### Core Components
1. **FastAPI Application** (`main.py`)
   - Lifespan management with async context
   - CORS middleware configuration
   - Structured logging with structlog
   - Session and Claude manager initialization

2. **API Endpoints** (`/api/`)
   - `/v1/chat/completions` - OpenAI-compatible chat endpoint
   - `/v1/models` - List available Claude models
   - `/v1/projects` - Project management
   - `/v1/sessions` - Session management

3. **Core Services** (`/core/`)
   - `claude_manager.py` - Interfaces with Claude Code CLI process
   - `session_manager.py` - Manages conversation sessions
   - `database.py` - SQLite database for persistence
   - `auth.py` - Authentication middleware
   - `config.py` - Configuration management

4. **Models** (`/models/`)
   - `openai.py` - OpenAI-compatible request/response models
   - `claude.py` - Claude-specific models and enums

5. **Utilities** (`/utils/`)
   - `streaming.py` - SSE streaming response handling
   - `parser.py` - Claude output parsing and token estimation

## iOS Integration Points

### 1. API Client Mapping
**iOS File**: `Sources/Services/APIClient.swift`
**Backend Endpoints**:
```
iOS Method                  → Backend Endpoint
createChatCompletion()     → POST /v1/chat/completions
listModels()               → GET /v1/models
createProject()            → POST /v1/projects
getProject()               → GET /v1/projects/{id}
createSession()            → POST /v1/sessions
getSession()               → GET /v1/sessions/{id}
```

### 2. Streaming Service Integration
**iOS File**: `Sources/Services/StreamingChatService.swift`
**Backend Support**: 
- Uses Server-Sent Events (SSE) format
- Streaming enabled via `"stream": true` in request
- Parses JSONL output from Claude Code CLI

### 3. Model Definitions
**iOS Models** → **Backend Models**
```swift
// iOS ChatRequest
struct ChatRequest {
    model: String
    messages: [ChatMessage]
    stream: Bool
    temperature: Float?
    maxTokens: Int?
}

// Maps to Backend ChatCompletionRequest
{
    "model": "claude-3-5-haiku-20241022",
    "messages": [...],
    "stream": true,
    "temperature": 1.0,
    "max_tokens": null,
    "project_id": null,
    "session_id": null
}
```

### 4. Supported Claude Models
Both iOS and backend must support:
- `claude-opus-4-20250514` - Most powerful
- `claude-sonnet-4-20250514` - Latest Sonnet
- `claude-3-7-sonnet-20250219` - Advanced
- `claude-3-5-haiku-20241022` - Fast & cost-effective

### 5. Authentication Flow
**Backend**: Optional auth via `require_auth` setting
**iOS**: Can pass API key in headers or use session-based auth
**Header**: `Authorization: Bearer {api_key}`

## Required Backend Modifications for iOS

### 1. Health Check Endpoint
iOS expects: `GET /health`
Backend provides: Already implemented ✅

### 2. Error Response Format
iOS expects consistent error format:
```json
{
    "error": {
        "message": "Error description",
        "type": "error_type",
        "code": "error_code"
    }
}
```

### 3. Session Management
- iOS needs persistent session support
- Backend provides session_id in responses
- Can resume conversations using session_id

### 4. Project Context
- iOS can send project_id for context
- Backend maintains project directories
- Supports workspace-aware Claude Code execution

## Integration Implementation Steps

### Phase 1: Basic Integration
1. ✅ Clone backend repository
2. ✅ Remove .git directory
3. Configure backend with iOS app requirements
4. Set up local backend server for testing

### Phase 2: API Configuration
1. Update iOS `APIConfig.swift` with backend URL
2. Configure model mappings
3. Implement error handling for backend responses
4. Add retry logic for failed requests

### Phase 3: Streaming Implementation
1. Implement SSE parsing in iOS
2. Handle streaming response chunks
3. Implement proper error handling for stream interruptions
4. Add progress tracking for long responses

### Phase 4: Session & Project Management
1. Implement session persistence in iOS
2. Add project context support
3. Implement session resume functionality
4. Add project switching capabilities

## Backend Server Requirements

### Development Setup
```bash
# Install dependencies
cd claude-code-api
make install

# Start development server
make start-dev
# Server runs at http://localhost:8000
```

### Production Configuration
- Set `ANTHROPIC_API_KEY` environment variable
- Configure `claude_binary_path` in config
- Set appropriate CORS origins
- Enable authentication if needed

## iOS Network Layer Updates Needed

### 1. Update Base URL
```swift
// In APIConfig.swift
static let baseURL = "http://localhost:8000/v1"
```

### 2. Add Streaming Support
```swift
// Implement SSE parser for streaming responses
class SSEParser {
    func parse(data: Data) -> ChatStreamEvent? {
        // Parse SSE format from backend
    }
}
```

### 3. Session Management
```swift
// Add session ID tracking
class SessionManager {
    var currentSessionId: String?
    func resumeSession(_ id: String) { }
}
```

## Testing Strategy

### 1. Backend Testing
- Run `make test` for unit tests
- Use `make test-chat` for chat endpoint testing
- Verify with curl commands from README

### 2. iOS Integration Testing
- Start backend locally
- Update iOS app to point to localhost
- Test basic chat completion
- Verify streaming responses
- Test session persistence

### 3. End-to-End Testing
- Full conversation flow
- Project context switching
- Error recovery scenarios
- Network interruption handling

## Security Considerations

1. **API Key Management**: Store securely in iOS Keychain
2. **HTTPS**: Use SSL/TLS in production
3. **Certificate Pinning**: Already implemented in iOS
4. **Rate Limiting**: Backend supports via semaphore
5. **Request Signing**: Can be added if needed

## Performance Optimizations

1. **Caching**: iOS has request/response caching
2. **Connection Pooling**: iOS limits to 6 connections per host
3. **Compression**: Enable gzip for responses
4. **Batch Requests**: iOS supports request batching
5. **Background Sessions**: iOS has background session support

## Next Steps

1. Set up backend server locally
2. Configure environment variables
3. Test backend endpoints with curl
4. Update iOS configuration
5. Implement streaming parser
6. Test end-to-end integration
7. Deploy backend to production server