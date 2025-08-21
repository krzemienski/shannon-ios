#!/bin/bash

# ClaudeCode iOS - Project Bootstrap Script
# This script sets up the development environment

set -e

echo "🚀 ClaudeCode iOS - Project Bootstrap"
echo "======================================"

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew is not installed. Please install it first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Install XcodeGen if not present
if ! command -v xcodegen &> /dev/null; then
    echo "📦 Installing XcodeGen..."
    brew install xcodegen
else
    echo "✅ XcodeGen is already installed"
fi

# Install SwiftLint if not present
if ! command -v swiftlint &> /dev/null; then
    echo "📦 Installing SwiftLint..."
    brew install swiftlint
else
    echo "✅ SwiftLint is already installed"
fi

# Install xcbeautify if not present
if ! command -v xcbeautify &> /dev/null; then
    echo "📦 Installing xcbeautify..."
    brew install xcbeautify
else
    echo "✅ xcbeautify is already installed"
fi

# Install libssh2 for Citadel/SSH support
if ! brew list libssh2 &> /dev/null; then
    echo "📦 Installing libssh2 for SSH support..."
    brew install libssh2
else
    echo "✅ libssh2 is already installed"
fi

# Check for Xcode
if ! xcode-select -p &> /dev/null; then
    echo "❌ Xcode is not installed or command line tools are not configured"
    echo "   Please install Xcode from the App Store and run: xcode-select --install"
    exit 1
else
    echo "✅ Xcode is installed at: $(xcode-select -p)"
fi

# Generate Xcode project
echo "🔨 Generating Xcode project..."
xcodegen generate

# Create .gitignore if it doesn't exist
if [ ! -f .gitignore ]; then
    echo "📝 Creating .gitignore..."
    cat > .gitignore << 'EOF'
# Xcode
*.xcodeproj
*.xcworkspace
!default.xcworkspace
xcuserdata/
DerivedData/
*.xcscmblueprint
*.xccheckout

# Swift Package Manager
.build/
.swiftpm/
Package.resolved

# CocoaPods
Pods/
*.xcworkspace

# Carthage
Carthage/Build/
Carthage/Checkouts

# macOS
.DS_Store
*.swp
*~.nib

# AppCode
.idea/

# Fastlane
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots/**/*.png
fastlane/test_output

# Code Injection
iOSInjectionProject/

# Environment
.env
.env.local
EOF
fi

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "Next steps:"
echo "1. Open ClaudeCode.xcodeproj in Xcode"
echo "2. Select the ClaudeCode scheme"
echo "3. Build and run (⌘R)"
echo ""