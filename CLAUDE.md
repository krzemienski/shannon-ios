# CLAUDE.md

## Project Overview

<!-- Run /app-design:create to generate app design document -->
<!-- Run /tech-stack:create to generate tech stack documentation -->

- App Design: @.taskmaster/docs/app-design-document.md
- Tech Stack: @.taskmaster/docs/tech-stack.md

## Simulator Configuration

### iPhone 16 Pro Max (iOS 18.6)
- **Simulator UUID**: `A707456B-44DB-472F-9722-C88153CDFFA1`
- **Logs Path**: `logs/simulator_*.log`
- **Build Destination**: `platform=iOS Simulator,id=A707456B-44DB-472F-9722-C88153CDFFA1`

### REQUIRED: Use Simulator Automation Script
**CRITICAL - MANDATORY**: You MUST ALWAYS use the `Scripts/simulator_automation.sh` script for ALL building, testing, and launching operations. NEVER use manual xcodebuild or xcrun commands directly. This script handles all the complexity of simulator management, logging, and build configuration.

**DO NOT USE MANUAL COMMANDS - USE THE SCRIPT!**

#### Available Commands:
```bash
# Complete workflow (recommended)
./Scripts/simulator_automation.sh all

# Individual commands
./Scripts/simulator_automation.sh build    # Build with logging
./Scripts/simulator_automation.sh launch   # Install and launch
./Scripts/simulator_automation.sh logs     # Capture logs only
./Scripts/simulator_automation.sh status   # Check simulator status
./Scripts/simulator_automation.sh clean    # Clean build artifacts
./Scripts/simulator_automation.sh help     # Show all options
```

#### Key Features:
- Automatic simulator boot if needed
- Log capture with filtering for ClaudeCode
- Proper PKG_CONFIG_PATH for libssh2 (Citadel/SSH dependencies)
- XcodeGen project generation if missing
- Clean build and installation
- Color-coded output for easy debugging

### Manual Build & Launch (Fallback Only)
```bash
# Only use if automation script fails
export SIMULATOR_UUID="A707456B-44DB-472F-9722-C88153CDFFA1"
export APP_BUNDLE_ID="com.claudecode.ios"

# 1. Start log capture (background)
xcrun simctl spawn $SIMULATOR_UUID log stream \
    --level=debug --style=syslog > logs/simulator_$(date +%Y%m%d_%H%M%S).log 2>&1 &

# 2. Build with Xcode
xcodebuild -scheme ClaudeCode \
    -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
    build

# 3. Install and launch
xcrun simctl install $SIMULATOR_UUID path/to/ClaudeCode.app
xcrun simctl launch $SIMULATOR_UUID $APP_BUNDLE_ID
```

## Project Status

<!-- **Current Stage**: Pre-MVP -->

### DO Care About

<!-- - **Security**: Authentication, authorization, input validation
- **Core Functionality**: Essential features that deliver primary value
- **Data Integrity**: Proper database design and constraints
- **Error Handling**: Basic error boundaries and user feedback -->

### DO NOT Care About

<!-- - **Unit Tests**: Focus on manual testing for now
- **Performance Optimization**: Premature optimization
- **Perfect Code**: Working implementation over perfect abstractions
- **Comprehensive Logging**: Basic console.error is enough -->

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
