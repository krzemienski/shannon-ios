# Contributing to Claude Code iOS

Thank you for your interest in contributing to Claude Code iOS! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [How to Contribute](#how-to-contribute)
5. [Coding Standards](#coding-standards)
6. [Testing Guidelines](#testing-guidelines)
7. [Pull Request Process](#pull-request-process)
8. [Issue Guidelines](#issue-guidelines)
9. [Documentation](#documentation)
10. [Community](#community)

## Code of Conduct

### Our Pledge

We are committed to making participation in this project a harassment-free experience for everyone, regardless of level of experience, gender, gender identity and expression, sexual orientation, disability, personal appearance, body size, race, ethnicity, age, religion, or nationality.

### Expected Behavior

- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

### Unacceptable Behavior

- Harassment, discrimination, or offensive comments
- Trolling or insulting/derogatory comments
- Public or private harassment
- Publishing others' private information without permission

## Getting Started

### Prerequisites

- macOS Ventura (13.0) or later
- Xcode 15.0 or later
- Swift 5.9 or later
- Git
- GitHub account
- Basic knowledge of Swift and iOS development

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/claude-code-ios.git
   cd claude-code-ios
   ```
3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/krzemienski/claude-code-ios.git
   ```

## Development Setup

### 1. Install Dependencies

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install XcodeGen
brew install xcodegen

# Install SwiftLint
brew install swiftlint

# Install pre-commit hooks (optional)
brew install pre-commit
pre-commit install
```

### 2. Generate Xcode Project

```bash
# Generate project from Project.yml
xcodegen generate
```

### 3. Configure Development Environment

Create a `.env.development` file:
```bash
API_BASE_URL=http://localhost:8000/v1
LOG_LEVEL=debug
ENABLE_TESTING_FEATURES=YES
```

### 4. Run the Backend (Optional)

```bash
cd claude-code-api
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app:app --reload
```

### 5. Build and Run

```bash
# Using automation script
./Scripts/simulator_automation.sh all

# Or open in Xcode
open ClaudeCode.xcodeproj
# Press Cmd+R to run
```

## How to Contribute

### Types of Contributions

#### 1. Bug Reports
- Search existing issues first
- Provide detailed reproduction steps
- Include system information
- Add screenshots if applicable

#### 2. Feature Requests
- Check roadmap and existing requests
- Explain use case clearly
- Propose implementation approach
- Consider backward compatibility

#### 3. Code Contributions
- Bug fixes
- New features
- Performance improvements
- Refactoring
- Tests

#### 4. Documentation
- README improvements
- API documentation
- Code comments
- Tutorial writing

#### 5. Design
- UI/UX improvements
- Icon and asset creation
- Theme contributions
- Accessibility enhancements

### Contribution Workflow

1. **Find or Create Issue**
   - Check existing issues
   - Create new issue if needed
   - Get feedback before starting major work

2. **Create Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-number
   ```

3. **Make Changes**
   - Write clean, readable code
   - Follow coding standards
   - Add tests for new features
   - Update documentation

4. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: add new feature" 
   # Use conventional commits
   ```

5. **Push and Create PR**
   ```bash
   git push origin feature/your-feature-name
   ```

## Coding Standards

### Swift Style Guide

We follow the [Ray Wenderlich Swift Style Guide](https://github.com/raywenderlich/swift-style-guide) with some modifications:

#### Naming Conventions

```swift
// Classes, Structs, Enums - UpperCamelCase
class ChatViewController { }
struct UserModel { }
enum NetworkError { }

// Variables, Functions - lowerCamelCase
var userName: String
func sendMessage() { }

// Constants - lowerCamelCase
let maximumRetryCount = 3

// Protocols - UpperCamelCase, often ending in -able, -ible, or -ing
protocol Sendable { }
protocol DataProviding { }
```

#### Code Organization

```swift
// MARK: - Properties
private let apiClient: APIClient
@Published var messages: [Message] = []

// MARK: - Lifecycle
init(apiClient: APIClient) {
    self.apiClient = apiClient
}

// MARK: - Public Methods
func sendMessage(_ text: String) {
    // Implementation
}

// MARK: - Private Methods
private func processResponse(_ response: Response) {
    // Implementation
}
```

#### SwiftUI Best Practices

```swift
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Chat")
                .toolbar {
                    toolbarContent
                }
        }
    }
    
    // MARK: - Views
    private var content: some View {
        // View implementation
    }
    
    private var toolbarContent: some ToolbarContent {
        // Toolbar implementation
    }
}
```

### File Organization

```
Sources/
├── App/                 # App entry point
├── Models/              # Data models
├── Views/               # SwiftUI views
├── ViewModels/          # View models
├── Services/            # API and services
├── Core/                # Core functionality
├── Components/          # Reusable UI components
├── Utilities/           # Helper functions
└── Resources/           # Assets and resources
```

### SwiftLint Configuration

Our `.swiftlint.yml` enforces consistent code style:

```yaml
disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - empty_count
  - closure_spacing
  - contains_over_first_not_nil

line_length:
  warning: 120
  error: 150

file_length:
  warning: 500
  error: 1000
```

## Testing Guidelines

### Test Types

#### Unit Tests
```swift
class ChatViewModelTests: XCTestCase {
    var sut: ChatViewModel!
    var mockAPIClient: MockAPIClient!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = ChatViewModel(apiClient: mockAPIClient)
    }
    
    func testSendMessage() async throws {
        // Given
        let message = "Test"
        
        // When
        await sut.sendMessage(message)
        
        // Then
        XCTAssertEqual(sut.messages.count, 1)
    }
}
```

#### UI Tests
```swift
class ChatUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launch()
    }
    
    func testSendMessage() {
        // Given
        let textField = app.textFields["messageInput"]
        let sendButton = app.buttons["sendButton"]
        
        // When
        textField.tap()
        textField.typeText("Hello")
        sendButton.tap()
        
        // Then
        XCTAssertTrue(app.staticTexts["Hello"].exists)
    }
}
```

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme ClaudeCode -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test -scheme ClaudeCode -only-testing:ClaudeCodeTests/ChatViewModelTests

# Generate coverage report
xcodebuild test -scheme ClaudeCode -enableCodeCoverage YES
```

### Test Coverage Requirements

- New features: Minimum 80% coverage
- Bug fixes: Include regression test
- UI components: Snapshot tests preferred

## Pull Request Process

### Before Submitting

1. **Update from upstream**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run tests**
   ```bash
   ./Scripts/run_tests.sh
   ```

3. **Run SwiftLint**
   ```bash
   swiftlint
   ```

4. **Update documentation**
   - Add/update code comments
   - Update README if needed
   - Add CHANGELOG entry

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] UI tests pass
- [ ] Manual testing completed

