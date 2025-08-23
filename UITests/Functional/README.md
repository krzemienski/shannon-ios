# Functional UI Tests with Real Backend

This directory contains comprehensive functional UI tests for Claude Code iOS that connect to a **real backend server** running locally. These tests verify end-to-end functionality including data persistence, network communication, and real-time features.

## ⚠️ Important: Real Backend Required

**These tests DO NOT use mocks or fake data.** They require a live backend server to be running locally and will make real API calls, create real data, and test actual persistence.

## Quick Start

### 1. Start the Backend Server

```bash
# Navigate to the backend directory
cd claude-code-api

# Start the FastAPI server
python -m claude_code_api.main

# Or if you have it set up with uvicorn:
uvicorn claude_code_api.main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. Run the Tests

Using the simulator automation script (recommended):

```bash
# Run all functional tests
./Scripts/simulator_automation.sh test --functional

# Run specific test class
./Scripts/simulator_automation.sh test --class ProjectFlowTests
```

Or manually with xcodebuild:

```bash
# Set environment variables
export BACKEND_URL="http://localhost:8000"
export NETWORK_TIMEOUT="30"
export UI_WAIT_TIMEOUT="15"

# Run tests
xcodebuild test \
  -scheme ClaudeCode \
  -destination "platform=iOS Simulator,id=A707456B-44DB-472F-9722-C88153CDFFA1" \
  -testPlan FunctionalTests
```

## Test Coverage

### 1. Project Flow Tests (`ProjectFlowTests.swift`)
- **Project List Loading**: Verify projects load from real backend
- **Project Selection**: Select existing projects and load details
- **Project Creation**: Create new projects that persist to backend
- **Project Management**: Delete, search, and filter projects
- **Data Persistence**: Verify projects persist across app sessions

### 2. Session Flow Tests (`SessionFlowTests.swift`)
- **Session List**: View existing sessions from backend within projects
- **Session Selection**: Load session history from backend
- **Session Creation**: Create new sessions that persist
- **Session Switching**: Navigate between multiple sessions
- **Cross-Session Persistence**: Verify sessions persist across app restarts

### 3. Messaging Flow Tests (`MessagingFlowTests.swift`)
- **Real Message Sending**: Send messages and receive actual backend responses
- **Message Persistence**: Verify messages persist across navigation and restarts
- **Streaming Responses**: Test real-time streaming message updates
- **Multiple Messages**: Send sequences of messages with backend responses
- **Error Handling**: Test network errors and connection issues
- **Message History**: Scroll through and load historical messages

### 4. Monitoring Flow Tests (`MonitoringFlowTests.swift`)
- **Performance Metrics**: View real performance data from backend
- **Error Logs**: Access and filter actual error logs
- **Telemetry Data**: View and export real telemetry information
- **Real-time Updates**: Monitor live metric updates during activity
- **Configuration**: Modify monitoring settings with backend persistence

### 5. MCP Configuration Tests (`MCPConfigurationTests.swift`)
- **MCP Server List**: View configured MCP servers from backend
- **Server Configuration**: Add, modify, and delete MCP server settings
- **Connection Testing**: Test actual connections to MCP servers
- **Settings Persistence**: Verify MCP settings persist to backend
- **Server Status**: Monitor MCP server connection status

## Environment Configuration

### Required Environment Variables

```bash
# Backend Configuration
BACKEND_URL="http://localhost:8000"              # Backend server URL
NETWORK_TIMEOUT="30"                             # API request timeout (seconds)
UI_WAIT_TIMEOUT="15"                             # UI element wait timeout (seconds)

# Optional Configuration
AUTH_TOKEN=""                                    # Authentication token if required
VERBOSE_LOGGING="true"                          # Enable detailed logging
CLEANUP_AFTER_TESTS="true"                     # Clean up test data (default: true)
TEST_DATA_PREFIX="UITest_"                      # Prefix for test data identification
```

### Backend Requirements

The backend server must be running and provide these endpoints:

- `GET /v1/projects` - List projects
- `POST /v1/projects` - Create project
- `GET /v1/projects/{id}` - Get project details
- `DELETE /v1/projects/{id}` - Delete project
- `GET /v1/sessions` - List sessions
- `POST /v1/sessions` - Create session
- `GET /v1/sessions/{id}` - Get session details
- `DELETE /v1/sessions/{id}` - Delete session
- `POST /v1/chat/{session_id}` - Send chat message
- `GET /v1/health` - Health check endpoint

## Test Data Management

### Automatic Cleanup

Tests automatically clean up their data after completion by:

1. Tracking all created projects and sessions
2. Deleting them in tearDown methods
3. Using test data prefixes for identification
4. Running backend cleanup procedures

### Manual Cleanup

If tests are interrupted, you can manually clean up:

```bash
# Clean up test data via API
curl -X DELETE "http://localhost:8000/v1/projects" \
  -H "Content-Type: application/json" \
  -d '{"prefix": "UITest_"}'

