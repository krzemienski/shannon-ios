# Claude Code iOS

[![Swift Version](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen.svg)](https://github.com/krzemienski/claude-code-ios)

A powerful native iOS client for Claude AI, providing seamless integration with Claude's capabilities through an intuitive mobile interface. Built with Swift and SwiftUI, Claude Code iOS delivers professional-grade AI assistance for developers on the go.

## 🌟 Features

### Core Capabilities
- **💬 AI Chat Interface** - Full-featured chat with Claude AI models
- **🔄 Real-time Streaming** - Server-sent events for responsive interactions
- **📱 Native iOS Experience** - Built with SwiftUI for optimal performance
- **🔒 Security First** - Biometric authentication, keychain storage, and encrypted communications
- **🎨 Cyberpunk UI Theme** - Modern, customizable dark theme with neon accents
- **🖥️ SSH Terminal** - Integrated terminal with SSH support for remote development
- **📊 Performance Monitoring** - Real-time metrics and system diagnostics
- **🛠️ MCP Tool Support** - Extensible tool system for enhanced capabilities

### Advanced Features
- **Project Management** - Organize conversations by project context
- **Background Processing** - Continue tasks while app is backgrounded
- **Offline Support** - Queue messages for sending when connection restored
- **Multi-Model Support** - Switch between Claude Opus, Sonnet, and Haiku models
- **Code Highlighting** - Syntax highlighting for 100+ languages
- **Export/Import** - Backup and restore conversations and settings

## 📋 Requirements

- **iOS** 17.0 or later
- **Xcode** 15.0 or later
- **Swift** 5.9 or later
- **Device** iPhone, iPad (Universal app)
- **Backend** Claude Code API server (included)

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/krzemienski/claude-code-ios.git
cd claude-code-ios-swift2
```

### 2. Install Dependencies
```bash
# Install XcodeGen if not already installed
brew install xcodegen

# Install libssh2 for SSH support (required for Citadel)
brew install libssh2

# Install SwiftLint for code quality
brew install swiftlint

# Generate Xcode project
xcodegen generate

# Install Swift Package dependencies (handled by Xcode)
```

### 3. Configure the Backend (Optional)
```bash
# Navigate to backend directory
cd claude-code-api

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the server
uvicorn app:app --reload --port 8000
```

### 4. Build and Run
```bash
# Using the automation script (STRONGLY RECOMMENDED)
./Scripts/simulator_automation.sh all

# Available automation commands:
./Scripts/simulator_automation.sh build    # Build only
./Scripts/simulator_automation.sh launch   # Install and launch
./Scripts/simulator_automation.sh logs     # Capture logs
./Scripts/simulator_automation.sh status   # Check simulator status
./Scripts/simulator_automation.sh clean    # Clean build artifacts
./Scripts/simulator_automation.sh test     # Run UI tests
./Scripts/simulator_automation.sh help     # Show all options

# Or open in Xcode
open ClaudeCodeSwift.xcodeproj
# Then press Cmd+R to build and run
```

## 📱 Simulator Configuration

The project is configured for iPhone 16 Pro Max simulator:
- **Simulator UUID**: `A707456B-44DB-472F-9722-C88153CDFFA1`
- **iOS Version**: 18.6
- **Bundle ID**: `com.claudecode.ios`
- **Use Script**: `./Scripts/simulator_automation.sh` for automated building

**IMPORTANT**: Always use the automation script instead of manual xcodebuild commands. The script handles:
- Automatic simulator boot if needed
- Log capture with filtering for ClaudeCode
- Proper PKG_CONFIG_PATH for libssh2 dependencies
- XcodeGen project generation if missing
- Clean build and installation
- Color-coded output for debugging

## 🏗️ Architecture

Claude Code iOS follows a modular MVVM-C (Model-View-ViewModel-Coordinator) architecture:

```
Sources/
├── App/                    # App entry point and configuration
│   ├── ClaudeCodeApp.swift
│   ├── ContentView.swift
│   └── AppDelegate.swift
├── Core/                   # Core functionality
│   ├── Coordinators/       # Navigation coordinators
│   ├── Data/              # Core Data stack
│   ├── DependencyContainer.swift
│   ├── Networking/        # API and WebSocket clients
│   ├── Security/          # Security and encryption
│   ├── State/             # Global state management
│   └── Telemetry/         # Analytics and monitoring
├── Features/              # Feature modules
│   ├── Chat/             # Chat functionality
│   ├── Projects/         # Project management
│   ├── Terminal/         # Terminal emulator
│   └── Tools/            # Developer tools
├── Models/                # Data models
├── Services/              # Business logic services
│   ├── SSH/              # SSH implementation
│   ├── Notifications/    # Push notifications
│   └── Voice/            # Voice features
├── UI/                    # Shared UI components
│   ├── Components/       # Reusable components
│   └── DesignSystem/     # Design tokens and themes
├── ViewModels/           # View models for MVVM
└── Views/                # SwiftUI views
    ├── Chat/            # Chat interface views
    ├── Projects/        # Project views
    ├── Settings/        # Settings views
    └── Tools/           # Tool views
```

## 🔧 Configuration

### API Configuration
Configure the API endpoint in `Services/APIConfig.swift`:
```swift
struct APIConfig {
    static let baseURL = "http://localhost:8000"
    static let apiVersion = "v1"
}
```

### Environment Variables
Set in Xcode scheme or `.env` file:
```bash
API_BASE_URL=http://localhost:8000/v1
LOG_LEVEL=debug
ENABLE_TESTING_FEATURES=YES
```

## 🧪 Testing

### Run UI Tests
```bash
# Using automation script (recommended)
./Scripts/simulator_automation.sh test

# Run all UI tests
xcodebuild test \
    -scheme ClaudeCode \
    -destination "platform=iOS Simulator,id=A707456B-44DB-472F-9722-C88153CDFFA1" \
    -only-testing:ClaudeCodeUITests

# Run specific test suite
xcodebuild test \
    -scheme ClaudeCode \
    -destination "platform=iOS Simulator,id=A707456B-44DB-472F-9722-C88153CDFFA1" \
    -only-testing:ClaudeCodeUITests/ChatStreamingTests

# Run with coverage
xcodebuild test \
    -scheme ClaudeCode \
    -destination "platform=iOS Simulator,id=A707456B-44DB-472F-9722-C88153CDFFA1" \
    -enableCodeCoverage YES \
    -resultBundlePath TestResults
```

### Test Coverage Areas
- **Authentication Tests**: Login, biometric auth, session management
- **Chat Tests**: Message streaming, error handling, offline queue
- **File Operations**: File CRUD, search, syntax highlighting
- **Project Management**: Project lifecycle, terminal operations, SSH
- **Monitoring Tests**: Metric collection, alerts, data export
- **Settings Tests**: Configuration, theme switching, data management
- **Navigation Tests**: Tab navigation, deep linking, modal flows

### Test Scripts
```bash
# Run functional UI tests
./Scripts/test_functional_ui.swift

# Test networking layer
./Scripts/test_networking.swift

# Run notification tests
./Scripts/test_notifications.swift
```

## 📚 Documentation

- [Architecture Guide](docs/ARCHITECTURE.md) - System design and patterns
- [API Documentation](docs/API_DOCUMENTATION.md) - Complete API reference
- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) - App Store submission process
- [User Manual](docs/USER_MANUAL.md) - End-user documentation
- [Contributing](CONTRIBUTING.md) - Development guidelines
- [Testing Guide](docs/TESTING_GUIDE.md) - Comprehensive testing documentation
- [Security Overview](docs/SECURITY.md) - Security features and implementation

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 🐛 Common Issues & Solutions

### Build Failures
```bash
# Regenerate project file
xcodegen generate

# Clean build artifacts
./Scripts/simulator_automation.sh clean

# Check for missing dependencies
brew list libssh2
```

### Simulator Issues
```bash
# Reset simulator
xcrun simctl erase A707456B-44DB-472F-9722-C88153CDFFA1

# Check simulator status
./Scripts/simulator_automation.sh status
```

### SSH Connection Failures
```bash
# Verify libssh2 installation
brew list libssh2

# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Claude Code API** - Backend implementation from [claude-code-api](https://github.com/codingworkflow/claude-code-api)
- **Anthropic** - For Claude AI models and capabilities
- **Swift Community** - For excellent open-source packages
- **Contributors** - Everyone who has contributed to this project

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/krzemienski/claude-code-ios/issues)
- **Discussions**: [GitHub Discussions](https://github.com/krzemienski/claude-code-ios/discussions)
- **Email**: support@claudecode.app

## 🚦 Project Status

### Completed ✅
- Core Architecture with MVVM-C pattern
- Complete UI/UX Design System with Cyberpunk theme
- Claude AI API Integration with streaming
- Security Implementation (Jailbreak detection, Keychain, Biometrics)
- SSH Terminal with libssh2 integration
- Project Management System
- System Monitoring Dashboard
- Offline Support with Core Data
- WebSocket Communication
- Push Notifications

### In Progress 🚧
- App Store Preparation
- Performance Optimization
- UI Test Suite Completion

### Planned 📋
- Beta Testing Program
- iPad Support
- macOS Catalyst Version
- CloudKit Sync
- Widget Extensions

---

Built with ❤️ using Claude Code and Swift