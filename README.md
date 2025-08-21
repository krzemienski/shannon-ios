# Shannon iOS

The future home of Shannon - a modern iOS application built with Swift and SwiftUI, leveraging Claude's capabilities for intelligent code assistance and development.

## Overview

Shannon iOS is an upcoming native iOS client that will provide a seamless mobile experience for interacting with Claude through an intuitive and powerful interface. This repository contains the foundation and development framework for building the application.

## Current Documentation

The project currently includes comprehensive documentation and development infrastructure:

### Available Documentation

- **App Design Document** - Comprehensive design specifications and user experience guidelines
- **Tech Stack Documentation** - Detailed technical architecture and technology choices
- **Product Requirements** - Feature specifications and development priorities
- **Task Management** - Structured development workflow using Task Master with tagged tasks

### Development Infrastructure

- **Task Master Integration** - AI-powered task management system for organized development
- **Claude Code Configuration** - Optimized settings for AI-assisted development
- **Cursor IDE Rules** - Code standards and development patterns
- **Custom Commands** - Streamlined workflows for common development tasks

## Project Structure

```
shannon-ios/
├── .taskmaster/          # Task management and project planning
│   ├── docs/            # App design, tech stack, and PRD documents
│   ├── tasks/           # Tagged task management system
│   └── config.json      # AI model configuration
├── .cursor/              # Cursor IDE configuration and rules
├── .claude/              # Claude Code configuration and commands
├── claude-code-api/      # Backend API (see attribution below)
└── src/                  # iOS application source code (coming soon)
```

## Backend API Attribution

This project includes the [Claude Code API](https://github.com/codingworkflow/claude-code-api) backend implementation, which provides:

- OpenAI-compatible API endpoints for Claude interactions
- Session management and context handling
- Streaming responses and error handling
- Project-based organization

Full credit and thanks to the original [claude-code-api](https://github.com/codingworkflow/claude-code-api) project for the excellent backend foundation.

## Getting Started

### Prerequisites

- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Swift 5.9+
- Task Master for project management
- Node.js (for backend API if needed)

### Setup

1. Clone the repository
   ```bash
   git clone https://github.com/krzemienski/shannon-ios.git
   cd shannon-ios
   ```

2. Review existing documentation
   - App Design: `.taskmaster/docs/app-design-document.md`
   - Tech Stack: `.taskmaster/docs/tech-stack.md`
   - PRD: `.taskmaster/docs/prd.txt`

3. Set up Task Master for development workflow
   ```bash
   task-master list  # View current tasks
   ```

## Task Management

This project uses Task Master for development workflow management. Key commands:

```bash
# View all tasks
task-master list

# Get next task to work on
task-master next

# Mark task as complete
task-master set-status --id=<id> --status=done

# Work with feature tags
task-master tags  # List all feature tags
task-master use-tag <tag-name>  # Switch context
```

## Development Roadmap

The iOS application is currently in the planning and foundation phase. The comprehensive documentation and task structure are already in place to guide development:

1. **Foundation** (Current Phase)
   - Project structure and configuration ✓
   - Development workflow setup ✓
   - Documentation and planning ✓

2. **Core Implementation** (Next)
   - SwiftUI views and navigation
   - Claude API integration
   - Session management
   - Core UI components

3. **Feature Development**
   - Chat interface
   - Project management
   - Code assistance features
   - Settings and customization

## Development Approach

The project follows a structured development approach with:
- Task-driven development using Task Master
- AI-assisted development with Claude Code
- Clear separation of concerns
- Modern Swift and SwiftUI patterns
- Comprehensive documentation-first approach

## Contributing

Please refer to the task list and development guidelines in the `.taskmaster` directory. The project uses a tagged task system for managing different features and development contexts.

## License

[To be determined]

## Acknowledgments

- Backend API implementation from [claude-code-api](https://github.com/codingworkflow/claude-code-api)
- Built with Claude Code and Task Master for AI-assisted development