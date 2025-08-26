#!/bin/bash

# Screenshot Automation Script for Claude Code iOS
# Automated screenshot capture with UI interaction
# Version: 1.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCREENSHOTS_DIR="$PROJECT_ROOT/AppStoreAssets/Screenshots"

# App Configuration
BUNDLE_ID="com.claudecode.ios"
SIMULATOR_UUID="A707456B-44DB-472F-9722-C88153CDFFA1"

# Screenshot configurations
declare -A SCREENSHOT_SCENARIOS=(
    ["01_welcome"]="Welcome and onboarding screen"
    ["02_main_interface"]="Main interface with navigation"
    ["03_code_editor"]="Code editor with syntax highlighting"
    ["04_ai_assistant"]="AI assistant and code completion"
    ["05_terminal_ssh"]="Terminal with SSH connection"
    ["06_file_browser"]="File browser and project management"
    ["07_git_integration"]="Git operations and version control"
    ["08_settings"]="Settings and preferences"
    ["09_dark_mode"]="Dark mode interface"
    ["10_features_demo"]="Key features demonstration"
)

# Device configurations
declare -A DEVICES=(
    ["iphone_67"]="iPhone 15 Pro Max"
    ["iphone_61"]="iPhone 15 Pro"
    ["ipad_129"]="iPad Pro (12.9-inch) (6th generation)"
    ["ipad_11"]="iPad Pro (11-inch) (4th generation)"
)

# Print functions
print_step() {
    echo -e "${BLUE}→ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

# Setup simulator for screenshots
setup_simulator() {
    local device="$1"
    local mode="$2"
    
    print_step "Setting up simulator for $device ($mode mode)"
    
    # Boot simulator if needed
    local boot_status=$(xcrun simctl list devices | grep "$SIMULATOR_UUID" | grep -o "Booted\|Shutdown" || echo "Unknown")
    
    if [ "$boot_status" != "Booted" ]; then
        print_step "Booting simulator..."
        xcrun simctl boot "$SIMULATOR_UUID"
        sleep 5
    fi
    
    # Set appearance mode
    if [ "$mode" = "dark" ]; then
        xcrun simctl ui "$SIMULATOR_UUID" appearance dark
    else
        xcrun simctl ui "$SIMULATOR_UUID" appearance light
    fi
    
    # Set device orientation to portrait
    xcrun simctl ui "$SIMULATOR_UUID" orientation portrait
    
    # Wait for UI to settle
    sleep 2
    
    print_success "Simulator ready for screenshots"
}

# Launch app and wait for it to be ready
launch_app() {
    print_step "Launching Claude Code app..."
    
    # Launch the app
    xcrun simctl launch "$SIMULATOR_UUID" "$BUNDLE_ID"
    
    # Wait for app to fully load
    sleep 3
    
    # Verify app is running
    if xcrun simctl launch --list "$SIMULATOR_UUID" | grep -q "$BUNDLE_ID"; then
        print_success "App launched successfully"
    else
        print_warning "App may not have launched properly"
    fi
}

# Take screenshot with retry logic
take_screenshot() {
    local output_path="$1"
    local description="$2"
    local max_retries=3
    local retry_count=0
    
    print_step "Taking screenshot: $description"
    
    while [ $retry_count -lt $max_retries ]; do
        # Take screenshot
        xcrun simctl io "$SIMULATOR_UUID" screenshot "$output_path"
        
        # Check if screenshot was taken successfully
        if [ -f "$output_path" ] && [ -s "$output_path" ]; then
            print_success "Screenshot saved: $(basename "$output_path")"
            return 0
        else
            retry_count=$((retry_count + 1))
            print_warning "Screenshot failed, retry $retry_count/$max_retries"
            sleep 1
        fi
    done
    
    print_error "Failed to take screenshot after $max_retries attempts"
}

# Navigate app UI for specific scenarios
navigate_to_scenario() {
    local scenario="$1"
    
    print_step "Navigating to scenario: $scenario"
    
    case $scenario in
        "01_welcome")
            # Should be the initial screen after launch
            sleep 1
            ;;
        "02_main_interface")
            # Dismiss welcome if present, show main interface
            simulate_tap 500 1000  # Dismiss any overlay
            sleep 2
            ;;
        "03_code_editor")
            # Navigate to code editor
            simulate_tap 200 800   # Code editor tab/button
            sleep 2
            # Show some code
            simulate_text_input "// Welcome to Claude Code\nfunction hello() {\n    console.log('Hello World!');\n}"
            sleep 1
            ;;
        "04_ai_assistant")
            # Show AI assistant
            simulate_tap 300 600   # AI assistant button
            sleep 2
            # Show AI suggestion
            simulate_text_input "// AI: Code completion active"
            sleep 1
            ;;
        "05_terminal_ssh")
            # Navigate to terminal
            simulate_tap 150 800   # Terminal tab
            sleep 2
            # Show SSH connection
            simulate_text_input "ssh user@example.com"
            sleep 1
            simulate_tap 400 900   # Connect button
            sleep 2
            ;;
        "06_file_browser")
            # Navigate to file browser
            simulate_tap 100 700   # Files tab
            sleep 2
            # Show file structure
            simulate_tap 200 400   # Expand folder
            sleep 1
            ;;
        "07_git_integration")
            # Show git operations
            simulate_tap 250 750   # Git tab
            sleep 2
            # Show git status
            simulate_text_input "git status"
            sleep 1
            ;;
        "08_settings")
            # Navigate to settings
            simulate_tap 350 800   # Settings tab
            sleep 2
            ;;
        "09_dark_mode")
            # Should already be in dark mode from simulator setup
            sleep 1
            ;;
        "10_features_demo")
            # Show multiple features in one view
            simulate_tap 200 600   # Main view
            sleep 1
            ;;
    esac
    
    # Wait for UI to settle after navigation
    sleep 1
}

