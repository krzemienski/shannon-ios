//
//  SSHMonitoringCoordinator.swift
//  ClaudeCode
//
//  Central coordinator for SSH monitoring across all components (Tasks 776-800)
//

import Foundation
import Combine
import OSLog

/// Central coordinator for SSH monitoring across all components
@MainActor
public class SSHMonitoringCoordinator: ObservableObject {
    // MARK: - Singleton
    
    public static let shared = SSHMonitoringCoordinator()
    
    // MARK: - Published Properties
    
    @Published public private(set) var globalMonitor: SSHMonitor
    @Published public private(set) var sessionMonitors: [String: SSHSessionMonitor] = [:]
    @Published public private(set) var aggregatedMetrics: AggregatedSSHMetrics
    @Published public private(set) var healthStatus: SSHHealthStatus
    @Published public private(set) var realtimeStatus: SSHRealtimeStatus
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHMonitoringCoordinator")
    private let telemetry = TelemetryManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let updateQueue = DispatchQueue(label: "com.claudecode.ssh.monitoring.coordinator", qos: .utility)
    
    // Update intervals
    private var aggregationTimer: Timer?
    private let aggregationInterval: TimeInterval = 5.0
    private var healthCheckTimer: Timer?
    private let healthCheckInterval: TimeInterval = 10.0
    
    // Thresholds for health monitoring
    private let healthThresholds = HealthThresholds()
    
    // MARK: - Initialization
    
    private init() {
        self.globalMonitor = SSHMonitor()
        self.aggregatedMetrics = AggregatedSSHMetrics()
        self.healthStatus = SSHHealthStatus()
        self.realtimeStatus = SSHRealtimeStatus()
        
        setupMonitoring()
        startTimers()
    }
    
    // MARK: - Session Management
    
    /// Create a monitor for a specific SSH session
    public func createSessionMonitor(sessionId: String, host: String, port: Int) -> SSHSessionMonitor {
        let monitor = SSHSessionMonitor(
            sessionId: sessionId,
            host: host,
            port: port,
            parentCoordinator: self
        )
        
        sessionMonitors[sessionId] = monitor
        
        logger.info("Created session monitor for \(sessionId)")
        telemetry.logEvent(
            "ssh_monitoring.session_created",
            category: .ssh,
            level: .info,
            properties: ["sessionId": sessionId, "host": host]
        )
        
        return monitor
    }
    
    /// Remove a session monitor
    public func removeSessionMonitor(sessionId: String) {
        guard let monitor = sessionMonitors.removeValue(forKey: sessionId) else { return }
        
        // Archive session metrics before removal
        archiveSessionMetrics(monitor)
        
        logger.info("Removed session monitor for \(sessionId)")
    }
    
    // MARK: - Monitoring Operations
    
    /// Start monitoring an operation
    @discardableResult
    public func startOperation(
        type: SSHOperationType,
        host: String,
        port: Int,
        sessionId: String? = nil,
        metadata: [String: String]? = nil
    ) -> UUID {
        // Track in global monitor
        let operationId = globalMonitor.beginOperation(
            type: type,
            host: host,
            port: port,
            metadata: metadata
        )
        
        // Track in session monitor if available
        if let sessionId = sessionId,
           let sessionMonitor = sessionMonitors[sessionId] {
            sessionMonitor.trackOperation(operationId, type: type, metadata: metadata)
        }
        
        // Update realtime status
        updateRealtimeStatus()
        
        return operationId
    }
    
    /// Complete a monitored operation
    public func completeOperation(
        _ operationId: UUID,
        success: Bool,
        sessionId: String? = nil,
        bytesTransferred: Int64 = 0,
        output: String? = nil,
        error: String? = nil
    ) {
        // Complete in global monitor
        globalMonitor.completeOperation(
            operationId,
            success: success,
            bytesTransferred: bytesTransferred,
            output: output,
            error: error
        )
        
        // Complete in session monitor if available
        if let sessionId = sessionId,
           let sessionMonitor = sessionMonitors[sessionId] {
            sessionMonitor.completeOperation(operationId, success: success)
        }
        
        // Update realtime status
        updateRealtimeStatus()
        
        // Check for anomalies
        checkForAnomalies(operationId: operationId, success: success, error: error)
    }
    
