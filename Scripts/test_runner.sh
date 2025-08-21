#!/bin/bash

# Claude Code iOS - Test Runner Script
# Comprehensive test execution with coverage reporting

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly SIMULATOR_UUID="${SIMULATOR_UUID:-A707456B-44DB-472F-9722-C88153CDFFA1}"
readonly SCHEME_NAME="ClaudeCode"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUILD_DIR="${PROJECT_ROOT}/build"
readonly COVERAGE_DIR="${PROJECT_ROOT}/coverage"
readonly REPORTS_DIR="${PROJECT_ROOT}/test-reports"

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
    log_info "Setting up test directories..."
    mkdir -p "$COVERAGE_DIR"
    mkdir -p "$REPORTS_DIR"
    log_success "Directories created"
}

# Check for required tools
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode command line tools not installed"
        exit 1
    fi
    
    if ! command -v xcbeautify &> /dev/null; then
        log_warning "xcbeautify not installed. Install with: brew install xcbeautify"
    fi
    
    if ! command -v xcov &> /dev/null; then
        log_warning "xcov not installed. Coverage reports will be basic."
        log_info "Install with: gem install xcov"
    fi
    
    if ! command -v xcresultparser &> /dev/null; then
        log_warning "xcresultparser not installed. Test reports will be basic."
        log_info "Install with: brew install chargepoint/xcparse/xcparse"
    fi
    
    log_success "Dependency check complete"
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

# Run unit tests
run_unit_tests() {
    log_info "Running unit tests..."
    
    local test_log="${REPORTS_DIR}/unit-tests-$(date +%Y%m%d_%H%M%S).log"
    local result_bundle="${BUILD_DIR}/TestResults.xcresult"
    
    if command -v xcbeautify &> /dev/null; then
        xcodebuild test \
            -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
            -scheme "$SCHEME_NAME" \
            -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
            -derivedDataPath "$BUILD_DIR" \
            -resultBundlePath "$result_bundle" \
            -enableCodeCoverage YES \
            -only-testing:ClaudeCodeTests \
            2>&1 | tee "$test_log" | xcbeautify --report junit --report-path "${REPORTS_DIR}/unit-tests.xml" || {
                log_error "Unit tests failed"
                parse_test_results "$result_bundle"
                exit 1
            }
    else
        xcodebuild test \
            -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
            -scheme "$SCHEME_NAME" \
            -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
            -derivedDataPath "$BUILD_DIR" \
            -resultBundlePath "$result_bundle" \
            -enableCodeCoverage YES \
            -only-testing:ClaudeCodeTests \
            2>&1 | tee "$test_log" || {
                log_error "Unit tests failed"
                parse_test_results "$result_bundle"
                exit 1
            }
    fi
    
    log_success "Unit tests passed!"
    parse_test_results "$result_bundle"
}

# Run UI tests
run_ui_tests() {
    log_info "Running UI tests..."
    
    local test_log="${REPORTS_DIR}/ui-tests-$(date +%Y%m%d_%H%M%S).log"
    local result_bundle="${BUILD_DIR}/UITestResults.xcresult"
    
    if command -v xcbeautify &> /dev/null; then
        xcodebuild test \
            -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
            -scheme "$SCHEME_NAME" \
            -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
            -derivedDataPath "$BUILD_DIR" \
            -resultBundlePath "$result_bundle" \
            -enableCodeCoverage YES \
            -only-testing:ClaudeCodeUITests \
            2>&1 | tee "$test_log" | xcbeautify --report junit --report-path "${REPORTS_DIR}/ui-tests.xml" || {
                log_error "UI tests failed"
                parse_test_results "$result_bundle"
                exit 1
            }
    else
        xcodebuild test \
            -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
            -scheme "$SCHEME_NAME" \
            -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
            -derivedDataPath "$BUILD_DIR" \
            -resultBundlePath "$result_bundle" \
            -enableCodeCoverage YES \
            -only-testing:ClaudeCodeUITests \
            2>&1 | tee "$test_log" || {
                log_error "UI tests failed"
                parse_test_results "$result_bundle"
                exit 1
            }
    fi
    
    log_success "UI tests passed!"
    parse_test_results "$result_bundle"
}

