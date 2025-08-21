# Claude Code iOS - Custom Instructions & Operational Rules
## Execution Framework for ClaudeCode iOS Development

---

# BACKEND REQUIREMENTS

## Claude Code API Gateway
- **MANDATORY**: Backend must be running before iOS development
- **Location**: `claude-code-api/` directory
- **Start Command**: `make start` (development) or `make start-prod` (production)
- **Base URL**: `http://localhost:8000/v1` (NOT localhost:11434)
- **Health Check**: `curl http://localhost:8000/health`
- **Prerequisites**: Python 3.10+, Claude CLI (`npm install -g claude-code`)

# CORE OPERATIONAL PRINCIPLES

## 1. SEQUENTIAL THINKING PROTOCOL
- **Always** process tasks in order unless dependencies dictate otherwise
- **Never** skip ahead without completing prerequisites
- **Document** every decision and implementation detail
- **Validate** each step before proceeding to the next
- **Verify** backend is running before any API-related tasks

## 2. BUILD-TEST CYCLE DISCIPLINE
- **Build** after implementing 2-4 related tasks
- **Test** immediately upon encountering any error
- **Log** all build outputs and test results
- **Fix** issues before proceeding to new tasks

## 3. EVIDENCE-BASED DEVELOPMENT
- **Screenshot** UI implementations for validation
- **Log** all API responses and SSE events
- **Measure** performance metrics at each checkpoint
- **Document** all architectural decisions with rationale

---

# EXECUTION RULES

## Rule 1: Task Management
```
BEFORE starting any task:
1. Check prerequisites are complete
2. Read relevant documentation
3. Understand the specification
4. Plan the implementation approach

DURING task execution:
1. Follow SwiftUI best practices
2. Use proper error handling
3. Implement logging at key points
4. Write descriptive comments

AFTER completing task:
1. Build and verify no errors
2. Test the implementation
3. Update documentation
4. Commit with descriptive message
```

## Rule 2: API Integration Protocol
```
FOR EVERY API endpoint:
1. Read the OpenAI-compatible spec
2. Implement request/response models
3. Add proper error handling
4. Include retry logic
5. Log all requests/responses
6. Test with mock data first
7. Test with real backend
8. Handle edge cases
9. Document usage examples
```

## Rule 3: SSE Implementation Guidelines
```
WHEN implementing SSE:
1. Use URLSession with stream delegate
2. Handle partial chunks properly
3. Parse "data:" lines correctly
4. Process different event types
5. Handle [DONE] signal
6. Implement reconnection logic
7. Add timeout handling
8. Test with mock SSE server
9. Validate with real backend
```

## Rule 4: UI Development Standards
```
FOR EACH View:
1. Start with basic structure
2. Apply HSL theme tokens
3. Implement state management
4. Add user interactions
5. Include loading states
6. Handle error states
7. Add accessibility labels
8. Test on multiple devices
9. Optimize performance
10. Document usage
```

## Rule 5: State Management Rules
```
ALWAYS:
- Use @StateObject for owned objects
- Use @ObservedObject for passed objects
- Use @EnvironmentObject sparingly
- Keep view models focused
- Implement proper initialization
- Handle memory management
- Avoid retain cycles
- Test state transitions
```

---

# DEVELOPMENT WORKFLOW

## Phase 0: Setup (Tasks 001-100)
```swift
// Priority: Environment first, then research
1. Set up development environment completely
2. Install all required tools
3. Research each technology thoroughly
4. Document findings in memory (MCP)
5. Create architecture diagrams
```

## Phase 1: Foundation (Tasks 101-300)
```swift
// Priority: Structure → Theme → Models → Utilities
1. Generate project with XcodeGen
2. Implement complete theme system
3. Create all data models
4. Build utility functions
5. Set up settings management
```

## Phase 2: Networking (Tasks 301-500)
```swift
// Priority: APIClient → SSE → Endpoints → SSH
1. Build robust APIClient
2. Implement SSE streaming
3. Create all API methods
4. Integrate SSH client
```

## Phase 3: UI Implementation (Tasks 501-750)
```swift
// Priority: Components → Views → Chat → Timeline
1. Create reusable components
2. Implement all main views
3. Build chat console
4. Create tool timeline
```

## Phase 4: Monitoring (Tasks 751-850)
```swift
// Priority: SSH monitoring → Telemetry
1. Implement SSH monitoring
2. Add telemetry system
3. Create analytics
```

