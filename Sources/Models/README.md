# Claude Code iOS Models

## Overview

This directory contains all data models for the Claude Code iOS application, implementing Tasks 161-200 from TASK_PLAN.md.

## Architecture

The models follow these architectural principles:
- **Codable Protocol**: All models implement Codable for JSON serialization
- **OpenAI Compatibility**: Chat models are OpenAI-compatible with Claude extensions
- **Validation**: Comprehensive validation logic with typed errors
- **Factory Methods**: Convenient constructors for common configurations
- **UI Extensions**: Display helpers for SwiftUI integration

## Directory Structure

```
Models/
├── Network/              # API request/response models
│   ├── ChatModels.swift         # Chat completion models (Tasks 162-165)
│   ├── CoreModels.swift         # Core API models (Tasks 168-169, 173-175)
│   ├── MCPModels.swift          # MCP configuration (Tasks 181-183)
│   ├── MonitoringModels.swift   # Monitoring & telemetry (Tasks 186, 189-196)
│   ├── ProjectModels.swift      # Project management (Task 166)
│   ├── SessionModels.swift      # Session management (Task 167)
│   ├── SSHModels.swift          # SSH configuration (Tasks 184-185)
│   └── ToolModels.swift         # Tool/function models (Tasks 170-172)
│
└── Extensions/           # Model enhancements
    ├── ModelExtensions.swift     # UI display helpers (Task 176)
    ├── ModelFactories.swift      # Factory methods (Task 178)
    ├── ModelTestUtilities.swift  # Test utilities (Task 179)
    └── ModelValidation.swift     # Validation logic (Task 177)
```

## Key Models

### Chat Models
- `ChatCompletionRequest`: OpenAI-compatible chat request
- `ChatCompletionResponse`: Chat completion response
- `ChatCompletionChunk`: Streaming response chunk
- `ChatMessage`: Individual message with role and content
- `ChatTool`: Tool/function definition

### Project & Session
- `ProjectInfo`: Project metadata and settings
- `SessionInfo`: Chat session with messages and context
- `SessionStats`: Usage statistics and metrics

### Infrastructure
- `SSHConfig`: SSH connection configuration
- `MCPServer`: MCP server configuration
- `MCPTool`: Detailed tool specification with JSON Schema

### Monitoring
- `ProcessInfo`: System process information
- `TraceEvent`: Application telemetry events
- `UserPreferences`: User settings and preferences

## Usage Examples

### Creating a Chat Request
```swift
let request = ChatCompletionRequest.simple(
    model: "gpt-4",
    messages: [
        .system("You are a helpful assistant"),
        .user("Hello!")
    ],
    temperature: 0.7
)
```

### Validating Models
```swift
do {
    try request.validate()
    // Request is valid
} catch let error as ValidationError {
    // Handle validation error
    print(error.localizedDescription)
}
```

### Using Factory Methods
```swift
// Create a new project
let project = ProjectInfo.new(
    name: "My Project",
    path: "/path/to/project"
)

// Create an SSH config
let ssh = SSHConfig.withPassword(
    name: "My Server",
    host: "example.com",
    username: "user",
    password: "pass"
)
```

### UI Display Extensions
```swift
// Get formatted display values
let roleColor = message.roleColor
let roleIcon = message.roleIcon
let formattedCost = usage.formattedCost(with: pricing)
let statusBadge = project.statusBadge
```

## Validation

All request models implement the `Validatable` protocol:

```swift
protocol Validatable {
    func validate() throws
}
```

Validation includes:
- Required field checks
- Range validation for numeric values
- Format validation for strings (email, URL, etc.)
- Cross-field dependency validation
- Custom business logic validation

## Testing

Test utilities are provided in `ModelTestUtilities.swift`:

```swift
// Generate mock data
let mockChat = MockDataGenerator.mockChatRequest()
let mockProject = MockDataGenerator.mockProject()

// Test validation
let result = ValidationTestUtilities.testValidation(
    model: request,
    shouldPass: true
)

// Test encoding/decoding
let codingResult = CodingTestUtilities.testCodable(model: request)

// Benchmark performance
let benchmark = PerformanceTestUtilities.benchmark(
    model: request,
    iterations: 1000
)
```

## API Compatibility

The models are designed to be compatible with:
- OpenAI Chat Completions API
- Claude API (via gateway)
- Local Claude Code API Gateway (http://localhost:8000/v1)

## Next Steps

With Tasks 161-200 complete, the next phase involves:
- Tasks 251-300: Settings & Configuration
- Integration with ViewModels (MVVM)
- API client implementation using these models
- SwiftUI views consuming the models

## Contributing

When adding new models:
1. Implement `Codable` and `Equatable`
2. Add validation logic if it's a request model
3. Create factory methods for common configurations
4. Add UI display extensions as needed
5. Include test utilities for mock data generation