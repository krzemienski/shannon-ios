import Foundation

/// API configuration for Claude Code backend
struct APIConfig {
    // MARK: - Base Configuration
    
    /// Host machine IP address for simulator connectivity
    /// This is the IP address of your Mac on the local network
    private static let hostMachineIP = "192.168.0.155"
    
    /// Determine the correct base URL based on the runtime environment
    private static var localhostURL: String {
        #if targetEnvironment(simulator)
        // iOS Simulator needs to use host machine IP, not localhost
        return "http://\(hostMachineIP):8000/v1"
        #else
        // On device, use actual IP or configured URL
        return "http://\(hostMachineIP):8000/v1"
        #endif
    }
    
    /// Base URL for the Claude Code API Gateway
    /// Automatically configures for simulator vs device
    public static let baseURL = URL(string: localhostURL)!
    
    /// Default base URL string for settings
    public static let defaultBaseURL = localhostURL
    
    /// Alternative localhost configurations
    public static let localhostVariants = [
        "http://localhost:8000/v1",          // Standard localhost
        "http://127.0.0.1:8000/v1",          // Loopback address
        "http://\(hostMachineIP):8000/v1",   // Host machine IP
        "http://0.0.0.0:8000/v1"             // All interfaces
    ]
    
    /// Alternative base URLs for different environments
    static let productionURL = URL(string: "https://api.claudecode.com/v1")!
    static let stagingURL = URL(string: "https://staging-api.claudecode.com/v1")!
    
    /// Check if URL is localhost variant
    public static func isLocalhost(_ url: String) -> Bool {
        return url.contains("localhost") || 
               url.contains("127.0.0.1") || 
               url.contains(hostMachineIP) ||
               url.contains("0.0.0.0")
    }
    
    /// Get the appropriate health check URL
    public static func healthCheckURL(for baseURL: String = defaultBaseURL) -> URL? {
        // Health endpoint is at root /health, not under /v1
        let urlString = baseURL
            .replacingOccurrences(of: "/v1", with: "")
            .appending("/health")
        return URL(string: urlString)
    }
    
    // MARK: - Endpoints
    
    enum Endpoint {
        // Chat endpoints
        case chatCompletions
        case chatStream
        
        // Model endpoints
        case models
        case modelDetails(String)
        
        // Session endpoints
        case sessions
        case sessionDetails(String)
        
        // Project endpoints
        case projects
        case projectDetails(String)
        
        // Tool endpoints
        case tools
        case toolExecution
        
        // SSH endpoints
        case sshSessions
        case sshCommand
        
        var path: String {
            switch self {
            case .chatCompletions:
                return "/chat/completions"
            case .chatStream:
                return "/chat/completions"  // Same endpoint, SSE enabled via headers
            case .models:
                return "/models"
            case .modelDetails(let modelId):
                return "/models/\(modelId)"
            case .sessions:
                return "/sessions"
            case .sessionDetails(let sessionId):
                return "/sessions/\(sessionId)"
            case .projects:
                return "/projects"
            case .projectDetails(let projectId):
                return "/projects/\(projectId)"
            case .tools:
                return "/tools"
            case .toolExecution:
                return "/tools/execute"
            case .sshSessions:
                return "/ssh/sessions"
            case .sshCommand:
                return "/ssh/execute"
            }
        }
        
        func url(baseURL: URL = APIConfig.baseURL) -> URL {
            baseURL.appendingPathComponent(path)
        }
    }
    
    // MARK: - Headers
    
    static func defaultHeaders(apiKey: String? = nil) -> [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "ClaudeCode-iOS/1.0",
            "X-Client-Platform": "iOS",
            "X-Client-Version": "1.0"
        ]
        
        // Add simulator identifier for debugging
        #if targetEnvironment(simulator)
        headers["X-Client-Environment"] = "simulator"
        headers["X-Client-Host-IP"] = hostMachineIP
        #endif
        
        if let apiKey = apiKey {
            headers["Authorization"] = "Bearer \(apiKey)"
        }
        
