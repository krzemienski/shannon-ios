//
//  TelemetryManager+Convenience.swift
//  ClaudeCode
//
//  Convenience methods for telemetry logging
//

import Foundation

extension TelemetryManager {
    /// Convenience method for logging custom events with string parameters
    public func logEvent(
        _ name: String,
        category: TelemetryEventCategory = .general,
        level: TelemetryLevel = .info,
        properties: [String: String] = [:],
        measurements: [String: Double] = [:]
    ) {
        let metadata = properties.reduce(into: [String: String]()) { result, item in
            result[item.key] = item.value
        }
        
        let event = CustomEvent(
            name: name,
            category: category.rawValue,
            metadata: metadata
        )
        
        logEvent(event)
    }
}

/// Telemetry event categories
public enum TelemetryEventCategory: String {
    case general = "general"
    case ssh = "ssh"
    case performance = "performance"
    case error = "error"
    case userAction = "user_action"
    case appLifecycle = "app_lifecycle"
}

/// Telemetry levels
public enum TelemetryLevel: String {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}