#!/bin/bash

# Claude Code iOS - Documentation Generation Script
# Generate code documentation using various tools

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DOCS_DIR="${PROJECT_ROOT}/docs"
readonly BUILD_DIR="${PROJECT_ROOT}/build/docs"
readonly SCHEME_NAME="ClaudeCode"

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
    log_info "Setting up documentation directories..."
    mkdir -p "$DOCS_DIR"
    mkdir -p "$BUILD_DIR"
    log_success "Directories created"
}

# Check for documentation tools
check_dependencies() {
    log_info "Checking documentation tools..."
    
    local has_tools=false
    
    # Check for Swift-DocC (built into Xcode 13+)
    if xcodebuild -version | grep -q "Xcode 1[3-9]"; then
        log_success "Swift-DocC available (built into Xcode)"
        has_tools=true
    fi
    
    # Check for jazzy
    if command -v jazzy &> /dev/null; then
        log_success "jazzy installed"
        has_tools=true
    else
        log_info "jazzy not installed. Install with: gem install jazzy"
    fi
    
    # Check for swift-doc
    if command -v swift-doc &> /dev/null; then
        log_success "swift-doc installed"
        has_tools=true
    else
        log_info "swift-doc not installed. Install with: brew install swiftdocorg/formulae/swift-doc"
    fi
    
    # Check for sourcedocs
    if command -v sourcedocs &> /dev/null; then
        log_success "SourceDocs installed"
        has_tools=true
    else
        log_info "SourceDocs not installed. Install with: brew install sourcedocs"
    fi
    
    if [ "$has_tools" = false ]; then
        log_error "No documentation tools found. Please install at least one."
        exit 1
    fi
}

# Generate documentation with Swift-DocC
generate_docc() {
    log_info "Generating documentation with Swift-DocC..."
    
    # Build documentation catalog
    xcodebuild docbuild \
        -scheme "$SCHEME_NAME" \
        -derivedDataPath "$BUILD_DIR" \
        -destination "generic/platform=iOS" || {
            log_warning "DocC generation failed"
            return 1
        }
    
    # Find the .doccarchive
    local docc_archive=$(find "$BUILD_DIR" -name "*.doccarchive" -type d | head -n 1)
    
    if [ -n "$docc_archive" ]; then
        # Copy to docs directory
        cp -r "$docc_archive" "$DOCS_DIR/"
        log_success "DocC documentation generated"
        
        # Generate static website from DocC
        if command -v docc &> /dev/null; then
            log_info "Converting to static website..."
            docc process-archive transform-for-static-hosting \
                "$docc_archive" \
                --output-path "${DOCS_DIR}/docc-website" \
                --hosting-base-path "/ClaudeCode"
            log_success "Static website generated at ${DOCS_DIR}/docc-website"
        fi
    else
        log_warning "DocC archive not found"
    fi
}

# Generate documentation with jazzy
generate_jazzy() {
    if ! command -v jazzy &> /dev/null; then
        log_warning "jazzy not installed, skipping"
        return
    fi
    
    log_info "Generating documentation with jazzy..."
    
    # Create jazzy config
    cat > "${PROJECT_ROOT}/.jazzy.yaml" <<EOF
module: ClaudeCode
author: Claude Code Team
github_url: https://github.com/yourusername/claude-code-ios
output: ${DOCS_DIR}/jazzy
theme: fullwidth
clean: true
xcodebuild_arguments:
  - -project
  - ClaudeCode.xcodeproj
  - -scheme
  - ClaudeCode
  - -destination
  - "generic/platform=iOS"
min_acl: internal
swift_build_tool: xcodebuild
EOF
    
    # Run jazzy
    (cd "$PROJECT_ROOT" && jazzy) || {
        log_warning "jazzy generation failed"
        return 1
    }
    
    log_success "jazzy documentation generated at ${DOCS_DIR}/jazzy"
}

# Generate documentation with swift-doc
generate_swift_doc() {
    if ! command -v swift-doc &> /dev/null; then
        log_warning "swift-doc not installed, skipping"
        return
    fi
    
    log_info "Generating documentation with swift-doc..."
    
    # Generate documentation
    swift-doc generate "${PROJECT_ROOT}/Sources" \
        --module-name ClaudeCode \
        --output "${DOCS_DIR}/swift-doc" \
        --format html || {
            log_warning "swift-doc generation failed"
            return 1
        }
    
    log_success "swift-doc documentation generated at ${DOCS_DIR}/swift-doc"
}

# Generate documentation with SourceDocs
generate_sourcedocs() {
    if ! command -v sourcedocs &> /dev/null; then
        log_warning "SourceDocs not installed, skipping"
        return
    fi
    
    log_info "Generating documentation with SourceDocs..."
    
    # Generate markdown documentation
    sourcedocs generate \
        --all-modules \
        --output-folder "${DOCS_DIR}/sourcedocs" || {
            log_warning "SourceDocs generation failed"
            return 1
        }
    
    log_success "SourceDocs documentation generated at ${DOCS_DIR}/sourcedocs"
}

