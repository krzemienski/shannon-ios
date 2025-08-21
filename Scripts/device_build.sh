#!/bin/bash

# Claude Code iOS - Device Build and Installation Script
# Build, sign, and install on physical iOS devices

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly SCHEME_NAME="ClaudeCode"
readonly APP_BUNDLE_ID="com.claudecode.ios"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUILD_DIR="${PROJECT_ROOT}/build"
readonly ARCHIVE_PATH="${BUILD_DIR}/ClaudeCode.xcarchive"
readonly IPA_PATH="${BUILD_DIR}/ClaudeCode.ipa"

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

# Check for connected devices
check_devices() {
    log_info "Checking for connected devices..."
    
    # List connected devices
    local devices=$(xcrun devicectl list devices | grep -E "iPhone|iPad" | grep -v "Simulator")
    
    if [ -z "$devices" ]; then
        log_error "No physical devices connected"
        log_info "Please connect an iOS device via USB or enable wireless debugging"
        
        # Check if ios-deploy is installed for alternative
        if command -v ios-deploy &> /dev/null; then
            log_info "Checking with ios-deploy..."
            ios-deploy -c || true
        fi
        
        exit 1
    fi
    
    log_success "Connected devices found:"
    echo "$devices"
    
    # Get first device UUID
    DEVICE_UUID=$(xcrun devicectl list devices | grep -E "iPhone|iPad" | grep -v "Simulator" | head -1 | awk '{print $NF}' | tr -d '()')
    log_info "Using device: $DEVICE_UUID"
}

# Check code signing
check_code_signing() {
    log_info "Checking code signing configuration..."
    
    # Check for development team
    local team_id=$(defaults read "${PROJECT_ROOT}/ClaudeCode.xcodeproj/project.pbxproj" 2>/dev/null | grep DEVELOPMENT_TEAM | head -1 | awk '{print $3}' | tr -d '";')
    
    if [ -z "$team_id" ]; then
        log_warning "No development team configured"
        log_info "Please configure your development team in Xcode"
        log_info "1. Open ClaudeCode.xcodeproj in Xcode"
        log_info "2. Select the project in the navigator"
        log_info "3. Go to Signing & Capabilities"
        log_info "4. Select your development team"
    else
        log_success "Development team found: $team_id"
    fi
    
    # Check for provisioning profiles
    log_info "Checking provisioning profiles..."
    security find-identity -p codesigning -v | head -5 || true
}

# Build for device
build_for_device() {
    log_info "Building for device..."
    
    # Ensure project exists
    if [ ! -d "${PROJECT_ROOT}/ClaudeCode.xcodeproj" ]; then
        log_warning "Xcode project not found. Generating with XcodeGen..."
        (cd "$PROJECT_ROOT" && xcodegen)
        log_success "Xcode project generated"
    fi
    
    # Build for device
    log_info "Building ClaudeCode for device..."
    
    xcodebuild \
        -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Debug \
        -destination "generic/platform=iOS" \
        -derivedDataPath "$BUILD_DIR" \
        CODE_SIGN_IDENTITY="Apple Development" \
        CODE_SIGN_STYLE="Automatic" \
        DEVELOPMENT_TEAM="AUTO" \
        build || {
            log_error "Build failed"
            log_info "Please check your code signing configuration"
            exit 1
        }
    
    log_success "Build completed successfully"
}

# Archive for device
archive_for_device() {
    log_info "Creating archive for device..."
    
    xcodebuild archive \
        -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=iOS" \
        CODE_SIGN_IDENTITY="Apple Development" \
        CODE_SIGN_STYLE="Automatic" \
        DEVELOPMENT_TEAM="AUTO" || {
            log_error "Archive creation failed"
            exit 1
        }
    
    log_success "Archive created at: $ARCHIVE_PATH"
}

# Export IPA
export_ipa() {
    log_info "Exporting IPA..."
    
    # Create export options plist
    cat > "${BUILD_DIR}/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>AUTO</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>compileBitcode</key>
    <false/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF
    
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$BUILD_DIR" \
        -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" || {
            log_error "IPA export failed"
            exit 1
        }
    
    log_success "IPA exported to: $IPA_PATH"
}

