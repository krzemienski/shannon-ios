# Claude Code iOS - Deployment Automation Guide

## 🚀 Overview

This document provides comprehensive instructions for deploying Claude Code iOS to TestFlight and the App Store using our automated deployment infrastructure.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [One-Command Deployment](#one-command-deployment)
- [Deployment Scripts](#deployment-scripts)
- [CI/CD Pipeline](#cicd-pipeline)
- [Environment Configuration](#environment-configuration)
- [Beta Testing](#beta-testing)
- [Version Management](#version-management)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **Xcode 15.2+**: Required for building iOS apps
- **Xcode Command Line Tools**: `xcode-select --install`
- **Fastlane**: `gem install fastlane`
- **XcodeGen**: `brew install xcodegen`
- **Git**: Version control
- **jq**: `brew install jq` (for JSON processing)

### Apple Developer Account

1. **Apple Developer Program Membership** ($99/year)
2. **App Store Connect Access**
3. **Valid Distribution Certificate**
4. **App Store Provisioning Profile**

### API Keys Setup

1. **Create App Store Connect API Key**:
   ```bash
   # Go to App Store Connect > Users and Access > Keys
   # Generate a new API key with "Admin" or "App Manager" role
   # Download the .p8 file and note the Key ID and Issuer ID
   ```

2. **Set Environment Variables**:
   ```bash
   export APP_STORE_API_KEY_ID="YOUR_KEY_ID"
   export APP_STORE_API_ISSUER_ID="YOUR_ISSUER_ID"
   export APP_STORE_API_KEY="$(cat ~/path/to/AuthKey_YOUR_KEY_ID.p8)"
   ```

## Quick Start

### 🎯 One-Command Deployment to TestFlight

```bash
# Deploy to TestFlight with automatic version bump
./Scripts/deploy.sh

# Deploy to TestFlight with specific version bump
./Scripts/deploy.sh deploy testflight minor

# Deploy to App Store
./Scripts/deploy.sh deploy appstore major
```

### 🎯 Using Fastlane

```bash
# Deploy to TestFlight
fastlane beta

# Deploy to App Store
fastlane release

# Run tests and deploy
fastlane ci deploy_beta:true
```

## One-Command Deployment

The `deploy.sh` script provides complete automation:

### Basic Usage

```bash
# Default: Deploy to TestFlight with patch version bump
./Scripts/deploy.sh

# Specify target and version bump
./Scripts/deploy.sh deploy [target] [bump]
# target: testflight|appstore
# bump: major|minor|patch
```

### What It Does

1. ✅ Checks prerequisites
2. ✅ Validates git state
3. ✅ Bumps version automatically
4. ✅ Generates release notes
5. ✅ Builds and archives app
6. ✅ Exports IPA
7. ✅ Uploads to TestFlight/App Store
8. ✅ Creates git tag
9. ✅ Sends notifications

### Advanced Options

```bash
# Force deployment with uncommitted changes
./Scripts/deploy.sh --force

# Skip git tag creation
./Scripts/deploy.sh --skip-tag

# Dry run (simulate without executing)
./Scripts/deploy.sh --dry-run

# Verbose output
./Scripts/deploy.sh --verbose
```

## Deployment Scripts

### 📁 Scripts Overview

```
Scripts/
├── deploy.sh              # Main deployment script
├── release_automation.sh  # Legacy release script
├── beta_testing.sh       # Beta infrastructure setup
├── version_manager.sh    # Version and changelog management
└── simulator_automation.sh # Simulator testing
```

### deploy.sh

**Main deployment orchestrator**

Features:
- One-command deployment
- Automatic version management
- Release note generation
- Git tag creation
- Notification system

```bash
# Examples
./Scripts/deploy.sh deploy testflight patch
./Scripts/deploy.sh build Release
./Scripts/deploy.sh validate build/ClaudeCode.ipa
./Scripts/deploy.sh notes 1.2.0
```

### version_manager.sh

**Version and changelog management**

```bash
# Bump version
./Scripts/version_manager.sh bump minor

# Generate changelog
./Scripts/version_manager.sh changelog v1.0.0 v1.1.0

# Generate release notes
./Scripts/version_manager.sh notes 1.2.0 markdown

# Prepare complete release
./Scripts/version_manager.sh prepare
```

### beta_testing.sh

**Beta testing infrastructure setup**

```bash
# Setup complete beta infrastructure
./Scripts/beta_testing.sh all

# Setup specific components
./Scripts/beta_testing.sh crashlytics
./Scripts/beta_testing.sh analytics
./Scripts/beta_testing.sh feedback
```

## CI/CD Pipeline

### GitHub Actions Workflow

The `.github/workflows/deploy.yml` provides automated CI/CD:

#### Automatic Triggers

- **Push to main**: Deploy to TestFlight
- **Push tag v***: Deploy to App Store
- **Pull Request**: Run tests only

#### Manual Triggers

```yaml
# Trigger via GitHub UI or API
workflow_dispatch:
  inputs:
    deployment_target: testflight|appstore
    version_bump: patch|minor|major
    skip_tests: true|false
```

### Setting Up GitHub Secrets

Required secrets in GitHub repository settings:

```yaml
# Apple Developer
TEAM_ID: "YOUR_TEAM_ID"
APP_STORE_CONNECT_API_KEY_ID: "API_KEY_ID"
APP_STORE_CONNECT_API_ISSUER_ID: "ISSUER_ID"
APP_STORE_CONNECT_API_KEY: "-----BEGIN PRIVATE KEY-----..."

# Code Signing (Base64 encoded)
BUILD_CERTIFICATE_BASE64: "base64_encoded_p12"
P12_PASSWORD: "certificate_password"
BUILD_PROVISION_PROFILE_BASE64: "base64_encoded_mobileprovision"
KEYCHAIN_PASSWORD: "temporary_keychain_password"

# Optional Notifications
SLACK_WEBHOOK_URL: "https://hooks.slack.com/..."
DISCORD_WEBHOOK_URL: "https://discord.com/api/webhooks/..."
```

### Encoding Certificates for CI

```bash
# Encode certificate
base64 -i Certificates.p12 | pbcopy

# Encode provisioning profile
base64 -i Profile.mobileprovision | pbcopy
```

## Environment Configuration

### Build Configurations

```
Configs/
├── Debug.xcconfig        # Development builds
├── Release.xcconfig      # Release builds
├── TestFlight.xcconfig   # TestFlight beta builds
└── Production.xcconfig   # App Store production
```

### Environment Variables

#### Development
```bash
API_BASE_URL=http://localhost:8000
ENABLE_DEBUG_MENU=YES
ENABLE_MOCK_DATA=YES
```

#### TestFlight
```bash
API_BASE_URL=https://api-staging.claudecode.app
ENABLE_ANALYTICS=YES
ENABLE_CRASH_REPORTING=YES
ENABLE_BETA_FEATURES=YES
```

#### Production
```bash
API_BASE_URL=https://api.claudecode.app
ENABLE_ANALYTICS=YES
ENABLE_CRASH_REPORTING=YES
ENABLE_CERTIFICATE_PINNING=YES
```

## Beta Testing

### TestFlight Setup

1. **Configure Beta Testing**:
   ```bash
   ./Scripts/beta_testing.sh all
   ```

2. **Beta Test Information**:
   - Max testers: 10,000
   - Build expiry: 90 days
   - Groups: Internal, External

3. **Beta Tester Onboarding**:
   ```
   1. Send TestFlight invitation
   2. Tester accepts via email
   3. Downloads TestFlight app
   4. Installs Claude Code beta
   ```

### Crash Reporting

**Firebase Crashlytics**:
```swift
// Automatic setup in AppDelegate
FirebaseApp.configure()
```

**Sentry Integration**:
```swift
SentrySDK.start { options in
    options.dsn = "YOUR_SENTRY_DSN"
    options.environment = "beta"
}
```

### Analytics Tracking

```swift
// Track beta events
AnalyticsManager.shared.track(.betaFeatureUsed, parameters: [
    "feature_name": "new_feature",
    "user_segment": "beta"
])
```

### Feedback Collection

In-app feedback system:
```swift
FeedbackManager.shared.showFeedbackDialog(from: viewController)
```

## Version Management

### Semantic Versioning

Format: `MAJOR.MINOR.PATCH[-PRERELEASE.NUMBER]`

- **Major**: Breaking changes
- **Minor**: New features
- **Patch**: Bug fixes
- **Prerelease**: Beta versions

### Version Bump Examples

```bash
# Current: 1.2.3
./Scripts/version_manager.sh bump patch  # → 1.2.4
./Scripts/version_manager.sh bump minor  # → 1.3.0
./Scripts/version_manager.sh bump major  # → 2.0.0

# Prerelease versions
./Scripts/version_manager.sh bump prerelease beta  # → 1.2.3-beta.1
```

### Changelog Generation

Automatic changelog from git commits:
```bash
# Generate for current version
./Scripts/version_manager.sh changelog

# Generate between versions
./Scripts/version_manager.sh changelog v1.0.0 v1.1.0
```

### Release Notes

Multiple formats supported:
```bash
# Markdown (for GitHub)
./Scripts/version_manager.sh notes 1.2.0 markdown

# HTML (for website)
./Scripts/version_manager.sh notes 1.2.0 html

# JSON (for API)
./Scripts/version_manager.sh notes 1.2.0 json
```

## App Store Metadata

### Directory Structure

```
fastlane/metadata/
└── en-US/
    ├── description.txt        # App description
    ├── keywords.txt          # Search keywords
    ├── name.txt             # App name
    ├── subtitle.txt         # App subtitle
    ├── release_notes.txt    # What's new
    ├── support_url.txt      # Support URL
    ├── marketing_url.txt    # Marketing URL
    └── privacy_url.txt      # Privacy policy URL
```

### Screenshot Automation

```bash
# Generate screenshots for all devices
fastlane snapshot

# Upload screenshots
fastlane deliver --skip_metadata --skip_binary_upload
```

## Deployment Workflows

### Development → TestFlight

```bash
# 1. Ensure clean git state
git status

# 2. Run tests
fastlane test

# 3. Deploy to TestFlight
./Scripts/deploy.sh deploy testflight patch

# 4. Monitor TestFlight
# Wait for processing (5-30 minutes)
# Check email for confirmation
```

### TestFlight → App Store

```bash
# 1. Test thoroughly in TestFlight
# Ensure no critical issues from beta testers

# 2. Prepare for App Store
./Scripts/version_manager.sh prepare 1.0.0

# 3. Deploy to App Store
./Scripts/deploy.sh deploy appstore major

# 4. Submit for review
# Monitor review status in App Store Connect
```

### Hotfix Deployment

```bash
# 1. Create hotfix branch
git checkout -b hotfix/critical-bug

# 2. Fix issue and test
# Make changes and test thoroughly

# 3. Deploy hotfix
./Scripts/deploy.sh deploy testflight patch --force

# 4. Fast-track to App Store if needed
./Scripts/deploy.sh deploy appstore patch
```

## Monitoring Deployments

### TestFlight Metrics

- **Crashes**: View in App Store Connect
- **Feedback**: TestFlight feedback section
- **Installation**: Number of testers who installed
- **Sessions**: Active usage statistics

### Production Metrics

- **Downloads**: App Analytics
- **Crashes**: Crashlytics/Sentry dashboards
- **Ratings**: App Store reviews
- **Performance**: Firebase Performance Monitoring

## Troubleshooting

### Common Issues

#### Code Signing Failed
```bash
# Reset certificates
security delete-keychain ios-build.keychain
fastlane match nuke distribution
fastlane match appstore
```

#### Upload to TestFlight Failed
```bash
# Validate IPA first
xcrun altool --validate-app --file build/ClaudeCode.ipa \
  --apiKey $APP_STORE_API_KEY_ID \
  --apiIssuer $APP_STORE_API_ISSUER_ID

# Check for common issues:
# - Invalid bundle ID
# - Missing entitlements
# - Expired certificates
```

#### Build Number Already Exists
```bash
# Increment build number
./Scripts/version_manager.sh bump patch
# Or use timestamp-based build number
```

### Debug Mode

Enable verbose logging:
```bash
# Fastlane
fastlane beta --verbose

# Deploy script
./Scripts/deploy.sh --verbose

# GitHub Actions
# Set secret: ACTIONS_RUNNER_DEBUG = true
```

### Getting Help

1. **Documentation**: `docs/` directory
2. **Scripts Help**: `./Scripts/[script].sh help`
3. **Fastlane Docs**: `fastlane docs`
4. **Support Email**: developer@claudecode.app
5. **Discord**: Join developer community

## Security Best Practices

### API Keys

- ❌ Never commit API keys to repository
- ✅ Use environment variables
- ✅ Use GitHub Secrets for CI/CD
- ✅ Rotate keys regularly

### Code Signing

- ✅ Use separate certificates for development/distribution
- ✅ Store certificates in secure keychain
- ✅ Use Fastlane Match for team certificate management

### Sensitive Data

- ✅ Encrypt sensitive configuration
- ✅ Use secure storage for credentials
- ✅ Implement certificate pinning for production

## Appendix

### Useful Commands

```bash
# View current version
cat .version

# Check TestFlight status
fastlane pilot list

# View build details
fastlane pilot builds

# Download dSYMs
fastlane download_dsyms

# Verify IPA contents
unzip -l build/ClaudeCode.ipa

# Test push notifications
fastlane pem
fastlane push
```

### Environment Variables Reference

```bash
# Required for deployment
export APP_STORE_API_KEY_ID="YOUR_KEY_ID"
export APP_STORE_API_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_API_KEY="$(cat AuthKey.p8)"
export FASTLANE_USER="developer@claudecode.app"
export FASTLANE_TEAM_ID="YOUR_TEAM_ID"

# Optional for notifications
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
export DISCORD_WEBHOOK_URL="https://discord.com/..."
export NOTIFICATION_EMAIL="team@claudecode.app"

# Optional for analytics
export FIREBASE_API_KEY="..."
export SENTRY_DSN="..."
export ANALYTICS_API_KEY="..."
```

---

## 🎉 Conclusion

With this deployment automation system, you can:

1. **Deploy to TestFlight** with a single command
2. **Automate version management** and changelog generation
3. **Run CI/CD pipelines** on every push
4. **Manage beta testing** infrastructure
5. **Track deployments** with analytics and crash reporting

For questions or issues, please refer to the troubleshooting section or contact the development team.

**Happy Deploying! 🚀**