# Generate README documentation
generate_readme_docs() {
    log_info "Generating README documentation..."
    
    # Create API documentation
    cat > "${DOCS_DIR}/API.md" <<EOF
# Claude Code iOS - API Documentation

## Overview
This document provides an overview of the Claude Code iOS application's API structure.

## Core Components

### Architecture
- **MVVM Pattern**: Model-View-ViewModel architecture
- **Coordinators**: Navigation flow management
- **Dependency Injection**: Service locator pattern

### Key Services
- **APIClient**: Network communication
- **SSHManager**: SSH connection management
- **StateManager**: Application state management

### View Models
- **ChatViewModel**: Chat interface logic
- **ProjectViewModel**: Project management
- **ToolsViewModel**: Tool execution
- **MonitorViewModel**: System monitoring
- **SettingsViewModel**: App configuration

## For detailed documentation, see:
- [Architecture Guide](architecture-implementation.md)
- [Component Guide](component-architecture.md)
- [Theme System](theme-system-design.md)
- [Backend Integration](backend-integration-guide.md)
EOF
    
    log_success "README documentation generated"
}

# Generate code statistics
generate_code_stats() {
    log_info "Generating code statistics..."
    
    cat > "${DOCS_DIR}/code-statistics.md" <<EOF
# Code Statistics

Generated on: $(date)

## Lines of Code
\`\`\`
$(find "${PROJECT_ROOT}/Sources" -name "*.swift" | xargs wc -l | tail -1)
\`\`\`

## File Count
\`\`\`
Swift Files: $(find "${PROJECT_ROOT}/Sources" -name "*.swift" | wc -l)
Test Files: $(find "${PROJECT_ROOT}/Tests" -name "*.swift" | wc -l)
UI Test Files: $(find "${PROJECT_ROOT}/UITests" -name "*.swift" | wc -l)
\`\`\`

## Directory Structure
\`\`\`
$(tree -d -L 3 "${PROJECT_ROOT}/Sources" 2>/dev/null || find "${PROJECT_ROOT}/Sources" -type d -maxdepth 3)
\`\`\`
EOF
    
    log_success "Code statistics generated"
}

# Serve documentation locally
serve_docs() {
    log_info "Starting documentation server..."
    
    # Check if Python is available
    if command -v python3 &> /dev/null; then
        log_info "Documentation available at: http://localhost:8080"
        log_info "Press Ctrl+C to stop the server"
        (cd "$DOCS_DIR" && python3 -m http.server 8080)
    else
        log_warning "Python not available for serving documentation"
        log_info "Documentation generated at: $DOCS_DIR"
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "=========================================="
    echo "Claude Code iOS - Documentation Generator"
    echo "=========================================="
    echo
    
    # Parse command line arguments
    local action="${1:-generate}"
    
    case "$action" in
        generate)
            setup_directories
            check_dependencies
            
            # Try all available documentation tools
            generate_docc
            generate_jazzy
            generate_swift_doc
            generate_sourcedocs
            generate_readme_docs
            generate_code_stats
            
            log_success "Documentation generation complete!"
            log_info "Documentation available at: $DOCS_DIR"
            ;;
        
        docc)
            setup_directories
            generate_docc
            ;;
        
        jazzy)
            setup_directories
            generate_jazzy
            ;;
        
        swift-doc)
            setup_directories
            generate_swift_doc
            ;;
        
        sourcedocs)
            setup_directories
            generate_sourcedocs
            ;;
        
        stats)
            setup_directories
            generate_code_stats
            ;;
        
        serve)
            serve_docs
            ;;
        
        clean)
            log_info "Cleaning documentation..."
            rm -rf "$BUILD_DIR"
            rm -rf "${DOCS_DIR}/jazzy"
            rm -rf "${DOCS_DIR}/swift-doc"
            rm -rf "${DOCS_DIR}/sourcedocs"
            rm -rf "${DOCS_DIR}/docc-website"
            rm -f "${DOCS_DIR}/*.doccarchive"
            log_success "Documentation cleaned"
            ;;
        
        help|--help|-h)
            echo "Usage: $0 [action]"
            echo
            echo "Actions:"
            echo "  generate   - Generate all documentation (default)"
            echo "  docc       - Generate Swift-DocC documentation"
            echo "  jazzy      - Generate jazzy documentation"
            echo "  swift-doc  - Generate swift-doc documentation"
            echo "  sourcedocs - Generate SourceDocs documentation"
            echo "  stats      - Generate code statistics"
            echo "  serve      - Serve documentation locally"
            echo "  clean      - Clean generated documentation"
            echo "  help       - Show this help message"
            echo
            echo "Documentation tools:"
            echo "  - Swift-DocC (built into Xcode 13+)"
            echo "  - jazzy: gem install jazzy"
            echo "  - swift-doc: brew install swiftdocorg/formulae/swift-doc"
            echo "  - SourceDocs: brew install sourcedocs"
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