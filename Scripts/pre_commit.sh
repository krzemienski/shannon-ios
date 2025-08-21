#!/bin/bash

# Claude Code iOS - Pre-commit Hook Script
# Run quality checks before allowing commits

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.swift$' || true)

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

# Check if there are Swift files to check
check_swift_files() {
    if [ -z "$SWIFT_FILES" ]; then
        log_info "No Swift files to check"
        return 1
    fi
    return 0
}

# Run SwiftLint
run_swiftlint() {
    if ! command -v swiftlint &> /dev/null; then
        log_warning "SwiftLint not installed. Install with: brew install swiftlint"
        return 0
    fi
    
    log_info "Running SwiftLint..."
    
    local lint_errors=0
    for file in $SWIFT_FILES; do
        if [ -f "$file" ]; then
            swiftlint lint --path "$file" --quiet || lint_errors=$((lint_errors + 1))
        fi
    done
    
    if [ $lint_errors -gt 0 ]; then
        log_error "SwiftLint found issues in $lint_errors file(s)"
        log_info "Fix the issues or run: swiftlint autocorrect"
        return 1
    fi
    
    log_success "SwiftLint passed"
    return 0
}

# Run SwiftFormat
run_swiftformat() {
    if ! command -v swiftformat &> /dev/null; then
        log_warning "SwiftFormat not installed. Install with: brew install swiftformat"
        return 0
    fi
    
    log_info "Running SwiftFormat..."
    
    for file in $SWIFT_FILES; do
        if [ -f "$file" ]; then
            swiftformat "$file" --quiet
            git add "$file"  # Re-add formatted file
        fi
    done
    
    log_success "SwiftFormat completed"
    return 0
}

# Check for build errors
check_build() {
    log_info "Checking for build errors..."
    
    # Generate project if needed
    if [ ! -d "${PROJECT_ROOT}/ClaudeCode.xcodeproj" ]; then
        log_info "Generating Xcode project..."
        (cd "$PROJECT_ROOT" && xcodegen generate)
    fi
    
    # Quick build check (syntax only)
    xcodebuild \
        -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
        -scheme ClaudeCode \
        -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
        -dry-run \
        2>&1 | grep -E "(error|warning):" || true
    
    log_success "Build check completed"
    return 0
}

# Check for sensitive information
check_secrets() {
    log_info "Checking for sensitive information..."
    
    local patterns=(
        "password"
        "secret"
        "apikey"
        "api_key"
        "token"
        "private_key"
        "-----BEGIN"
    )
    
    local found_secrets=false
    for file in $SWIFT_FILES; do
        if [ -f "$file" ]; then
            for pattern in "${patterns[@]}"; do
                if grep -qi "$pattern" "$file"; then
                    log_warning "Potential sensitive information found in $file"
                    found_secrets=true
                fi
            done
        fi
    done
    
    if [ "$found_secrets" = true ]; then
        log_error "Sensitive information detected. Please review your changes."
        log_info "Use environment variables or keychain for secrets"
        return 1
    fi
    
    log_success "No sensitive information detected"
    return 0
}

# Check file sizes
check_file_sizes() {
    log_info "Checking file sizes..."
    
    local large_files=0
    local max_size=1048576  # 1MB in bytes
    
    for file in $(git diff --cached --name-only); do
        if [ -f "$file" ]; then
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            if [ "$size" -gt "$max_size" ]; then
                log_warning "Large file detected: $file ($(($size / 1024))KB)"
                large_files=$((large_files + 1))
            fi
        fi
    done
    
    if [ $large_files -gt 0 ]; then
        log_warning "$large_files large file(s) detected"
        log_info "Consider using Git LFS for large files"
    fi
    
    return 0
}

# Check TODOs and FIXMEs
check_todos() {
    log_info "Checking for TODOs and FIXMEs..."
    
    local todo_count=0
    local fixme_count=0
    
    for file in $SWIFT_FILES; do
        if [ -f "$file" ]; then
            todo_count=$((todo_count + $(grep -c "TODO:" "$file" || true)))
            fixme_count=$((fixme_count + $(grep -c "FIXME:" "$file" || true)))
        fi
    done
    
    if [ $todo_count -gt 0 ] || [ $fixme_count -gt 0 ]; then
        log_warning "Found $todo_count TODOs and $fixme_count FIXMEs"
        log_info "Consider addressing these before committing"
    fi
    
    return 0
}

# Run unit tests (optional, can be slow)
run_tests() {
    if [ "${SKIP_TESTS:-0}" = "1" ]; then
        log_info "Skipping tests (SKIP_TESTS=1)"
        return 0
    fi
    
    if [ "${RUN_TESTS:-0}" = "1" ]; then
        log_info "Running unit tests..."
        
        xcodebuild test \
            -project "${PROJECT_ROOT}/ClaudeCode.xcodeproj" \
            -scheme ClaudeCode \
            -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
            -only-testing:ClaudeCodeTests \
            -quiet || {
                log_error "Tests failed"
                return 1
            }
        
        log_success "Tests passed"
    else
        log_info "Skipping tests. Set RUN_TESTS=1 to enable"
    fi
    
    return 0
}

# Install git hooks
install_hooks() {
    log_info "Installing git hooks..."
    
    local hooks_dir="${PROJECT_ROOT}/.git/hooks"
    
    if [ ! -d "$hooks_dir" ]; then
        log_error "Not a git repository"
        return 1
    fi
    
    # Create pre-commit hook
    cat > "$hooks_dir/pre-commit" <<'EOF'
#!/bin/bash
# Auto-generated pre-commit hook
./Scripts/pre_commit.sh
EOF
    
    chmod +x "$hooks_dir/pre-commit"
    
    log_success "Git hooks installed"
    log_info "Pre-commit hook will run automatically before each commit"
    return 0
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    local action="${1:-check}"
    
    case "$action" in
        check)
            echo "=========================================="
            echo "Claude Code iOS - Pre-commit Checks"
            echo "=========================================="
            echo
            
            local failed=false
            
            if check_swift_files; then
                run_swiftlint || failed=true
                run_swiftformat
                check_secrets || failed=true
            fi
            
            check_file_sizes
            check_todos
            # check_build  # Uncomment if you want build checks
            # run_tests    # Uncomment if you want test runs
            
            if [ "$failed" = true ]; then
                echo
                log_error "Pre-commit checks failed"
                log_info "Fix the issues and try again"
                exit 1
            fi
            
            echo
            log_success "All pre-commit checks passed!"
            ;;
        
        install)
            install_hooks
            ;;
        
        help|--help|-h)
            echo "Usage: $0 [action]"
            echo
            echo "Actions:"
            echo "  check    - Run pre-commit checks (default)"
            echo "  install  - Install git hooks"
            echo "  help     - Show this help message"
            echo
            echo "Environment variables:"
            echo "  SKIP_TESTS=1  - Skip test execution"
            echo "  RUN_TESTS=1   - Enable test execution"
            echo
            echo "To bypass pre-commit hooks:"
            echo "  git commit --no-verify"
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