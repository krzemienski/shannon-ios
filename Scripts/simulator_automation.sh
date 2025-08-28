#!/bin/bash

# Claude Code iOS - Simulator Automation Script
# iPhone 16 Pro Max (iOS 18.6) Build, Log, and Launch Automation

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

# Persistent Simulator UUID for iPhone 16 Pro Max (iOS 18.6)
readonly SIMULATOR_UUID="A707456B-44DB-472F-9722-C88153CDFFA1"
readonly APP_BUNDLE_ID="com.claudecodeswift.ios"
readonly SCHEME_NAME="ClaudeCodeSwift"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LOGS_DIR="${PROJECT_ROOT}/logs"
readonly BUILD_DIR="${PROJECT_ROOT}/build"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ============================================================================
# FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create necessary directories
setup_directories() {
    log_info "Setting up directories..."
    mkdir -p "$LOGS_DIR"
    mkdir -p "$BUILD_DIR"
    log_success "Directories created"
}

# Check if simulator exists and is available
check_simulator() {
    log_info "Checking simulator availability..."
    
    if xcrun simctl list devices | grep -q "$SIMULATOR_UUID"; then
        log_success "Simulator found: $SIMULATOR_UUID"
        
        # Get simulator status
        local status=$(xcrun simctl list devices | grep "$SIMULATOR_UUID" | sed 's/.*(\(.*\))/\1/')
        log_info "Simulator status: $status"
        
        # Boot simulator if needed
        if [[ "$status" == "Shutdown" ]]; then
            log_info "Booting simulator..."
            xcrun simctl boot "$SIMULATOR_UUID"
            sleep 5  # Give it time to boot
            log_success "Simulator booted"
        fi
    else
        log_error "Simulator not found: $SIMULATOR_UUID"
        log_info "Available simulators:"
        xcrun simctl list devices | grep "iPhone 16 Pro Max"
        exit 1
    fi
}

# Start log capture in background
start_log_capture() {
    local log_file="${LOGS_DIR}/simulator_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "Starting log capture..."
    log_info "Log file: $log_file"
    
    # Kill any existing log processes for this simulator
    pkill -f "simctl spawn $SIMULATOR_UUID log" 2>/dev/null || true
    
    # Start new log capture
    xcrun simctl spawn "$SIMULATOR_UUID" log stream \
        --level=debug \
        --style=syslog \
        --predicate 'processImagePath CONTAINS "ClaudeCodeSwift"' \
        > "$log_file" 2>&1 &
    
    LOG_PID=$!
    echo "$LOG_PID" > "${LOGS_DIR}/.log_pid"
    
    log_success "Log capture started (PID: $LOG_PID)"
    
    # Create symlink to latest log
    ln -sf "$log_file" "${LOGS_DIR}/latest.log"
}

# Build the app
build_app() {
    log_info "Building app..."
    log_info "Scheme: $SCHEME_NAME"
    log_info "Destination: iPhone 16 Pro Max (iOS 18.6)"
    
    # Set PKG_CONFIG_PATH for libssh2 (Shout dependency)
    export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/opt/libssh2/lib/pkgconfig:/opt/homebrew/opt/openssl@3/lib/pkgconfig"
    log_info "PKG_CONFIG_PATH set for libssh2"
    
    # Check if xcodeproj exists
    if [ ! -d "${PROJECT_ROOT}/ClaudeCodeSwift.xcodeproj" ]; then
        log_warning "Xcode project not found. Generating with XcodeGen..."
        if command -v xcodegen &> /dev/null; then
            (cd "$PROJECT_ROOT" && PKG_CONFIG_PATH="$PKG_CONFIG_PATH" xcodegen)
            log_success "Xcode project generated"
        else
            log_error "XcodeGen not installed. Run: brew install xcodegen"
            exit 1
        fi
    fi
    
    # Build with xcodebuild (with PKG_CONFIG_PATH for libssh2)
    # Use specific derived data path
    local derived_data="${PROJECT_ROOT}/build/DerivedData"
    
    if command -v xcbeautify &> /dev/null; then
        PKG_CONFIG_PATH="$PKG_CONFIG_PATH" xcodebuild \
            -project "${PROJECT_ROOT}/ClaudeCodeSwift.xcodeproj" \
            -scheme "$SCHEME_NAME" \
            -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
            -derivedDataPath "$derived_data" \
            clean build \
            | xcbeautify || {
                log_error "Build failed"
                exit 1
            }
    else
        PKG_CONFIG_PATH="$PKG_CONFIG_PATH" xcodebuild \
            -project "${PROJECT_ROOT}/ClaudeCodeSwift.xcodeproj" \
            -scheme "$SCHEME_NAME" \
            -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
            -derivedDataPath "$derived_data" \
            clean build || {
                log_error "Build failed"
                exit 1
            }
    fi
    
    log_success "Build completed successfully"
}

