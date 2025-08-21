#!/bin/bash

# Claude Code iOS - Release Automation Script
# Build, sign, and deploy releases to TestFlight and App Store

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
readonly EXPORT_OPTIONS_PATH="${BUILD_DIR}/ExportOptions.plist"

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

# Setup directories
setup_directories() {
    log_info "Setting up build directories..."
    mkdir -p "$BUILD_DIR"
    log_success "Directories created"
}

# Check for required tools
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode command line tools not installed"
        exit 1
    fi
    
    if ! command -v xcrun &> /dev/null; then
        log_error "xcrun not available"
        exit 1
    fi
    
    # Check for Fastlane (optional but recommended)
    if ! command -v fastlane &> /dev/null; then
        log_warning "Fastlane not installed. Some features may be limited."
        log_info "Install with: gem install fastlane"
    fi
    
    log_success "Dependencies checked"
}

# Generate Xcode project if needed
ensure_project() {
    if [ ! -d "${PROJECT_ROOT}/ClaudeCode.xcodeproj" ]; then
        log_warning "Xcode project not found. Generating with XcodeGen..."
        if command -v xcodegen &> /dev/null; then
            (cd "$PROJECT_ROOT" && xcodegen)
            log_success "Xcode project generated"
        else
            log_error "XcodeGen not installed. Run: brew install xcodegen"
            exit 1
        fi
    fi
}

# Update version and build number
update_version() {
    local version="$1"
    local build_number="${2:-$(date +%Y%m%d%H%M)}"
    
    log_info "Updating version to $version (build $build_number)..."
    
    # Update Info.plist
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "${PROJECT_ROOT}/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "${PROJECT_ROOT}/Info.plist"
    
    # Update project settings
    agvtool new-marketing-version "$version" 2>/dev/null || true
    agvtool new-version -all "$build_number" 2>/dev/null || true
    
    log_success "Version updated to $version ($build_number)"
}

# Create release archive
create_archive() {
    log_info "Creating release archive..."
    
    xcodebuild archive \
        -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=iOS" \
        -allowProvisioningUpdates \
        CODE_SIGN_STYLE="Automatic" || {
            log_error "Archive creation failed"
            exit 1
        }
    
    log_success "Archive created at: $ARCHIVE_PATH"
}

# Create export options plist
create_export_options() {
    local method="${1:-app-store}"
    
    log_info "Creating export options for method: $method..."
    
    cat > "$EXPORT_OPTIONS_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$method</string>
    <key>teamID</key>
    <string>AUTO</string>
    <key>uploadBitcode</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>generateAppStoreInformation</key>
    <true/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;thin-for-all-variants&gt;</string>
</dict>
</plist>
EOF
    
    log_success "Export options created"
}

# Export IPA from archive
export_ipa() {
    local method="${1:-app-store}"
    
    log_info "Exporting IPA for $method..."
    
    create_export_options "$method"
    
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$BUILD_DIR" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
        -allowProvisioningUpdates || {
            log_error "IPA export failed"
            exit 1
        }
    
    # Rename IPA if needed
    if [ -f "${BUILD_DIR}/ClaudeCode.ipa" ]; then
        mv "${BUILD_DIR}/ClaudeCode.ipa" "$IPA_PATH"
    fi
    
    log_success "IPA exported to: $IPA_PATH"
}

# Upload to TestFlight
upload_testflight() {
    log_info "Uploading to TestFlight..."
    
    if command -v fastlane &> /dev/null; then
        # Use Fastlane if available
        fastlane pilot upload \
            --ipa "$IPA_PATH" \
            --skip_waiting_for_build_processing \
            --skip_submission || {
                log_error "TestFlight upload failed"
                exit 1
            }
    else
        # Use xcrun altool
        xcrun altool --upload-app \
            --type ios \
            --file "$IPA_PATH" \
            --apiKey "${APP_STORE_API_KEY}" \
            --apiIssuer "${APP_STORE_API_ISSUER}" || {
                log_error "TestFlight upload failed"
                log_info "Set APP_STORE_API_KEY and APP_STORE_API_ISSUER environment variables"
                exit 1
            }
    fi
    
    log_success "Successfully uploaded to TestFlight"
}

# Submit to App Store
submit_appstore() {
    log_info "Submitting to App Store..."
    
    if command -v fastlane &> /dev/null; then
        # Use Fastlane if available
        fastlane deliver \
            --ipa "$IPA_PATH" \
            --submit_for_review \
            --automatic_release \
            --force || {
                log_error "App Store submission failed"
                exit 1
            }
    else
        log_warning "App Store submission requires Fastlane"
        log_info "Install with: gem install fastlane"
        log_info "Then run: fastlane deliver --ipa $IPA_PATH"
        exit 1
    fi
    
    log_success "Successfully submitted to App Store"
}

# Validate IPA
validate_ipa() {
    log_info "Validating IPA..."
    
    xcrun altool --validate-app \
        --type ios \
        --file "$IPA_PATH" \
        --apiKey "${APP_STORE_API_KEY}" \
        --apiIssuer "${APP_STORE_API_ISSUER}" || {
            log_warning "IPA validation failed"
            log_info "The IPA may have issues when submitting"
        }
    
    log_success "IPA validation complete"
}

# Create release notes
create_release_notes() {
    local version="$1"
    
    log_info "Creating release notes..."
    
    cat > "${BUILD_DIR}/release_notes.txt" <<EOF
Claude Code iOS v$version

What's New:
- Improved performance and stability
- Bug fixes and enhancements
- Updated UI components

For full changelog, visit: https://github.com/claudecode/ios/releases
EOF
    
    log_success "Release notes created"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "=========================================="
    echo "Claude Code iOS - Release Automation"
    echo "=========================================="
    echo
    
    local action="${1:-help}"
    local version="${2:-1.0.0}"
    
    case "$action" in
        archive)
            setup_directories
            check_dependencies
            ensure_project
            update_version "$version"
            create_archive
            ;;
        
        ipa)
            setup_directories
            export_ipa "app-store"
            validate_ipa
            ;;
        
        testflight)
            setup_directories
            check_dependencies
            ensure_project
            update_version "$version"
            create_archive
            export_ipa "app-store"
            validate_ipa
            upload_testflight
            create_release_notes "$version"
            ;;
        
        appstore)
            setup_directories
            check_dependencies
            ensure_project
            update_version "$version"
            create_archive
            export_ipa "app-store"
            validate_ipa
            submit_appstore
            create_release_notes "$version"
            ;;
        
        validate)
            validate_ipa
            ;;
        
        clean)
            log_info "Cleaning release artifacts..."
            rm -rf "$BUILD_DIR"
            rm -rf "$ARCHIVE_PATH"
            rm -rf "$IPA_PATH"
            log_success "Clean complete"
            ;;
        
        help|--help|-h)
            echo "Usage: $0 [action] [version]"
            echo
            echo "Actions:"
            echo "  archive    - Create release archive"
            echo "  ipa        - Export IPA from archive"
            echo "  testflight - Build and deploy to TestFlight"
            echo "  appstore   - Build and submit to App Store"
            echo "  validate   - Validate IPA file"
            echo "  clean      - Clean release artifacts"
            echo "  help       - Show this help message"
            echo
            echo "Examples:"
            echo "  $0 testflight 1.2.0  - Deploy version 1.2.0 to TestFlight"
            echo "  $0 appstore 2.0.0    - Submit version 2.0.0 to App Store"
            echo
            echo "Environment variables:"
            echo "  APP_STORE_API_KEY    - App Store Connect API Key"
            echo "  APP_STORE_API_ISSUER - App Store Connect API Issuer ID"
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