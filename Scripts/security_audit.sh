#!/bin/bash

# Claude Code iOS - Security Audit Script
# Comprehensive security checks for the iOS application

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPORTS_DIR="${PROJECT_ROOT}/security-reports"
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

# Setup directories
setup_directories() {
    mkdir -p "$REPORTS_DIR"
}

# Check for hardcoded secrets
check_secrets() {
    log_info "Checking for hardcoded secrets..."
    
    local report="${REPORTS_DIR}/secrets-scan.txt"
    echo "Security Scan Report - $(date)" > "$report"
    echo "================================" >> "$report"
    echo >> "$report"
    
    # Patterns to search for
    local patterns=(
        "password.*=.*['\"]"
        "api[_-]?key.*=.*['\"]"
        "secret.*=.*['\"]"
        "token.*=.*['\"]"
        "private[_-]?key"
        "-----BEGIN.*PRIVATE"
        "AWS[_-]?ACCESS"
        "AWS[_-]?SECRET"
    )
    
    local found_issues=false
    
    for pattern in "${patterns[@]}"; do
        log_info "Scanning for: $pattern"
        local results=$(grep -r -i -n "$pattern" "${PROJECT_ROOT}/Sources" 2>/dev/null || true)
        
        if [ -n "$results" ]; then
            echo "Found potential secret pattern: $pattern" >> "$report"
            echo "$results" >> "$report"
            echo >> "$report"
            found_issues=true
            log_warning "Found potential secrets matching: $pattern"
        fi
    done
    
    if [ "$found_issues" = true ]; then
        log_warning "Potential secrets found. Review: $report"
    else
        log_success "No hardcoded secrets detected"
    fi
}

# Check dependencies for vulnerabilities
check_dependencies() {
    log_info "Checking dependencies for vulnerabilities..."
    
    local report="${REPORTS_DIR}/dependency-audit.txt"
    
    # Check Swift Package Manager dependencies
    if [ -f "${PROJECT_ROOT}/Package.resolved" ]; then
        log_info "Analyzing Swift packages..."
        
        # Extract package URLs and versions
        cat "${PROJECT_ROOT}/Package.resolved" | \
            grep -E "(repositoryURL|version)" > "$report" || true
        
        # Check for outdated packages
        if command -v swift-outdated &> /dev/null; then
            swift-outdated > "${REPORTS_DIR}/outdated-packages.txt" || true
            log_info "Outdated packages report: ${REPORTS_DIR}/outdated-packages.txt"
        else
            log_info "swift-outdated not installed. Install with: mint install kiliankoe/swift-outdated"
        fi
    fi
    
    # Check CocoaPods if Podfile exists
    if [ -f "${PROJECT_ROOT}/Podfile" ]; then
        log_info "Analyzing CocoaPods..."
        
        if command -v pod-audit &> /dev/null; then
            pod-audit > "${REPORTS_DIR}/pod-audit.txt" || true
        else
            log_info "pod-audit not installed"
        fi
    fi
    
    log_success "Dependency check complete"
}

# Check App Transport Security settings
check_ats() {
    log_info "Checking App Transport Security settings..."
    
    local report="${REPORTS_DIR}/ats-check.txt"
    local plist="${PROJECT_ROOT}/Info.plist"
    
    if [ -f "$plist" ]; then
        # Check for ATS exceptions
        local ats_exceptions=$(/usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity" "$plist" 2>/dev/null || echo "none")
        
        if [ "$ats_exceptions" != "none" ]; then
            log_warning "ATS exceptions found:"
            echo "$ats_exceptions" | tee "$report"
            log_info "Review ATS exceptions for security implications"
        else
            log_success "No ATS exceptions found (good security practice)"
        fi
    fi
}

# Check keychain usage
check_keychain() {
    log_info "Checking keychain usage..."
    
    local report="${REPORTS_DIR}/keychain-usage.txt"
    
    # Search for keychain API usage
    grep -r "Keychain\|kSecClass\|SecItem" "${PROJECT_ROOT}/Sources" > "$report" 2>/dev/null || true
    
    if [ -s "$report" ]; then
        log_info "Keychain usage found. Verify proper implementation:"
        head -5 "$report"
    else
        log_warning "No keychain usage found. Consider using keychain for sensitive data"
    fi
}

# Check cryptography usage
check_crypto() {
    log_info "Checking cryptography usage..."
    
    local report="${REPORTS_DIR}/crypto-usage.txt"
    
    # Search for crypto API usage
    grep -r "CommonCrypto\|CryptoKit\|Security\.framework" "${PROJECT_ROOT}/Sources" > "$report" 2>/dev/null || true
    
    # Check for weak algorithms
    local weak_algos=(
        "MD5"
        "SHA1"
        "DES"
        "RC4"
    )
    
    for algo in "${weak_algos[@]}"; do
        local usage=$(grep -r "$algo" "${PROJECT_ROOT}/Sources" 2>/dev/null || true)
        if [ -n "$usage" ]; then
            log_warning "Weak algorithm detected: $algo"
            echo "Weak algorithm $algo usage:" >> "$report"
            echo "$usage" >> "$report"
        fi
    done
    
    log_success "Cryptography check complete"
}

# Check permissions usage
check_permissions() {
    log_info "Checking permissions usage..."
    
    local report="${REPORTS_DIR}/permissions.txt"
    local plist="${PROJECT_ROOT}/Info.plist"
    
    if [ -f "$plist" ]; then
        echo "Permission Usage Descriptions:" > "$report"
        echo "==============================" >> "$report"
        
        # Check for permission keys
        local permission_keys=(
            "NSCameraUsageDescription"
            "NSPhotoLibraryUsageDescription"
            "NSLocationWhenInUseUsageDescription"
            "NSLocationAlwaysUsageDescription"
            "NSMicrophoneUsageDescription"
            "NSContactsUsageDescription"
            "NSCalendarsUsageDescription"
            "NSFaceIDUsageDescription"
        )
        
        for key in "${permission_keys[@]}"; do
            local value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || echo "")
            if [ -n "$value" ]; then
                echo "$key: $value" >> "$report"
                log_info "Permission found: $key"
            fi
        done
    fi
    
    log_success "Permissions check complete"
}

