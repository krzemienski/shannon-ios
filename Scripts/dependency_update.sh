#!/bin/bash

# Claude Code iOS - Dependency Update Script
# Update and manage project dependencies

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPORTS_DIR="${PROJECT_ROOT}/dependency-reports"

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
    mkdir -p "$REPORTS_DIR"
}

# Update Swift Package Manager dependencies
update_spm() {
    log_info "Updating Swift Package Manager dependencies..."
    
    if [ -f "${PROJECT_ROOT}/Package.swift" ] || [ -f "${PROJECT_ROOT}/Package.resolved" ]; then
        # Update packages
        log_info "Resolving package versions..."
        swift package update
        
        # Show outdated packages
        if command -v swift-outdated &> /dev/null; then
            log_info "Checking for outdated packages..."
            swift-outdated > "${REPORTS_DIR}/spm-outdated.txt" || true
            cat "${REPORTS_DIR}/spm-outdated.txt"
        fi
        
        log_success "Swift packages updated"
    else
        log_info "No Swift Package Manager configuration found"
    fi
}

# Update CocoaPods dependencies
update_cocoapods() {
    log_info "Checking for CocoaPods..."
    
    if [ -f "${PROJECT_ROOT}/Podfile" ]; then
        if ! command -v pod &> /dev/null; then
            log_error "CocoaPods not installed. Install with: gem install cocoapods"
            return 1
        fi
        
        log_info "Updating CocoaPods..."
        
        # Update repo
        pod repo update
        
        # Check for outdated pods
        pod outdated > "${REPORTS_DIR}/pods-outdated.txt" || true
        
        # Update pods
        pod update
        
        log_success "CocoaPods updated"
    else
        log_info "No Podfile found"
    fi
}

# Update Carthage dependencies
update_carthage() {
    log_info "Checking for Carthage..."
    
    if [ -f "${PROJECT_ROOT}/Cartfile" ]; then
        if ! command -v carthage &> /dev/null; then
            log_error "Carthage not installed. Install with: brew install carthage"
            return 1
        fi
        
        log_info "Updating Carthage dependencies..."
        
        # Update dependencies
        carthage update --platform iOS --use-xcframeworks
        
        log_success "Carthage dependencies updated"
    else
        log_info "No Cartfile found"
    fi
}

# Update Homebrew tools
update_tools() {
    log_info "Updating development tools..."
    
    if ! command -v brew &> /dev/null; then
        log_warning "Homebrew not installed"
        return 1
    fi
    
    # Update Homebrew
    brew update
    
    # List of tools to update
    local tools=(
        "xcodegen"
        "swiftlint"
        "swiftformat"
        "xcbeautify"
        "periphery"
        "sourcedocs"
    )
    
    for tool in "${tools[@]}"; do
        if brew list "$tool" &>/dev/null; then
            log_info "Updating $tool..."
            brew upgrade "$tool" || true
        else
            log_info "$tool not installed"
        fi
    done
    
    # Update Ruby gems
    if command -v gem &> /dev/null; then
        log_info "Updating Ruby gems..."
        
        # Update fastlane
        if gem list fastlane -i &>/dev/null; then
            gem update fastlane
        fi
        
        # Update jazzy
        if gem list jazzy -i &>/dev/null; then
            gem update jazzy
        fi
        
        # Update xcov
        if gem list xcov -i &>/dev/null; then
            gem update xcov
        fi
    fi
    
    log_success "Development tools updated"
}

# Check Xcode version
check_xcode() {
    log_info "Checking Xcode version..."
    
    local current_version=$(xcodebuild -version | head -1 | awk '{print $2}')
    log_info "Current Xcode version: $current_version"
    
    # Check for Xcode updates
    if command -v softwareupdate &> /dev/null; then
        log_info "Checking for Xcode updates..."
        softwareupdate --list 2>&1 | grep -i xcode || log_info "No Xcode updates available"
    fi
    
    # Check command line tools
    log_info "Command Line Tools version:"
    pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | grep version || true
}