    // MARK: - Command Tracking
    
    /// Track command execution
    public func trackCommand(
        _ command: String,
        host: String,
        port: Int,
        sessionId: String? = nil
    ) -> UUID {
        let operationId = globalMonitor.trackCommand(
            command,
            host: host,
            port: port
        )
        
        if let sessionId = sessionId,
           let sessionMonitor = sessionMonitors[sessionId] {
            sessionMonitor.trackCommand(command)
        }
        
        return operationId
    }
    
    // MARK: - Health Monitoring
    
    /// Perform health check across all monitored components
    private func performHealthCheck() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.updateHealthStatus()
            }
        }
    }
    
    private func updateHealthStatus() {
        var status = SSHHealthStatus()
        
        // Check global metrics
        let globalStats = globalMonitor.globalStats
        status.overallHealth = calculateHealthScore(globalStats)
        
        // Check individual sessions
        for (sessionId, monitor) in sessionMonitors {
            let sessionHealth = SessionHealthStatus(
                sessionId: sessionId,
                isHealthy: monitor.isHealthy,
                errorRate: monitor.errorRate,
                averageLatency: monitor.averageLatency,
                uptime: monitor.uptime
            )
            status.sessionHealth[sessionId] = sessionHealth
        }
        
        // Check for system-wide issues
        status.hasHighErrorRate = globalMonitor.performanceMetrics.errorRate > healthThresholds.errorRateThreshold
        status.hasHighLatency = globalMonitor.performanceMetrics.averageLatency > healthThresholds.latencyThreshold
        status.hasLowThroughput = globalMonitor.performanceMetrics.throughput < healthThresholds.throughputThreshold
        
        // Generate health recommendations
        status.recommendations = generateHealthRecommendations(status)
        
        self.healthStatus = status
        
        // Log health status changes
        if status.overallHealth < 0.7 {
            logger.warning("SSH health degraded: \(status.overallHealth)")
            telemetry.logEvent(
                "ssh_monitoring.health_degraded",
                category: .ssh,
                level: .warning,
                measurements: ["health_score": status.overallHealth]
            )
        }
    }
    
    private func calculateHealthScore(_ stats: SSHConnectionStats) -> Double {
        var score = 1.0
        
        // Penalize based on error rate
        let errorRate = stats.totalConnections > 0 
            ? Double(stats.failedConnections) / Double(stats.totalConnections)
            : 0
        score -= errorRate * 0.3
        
        // Penalize based on command failures
        let commandErrorRate = stats.totalCommands > 0
            ? Double(stats.failedCommands) / Double(stats.totalCommands)
            : 0
        score -= commandErrorRate * 0.2
        
        // Consider connection time
        if stats.averageConnectionTime > 5.0 {
            score -= 0.1
        }
        
        // Consider command execution time
        if stats.averageCommandTime > 2.0 {
            score -= 0.1
        }
        
        return max(0, min(1, score))
    }
    
    private func generateHealthRecommendations(_ status: SSHHealthStatus) -> [String] {
        var recommendations: [String] = []
        
        if status.hasHighErrorRate {
            recommendations.append("High error rate detected. Check network connectivity and server status.")
        }
        
        if status.hasHighLatency {
            recommendations.append("High latency detected. Consider optimizing commands or checking network conditions.")
        }
        
        if status.hasLowThroughput {
            recommendations.append("Low throughput detected. Review command complexity and connection pooling.")
        }
        
        // Check individual session health
        let unhealthySessions = status.sessionHealth.filter { !$0.value.isHealthy }
        if !unhealthySessions.isEmpty {
            recommendations.append("Some sessions are unhealthy. Consider reconnecting or investigating issues.")
        }
        
        return recommendations
    }
    
    // MARK: - Metrics Aggregation
    
    private func aggregateMetrics() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.updateAggregatedMetrics()
            }
        }
    }
    
    private func updateAggregatedMetrics() {
        var metrics = AggregatedSSHMetrics()
        
        // Aggregate from global monitor
        let globalStats = globalMonitor.globalStats
        metrics.totalConnections = globalStats.totalConnections
        metrics.activeConnections = globalStats.activeConnections
        metrics.totalCommands = globalStats.totalCommands
        metrics.totalBytesTransferred = globalStats.totalBytesTransferred
        metrics.globalSuccessRate = globalStats.successRate
        
        // Aggregate from session monitors
        for monitor in sessionMonitors.values {
            metrics.totalSessions += 1
            if monitor.isActive {
                metrics.activeSessions += 1
            }
            metrics.sessionMetrics[monitor.sessionId] = monitor.getMetrics()
        }
        
        // Calculate aggregate performance metrics
        let performanceMetrics = globalMonitor.performanceMetrics
        metrics.averageLatency = performanceMetrics.averageLatency
        metrics.throughput = performanceMetrics.throughput
        metrics.errorRate = performanceMetrics.errorRate
        
        // Command frequency analysis
        metrics.topCommands = Array(performanceMetrics.commandFrequency
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { CommandFrequency(command: $0.key, count: $0.value) })
        
        // Recent errors
        metrics.recentErrors = performanceMetrics.lastErrors.suffix(10)
        
        self.aggregatedMetrics = metrics
    }
    
    // MARK: - Realtime Status Updates
    
    private func updateRealtimeStatus() {
        var status = SSHRealtimeStatus()
        
        // Active operations from global monitor
        status.activeOperations = globalMonitor.activeOperations.map { _, operation in
            ActiveOperation(
                id: UUID(),
                type: operation.operationType,
                host: operation.host,
                startTime: operation.startTime,
                duration: Date().timeIntervalSince(operation.startTime)
            )
        }
        
        // Connection status
        for monitor in sessionMonitors.values {
            status.connectionStatus[monitor.sessionId] = ConnectionStatus(
                sessionId: monitor.sessionId,
                host: monitor.host,
                port: monitor.port,
                isConnected: monitor.isActive,
                uptime: monitor.uptime,
                lastActivity: monitor.lastActivity
            )
        }
        
        // Current load and performance
        status.currentLoad = globalMonitor.performanceMetrics.currentLoad
        status.currentThroughput = globalMonitor.performanceMetrics.throughput
        status.activeAlerts = globalMonitor.alerts
        
        self.realtimeStatus = status
    }
    
    // MARK: - Anomaly Detection
    
    private func checkForAnomalies(operationId: UUID, success: Bool, error: String?) {
        // Check for repeated failures
        let recentFailures = globalMonitor.recentOperations
            .suffix(10)
            .filter { !$0.success }
            .count
        
        if recentFailures > 5 {
            logger.warning("High failure rate detected: \(recentFailures) failures in last 10 operations")
            telemetry.logEvent(
                "ssh_monitoring.anomaly.high_failure_rate",
                category: .ssh,
                level: .warning,
                measurements: ["failure_count": Double(recentFailures)]
            )
        }
        
        // Check for specific error patterns
        if let error = error {
            if error.contains("timeout") {
                telemetry.logEvent(
                    "ssh_monitoring.anomaly.timeout",
                    category: .ssh,
                    level: .warning
                )
            } else if error.contains("authentication") {
                telemetry.logEvent(
                    "ssh_monitoring.anomaly.auth_failure",
                    category: .ssh,
                    level: .error
                )
            } else if error.contains("connection refused") {
                telemetry.logEvent(
                    "ssh_monitoring.anomaly.connection_refused",
                    category: .ssh,
                    level: .error
                )
            }
        }
    }
    
    // MARK: - Data Export
    
    /// Export comprehensive monitoring data
    public func exportMonitoringData() -> ComprehensiveSSHMonitoringExport {
        ComprehensiveSSHMonitoringExport(
            exportDate: Date(),
            globalMetrics: globalMonitor.exportMetrics(),
            sessionMetrics: sessionMonitors.mapValues { $0.exportMetrics() },
            aggregatedMetrics: aggregatedMetrics,
            healthStatus: healthStatus,
            realtimeStatus: realtimeStatus
        )
    }
    
    /// Export to JSON
    public func exportToJSON() throws -> Data {
        let export = exportMonitoringData()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        // Subscribe to global monitor changes
        globalMonitor.$alerts
            .sink { [weak self] _ in
                self?.updateRealtimeStatus()
            }
            .store(in: &cancellables)
        
        globalMonitor.$recentOperations
            .sink { [weak self] _ in
                self?.aggregateMetrics()
            }
            .store(in: &cancellables)
    }
    
    private func startTimers() {
        // Start aggregation timer
        aggregationTimer = Timer.scheduledTimer(withTimeInterval: aggregationInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.aggregateMetrics()
            }
        }
        
        // Start health check timer
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.performHealthCheck()
            }
        }
    }
    
    private func archiveSessionMetrics(_ monitor: SSHSessionMonitor) {
        // Archive session metrics for historical analysis
        let metrics = monitor.exportMetrics()
        
        // TODO: Fix telemetry event logging
        // telemetry.logEvent(
        //     CustomEvent(
        //         name: "ssh_monitoring.session_archived",
        //         category: "ssh",
        //         metadata: [
        //             "sessionId": monitor.sessionId,
        //             "host": monitor.host,
        //             "duration": String(monitor.uptime)
        //         ]
        //     )
        // )
    }
}

