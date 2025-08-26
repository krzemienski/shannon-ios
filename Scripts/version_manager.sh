#!/bin/bash

# Claude Code iOS - Version Management System
# Automated version bumping, changelog generation, and release management
# Version: 2.0.0

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly VERSION_FILE="${PROJECT_ROOT}/.version"
readonly CHANGELOG_FILE="${PROJECT_ROOT}/CHANGELOG.md"
readonly RELEASE_NOTES_DIR="${PROJECT_ROOT}/release-notes"
readonly INFO_PLIST="${PROJECT_ROOT}/Info.plist"
readonly PROJECT_YML="${PROJECT_ROOT}/Project.yml"

# Version components
readonly VERSION_REGEX='^([0-9]+)\.([0-9]+)\.([0-9]+)(-([a-zA-Z]+)\.([0-9]+))?$'

# Git configuration
readonly DEFAULT_BRANCH="main"
readonly RELEASE_BRANCH_PREFIX="release/"
readonly TAG_PREFIX="v"

# Changelog categories
readonly CHANGELOG_CATEGORIES=(
    "Added:✨ Features"
    "Changed:🔄 Changes"
    "Deprecated:⚠️ Deprecated"
    "Removed:🗑️ Removed"
    "Fixed:🐛 Bug Fixes"
    "Security:🔒 Security"
    "Performance:⚡ Performance"
    "Documentation:📝 Documentation"
)

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_header() {
    echo
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD} $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

log_info() {
    echo -e "${BLUE}ℹ️  ${NC}$1"
}

log_success() {
    echo -e "${GREEN}✅ ${NC}$1"
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${NC}$1"
}

log_error() {
    echo -e "${RED}❌ ${NC}$1" >&2
}

log_step() {
    echo -e "${MAGENTA}▶ ${NC}$1"
}

# Ensure directory exists
ensure_dir() {
    mkdir -p "$1"
}

# ============================================================================
# VERSION MANAGEMENT
# ============================================================================

# Get current version from file
get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        # Try to get from Info.plist
        if [[ -f "$INFO_PLIST" ]]; then
            /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0"
        else
            echo "1.0.0"
        fi
    fi
}

# Parse version components
parse_version() {
    local version="$1"
    
    if [[ ! "$version" =~ $VERSION_REGEX ]]; then
        log_error "Invalid version format: $version"
        return 1
    fi
    
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} ${BASH_REMATCH[5]:-} ${BASH_REMATCH[6]:-}"
}

# Compare two versions
compare_versions() {
    local version1="$1"
    local version2="$2"
    
    IFS='.' read -r v1_major v1_minor v1_patch <<< "${version1%%-*}"
    IFS='.' read -r v2_major v2_minor v2_patch <<< "${version2%%-*}"
    
    if (( v1_major > v2_major )); then
        echo 1
    elif (( v1_major < v2_major )); then
        echo -1
    elif (( v1_minor > v2_minor )); then
        echo 1
    elif (( v1_minor < v2_minor )); then
        echo -1
    elif (( v1_patch > v2_patch )); then
        echo 1
    elif (( v1_patch < v2_patch )); then
        echo -1
    else
        echo 0
    fi
}

# Bump version
bump_version() {
    local bump_type="${1:-patch}"
    local prerelease="${2:-}"
    local current_version
    current_version=$(get_current_version)
    
    log_header "Version Bump: $bump_type"
    log_info "Current version: $current_version"
    
    # Parse current version
    IFS=' ' read -r major minor patch pre_type pre_num <<< "$(parse_version "$current_version")"
    
    # Handle version bump
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            pre_type=""
            pre_num=""
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            pre_type=""
            pre_num=""
            ;;
        patch)
            if [[ -n "$pre_type" ]]; then
                # If current is prerelease, just remove prerelease
                pre_type=""
                pre_num=""
            else
                patch=$((patch + 1))
            fi
            ;;
        prerelease)
            if [[ -n "$prerelease" ]]; then
                if [[ "$pre_type" == "$prerelease" ]]; then
                    # Increment prerelease number
                    pre_num=$((pre_num + 1))
                else
                    # New prerelease type
                    pre_type="$prerelease"
                    pre_num=1
                fi
            else
                log_error "Prerelease type required for prerelease bump"
                return 1
            fi
            ;;
        *)
            log_error "Invalid bump type: $bump_type"
            return 1
            ;;
    esac
    
    # Construct new version
    local new_version="${major}.${minor}.${patch}"
    if [[ -n "$pre_type" ]]; then
        new_version="${new_version}-${pre_type}.${pre_num}"
    fi
    
    log_success "New version: $new_version"
    
    # Update version in all locations
    update_version_everywhere "$new_version"
    
    echo "$new_version"
}

