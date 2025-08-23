//
//  AppError.swift
//  ClaudeCode
//
//  Application-level error types
//

import Foundation

/// Application-level errors
public enum AppError: LocalizedError {
    case initialization(String)
    case configuration(String)
    case network(Error)
    case api(APIError)
    case storage(Error)
    case ssh(Error)
    case monitoring(String)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .initialization(let message):
            return "Initialization Error: \(message)"
        case .configuration(let message):
            return "Configuration Error: \(message)"
        case .network(let error):
            return "Network Error: \(error.localizedDescription)"
        case .api(let apiError):
            return "API Error: \(apiError.localizedDescription)"
        case .storage(let error):
            return "Storage Error: \(error.localizedDescription)"
        case .ssh(let error):
            return "SSH Error: \(error.localizedDescription)"
        case .monitoring(let message):
            return "Monitoring Error: \(message)"
        case .unknown(let error):
            return "Unknown Error: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .initialization:
            return "Try restarting the application"
        case .configuration:
            return "Check your settings and try again"
        case .network:
            return "Check your internet connection and try again"
        case .api:
            return "Verify your API key and endpoint settings"
        case .storage:
            return "Check available storage space and permissions"
        case .ssh:
            return "Verify SSH connection settings and credentials"
        case .monitoring:
            return "Check monitoring service configuration"
        case .unknown:
            return "Please try again or contact support"
        }
    }
}

// APIError is now defined in APIModels.swift