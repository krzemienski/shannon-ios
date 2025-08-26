#!/bin/bash

# Make script executable on first run
chmod +x "$0" 2>/dev/null || true

# Master Asset Generation Script for Claude Code iOS
# Orchestrates the generation of all App Store assets
# Version: 1.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ASSETS_DIR="$PROJECT_ROOT/AppStoreAssets"

# Print functions
print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    Claude Code iOS Asset Generator                ║"
    echo "║                  Complete App Store Asset Creation                ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

print_header() {
    echo -e "\n${CYAN}======================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}======================================${NC}\n"
}

print_step() {
    echo -e "${BLUE}🔄 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Show help
show_help() {
    print_banner
    echo "Complete App Store asset generation for Claude Code iOS"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  all                    Generate all assets (default)"
    echo "  icons                  Generate app icons only"
    echo "  screenshots           Generate screenshots only"
    echo "  previews              Generate app preview videos only"
    echo "  marketing             Generate marketing materials only"
    echo "  listing               Generate App Store listing content only"
    echo "  export                Export assets for App Store Connect"
    echo "  validate              Validate all generated assets"
    echo "  clean                 Clean all generated assets"
    echo "  status                Show generation status"
    echo ""
    echo "Options:"
    echo "  --device DEVICE       Target specific device (iphone_67, iphone_61, ipad_129, ipad_11)"
    echo "  --language LANG       Target specific language (en, es, fr, de, ja, etc.)"
    echo "  --mode MODE           UI mode (light, dark, auto) [default: dark]"
    echo "  --quick              Quick generation (essential assets only)"
    echo "  --production         Production quality (full assets with validation)"
    echo "  --dry-run            Show what would be generated without creating files"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 all                                    # Generate all assets"
    echo "  $0 all --quick                           # Quick essential assets"
    echo "  $0 icons --production                    # Production quality icons"
    echo "  $0 screenshots --device iphone_67        # iPhone 15 Pro Max screenshots"
    echo "  $0 all --language es --mode light        # Spanish light mode assets"
    echo "  $0 export --production                   # Export production assets"
    echo ""
}

# Check system requirements
check_requirements() {
    print_header "Checking System Requirements"
    
    local requirements_met=true
    
    # Check Xcode tools
    if command -v xcrun &> /dev/null; then
        print_success "Xcode command line tools found"
    else
        print_error "Xcode command line tools required"
        requirements_met=false
    fi
    
    # Check simulator
    if xcrun simctl list devices | grep -q "A707456B-44DB-472F-9722-C88153CDFFA1"; then
        print_success "iPhone 15 Pro Max simulator found"
    else
        print_warning "Target simulator not found - some features may not work"
    fi
    
    # Check optional tools
    local tools=("convert:ImageMagick" "ffmpeg:FFmpeg" "rsvg-convert:librsvg")
    
    for tool_info in "${tools[@]}"; do
        local tool="${tool_info%%:*}"
        local package="${tool_info##*:}"
        
        if command -v "$tool" &> /dev/null; then
            print_success "$package found"
        else
            print_warning "$package not found - install with: brew install ${package,,}"
        fi
    done
    
    if [ "$requirements_met" = false ]; then
        print_error "Requirements not met. Please install missing components."
        exit 1
    fi
    
    print_success "System requirements check completed"
}

# Check build environment
check_build_environment() {
    print_step "Checking build environment..."
    
    # Check if app can be built
    cd "$PROJECT_ROOT"
    
    if [ -f "Project.yml" ]; then
        print_success "XcodeGen project configuration found"
    else
        print_warning "Project.yml not found"
    fi
    
    if [ -f "Scripts/simulator_automation.sh" ]; then
        print_success "Simulator automation script found"
    else
        print_warning "Simulator automation script not found"
    fi
    
    # Check if we can build the project
    if xcodebuild -list -project ClaudeCode.xcodeproj &>/dev/null 2>&1; then
        print_success "Xcode project appears valid"
    else
        print_warning "Xcode project may need generation or has issues"
        if command -v xcodegen &> /dev/null; then
            print_step "Generating Xcode project..."
            xcodegen
            print_success "Xcode project generated"
        fi
    fi
}

# Setup directory structure
setup_directories() {
    print_step "Setting up directory structure..."
    
    local directories=(
        "$ASSETS_DIR"
        "$ASSETS_DIR/Icons"
        "$ASSETS_DIR/Screenshots"
        "$ASSETS_DIR/Previews"
        "$ASSETS_DIR/Marketing"
        "$ASSETS_DIR/Listing"
        "$ASSETS_DIR/Export"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
    done
    
    print_success "Directory structure created"
}

# Generate app icons
generate_icons() {
    print_header "Generating App Icons"
    
    if [ -f "$SCRIPT_DIR/icon-generator.sh" ]; then
        chmod +x "$SCRIPT_DIR/icon-generator.sh"
        "$SCRIPT_DIR/icon-generator.sh" all
        print_success "App icons generation completed"
    else
        print_error "Icon generator script not found"
        return 1
    fi
}

# Generate screenshots
generate_screenshots() {
    local device_filter="$1"
    local language_filter="$2"
    local mode_filter="$3"
    
    print_header "Generating Screenshots"
    
    # Check if we should use the main script or automation script
    if [ -f "$SCRIPT_DIR/app-store-assets.sh" ]; then
        chmod +x "$SCRIPT_DIR/app-store-assets.sh"
        
        local args=("screenshots")
        [ -n "$device_filter" ] && args+=("--device" "$device_filter")
        [ -n "$language_filter" ] && args+=("--language" "$language_filter")
        [ -n "$mode_filter" ] && args+=("--mode" "$mode_filter")
        
        "$SCRIPT_DIR/app-store-assets.sh" "${args[@]}"
        print_success "Screenshots generation completed"
    else
        print_error "Screenshot generator script not found"
        return 1
    fi
}

# Generate app preview videos
generate_previews() {
    local device_filter="$1"
    local language_filter="$2"
    local mode_filter="$3"
    
    print_header "Generating App Preview Videos"
    
    if [ -f "$SCRIPT_DIR/app-store-assets.sh" ]; then
        local args=("previews")
        [ -n "$device_filter" ] && args+=("--device" "$device_filter")
        [ -n "$language_filter" ] && args+=("--language" "$language_filter")
        [ -n "$mode_filter" ] && args+=("--mode" "$mode_filter")
        
        "$SCRIPT_DIR/app-store-assets.sh" "${args[@]}"
        print_success "App preview videos generation completed"
    else
        print_error "Preview generator script not found"
        return 1
    fi
}

# Generate marketing materials
generate_marketing() {
    print_header "Generating Marketing Materials"
    
    if [ -f "$SCRIPT_DIR/app-store-assets.sh" ]; then
        "$SCRIPT_DIR/app-store-assets.sh" marketing
        print_success "Marketing materials generation completed"
    else
        print_error "Marketing generator script not found"
        return 1
    fi
}

# Generate listing content
generate_listing() {
    print_header "Generating App Store Listing Content"
    
    if [ -f "$SCRIPT_DIR/app-store-assets.sh" ]; then
        "$SCRIPT_DIR/app-store-assets.sh" listing
        print_success "Listing content generation completed"
    else
        print_error "Listing generator script not found"
        return 1
    fi
}

# Export assets for App Store Connect
export_assets() {
    print_header "Exporting Assets for App Store Connect"
    
    if [ -f "$SCRIPT_DIR/app-store-assets.sh" ]; then
        "$SCRIPT_DIR/app-store-assets.sh" export
        print_success "Asset export completed"
    else
        print_error "Asset exporter script not found"
        return 1
    fi
}

# Validate generated assets
validate_assets() {
    print_header "Validating Generated Assets"
    
    local validation_passed=true
    
    # Validate icons
    print_step "Validating icons..."
    if [ -d "$ASSETS_DIR/Icons" ]; then
        local icon_count=$(find "$ASSETS_DIR/Icons" -name "*.png" | wc -l)
        if [ "$icon_count" -gt 10 ]; then
            print_success "$icon_count icons generated"
        else
            print_warning "Only $icon_count icons found - may be incomplete"
            validation_passed=false
        fi
    else
        print_warning "Icons directory not found"
        validation_passed=false
    fi
    
    # Validate screenshots
    print_step "Validating screenshots..."
    if [ -d "$ASSETS_DIR/Screenshots" ]; then
        local screenshot_count=$(find "$ASSETS_DIR/Screenshots" -name "*.png" | wc -l)
        if [ "$screenshot_count" -gt 0 ]; then
            print_success "$screenshot_count screenshots generated"
        else
            print_warning "No screenshots found"
            validation_passed=false
        fi
    else
        print_warning "Screenshots directory not found"
        validation_passed=false
    fi
    
    # Validate listing content
    print_step "Validating listing content..."
    if [ -f "$ASSETS_DIR/Listing/app_store_metadata.json" ]; then
        print_success "App Store metadata found"
    else
        print_warning "App Store metadata not found"
        validation_passed=false
    fi
    
    # Validate export directory
    print_step "Validating export structure..."
    if [ -d "$ASSETS_DIR/Export" ]; then
        local export_items=$(find "$ASSETS_DIR/Export" -type f | wc -l)
        if [ "$export_items" -gt 0 ]; then
            print_success "$export_items export files ready"
        else
            print_warning "Export directory is empty"
        fi
    fi
    
    if [ "$validation_passed" = true ]; then
        print_success "Asset validation completed successfully"
    else
        print_warning "Some assets may need attention"
    fi
    
    return $validation_passed
}

# Show generation status
show_status() {
    print_header "Asset Generation Status"
    
    # Check each asset type
    local asset_types=(
        "Icons:$ASSETS_DIR/Icons:*.png"
        "Screenshots:$ASSETS_DIR/Screenshots:*.png"
        "Previews:$ASSETS_DIR/Previews:*.mov"
        "Marketing:$ASSETS_DIR/Marketing:*"
        "Listing:$ASSETS_DIR/Listing:*.json"
        "Export:$ASSETS_DIR/Export:*"
    )
    
    for asset_info in "${asset_types[@]}"; do
        local name="${asset_info%%:*}"
        local path="${asset_info#*:}"
        local pattern="${path#*:}"
        path="${path%:*}"
        
        if [ -d "$path" ]; then
            local count=$(find "$path" -name "$pattern" -type f 2>/dev/null | wc -l)
            if [ "$count" -gt 0 ]; then
                print_success "$name: $count files"
            else
                print_warning "$name: No files found"
            fi
        else
            print_warning "$name: Directory not found"
        fi
    done
    
    # Show total disk usage
    if [ -d "$ASSETS_DIR" ]; then
        local size=$(du -sh "$ASSETS_DIR" 2>/dev/null | cut -f1)
        print_info "Total asset size: $size"
    fi
}

# Clean generated assets
clean_assets() {
    print_header "Cleaning Generated Assets"
    
    if [ -d "$ASSETS_DIR" ]; then
        print_step "Removing assets directory..."
        rm -rf "$ASSETS_DIR"
        print_success "Assets cleaned"
    else
        print_info "No assets directory found"
    fi
}

# Quick generation mode (essential assets only)
quick_generation() {
    local device_filter="$1"
    local language_filter="${2:-en}"
    local mode_filter="${3:-dark}"
    
    print_header "Quick Asset Generation"
    print_info "Generating essential assets only for faster turnaround"
    
    setup_directories
    
    # Generate icons (always needed)
    generate_icons
    
    # Generate screenshots for one device and language
    local target_device="${device_filter:-iphone_67}"
    generate_screenshots "$target_device" "$language_filter" "$mode_filter"
    
    # Generate basic listing content
    generate_listing
    
    # Quick export
    export_assets
    
    print_success "Quick generation completed"
}

# Production generation mode (complete asset set with validation)
production_generation() {
    local device_filter="$1"
    local language_filter="$2"
    local mode_filter="$3"
    
    print_header "Production Asset Generation"
    print_info "Generating complete production-ready asset set"
    
    check_build_environment
    setup_directories
    
    # Generate all assets
    generate_icons
    generate_screenshots "$device_filter" "$language_filter" "$mode_filter"
    generate_previews "$device_filter" "$language_filter" "$mode_filter"
    generate_marketing
    generate_listing
    
    # Validate everything
    if ! validate_assets; then
        print_warning "Validation issues found - please review before submission"
    fi
    
    # Export for App Store Connect
    export_assets
    
    print_success "Production generation completed"
}

# Dry run mode (show what would be generated)
dry_run_mode() {
    print_header "Asset Generation Dry Run"
    print_info "Showing what would be generated without creating files"
    
    echo "📱 Icons:"
    echo "  • iOS app icons (20x20 to 1024x1024)"
    echo "  • Xcode asset catalog"
    echo "  • App Store marketing icon"
    echo ""
    
    echo "📸 Screenshots:"
    echo "  • iPhone 15 Pro Max (6.7\")"
    echo "  • iPhone 15 Pro (6.1\")"
    echo "  • iPad Pro 12.9\" (6th gen)"
    echo "  • iPad Pro 11\" (4th gen)"
    echo ""
    
    echo "🎬 App Previews:"
    echo "  • 15-30 second videos per device"
    echo "  • Feature demonstrations"
    echo "  • Multiple language support"
    echo ""
    
    echo "🎨 Marketing:"
    echo "  • Feature graphics"
    echo "  • Social media templates"
    echo "  • Press kit materials"
    echo ""
    
    echo "📄 Listing Content:"
    echo "  • App Store descriptions"
    echo "  • Keywords and metadata"
    echo "  • What's new templates"
    echo ""
    
    echo "📦 Export Package:"
    echo "  • App Store Connect ready structure"
    echo "  • Submission checklist"
    echo "  • Asset validation reports"
    
    print_info "Use without --dry-run to generate actual files"
}

# Make scripts executable
make_scripts_executable() {
    local scripts=(
        "$SCRIPT_DIR/app-store-assets.sh"
        "$SCRIPT_DIR/screenshot-automation.sh"
        "$SCRIPT_DIR/icon-generator.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
        fi
    done
}

# Main execution function
main() {
    local command="${1:-all}"
    local device_filter=""
    local language_filter=""
    local mode_filter="dark"
    local quick_mode=false
    local production_mode=false
    local dry_run=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --device)
                device_filter="$2"
                shift 2
                ;;
            --language)
                language_filter="$2"
                shift 2
                ;;
            --mode)
                mode_filter="$2"
                shift 2
                ;;
            --quick)
                quick_mode=true
                shift
                ;;
            --production)
                production_mode=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                if [ -z "$command" ]; then
                    command="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Show banner
    print_banner
    
    # Handle dry run mode
    if [ "$dry_run" = true ]; then
        dry_run_mode
        exit 0
    fi
    
    # Check requirements
    check_requirements
    
    # Make scripts executable
    make_scripts_executable
    
    # Execute command
    case $command in
        "all")
            if [ "$quick_mode" = true ]; then
                quick_generation "$device_filter" "$language_filter" "$mode_filter"
            elif [ "$production_mode" = true ]; then
                production_generation "$device_filter" "$language_filter" "$mode_filter"
            else
                # Standard generation
                setup_directories
                generate_icons
                generate_screenshots "$device_filter" "$language_filter" "$mode_filter"
                generate_previews "$device_filter" "$language_filter" "$mode_filter"
                generate_marketing
                generate_listing
                export_assets
                validate_assets
            fi
            ;;
        "icons")
            setup_directories
            generate_icons
            ;;
        "screenshots")
            setup_directories
            generate_screenshots "$device_filter" "$language_filter" "$mode_filter"
            ;;
        "previews")
            setup_directories
            generate_previews "$device_filter" "$language_filter" "$mode_filter"
            ;;
        "marketing")
            setup_directories
            generate_marketing
            ;;
        "listing")
            setup_directories
            generate_listing
            ;;
        "export")
            export_assets
            ;;
        "validate")
            validate_assets
            ;;
        "status")
            show_status
            ;;
        "clean")
            clean_assets
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
    
    # Final status
    print_header "Asset Generation Summary"
    show_status
    
    print_success "🎉 Claude Code iOS assets are ready!"
    echo -e "${CYAN}📁 Assets location: $ASSETS_DIR${NC}"
    echo -e "${CYAN}📦 Export ready: $ASSETS_DIR/Export${NC}"
    echo -e "${CYAN}📋 Submission checklist: $ASSETS_DIR/Export/submission_checklist.md${NC}"
}

# Run main function with all arguments
main "$@"