# Current Issues and Development Priorities

## Build Status: ❌ FAILED
The app currently has 20+ compilation errors preventing it from building and launching.

## Critical Path to MVP
The main goal is to get the app compiling and running on the simulator, even with reduced functionality.

## High Priority Issues (Must Fix)

### 1. Terminal Module Issues
- **Problem**: Missing types causing most compilation errors
- **Missing Types**: `TerminalLine`, `TerminalCharacter`, `CursorPosition`
- **Solution**: Either implement missing types or temporarily disable Terminal feature
- **Files**: `Sources/Features/Terminal/`

### 2. Protocol Conformance Issues
- **QueuedRequest**: Doesn't conform to Codable
- **Various types**: Missing Sendable conformance for concurrent code
- **Solution**: Add required protocol conformances

### 3. SwiftUI Compilation Issues
- **ToolbarContent**: Protocol conformance problems in ProjectDetailView
- **Solution**: Fix or simplify toolbar implementations

### 4. Actor Isolation Issues
- **RASPManager**: Actor isolation conflicts
- **RequestPrioritizer**: Concurrency issues
- **Solution**: Add `@unchecked Sendable` or refactor for proper actor isolation

## Recommended Fix Strategy

### Phase 1: Get It Compiling (Priority)
1. Comment out or stub Terminal module
2. Add minimal protocol conformances
3. Simplify complex SwiftUI views
4. Fix Sendable conformance issues

### Phase 2: Core Functionality
1. Ensure chat interface works
2. Verify API connectivity
3. Test basic project management
4. Validate authentication flow

### Phase 3: Advanced Features
1. Re-enable Terminal if needed
2. Add monitoring and telemetry
3. Implement tool system
4. Polish UI and animations

## DO NOT Focus On (Yet)
- Unit tests (get it running first)
- Performance optimization
- Perfect code quality
- Comprehensive error handling
- Advanced features (SSH, Terminal)
- App Store preparation

## Quick Win Opportunities
1. Use stub implementations for missing types
2. Temporarily disable non-critical features
3. Focus on chat functionality (core feature)
4. Use simple UI instead of complex components

## Build Command Reminder
**ALWAYS USE**: `./Scripts/simulator_automation.sh all`
**NEVER USE**: Direct xcodebuild or xcrun commands

## Environment Details
- Simulator: iPhone 16 Pro Max (iOS 18.6)
- UUID: 50523130-57AA-48B0-ABD0-4D59CE455F14
- Bundle ID: com.claudecode.ios
- Xcode: 15.0+
- Swift: 5.9+
- iOS Target: 17.0+

## Task Master Integration
Use Task Master to track progress:
- `task-master next` - Get next task
- `task-master show <id>` - View details
- `task-master set-status --id=<id> --status=done` - Complete task

## Success Criteria
The app is considered "working" when:
1. It builds without errors
2. It launches on the simulator
3. The main chat interface is visible
4. Basic navigation works
5. Can send/receive messages (even if mocked)