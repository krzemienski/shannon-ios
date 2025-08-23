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
cd claude-code-ios
```

### 2. Install Dependencies
```bash
# Install XcodeGen if not already installed
brew install xcodegen

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
# Using the automation script (recommended)
./Scripts/simulator_automation.sh all

# Or open in Xcode
open ClaudeCode.xcodeproj
# Then press Cmd+R to build and run
```

## 📱 Simulator Configuration

The project is configured for iPhone 16 Pro Max simulator:
- **Simulator UUID**: `A707456B-44DB-472F-9722-C88153CDFFA1`
- **iOS Version**: 18.6
- **Use Script**: `./Scripts/simulator_automation.sh` for automated building

## 🏗️ Architecture

Claude Code iOS follows a modular MVVM-C (Model-View-ViewModel-Coordinator) architecture:

```
Sources/
├── App/                    # App entry point and configuration
├── Architecture/           # Core architectural components
│   ├── DependencyInjection/
│   ├── ModuleRegistration/
│   └── StateManagement/
├── Core/                   # Core functionality
│   ├── Coordinators/       # Navigation coordinators
│   ├── Security/           # Security and encryption
│   ├── SSH/               # SSH client implementation
│   ├── State/             # Global state management
│   └── Telemetry/         # Analytics and monitoring
├── Features/              # Feature modules
│   └── Terminal/          # Terminal emulator
├── Models/                # Data models
├── Services/              # Network and API services
├── Theme/                 # Design system and theming
├── ViewModels/            # View models for MVVM
└── Views/                 # SwiftUI views
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
# Using automation script
./Scripts/simulator_automation.sh test

# Or using xcodebuild
xcodebuild test \
    -scheme ClaudeCode \
    -destination "platform=iOS Simulator,id=A707456B-44DB-472F-9722-C88153CDFFA1"
```

### Test Coverage
- UI Tests: Functional testing of all major workflows
- Integration Tests: API client and service layer
- Performance Tests: Memory and CPU usage monitoring

## 📚 Documentation

- [Architecture Guide](ARCHITECTURE.md) - System design and patterns
- [API Documentation](API_DOCUMENTATION.md) - Complete API reference
- [Deployment Guide](DEPLOYMENT_GUIDE.md) - App Store submission process
- [User Manual](USER_MANUAL.md) - End-user documentation
- [Contributing](CONTRIBUTING.md) - Development guidelines

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

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

- ✅ Core Architecture
- ✅ UI/UX Design System
- ✅ API Integration
- ✅ Security Implementation
- ✅ SSH Terminal
- 🚧 App Store Preparation
- 🚧 Performance Optimization
- 📋 Beta Testing

---

Built with ❤️ using Claude Code and Swift