# Update version in all project files
update_version_everywhere() {
    local version="$1"
    local build_number="${2:-$(date +%Y%m%d%H%M)}"
    
    log_step "Updating version to $version (build $build_number)..."
    
    # Update version file
    echo "$version" > "$VERSION_FILE"
    log_success "Updated $VERSION_FILE"
    
    # Update Info.plist
    if [[ -f "$INFO_PLIST" ]]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$INFO_PLIST" || true
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$INFO_PLIST" || true
        log_success "Updated Info.plist"
    fi
    
    # Update Project.yml (if using XcodeGen)
    if [[ -f "$PROJECT_YML" ]]; then
        # Use sed to update version in Project.yml
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/MARKETING_VERSION: .*/MARKETING_VERSION: $version/" "$PROJECT_YML"
            sed -i '' "s/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: $build_number/" "$PROJECT_YML"
        else
            sed -i "s/MARKETING_VERSION: .*/MARKETING_VERSION: $version/" "$PROJECT_YML"
            sed -i "s/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: $build_number/" "$PROJECT_YML"
        fi
        log_success "Updated Project.yml"
    fi
    
    # Update using agvtool if available
    if command -v agvtool &>/dev/null; then
        (cd "$PROJECT_ROOT" && agvtool new-marketing-version "$version" &>/dev/null) || true
        (cd "$PROJECT_ROOT" && agvtool new-version -all "$build_number" &>/dev/null) || true
        log_success "Updated with agvtool"
    fi
}

# ============================================================================
# CHANGELOG MANAGEMENT
# ============================================================================

# Initialize changelog
init_changelog() {
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        log_step "Initializing CHANGELOG.md..."
        
        cat > "$CHANGELOG_FILE" <<'EOF'
# Changelog

All notable changes to Claude Code iOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release

EOF
        log_success "CHANGELOG.md initialized"
    fi
}

# Add entry to changelog
add_changelog_entry() {
    local category="$1"
    local message="$2"
    local version="${3:-Unreleased}"
    
    init_changelog
    
    # Find the section for the version
    local section_line
    section_line=$(grep -n "## \[$version\]" "$CHANGELOG_FILE" | cut -d: -f1 | head -1)
    
    if [[ -z "$section_line" ]]; then
        # Add new version section after [Unreleased]
        local unreleased_line
        unreleased_line=$(grep -n "## \[Unreleased\]" "$CHANGELOG_FILE" | cut -d: -f1)
        
        if [[ -n "$unreleased_line" ]]; then
            # Insert new version section
            local insert_line=$((unreleased_line + 2))
            local date=$(date +%Y-%m-%d)
            
            sed -i "" "${insert_line}i\\
\\
## [$version] - $date\\
\\
### $category\\
- $message" "$CHANGELOG_FILE"
        fi
    else
        # Find or create category within version section
        local category_line
        category_line=$(awk -v start="$section_line" -v cat="### $category" \
            'NR > start && $0 ~ cat { print NR; exit }' "$CHANGELOG_FILE")
        
        if [[ -n "$category_line" ]]; then
            # Add to existing category
            sed -i "" "${category_line}a\\
- $message" "$CHANGELOG_FILE"
        else
            # Add new category
            local next_section
            next_section=$(awk -v start="$section_line" \
                'NR > start && /^## / { print NR; exit }' "$CHANGELOG_FILE")
            
            if [[ -n "$next_section" ]]; then
                local insert_line=$((next_section - 1))
            else
                local insert_line=$(wc -l < "$CHANGELOG_FILE")
            fi
            
            sed -i "" "${insert_line}i\\
\\
### $category\\
- $message" "$CHANGELOG_FILE"
        fi
    fi
    
    log_success "Added changelog entry: [$category] $message"
}

