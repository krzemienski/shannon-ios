# Shannon iOS Codebase Structure

## Root Directory Structure
```
shannon-ios/
├── .claude/                 # Claude Code configuration
├── .taskmaster/            # Task Master AI configuration
│   ├── tasks/             # Task files and tasks.json
│   ├── docs/              # PRDs and documentation
│   └── config.json        # AI model configuration
├── .github/                # GitHub Actions workflows
├── Sources/                # Main source code
├── Scripts/                # Build and automation scripts
├── Resources/              # App resources (assets, fonts, etc.)
├── Configs/                # Build configurations
├── UITests/                # UI test suite
├── docs/                   # Project documentation
├── logs/                   # Build and simulator logs
├── build/                  # Build artifacts
└── [Configuration Files]   # Various config files
```

## Sources Directory (Main Code)
```
Sources/
├── App/                    # Application entry point
│   ├── ClaudeCodeApp.swift    # Main app struct
│   ├── AppDelegate.swift      # App lifecycle
│   └── ContentView.swift      # Root view
│
├── Core/                   # Core infrastructure
│   ├── Coordinators/       # Navigation coordination
│   ├── Security/           # Biometric auth, keychain
│   ├── Networking/         # API client, SSE support
│   ├── State/              # App state management
│   ├── Telemetry/          # Performance monitoring
│   ├── ErrorTracking/      # Error handling
│   ├── Data/               # Data persistence
│   ├── DependencyInjection/# Swinject DI setup
│   └── ModuleRegistration/ # Module registration
│
├── Features/               # Feature modules
│   └── Terminal/           # SSH terminal feature
│
├── Models/                 # Data models
│   ├── Chat models
│   ├── Project models
│   ├── Tool models
│   └── API models
│
├── Services/               # Business logic
│   ├── APIService
│   ├── AuthService
│   ├── ChatService
│   └── ProjectService
│
├── Views/                  # SwiftUI views
│   ├── Chat views
│   ├── Project views
│   ├── Settings views
│   └── Tool views
│
├── ViewModels/             # MVVM view models
│   ├── ChatViewModel
│   ├── ProjectViewModel
│   └── SettingsViewModel
│
├── Components/             # Reusable components
│   ├── Buttons
│   ├── Cards
│   ├── Lists
│   └── Inputs
│
├── UI/                     # UI utilities
│   ├── Extensions
│   ├── Modifiers
│   └── Styles
│
├── Theme/                  # Design system
│   ├── Colors (HSL system)
│   ├── Typography
│   ├── Spacing
│   └── Animations
│
└── Utilities/              # Helper functions
    ├── Extensions
    ├── Formatters
    └── Validators
```

## Key Configuration Files
- `Package.swift` - SPM dependencies
- `Project.yml` - XcodeGen configuration
- `Project.swift` - Tuist configuration
- `.swiftlint.yml` - Linting rules
- `Makefile` - Build automation
- `Info.plist` - App configuration
- `.mcp.json` - MCP server configuration
- `CLAUDE.md` - Project documentation

## Scripts Directory
- `simulator_automation.sh` - **PRIMARY BUILD SCRIPT**
- `bootstrap.sh` - Initial setup
- `quality_checks.sh` - Code quality
- `test_runner.sh` - Test execution
- `deploy.sh` - Deployment automation
- `fix_*.sh` - Various fix scripts

## Build Outputs
- `build/` - Compiled app and artifacts
- `logs/` - Simulator and build logs
- `DerivedData/` - Xcode derived data (gitignored)

## Module Organization
Each feature follows MVVM pattern:
- **Model**: Data structures and business entities
- **View**: SwiftUI views and UI components  
- **ViewModel**: Presentation logic and state management
- **Service**: API and business logic
- **Coordinator**: Navigation logic

## Dependency Graph
```
App → Coordinators → Features → ViewModels → Services → Models
                  ↓           ↓            ↓
                Views    Components    Networking
                  ↓           ↓            ↓
                Theme    Utilities    Security
```

## Known Issue Areas
- Terminal module (missing types causing compilation errors)
- Protocol conformances (Codable, Sendable issues)
- SwiftUI toolbar implementations
- Actor isolation conflicts

## Import Patterns
Common imports across the codebase:
- `import SwiftUI` - UI framework
- `import Combine` - Reactive programming
- `import Swinject` - Dependency injection
- `import KeychainAccess` - Secure storage
- `import Logging` - Logging framework
- `import Citadel` - SSH support