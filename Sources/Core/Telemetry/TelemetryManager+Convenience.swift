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
        // Convert string properties to AnyCodable
        let data = properties.reduce(into: [String: AnyCodable]()) { result, item in
            result[item.key] = AnyCodable(item.value)
        }
        
        // Add measurements to data
        let fullData = measurements.reduce(into: data) { result, item in
            result[item.key] = AnyCodable(item.value)
        }
        
        let event = CustomEvent(
            sessionId: self.sessionId,
            name: name,
            category: category.rawValue,
            data: fullData
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