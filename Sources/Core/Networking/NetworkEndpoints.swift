//
//  NetworkEndpoints.swift
//  ClaudeCode
//
//  Centralized network endpoint configuration for Shannon iOS app
//

import Foundation

/// Centralized network endpoints configuration
public struct NetworkEndpoints {
    // MARK: - Host Configuration
    
    /// Backend host IP address for local development
    /// This is the IP address of your Mac running the backend server
    public static let hostIP = "192.168.0.155"
    
    /// Backend port
    public static let port = 8000
    
    // MARK: - Base URLs
    
    /// HTTP base URL for API endpoints
    public static var apiBaseURL: String {
        "http://\(hostIP):\(port)/v1"
    }
    
    /// WebSocket URL for real-time updates
    public static var websocketURL: String {
        "ws://\(hostIP):\(port)/ws"
    }
    
    /// Health check endpoint
    public static var healthURL: String {
        "http://\(hostIP):\(port)/health"
    }
    
    /// Products endpoint (for testing)
    public static var productsURL: String {
        "http://\(hostIP):\(port)/v1/products"
    }
    
    // MARK: - Endpoint Paths
    
    public struct Paths {
        // Chat endpoints
        public static let chatCompletions = "/chat/completions"
        public static let chatStream = "/chat/completions"  // SSE via headers
        
        // Model endpoints
        public static let models = "/models"
        
        // Session endpoints
        public static let sessions = "/sessions"
        
        // Project endpoints
        public static let projects = "/projects"
        
        // Tool endpoints
        public static let tools = "/tools"
        public static let toolExecution = "/tools/execute"
        
        // SSH endpoints
        public static let sshSessions = "/ssh/sessions"
        public static let sshCommand = "/ssh/execute"
    }
    
    // MARK: - Helper Methods
    
    /// Check if a URL is pointing to our backend
    public static func isBackendURL(_ url: String) -> Bool {
        return url.contains(hostIP) || 
               url.contains("localhost") || 
               url.contains("127.0.0.1") ||
               url.contains("0.0.0.0")
    }
    
    /// Get the full URL for a given path
    public static func fullURL(for path: String) -> URL? {
        URL(string: apiBaseURL + path)
    }
    
    /// Convert HTTP URL to WebSocket URL
    public static func toWebSocketURL(_ httpURL: String) -> String {
        httpURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "/v1", with: "/ws")
    }
    
    // MARK: - Environment-Specific Configuration
    
    /// Get the appropriate base URL for the current environment
    public static func baseURL(for environment: Environment = .development) -> String {
        switch environment {
        case .development:
            return apiBaseURL
        case .staging:
            return "https://staging-api.claudecode.com/v1"
        case .production:
            return "https://api.claudecode.com/v1"
        }
    }
    
    public enum Environment {
        case development
        case staging
        case production
    }
}