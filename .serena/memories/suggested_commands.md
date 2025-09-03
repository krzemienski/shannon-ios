# Suggested Commands for Shannon iOS Development

## CRITICAL: Always Use Simulator Automation Script
**NEVER use manual xcodebuild or xcrun commands directly!**
Always use the automation script: `./Scripts/simulator_automation.sh`

## Primary Build Commands (Use These!)
```bash
# Complete workflow (recommended - builds, installs, and launches)
./Scripts/simulator_automation.sh all

# Individual operations
./Scripts/simulator_automation.sh build    # Build the app
./Scripts/simulator_automation.sh launch   # Install and launch on simulator
./Scripts/simulator_automation.sh logs     # Capture simulator logs
./Scripts/simulator_automation.sh status   # Check simulator status
./Scripts/simulator_automation.sh clean    # Clean build artifacts
./Scripts/simulator_automation.sh help     # Show all available options
```

## Makefile Commands (Alternative)
```bash
make all         # Complete build and test workflow
make bootstrap   # Install dependencies and generate project
make generate    # Generate Xcode project with XcodeGen
make build       # Build for simulator
make test        # Run all tests with coverage
make clean       # Clean all build artifacts
make simulator   # Build and run on simulator
make lint        # Run SwiftLint
make format      # Format code with SwiftFormat
```

## Task Master Commands
```bash
task-master list                           # Show all tasks
task-master next                           # Get next available task
task-master show <id>                      # View task details
task-master set-status --id=<id> --status=done  # Mark task complete
task-master update-subtask --id=<id> --prompt="notes"  # Add implementation notes
```

## Git Commands
```bash
git status                                  # Check current status
git add -A                                  # Stage all changes
git commit -m "fix: description"            # Commit with conventional format
git push origin feature/branch-name         # Push to remote
```

## Project Generation & Dependencies
```bash
xcodegen generate                           # Generate Xcode project from Project.yml
swift package resolve                       # Resolve SPM dependencies
swift build                                # Build from command line
```

## Testing Commands
```bash
swift test                                  # Run unit tests
xcodebuild test -scheme ClaudeCode -destination "id=50523130-57AA-48B0-ABD0-4D59CE455F14"
```

## Debugging & Logs
```bash
xcrun simctl spawn 50523130-57AA-48B0-ABD0-4D59CE455F14 log stream --level=debug
tail -f logs/simulator_*.log               # Follow latest simulator log
```

## Environment Variables
```bash
export SIMULATOR_UUID="50523130-57AA-48B0-ABD0-4D59CE455F14"
export APP_BUNDLE_ID="com.claudecode.ios"
export PKG_CONFIG_PATH="/opt/homebrew/opt/libssh2/lib/pkgconfig"
```