## Phase 5: Testing (Tasks 851-950)
```swift
// Priority: Unit tests → Integration → UI tests
1. Achieve 80% code coverage
2. Test all integrations
3. Complete UI test suite
```

## Phase 6: Deployment (Tasks 951-1000)
```swift
// Priority: Build config → Documentation → Release
1. Configure release settings
2. Create documentation
3. Prepare for App Store
```

---

# TECHNICAL SPECIFICATIONS

## API Configuration
```swift
struct APIConfig {
    static let baseURL = "http://localhost:8000/v1" // Claude Code API Gateway
    static let productionURL = "https://api.claudecode.com" // Production
    static let timeout: TimeInterval = 30
    static let retryCount = 3
    static let sseBufferSize = 4096
    static let defaultModel = "claude-3-5-haiku-20241022"
}
```

## Theme Tokens (HSL)
```swift
enum Theme {
    static let background = Color(hsl: 240, 10, 5)    // Dark background
    static let foreground = Color(hsl: 0, 0, 95)      // Light text
    static let card = Color(hsl: 240, 10, 8)          // Card background
    static let border = Color(hsl: 240, 10, 20)       // Borders
    static let primary = Color(hsl: 142, 70, 45)      // Primary green
    static let accent = Color(hsl: 280, 70, 50)       // Purple accent
}
```

## Model Structure
```swift
// Follow Codable protocol for all models
struct ChatRequest: Codable {
    let model: String
    let messages: [Message]
    let stream: Bool
    let temperature: Double?
    let mcp: MCPConfig?
}
```

## SSE Event Types
```
data: {"object": "chat.completion.chunk", "choices": [...]}
data: {"object": "tool_use", "id": "...", "name": "...", "input": {...}}
data: {"object": "tool_result", "tool_id": "...", "content": "..."}
data: {"object": "usage", "input_tokens": N, "output_tokens": N}
data: [DONE]
```

---

# VALIDATION CHECKPOINTS

## Every 10 Tasks
```bash
# First verify backend is running:
curl -s http://localhost:8000/health | jq .
# If not running, start it:
cd claude-code-api && make start

# Then run iOS build commands:
xcodebuild -project ClaudeCode.xcodeproj -scheme ClaudeCode build
swiftlint
git status
git add .
git commit -m "Complete tasks XXX-XXX: [description]"

# Test API integration:
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-3-5-haiku-20241022", "messages": [{"role": "user", "content": "test"}], "stream": false}'
```

## Every 50 Tasks
```bash
# Performance profiling:
instruments -t "Time Profiler" ClaudeCode.app
instruments -t "Leaks" ClaudeCode.app

# Generate test coverage:
xcodebuild test -scheme ClaudeCode -enableCodeCoverage YES
```

## Every Phase
```bash
# Full validation:
1. Run all unit tests
2. Run all UI tests
3. Profile memory usage
4. Check for memory leaks
5. Validate accessibility
6. Test on physical device
7. Review security
8. Update documentation
```

---

# MEMORY & STATE MANAGEMENT

## Using Memory MCP
```
STORE in memory:
- Architecture decisions
- API response examples
- Error patterns encountered
- Performance baselines
- Test results
- Bug fixes applied
- Configuration changes
```

## Session State
```
MAINTAIN across sessions:
- Current task number
- Completed tasks list
- Known issues
- Test failures
- Performance metrics
- Build configurations
```

---

# ERROR HANDLING PATTERNS

## Network Errors
```swift
enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(Int)
    case timeout
    case noConnection
}

// Always provide recovery suggestions
```

## UI Error States
```swift
struct ErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
            Text(error.localizedDescription)
            Button("Retry", action: retry)
        }
    }
}
```

---

# TESTING REQUIREMENTS

## Unit Test Coverage
- Minimum 80% code coverage
- Test all public methods
- Test error conditions
- Test edge cases
- Mock external dependencies

## Integration Tests
- Test API endpoints with mock server
- Test SSE streaming with mock events
- Test SSH connections with test server
- Test data persistence
- Test state management

## UI Tests
- Test all user flows
- Test error handling
- Test loading states
- Test device rotations
- Test accessibility

---

# DOCUMENTATION STANDARDS

## Code Comments
```swift
/// Processes incoming SSE events and updates the message stream
/// - Parameters:
///   - data: Raw SSE data from the server
///   - completion: Callback with parsed event or error
/// - Throws: `SSEError.invalidFormat` if data cannot be parsed
func processSSEData(_ data: Data, completion: @escaping (Result<SSEEvent, Error>) -> Void) throws {
    // Implementation
}
```

