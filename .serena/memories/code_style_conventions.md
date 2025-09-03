# Code Style and Conventions for Shannon iOS

## Swift Code Style

### Naming Conventions
- **Types**: PascalCase (e.g., `ChatViewModel`, `APIClient`)
- **Properties/Methods**: camelCase (e.g., `messageHistory`, `sendMessage()`)
- **Constants**: camelCase with clear prefixes (e.g., `defaultTimeout`, `maxRetryCount`)
- **Protocols**: PascalCase, often ending in `Protocol`, `Delegate`, or descriptive suffix
- **Enums**: PascalCase for type, camelCase for cases

### Code Organization
- Use `// MARK: -` comments to organize code sections
- Order: Properties → Initializers → Public Methods → Private Methods
- Group related functionality together
- One type per file (classes, structs, enums)

### SwiftUI Specific
- Use `@StateObject` for owned objects
- Use `@ObservedObject` for injected objects
- Use `@EnvironmentObject` for shared app state
- Prefer composition over inheritance
- Extract complex views into separate components

### Architecture Patterns
- **MVVM Pattern**: Views → ViewModels → Models
- **Coordinator Pattern**: Navigation logic separated from views
- **Dependency Injection**: Using Swinject container
- **Repository Pattern**: Data access abstraction

### SwiftLint Rules
- Enforced via `.swiftlint.yml` configuration
- Key rules: line length (120), file length (400), function body length (40)
- Run `swiftlint` before committing
- Auto-fix with `swiftlint --fix`

### Access Control
- Use explicit access modifiers (`public`, `internal`, `private`)
- Prefer `private` by default, expose only what's necessary
- Use `private(set)` for read-only public properties

### Error Handling
- Use Swift's `Result` type for async operations
- Define custom `Error` enums for domain-specific errors
- Always provide meaningful error messages
- Use `do-catch` for synchronous error handling

### Documentation
- Use `///` for public API documentation
- Include parameter descriptions for methods
- Document complex logic with inline comments
- Keep comments up-to-date with code changes

### Testing Conventions
- Test files named `{ClassName}Tests.swift`
- Use descriptive test method names: `test_{methodName}_{scenario}_{expectedResult}`
- Arrange-Act-Assert pattern for test structure
- Mock external dependencies

### File Structure
```
Sources/
├── App/           # App entry point and configuration
├── Core/          # Core infrastructure (DI, networking, security)
├── Features/      # Feature modules (Terminal, Chat, etc.)
├── Models/        # Data models and entities
├── Services/      # Business logic and API services
├── UI/            # Reusable UI components
├── Views/         # SwiftUI views
├── ViewModels/    # View models for MVVM
├── Components/    # Reusable components
├── Theme/         # Design system and theming
└── Utilities/     # Helper functions and extensions
```

### Git Commit Conventions
- Use conventional commits: `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`
- Keep commits atomic and focused
- Write clear, descriptive commit messages
- Reference task IDs when applicable: `fix: auth issue (task 1.2)`