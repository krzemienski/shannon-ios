#!/bin/bash

# Minimal build script to get the app compiling
# This temporarily excludes problematic files to get a working build

echo "=== Minimal Build Configuration ==="
echo "This will create a minimal working build by excluding problematic files"
echo

# Backup current Project.yml
cp Project.yml Project.yml.backup

# Create minimal Project.yml
cat > Project.yml.minimal << 'EOF'
name: ClaudeCode
options:
  bundleIdPrefix: com.claudecode
  deploymentTarget:
    iOS: 17.0
  createIntermediateGroups: true
  groupSortPosition: top
  
settings:
  base:
    DEVELOPMENT_TEAM: ""
    SWIFT_VERSION: 5.9
    IPHONEOS_DEPLOYMENT_TARGET: 17.0
    SWIFT_EMIT_LOC_STRINGS: NO
    
packages:
  KeychainAccess:
    url: https://github.com/kishikawakatsumi/KeychainAccess
    from: 4.2.2
  Logging:
    url: https://github.com/apple/swift-log
    from: 1.0.0

targets:
  ClaudeCode:
    type: application
    platform: iOS
    sources:
      - path: Sources
        excludes:
          # Exclude SSH-related files
          - "**/SSH/**"
          - "**/SSHManager.swift"
          - "**/SSHMonitor*.swift"
          - "**/SSHGlobalConfigView.swift"
          - "**/TerminalEmulatorView.swift"
          # Exclude duplicate model files
          - "Models/APIModels.swift"
          - "Models/AppError.swift"
          - "Views/Monitor/AlertConfigurationView.swift"
          - "Views/Monitor/MonitorView.swift"
          - "ViewModels/MonitorViewModel.swift"
          - "ViewModels/ProjectsViewModel.swift"
          - "Core/State/AppState.swift"
          - "Core/Coordinators/MonitorCoordinator.swift"
          - "Views/Tools/ToolsView.swift"
          - "Services/NetworkMonitor.swift"
          - "Architecture/ModuleRegistration/AppModules.swift"
          # Exclude problematic animation files
          - "Views/Animations/AnimationUtilities.swift"
          - "UI/DesignSystem/Animations.swift"
    settings:
      base:
        INFOPLIST_FILE: Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.claudecode.ios
        PRODUCT_NAME: ClaudeCode
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        SWIFT_EMIT_LOC_STRINGS: NO
        CODE_SIGN_ENTITLEMENTS: ClaudeCode.entitlements
    dependencies:
      - package: KeychainAccess
      - package: Logging
    preBuildScripts:
      - name: SwiftLint
        script: |
          if which swiftlint > /dev/null; then
            swiftlint --config .swiftlint.yml
          else
            echo "warning: SwiftLint not installed"
          fi
        basedOnDependencyAnalysis: false
    postBuildScripts:
      - name: Build Info
        script: |
          echo "Build completed: $(date)"
        basedOnDependencyAnalysis: false

  ClaudeCodeUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - Tests/UITests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.claudecode.ios.uitests
        SWIFT_EMIT_LOC_STRINGS: NO
    dependencies:
      - target: ClaudeCode
EOF

echo "Using minimal configuration..."
mv Project.yml Project.yml.full
cp Project.yml.minimal Project.yml

# Generate Xcode project
echo "Generating Xcode project..."
xcodegen generate

echo "Building with minimal configuration..."
xcodebuild -scheme ClaudeCode \
    -destination "platform=iOS Simulator,id=A707456B-44DB-472F-9722-C88153CDFFA1" \
    clean build \
    2>&1 | xcbeautify

# Check build result
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ Minimal build succeeded!"
    echo "Note: Many features are disabled in this build"
else
    echo "❌ Build still failing. More exclusions needed."
fi