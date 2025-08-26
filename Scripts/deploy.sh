#!/bin/bash

# Claude Code iOS - Comprehensive Deployment Automation
# One-command deployment to TestFlight and App Store
# Author: Claude Code Team
# Version: 2.0.0

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# ============================================================================
# CONFIGURATION
# ============================================================================

# Project settings
readonly SCHEME_NAME="ClaudeCode"
readonly APP_BUNDLE_ID="com.claudecode.ios"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUILD_DIR="${PROJECT_ROOT}/build"
readonly LOGS_DIR="${PROJECT_ROOT}/logs"
readonly REPORTS_DIR="${PROJECT_ROOT}/reports"
readonly METADATA_DIR="${PROJECT_ROOT}/fastlane/metadata"

# Deployment settings
readonly DEFAULT_BRANCH="main"
readonly VERSION_FILE="${PROJECT_ROOT}/.version"
readonly CHANGELOG_FILE="${PROJECT_ROOT}/CHANGELOG.md"
readonly RELEASE_NOTES_TEMPLATE="${PROJECT_ROOT}/Scripts/templates/release_notes.md"

# Environment detection
readonly IS_CI="${CI:-false}"
readonly BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Logging functions
log_header() {
    echo
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD} $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ [SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️  [WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}❌ [ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "${MAGENTA}▶ $1${NC}"
}

# Progress indicator
show_progress() {
    local message="$1"
    echo -ne "${BLUE}⏳ ${message}...${NC}"
}

complete_progress() {
    echo -e "\r${GREEN}✅ $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Ensure directory exists
ensure_dir() {
    mkdir -p "$1"
}

# Read version from file or default
get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "1.0.0"
    fi
}

# Save version to file
save_version() {
    echo "$1" > "$VERSION_FILE"
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_prerequisites() {
    log_header "Checking Prerequisites"
    
    local missing_tools=()
    
    # Required tools
    local required_tools=(
        "xcodebuild:Xcode Command Line Tools"
        "xcrun:Xcode Tools"
        "git:Version Control"
        "jq:JSON Processor"
    )
    
    for tool_spec in "${required_tools[@]}"; do
        IFS=':' read -r tool description <<< "$tool_spec"
        if ! command_exists "$tool"; then
            missing_tools+=("$description ($tool)")
        else
            log_success "$description installed"
        fi
    done
    
    # Optional but recommended tools
    local optional_tools=(
        "fastlane:Deployment Automation"
        "xcpretty:Build Output Formatter"
        "xcodegen:Project Generation"
        "swiftlint:Code Linter"
    )
    
    for tool_spec in "${optional_tools[@]}"; do
        IFS=':' read -r tool description <<< "$tool_spec"
        if ! command_exists "$tool"; then
            log_warning "$description not installed (optional)"
        else
            log_success "$description installed"
        fi
    done
    
    # Check for missing required tools
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo
        echo "Install missing tools and try again."
        exit 1
    fi
    
    # Check Xcode version
    local xcode_version
    xcode_version=$(xcodebuild -version | head -1 | awk '{print $2}')
    log_info "Xcode version: $xcode_version"
    
    # Check for certificates and provisioning profiles
    log_step "Checking code signing..."
    if security find-identity -p codesigning -v | grep -q "Developer ID"; then
        log_success "Code signing certificates found"
    else
        log_warning "No code signing certificates found - will use automatic signing"
    fi
}

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

setup_environment() {
    log_header "Setting Up Environment"
    
    # Create necessary directories
    ensure_dir "$BUILD_DIR"
    ensure_dir "$LOGS_DIR"
    ensure_dir "$REPORTS_DIR"
    ensure_dir "$METADATA_DIR"
    
    # Setup log file for this run
    export DEPLOY_LOG="${LOGS_DIR}/deploy_$(date +%Y%m%d_%H%M%S).log"
    exec 2> >(tee -a "$DEPLOY_LOG" >&2)
    
    log_success "Environment directories created"
    
    # Load environment variables if available
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        log_step "Loading environment variables..."
        # shellcheck disable=SC1091
        source "${PROJECT_ROOT}/.env"
        log_success "Environment variables loaded"
    fi
    
    # Setup Fastlane environment
    if command_exists fastlane; then
        export FASTLANE_SKIP_UPDATE_CHECK="true"
        export FASTLANE_HIDE_CHANGELOG="true"
        
        if [[ "$IS_CI" == "true" ]]; then
            export FASTLANE_DISABLE_COLORS="true"
            export FASTLANE_DISABLE_OUTPUT_FORMAT="true"
        fi
        
        log_success "Fastlane environment configured"
    fi
}

# ============================================================================
# VERSION MANAGEMENT
# ============================================================================

bump_version() {
    local bump_type="${1:-patch}"
    local current_version
    current_version=$(get_current_version)
    
    log_header "Version Management"
    log_info "Current version: $current_version"
    
    # Parse version components
    IFS='.' read -r major minor patch <<< "$current_version"
    
    # Calculate new version
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid bump type: $bump_type"
            exit 1
            ;;
    esac
    
    local new_version="${major}.${minor}.${patch}"
    log_info "New version: $new_version"
    
    # Update version in project
    update_project_version "$new_version"
    
    # Save version
    save_version "$new_version"
    
    echo "$new_version"
}

update_project_version() {
    local version="$1"
    local build="${2:-$BUILD_NUMBER}"
    
    log_step "Updating project version to $version ($build)..."
    
    # Update Info.plist
    if [[ -f "${PROJECT_ROOT}/Info.plist" ]]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "${PROJECT_ROOT}/Info.plist"
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "${PROJECT_ROOT}/Info.plist"
    fi
    
    # Update with agvtool if available
    if command_exists agvtool; then
        (cd "$PROJECT_ROOT" && agvtool new-marketing-version "$version" &>/dev/null || true)
        (cd "$PROJECT_ROOT" && agvtool new-version -all "$build" &>/dev/null || true)
    fi
    
    # Update using Fastlane if available
    if command_exists fastlane; then
        (cd "$PROJECT_ROOT" && \
            fastlane run increment_version_number version_number:"$version" &>/dev/null || true)
        (cd "$PROJECT_ROOT" && \
            fastlane run increment_build_number build_number:"$build" &>/dev/null || true)
    fi
    
    log_success "Version updated to $version ($build)"
}

# ============================================================================
# GIT OPERATIONS
# ============================================================================

ensure_clean_git() {
    log_step "Checking git status..."
    
    if [[ "$IS_CI" == "true" ]]; then
        log_info "Running in CI, skipping git checks"
        return 0
    fi
    
    if ! git diff-index --quiet HEAD --; then
        log_warning "Uncommitted changes detected"
        
        if [[ "${FORCE:-false}" != "true" ]]; then
            log_error "Please commit or stash changes before deploying"
            log_info "Use --force to override this check"
            exit 1
        fi
        
        log_warning "Proceeding with uncommitted changes (forced)"
    else
        log_success "Git working directory clean"
    fi
}

create_release_tag() {
    local version="$1"
    local tag_name="v$version"
    
    if [[ "$IS_CI" == "true" ]] || [[ "${SKIP_TAG:-false}" == "true" ]]; then
        log_info "Skipping tag creation"
        return 0
    fi
    
    log_step "Creating release tag $tag_name..."
    
    # Check if tag already exists
    if git tag -l "$tag_name" | grep -q "$tag_name"; then
        log_warning "Tag $tag_name already exists"
        return 0
    fi
    
    # Create annotated tag
    git tag -a "$tag_name" -m "Release $version

$(generate_release_notes "$version")" || {
        log_warning "Failed to create tag"
        return 1
    }
    
    log_success "Tag $tag_name created"
    
    # Push tag to remote
    if [[ "${PUSH_TAG:-true}" == "true" ]]; then
        log_step "Pushing tag to remote..."
        git push origin "$tag_name" || log_warning "Failed to push tag"
    fi
}

# ============================================================================
# RELEASE NOTES GENERATION
# ============================================================================

generate_release_notes() {
    local version="${1:-$(get_current_version)}"
    local output_file="${REPORTS_DIR}/release_notes_${version}.md"
    
    log_header "Generating Release Notes"
    
    # Get commits since last tag
    local last_tag
    last_tag=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
    
    local commit_range
    if [[ -n "$last_tag" ]]; then
        commit_range="${last_tag}..HEAD"
    else
        commit_range="HEAD~10..HEAD"
    fi
    
    # Generate release notes
    cat > "$output_file" <<EOF
# Claude Code iOS v${version}

## 🎉 Release Information
- **Version**: ${version}
- **Build**: ${BUILD_NUMBER}
- **Date**: $(date +"%Y-%m-%d")
- **Branch**: $(git rev-parse --abbrev-ref HEAD)
- **Commit**: $(git rev-parse --short HEAD)

## ✨ What's New

### Features
EOF
    
    # Add feature commits
    git log "$commit_range" --pretty=format:"- %s" --grep="feat:" >> "$output_file"
    echo >> "$output_file"
    
    cat >> "$output_file" <<EOF

### Improvements
EOF
    
    # Add improvement commits
    git log "$commit_range" --pretty=format:"- %s" --grep="improve\|enhance\|optimize" >> "$output_file"
    echo >> "$output_file"
    
    cat >> "$output_file" <<EOF

### Bug Fixes
EOF
    
    # Add bug fix commits
    git log "$commit_range" --pretty=format:"- %s" --grep="fix:" >> "$output_file"
    echo >> "$output_file"
    
    cat >> "$output_file" <<EOF

### Other Changes
EOF
    
    # Add other commits
    git log "$commit_range" --pretty=format:"- %s" | \
        grep -v -E "feat:|fix:|improve|enhance|optimize" >> "$output_file"
    echo >> "$output_file"
    
    cat >> "$output_file" <<EOF

## 📱 Requirements
- iOS 17.0 or later
- iPhone or iPad
- ~50MB storage space

## 🔗 Links
- [Documentation](https://docs.claudecode.app)
- [Support](https://support.claudecode.app)
- [Privacy Policy](https://claudecode.app/privacy)

---
*Generated on $(date +"%Y-%m-%d %H:%M:%S")*
EOF
    
    log_success "Release notes generated: $output_file"
    
    # Return the content for inline use
    cat "$output_file"
}

# ============================================================================
# BUILD OPERATIONS
# ============================================================================

build_app() {
    local configuration="${1:-Release}"
    local export_method="${2:-app-store}"
    
    log_header "Building Application"
    log_info "Configuration: $configuration"
    log_info "Export method: $export_method"
    
    # Generate project if needed
    if [[ ! -d "${PROJECT_ROOT}/ClaudeCode.xcodeproj" ]]; then
        if command_exists xcodegen; then
            log_step "Generating Xcode project..."
            (cd "$PROJECT_ROOT" && xcodegen generate)
            log_success "Project generated"
        else
            log_error "Xcode project not found and XcodeGen not installed"
            exit 1
        fi
    fi
    
    # Clean build directory
    log_step "Cleaning build directory..."
    rm -rf "${BUILD_DIR:?}/"*
    
    # Build archive
    log_step "Building archive..."
    local archive_path="${BUILD_DIR}/ClaudeCode.xcarchive"
    
    xcodebuild archive \
        -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration "$configuration" \
        -archivePath "$archive_path" \
        -destination "generic/platform=iOS" \
        -allowProvisioningUpdates \
        CODE_SIGNING_ALLOWED=YES \
        CODE_SIGN_STYLE="Automatic" \
        DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}" \
        | tee "${LOGS_DIR}/build.log" \
        | xcpretty --color || {
            log_error "Archive build failed"
            exit 1
        }
    
    log_success "Archive created successfully"
    
    # Export IPA
    log_step "Exporting IPA..."
    local export_options="${BUILD_DIR}/ExportOptions.plist"
    
    # Create export options plist
    create_export_options "$export_method"
    
    xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$BUILD_DIR" \
        -exportOptionsPlist "$export_options" \
        -allowProvisioningUpdates \
        | tee -a "${LOGS_DIR}/build.log" \
        | xcpretty --color || {
            log_error "IPA export failed"
            exit 1
        }
    
    log_success "IPA exported successfully"
    
    # Rename IPA for clarity
    if [[ -f "${BUILD_DIR}/${SCHEME_NAME}.ipa" ]]; then
        local version
        version=$(get_current_version)
        local ipa_name="ClaudeCode_${version}_${BUILD_NUMBER}.ipa"
        mv "${BUILD_DIR}/${SCHEME_NAME}.ipa" "${BUILD_DIR}/${ipa_name}"
        log_info "IPA renamed to: $ipa_name"
    fi
}

create_export_options() {
    local method="${1:-app-store}"
    local export_options="${BUILD_DIR}/ExportOptions.plist"
    
    log_step "Creating export options for $method..."
    
    cat > "$export_options" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$method</string>
    <key>teamID</key>
    <string>${DEVELOPMENT_TEAM:-AUTO}</string>
    <key>uploadBitcode</key>
    <false/>
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
    <key>provisioningProfiles</key>
    <dict>
        <key>${APP_BUNDLE_ID}</key>
        <string>Automatic</string>
    </dict>
</dict>
</plist>
EOF
    
    log_success "Export options created"
}

# ============================================================================
# DEPLOYMENT OPERATIONS
# ============================================================================

deploy_testflight() {
    local ipa_path="${1:-${BUILD_DIR}/ClaudeCode*.ipa}"
    
    log_header "Deploying to TestFlight"
    
    # Find IPA file
    ipa_path=$(ls $ipa_path 2>/dev/null | head -1)
    if [[ ! -f "$ipa_path" ]]; then
        log_error "IPA file not found"
        exit 1
    fi
    
    log_info "IPA: $(basename "$ipa_path")"
    
    # Validate IPA first
    validate_ipa "$ipa_path"
    
    # Deploy using Fastlane if available
    if command_exists fastlane; then
        log_step "Deploying with Fastlane..."
        
        (cd "$PROJECT_ROOT" && \
            fastlane pilot upload \
                --ipa "$ipa_path" \
                --skip_waiting_for_build_processing \
                --skip_submission \
                --changelog "$(generate_release_notes | head -20)") || {
            log_error "Fastlane deployment failed"
            exit 1
        }
    else
        # Use xcrun altool as fallback
        log_step "Deploying with altool..."
        
        if [[ -z "${APP_STORE_API_KEY:-}" ]] || [[ -z "${APP_STORE_API_ISSUER:-}" ]]; then
            log_error "App Store Connect API credentials not set"
            log_info "Set APP_STORE_API_KEY and APP_STORE_API_ISSUER environment variables"
            exit 1
        fi
        
        xcrun altool --upload-app \
            --type ios \
            --file "$ipa_path" \
            --apiKey "$APP_STORE_API_KEY" \
            --apiIssuer "$APP_STORE_API_ISSUER" || {
            log_error "altool deployment failed"
            exit 1
        }
    fi
    
    log_success "Successfully deployed to TestFlight!"
    
    # Generate TestFlight link
    local version
    version=$(get_current_version)
    log_info "TestFlight link will be available at:"
    log_info "https://testflight.apple.com/join/YOUR_PUBLIC_LINK"
    
    # Send notifications if configured
    send_deployment_notification "testflight" "$version"
}

deploy_appstore() {
    local ipa_path="${1:-${BUILD_DIR}/ClaudeCode*.ipa}"
    
    log_header "Deploying to App Store"
    
    # Find IPA file
    ipa_path=$(ls $ipa_path 2>/dev/null | head -1)
    if [[ ! -f "$ipa_path" ]]; then
        log_error "IPA file not found"
        exit 1
    fi
    
    log_info "IPA: $(basename "$ipa_path")"
    
    # Validate IPA
    validate_ipa "$ipa_path"
    
    # Prepare metadata
    prepare_appstore_metadata
    
    # Deploy using Fastlane
    if ! command_exists fastlane; then
        log_error "App Store deployment requires Fastlane"
        log_info "Install with: gem install fastlane"
        exit 1
    fi
    
    log_step "Deploying to App Store..."
    
    (cd "$PROJECT_ROOT" && \
        fastlane deliver \
            --ipa "$ipa_path" \
            --submit_for_review \
            --automatic_release \
            --force \
            --skip_screenshots) || {
        log_error "App Store deployment failed"
        exit 1
    }
    
    log_success "Successfully submitted to App Store!"
    
    # Send notifications
    local version
    version=$(get_current_version)
    send_deployment_notification "appstore" "$version"
}

validate_ipa() {
    local ipa_path="$1"
    
    log_step "Validating IPA..."
    
    # Basic file validation
    if [[ ! -f "$ipa_path" ]]; then
        log_error "IPA file does not exist: $ipa_path"
        return 1
    fi
    
    # Check file size
    local ipa_size
    ipa_size=$(du -h "$ipa_path" | cut -f1)
    log_info "IPA size: $ipa_size"
    
    # Validate with altool if credentials are available
    if [[ -n "${APP_STORE_API_KEY:-}" ]] && [[ -n "${APP_STORE_API_ISSUER:-}" ]]; then
        xcrun altool --validate-app \
            --type ios \
            --file "$ipa_path" \
            --apiKey "$APP_STORE_API_KEY" \
            --apiIssuer "$APP_STORE_API_ISSUER" 2>&1 | tee -a "$DEPLOY_LOG" || {
            log_warning "IPA validation had warnings"
        }
    else
        log_warning "Skipping online validation (no API credentials)"
    fi
    
    log_success "IPA validation complete"
}

prepare_appstore_metadata() {
    log_step "Preparing App Store metadata..."
    
    # Ensure metadata directory structure
    ensure_dir "${METADATA_DIR}/en-US"
    ensure_dir "${METADATA_DIR}/screenshots"
    
    # Generate metadata files
    local version
    version=$(get_current_version)
    
    # App name
    echo "Claude Code" > "${METADATA_DIR}/en-US/name.txt"
    
    # Subtitle
    echo "AI-Powered iOS Development" > "${METADATA_DIR}/en-US/subtitle.txt"
    
    # Description
    cat > "${METADATA_DIR}/en-US/description.txt" <<EOF
Claude Code revolutionizes iOS development with AI-powered assistance and advanced features designed for professional developers.

KEY FEATURES:
• Intelligent code completion and suggestions
• Real-time collaboration tools
• Advanced debugging capabilities
• Performance monitoring and optimization
• Secure SSH connections
• Project management integration
• Beautiful cyberpunk-themed UI

DEVELOPER PRODUCTIVITY:
Boost your development workflow with smart automation, context-aware suggestions, and seamless integration with your existing tools.

SECURITY FIRST:
Enterprise-grade security with biometric authentication, encrypted storage, and secure communication protocols.

REQUIREMENTS:
• iOS 17.0 or later
• Compatible with iPhone and iPad
• Internet connection required for AI features

Join thousands of developers who are already coding smarter with Claude Code.
EOF
    
    # Keywords
    echo "developer,coding,AI,productivity,swift,ios,programming,ide,tools,automation" \
        > "${METADATA_DIR}/en-US/keywords.txt"
    
    # Release notes
    generate_release_notes "$version" | head -500 > "${METADATA_DIR}/en-US/release_notes.txt"
    
    # Support URL
    echo "https://support.claudecode.app" > "${METADATA_DIR}/en-US/support_url.txt"
    
    # Marketing URL
    echo "https://claudecode.app" > "${METADATA_DIR}/en-US/marketing_url.txt"
    
    # Privacy URL
    echo "https://claudecode.app/privacy" > "${METADATA_DIR}/en-US/privacy_url.txt"
    
    log_success "App Store metadata prepared"
}

# ============================================================================
# NOTIFICATION SYSTEM
# ============================================================================

send_deployment_notification() {
    local deployment_type="$1"
    local version="$2"
    
    log_step "Sending deployment notifications..."
    
    # Slack notification
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        local message
        case "$deployment_type" in
            testflight)
                message="🚀 Claude Code iOS v${version} deployed to TestFlight!"
                ;;
            appstore)
                message="🎉 Claude Code iOS v${version} submitted to App Store!"
                ;;
            *)
                message="📱 Claude Code iOS v${version} deployed!"
                ;;
        esac
        
        curl -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"$message\"}" \
            2>/dev/null || log_warning "Slack notification failed"
    fi
    
    # Discord notification
    if [[ -n "${DISCORD_WEBHOOK_URL:-}" ]]; then
        local message
        case "$deployment_type" in
            testflight)
                message="🚀 **Claude Code iOS** v${version} deployed to TestFlight!"
                ;;
            appstore)
                message="🎉 **Claude Code iOS** v${version} submitted to App Store!"
                ;;
            *)
                message="📱 **Claude Code iOS** v${version} deployed!"
                ;;
        esac
        
        curl -X POST "$DISCORD_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"content\":\"$message\"}" \
            2>/dev/null || log_warning "Discord notification failed"
    fi
    
    # Email notification (using mail command if available)
    if [[ -n "${NOTIFICATION_EMAIL:-}" ]] && command_exists mail; then
        echo "Claude Code iOS v${version} has been deployed to ${deployment_type}." | \
            mail -s "Claude Code iOS Deployment: v${version}" "$NOTIFICATION_EMAIL" \
            2>/dev/null || log_warning "Email notification failed"
    fi
    
    log_success "Notifications sent"
}

