//
//  SSHMonitor.swift
//  ClaudeCode
//
//  SSH operation monitoring and metrics collection (Tasks 751-775)
//

import Foundation
import OSLog
import Combine

/// SSH operation types for monitoring
public enum SSHOperationType: String, CaseIterable {
    case connect = "connect"
    case disconnect = "disconnect"
    case command = "command"
    case fileTransfer = "file_transfer"
    case portForward = "port_forward"
    case authenticate = "authenticate"
    case keepAlive = "keep_alive"
    case error = "error"
}

/// SSH operation metrics
public struct SSHOperationMetrics: Codable {
    public let operationType: SSHOperationType
    public let host: String
    public let port: Int
    public let startTime: Date
    public var endTime: Date?
    public var duration: TimeInterval?
    public var success: Bool = false
    public var bytesTransferred: Int64 = 0
    public var errorMessage: String?
    public var commandOutput: String?
    public var metadata: [String: String] = [:]
    
    public var isCompleted: Bool {
        endTime != nil
    }
    
    mutating func complete(success: Bool, error: String? = nil) {
        self.endTime = Date()
        self.duration = endTime?.timeIntervalSince(startTime)
        self.success = success
        self.errorMessage = error
    }
}

/// SSH connection statistics
public struct SSHConnectionStats: Codable {
    public var totalConnections: Int = 0
    public var activeConnections: Int = 0
    public var failedConnections: Int = 0
    public var totalCommands: Int = 0
    public var failedCommands: Int = 0
    public var totalBytesTransferred: Int64 = 0
    public var averageConnectionTime: TimeInterval = 0
    public var averageCommandTime: TimeInterval = 0
    public var lastConnectionTime: Date?
    public var uptime: TimeInterval = 0
    public var reconnectCount: Int = 0
    
    public var successRate: Double {
        let total = totalConnections + totalCommands
        let failed = failedConnections + failedCommands
        guard total > 0 else { return 1.0 }
        return Double(total - failed) / Double(total)
    }
}

