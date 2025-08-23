//
//  SSHSessionMonitor.swift
//  ClaudeCode
//
//  Per-session SSH monitoring (Tasks 781-785)
//

import Foundation
import OSLog
import Combine

/// Monitor for individual SSH sessions
@MainActor
public class SSHSessionMonitor: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var isActive = false
    @Published public private(set) var sessionMetrics: SessionDetailedMetrics
    @Published public private(set) var commandHistory: [CommandRecord] = []
    @Published public private(set) var activeOperations: [UUID: OperationRecord] = [:]
    @Published public private(set) var lastActivity: Date?
    
    // MARK: - Public Properties
    
    public let sessionId: String
    public let host: String
    public let port: Int
    
    public var isHealthy: Bool {
        errorRate < 0.1 && averageLatency < 2.0
    }
    
    public var errorRate: Double {
        sessionMetrics.errorRate
    }
    
    public var averageLatency: TimeInterval {
        sessionMetrics.averageLatency
    }
    
    public var uptime: TimeInterval {
        isActive ? Date().timeIntervalSince(sessionMetrics.connectedAt) : sessionMetrics.totalUptime
    }
    
    // MARK: - Private Properties
    
    private weak var parentCoordinator: SSHMonitoringCoordinator?
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHSessionMonitor")
    private var commandBuffer = CircularBuffer<CommandRecord>(capacity: 100)
    private let telemetry = TelemetryManager.shared
    
    // Performance tracking
    private var latencyMeasurements: [TimeInterval] = []
    private var errorCount = 0
    private var successCount = 0
    
    // Update timer
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 1.0
    
    // MARK: - Initialization
    
    public init(
        sessionId: String,
        host: String,
        port: Int,
        parentCoordinator: SSHMonitoringCoordinator? = nil
    ) {
        self.sessionId = sessionId
        self.host = host
        self.port = port
        self.parentCoordinator = parentCoordinator
        self.sessionMetrics = SessionDetailedMetrics(
            sessionId: sessionId,
            host: host,
            port: port,
            connectedAt: Date()
        )
        
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    /// Start monitoring the session
    public func startMonitoring() {
        guard !isActive else { return }
        
        isActive = true
        sessionMetrics.connectedAt = Date()
        lastActivity = Date()
        
        // Start update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
        
        logger.info("Started monitoring session \(sessionId)")
        telemetry.logEvent(
            "ssh_session_monitor.started",
            category: .ssh,
            level: .info,
            properties: ["sessionId": sessionId, "host": host]
        )
    }
    
    /// Stop monitoring the session
    public func stopMonitoring() {
        guard isActive else { return }
        
        isActive = false
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Update total uptime
        sessionMetrics.totalUptime = uptime
        sessionMetrics.disconnectedAt = Date()
        
        logger.info("Stopped monitoring session \(sessionId)")
        telemetry.logEvent(
            "ssh_session_monitor.stopped",
            category: .ssh,
            level: .info,
            properties: ["sessionId": sessionId],
            measurements: ["uptime": uptime]
        )
    }
    
    // MARK: - Operation Tracking
    
    /// Track an operation in this session
    public func trackOperation(
        _ operationId: UUID,
        type: SSHOperationType,
        metadata: [String: String]? = nil
    ) {
        let operation = OperationRecord(
            id: operationId,
            type: type,
            startTime: Date(),
            metadata: metadata
        )
        
        activeOperations[operationId] = operation
        lastActivity = Date()
        
        // Update metrics based on operation type
        switch type {
        case .command:
            sessionMetrics.totalCommands += 1
        case .fileTransfer:
            sessionMetrics.totalFileTransfers += 1
        case .portForward:
            sessionMetrics.totalPortForwards += 1
        case .authenticate:
            sessionMetrics.authenticationAttempts += 1
        default:
            break
        }
    }
    
    /// Complete an operation
    public func completeOperation(_ operationId: UUID, success: Bool) {
        guard var operation = activeOperations.removeValue(forKey: operationId) else { return }
        
        operation.endTime = Date()
        operation.success = success
        operation.duration = operation.endTime?.timeIntervalSince(operation.startTime)
        
        lastActivity = Date()
        
        // Update success/error counts
        if success {
            successCount += 1
        } else {
            errorCount += 1
            sessionMetrics.totalErrors += 1
        }
        
        // Track latency
        if let duration = operation.duration {
            latencyMeasurements.append(duration)
            if latencyMeasurements.count > 100 {
                latencyMeasurements.removeFirst()
            }
            
            // Track slow operations
            if duration > 5.0 {
                sessionMetrics.slowOperations.append(SlowOperation(
                    type: operation.type,
                    duration: duration,
                    timestamp: operation.startTime
                ))
                if sessionMetrics.slowOperations.count > 10 {
                    sessionMetrics.slowOperations.removeFirst()
                }
            }
        }
        
        updateMetrics()
    }
    
    // MARK: - Command Tracking
    
    /// Track a command execution
    public func trackCommand(_ command: String) {
        let record = CommandRecord(
            command: parseCommand(command),
            fullCommand: command,
            timestamp: Date(),
            sessionId: sessionId
        )
        
        commandHistory.append(record)
        if commandHistory.count > 100 {
            commandHistory.removeFirst()
        }
        
        commandBuffer.append(record)
        
        // Update command frequency
        sessionMetrics.commandFrequency[record.command, default: 0] += 1
        
        lastActivity = Date()
    }
    
    /// Track bytes transferred
    public func trackBytesTransferred(_ bytes: Int64) {
        sessionMetrics.bytesTransferred += bytes
        sessionMetrics.totalBytesTransferred += bytes
        lastActivity = Date()
    }
    
    /// Track an error
    public func trackError(_ error: String, operation: String) {
        let errorRecord = SSHErrorRecord(
            message: error,
            timestamp: Date(),
            host: host,
            operation: operation
        )
        
        sessionMetrics.recentErrors.append(errorRecord)
        if sessionMetrics.recentErrors.count > 20 {
            sessionMetrics.recentErrors.removeFirst()
        }
        
        errorCount += 1
        sessionMetrics.totalErrors += 1
        lastActivity = Date()
    }
    
    // MARK: - Metrics Updates
    
    private func updateMetrics() {
        // Update error rate
        let total = successCount + errorCount
        sessionMetrics.errorRate = total > 0 ? Double(errorCount) / Double(total) : 0
        
        // Update average latency
        if !latencyMeasurements.isEmpty {
            sessionMetrics.averageLatency = latencyMeasurements.reduce(0, +) / Double(latencyMeasurements.count)
        }
        
        // Update throughput (operations per minute)
        let uptime = self.uptime
        if uptime > 0 {
            sessionMetrics.throughput = Double(sessionMetrics.totalCommands) / (uptime / 60.0)
        }
        
        // Check for idle timeout
        if let lastActivity = lastActivity {
            let idleTime = Date().timeIntervalSince(lastActivity)
            sessionMetrics.isIdle = idleTime > 300 // 5 minutes
        }
        
        // Update peak metrics
        if sessionMetrics.throughput > sessionMetrics.peakThroughput {
            sessionMetrics.peakThroughput = sessionMetrics.throughput
        }
        
        let activeCount = activeOperations.count
        if activeCount > sessionMetrics.peakConcurrentOperations {
            sessionMetrics.peakConcurrentOperations = activeCount
        }
    }
    
    // MARK: - Command Parsing
    
    private func parseCommand(_ command: String) -> String {
        let components = command.split(separator: " ")
        guard let baseCommand = components.first else { return command }
        
        let base = String(baseCommand)
        
        // Handle sudo/su prefixes
        if base == "sudo" || base == "su" {
            return components.count > 1 ? String(components[1]) : base
        }
        
        // For complex commands, categorize
        if command.contains("|") {
            return "piped"
        }
        if command.contains("&&") || command.contains("||") {
            return "chained"
        }
        if command.contains(">") || command.contains("<") {
            return "redirected"
        }
        
        return base
    }
    
    // MARK: - Data Export
    
    /// Get current metrics
    public func getMetrics() -> SessionMetrics {
        SessionMetrics(
            sessionId: sessionId,
            totalCommands: sessionMetrics.totalCommands,
            errorRate: sessionMetrics.errorRate,
            bytesTransferred: sessionMetrics.bytesTransferred,
            uptime: uptime
        )
    }
    
    /// Export detailed metrics
    public func exportMetrics() -> SSHSessionMonitoringExport {
        SSHSessionMonitoringExport(
            sessionId: sessionId,
            host: host,
            port: port,
            metrics: sessionMetrics,
            commandHistory: Array(commandBuffer.drain()),
            isActive: isActive,
            lastActivity: lastActivity
        )
    }
}

