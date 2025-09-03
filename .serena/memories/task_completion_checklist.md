# Task Completion Checklist for Shannon iOS

## Before Marking a Task Complete

### 1. Code Quality Checks
- [ ] Run SwiftLint: `swiftlint` (or `make lint`)
- [ ] Fix any SwiftLint warnings/errors
- [ ] Format code if needed: `make format`
- [ ] Ensure proper access modifiers are used
- [ ] Remove any debug print statements
- [ ] Remove commented-out code

### 2. Build Verification
- [ ] Clean build folder: `./Scripts/simulator_automation.sh clean`
- [ ] Build successfully: `./Scripts/simulator_automation.sh build`
- [ ] No compilation errors or warnings
- [ ] App launches on simulator: `./Scripts/simulator_automation.sh launch`

### 3. Testing
- [ ] Write/update unit tests for new code
- [ ] Run tests: `make test` or `swift test`
- [ ] Ensure all tests pass
- [ ] Test edge cases and error scenarios
- [ ] Manual testing on simulator for UI changes

### 4. Documentation
- [ ] Update code comments for complex logic
- [ ] Add/update documentation for public APIs
- [ ] Update README.md if adding new features
- [ ] Document any new dependencies or setup steps

### 5. Task Master Updates
- [ ] Update subtask with implementation notes:
  ```bash
  task-master update-subtask --id=<id> --prompt="implementation details"
  ```
- [ ] Mark task as complete:
  ```bash
  task-master set-status --id=<id> --status=done
  ```

### 6. Git Operations
- [ ] Stage changes: `git add -A`
- [ ] Review changes: `git diff --staged`
- [ ] Commit with descriptive message:
  ```bash
  git commit -m "feat: implement feature (task X.Y)"
  ```
- [ ] Push to feature branch (not main/master)

### 7. Final Verification
- [ ] App still builds and runs after all changes
- [ ] No regression in existing functionality
- [ ] Performance is acceptable (no obvious lag/issues)
- [ ] Memory usage is reasonable (check for leaks)

## Quick Validation Command Sequence
```bash
# 1. Clean and build
./Scripts/simulator_automation.sh clean
./Scripts/simulator_automation.sh build

# 2. Run quality checks
swiftlint
make test

# 3. Launch and verify
./Scripts/simulator_automation.sh launch

# 4. If all good, commit
git add -A
git commit -m "fix: description (task X.Y)"

# 5. Update task status
task-master set-status --id=X.Y --status=done
```

## Common Issues to Check
- Missing `import` statements
- Unresolved type references
- Protocol conformance issues
- Access level conflicts
- Sendable conformance for concurrent code
- Missing required initializers
- Retain cycles in closures (use `[weak self]`)

## Platform-Specific Notes
- System: Darwin (macOS)
- Target iOS: 17.0+
- Swift: 5.9+
- Always test on the configured simulator (iPhone 16 Pro Max)