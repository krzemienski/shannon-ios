# ClaudeCode iOS - Makefile
# Complete automation for iOS development workflow

.PHONY: help all bootstrap generate build test clean lint format open
.PHONY: simulator device archive release beta docs security update
.PHONY: ci-build ci-test ci-release pre-commit

# Configuration
SIMULATOR_UUID ?= A707456B-44DB-472F-9722-C88153CDFFA1
SCHEME = ClaudeCode
APP_BUNDLE_ID = com.claudecode.ios
BUILD_DIR = build
LOGS_DIR = logs
ARCHIVE_PATH = $(BUILD_DIR)/ClaudeCode.xcarchive
IPA_PATH = $(BUILD_DIR)/ClaudeCode.ipa

# Default target
help:
	@echo "╔════════════════════════════════════════════════════════════════╗"
	@echo "║             ClaudeCode iOS - Build Automation                     ║"
	@echo "╠════════════════════════════════════════════════════════════════╣"
	@echo "║ Basic Commands:                                                   ║"
	@echo "║   make all         - Complete build and test workflow             ║"
	@echo "║   make bootstrap   - Install dependencies and generate project    ║"
	@echo "║   make generate    - Generate Xcode project with XcodeGen         ║"
	@echo "║   make build       - Build for simulator                          ║"
	@echo "║   make test        - Run all tests with coverage                  ║"
	@echo "║   make clean       - Clean all build artifacts                    ║"
	@echo "║                                                                    ║"
	@echo "║ Simulator Commands:                                               ║"
	@echo "║   make simulator   - Build and run on simulator                   ║"
	@echo "║   make sim-test    - Run tests on simulator                       ║"
	@echo "║   make sim-ui-test - Run UI tests on simulator                    ║"
	@echo "║                                                                    ║"
	@echo "║ Device Commands:                                                  ║"
	@echo "║   make device      - Build and install on device                  ║"
	@echo "║   make device-test - Run tests on device                          ║"
	@echo "║                                                                    ║"
	@echo "║ Release Commands:                                                 ║"
	@echo "║   make archive     - Create release archive                       ║"
	@echo "║   make release     - Build release IPA                            ║"
	@echo "║   make beta        - Deploy to TestFlight                         ║"
	@echo "║   make appstore    - Submit to App Store                          ║"
	@echo "║                                                                    ║"
	@echo "║ Quality Commands:                                                 ║"
	@echo "║   make lint        - Run SwiftLint                                ║"
	@echo "║   make format      - Format code with SwiftFormat                 ║"
	@echo "║   make docs        - Generate documentation                       ║"
	@echo "║   make security    - Run security audit                           ║"
	@echo "║   make analyze     - Run static analysis                          ║"
	@echo "║                                                                    ║"
	@echo "║ CI/CD Commands:                                                   ║"
	@echo "║   make ci-build    - CI build pipeline                            ║"
	@echo "║   make ci-test     - CI test pipeline                             ║"
	@echo "║   make ci-release  - CI release pipeline                          ║"
	@echo "║                                                                    ║"
	@echo "║ Utility Commands:                                                 ║"
	@echo "║   make update      - Update dependencies                          ║"
	@echo "║   make pre-commit  - Run pre-commit checks                        ║"
	@echo "║   make open        - Open project in Xcode                        ║"
	@echo "╚════════════════════════════════════════════════════════════════╝"

# Complete workflow
all: clean bootstrap generate build test
	@echo "✅ Complete workflow executed successfully!"

# Bootstrap the project
bootstrap:
	@./Scripts/bootstrap.sh

# Generate Xcode project
generate:
	@echo "🔨 Generating Xcode project..."
	@xcodegen generate

# Build the project for simulator
build: generate
	@echo "🏗️ Building ClaudeCode for simulator..."
	@./Scripts/simulator_automation.sh build

# Run all tests with coverage
test: generate
	@echo "🧪 Running tests..."
	@./Scripts/test_runner.sh all