# ============================================================================
# ONE-COMMAND DEPLOYMENT
# ============================================================================

deploy_one_command() {
    local target="${1:-testflight}"
    local version_bump="${2:-patch}"
    
    log_header "🚀 One-Command Deployment to ${target^^}"
    
    # Pre-flight checks
    check_prerequisites
    setup_environment
    ensure_clean_git
    
    # Version management
    local new_version
    new_version=$(bump_version "$version_bump")
    
    # Generate release notes
    generate_release_notes "$new_version"
    
    # Build application
    build_app "Release" "app-store"
    
    # Deploy based on target
    case "$target" in
        testflight|beta)
            deploy_testflight
            ;;
        appstore|production)
            deploy_appstore
            ;;
        *)
            log_error "Invalid deployment target: $target"
            exit 1
            ;;
    esac
    
    # Post-deployment tasks
    create_release_tag "$new_version"
    
    # Generate summary
    generate_deployment_summary "$target" "$new_version"
}

generate_deployment_summary() {
    local target="$1"
    local version="$2"
    
    log_header "📊 Deployment Summary"
    
    cat <<EOF
┌─────────────────────────────────────────────────────┐
│              DEPLOYMENT SUCCESSFUL!                 │
├─────────────────────────────────────────────────────┤
│ Target:      ${target^^}                           │
│ Version:     v${version}                           │
│ Build:       ${BUILD_NUMBER}                       │
│ Date:        $(date +"%Y-%m-%d %H:%M:%S")         │
│ Duration:    ${SECONDS}s                           │
├─────────────────────────────────────────────────────┤
│ Artifacts:                                         │
│ • IPA:       ${BUILD_DIR}/ClaudeCode*.ipa         │
│ • Archive:   ${BUILD_DIR}/ClaudeCode.xcarchive    │
│ • Logs:      ${DEPLOY_LOG}                        │
│ • Notes:     ${REPORTS_DIR}/release_notes_*.md    │
└─────────────────────────────────────────────────────┘

Next Steps:
EOF
    
    case "$target" in
        testflight|beta)
            cat <<EOF
