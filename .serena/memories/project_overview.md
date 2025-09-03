# Shannon iOS (Claude Code iOS) - Project Overview

## Project Purpose
Shannon iOS (also known as Claude Code iOS) is a powerful native iOS client for Claude AI, providing seamless integration with Claude's capabilities through an intuitive mobile interface. The app is built with Swift and SwiftUI, delivering professional-grade AI assistance for developers on the go.

## Tech Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Platform**: iOS 17.0+ (Universal app for iPhone/iPad)
- **Architecture**: MVVM + Coordinator Pattern
- **Dependency Management**: Swift Package Manager (SPM)
- **Build System**: XcodeGen + Xcode

## Key Dependencies
- **Swinject**: Dependency injection framework (2.9.0+)
- **KeychainAccess**: Secure keychain storage (4.2.2+)
- **swift-log**: Apple's logging framework (1.5.3+)
- **Citadel**: SSH support library (0.7.0+)

## Core Features
- AI Chat Interface with Claude models (Opus, Sonnet, Haiku)
- Real-time Server-Sent Events (SSE) streaming
- Biometric authentication and security
- SSH Terminal integration
- Project management and organization
- Background processing support
- Offline message queueing
- Performance monitoring and telemetry
- MCP (Model Context Protocol) tool support
- Cyberpunk-themed UI with HSL color system

## Current Build Status
- **Stage**: Pre-MVP with compilation errors
- **Simulator**: iPhone 16 Pro Max (iOS 18.6) 
- **UUID**: 50523130-57AA-48B0-ABD0-4D59CE455F14
- **Bundle ID**: com.claudecode.ios or com.claudecodeswift.ios
- **Critical Issues**: ~20+ compilation errors requiring fixes before launch

## Development Tools
- Xcode 15.0+
- XcodeGen for project generation
- SwiftLint for code quality
- Task Master AI for task management
- Makefile for build automation