# Install and launch app
install_and_launch() {
    log_info "Installing app on simulator..."
    
    # Find the app bundle in our specific derived data location
    local derived_data="${PROJECT_ROOT}/build/DerivedData"
    local app_path=$(find "$derived_data"/Build/Products/Debug-iphonesimulator -name "ClaudeCodeSwift.app" -type d 2>/dev/null | head -n 1)
    
    if [ -z "$app_path" ]; then
        log_error "App bundle not found in DerivedData"
        exit 1
    fi
    
    log_info "App bundle: $app_path"
    
    # Uninstall existing app (if any)
    xcrun simctl uninstall "$SIMULATOR_UUID" "$APP_BUNDLE_ID" 2>/dev/null || true
    
    # Install new app
    xcrun simctl install "$SIMULATOR_UUID" "$app_path"
    log_success "App installed"
    
    # Launch app
    log_info "Launching app..."
    xcrun simctl launch "$SIMULATOR_UUID" "$APP_BUNDLE_ID"
    log_success "App launched"
    
    # Open simulator window
    open -a Simulator
}

# Stop log capture
stop_log_capture() {
    if [ -f "${LOGS_DIR}/.log_pid" ]; then
        local pid=$(cat "${LOGS_DIR}/.log_pid")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping log capture (PID: $pid)..."
            kill "$pid"
            rm "${LOGS_DIR}/.log_pid"
            log_success "Log capture stopped"
        fi
    fi
}

