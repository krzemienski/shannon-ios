# Shannon iOS Network Configuration

## Backend Connection Details
- **Host IP**: 192.168.0.155
- **Port**: 8000
- **Base URL**: http://192.168.0.155:8000/v1
- **WebSocket URL**: ws://192.168.0.155:8000/ws
- **Health Check**: http://192.168.0.155:8000/health
- **Products**: http://192.168.0.155:8000/v1/products

## Configuration Files Updated

### 1. APIConfig.swift
- Location: `/Sources/Services/APIConfig.swift`
- Status: ✅ Already configured with correct IP (192.168.0.155)
- Key setting: `private static let hostMachineIP = "192.168.0.155"`

### 2. APIClient.swift
- Location: `/Sources/Services/APIClient.swift`
- Status: ✅ Fixed hardcoded localhost in health check
- Now uses: `APIConfig.healthCheckURL(for: APIConfig.defaultBaseURL)`

### 3. WebSocketService.swift
- Location: `/Sources/Core/Networking/WebSocket/WebSocketService.swift`
- Status: ✅ Updated from localhost to 192.168.0.155
- WebSocket URL: `ws://192.168.0.155:8000/ws`

### 4. NetworkMonitor.swift
- Location: `/Sources/Services/NetworkMonitor.swift`
- Status: ✅ Fixed hardcoded localhost
- Health check URL: `http://192.168.0.155:8000/health`

### 5. UI Components Updated
- **EnhancedOnboardingView.swift**: ✅ Default URL updated to 192.168.0.155
- **AppState.swift**: ✅ Default baseURL updated to 192.168.0.155
- **APIConfigurationView.swift**: ✅ Default URL updated to 192.168.0.155

### 6. Info.plist
- Location: `/Info.plist`
- Status: ✅ Already has NSAppTransportSecurity exception for 192.168.0.155
- Allows insecure HTTP loads for local development

### 7. New Centralized Configuration
- Created: `/Sources/Core/Networking/NetworkEndpoints.swift`
- Purpose: Centralized network endpoint configuration
- Features:
  - Single source of truth for host IP
  - Helper methods for URL construction
  - Environment-specific configuration support

## Testing Endpoints

To verify the configuration works:

1. **Health Check**: 
   ```bash
   curl http://192.168.0.155:8000/health
   ```

2. **Models List**:
   ```bash
   curl http://192.168.0.155:8000/v1/models
   ```

3. **WebSocket Connection**:
   ```bash
   wscat -c ws://192.168.0.155:8000/ws
   ```

## Usage in Code

```swift
// Use APIConfig for API calls
let baseURL = APIConfig.baseURL  // http://192.168.0.155:8000/v1

// Use NetworkEndpoints for centralized configuration
let apiURL = NetworkEndpoints.apiBaseURL
let wsURL = NetworkEndpoints.websocketURL
let healthURL = NetworkEndpoints.healthURL

// Check health
let healthy = await APIClient.shared.checkHealth()
```

## Notes for Other Agents

1. **Do NOT use localhost or 127.0.0.1** - iOS Simulator cannot reach localhost on host machine
2. **Always use 192.168.0.155** - This is the host machine's IP on the local network
3. **HTTP is allowed** - Info.plist has NSAppTransportSecurity exceptions
4. **WebSocket uses ws://** - Not wss:// for local development
5. **Port 8000** - Backend is running on port 8000

## Validation Status

✅ All network configuration files updated
✅ Hardcoded localhost references removed
✅ Info.plist configured for local HTTP
✅ WebSocket endpoints configured
✅ Centralized configuration created
✅ UI default values updated

The Shannon iOS app is now properly configured to connect to the backend at 192.168.0.155:8000.