# Install on device using ios-deploy
install_with_ios_deploy() {
    log_info "Installing with ios-deploy..."
    
    if ! command -v ios-deploy &> /dev/null; then
        log_warning "ios-deploy not installed"
        log_info "Install with: brew install ios-deploy"
        return 1
    fi
    
    # Find the app bundle
    local app_path=$(find "$BUILD_DIR" -name "*.app" -type d | head -n 1)
    
    if [ -z "$app_path" ]; then
        log_error "App bundle not found"
        return 1
    fi
    
    log_info "Installing $app_path..."
    ios-deploy --bundle "$app_path" --debug --no-wifi || {
        log_error "Installation failed"
        return 1
    }
    
    log_success "App installed and launched"
    return 0
}

# Install on device using devicectl
install_with_devicectl() {
    log_info "Installing with devicectl..."
    
    # Find the app bundle
    local app_path=$(find "$BUILD_DIR" -name "*.app" -type d | head -n 1)
    
    if [ -z "$app_path" ]; then
        log_error "App bundle not found"
        return 1
    fi
    
    log_info "Installing $app_path on device $DEVICE_UUID..."
    
    xcrun devicectl device install app \
        --device "$DEVICE_UUID" \
        "$app_path" || {
            log_error "Installation failed"
            return 1
        }
    
    log_success "App installed successfully"
    
    # Launch the app
    log_info "Launching app..."
    xcrun devicectl device process launch \
        --device "$DEVICE_UUID" \
        --bundle-identifier "$APP_BUNDLE_ID" || {
            log_warning "Launch failed - please launch manually"
        }
    
    return 0
}

# Run tests on device
run_tests_on_device() {
    log_info "Running tests on device..."
    
    xcodebuild test \
        -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination "id=$DEVICE_UUID" \
        -derivedDataPath "$BUILD_DIR" \
        CODE_SIGN_IDENTITY="Apple Development" \
        CODE_SIGN_STYLE="Automatic" \
        DEVELOPMENT_TEAM="AUTO" || {
            log_error "Tests failed"
            exit 1
        }
    
    log_success "Tests completed on device"
}

# Clean build artifacts
clean_build() {
    log_info "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"
    rm -rf "$ARCHIVE_PATH"
    rm -rf "$IPA_PATH"
    log_success "Clean complete"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "=========================================="
    echo "Claude Code iOS - Device Build & Install"
    echo "=========================================="
    echo
    
    # Parse command line arguments
    local action="${1:-install}"
    
    case "$action" in
        install)
            check_devices
            check_code_signing
            build_for_device
            
            # Try devicectl first, then ios-deploy
            if ! install_with_devicectl; then
                log_info "Trying alternative installation method..."
                install_with_ios_deploy
            fi
            ;;
        
        build)
            check_devices
            check_code_signing
            build_for_device
            ;;
        
        archive)
            check_code_signing
            archive_for_device
            ;;
        
        export)
            check_code_signing
            archive_for_device
            export_ipa
            ;;
        
        test)
            check_devices
            check_code_signing
            run_tests_on_device
            ;;
        
        clean)
            clean_build
            ;;
        
        check)
            check_devices
            check_code_signing
            ;;
        
        help|--help|-h)
            echo "Usage: $0 [action]"
            echo
            echo "Actions:"
            echo "  install  - Build and install on device (default)"
            echo "  build    - Build for device only"
            echo "  archive  - Create release archive"
            echo "  export   - Export IPA file"
            echo "  test     - Run tests on device"
            echo "  clean    - Clean build artifacts"
            echo "  check    - Check device and signing status"
            echo "  help     - Show this help message"
            echo
            echo "Requirements:"
            echo "  - Physical iOS device connected"
            echo "  - Valid development certificate"
            echo "  - Xcode configured with development team"
            echo
            echo "Optional tools for better experience:"
            echo "  - ios-deploy: brew install ios-deploy"
            ;;
        
        *)
            log_error "Unknown action: $action"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"