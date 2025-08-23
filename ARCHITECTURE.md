# Claude Code iOS Architecture Guide

## Table of Contents

1. [Overview](#overview)
2. [Architecture Pattern](#architecture-pattern)
3. [Core Components](#core-components)
4. [Module Structure](#module-structure)
5. [Data Flow](#data-flow)
6. [Dependency Management](#dependency-management)
7. [Security Architecture](#security-architecture)
8. [Performance Optimization](#performance-optimization)
9. [Testing Strategy](#testing-strategy)
10. [Best Practices](#best-practices)

## Overview

Claude Code iOS is built using a modular MVVM-C (Model-View-ViewModel-Coordinator) architecture that emphasizes:

- **Separation of Concerns**: Clear boundaries between UI, business logic, and data layers
- **Testability**: Isolated components that can be unit tested independently
- **Scalability**: Modular design that supports feature addition without architectural changes
- **Maintainability**: Clean code organization with consistent patterns throughout

## Architecture Pattern

### MVVM-C (Model-View-ViewModel-Coordinator)

```
┌─────────────────────────────────────────────────────────────┐
│                         Coordinator                         │
│                    (Navigation & Flow)                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                           View                              │
│                      (SwiftUI Views)                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        ViewModel                            │
│              (Business Logic & Presentation)                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                          Model                              │
│                    (Data & Services)                        │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

#### Coordinators
- **Purpose**: Handle navigation logic and flow control
- **Location**: `Sources/Core/Coordinators/`
- **Key Classes**:
  - `AppCoordinator`: Main app navigation
  - `ChatCoordinator`: Chat flow management
  - `ProjectsCoordinator`: Project navigation
  - `SettingsCoordinator`: Settings flow

#### Views
- **Purpose**: SwiftUI views for UI presentation
- **Location**: `Sources/Views/`
- **Organization**: Grouped by feature (Chat, Projects, Settings, etc.)

#### ViewModels
- **Purpose**: Business logic and view state management
- **Location**: `Sources/ViewModels/`
- **Pattern**: ObservableObject with @Published properties

#### Models
- **Purpose**: Data structures and domain entities
- **Location**: `Sources/Models/`
- **Types**: API models, domain models, network models

#### Services
- **Purpose**: External communication and data persistence
- **Location**: `Sources/Services/`
- **Key Services**:
  - `APIClient`: REST API communication
  - `SSEClient`: Server-sent events handling
  - `SSHManager`: SSH connection management

## Core Components

### Dependency Injection

```swift
// Sources/Architecture/DependencyInjection/ServiceContainer.swift
class ServiceContainer {
    static let shared = ServiceContainer()
    
    private var services: [String: Any] = [:]
    
    func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
    }
    
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return services[key] as? T
    }
}
```

### State Management

```swift
// Sources/Architecture/StateManagement/StateManager.swift
@MainActor
class StateManager: ObservableObject {
    @Published var appState: AppState
    @Published var chatStore: ChatStore
    @Published var projectStore: ProjectStore
    @Published var settingsStore: SettingsStore
    
    private let persistenceManager: PersistenceManager
    
    init() {
        // Initialize stores with persistence
    }
}
```

### Reactive Store

```swift
// Sources/Architecture/StateManagement/ReactiveStore.swift
protocol ReactiveStore: ObservableObject {
    associatedtype State
    var state: State { get }
    func dispatch(_ action: Action)
}
```

## Module Structure

### Feature Modules

Each feature follows a consistent structure:

```
Features/
└── Terminal/
    ├── ViewModels/
    │   └── TerminalViewModel.swift
    ├── Views/
    │   ├── TerminalEmulatorView.swift
    │   ├── TerminalInputView.swift
    │   └── TerminalOutputView.swift
    └── Models/
        └── TerminalModels.swift
```

### Core Modules

```
Core/
├── Security/           # Authentication, encryption, keychain
├── SSH/               # SSH client implementation
├── State/             # Global state management
├── Telemetry/         # Analytics and monitoring
├── Networking/        # Network layer abstractions
└── Monitoring/        # Performance and system monitoring
```

## Data Flow

### Unidirectional Data Flow

```
User Action → View → ViewModel → Service → API
                ↑                    ↓
                └── State Update ← Response
```

### Example: Sending a Chat Message

```swift
// 1. User taps send button in ChatView
Button("Send") {
    viewModel.sendMessage(text)
}

// 2. ViewModel processes the action
class ChatViewModel: ObservableObject {
    func sendMessage(_ text: String) {
        Task {
            let message = ChatMessage(content: text)
            await apiClient.sendMessage(message)
            await MainActor.run {
                self.messages.append(message)
            }
        }
    }
}

// 3. API Client sends request
class APIClient {
    func sendMessage(_ message: ChatMessage) async throws -> ChatResponse {
        let request = createRequest(endpoint: "/chat/completions", body: message)
        return try await networkService.perform(request)
    }
}
```

## Dependency Management

### Service Locator Pattern

```swift
protocol ServiceLocating {
    func resolve<T>(_ type: T.Type) -> T
}

class ServiceLocator: ServiceLocating {
    private let container: ServiceContainer
    
    func resolve<T>(_ type: T.Type) -> T {
        guard let service = container.resolve(type) else {
            fatalError("Service \(type) not registered")
        }
        return service
    }
}
```

### Module Registration

```swift
// Sources/Architecture/ModuleRegistration/AppModules.swift
class AppModules {
    static func registerAll() {
        // Register services
        ServiceContainer.shared.register(APIClient(), for: APIClient.self)
        ServiceContainer.shared.register(SSHManager(), for: SSHManager.self)
        ServiceContainer.shared.register(KeychainManager(), for: KeychainManager.self)
        
        // Register view models
        ServiceContainer.shared.register(ChatViewModel(), for: ChatViewModel.self)
        ServiceContainer.shared.register(ProjectViewModel(), for: ProjectViewModel.self)
    }
}
```

## Security Architecture

### Layer Defense Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
│              (Jailbreak Detection, RASP)                    │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                     Transport Layer                         │
│           (Certificate Pinning, TLS 1.3)                    │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      Storage Layer                          │
│           (Keychain, Encrypted Core Data)                   │
└─────────────────────────────────────────────────────────────┘
```

### Key Security Components

- **BiometricAuthManager**: Face ID/Touch ID authentication
- **KeychainManager**: Secure credential storage
- **DataEncryptionManager**: AES-256 encryption for sensitive data
- **CertificatePinningManager**: SSL certificate validation
- **JailbreakDetector**: Runtime application self-protection

## Performance Optimization

### Caching Strategy

```swift
// Sources/Core/Utilities/LRUCache.swift
class LRUCache<Key: Hashable, Value> {
    private let maxSize: Int
    private var cache: [Key: Node<Key, Value>] = [:]
    private let list = DoublyLinkedList<Key, Value>()
    
    func get(_ key: Key) -> Value? {
        guard let node = cache[key] else { return nil }
        list.moveToFront(node)
        return node.value
    }
    
    func set(_ key: Key, value: Value) {
        if let node = cache[key] {
            node.value = value
            list.moveToFront(node)
        } else {
            let node = Node(key: key, value: value)
            cache[key] = node
            list.addToFront(node)
            
            if cache.count > maxSize {
                evictLRU()
            }
        }
    }
}
```

### Image Caching

```swift
// Sources/Core/Utilities/ImageCache.swift
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString
        
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        guard let image = await downloadImage(from: url) else {
            return nil
        }
        
        cache.setObject(image, forKey: key)
        return image
    }
}
```

### Debouncing

```swift
// Sources/Core/Utilities/Debouncer.swift
class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    func debounce(_ action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}
```

## Testing Strategy

### Test Pyramid

```
         ╱╲
        ╱  ╲      E2E Tests (10%)
       ╱    ╲     - Critical user flows
      ╱──────╲    - App Store validation
     ╱        ╲
    ╱          ╲  Integration Tests (30%)
   ╱            ╲ - API integration
  ╱──────────────╲ - Service layer
 ╱                ╲
╱                  ╲ Unit Tests (60%)
────────────────────╲ - ViewModels
                      - Business logic
                      - Utilities
```

### Testing Patterns

```swift
// ViewModel Testing
class ChatViewModelTests: XCTestCase {
    var sut: ChatViewModel!
    var mockAPIClient: MockAPIClient!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = ChatViewModel(apiClient: mockAPIClient)
    }
    
    func testSendMessage() async {
        // Given
        let message = "Test message"
        mockAPIClient.stubResponse = .success(ChatResponse())
        
        // When
        await sut.sendMessage(message)
        
        // Then
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.content, message)
    }
}
```

## Best Practices

### 1. Coordinator Pattern
- Keep navigation logic out of views and view models
- Use coordinators for complex flows
- Pass dependencies through initializers

### 2. Async/Await
- Use modern concurrency for all asynchronous operations
- Proper error handling with do-catch blocks
- MainActor for UI updates

### 3. SwiftUI Best Practices
- Small, focused views
- Composition over inheritance
- Environment objects for shared state

### 4. Dependency Injection
- Constructor injection preferred
- Protocol-oriented design
- Testable components

### 5. Error Handling
```swift
enum AppError: LocalizedError {
    case networkError(Error)
    case invalidData
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data received"
        case .unauthorized:
            return "Authentication required"
        }
    }
}
```

### 6. Memory Management
- Weak references for delegates
- Capture lists in closures
- Proper cleanup in deinit

### 7. Performance
- Lazy loading where appropriate
- Image and data caching
- Background queue for heavy operations

### 8. Security
- Never store sensitive data in UserDefaults
- Use Keychain for credentials
- Validate all inputs
- Certificate pinning for API calls

## Migration Strategy

### From Existing Architecture

1. **Phase 1**: Establish coordinator layer
2. **Phase 2**: Migrate to MVVM pattern
3. **Phase 3**: Implement dependency injection
4. **Phase 4**: Add reactive state management
5. **Phase 5**: Optimize and refactor

### Adding New Features

1. Create feature module structure
2. Define models and API contracts
3. Implement service layer
4. Create view model with business logic
5. Build SwiftUI views
6. Add coordinator for navigation
7. Write tests
8. Document feature

---

This architecture provides a solid foundation for building a scalable, maintainable, and testable iOS application while following Apple's best practices and modern Swift patterns.