/// SSH monitor for tracking operations and metrics
@MainActor
public class SSHMonitor: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var isMonitoring = false
    @Published public private(set) var activeOperations: [UUID: SSHOperationMetrics] = [:]
    @Published public private(set) var recentOperations: [SSHOperationMetrics] = []
    @Published public private(set) var connectionStats: [String: SSHConnectionStats] = [:]
    @Published public private(set) var globalStats = SSHConnectionStats()
    @Published public private(set) var performanceMetrics: SSHPerformanceMetrics
    @Published public private(set) var alerts: [SSHAlert] = []
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHMonitor")
    private let telemetry = TelemetryManager.shared
    private var operationHistory = CircularBuffer<SSHOperationMetrics>(capacity: 1000)
    private let queue = DispatchQueue(label: "com.claudecode.ssh.monitor", qos: .utility)
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 1.0
    private var startTime = Date()
    
    // Thresholds for alerts
    private let slowCommandThreshold: TimeInterval = 5.0
    private let highLatencyThreshold: TimeInterval = 1.0
    private let errorRateThreshold: Double = 0.2
    private let maxReconnectThreshold = 5
    
    // MARK: - Initialization
    
    public init() {
        self.performanceMetrics = SSHPerformanceMetrics()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    /// Start monitoring SSH operations
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        startTime = Date()
        
        // Start update timer for real-time metrics
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
        
        logger.info("SSH monitoring started")
        telemetry.logEvent(
            "ssh_monitor.started",
            category: .ssh,
            level: .info
        )
    }
    
    /// Stop monitoring SSH operations
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Export final metrics
        exportMetrics()
        
        logger.info("SSH monitoring stopped")
        telemetry.logEvent(
            "ssh_monitor.stopped",
            category: .ssh,
            level: .info,
            measurements: ["uptime": Date().timeIntervalSince(startTime)]
        )
    }
    
    // MARK: - Operation Tracking
    
    /// Begin tracking an SSH operation
    @discardableResult
    public func beginOperation(
        type: SSHOperationType,
        host: String,
        port: Int,
        metadata: [String: String]? = nil
    ) -> UUID {
        let operationId = UUID()
        
        var operation = SSHOperationMetrics(
            operationType: type,
            host: host,
            port: port,
            startTime: Date()
        )
        
        if let metadata = metadata {
            operation.metadata = metadata
        }
        
        activeOperations[operationId] = operation
        
        // Update connection stats
        let hostKey = "\(host):\(port)"
        var stats = connectionStats[hostKey] ?? SSHConnectionStats()
        
        switch type {
        case .connect:
            stats.totalConnections += 1
            stats.activeConnections += 1
            stats.lastConnectionTime = Date()
            globalStats.totalConnections += 1
            globalStats.activeConnections += 1
        case .command:
            stats.totalCommands += 1
            globalStats.totalCommands += 1
        default:
            break
        }
        
        connectionStats[hostKey] = stats
        
        // Log telemetry
        telemetry.logEvent(
            "ssh_operation.started",
            category: .ssh,
            level: .info,
            properties: [
                "type": type.rawValue,
                "host": host,
                "port": port
            ]
        )
        
        logger.debug("Started SSH operation: \(type.rawValue) for \(host):\(port)")
        
        return operationId
    }
    
    /// Complete tracking an SSH operation
    public func completeOperation(
        _ operationId: UUID,
        success: Bool,
        bytesTransferred: Int64 = 0,
        output: String? = nil,
        error: String? = nil
    ) {
        guard var operation = activeOperations[operationId] else {
            logger.warning("Attempted to complete unknown operation: \(operationId)")
            return
        }
        
        operation.complete(success: success, error: error)
        operation.bytesTransferred = bytesTransferred
        operation.commandOutput = output
        
        // Remove from active operations
        activeOperations.removeValue(forKey: operationId)
        
        // Add to history
        operationHistory.append(operation)
        recentOperations.append(operation)
        if recentOperations.count > 100 {
            recentOperations.removeFirst()
        }
        
        // Update stats
        updateOperationStats(operation)
        
        // Check for alerts
        checkForAlerts(operation)
        
        // Log telemetry
        telemetry.logEvent(
            "ssh_operation.completed",
            category: .ssh,
            level: success ? .info : .error,
            properties: [
                "type": operation.operationType.rawValue,
                "host": operation.host,
                "port": operation.port,
                "success": success,
                "error": error ?? ""
            ],
            measurements: [
                "duration": operation.duration ?? 0,
                "bytes": Double(bytesTransferred)
            ]
        )
        
        logger.debug("Completed SSH operation: \(operation.operationType.rawValue) - Success: \(success)")
    }
    
    /// Track command execution
    public func trackCommand(
        _ command: String,
        host: String,
        port: Int,
        operationId: UUID? = nil
    ) -> UUID {
        let id = operationId ?? beginOperation(
            type: .command,
            host: host,
            port: port,
            metadata: ["command": parseCommand(command)]
        )
        
        // Parse and categorize command
        let parsedCommand = parseCommand(command)
        performanceMetrics.commandFrequency[parsedCommand, default: 0] += 1
        
        return id
    }
    
    // MARK: - Command Parsing
    
    /// Parse command to extract the base command
    private func parseCommand(_ command: String) -> String {
        let components = command.split(separator: " ")
        guard let baseCommand = components.first else { return command }
        
        // Common commands to track
        let commonCommands = [
            "ls", "cd", "pwd", "cat", "echo", "grep", "find",
            "ps", "top", "df", "du", "free", "uptime",
            "systemctl", "service", "docker", "kubectl",
            "git", "npm", "yarn", "python", "node"
        ]
        
        let base = String(baseCommand)
        if commonCommands.contains(base) {
            return base
        }
        
        // Check for sudo/su prefixes
        if base == "sudo" || base == "su" {
            return components.count > 1 ? String(components[1]) : base
        }
        
        // For complex commands, just return the category
        if command.contains("|") {
            return "piped_command"
        }
        if command.contains("&&") || command.contains("||") {
            return "chained_command"
        }
        if command.contains(">") || command.contains("<") {
            return "redirected_command"
        }
        
        return base
    }
    
    // MARK: - Metrics Updates
    
    private func updateOperationStats(_ operation: SSHOperationMetrics) {
        let hostKey = "\(operation.host):\(operation.port)"
        var stats = connectionStats[hostKey] ?? SSHConnectionStats()
        
        switch operation.operationType {
        case .connect:
            if !operation.success {
                stats.failedConnections += 1
                globalStats.failedConnections += 1
            }
            if let duration = operation.duration {
                updateAverageTime(&stats.averageConnectionTime, stats.totalConnections, duration)
                updateAverageTime(&globalStats.averageConnectionTime, globalStats.totalConnections, duration)
            }
            
        case .disconnect:
            stats.activeConnections = max(0, stats.activeConnections - 1)
            globalStats.activeConnections = max(0, globalStats.activeConnections - 1)
            
        case .command:
            if !operation.success {
                stats.failedCommands += 1
                globalStats.failedCommands += 1
            }
            if let duration = operation.duration {
                updateAverageTime(&stats.averageCommandTime, stats.totalCommands, duration)
                updateAverageTime(&globalStats.averageCommandTime, globalStats.totalCommands, duration)
                
                // Track command performance
                performanceMetrics.slowestCommands.append((
                    command: operation.metadata["command"] ?? "unknown",
                    duration: duration,
                    timestamp: operation.startTime
                ))
                performanceMetrics.slowestCommands.sort { $0.duration > $1.duration }
                if performanceMetrics.slowestCommands.count > 10 {
                    performanceMetrics.slowestCommands.removeLast()
                }
            }
            
        case .fileTransfer:
            stats.totalBytesTransferred += operation.bytesTransferred
            globalStats.totalBytesTransferred += operation.bytesTransferred
            
        case .authenticate:
            if operation.success {
                performanceMetrics.successfulAuthentications += 1
            } else {
                performanceMetrics.failedAuthentications += 1
            }
            
        case .error:
            performanceMetrics.errorCount += 1
            performanceMetrics.lastErrors.append(
                SSHError(
                    message: operation.errorMessage ?? "Unknown error",
                    timestamp: operation.startTime,
                    host: operation.host,
                    operation: operation.operationType.rawValue
                )
            )
            if performanceMetrics.lastErrors.count > 20 {
                performanceMetrics.lastErrors.removeFirst()
            }
            
        default:
            break
        }
        
        connectionStats[hostKey] = stats
    }
    
    private func updateAverageTime(_ average: inout TimeInterval, _ count: Int, _ newValue: TimeInterval) {
        if count > 0 {
            average = (average * Double(count - 1) + newValue) / Double(count)
        } else {
            average = newValue
        }
    }
    
    /// Update real-time metrics
    private func updateMetrics() {
        // Update uptime
        globalStats.uptime = Date().timeIntervalSince(startTime)
        
        // Calculate current load
        let activeCount = activeOperations.count
        performanceMetrics.currentLoad = Double(activeCount) / 10.0 // Assuming 10 concurrent operations is full load
        
        // Update performance indicators
        updatePerformanceIndicators()
        
        // Clean old alerts
        let alertCutoff = Date().addingTimeInterval(-300) // Keep alerts for 5 minutes
        alerts.removeAll { $0.timestamp < alertCutoff }
    }
    
    private func updatePerformanceIndicators() {
        // Calculate average latency from recent operations
        let recentOps = recentOperations.suffix(20)
        if !recentOps.isEmpty {
            let latencies = recentOps.compactMap { $0.duration }
            performanceMetrics.averageLatency = latencies.reduce(0, +) / Double(latencies.count)
        }
        
        // Calculate throughput (operations per minute)
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        let recentOpsCount = recentOperations.filter { $0.startTime > oneMinuteAgo }.count
        performanceMetrics.throughput = Double(recentOpsCount)
        
        // Update error rate
        if globalStats.totalConnections + globalStats.totalCommands > 0 {
            performanceMetrics.errorRate = Double(globalStats.failedConnections + globalStats.failedCommands) /
                                           Double(globalStats.totalConnections + globalStats.totalCommands)
        }
    }
    
    // MARK: - Alerts
    
    private func checkForAlerts(_ operation: SSHOperationMetrics) {
        // Check for slow operations
        if let duration = operation.duration, duration > slowCommandThreshold {
            addAlert(
                level: .warning,
                message: "Slow \(operation.operationType.rawValue) operation: \(String(format: "%.2f", duration))s",
                details: ["host": operation.host, "command": operation.metadata["command"] ?? ""]
            )
        }
        
        // Check for high latency
        if performanceMetrics.averageLatency > highLatencyThreshold {
            addAlert(
                level: .warning,
                message: "High average latency detected: \(String(format: "%.2f", performanceMetrics.averageLatency))s",
                details: nil
            )
        }
        
        // Check for high error rate
        if performanceMetrics.errorRate > errorRateThreshold {
            addAlert(
                level: .critical,
                message: "High error rate: \(String(format: "%.1f%%", performanceMetrics.errorRate * 100))",
                details: nil
            )
        }
        
        // Check for connection failures
        if !operation.success && operation.operationType == .connect {
            addAlert(
                level: .error,
                message: "Connection failed to \(operation.host):\(operation.port)",
                details: ["error": operation.errorMessage ?? "Unknown error"]
            )
        }
    }
    
    private func addAlert(level: SSHAlertLevel, message: String, details: [String: String]?) {
        let alert = SSHAlert(
            id: UUID(),
            level: level,
            message: message,
            details: details,
            timestamp: Date()
        )
        
        alerts.append(alert)
        
        // Log to telemetry
        telemetry.logEvent(
            "ssh_monitor.alert",
            category: .ssh,
            level: level.toTelemetryLevel(),
            properties: ["message": message]
        )
        
        logger.warning("SSH Alert: \(message)")
    }
    
    // MARK: - Data Export
    
    /// Export monitoring data
    public func exportMetrics() -> SSHMonitoringExport {
        SSHMonitoringExport(
            exportDate: Date(),
            globalStats: globalStats,
            connectionStats: connectionStats,
            performanceMetrics: performanceMetrics,
            recentOperations: recentOperations,
            alerts: alerts
        )
    }
    
    /// Export to JSON
    public func exportToJSON() throws -> Data {
        let export = exportMetrics()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }
    
    /// Clear all monitoring data
    public func clearData() {
        activeOperations.removeAll()
        recentOperations.removeAll()
        connectionStats.removeAll()
        globalStats = SSHConnectionStats()
        performanceMetrics = SSHPerformanceMetrics()
        alerts.removeAll()
        operationHistory = CircularBuffer(capacity: 1000)
        
        logger.info("SSH monitoring data cleared")
    }
}

