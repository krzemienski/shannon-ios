//
//  ViewModels.swift
//  ClaudeCode
//
//  Shared view models and types used across multiple views
//

import Foundation

// MARK: - Tool Models

public struct PanelToolInfo: Identifiable {
    public let id = UUID().uuidString
    public let name: String
    public let category: String
    public let icon: String
    public let description: String
    public let usage: String
    public let examples: [String]
    public let lastUsed: Date?
    
    public init(
        name: String,
        category: String,
        icon: String,
        description: String,
        usage: String,
        examples: [String],
        lastUsed: Date?
    ) {
        self.name = name
        self.category = category
        self.icon = icon
        self.description = description
        self.usage = usage
        self.examples = examples
        self.lastUsed = lastUsed
    }
}

// MARK: - Performance Models

public struct PerformanceBottleneck: Identifiable, Hashable {
    public let id = UUID().uuidString
    public let component: String
    public let severity: BottleneckSeverity
    public let impact: Double // 0.0 to 1.0
    public let description: String
    public let recommendation: String
    public let timestamp: Date
    
    public enum BottleneckSeverity: String, CaseIterable {
        case low, medium, high, critical
        
        public var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
    }
    
    public init(component: String, severity: BottleneckSeverity, impact: Double, description: String, recommendation: String, timestamp: Date = Date()) {
        self.component = component
        self.severity = severity
        self.impact = impact
        self.description = description
        self.recommendation = recommendation
        self.timestamp = timestamp
    }
}

public struct PerformanceMeasurement: Identifiable {
    public let id = UUID().uuidString
    public let name: String
    public let value: Double
    public let unit: String
    public let timestamp: Date
    public let category: String
    
    public init(name: String, value: Double, unit: String, category: String, timestamp: Date = Date()) {
        self.name = name
        self.value = value
        self.unit = unit
        self.category = category
        self.timestamp = timestamp
    }
}

public struct PerformanceSpan: Identifiable {
    public let id = UUID().uuidString
    public let name: String
    public let startTime: Date
    public let endTime: Date
    public let duration: TimeInterval
    public let parentSpanId: String?
    public let attributes: [String: Any]
    
    public init(name: String, startTime: Date, endTime: Date, parentSpanId: String? = nil, attributes: [String: Any] = [:]) {
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
        self.parentSpanId = parentSpanId
        self.attributes = attributes
    }
}

// MARK: - Monitor Models

public enum AlertMetricType: String {
    case cpu = "cpu"
    case memory = "memory"
    case network = "network"
    case disk = "disk"
    case error = "error"
    
    public var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .network: return "Network"
        case .disk: return "Disk"
        case .error: return "Error Rate"
        }
    }
}

public enum MonitorMetricType: String, CaseIterable {
    case cpuUsage = "CPU Usage"
    case memoryUsage = "Memory Usage"
    case diskUsage = "Disk Usage"
    case networkBandwidth = "Network Bandwidth"
    case responseTime = "Response Time"
    case errorRate = "Error Rate"
}