## Screenshots (if applicable)
Add screenshots here

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No warnings generated
- [ ] Tests added/updated
```

### Review Process

1. Automated checks must pass
2. At least one maintainer review required
3. All feedback addressed
4. Squash commits if requested
5. Maintain clean commit history

## Issue Guidelines

### Bug Report Template

```markdown
**Describe the bug**
Clear description of the issue

**To Reproduce**
1. Go to '...'
2. Click on '...'
3. See error

**Expected behavior**
What should happen

**Screenshots**
If applicable

**Environment:**
- iOS Version: [e.g., 17.0]
- Device: [e.g., iPhone 15 Pro]
- App Version: [e.g., 1.0.0]

**Additional context**
Any other relevant information
```

### Feature Request Template

```markdown
**Is your feature request related to a problem?**
Description of the problem

**Describe the solution**
How you'd like it to work

**Alternatives considered**
Other solutions you've thought about

**Additional context**
Any other information or screenshots
```

## Documentation

### Code Documentation

```swift
/// Sends a message to the Claude API and processes the response
/// - Parameters:
///   - text: The message text to send
///   - model: The AI model to use (default: Haiku)
/// - Returns: The API response
/// - Throws: `APIError` if the request fails
func sendMessage(_ text: String, model: Model = .haiku) async throws -> Response {
    // Implementation
}
```

### README Updates

- Keep README current with new features
- Update installation instructions
- Add new dependencies
- Update screenshots

### API Documentation

- Document all public APIs
- Include usage examples
- Note breaking changes
- Version compatibility

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General discussions and questions
- **Twitter**: [@ClaudeCodeApp](https://twitter.com/ClaudeCodeApp)
- **Email**: dev@claudecode.app

### Getting Help

- Check documentation first
- Search existing issues
- Ask in GitHub Discussions
- Contact maintainers

### Recognition

Contributors are recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project README
- Annual contributor spotlight

## Development Tips

### Useful Commands

```bash
# Clean build folder
./Scripts/clean.sh

# Generate documentation
./Scripts/generate_docs.sh

# Run performance tests
./Scripts/performance_test.sh

# Check for memory leaks
./Scripts/check_memory.sh
```

### Debugging

```swift
// Debug logging
#if DEBUG
print("Debug: \(variable)")
#endif

// Breakpoint conditions
// condition: userID == "test"

// LLDB commands
// po variable
// expr variable = newValue
```

### Performance

- Profile with Instruments
- Monitor memory usage
- Check for retain cycles
- Optimize image loading
- Use lazy loading

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

## Questions?

Feel free to:
- Open an issue for clarification
- Ask in GitHub Discussions
- Contact maintainers directly

Thank you for contributing to Claude Code iOS! 🎉