## README Sections
1. Project Overview
2. Architecture
3. Setup Instructions
4. API Documentation
5. Testing Guide
6. Deployment Process
7. Troubleshooting
8. Contributing Guidelines

---

# PERFORMANCE TARGETS

## App Launch
- Cold start: < 2 seconds
- Warm start: < 0.5 seconds
- First meaningful paint: < 1 second

## UI Responsiveness
- Touch response: < 100ms
- Animation FPS: 60fps
- Scroll performance: No drops below 55fps
- List rendering: < 16ms per frame

## Memory Usage
- Baseline: < 50MB
- Active chat: < 100MB
- With monitoring: < 150MB
- Memory leaks: Zero tolerance

## Network Performance
- API requests: < 500ms (local)
- SSE latency: < 100ms per event
- Reconnection: < 2 seconds
- Retry backoff: Exponential

---

# SECURITY REQUIREMENTS

## API Keys
- Store in Keychain only
- Never log or display
- Validate before use
- Clear on logout

## Network Security
- Use HTTPS in production
- Validate SSL certificates
- Implement certificate pinning (future)
- No sensitive data in URLs

## Data Protection
- Encrypt sensitive data at rest
- Clear memory after use
- No screenshots of sensitive info
- Implement data purge

---

# ACCESSIBILITY REQUIREMENTS

## VoiceOver Support
- All interactive elements labeled
- Meaningful descriptions
- Proper navigation order
- Announce state changes

## Visual Accessibility
- Support Dynamic Type
- Minimum contrast ratios
- Respect Reduce Motion
- Support color blind modes

## Interaction
- Minimum touch targets: 44x44pt
- Keyboard navigation support
- Voice Control compatible
- Switch Control support

---

# GIT WORKFLOW

## Branch Strategy
```bash
main              # Production-ready code
├── develop       # Integration branch
├── feature/*     # Feature branches
├── bugfix/*      # Bug fix branches
└── release/*     # Release preparation
```

## Commit Messages
```
feat: Add SSE streaming support
fix: Resolve memory leak in chat view
docs: Update API documentation
test: Add unit tests for APIClient
refactor: Simplify state management
perf: Optimize list rendering
style: Apply SwiftLint rules
```

---

# MONITORING & LOGGING

## Log Levels
```swift
enum LogLevel {
    case verbose  // Development only
    case debug    // Detailed debugging
    case info     // General information
    case warning  // Potential issues
    case error    // Errors that need attention
    case critical // App-breaking issues
}
```

## Telemetry Events
```swift
// Track these events:
- App launch
- Screen views
- API requests
- SSE connections
- Tool usage
- Errors
- Performance metrics
- User actions
```

---

# DEPLOYMENT CHECKLIST

## Pre-Release
- [ ] All tests passing
- [ ] No memory leaks
- [ ] Performance targets met
- [ ] Security audit passed
- [ ] Accessibility verified
- [ ] Documentation complete
- [ ] Release notes written
- [ ] Screenshots updated

## Post-Release
- [ ] Monitor crash reports
- [ ] Track user feedback
- [ ] Analyze usage metrics
- [ ] Plan improvements
- [ ] Update roadmap

---

# SUCCESS CRITERIA

## MVP Requirements
✅ Connect to OpenAI-compatible API
✅ Stream chat responses via SSE
✅ Display tool usage timeline
✅ Show token usage and costs
✅ Manage projects and sessions
✅ Configure MCP tools
✅ SSH monitoring capability
✅ Dark cyberpunk theme
✅ iOS 17+ compatibility

## Quality Metrics
✅ < 0.1% crash rate
✅ > 4.5 App Store rating
✅ < 2 second load time
✅ > 99% API success rate
✅ Zero security vulnerabilities

---

# FINAL NOTES

1. **Always prioritize user experience over perfect code**
2. **Ship iteratively - get feedback early and often**
3. **Test on real devices, not just simulators**
4. **Document decisions for future reference**
5. **Keep the code maintainable and readable**
6. **Follow iOS Human Interface Guidelines**
7. **Respect user privacy and data**
8. **Make the app accessible to everyone**
9. **Monitor performance continuously**
10. **Celebrate milestones and learn from mistakes!**

---

Generated from ClaudeCode_iOS_SPEC_consolidated_v1.md
Ready for disciplined execution with continuous validation!