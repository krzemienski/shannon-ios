import Foundation

/// API configuration for Claude Code backend
enum APIConfig {
    // MARK: - Base Configuration
    
    /// Base URL for the Claude Code API Gateway
    /// Should be running at localhost:8000 in development
    static let baseURL = URL(string: "http://localhost:8000/v1")!
    
    /// Default base URL string for settings
    static let defaultBaseURL = "http://localhost:8000/v1"
    
    /// Alternative base URLs for different environments
    static let productionURL = URL(string: "https://api.claudecode.com/v1")!
    static let stagingURL = URL(string: "https://staging-api.claudecode.com/v1")!
    
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
            "User-Agent": "ClaudeCode-iOS/1.0"
        ]
        
        if let apiKey = apiKey {
            headers["Authorization"] = "Bearer \(apiKey)"
        }
        
        return headers
    }
    
    static func sseHeaders(apiKey: String? = nil) -> [String: String] {
        var headers = defaultHeaders(apiKey: apiKey)
        headers["Accept"] = "text/event-stream"
        headers["Cache-Control"] = "no-cache"
        return headers
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
            timeout: 30,
            maxRetries: 3,
            retryDelay: 1.0
        )
        
        static let streaming = RequestConfig(
            timeout: 300,  // 5 minutes for streaming
            maxRetries: 1,
            retryDelay: 0
        )
        
        static let longRunning = RequestConfig(
            timeout: 120,
            maxRetries: 2,
            retryDelay: 2.0
        )
    }
    
    // MARK: - Error Codes
    
    enum APIError: LocalizedError {
        case invalidURL
        case noData
        case decodingError(Error)
        case networkError(Error)
        case serverError(statusCode: Int, message: String?)
        case unauthorized
        case rateLimited(retryAfter: TimeInterval?)
        case backendNotRunning
        
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
                return "Backend API is not running at \(baseURL.absoluteString)"
            }
        }
    }
}