# Generate changelog from git commits
generate_changelog_from_git() {
    local from_tag="${1:-}"
    local to_tag="${2:-HEAD}"
    local version="${3:-Unreleased}"
    
    log_header "Generating Changelog from Git"
    
    # Determine commit range
    local range
    if [[ -n "$from_tag" ]]; then
        range="${from_tag}..${to_tag}"
    else
        # Find last tag
        from_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
        if [[ -n "$from_tag" ]]; then
            range="${from_tag}..${to_tag}"
        else
            range="HEAD~20..${to_tag}"
        fi
    fi
    
    log_info "Analyzing commits in range: $range"
    
    # Parse commits by conventional commit type
    local -A commits_by_type
    
    while IFS= read -r commit; do
        local hash="${commit%%|*}"
        local rest="${commit#*|}"
        local type="${rest%%:*}"
        local message="${rest#*: }"
        
        case "$type" in
            feat|feature)
                commits_by_type[Added]+="- $message\n"
                ;;
            fix|bugfix)
                commits_by_type[Fixed]+="- $message\n"
                ;;
            perf|performance)
                commits_by_type[Performance]+="- $message\n"
                ;;
            docs|documentation)
                commits_by_type[Documentation]+="- $message\n"
                ;;
            security|sec)
                commits_by_type[Security]+="- $message\n"
                ;;
            deprecated|deprecate)
                commits_by_type[Deprecated]+="- $message\n"
                ;;
            remove|removed)
                commits_by_type[Removed]+="- $message\n"
                ;;
            change|changed|refactor)
                commits_by_type[Changed]+="- $message\n"
                ;;
            *)
                # Try to categorize by keywords
                if [[ "$message" =~ (add|new|create|implement) ]]; then
                    commits_by_type[Added]+="- $message\n"
                elif [[ "$message" =~ (fix|repair|resolve|correct) ]]; then
                    commits_by_type[Fixed]+="- $message\n"
                elif [[ "$message" =~ (update|modify|change|refactor) ]]; then
                    commits_by_type[Changed]+="- $message\n"
                elif [[ "$message" =~ (remove|delete|clean) ]]; then
                    commits_by_type[Removed]+="- $message\n"
                elif [[ "$message" =~ (deprecate) ]]; then
                    commits_by_type[Deprecated]+="- $message\n"
                elif [[ "$message" =~ (security|vulnerability|cve) ]]; then
                    commits_by_type[Security]+="- $message\n"
                elif [[ "$message" =~ (performance|optimize|speed) ]]; then
                    commits_by_type[Performance]+="- $message\n"
                elif [[ "$message" =~ (doc|readme|comment) ]]; then
                    commits_by_type[Documentation]+="- $message\n"
                else
                    commits_by_type[Changed]+="- $message\n"
                fi
                ;;
        esac
    done < <(git log "$range" --pretty=format:"%h|%s" --no-merges)
    
    # Update changelog
    init_changelog
    
    # Add version header if not Unreleased
    if [[ "$version" != "Unreleased" ]]; then
        local date=$(date +%Y-%m-%d)
        
        # Check if version already exists
        if ! grep -q "## \[$version\]" "$CHANGELOG_FILE"; then
            # Add after [Unreleased]
            sed -i "" "/## \[Unreleased\]/a\\
\\
## [$version] - $date" "$CHANGELOG_FILE"
        fi
    fi
    
    # Add categorized commits
    for category in Added Changed Deprecated Removed Fixed Security Performance Documentation; do
        if [[ -n "${commits_by_type[$category]:-}" ]]; then
            echo -e "\n### $category" >> "$CHANGELOG_FILE"
            echo -e "${commits_by_type[$category]}" >> "$CHANGELOG_FILE"
        fi
    done
    
    log_success "Changelog generated for version $version"
}

# ============================================================================
# RELEASE NOTES GENERATION
# ============================================================================

# Generate release notes
generate_release_notes() {
    local version="${1:-$(get_current_version)}"
    local format="${2:-markdown}"
    
    log_header "Generating Release Notes for v$version"
    
    ensure_dir "$RELEASE_NOTES_DIR"
    
    local output_file="${RELEASE_NOTES_DIR}/release-notes-${version}.${format}"
    
    case "$format" in
        markdown|md)
            generate_markdown_release_notes "$version" > "$output_file"
            ;;
        html)
            generate_html_release_notes "$version" > "$output_file"
            ;;
        json)
            generate_json_release_notes "$version" > "$output_file"
            ;;
        *)
            log_error "Unknown format: $format"
            return 1
            ;;
    esac
    
    log_success "Release notes generated: $output_file"
    
    # Also generate a latest symlink
    ln -sf "$(basename "$output_file")" "${RELEASE_NOTES_DIR}/release-notes-latest.${format}"
    
    # Display preview
    echo
    echo "Preview:"
    echo "────────────────────────────────────────"
    head -20 "$output_file"
    echo "..."
    echo "────────────────────────────────────────"
}