# Clean dependency caches
clean_caches() {
    log_info "Cleaning dependency caches..."
    
    # Clean SPM cache
    if [ -d "${HOME}/Library/Caches/org.swift.swiftpm" ]; then
        log_info "Cleaning Swift Package Manager cache..."
        rm -rf "${HOME}/Library/Caches/org.swift.swiftpm"
    fi
    
    # Clean CocoaPods cache
    if command -v pod &> /dev/null; then
        log_info "Cleaning CocoaPods cache..."
        pod cache clean --all
    fi
    
    # Clean Carthage cache
    if [ -d "${HOME}/Library/Caches/org.carthage.CarthageKit" ]; then
        log_info "Cleaning Carthage cache..."
        rm -rf "${HOME}/Library/Caches/org.carthage.CarthageKit"
    fi
    
    # Clean DerivedData
    if [ -d "${HOME}/Library/Developer/Xcode/DerivedData" ]; then
        log_info "Cleaning DerivedData..."
        rm -rf "${HOME}/Library/Developer/Xcode/DerivedData/ClaudeCode-*"
    fi
    
    log_success "Caches cleaned"
}

# Generate dependency report
generate_report() {
    log_info "Generating dependency report..."
    
    local report="${REPORTS_DIR}/dependency-report.md"
    
    cat > "$report" <<EOF
# Dependency Update Report

Generated on: $(date)

## Swift Package Manager
$(if [ -f "${PROJECT_ROOT}/Package.resolved" ]; then
    echo "### Current Packages"
    cat "${PROJECT_ROOT}/Package.resolved" | grep -E "package|version" | head -20
else
    echo "No SPM packages found"
fi)

## CocoaPods
$(if [ -f "${PROJECT_ROOT}/Podfile.lock" ]; then
    echo "### Current Pods"
    grep "^\s*-" "${PROJECT_ROOT}/Podfile.lock" | head -20
else
    echo "No CocoaPods found"
fi)

## Carthage
$(if [ -f "${PROJECT_ROOT}/Cartfile.resolved" ]; then
    echo "### Current Carthage Dependencies"
    cat "${PROJECT_ROOT}/Cartfile.resolved"
else
    echo "No Carthage dependencies found"
fi)

## Development Tools
\`\`\`
Xcode: $(xcodebuild -version | head -1)
Swift: $(swift --version | head -1)
SwiftLint: $(swiftlint version 2>/dev/null || echo "Not installed")
XcodeGen: $(xcodegen version 2>/dev/null || echo "Not installed")
\`\`\`

## Recommendations
1. Review outdated dependencies before updating
2. Test thoroughly after updates
3. Update one dependency at a time for easier debugging
4. Keep a backup of working dependency versions
EOF
    
    log_success "Dependency report generated: $report"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "=========================================="
    echo "Claude Code iOS - Dependency Update"
    echo "=========================================="
    echo
    
    local action="${1:-all}"
    
    case "$action" in
        spm)
            setup_directories
            update_spm
            ;;
        
        cocoapods|pods)
            setup_directories
            update_cocoapods
            ;;
        
        carthage)
            setup_directories
            update_carthage
            ;;
        
        tools)
            update_tools
            ;;
        
        xcode)
            check_xcode
            ;;
        
        clean)
            clean_caches
            ;;
        
        report)
            setup_directories
            generate_report
            ;;
        
        all)
            setup_directories
            update_spm
            update_cocoapods
            update_carthage
            update_tools
            check_xcode
            generate_report
            log_success "All dependencies updated!"
            log_info "Report available at: ${REPORTS_DIR}/dependency-report.md"
            ;;
        
        help|--help|-h)
            echo "Usage: $0 [action]"
            echo
            echo "Actions:"
            echo "  all       - Update all dependencies (default)"
            echo "  spm       - Update Swift Package Manager"
            echo "  pods      - Update CocoaPods"
            echo "  carthage  - Update Carthage dependencies"
            echo "  tools     - Update development tools"
            echo "  xcode     - Check Xcode version"
            echo "  clean     - Clean dependency caches"
            echo "  report    - Generate dependency report"
            echo "  help      - Show this help message"
            echo
            echo "Reports are saved to: ${REPORTS_DIR}"
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