# Or restart the backend to reset the database
```

### Test Data Isolation

- All test data uses the `UITest_` prefix by default
- Tests create unique identifiers with timestamps
- No production data is modified during testing
- Each test class manages its own data lifecycle

## Debugging and Troubleshooting

### Enable Verbose Logging

```bash
export VERBOSE_LOGGING="true"
```

This will output:
- API request/response details
- Backend connection status
- Test data creation/cleanup
- Network timing information

### Common Issues

**Backend Not Available**
```
Error: Backend must be available for functional tests
```
- Ensure backend server is running on http://localhost:8000
- Check firewall settings
- Verify backend health endpoint responds

**Test Timeouts**
```
Error: Element did not appear within timeout
```
- Increase UI_WAIT_TIMEOUT environment variable
- Check network connectivity
- Verify backend is responding quickly

**Data Persistence Failures**
```
Error: Data should persist to backend
```
- Check backend database is working
- Verify API endpoints are implemented correctly
- Check authentication if required

### Screenshots and Logs

Tests automatically capture:
- Screenshots at key test points (saved to test results)
- Simulator logs (saved to `logs/` directory)
- API request/response logs (when verbose logging enabled)

## Integration with Development Workflow

### CI/CD Integration

Add to your CI pipeline:

```yaml
- name: Start Backend
  run: |
    cd claude-code-api
    python -m claude_code_api.main &
    sleep 10  # Wait for backend to start

- name: Run Functional Tests
  run: |
    export BACKEND_URL="http://localhost:8000"
    ./Scripts/simulator_automation.sh test --functional
```

### Pre-commit Testing

Run before committing changes:

```bash
# Quick functional test
./Scripts/simulator_automation.sh test --class MessagingFlowTests

# Full functional test suite
./Scripts/simulator_automation.sh test --functional
```

### Performance Testing

Monitor test execution time:

```bash
# Run with timing
time ./Scripts/simulator_automation.sh test --functional

# Expected times (approximate):
# ProjectFlowTests: 2-3 minutes
# SessionFlowTests: 3-4 minutes  
# MessagingFlowTests: 4-5 minutes (includes real AI responses)
# MonitoringFlowTests: 2-3 minutes
# MCPConfigurationTests: 2-3 minutes
```

## Architecture Notes

### Test Design Principles

1. **Real Backend Dependency**: No mocking - tests verify actual system behavior
2. **Data Persistence**: All tests verify data survives app restarts and navigation
3. **Network Resilience**: Tests handle real network delays and timeouts
4. **Cleanup Responsibility**: Each test cleans up its own data
5. **Screenshot Documentation**: Visual evidence of test execution and failures

### Backend Integration

Tests use the `BackendAPIHelper` class to:
- Make authenticated API requests
- Verify data persistence outside the UI
- Set up test scenarios
- Clean up test data
- Validate backend state

### Error Handling

Tests handle real-world scenarios:
- Network timeouts and connectivity issues
- Backend errors and HTTP status codes
- Authentication failures
- Rate limiting and throttling
- Data validation errors

## Contributing

When adding new functional tests:

1. **Extend existing test classes** for related functionality
2. **Create new test classes** for new feature areas
3. **Use RealBackendConfig** for all backend communication
4. **Follow naming conventions** (TestData classes, test method names)
5. **Add cleanup logic** in tearDown methods
6. **Include screenshots** at key verification points
7. **Test data persistence** across app lifecycle events
8. **Document environment variables** if new configuration is needed

### Test Method Naming

```swift
func testFeatureDoesActionWithRealBackend() throws
func testFeaturePersistsToBackend() throws 
func testFeatureHandlesNetworkError() throws
```

### Required Test Components

Every functional test should:
- ✅ Connect to real backend
- ✅ Verify data persistence
- ✅ Clean up test data
- ✅ Handle network timeouts
- ✅ Take verification screenshots
- ✅ Use unique test identifiers

---

**Remember**: These are functional tests that require a live backend. They test the complete system integration, not individual components in isolation.