# Generate markdown release notes
generate_markdown_release_notes() {
    local version="$1"
    local build_number=$(date +%Y%m%d%H%M)
    
    cat <<EOF
# Claude Code iOS v${version}

**Release Date**: $(date +"%B %d, %Y")  
**Build**: ${build_number}

## 🎉 Highlights

This release includes significant improvements to performance, stability, and user experience.

## ✨ What's New

EOF
    
    # Extract from changelog
    if [[ -f "$CHANGELOG_FILE" ]]; then
        local in_version=false
        local category=""
        
        while IFS= read -r line; do
            if [[ "$line" =~ ^##\ \[$version\] ]]; then
                in_version=true
            elif [[ "$line" =~ ^##\ \[ ]] && [[ "$in_version" == true ]]; then
                break
            elif [[ "$in_version" == true ]]; then
                if [[ "$line" =~ ^###\  ]]; then
                    category="${line#### }"
                    echo "### $category"
                elif [[ "$line" =~ ^-\  ]]; then
                    echo "$line"
                fi
            fi
        done < "$CHANGELOG_FILE"
    else
        # Fallback to git log
        echo "### Changes"
        git log --pretty=format:"- %s" -10
    fi
    
    cat <<EOF

## 📱 Compatibility

- **Minimum iOS Version**: 17.0
- **Supported Devices**: iPhone and iPad
- **Recommended**: iOS 17.2 or later for best experience

## 📦 Installation

### TestFlight
1. Join the beta: [TestFlight Link](https://testflight.apple.com/join/XXXXXXXXX)
2. Install the TestFlight app
3. Accept the invitation
4. Install Claude Code

### App Store
Coming soon!

## 🐛 Known Issues

- None reported in this release

## 📝 Notes

- This version includes automatic crash reporting
- Performance metrics are collected anonymously
- All data is encrypted end-to-end

## 🔗 Links

- [Documentation](https://docs.claudecode.app)
- [Support](https://support.claudecode.app)
- [Privacy Policy](https://claudecode.app/privacy)
- [Terms of Service](https://claudecode.app/terms)

## 💬 Feedback

We'd love to hear from you! Send feedback to:
- Email: feedback@claudecode.app
- Discord: [Join Server](https://discord.gg/claudecode)
- Twitter: [@claudecodeapp](https://twitter.com/claudecodeapp)

---

*Thank you for using Claude Code!* 🚀
EOF
}

# Generate HTML release notes
generate_html_release_notes() {
    local version="$1"
    
    cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Claude Code iOS v${version} - Release Notes</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container {
            background: white;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
        }
        h1 {
            color: #667eea;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
        }
        h2 {
            color: #764ba2;
            margin-top: 30px;
        }
        h3 {
            color: #555;
        }
        .highlight {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .badge {
            display: inline-block;
            padding: 3px 8px;
            background: #667eea;
            color: white;
            border-radius: 3px;
            font-size: 12px;
            margin-right: 5px;
        }
        ul {
            list-style-type: none;
            padding-left: 0;
        }
        ul li {
            position: relative;
            padding-left: 25px;
            margin: 10px 0;
        }
        ul li:before {
            content: "✨";
            position: absolute;
            left: 0;
        }
        .button {
            display: inline-block;
            padding: 12px 30px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            margin: 10px 5px;
        }
        .button:hover {
            background: #764ba2;
        }
        footer {
            margin-top: 50px;
            text-align: center;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Claude Code iOS v${version}</h1>
        
        <div class="highlight">
            <h2>🎉 Release Highlights</h2>
            <p>This release brings exciting new features and improvements!</p>
            <span class="badge">New Features</span>
            <span class="badge">Performance</span>
            <span class="badge">Bug Fixes</span>
        </div>
        
        <h2>✨ What's New</h2>
        <ul>
$(git log --pretty=format:"            <li>%s</li>" -10)
        </ul>
        
        <h2>📱 Requirements</h2>
        <ul>
            <li>iOS 17.0 or later</li>
            <li>iPhone or iPad</li>
            <li>50MB free storage</li>
        </ul>
        
        <h2>📦 Get Started</h2>
        <div style="text-align: center; margin: 30px 0;">
            <a href="https://testflight.apple.com/join/XXXXXX" class="button">Join TestFlight Beta</a>
            <a href="https://apps.apple.com/app/claude-code/idXXXXXX" class="button">Download from App Store</a>
        </div>
        
        <footer>
            <p>© 2024 Claude Code | <a href="https://claudecode.app">Website</a> | <a href="https://claudecode.app/privacy">Privacy</a></p>
        </footer>
    </div>
</body>
</html>
EOF
}

# Generate JSON release notes
generate_json_release_notes() {
    local version="$1"
    local build_number=$(date +%Y%m%d%H%M)
    
    cat <<EOF
{
  "version": "${version}",
  "build": "${build_number}",
  "releaseDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "highlights": [
    "Improved performance and stability",
    "New features and enhancements",
    "Bug fixes and optimizations"
  ],
  "changes": {
    "added": [
$(git log --pretty=format:'      "%s",' -10 --grep="feat:" | sed '$ s/,$//')
    ],
    "fixed": [
$(git log --pretty=format:'      "%s",' -10 --grep="fix:" | sed '$ s/,$//')
    ],
    "changed": [
$(git log --pretty=format:'      "%s",' -10 --grep="refactor:" | sed '$ s/,$//')
    ]
  },
  "requirements": {
    "minimumOS": "17.0",
    "devices": ["iPhone", "iPad"],
    "storage": "50MB"
  },
  "links": {
    "testflight": "https://testflight.apple.com/join/XXXXXX",
    "appstore": "https://apps.apple.com/app/claude-code/idXXXXXX",
    "documentation": "https://docs.claudecode.app",
    "support": "https://support.claudecode.app"
  }
}
EOF
}

# ============================================================================
# RELEASE MANAGEMENT
# ============================================================================

# Prepare release
prepare_release() {
    local version="${1:-}"
    local bump_type="${2:-patch}"
    
    log_header "Preparing Release"
    
    # Ensure clean git state
    if [[ -n "$(git status --porcelain)" ]]; then
        log_warning "Uncommitted changes detected"
        log_info "Stashing changes..."
        git stash push -m "Pre-release stash $(date +%Y%m%d_%H%M%S)"
    fi
    
    # Determine version
    if [[ -z "$version" ]]; then
        version=$(bump_version "$bump_type")
    else
        update_version_everywhere "$version"
    fi
    
    # Generate changelog
    generate_changelog_from_git "" "HEAD" "$version"
    
    # Generate release notes
    generate_release_notes "$version" "markdown"
    generate_release_notes "$version" "html"
    generate_release_notes "$version" "json"
    
    # Create release branch
    local release_branch="${RELEASE_BRANCH_PREFIX}${version}"
    log_step "Creating release branch: $release_branch"
    git checkout -b "$release_branch"
    
    # Commit changes
    log_step "Committing release changes..."
    git add .
    git commit -m "chore(release): prepare release v${version}

- Bump version to ${version}
- Update changelog
- Generate release notes"
    
    # Create tag
    local tag="${TAG_PREFIX}${version}"
    log_step "Creating tag: $tag"
    git tag -a "$tag" -m "Release v${version}

$(generate_markdown_release_notes "$version" | head -50)"
    
    log_success "Release v${version} prepared!"
    
    echo
    echo "Next steps:"
    echo "1. Review changes: git diff HEAD~1"
    echo "2. Push branch: git push -u origin $release_branch"
    echo "3. Push tag: git push origin $tag"
    echo "4. Create pull request to merge into $DEFAULT_BRANCH"
    echo "5. Deploy to TestFlight/App Store"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

show_usage() {
    cat <<EOF
Claude Code iOS - Version Management System

Usage: $(basename "$0") [command] [options]

Commands:
    bump [type] [pre]      Bump version (major|minor|patch|prerelease)
    changelog [from] [to]  Generate changelog from git commits
    notes [version] [fmt]  Generate release notes (markdown|html|json)
    prepare [ver] [type]   Prepare complete release
    current                Show current version
    compare v1 v2          Compare two versions
    help                   Show this help message

Examples:
    $(basename "$0") bump patch                    # Bump patch version
    $(basename "$0") bump minor                    # Bump minor version
    $(basename "$0") bump prerelease beta          # Create beta prerelease
    $(basename "$0") changelog v1.0.0 v1.1.0       # Generate changelog
    $(basename "$0") notes 1.2.0 markdown          # Generate release notes
    $(basename "$0") prepare                       # Prepare patch release
    $(basename "$0") prepare 2.0.0                 # Prepare specific version

Version Format:
    MAJOR.MINOR.PATCH[-PRERELEASE.NUMBER]
    Example: 1.2.3-beta.1

EOF
}

main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        bump)
            bump_version "$@"
            ;;
        changelog)
            generate_changelog_from_git "$@"
            ;;
        notes)
            generate_release_notes "$@"
            ;;
        prepare)
            prepare_release "$@"
            ;;
        current)
            echo "$(get_current_version)"
            ;;
        compare)
            if [[ $# -lt 2 ]]; then
                log_error "Two versions required"
                exit 1
            fi
            result=$(compare_versions "$1" "$2")
            case $result in
                1) echo "$1 > $2" ;;
                -1) echo "$1 < $2" ;;
                0) echo "$1 = $2" ;;
            esac
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
}

# Run main
main "$@"