// MARK: - Supporting Types

/// SSH performance metrics
public struct SSHPerformanceMetrics: Codable {
    public var averageLatency: TimeInterval = 0
    public var throughput: Double = 0 // Operations per minute
    public var errorRate: Double = 0
    public var currentLoad: Double = 0
    public var successfulAuthentications: Int = 0
    public var failedAuthentications: Int = 0
    public var errorCount: Int = 0
    public var commandFrequency: [String: Int] = [:]
    public var slowestCommands: [(command: String, duration: TimeInterval, timestamp: Date)] = []
    public var lastErrors: [SSHError] = []
    
    enum CodingKeys: String, CodingKey {
        case averageLatency, throughput, errorRate, currentLoad
        case successfulAuthentications, failedAuthentications, errorCount
        case commandFrequency
    }
}

/// SSH error information
public struct SSHErrorRecord: Codable {
    public let message: String
    public let timestamp: Date
    public let host: String
    public let operation: String
}

/// SSH alert
public struct SSHAlert: Codable, Identifiable {
    public let id: UUID
    public let level: SSHAlertLevel
    public let message: String
    public let details: [String: String]?
    public let timestamp: Date
}

/// SSH alert level
public enum SSHAlertLevel: String, Codable {
    case info
    case warning
    case error
    case critical
    
    func toTelemetryLevel() -> TelemetryLevel {
        switch self {
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        }
    }
}

/// SSH monitoring export data
public struct SSHMonitoringExport: Codable {
    public let exportDate: Date
    public let globalStats: SSHConnectionStats
    public let connectionStats: [String: SSHConnectionStats]
    public let performanceMetrics: SSHPerformanceMetrics
    public let recentOperations: [SSHOperationMetrics]
    public let alerts: [SSHAlert]
}