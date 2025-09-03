# CLAUDE.md

## Project Overview

<!-- Run /app-design:create to generate app design document -->
<!-- Run /tech-stack:create to generate tech stack documentation -->

- App Design: @.taskmaster/docs/app-design-document.md
- Tech Stack: @.taskmaster/docs/tech-stack.md

## 🚀 Build System: Tuist

This project uses **Tuist** for build management and project generation. Tuist provides:
- Declarative project configuration in Swift
- Reproducible builds across team members
- Dependency management via Swift Package Manager
- Automatic project generation from manifest files

### Required Tuist Files
- `Tuist.swift` - Root configuration for Tuist
- `Project.swift` - Project definition with targets and dependencies
- `Tuist/ProjectDescriptionHelpers/` - Shared build settings and helpers

## Build Instructions (Tuist)

### Prerequisites
```bash
# Install Tuist (if not already installed)
curl -Ls https://install.tuist.io | bash

# Or via Homebrew
brew install tuist
```

### Primary Build Workflow
```bash
# 1. Generate Xcode project from Tuist manifests
tuist generate

# 2. Build the project
tuist build

# 3. Run on simulator
tuist build --open

# Alternative: Build with specific configuration
tuist build --configuration Debug
tuist build --configuration Release

# Clean build
tuist clean
tuist build --clean
```

### Common Tuist Commands
```bash
# Edit Tuist manifests in Xcode
tuist edit

# Install dependencies
tuist install

# Graph visualization
tuist graph

# Run tests
tuist test

# Focus on specific targets (faster generation)
tuist generate ClaudeCodeSwift

# Cache management
tuist cache warm  # Pre-build dependencies
tuist cache print # Show cache status
```

### Troubleshooting Tuist Builds
```bash
# Clear all caches and regenerate
tuist clean
rm -rf Derived/
rm -rf .build/
tuist generate

# Verbose output for debugging
tuist build --verbose

# Check Tuist version
tuist version

# Update Tuist
tuist update
```

## Simulator Configuration

### iPhone 16 Pro Max (iOS 18.6)
- **Simulator UUID**: `50523130-57AA-48B0-ABD0-4D59CE455F14`
- **Logs Path**: `logs/simulator_*.log`
- **Build Destination**: `platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14`

### Automated Build & Launch with Tuist
```bash
# Complete workflow using Tuist
tuist generate && tuist build --open

# Or use the automation script (legacy, pre-Tuist)
./Scripts/simulator_automation.sh all
```

### Manual Simulator Operations (Fallback Only)
```bash
# Only use if Tuist and automation script fail
export SIMULATOR_UUID="50523130-57AA-48B0-ABD0-4D59CE455F14"
export APP_BUNDLE_ID="com.claudecode.ios"

# Start log capture (background)
xcrun simctl spawn $SIMULATOR_UUID log stream \
    --level=debug --style=syslog > logs/simulator_$(date +%Y%m%d_%H%M%S).log 2>&1 &

# Install and launch (after Tuist build)
xcrun simctl install $SIMULATOR_UUID Derived/Build/Products/Debug-iphonesimulator/ClaudeCode.app
xcrun simctl launch $SIMULATOR_UUID $APP_BUNDLE_ID
```

## Project Status

**Current Stage**: Pre-MVP - Multiple Compilation Errors
**Build Status**: ❌ FAILED - Requires targeted fixes for launch

### Build Progress Summary

#### ✅ Fixed Issues (Completed)
- Navigation parameter mismatches in CoordinatorView
- Tool view implementations (ToolExecutionView, ToolCategoryView)
- Voice input structure (VoiceWaveformView, VoiceInputConfiguration)
- SSHAuthMethod duplicate definition resolved
- Performance types added (PerformanceBottleneck, PerformanceMeasurement, PerformanceSpan)
- SSEConfiguration Sendable conformance
- APIError reference corrected

#### ❌ Remaining Critical Issues (20+ errors)
1. **Terminal Module** - Missing types: TerminalLine, TerminalCharacter, CursorPosition
2. **Protocol Conformance** - QueuedRequest doesn't conform to Codable
3. **Concurrency Issues** - Multiple singletons need @unchecked Sendable
4. **SwiftUI Issues** - ToolbarContent protocol problems in ProjectDetailView
5. **Actor Isolation** - Conflicts in RASPManager, RequestPrioritizer