# Run OWASP Mobile Top 10 checks
check_owasp() {
    log_info "Running OWASP Mobile Top 10 checks..."
    
    local report="${REPORTS_DIR}/owasp-top10.md"
    
    cat > "$report" <<EOF
# OWASP Mobile Top 10 Security Audit

Generated on: $(date)

## M1: Improper Platform Usage
- [ ] Check for proper use of platform security features
- [ ] Verify keychain usage for sensitive data
- [ ] Check biometric authentication implementation

## M2: Insecure Data Storage
- [ ] No sensitive data in UserDefaults
- [ ] No sensitive data in plain text files
- [ ] Encrypted Core Data if storing sensitive info

## M3: Insecure Communication
- [ ] HTTPS only (no HTTP)
- [ ] Certificate pinning implemented
- [ ] No ATS exceptions without justification

## M4: Insecure Authentication
- [ ] Strong authentication mechanisms
- [ ] Secure session management
- [ ] Biometric authentication where appropriate

## M5: Insufficient Cryptography
- [ ] No weak algorithms (MD5, SHA1, DES)
- [ ] Proper key management
- [ ] Use of iOS crypto APIs

## M6: Insecure Authorization
- [ ] Proper authorization checks
- [ ] Role-based access control
- [ ] Server-side authorization

## M7: Client Code Quality
- [ ] Input validation
- [ ] No SQL injection vulnerabilities
- [ ] Proper error handling

## M8: Code Tampering
- [ ] Jailbreak detection
- [ ] Anti-debugging measures
- [ ] Code obfuscation for sensitive logic

## M9: Reverse Engineering
- [ ] String obfuscation
- [ ] No sensitive data in binary
- [ ] Anti-tampering checks

## M10: Extraneous Functionality
- [ ] No test code in production
- [ ] No hidden features
- [ ] No development endpoints
EOF
    
    log_success "OWASP checklist created: $report"
}

# Generate security report
generate_report() {
    log_info "Generating security summary..."
    
    local summary="${REPORTS_DIR}/security-summary.md"
    
    cat > "$summary" <<EOF
# Security Audit Summary

Generated on: $(date)

## Scan Results

### Secrets Scan
$([ -f "${REPORTS_DIR}/secrets-scan.txt" ] && echo "✅ Completed" || echo "❌ Not run")

### Dependency Audit
$([ -f "${REPORTS_DIR}/dependency-audit.txt" ] && echo "✅ Completed" || echo "❌ Not run")

### ATS Check
$([ -f "${REPORTS_DIR}/ats-check.txt" ] && echo "✅ Completed" || echo "❌ Not run")

### Keychain Usage
$([ -f "${REPORTS_DIR}/keychain-usage.txt" ] && echo "✅ Completed" || echo "❌ Not run")

### Cryptography Check
$([ -f "${REPORTS_DIR}/crypto-usage.txt" ] && echo "✅ Completed" || echo "❌ Not run")

### Permissions Review
$([ -f "${REPORTS_DIR}/permissions.txt" ] && echo "✅ Completed" || echo "❌ Not run")

### OWASP Top 10
$([ -f "${REPORTS_DIR}/owasp-top10.md" ] && echo "✅ Checklist generated" || echo "❌ Not generated")

## Recommendations

1. Review all findings in individual reports
2. Address any hardcoded secrets immediately
3. Update dependencies with known vulnerabilities
4. Implement certificate pinning for API calls
5. Use keychain for all sensitive data storage
6. Enable jailbreak detection for production builds
7. Implement proper input validation
8. Review and minimize required permissions

## Report Files
$(ls -la "${REPORTS_DIR}" 2>/dev/null || echo "No reports generated")
EOF
    
    log_success "Security summary generated: $summary"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "=========================================="
    echo "Claude Code iOS - Security Audit"
    echo "=========================================="
    echo
    
    local action="${1:-all}"
    
    case "$action" in
        secrets)
            setup_directories
            check_secrets
            ;;
        
        dependencies)
            setup_directories
            check_dependencies
            ;;
        
        ats)
            setup_directories
            check_ats
            ;;
        
        keychain)
            setup_directories
            check_keychain
            ;;
        
        crypto)
            setup_directories
            check_crypto
            ;;
        
        permissions)
            setup_directories
            check_permissions
            ;;
        
        owasp)
            setup_directories
            check_owasp
            ;;
        
        all)
            setup_directories
            check_secrets
            check_dependencies
            check_ats
            check_keychain
            check_crypto
            check_permissions
            check_owasp
            generate_report
            log_success "Security audit complete!"
            log_info "Reports available at: ${REPORTS_DIR}"
            ;;
        
        help|--help|-h)
            echo "Usage: $0 [action]"
            echo
            echo "Actions:"
            echo "  all          - Run all security checks (default)"
            echo "  secrets      - Check for hardcoded secrets"
            echo "  dependencies - Audit dependencies for vulnerabilities"
            echo "  ats          - Check App Transport Security settings"
            echo "  keychain     - Review keychain usage"
            echo "  crypto       - Check cryptography implementation"
            echo "  permissions  - Review app permissions"
            echo "  owasp        - Generate OWASP Top 10 checklist"
            echo "  help         - Show this help message"
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