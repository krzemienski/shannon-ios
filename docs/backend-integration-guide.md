# Backend API Integration Guide

## Overview

The iOS Swift application communicates with the Claude Code API Gateway, an OpenAI-compatible backend that provides access to Claude models through a RESTful API.

## Architecture

```
iOS App → HTTP/REST → Claude Code API Gateway → Claude CLI → Claude Models
```

## Backend Requirements

### Prerequisites
- Python 3.10+ installed
- Node.js/npm (for Claude CLI)
- Claude Code CLI (`npm install -g claude-code`)
- Unix-based system (macOS/Linux)

### Environment Setup
```bash
# Clone the backend repository
cd claude-code-api/

# Install Python dependencies
make install

# Verify Claude CLI is available
which claude

# Start the API server (development)
make start

# Or production mode
make start-prod
```

## API Configuration

### Base URLs
- **Local Development**: `http://localhost:8000`
- **API Endpoint**: `http://localhost:8000/v1`
- **Documentation**: `http://localhost:8000/docs`
- **Health Check**: `http://localhost:8000/health`

### Available Models
```json
{
  "models": [
    "claude-opus-4-20250514",      // Most powerful
    "claude-sonnet-4-20250514",    // Latest Sonnet
    "claude-3-7-sonnet-20250219",  // Advanced
    "claude-3-5-haiku-20241022"    // Fast & cost-effective (default)
  ]
}
```

## iOS App Configuration

### Network Configuration
```swift
// NetworkConfig.swift
struct APIConfig {
    static let baseURL = "http://localhost:8000/v1"
    static let defaultModel = "claude-3-5-haiku-20241022"
    static let timeout: TimeInterval = 300 // 5 minutes for streaming
    
    // Headers
    static let headers = [
        "Content-Type": "application/json",
        "Accept": "application/json"
    ]
}
```

### API Client Setup
```swift
// ClaudeAPIClient.swift
class ClaudeAPIClient {
    private let session = URLSession.shared
    private let baseURL = APIConfig.baseURL
    
    func checkHealth() async throws -> HealthResponse {
        let url = URL(string: "\(baseURL.replacingOccurrences(of: "/v1", with: ""))/health")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }
    
    func listModels() async throws -> ModelListResponse {
        let url = URL(string: "\(baseURL)/models")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(ModelListResponse.self, from: data)
    }
    
    func createChatCompletion(_ request: ChatRequest) async throws -> ChatResponse {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, _) = try await session.data(for: urlRequest)
        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }
}
```

## Testing Integration

### Quick Health Check
```bash
# Verify backend is running
curl -i http://localhost:8000/health

# Expected response:
{
  "status": "healthy",
  "version": "1.0.0",
  "claude_version": "1.x.x",
  "active_sessions": 0
}
```

### Test Chat Completion
```bash
# Send a test message
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-haiku-20241022",
    "messages": [
      {"role": "user", "content": "Hello from iOS!"}
    ],
    "stream": false
  }'
```

### List Available Models
```bash
curl http://localhost:8000/v1/models | jq .
```

## Error Handling

### Common Issues and Solutions

1. **Backend Not Running**
   - Error: Connection refused
   - Solution: Start backend with `make start` in claude-code-api directory

2. **Claude CLI Not Found**
   - Error: "Claude Code CLI not available"
   - Solution: Install with `npm install -g claude-code`

3. **Port Already in Use**
   - Error: Address already in use
   - Solution: `make kill PORT=8000` then restart

4. **Session Timeout**
   - Error: Request timeout
   - Solution: Increase timeout in iOS client or use streaming

## Development Workflow

### Starting Backend for iOS Development
```bash
# Terminal 1: Start backend
cd claude-code-api
make start

# Terminal 2: Monitor logs
tail -f claude_api.log

# Terminal 3: Run iOS app
cd ../
open ClaudeCodeiOS.xcodeproj
# Build and run in Xcode
```

### Switching Between Models
```swift
// In iOS app
let request = ChatRequest(
    model: "claude-sonnet-4-20250514", // Premium model
    messages: [...],
    stream: true
)
```

## Security Considerations

### Local Development
- No authentication required by default
- CORS allows all origins (`*`)
- Suitable for local development only

### Production Deployment
- Enable authentication: Set `REQUIRE_AUTH=true`
- Configure API keys: `API_KEYS=key1,key2,key3`
- Restrict CORS: `ALLOWED_ORIGINS=https://yourdomain.com`
- Use HTTPS with proper certificates

## Performance Optimization

### Streaming Responses
```swift
// Enable streaming for better UX
let request = ChatRequest(
    model: model,
    messages: messages,
    stream: true // Enable streaming
)

// Handle streaming response
for try await chunk in response.chunks {
    updateUI(with: chunk)
}
```

### Session Management
- Reuse `session_id` for conversation continuity
- Store session IDs locally for resume capability
- Clean up old sessions periodically

## Monitoring & Debugging

### Backend Logs
```bash
# View structured logs
tail -f claude_api.log | jq .

# Filter by session
tail -f claude_api.log | grep "session_id"
```

### API Documentation
- Interactive docs: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- OpenAPI spec: http://localhost:8000/openapi.json

## Next Steps

1. **Setup Backend**: Follow prerequisites and run `make install && make start`
2. **Verify Health**: Test with curl or browser
3. **Configure iOS App**: Update base URL and model settings
4. **Test Integration**: Run sample requests
5. **Implement Features**: Build chat UI with streaming support