### Recommended Path to MVP
1. Comment out Terminal module (most errors)
2. Add stub implementations for missing types
3. Fix Sendable conformance issues
4. Simplify toolbar implementations
5. Focus on core chat/API features only

### DO Care About

- **Build Fixes**: Get the app compiling first (Priority 1)
- **Core Navigation**: Fix CoordinatorView parameter mismatches
- **Missing Views**: Create stub implementations for Tools module
- **Security**: Biometric auth, certificate pinning already implemented
- **Core Functionality**: Chat, Projects, Tools, Monitoring modules

### DO NOT Care About

- **Unit Tests**: Focus on getting app running first
- **Performance Optimization**: Already has good architecture
- **Perfect Code**: Get working implementation first
- **Comprehensive Logging**: Basic implementation exists

### Development Approach

<!-- - **Focus**: Ship working features quickly
- **Iterate**: Get user feedback early and often
- **Refactor**: Clean up after validation, not before -->

## Commands

### Development

<!-- - `pnpm typecheck` - Run TypeScript type checking (must pass without errors)
- `pnpm lint` - Run ESLint
- `pnpm format` - Format code with Prettier -->

### Database

<!-- - `pnpm db:generate` - Generate Prisma client from schema
- `pnpm db:push` - Push schema changes to database
- `pnpm db:seed` - Seed database with initial data -->

### Testing

<!-- - `pnpm test` - Run unit tests
- `pnpm test:e2e` - Run end-to-end tests -->

## Available Slash Commands

### Task Management

- `/task:next` - Get next task and start implementing
- `/task:list` - List all tasks
- `/task:show <id>` - Show task details
- `/task:done <id>` - Mark task complete
- `/task:add` - Add one or more tasks
- `/task:add-interactive` - Add tasks with clarifying questions
- `/prd:parse` - Parse PRD into tasks
- `/task:expand <id>` - Break down complex tasks
- `/task:move <from> to <to>` - Reorganize tasks

### Task Updates

- `/task:update` - Update tasks based on changes
- `/task:update-interactive` - Update tasks with clarifying questions
- `/task:research` - Research best practices

### Research

- `/research:task` - Research for specific tasks
- `/research:architecture` - Research system design
- `/research:tech` - Research technologies
- `/research:security` - Research security practices

### Documentation

- `/app-design:create` - Create app design document
- `/app-design:update` - Update app design document
- `/tech-stack:create` - Create tech stack documentation
- `/tech-stack:update` - Update tech stack documentation
- `/prd:create-interactive` - Create PRD with Q&A
- `/prd:create` - Create PRD without questions

### Development Tools

- `/rules:create` - Create new Cursor rule
- `/rules:update` - Update existing Cursor rule

## Development Guidelines

This project uses a unified approach to development patterns across Claude Code and Cursor:

### Core Rules

- @.cursor/rules/cursor-rules.mdc - Rule creation guidelines
- @.cursor/rules/project-status.mdc - Stage-based development priorities
- @.cursor/rules/self-improve.mdc - Continuous improvement patterns

### Task Management

- @.cursor/rules/taskmaster/taskmaster.mdc - Task Master command reference
- @.cursor/rules/taskmaster/dev-workflow.mdc - Development workflow patterns

### Complete Task Master Guide

- .taskmaster/docs/taskmaster-guide.md - Full tagged task management documentation, if needed

## Project Structure

```
project/
├── .taskmaster/          # Task management files
│   ├── tasks/           # Task database and files
│   ├── docs/            # PRDs and documentation
│   └── config.json      # AI model configuration
├── .cursor/             # Cursor-specific rules
│   └── rules/           # Development patterns
├── .claude/             # Claude Code configuration
│   ├── commands/        # Custom slash commands
│   └── settings.json    # Tool preferences
└── src/                 # Application source code
```

## Notes

- Never work directly on the `master` tag - always create feature tags
- Run typecheck before committing
- Use `/task:next` to automatically get and start implementing tasks

## Task Master AI Instructions
**Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**
@./.taskmaster/CLAUDE.md