# Simulate tap at coordinates
simulate_tap() {
    local x="$1"
    local y="$2"
    
    # Using touch simulation via AppleScript (alternative to UI automation)
    osascript -e "
    tell application \"Simulator\"
        activate
    end tell
    " 2>/dev/null || true
    
    # Alternative: Use xcrun simctl to simulate touch (if available)
    # This is a placeholder - actual touch simulation might require different tools
    sleep 0.5
}

# Simulate text input
simulate_text_input() {
    local text="$1"
    
    # This would require UI automation tools like UI Testing or third-party tools
    # For now, we'll just wait and assume manual input or pre-staged content
    sleep 1
}

# Generate screenshots for a specific scenario
generate_scenario_screenshots() {
    local scenario="$1"
    local device="$2"
    local language="$3"
    local mode="$4"
    
    local description="${SCREENSHOT_SCENARIOS[$scenario]}"
    local output_dir="$SCREENSHOTS_DIR/$device/$language"
    local filename="${scenario}_${mode}.png"
    local output_path="$output_dir/$filename"
    
    mkdir -p "$output_dir"
    
    print_step "Generating screenshot: $scenario ($description)"
    
    # Navigate to the specific scenario
    navigate_to_scenario "$scenario"
    
    # Take the screenshot
    take_screenshot "$output_path" "$description"
    
    # Add small delay between scenarios
    sleep 1
}

# Generate all screenshots for a device and configuration
generate_device_screenshots() {
    local device="$1"
    local language="$2"
    local mode="$3"
    
    local device_name="${DEVICES[$device]}"
    
    print_step "Generating screenshots for $device_name ($language, $mode mode)"
    
    # Setup simulator
    setup_simulator "$device" "$mode"
    
    # Launch app
    launch_app
    
    # Generate screenshots for each scenario
    for scenario in $(printf '%s\n' "${!SCREENSHOT_SCENARIOS[@]}" | sort); do
        generate_scenario_screenshots "$scenario" "$device" "$language" "$mode"
    done
    
    print_success "Screenshots completed for $device_name"
}

# Add text overlays to screenshots (optional)
add_text_overlays() {
    local screenshot_path="$1"
    local text="$2"
    
    if command -v convert &> /dev/null; then
        print_step "Adding text overlay: $text"
        
        # Create temporary overlay image
        local temp_overlay="/tmp/text_overlay.png"
        
        convert -size 1200x100 xc:none \
            -font Arial -pointsize 48 \
            -fill white -stroke black -strokewidth 2 \
            -gravity center -annotate +0+0 "$text" \
            "$temp_overlay"
        
        # Composite overlay onto screenshot
        convert "$screenshot_path" "$temp_overlay" \
            -gravity south -geometry +0+50 \
            -composite "$screenshot_path"
        
        rm -f "$temp_overlay"
        
        print_success "Text overlay added"
    fi
}

# Optimize screenshots for App Store
optimize_screenshots() {
    local screenshots_dir="$1"
    
    if command -v convert &> /dev/null; then
        print_step "Optimizing screenshots for App Store..."
        
        find "$screenshots_dir" -name "*.png" -type f | while read screenshot; do
            # Optimize PNG compression
            convert "$screenshot" -strip -quality 95 "$screenshot"
        done
        
        print_success "Screenshots optimized"
    else
        print_warning "ImageMagick not available - skipping optimization"
    fi
}

# Validate screenshot requirements
validate_screenshots() {
    local device="$1"
    local screenshots_dir="$SCREENSHOTS_DIR/$device"
    
    print_step "Validating screenshots for $device"
    
    # Define expected resolutions for each device
    declare -A expected_resolutions=(
        ["iphone_67"]="1290x2796"
        ["iphone_61"]="1179x2556"
        ["ipad_129"]="2048x2732"
        ["ipad_11"]="1668x2388"
    )
    
    local expected_res="${expected_resolutions[$device]}"
    local validation_passed=true
    
    # Check each screenshot
    find "$screenshots_dir" -name "*.png" -type f | while read screenshot; do
        if command -v identify &> /dev/null; then
            local actual_res=$(identify -format "%wx%h" "$screenshot")
            
            if [ "$actual_res" != "$expected_res" ]; then
                print_warning "Resolution mismatch: $screenshot ($actual_res, expected $expected_res)"
                validation_passed=false
            fi
            
            local file_size=$(stat -f%z "$screenshot" 2>/dev/null || stat -c%s "$screenshot" 2>/dev/null)
            if [ "$file_size" -lt 10000 ]; then
                print_warning "Screenshot may be corrupted (too small): $screenshot"
                validation_passed=false
            fi
        fi
    done
    
    if [ "$validation_passed" = true ]; then
        print_success "Screenshot validation passed"
    else
        print_warning "Some screenshots may need attention"
    fi
}