1. Wait for Apple processing (usually 5-30 minutes)
2. Check TestFlight for build availability
3. Distribute to beta testers
4. Monitor crash reports and feedback
EOF
            ;;
        appstore|production)
            cat <<EOF
1. Wait for App Store review (usually 24-48 hours)
2. Monitor review status in App Store Connect
3. Respond to any reviewer feedback
4. Plan marketing announcement
EOF
            ;;
    esac
    
    echo
    log_success "Deployment completed successfully! 🎉"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

show_usage() {
    cat <<EOF
Claude Code iOS - Deployment Automation v2.0.0

USAGE:
    $(basename "$0") [command] [options]

COMMANDS:
    deploy [target] [bump]    One-command deployment (default)
    build [config]           Build application only
    testflight               Deploy to TestFlight
    appstore                 Deploy to App Store
    validate [ipa]           Validate IPA file
    version [bump]           Bump version (major|minor|patch)
    notes [version]          Generate release notes
    clean                    Clean build artifacts
    help                     Show this help message

OPTIONS:
    --force                  Force deployment with uncommitted changes
    --skip-tag              Skip git tag creation
    --no-push               Don't push tags to remote
    --verbose               Show detailed output
    --dry-run               Simulate deployment without executing

EXAMPLES:
    $(basename "$0")                    # Deploy to TestFlight with patch bump
    $(basename "$0") deploy testflight minor  # Deploy to TestFlight with minor bump
    $(basename "$0") deploy appstore major    # Deploy to App Store with major bump
    $(basename "$0") build Release            # Build Release configuration only
    $(basename "$0") version minor            # Bump minor version

ENVIRONMENT VARIABLES:
    APP_STORE_API_KEY        App Store Connect API Key
    APP_STORE_API_ISSUER     App Store Connect API Issuer ID
    DEVELOPMENT_TEAM         Apple Developer Team ID
    SLACK_WEBHOOK_URL        Slack webhook for notifications
    DISCORD_WEBHOOK_URL      Discord webhook for notifications
    NOTIFICATION_EMAIL       Email for deployment notifications

For more information, visit: https://github.com/claudecode/ios
EOF
}

main() {
    local start_time=$SECONDS
    
    # Parse arguments
    local command="${1:-deploy}"
    shift || true
    
    case "$command" in
        deploy)
            deploy_one_command "$@"
            ;;
        build)
            check_prerequisites
            setup_environment
            build_app "$@"
            ;;
        testflight|beta)
            check_prerequisites
            setup_environment
            ensure_clean_git
            bump_version patch
            build_app "Release" "app-store"
            deploy_testflight
            ;;
        appstore|production)
            check_prerequisites
            setup_environment
            ensure_clean_git
            bump_version minor
            build_app "Release" "app-store"
            deploy_appstore
            ;;
        validate)
            validate_ipa "$@"
            ;;
        version)
            bump_version "$@"
            ;;
        notes)
            generate_release_notes "$@"
            ;;
        clean)
            log_info "Cleaning build artifacts..."
            rm -rf "$BUILD_DIR"
            log_success "Clean complete"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
    
    # Show execution time
    local elapsed=$((SECONDS - start_time))
    log_info "Total execution time: ${elapsed}s"
}

# Run main function with all arguments
main "$@"