//
//  SSHMonitor.swift
//  ClaudeCode
//
//  SSH monitoring and metrics collection service
//

import Foundation
import SwiftUI
import Combine

/// SSH monitoring service for tracking connections and operations
@MainActor
public final class SSHMonitor: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var activeOperations: [String: SSHOperationMetrics] = [:]
    @Published public var connectionStats: [String: SSHConnectionStats] = [:]
    @Published public var alerts: [SSHAlert] = []
    @Published public var globalStats: SSHGlobalStats
    @Published public var performanceMetrics: SSHPerformanceMetrics
    @Published public var recentOperations: [SSHOperation] = []
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let maxRecentOperations = 100
    private let maxAlerts = 50
    
    // MARK: - Initialization
    
    public init() {
        self.globalStats = SSHGlobalStats()
        self.performanceMetrics = SSHPerformanceMetrics()
        
        // Start monitoring
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Record a new SSH operation
    public func recordOperation(_ operation: SSHOperation) {
        // Add to recent operations
        recentOperations.insert(operation, at: 0)
        if recentOperations.count > maxRecentOperations {
            recentOperations.removeLast()
        }
        
        // Update global stats
        globalStats.totalCommands += 1
        if operation.success {
            globalStats.successCount += 1
        }
        globalStats.successRate = Double(globalStats.successCount) / Double(globalStats.totalCommands)
        
        // Update performance metrics
        updatePerformanceMetrics(for: operation)
        
        // Update connection stats for the host
        updateConnectionStats(for: operation)
    }
    
    /// Start tracking an active operation
    public func startOperation(id: String, host: String, command: String) -> SSHOperationMetrics {
        let operation = SSHOperationMetrics(
            id: id,
            host: host,
            command: command,
            startTime: Date(),
            status: .running,
            progress: 0.0
        )
        activeOperations[id] = operation
        return operation
    }
    
    /// Update an active operation's progress
    public func updateOperation(id: String, progress: Double, bytesTransferred: Int64 = 0) {
        if var operation = activeOperations[id] {
            operation.progress = progress
            operation.bytesTransferred += bytesTransferred
            activeOperations[id] = operation
            
            // Update global bytes transferred
            globalStats.totalBytesTransferred += bytesTransferred
        }
    }
    
    /// Complete an active operation
    public func completeOperation(id: String, success: Bool, output: String? = nil, error: String? = nil) {
        guard let operation = activeOperations[id] else { return }
        
        let duration = Date().timeIntervalSince(operation.startTime)
        
        // Create completed operation record
        let completedOp = SSHOperation(
            id: id,
            host: operation.host,
            command: operation.command,
            timestamp: operation.startTime,
            duration: duration,
            success: success,
            output: output,
            error: error,
            bytesTransferred: operation.bytesTransferred
        )
        
        // Record the operation
        recordOperation(completedOp)
        
        // Remove from active operations
        activeOperations.removeValue(forKey: id)
    }
    
    /// Add a new alert
    public func addAlert(_ alert: SSHAlert) {
        alerts.insert(alert, at: 0)
        if alerts.count > maxAlerts {
            alerts.removeLast()
        }
    }
    
    /// Clear all alerts
    public func clearAlerts() {
        alerts.removeAll()
    }
    
    /// Update connection count
    public func updateConnectionCount(active: Int, total: Int) {
        globalStats.activeConnections = active
        globalStats.totalConnections = total
    }
    
    // MARK: - Private Methods
    
    private func startMonitoring() {
        // Simulate periodic updates for demo purposes
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMetrics()
            }
            .store(in: &cancellables)
    }
    
    private func updateMetrics() {
        // Calculate current load based on active operations
        let operationCount = Double(activeOperations.count)
        performanceMetrics.currentLoad = min(operationCount / 10.0, 1.0)
        
        // Calculate throughput (operations per minute)
        let recentOps = recentOperations.filter { 
            Date().timeIntervalSince($0.timestamp) < 60
        }
        performanceMetrics.throughput = Double(recentOps.count)
    }
    
    private func updatePerformanceMetrics(for operation: SSHOperation) {
        // Update command frequency
        let command = operation.command.components(separatedBy: " ").first ?? operation.command
        performanceMetrics.commandFrequency[command, default: 0] += 1
        
        // Track slow commands
        if operation.duration > 2.0 {
            let slowCommand = SlowCommand(
                command: operation.command,
                duration: operation.duration,
                timestamp: operation.timestamp
            )
            performanceMetrics.slowestCommands.insert(slowCommand, at: 0)
            
            // Keep only top 10 slowest
            if performanceMetrics.slowestCommands.count > 10 {
                performanceMetrics.slowestCommands.removeLast()
            }
        }
        
        // Update average latency (rolling average of last 100 operations)
        let recentDurations = recentOperations.prefix(100).map { $0.duration }
        if !recentDurations.isEmpty {
            performanceMetrics.averageLatency = recentDurations.reduce(0, +) / Double(recentDurations.count)
        }
        
        // Update error rate
        let recentErrors = recentOperations.prefix(100).filter { !$0.success }.count
        performanceMetrics.errorRate = Double(recentErrors) / Double(min(recentOperations.count, 100))
    }
    
    private func updateConnectionStats(for operation: SSHOperation) {
        let hostKey = operation.host
        
        var stats = connectionStats[hostKey] ?? SSHConnectionStats(
            host: hostKey,
            firstConnected: Date(),
            lastConnected: Date(),
            lastConnectionTime: Date(),
            totalConnections: 0,
            totalCommands: 0,
            totalBytesTransferred: 0,
            averageLatency: 0,
            successRate: 0,
            successCount: 0,
            failedCommands: 0,
            averageConnectionTime: 0,
            isActive: false
        )
        
        // Update stats
        stats.lastConnected = Date()
        stats.lastConnectionTime = Date()
        stats.totalCommands += 1
        stats.totalBytesTransferred += operation.bytesTransferred
        
        // Update success rate and failed count
        if operation.success {
            stats.successCount += 1
        } else {
            stats.failedCommands += 1
        }
        stats.successRate = Double(stats.successCount) / Double(stats.totalCommands)
        
        // Update average latency (simple moving average)
        stats.averageLatency = (stats.averageLatency * Double(stats.totalCommands - 1) + operation.duration) / Double(stats.totalCommands)
        
        connectionStats[hostKey] = stats
    }
}