// MARK: - Supporting Types

/// Detailed metrics for a session
public struct SessionDetailedMetrics: Codable {
    public let sessionId: String
    public let host: String
    public let port: Int
    public var connectedAt: Date
    public var disconnectedAt: Date?
    public var totalUptime: TimeInterval = 0
    
    // Operation counts
    public var totalCommands: Int = 0
    public var totalFileTransfers: Int = 0
    public var totalPortForwards: Int = 0
    public var authenticationAttempts: Int = 0
    public var totalErrors: Int = 0
    
    // Performance metrics
    public var errorRate: Double = 0
    public var averageLatency: TimeInterval = 0
    public var throughput: Double = 0  // Operations per minute
    public var peakThroughput: Double = 0
    public var peakConcurrentOperations: Int = 0
    
    // Data transfer
    public var bytesTransferred: Int64 = 0
    public var totalBytesTransferred: Int64 = 0
    
    // Command analysis
    public var commandFrequency: [String: Int] = [:]
    public var slowOperations: [SlowOperation] = []
    public var recentErrors: [SSHErrorRecord] = []
    
    // Status
    public var isIdle: Bool = false
}

/// Command execution record
public struct CommandRecord: Codable {
    public let command: String  // Parsed base command
    public let fullCommand: String  // Full command string
    public let timestamp: Date
    public let sessionId: String
}

/// Operation record
public struct OperationRecord {
    public let id: UUID
    public let type: SSHOperationType
    public let startTime: Date
    public var endTime: Date?
    public var duration: TimeInterval?
    public var success: Bool = false
    public let metadata: [String: String]?
}

/// Slow operation record
public struct SlowOperation: Codable {
    public let type: SSHOperationType
    public let duration: TimeInterval
    public let timestamp: Date
}

/// Session monitoring export data
public struct SSHSessionMonitoringExport: Codable {
    public let sessionId: String
    public let host: String
    public let port: Int
    public let metrics: SessionDetailedMetrics
    public let commandHistory: [CommandRecord]
    public let isActive: Bool
    public let lastActivity: Date?
}