# Clean up on exit
cleanup() {
    log_info "Cleaning up..."
    stop_log_capture
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "=========================================="
    echo "Claude Code iOS - Simulator Automation"
    echo "iPhone 16 Pro Max (iOS 18.6)"
    echo "UUID: $SIMULATOR_UUID"
    echo "=========================================="
    echo
    
    # Set up trap for cleanup
    trap cleanup EXIT
    
    # Parse command line arguments
    case "${1:-all}" in
        logs)
            setup_directories
            check_simulator
            start_log_capture
            log_info "Log capture running. Press Ctrl+C to stop."
            wait $LOG_PID
            ;;
        build)
            setup_directories
            check_simulator
            start_log_capture
            build_app
            ;;
        launch)
            check_simulator
            install_and_launch
            ;;
        all|"")
            setup_directories
            check_simulator
            start_log_capture
            build_app
            install_and_launch
            log_success "Complete workflow executed successfully!"
            log_info "Logs available at: ${LOGS_DIR}/latest.log"
            ;;
        clean)
            log_info "Cleaning build artifacts..."
            rm -rf "$BUILD_DIR"
            log_success "Build directory cleaned"
            ;;
        status)
            check_simulator
            ;;
        test)
            setup_directories
            check_simulator
            start_log_capture
            log_info "Running tests..."
            
            # Set PKG_CONFIG_PATH for libssh2
            export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/opt/libssh2/lib/pkgconfig:/opt/homebrew/opt/openssl@3/lib/pkgconfig"
            
            # Generate project if needed
            if [ ! -d "${PROJECT_ROOT}/ClaudeCodeSwift.xcodeproj" ]; then
                log_warning "Xcode project not found. Generating with XcodeGen..."
                (cd "$PROJECT_ROOT" && PKG_CONFIG_PATH="$PKG_CONFIG_PATH" xcodegen)
                log_success "Xcode project generated"
            fi
            
            # Run unit tests
            log_info "Running unit tests..."
            PKG_CONFIG_PATH="$PKG_CONFIG_PATH" xcodebuild test \
                -project "${PROJECT_ROOT}/ClaudeCodeSwift.xcodeproj" \
                -scheme "$SCHEME_NAME" \
                -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
                -derivedDataPath "$BUILD_DIR" \
                -enableCodeCoverage YES \
                2>&1 | tee "${LOGS_DIR}/test_$(date +%Y%m%d_%H%M%S).log" | xcbeautify || {
                    log_error "Tests failed"
                    exit 1
                }
            
            log_success "All tests passed!"
            
            # Generate coverage report if xcov is installed
            if command -v xcov &> /dev/null; then
                log_info "Generating coverage report..."
                xcov --project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
                     --scheme "$SCHEME_NAME" \
                     --output_directory "${PROJECT_ROOT}/coverage" \
                     --derived_data_path "$BUILD_DIR"
                log_success "Coverage report generated in coverage/"
            fi
            ;;
        uitest)
            setup_directories
            check_simulator
            start_log_capture
            log_info "Running UI tests..."
            
            # Set PKG_CONFIG_PATH for libssh2
            export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/opt/libssh2/lib/pkgconfig:/opt/homebrew/opt/openssl@3/lib/pkgconfig"
            
            # Generate project if needed
            if [ ! -d "${PROJECT_ROOT}/ClaudeCodeSwift.xcodeproj" ]; then
                log_warning "Xcode project not found. Generating with XcodeGen..."
                (cd "$PROJECT_ROOT" && PKG_CONFIG_PATH="$PKG_CONFIG_PATH" xcodegen)
                log_success "Xcode project generated"
            fi
            
            # Build and install app first
            build_app
            install_and_launch
            
            # Parse additional arguments for specific tests
            local test_args=""
            local test_type="${2:-standard}"
            
            case "$test_type" in
                backend)
                    log_info "Running ALL tests against REAL BACKEND at http://localhost:8000/v1/"
                    log_warning "⚠️  IMPORTANT: Ensure backend is running at http://localhost:8000"
                    
                    # Check backend is accessible
                    if ! curl -f -s -o /dev/null "http://localhost:8000/v1/health" 2>/dev/null; then
                        log_error "Backend is not accessible at http://localhost:8000/v1/"
                        log_error "Please start the backend server first!"
                        exit 1
                    fi
                    log_success "Backend is accessible"
                    
                    test_args="-only-testing:ClaudeCodeUITests"
                    
                    # Set environment variables for real backend testing
                    export API_BASE_URL="http://localhost:8000/v1/"
                    export TEST_MODE="YES"
                    export TEST_API_KEY="${TEST_API_KEY:-sk-test-key-12345}"
                    export TEST_USERNAME="${TEST_USERNAME:-test@claudecode.com}"
                    export TEST_PASSWORD="${TEST_PASSWORD:-TestPassword123!}"
                    export TEST_SSH_HOST="${TEST_SSH_HOST:-localhost}"
                    export TEST_SSH_PORT="${TEST_SSH_PORT:-2222}"
                    export TEST_SSH_USER="${TEST_SSH_USER:-testuser}"
                    export TEST_SSH_PASSWORD="${TEST_SSH_PASSWORD:-testpass123}"
                    
                    log_info "API Base URL: $API_BASE_URL"
                    log_info "Test API Key: ${TEST_API_KEY:0:10}..."
                    ;;
                auth)
                    log_info "Running Authentication tests against real backend..."
                    test_args="-only-testing:ClaudeCodeUITests/AuthenticationTests"
                    export API_BASE_URL="http://localhost:8000/v1/"
                    ;;
                chat)
                    log_info "Running Chat & Streaming tests against real backend..."
                    test_args="-only-testing:ClaudeCodeUITests/ChatStreamingTests"
                    export API_BASE_URL="http://localhost:8000/v1/"
                    ;;
                projects)
                    log_info "Running Project Management tests against real backend..."
                    test_args="-only-testing:ClaudeCodeUITests/ProjectManagementTests"
                    export API_BASE_URL="http://localhost:8000/v1/"
                    ;;
                files)
                    log_info "Running File Operations tests against real backend..."
                    test_args="-only-testing:ClaudeCodeUITests/FileOperationsTests"
                    export API_BASE_URL="http://localhost:8000/v1/"
                    ;;
                ssh)
                    log_info "Running SSH Terminal tests against real backend..."
                    test_args="-only-testing:ClaudeCodeUITests/SSHTerminalTests"
                    export API_BASE_URL="http://localhost:8000/v1/"
                    ;;
                comprehensive)
                    log_info "Running COMPREHENSIVE test suite against real backend..."
                    test_args="-only-testing:ClaudeCodeUITests/ComprehensiveTestSuite"
                    export API_BASE_URL="http://localhost:8000/v1/"
                    ;;
                functional)
                    log_info "Running functional UI tests with real backend..."
                    test_args="-only-testing:ClaudeCodeUITests/ProjectFlowTests -only-testing:ClaudeCodeUITests/SessionFlowTests -only-testing:ClaudeCodeUITests/MessagingFlowTests -only-testing:ClaudeCodeUITests/MonitoringFlowTests -only-testing:ClaudeCodeUITests/MCPConfigurationTests"
                    
                    # Set environment variables for functional testing
                    export BACKEND_URL="${BACKEND_URL:-http://localhost:8000}"
                    export NETWORK_TIMEOUT="${NETWORK_TIMEOUT:-30}"
                    export UI_WAIT_TIMEOUT="${UI_WAIT_TIMEOUT:-15}"
                    export VERBOSE_LOGGING="${VERBOSE_LOGGING:-true}"
                    export CLEANUP_AFTER_TESTS="${CLEANUP_AFTER_TESTS:-true}"
                    
                    log_info "Backend URL: $BACKEND_URL"
                    log_info "Network timeout: ${NETWORK_TIMEOUT}s"
                    log_info "UI wait timeout: ${UI_WAIT_TIMEOUT}s"
                    ;;
                standard)
                    log_info "Running standard UI tests..."
                    test_args="-only-testing:ClaudeCodeUITests"
                    ;;
                *)
                    # Specific test class
                    log_info "Running specific test class: $test_type"
                    test_args="-only-testing:ClaudeCodeUITests/$test_type"
                    ;;
            esac
            
            # Run UI tests
            log_info "Executing tests with args: $test_args"
            PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
            API_BASE_URL="${API_BASE_URL:-http://localhost:8000/v1/}" \
            TEST_MODE="${TEST_MODE:-YES}" \
            TEST_API_KEY="$TEST_API_KEY" \
            TEST_USERNAME="$TEST_USERNAME" \
            TEST_PASSWORD="$TEST_PASSWORD" \
            TEST_SSH_HOST="$TEST_SSH_HOST" \
            TEST_SSH_PORT="$TEST_SSH_PORT" \
            TEST_SSH_USER="$TEST_SSH_USER" \
            TEST_SSH_PASSWORD="$TEST_SSH_PASSWORD" \
            BACKEND_URL="$BACKEND_URL" \
            NETWORK_TIMEOUT="$NETWORK_TIMEOUT" \
            UI_WAIT_TIMEOUT="$UI_WAIT_TIMEOUT" \
            VERBOSE_LOGGING="$VERBOSE_LOGGING" \
            CLEANUP_AFTER_TESTS="$CLEANUP_AFTER_TESTS" \
            xcodebuild test \
                -project "${PROJECT_ROOT}/ClaudeCodeSwift.xcodeproj" \
                -scheme "$SCHEME_NAME" \
                -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
                -derivedDataPath "$BUILD_DIR" \
                $test_args \
                2>&1 | tee "${LOGS_DIR}/uitest_$(date +%Y%m%d_%H%M%S).log" | xcbeautify || {
                    log_error "UI tests failed"
                    exit 1
                }
            
            log_success "UI tests completed!"
            ;;
        help|--help|-h)
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  all     - Run complete workflow (default)"
            echo "  logs    - Start log capture only"
            echo "  build   - Build app with logging"
            echo "  launch  - Install and launch app"
            echo "  test    - Run all unit tests with coverage"
            echo "  uitest [type|class] - Run UI tests against REAL BACKEND"
            echo "    uitest backend      - Run ALL tests against real backend (comprehensive)"
            echo "    uitest auth         - Run authentication tests only"
            echo "    uitest chat         - Run chat & streaming tests only"
            echo "    uitest projects     - Run project management tests only"
            echo "    uitest files        - Run file operations tests only"
            echo "    uitest ssh          - Run SSH terminal tests only"
            echo "    uitest comprehensive - Run comprehensive test suite"
            echo "    uitest functional   - Run functional tests with real backend"
            echo "    uitest standard     - Run standard UI tests (default)"
            echo "    uitest [ClassName]  - Run specific test class"
            echo "  clean   - Clean build artifacts"
            echo "  status  - Check simulator status"
            echo "  help    - Show this help message"
            echo
            echo "Environment Variables for Testing:"
            echo "  TEST_API_KEY      - API key for authentication tests"
            echo "  TEST_USERNAME     - Username for test account"
            echo "  TEST_PASSWORD     - Password for test account"
            echo "  TEST_SSH_HOST     - SSH host for terminal tests"
            echo "  TEST_SSH_PORT     - SSH port for terminal tests"
            echo "  TEST_SSH_USER     - SSH username"
            echo "  TEST_SSH_PASSWORD - SSH password"
            echo
            echo "Example Usage:"
            echo "  # Run all tests against real backend"
            echo "  ./Scripts/simulator_automation.sh uitest backend"
            echo
            echo "  # Run specific test category"
            echo "  ./Scripts/simulator_automation.sh uitest auth"
            echo
            echo "  # Run with custom test credentials"
            echo "  TEST_API_KEY='sk-real-key' ./Scripts/simulator_automation.sh uitest backend"
            echo
            echo "Environment:"
            echo "  Simulator UUID: $SIMULATOR_UUID"
            echo "  Bundle ID: $APP_BUNDLE_ID"
            echo "  Backend URL: http://localhost:8000/v1/"
            echo "  Logs: ${LOGS_DIR}/"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"