# Run unit tests only
test-unit: generate
	@echo "🧪 Running unit tests..."
	@./Scripts/test_runner.sh unit

# Run UI tests only
test-ui: generate
	@echo "🧪 Running UI tests..."
	@./Scripts/test_runner.sh ui

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(LOGS_DIR)/*.log
	@rm -rf DerivedData
	@rm -rf ~/Library/Developer/Xcode/DerivedData/ClaudeCode-*
	@xcodebuild -project ClaudeCode.xcodeproj -scheme $(SCHEME) clean 2>/dev/null || true
	@echo "✅ Clean complete"

# ============================================================================
# Simulator Commands
# ============================================================================

# Build and run on simulator
simulator: generate
	@echo "📱 Building and running on simulator..."
	@./Scripts/simulator_automation.sh all

# Run tests on simulator
sim-test: generate
	@echo "🧪 Running tests on simulator..."
	@./Scripts/simulator_automation.sh test

# Run UI tests on simulator
sim-ui-test: generate
	@echo "🧪 Running UI tests on simulator..."
	@./Scripts/simulator_automation.sh uitest

# ============================================================================
# Device Commands
# ============================================================================

# Build and install on device
device: generate
	@echo "📱 Building for device..."
	@./Scripts/device_build.sh install

# Run tests on device
device-test: generate
	@echo "🧪 Running tests on device..."
	@./Scripts/device_build.sh test

# ============================================================================
# Release Commands
# ============================================================================

# Create release archive
archive: generate
	@echo "📦 Creating release archive..."
	@./Scripts/release_automation.sh archive

# Build release IPA
release: archive
	@echo "🚀 Building release IPA..."
	@./Scripts/release_automation.sh ipa

# Deploy to TestFlight
beta: release
	@echo "✈️ Deploying to TestFlight..."
	@./Scripts/release_automation.sh testflight

# Submit to App Store
appstore: release
	@echo "🍎 Submitting to App Store..."
	@./Scripts/release_automation.sh appstore

# ============================================================================
# Quality Commands
# ============================================================================

# Run SwiftLint
lint:
	@echo "🔍 Running SwiftLint..."
	@./Scripts/quality_checks.sh lint

# Format code
format:
	@echo "✨ Formatting code..."
	@./Scripts/quality_checks.sh format

# Generate documentation
docs:
	@echo "📚 Generating documentation..."
	@./Scripts/documentation.sh generate

# Run security audit
security:
	@echo "🔒 Running security audit..."
	@./Scripts/security_audit.sh all

# Run static analysis
analyze: generate
	@echo "🔬 Running static analysis..."
	@./Scripts/quality_checks.sh analyze

# ============================================================================
# CI/CD Commands
# ============================================================================

# CI build pipeline
ci-build: clean generate build
	@echo "✅ CI build complete"

# CI test pipeline
ci-test: clean generate test
	@echo "✅ CI tests complete"

# CI release pipeline
ci-release: clean generate archive release
	@echo "✅ CI release complete"

# ============================================================================
# Utility Commands
# ============================================================================

# Update dependencies
update:
	@echo "📦 Updating dependencies..."
	@./Scripts/dependency_update.sh all

# Run pre-commit checks
pre-commit:
	@echo "🔍 Running pre-commit checks..."
	@./Scripts/pre_commit.sh

# Open project in Xcode
open: generate
	@echo "📱 Opening Xcode..."
	@open ClaudeCode.xcodeproj

# ============================================================================
# Backend Commands (for integration)
# ============================================================================

# Install backend dependencies
backend-install:
	@echo "📦 Installing backend dependencies..."
	@cd claude-code-api && make install

# Start backend server
backend-start:
	@echo "🚀 Starting backend server..."
	@cd claude-code-api && make start

# Check backend health
backend-health:
	@echo "🏥 Checking backend health..."
	@curl -s http://localhost:8000/health | jq . || echo "❌ Backend not running"

# Start both backend and iOS simulator
dev: backend-start simulator
	@echo "🚀 Development environment ready!"