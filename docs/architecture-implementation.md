# Claude Code iOS Architecture Implementation

## Overview

The Claude Code iOS app follows a robust MVVM (Model-View-ViewModel) architecture with centralized state management, dependency injection, and clear separation of concerns.

## Architecture Components

### 1. Dependency Injection (`DependencyContainer`)

**Location**: `Sources/Core/DependencyInjection/DependencyContainer.swift`

The `DependencyContainer` serves as the central dependency injection container for the entire application:

- **Singleton Pattern**: Single shared instance manages all dependencies
- **Service Management**: Lazy initialization of core services
- **ViewModel Factory**: Creates and manages ViewModels with proper dependencies
- **Lifecycle Management**: Handles app lifecycle events and cleanup

Key Features:
- Centralized service initialization
- ViewModel caching and reuse
- Environment injection for SwiftUI views
- Automatic cleanup on app termination

### 2. State Management

#### Core State Stores

1. **`AppState`** (`Sources/Core/State/AppState.swift`)
   - Global application state
   - Connection status
   - API health monitoring
   - Background task management
   - Session persistence

2. **`SettingsStore`** (`Sources/Core/State/SettingsStore.swift`)
   - User preferences (theme, font size, etc.)
   - API configuration
   - SSH settings
   - Secure credential storage via Keychain
   - UserDefaults integration

3. **`ChatStore`** (`Sources/Core/State/ChatStore.swift`)
   - Conversation management
   - Message history
   - Real-time chat state
   - Auto-save functionality
   - Import/export capabilities

4. **`ProjectStore`** (`Sources/Core/State/ProjectStore.swift`)
   - Project configurations
   - SSH connection settings
   - Environment variables
   - Project lifecycle management

5. **`ToolStore`** (`Sources/Core/State/ToolStore.swift`)
   - Available tools catalog
   - Tool execution management
   - Execution history
   - Favorites and recent tools

6. **`MonitorStore`** (`Sources/Core/State/MonitorStore.swift`)
   - System metrics (CPU, memory, disk)
   - Network statistics
   - SSH connection monitoring
   - System logs
   - Performance data export

### 3. ViewModels (MVVM Pattern)

Each major view has a dedicated ViewModel that:
- Manages UI state
- Coordinates between stores and services
- Handles business logic
- Provides data transformation for views

#### Implemented ViewModels:

1. **`ChatViewModel`** (`Sources/ViewModels/ChatViewModel.swift`)
   - Chat interface management
   - Message sending/receiving
   - Streaming responses
   - Error handling
   - Connection status

2. **`ProjectViewModel`** (`Sources/ViewModels/ProjectViewModel.swift`)
   - Project CRUD operations
   - SSH configuration
   - Environment variable management
   - Project search and filtering

3. **`SettingsViewModel`** (`Sources/ViewModels/SettingsViewModel.swift`)
   - Settings management
   - Connection testing
   - Import/export settings
   - Theme and preference updates

4. **`MonitorViewModel`** (`Sources/ViewModels/MonitorViewModel.swift`)
   - Real-time monitoring
   - Performance metrics
   - Log filtering and export
   - Alert management

5. **`ToolsViewModel`** (`Sources/ViewModels/ToolsViewModel.swift`)
   - Tool execution
   - Parameter validation
   - Execution history
   - Favorites management

### 4. Security (`KeychainManager`)

**Location**: `Sources/Core/Security/KeychainManager.swift`

Secure storage implementation:
- API keys
- SSH credentials
- Sensitive user data
- Encryption at rest
- Access control

### 5. Data Flow Architecture

```
┌─────────────┐     ┌──────────────┐     ┌────────────┐
│    Views    │────▶│  ViewModels  │────▶│   Stores   │
└─────────────┘     └──────────────┘     └────────────┘
       ▲                    │                     │
       │                    │                     │
       └────────────────────┴─────────────────────┘
                     Data Binding
                      (Combine)

┌──────────────────────────────────────────────────┐
│            DependencyContainer                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │ Services │  │  Stores  │  │ViewModels│      │
│  └──────────┘  └──────────┘  └──────────┘      │
└──────────────────────────────────────────────────┘
```

## Key Architectural Decisions

### 1. Thread Safety
- All UI updates on `@MainActor`
- Concurrent operations for network and data processing
- Thread-safe data structures

### 2. Error Propagation
- Typed errors for each domain
- Centralized error handling in ViewModels
- User-friendly error messages

### 3. Separation of Concerns
- Views: Pure UI rendering
- ViewModels: Business logic and state management
- Stores: Data persistence and domain logic
- Services: External communication

### 4. Reusable Components
- Generic store patterns
- Shared validation logic
- Common UI components
- Standardized error types

## App Lifecycle Management

### Initialization Flow
1. `ClaudeCodeApp` creates `DependencyContainer`
2. Container initializes core services
3. Settings loaded from UserDefaults/Keychain
4. AppState initialization
5. View hierarchy receives dependencies

### Background Processing
- Background task registration
- SSH monitoring
- Telemetry sync
- State persistence

### State Persistence
- Automatic save on background
- Periodic auto-save (30 seconds)
- Manual save triggers
- Crash recovery

## Testing Strategy

### Unit Testing
- ViewModels: Business logic validation
- Stores: Data management and persistence
- Services: API communication
- Security: Keychain operations

### Integration Testing
- ViewModel-Store interaction
- Service integration
- End-to-end data flow

### UI Testing
- View rendering
- User interactions
- Navigation flow
- Error scenarios

## Performance Considerations

### Memory Management
- Lazy loading of services
- ViewModel caching
- Automatic cleanup
- Weak references in Combine

### Network Optimization
- Request batching
- Response caching
- Connection pooling
- Rate limiting

### UI Performance
- Async operations
- Main thread protection
- Efficient data binding
- List virtualization

## Future Enhancements

### Planned Improvements
1. Core Data integration for offline support
2. CloudKit sync for multi-device support
3. Widget extension support
4. Shortcuts integration
5. Background processing enhancements

### Scalability Considerations
- Modular architecture supports feature additions
- Clean separation enables parallel development
- Testable components facilitate refactoring
- Performance monitoring for optimization

## Usage Examples

### Creating a New Feature

1. Create a Store for domain logic:
```swift
class FeatureStore: ObservableObject {
    @Published var data: [Item] = []
    // Implementation
}
```

2. Create a ViewModel:
```swift
class FeatureViewModel: ObservableObject {
    private let store: FeatureStore
    // Implementation
}
```

3. Register in DependencyContainer:
```swift
lazy var featureStore = FeatureStore()

func makeFeatureViewModel() -> FeatureViewModel {
    FeatureViewModel(store: featureStore)
}
```

4. Use in View:
```swift
struct FeatureView: View {
    @StateObject private var viewModel: FeatureViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: 
            DependencyContainer.shared.makeFeatureViewModel()
        )
    }
}
```

## Conclusion

This architecture provides a solid foundation for the Claude Code iOS app with:
- Clear separation of concerns
- Testable components
- Scalable structure
- Robust state management
- Secure data handling
- Performance optimization

The MVVM pattern with dependency injection ensures maintainability and enables efficient development of new features while maintaining code quality and consistency.