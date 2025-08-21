#!/bin/bash

# Claude Code iOS - Quality Checks Script
# Run various quality checks on the codebase

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPORTS_DIR="${PROJECT_ROOT}/quality-reports"

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

# Run SwiftLint
run_lint() {
    log_info "Running SwiftLint..."
    
    if ! command -v swiftlint &> /dev/null; then
        log_error "SwiftLint not installed. Install with: brew install swiftlint"
        return 1
    fi
    
    # Generate report
    swiftlint lint \
        --config "${PROJECT_ROOT}/.swiftlint.yml" \
        --reporter json \
        > "${REPORTS_DIR}/swiftlint.json" || true
    
    # Display summary
    swiftlint lint \
        --config "${PROJECT_ROOT}/.swiftlint.yml" \
        --reporter summary || true
    
    log_success "SwiftLint complete. Report: ${REPORTS_DIR}/swiftlint.json"
}

# Run SwiftFormat
run_format() {
    log_info "Running SwiftFormat..."
    
    if ! command -v swiftformat &> /dev/null; then
        log_error "SwiftFormat not installed. Install with: brew install swiftformat"
        return 1
    fi
    
    # Format files
    swiftformat "${PROJECT_ROOT}/Sources" \
        "${PROJECT_ROOT}/Tests" \
        "${PROJECT_ROOT}/UITests" \
        --config "${PROJECT_ROOT}/.swiftformat" \
        --verbose
    
    log_success "SwiftFormat complete"
}

# Run static analysis
run_analyze() {
    log_info "Running static analysis..."
    
    # Ensure project exists
    if [ ! -d "${PROJECT_ROOT}/ClaudeCode.xcodeproj" ]; then
        log_info "Generating Xcode project..."
        (cd "$PROJECT_ROOT" && xcodegen)
    fi
    
    # Run Xcode analyzer
    xcodebuild analyze \
        -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
        -scheme ClaudeCode \
        -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
        CLANG_ANALYZER_SECURITY_FLOATLOOPCOUNTER=YES \
        CLANG_ANALYZER_SECURITY_INSECUREAPI_RAND=YES \
        CLANG_ANALYZER_SECURITY_KEYCHAIN_API=YES \
        > "${REPORTS_DIR}/static-analysis.log" 2>&1 || {
            log_warning "Static analysis found issues. Check ${REPORTS_DIR}/static-analysis.log"
        }
    
    # Check for unused code with Periphery
    if command -v periphery &> /dev/null; then
        log_info "Checking for unused code..."
        periphery scan \
            --project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
            --schemes ClaudeCode \
            --targets ClaudeCode \
            --format json \
            > "${REPORTS_DIR}/unused-code.json" || true
    else
        log_info "Periphery not installed. Install with: brew install periphery"
    fi
    
    log_success "Static analysis complete"
}

# Check code complexity
check_complexity() {
    log_info "Checking code complexity..."
    
    # Create complexity report
    cat > "${REPORTS_DIR}/complexity.md" <<EOF
# Code Complexity Report

Generated on: $(date)

## Metrics

### Lines of Code
\`\`\`
Swift: $(find "${PROJECT_ROOT}/Sources" -name "*.swift" | xargs wc -l | tail -1 | awk '{print $1}')
Tests: $(find "${PROJECT_ROOT}/Tests" -name "*.swift" | xargs wc -l | tail -1 | awk '{print $1}')
UI Tests: $(find "${PROJECT_ROOT}/UITests" -name "*.swift" | xargs wc -l | tail -1 | awk '{print $1}')
\`\`\`

### File Count
\`\`\`
Swift Files: $(find "${PROJECT_ROOT}/Sources" -name "*.swift" | wc -l)
Test Files: $(find "${PROJECT_ROOT}/Tests" -name "*.swift" | wc -l)
\`\`\`

### Largest Files
\`\`\`
$(find "${PROJECT_ROOT}/Sources" -name "*.swift" -exec wc -l {} \; | sort -rn | head -10)
\`\`\`
EOF
    
    log_success "Complexity report generated: ${REPORTS_DIR}/complexity.md"
}

# Check code duplication
check_duplication() {
    log_info "Checking for code duplication..."
    
    if command -v jscpd &> /dev/null; then
        jscpd "${PROJECT_ROOT}/Sources" \
            --reporters "json,console" \
            --output "${REPORTS_DIR}" \
            --ignore "**/*.generated.swift" || true
    else
        log_info "jscpd not installed. Install with: npm install -g jscpd"
        
        # Basic duplication check
        log_info "Running basic duplication check..."
        find "${PROJECT_ROOT}/Sources" -name "*.swift" -exec md5 {} \; | \
            sort | uniq -d -w 32 > "${REPORTS_DIR}/duplicate-files.txt"
    fi
    
    log_success "Duplication check complete"
}

# Run all quality checks
run_all() {
    setup_directories
    run_lint
    run_format
    run_analyze
    check_complexity
    check_duplication
    
    log_success "All quality checks complete!"
    log_info "Reports available at: ${REPORTS_DIR}"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "=========================================="
    echo "Claude Code iOS - Quality Checks"
    echo "=========================================="
    echo
    
    local action="${1:-all}"
    
    case "$action" in
        lint)
            setup_directories
            run_lint
            ;;
        
        format)
            run_format
            ;;
        
        analyze)
            setup_directories
            run_analyze
            ;;
        
        complexity)
            setup_directories
            check_complexity
            ;;
        
        duplication)
            setup_directories
            check_duplication
            ;;
        
        all)
            run_all
            ;;
        
        help|--help|-h)
            echo "Usage: $0 [action]"
            echo
            echo "Actions:"
            echo "  all         - Run all quality checks (default)"
            echo "  lint        - Run SwiftLint"
            echo "  format      - Run SwiftFormat"
            echo "  analyze     - Run static analysis"
            echo "  complexity  - Check code complexity"
            echo "  duplication - Check for code duplication"
            echo "  help        - Show this help message"
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