// MARK: - Supporting Types

/// Health thresholds for monitoring
private struct HealthThresholds {
    let errorRateThreshold: Double = 0.1  // 10% error rate
    let latencyThreshold: TimeInterval = 2.0  // 2 seconds
    let throughputThreshold: Double = 1.0  // 1 operation per minute minimum
}

/// Aggregated SSH metrics across all sessions
public struct AggregatedSSHMetrics: Codable {
    public var totalConnections: Int = 0
    public var activeConnections: Int = 0
    public var totalSessions: Int = 0
    public var activeSessions: Int = 0
    public var totalCommands: Int = 0
    public var totalBytesTransferred: Int64 = 0
    public var globalSuccessRate: Double = 0
    public var averageLatency: TimeInterval = 0
    public var throughput: Double = 0
    public var errorRate: Double = 0
    public var topCommands: [CommandFrequency] = []
    public var recentErrors: [SSHErrorRecord] = []
    public var sessionMetrics: [String: SessionMetrics] = [:]
}

/// Command frequency tracking
public struct CommandFrequency: Codable {
    public let command: String
    public let count: Int
}

/// SSH health status
public struct SSHHealthStatus: Codable {
    public var overallHealth: Double = 1.0  // 0.0 to 1.0
    public var sessionHealth: [String: SessionHealthStatus] = [:]
    public var hasHighErrorRate: Bool = false
    public var hasHighLatency: Bool = false
    public var hasLowThroughput: Bool = false
    public var recommendations: [String] = []
}