# Run all tests
run_all_tests() {
    log_info "Running all tests..."
    
    local test_log="${REPORTS_DIR}/all-tests-$(date +%Y%m%d_%H%M%S).log"
    local result_bundle="${BUILD_DIR}/AllTestResults.xcresult"
    
    if command -v xcbeautify &> /dev/null; then
        xcodebuild test \
            -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
            -scheme "$SCHEME_NAME" \
            -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
            -derivedDataPath "$BUILD_DIR" \
            -resultBundlePath "$result_bundle" \
            -enableCodeCoverage YES \
            2>&1 | tee "$test_log" | xcbeautify --report junit --report-path "${REPORTS_DIR}/all-tests.xml" || {
                log_error "Tests failed"
                parse_test_results "$result_bundle"
                exit 1
            }
    else
        xcodebuild test \
            -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
            -scheme "$SCHEME_NAME" \
            -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
            -derivedDataPath "$BUILD_DIR" \
            -resultBundlePath "$result_bundle" \
            -enableCodeCoverage YES \
            2>&1 | tee "$test_log" || {
                log_error "Tests failed"
                parse_test_results "$result_bundle"
                exit 1
            }
    fi
    
    log_success "All tests passed!"
    parse_test_results "$result_bundle"
}

# Parse test results
parse_test_results() {
    local result_bundle="$1"
    
    if [ -d "$result_bundle" ]; then
        log_info "Parsing test results..."
        
        # Extract test summary
        if command -v xcresultparser &> /dev/null; then
            xcresultparser "$result_bundle" --output "${REPORTS_DIR}"
            log_success "Test results parsed to ${REPORTS_DIR}"
        else
            log_info "Basic test summary:"
            xcodebuild -resultBundlePath "$result_bundle" -resultBundleVersion 3 -showTestPlans || true
        fi
    fi
}

# Generate coverage report
generate_coverage_report() {
    log_info "Generating coverage report..."
    
    if command -v xcov &> /dev/null; then
        xcov --project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
             --scheme "$SCHEME_NAME" \
             --output_directory "$COVERAGE_DIR" \
             --derived_data_path "$BUILD_DIR" \
             --json_report \
             --markdown_report
        
        log_success "Coverage report generated in ${COVERAGE_DIR}"
        
        # Display coverage summary
        if [ -f "${COVERAGE_DIR}/report.json" ]; then
            log_info "Coverage Summary:"
            python3 -c "
import json
with open('${COVERAGE_DIR}/report.json', 'r') as f:
    data = json.load(f)
    print(f\"  Total Coverage: {data.get('coverage', 0):.1%}\")
    print(f\"  Lines Covered: {data.get('lines_covered', 0)}\")
    print(f\"  Lines Total: {data.get('lines_total', 0)}\")
" 2>/dev/null || true
        fi
    else
        # Basic coverage using xcodebuild
        log_info "Generating basic coverage report..."
        xcodebuild -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
                   -scheme "$SCHEME_NAME" \
                   -showBuildSettings \
                   -derivedDataPath "$BUILD_DIR" | grep -E "COVERAGE" || true
    fi
}

# Run performance tests
run_performance_tests() {
    log_info "Running performance tests..."
    
    xcodebuild test \
        -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination "platform=iOS Simulator,id=$SIMULATOR_UUID" \
        -derivedDataPath "$BUILD_DIR" \
        -only-testing:ClaudeCodeTests/PerformanceTests \
        -enableCodeCoverage NO \
        2>&1 | tee "${REPORTS_DIR}/performance-tests.log" || {
            log_warning "Performance tests failed or not found"
        }
    
    log_success "Performance tests complete"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "=========================================="
    echo "Claude Code iOS - Test Runner"
    echo "=========================================="
    echo
    
    # Parse command line arguments
    local test_type="${1:-all}"
    
    # Setup
    setup_directories
    check_dependencies
    ensure_project
    
    # Run tests based on type
    case "$test_type" in
        unit)
            run_unit_tests
            generate_coverage_report
            ;;
        ui)
            run_ui_tests
            ;;
        performance)
            run_performance_tests
            ;;
        all)
            run_all_tests
            generate_coverage_report
            ;;
        coverage)
            generate_coverage_report
            ;;
        help|--help|-h)
            echo "Usage: $0 [test-type]"
            echo
            echo "Test Types:"
            echo "  all         - Run all tests (default)"
            echo "  unit        - Run unit tests only"
            echo "  ui          - Run UI tests only"
            echo "  performance - Run performance tests"
            echo "  coverage    - Generate coverage report only"
            echo "  help        - Show this help message"
            echo
            echo "Reports are saved to: ${REPORTS_DIR}"
            echo "Coverage reports are saved to: ${COVERAGE_DIR}"
            ;;
        *)
            log_error "Unknown test type: $test_type"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
    
    log_success "Test execution complete!"
    echo "Reports available at: ${REPORTS_DIR}"
    echo "Coverage available at: ${COVERAGE_DIR}"
}

# Run main function
main "$@"