        return headers
    }
    
    static func sseHeaders(apiKey: String? = nil) -> [String: String] {
        var headers = defaultHeaders(apiKey: apiKey)
        headers["Accept"] = "text/event-stream"
        headers["Cache-Control"] = "no-cache"
        headers["Connection"] = "keep-alive"
        return headers
    }
    
    // MARK: - Network Configuration
    
    /// Network timeout configurations for different scenarios
    struct NetworkTimeouts {
        static let standard: TimeInterval = 30
        static let streaming: TimeInterval = 300  // 5 minutes
        static let upload: TimeInterval = 600     // 10 minutes
        static let healthCheck: TimeInterval = 5
    }
    
    /// Connection quality thresholds
    struct ConnectionQuality {
        static let excellentLatency: TimeInterval = 0.05  // 50ms
        static let goodLatency: TimeInterval = 0.1        // 100ms
        static let fairLatency: TimeInterval = 0.3        // 300ms
        static let poorLatency: TimeInterval = 1.0        // 1 second
    }
    
    // MARK: - Available Models
    
    /// Models available from the Claude Code API Gateway
    enum Model: String, CaseIterable {
        case claudeOpus4 = "claude-opus-4"
        case claudeSonnet4 = "claude-sonnet-4"
        case claude37Sonnet = "claude-3-7-sonnet"
        case claude35Haiku = "claude-3-5-haiku"
        
        var displayName: String {
            switch self {
            case .claudeOpus4:
                return "Claude Opus 4"
            case .claudeSonnet4:
                return "Claude Sonnet 4"
            case .claude37Sonnet:
                return "Claude 3.7 Sonnet"
            case .claude35Haiku:
                return "Claude 3.5 Haiku"
            }
        }
        
        var description: String {
            switch self {
            case .claudeOpus4:
                return "Most capable model for complex tasks"
            case .claudeSonnet4:
                return "Balanced performance and speed"
            case .claude37Sonnet:
                return "Previous generation balanced model"
            case .claude35Haiku:
                return "Fast and efficient for simple tasks"
            }
        }
    }
    
    // MARK: - Request Configuration
    
    struct RequestConfig {
        let timeout: TimeInterval
        let maxRetries: Int
        let retryDelay: TimeInterval
        
        static let `default` = RequestConfig(
            timeout: NetworkTimeouts.standard,
            maxRetries: 3,
            retryDelay: 1.0
        )
        
        static let streaming = RequestConfig(
            timeout: NetworkTimeouts.streaming,
            maxRetries: 1,
            retryDelay: 0
        )
        
        static let longRunning = RequestConfig(
            timeout: 120,
            maxRetries: 2,
            retryDelay: 2.0
        )
        
        static let healthCheck = RequestConfig(
            timeout: NetworkTimeouts.healthCheck,
            maxRetries: 1,
            retryDelay: 0
        )
    }
    
    // MARK: - Error Codes
    
    typealias APIError = ConfigError
    
    enum ConfigError: LocalizedError {
        case invalidURL
        case noData
        case decodingError(Error)
        case networkError(Error)
        case serverError(statusCode: Int, message: String?)
        case unauthorized
        case rateLimited(retryAfter: TimeInterval?)
        case backendNotRunning
        case connectionTimeout
        case noInternetConnection
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL configuration"
            case .noData:
                return "No data received from server"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .serverError(let statusCode, let message):
                return "Server error (\(statusCode)): \(message ?? "Unknown error")"
            case .unauthorized:
                return "Unauthorized - check API key"
            case .rateLimited(let retryAfter):
                if let retryAfter = retryAfter {
                    return "Rate limited - retry after \(Int(retryAfter)) seconds"
                }
                return "Rate limited - please try again later"
            case .backendNotRunning:
                return "Backend API is not running. Please ensure the backend is started at \(baseURL.absoluteString)"
            case .connectionTimeout:
                return "Connection timed out. Please check your network connection."
            case .noInternetConnection:
                return "No internet connection available"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .backendNotRunning:
                return "Start the backend with: cd claude-code-api && make start"
            case .connectionTimeout:
                return "Check if the backend is running and accessible at \(baseURL.absoluteString)"
            case .unauthorized:
                return "Verify your API key in Settings"
            default:
                return nil
            }
        }
    }
}