/// Session health status
public struct SessionHealthStatus: Codable {
    public let sessionId: String
    public let isHealthy: Bool
    public let errorRate: Double
    public let averageLatency: TimeInterval
    public let uptime: TimeInterval
}

/// Realtime SSH status
public struct SSHRealtimeStatus: Codable {
    public var activeOperations: [ActiveOperation] = []
    public var connectionStatus: [String: ConnectionStatus] = [:]
    public var currentLoad: Double = 0
    public var currentThroughput: Double = 0
    public var activeAlerts: [SSHAlert] = []
}

/// Active operation info
public struct ActiveOperation: Codable, Identifiable {
    public let id: UUID
    public let type: SSHOperationType
    public let host: String
    public let startTime: Date
    public let duration: TimeInterval
}

/// Connection status info
public struct ConnectionStatus: Codable {
    public let sessionId: String
    public let host: String
    public let port: Int
    public let isConnected: Bool
    public let uptime: TimeInterval
    public let lastActivity: Date?
}

/// Session metrics
public struct SessionMetrics: Codable {
    public let sessionId: String
    public let totalCommands: Int
    public let errorRate: Double
    public let bytesTransferred: Int64
    public let uptime: TimeInterval
}

/// Comprehensive monitoring export
public struct ComprehensiveSSHMonitoringExport: Codable {
    public let exportDate: Date
    public let globalMetrics: SSHMonitoringExport
    public let sessionMetrics: [String: SSHSessionMonitoringExport]
    public let aggregatedMetrics: AggregatedSSHMetrics
    public let healthStatus: SSHHealthStatus
    public let realtimeStatus: SSHRealtimeStatus
}