// MARK: - Supporting Types

/// Global SSH statistics
public struct SSHGlobalStats: Codable {
    public var activeConnections: Int = 0
    public var totalConnections: Int = 0
    public var reconnectCount: Int = 0
    public var totalCommands: Int = 0
    public var successCount: Int = 0
    public var successRate: Double = 0
    public var totalBytesTransferred: Int64 = 0
}

/// SSH performance metrics
public struct SSHPerformanceMetrics: Codable {
    public var averageLatency: Double = 0
    public var throughput: Double = 0
    public var errorRate: Double = 0
    public var currentLoad: Double = 0
    public var commandFrequency: [String: Int] = [:]
    public var slowestCommands: [SlowCommand] = []
}

/// SSH operation metrics for active operations
public struct SSHOperationMetrics {
    public let id: String
    public let host: String
    public let command: String
    public let startTime: Date
    public var status: OperationStatus
    public var progress: Double
    public var bytesTransferred: Int64 = 0
    
    public enum OperationStatus {
        case running
        case completed
        case failed
    }
}

/// SSH connection statistics per host
public struct SSHConnectionStats: Codable {
    public let host: String
    public let firstConnected: Date
    public var lastConnected: Date
    public var lastConnectionTime: Date?  // Optional timestamp of last connection
    public var totalConnections: Int
    public var totalCommands: Int
    public var totalBytesTransferred: Int64
    public var averageLatency: Double
    public var successRate: Double
    public var successCount: Int = 0
    public var failedCommands: Int = 0
    public var failedConnections: Int = 0  // Added for compilation
    public var averageConnectionTime: TimeInterval = 0
    public var isActive: Bool
}

/// SSH operation record
public struct SSHOperation: Codable {
    public let id: String
    public let host: String
    public let command: String
    public let timestamp: Date
    public let duration: TimeInterval
    public let success: Bool
    public let output: String?
    public let error: String?
    public let bytesTransferred: Int64
}

/// SSH alert
public struct SSHAlert: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let severity: AlertSeverity
    public let title: String
    public let message: String
    public let host: String?
    
    public enum AlertSeverity {
        case info
        case warning
        case error
        case critical
    }
}

/// Slow command record
public struct SlowCommand: Codable {
    public let command: String
    public let duration: TimeInterval
    public let timestamp: Date
}

/// Format bytes for display
public func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .binary
    return formatter.string(fromByteCount: bytes)
}