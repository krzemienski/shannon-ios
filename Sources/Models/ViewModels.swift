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