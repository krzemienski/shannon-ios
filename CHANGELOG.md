# Changelog

All notable changes to Claude Code iOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- TestFlight beta testing preparation
- App Store metadata configuration
- Performance profiling tools
- Memory leak detection
- Crash reporting integration

### Changed
- Optimized app launch time
- Improved SSH connection stability
- Enhanced error messages

### Fixed
- Memory leaks in chat view
- SSH terminal scroll issues
- Dark mode inconsistencies

## [1.0.0] - 2024-01-20

### Added
- Initial release of Claude Code for iOS
- Full-featured chat interface with Claude AI
- Support for Claude Opus, Sonnet, and Haiku models
- Real-time streaming responses via Server-Sent Events
- Project-based conversation organization
- SSH terminal with remote development capabilities
- Comprehensive security features:
  - Biometric authentication (Face ID/Touch ID)
  - Keychain storage for sensitive data
  - Certificate pinning
  - Jailbreak detection
- Cyberpunk-themed dark UI
- Syntax highlighting for 100+ programming languages
- Code formatting and validation tools
- Performance monitoring dashboard
- Background task processing
- Offline message queuing
- Export conversations (PDF, Markdown, JSON)
- MCP tool integration
- Environment variables per project
- Multi-model support with model switching
- iPad optimization with keyboard shortcuts

### Security
- Implemented AES-256 encryption for local data
- Added runtime application self-protection (RASP)
- Integrated certificate pinning for API calls
- Enhanced input sanitization

### Performance
- Implemented LRU caching for API responses
- Added image caching system
- Optimized message pagination
- Implemented request debouncing

## [1.0.0-beta.3] - 2024-01-15

### Added
- TestFlight beta distribution
- Crash reporting via Crashlytics
- Analytics integration
- User feedback system

### Changed
- Improved onboarding flow
- Enhanced error handling
- Optimized network requests

### Fixed
- Fixed keyboard dismissal issues
- Resolved tab bar navigation bugs
- Fixed message ordering in conversations

## [1.0.0-beta.2] - 2024-01-10

### Added
- SSH key generation
- File transfer over SSH
- Port forwarding capabilities
- Terminal color schemes

### Changed
- Redesigned settings interface
- Improved SSH connection handling
- Enhanced terminal performance

### Fixed
- SSH connection timeout issues
- Terminal rendering bugs
- Memory leaks in SSH sessions

## [1.0.0-beta.1] - 2024-01-05

### Added
- Basic chat functionality
- API integration with Claude
- Project management
- Settings screen
- Basic SSH terminal

### Known Issues
- Occasional crashes on iPad
- SSH connections may timeout
- Some UI elements not properly themed

## [0.9.0] - 2024-01-01

### Added
- Core architecture implementation
- MVVM-C pattern setup
- Dependency injection framework
- Basic UI components
- Theme system
- Navigation coordinators

## [0.8.0] - 2023-12-25

### Added
- Project structure setup
- XcodeGen configuration
- SwiftLint integration
- Basic models and services
- API client foundation

## [0.7.0] - 2023-12-20

### Added
- Initial project creation
- README documentation
- License file
- Basic Swift package dependencies

---

## Version History Summary

| Version | Date | Highlights |
|---------|------|------------|
| 1.0.0 | 2024-01-20 | 🚀 Official release |
| 1.0.0-beta.3 | 2024-01-15 | TestFlight beta |
| 1.0.0-beta.2 | 2024-01-10 | SSH improvements |
| 1.0.0-beta.1 | 2024-01-05 | First beta |
| 0.9.0 | 2024-01-01 | Architecture complete |
| 0.8.0 | 2023-12-25 | Foundation laid |
| 0.7.0 | 2023-12-20 | Project started |

## Roadmap

### Version 1.1.0 (Planned - Q1 2024)
- [ ] Voice input support
- [ ] Claude vision capabilities
- [ ] Collaborative features
- [ ] Cloud sync
- [ ] Widget support

### Version 1.2.0 (Planned - Q2 2024)
- [ ] macOS Catalyst support
- [ ] Shortcuts app integration
- [ ] Custom themes
- [ ] Plugin system
- [ ] Advanced analytics

### Version 2.0.0 (Planned - Q3 2024)
- [ ] Major UI redesign
- [ ] AI agent capabilities
- [ ] Code execution environment
- [ ] Team collaboration
- [ ] Enterprise features

## Migration Notes

### Migrating from Beta to 1.0.0

1. **API Key Storage**: API keys are automatically migrated to the new secure storage
2. **Projects**: All projects and conversations are preserved
3. **Settings**: Settings are migrated, but some may need reconfiguration
4. **SSH Connections**: SSH connection settings need to be re-entered for security

### Breaking Changes in 1.0.0

- API endpoint structure changed from `/api/v1/` to `/v1/`
- Session ID format updated to UUID v4
- Removed deprecated `ChatManager` class
- Changed theme color values for better contrast

## Support

For issues or questions about specific versions:
- GitHub Issues: [github.com/claudecode/ios/issues](https://github.com/claudecode/ios/issues)
- Email: support@claudecode.app
- Documentation: [docs.claudecode.app](https://docs.claudecode.app)

## Contributors

Thanks to all contributors who have helped shape Claude Code iOS:

- Development Team
- Beta Testers
- Community Contributors
- Open Source Projects

---

[Unreleased]: https://github.com/claudecode/ios/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/claudecode/ios/releases/tag/v1.0.0
[1.0.0-beta.3]: https://github.com/claudecode/ios/releases/tag/v1.0.0-beta.3
[1.0.0-beta.2]: https://github.com/claudecode/ios/releases/tag/v1.0.0-beta.2
[1.0.0-beta.1]: https://github.com/claudecode/ios/releases/tag/v1.0.0-beta.1
[0.9.0]: https://github.com/claudecode/ios/releases/tag/v0.9.0
[0.8.0]: https://github.com/claudecode/ios/releases/tag/v0.8.0
[0.7.0]: https://github.com/claudecode/ios/releases/tag/v0.7.0