# Generate comparison screenshots (light vs dark mode)
generate_comparison_screenshots() {
    local device="$1"
    local language="$2"
    
    print_step "Generating light/dark mode comparison for $device"
    
    # Generate light mode screenshots
    generate_device_screenshots "$device" "$language" "light"
    
    # Generate dark mode screenshots  
    generate_device_screenshots "$device" "$language" "dark"
    
    # Create side-by-side comparisons if ImageMagick is available
    if command -v convert &> /dev/null; then
        create_mode_comparisons "$device" "$language"
    fi
}

# Create side-by-side light/dark mode comparisons
create_mode_comparisons() {
    local device="$1"
    local language="$2"
    local source_dir="$SCREENSHOTS_DIR/$device/$language"
    local comparison_dir="$source_dir/comparisons"
    
    mkdir -p "$comparison_dir"
    
    print_step "Creating mode comparison images"
    
    for scenario in $(printf '%s\n' "${!SCREENSHOT_SCENARIOS[@]}" | sort); do
        local light_image="$source_dir/${scenario}_light.png"
        local dark_image="$source_dir/${scenario}_dark.png"
        local comparison_image="$comparison_dir/${scenario}_comparison.png"
        
        if [ -f "$light_image" ] && [ -f "$dark_image" ]; then
            convert "$light_image" "$dark_image" +append "$comparison_image"
            print_success "Comparison created: ${scenario}_comparison.png"
        fi
    done
}

# Main execution function
main() {
    local command="${1:-all}"
    local device_filter="$2"
    local language_filter="${3:-en}"
    local mode_filter="${4:-dark}"
    
    case $command in
        "device")
            if [ -n "$device_filter" ]; then
                generate_device_screenshots "$device_filter" "$language_filter" "$mode_filter"
                optimize_screenshots "$SCREENSHOTS_DIR/$device_filter"
                validate_screenshots "$device_filter"
            else
                print_error "Device parameter required. Use: iphone_67, iphone_61, ipad_129, or ipad_11"
            fi
            ;;
        "comparison")
            if [ -n "$device_filter" ]; then
                generate_comparison_screenshots "$device_filter" "$language_filter"
                optimize_screenshots "$SCREENSHOTS_DIR/$device_filter"
                validate_screenshots "$device_filter"
            else
                print_error "Device parameter required for comparison mode"
            fi
            ;;
        "validate")
            if [ -n "$device_filter" ]; then
                validate_screenshots "$device_filter"
            else
                for device in "${!DEVICES[@]}"; do
                    validate_screenshots "$device"
                done
            fi
            ;;
        "optimize")
            if [ -n "$device_filter" ]; then
                optimize_screenshots "$SCREENSHOTS_DIR/$device_filter"
            else
                optimize_screenshots "$SCREENSHOTS_DIR"
            fi
            ;;
        "all")
            for device in "${!DEVICES[@]}"; do
                generate_device_screenshots "$device" "$language_filter" "$mode_filter"
                optimize_screenshots "$SCREENSHOTS_DIR/$device"
                validate_screenshots "$device"
            done
            ;;
        *)
            echo "Usage: $0 [command] [device] [language] [mode]"
            echo ""
            echo "Commands:"
            echo "  all         - Generate screenshots for all devices"
            echo "  device      - Generate screenshots for specific device"
            echo "  comparison  - Generate light/dark mode comparisons"
            echo "  validate    - Validate existing screenshots"
            echo "  optimize    - Optimize screenshots for App Store"
            echo ""
            echo "Devices: iphone_67, iphone_61, ipad_129, ipad_11"
            echo "Languages: en, es, fr, de, ja, zh-Hans, etc."
            echo "Modes: light, dark, auto"
            echo ""
            echo "Examples:"
            echo "  $0 device iphone_67 en dark"
            echo "  $0 comparison ipad_129 en"
            echo "  $0 validate"
            exit 1
            ;;
    esac
    
    print_success "Screenshot automation completed!"
}

# Check if simulator and tools are available
check_prerequisites() {
    if ! command -v xcrun &> /dev/null; then
        print_error "Xcode command line tools not installed"
    fi
    
    if ! xcrun simctl list devices | grep -q "$SIMULATOR_UUID"; then
        print_error "Simulator not found: $SIMULATOR_UUID"
    fi
    
    if ! command -v convert &> /dev/null; then
        print_warning "ImageMagick not installed - some features will be unavailable"
        echo "Install with: brew install imagemagick"
    fi
}

# Run prerequisite check and main function
check_prerequisites
main "$@"