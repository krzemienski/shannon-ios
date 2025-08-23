//
//  SSHMonitoringState.swift
//  ClaudeCode
//
//  State management for SSH monitoring UI (Tasks 786-790)
//

import Foundation
import SwiftUI
import Combine

/// Global state for SSH monitoring UI
@MainActor
public class SSHMonitoringState: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var isMonitoringEnabled = true
    @Published public var selectedSessionId: String?
    @Published public var displayMode: DisplayMode = .realtime
    @Published public var timeRange: TimeRange = .last5Minutes
    @Published public var filterOptions = FilterOptions()
    
    // Real-time data
    @Published public private(set) var realtimeMetrics: RealtimeMetrics
    @Published public private(set) var sessionList: [SessionSummary] = []
    @Published public private(set) var activeOperations: [ActiveOperationDisplay] = []
    @Published public private(set) var recentCommands: [RecentCommand] = []
    @Published public private(set) var performanceGraphData: PerformanceGraphData
    @Published public private(set) var alertBadges: AlertBadges
    
    // MARK: - Display Options
    
    public enum DisplayMode: String, CaseIterable {
        case realtime = "Real-time"
        case historical = "Historical"
        case analytics = "Analytics"
    }
    
    public enum TimeRange: String, CaseIterable {
        case last5Minutes = "5 min"
        case last15Minutes = "15 min"
        case lastHour = "1 hour"
        case last24Hours = "24 hours"
        case lastWeek = "Week"
        
        var timeInterval: TimeInterval {
            switch self {
            case .last5Minutes: return 300
            case .last15Minutes: return 900
            case .lastHour: return 3600
            case .last24Hours: return 86400
            case .lastWeek: return 604800
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let coordinator = SSHMonitoringCoordinator.shared
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 1.0
    
    // MARK: - Initialization
    
    public init() {
        self.realtimeMetrics = RealtimeMetrics()
        self.performanceGraphData = PerformanceGraphData()
        self.alertBadges = AlertBadges()
        
        setupBindings()
        startUpdates()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring updates
    public func startMonitoring() {
        isMonitoringEnabled = true
        coordinator.globalMonitor.startMonitoring()
        startUpdates()
    }
    
    /// Stop monitoring updates
    public func stopMonitoring() {
        isMonitoringEnabled = false
        coordinator.globalMonitor.stopMonitoring()
        stopUpdates()
    }
    
    /// Select a session for detailed view
    public func selectSession(_ sessionId: String?) {
        self.selectedSessionId = sessionId
        updateSessionDetails()
    }
    
    /// Clear all monitoring data
    public func clearAllData() {
        coordinator.globalMonitor.clearData()
        sessionList.removeAll()
        activeOperations.removeAll()
        recentCommands.removeAll()
        performanceGraphData.clearData()
        updateMetrics()
    }
    
    /// Export monitoring data
    public func exportData() throws -> Data {
        try coordinator.exportToJSON()
    }
    
    /// Apply filter to displayed data
    public func applyFilter(_ filter: FilterOptions) {
        self.filterOptions = filter
        updateDisplayedData()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Subscribe to coordinator updates
        coordinator.$realtimeStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateFromRealtimeStatus(status)
            }
            .store(in: &cancellables)
        
        coordinator.$aggregatedMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.updateFromAggregatedMetrics(metrics)
            }
            .store(in: &cancellables)
        
        coordinator.$healthStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] health in
                self?.updateHealthIndicators(health)
            }
            .store(in: &cancellables)
        
        coordinator.globalMonitor.$alerts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alerts in
                self?.updateAlertBadges(alerts)
            }
            .store(in: &cancellables)
    }
    
    private func startUpdates() {
        guard updateTimer == nil else { return }
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
        
        // Initial update
        updateMetrics()
    }
    
    private func stopUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateMetrics() {
        guard isMonitoringEnabled else { return }
        
        // Update realtime metrics
        let globalMonitor = coordinator.globalMonitor
        realtimeMetrics.activeConnections = globalMonitor.globalStats.activeConnections
        realtimeMetrics.totalCommands = globalMonitor.globalStats.totalCommands
        realtimeMetrics.errorRate = globalMonitor.performanceMetrics.errorRate
        realtimeMetrics.averageLatency = globalMonitor.performanceMetrics.averageLatency
        realtimeMetrics.throughput = globalMonitor.performanceMetrics.throughput
        realtimeMetrics.bytesTransferred = globalMonitor.globalStats.totalBytesTransferred
        
        // Update session list
        updateSessionList()
        
        // Update active operations
        updateActiveOperations()
        
        // Update recent commands
        updateRecentCommands()
        
        // Update performance graph data
        updatePerformanceGraph()
    }
    
    private func updateFromRealtimeStatus(_ status: SSHRealtimeStatus) {
        // Update active operations
        activeOperations = status.activeOperations.map { operation in
            ActiveOperationDisplay(
                id: operation.id,
                type: operation.type.rawValue.capitalized,
                host: operation.host,
                duration: formatDuration(operation.duration),
                isActive: true
            )
        }
        
        // Update connection status
        for (sessionId, connectionStatus) in status.connectionStatus {
            if let index = sessionList.firstIndex(where: { $0.id == sessionId }) {
                sessionList[index].isConnected = connectionStatus.isConnected
                sessionList[index].uptime = formatDuration(connectionStatus.uptime)
                sessionList[index].lastActivity = connectionStatus.lastActivity
            }
        }
    }
    
    private func updateFromAggregatedMetrics(_ metrics: AggregatedSSHMetrics) {
        // Update command frequency display
        let topCommands = metrics.topCommands.prefix(10).map { cmd in
            RecentCommand(
                command: cmd.command,
                count: cmd.count,
                timestamp: Date(),
                sessionId: nil
            )
        }
        
        if !topCommands.isEmpty {
            recentCommands = topCommands
        }
    }
    
    private func updateHealthIndicators(_ health: SSHHealthStatus) {
        // Update health score in metrics
        realtimeMetrics.healthScore = health.overallHealth
        
        // Update recommendations
        if !health.recommendations.isEmpty {
            alertBadges.recommendations = health.recommendations
        }
    }
    
    private func updateAlertBadges(_ alerts: [SSHAlert]) {
        let criticalCount = alerts.filter { $0.level == .critical }.count
        let errorCount = alerts.filter { $0.level == .error }.count
        let warningCount = alerts.filter { $0.level == .warning }.count
        
        alertBadges.criticalCount = criticalCount
        alertBadges.errorCount = errorCount
        alertBadges.warningCount = warningCount
        alertBadges.hasAlerts = criticalCount + errorCount + warningCount > 0
    }
    
    private func updateSessionList() {
        var sessions: [SessionSummary] = []
        
        for (sessionId, monitor) in coordinator.sessionMonitors {
            let metrics = monitor.getMetrics()
            let summary = SessionSummary(
                id: sessionId,
                host: monitor.host,
                port: monitor.port,
                isConnected: monitor.isActive,
                uptime: formatDuration(monitor.uptime),
                commandCount: metrics.totalCommands,
                errorRate: metrics.errorRate,
                bytesTransferred: formatBytes(metrics.bytesTransferred),
                lastActivity: monitor.lastActivity
            )
            sessions.append(summary)
        }
        
        // Apply filters
        if filterOptions.showActiveOnly {
            sessions = sessions.filter { $0.isConnected }
        }
        
        // Sort by last activity
        sessions.sort { ($0.lastActivity ?? Date.distantPast) > ($1.lastActivity ?? Date.distantPast) }
        
        self.sessionList = sessions
    }
    
    private func updateActiveOperations() {
        let operations = coordinator.globalMonitor.activeOperations.map { _, operation in
            ActiveOperationDisplay(
                id: UUID(),
                type: operation.operationType.rawValue.capitalized,
                host: operation.host,
                duration: formatDuration(Date().timeIntervalSince(operation.startTime)),
                isActive: true
            )
        }
        
        self.activeOperations = Array(operations.prefix(10))
    }
    
    private func updateRecentCommands() {
        let commands = coordinator.globalMonitor.recentOperations
            .filter { $0.operationType == .command }
            .suffix(20)
            .compactMap { operation -> RecentCommand? in
                guard let command = operation.metadata["command"] else { return nil }
                return RecentCommand(
                    command: command,
                    count: 1,
                    timestamp: operation.startTime,
                    sessionId: nil
                )
            }
        
        if !commands.isEmpty {
            self.recentCommands = Array(commands.reversed())
        }
    }
    
    private func updatePerformanceGraph() {
        performanceGraphData.addDataPoint(
            latency: coordinator.globalMonitor.performanceMetrics.averageLatency,
            throughput: coordinator.globalMonitor.performanceMetrics.throughput,
            errorRate: coordinator.globalMonitor.performanceMetrics.errorRate
        )
    }
    
    private func updateSessionDetails() {
        // Update detailed view for selected session
        guard let sessionId = selectedSessionId,
              let monitor = coordinator.sessionMonitors[sessionId] else { return }
        
        // Additional session-specific updates can be added here
    }
    
    private func updateDisplayedData() {
        // Apply filters and time range to displayed data
        updateMetrics()
    }
    
    // MARK: - Formatting Helpers
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Types

/// Filter options for monitoring display
public struct FilterOptions {
    public var showActiveOnly = false
    public var operationType: SSHOperationType?
    public var hostFilter: String?
    public var minErrorRate: Double?
    public var searchText = ""
}

/// Realtime metrics display
public struct RealtimeMetrics {
    public var activeConnections: Int = 0
    public var totalCommands: Int = 0
    public var errorRate: Double = 0
    public var averageLatency: TimeInterval = 0
    public var throughput: Double = 0
    public var bytesTransferred: Int64 = 0
    public var healthScore: Double = 1.0
}

/// Session summary for list display
public struct SessionSummary: Identifiable {
    public let id: String
    public let host: String
    public let port: Int
    public var isConnected: Bool
    public var uptime: String
    public let commandCount: Int
    public let errorRate: Double
    public let bytesTransferred: String
    public var lastActivity: Date?
}

/// Active operation display
public struct ActiveOperationDisplay: Identifiable {
    public let id: UUID
    public let type: String
    public let host: String
    public let duration: String
    public let isActive: Bool
}

/// Recent command display
public struct RecentCommand: Identifiable {
    public var id = UUID()
    public let command: String
    public let count: Int
    public let timestamp: Date
    public let sessionId: String?
}

/// Performance graph data
public class PerformanceGraphData: ObservableObject {
    @Published public var latencyPoints: [GraphPoint] = []
    @Published public var throughputPoints: [GraphPoint] = []
    @Published public var errorRatePoints: [GraphPoint] = []
    
    private let maxPoints = 60  // Keep last 60 data points
    
    public func addDataPoint(latency: TimeInterval, throughput: Double, errorRate: Double) {
        let timestamp = Date()
        
        latencyPoints.append(GraphPoint(timestamp: timestamp, value: latency))
        throughputPoints.append(GraphPoint(timestamp: timestamp, value: throughput))
        errorRatePoints.append(GraphPoint(timestamp: timestamp, value: errorRate * 100))  // Convert to percentage
        
        // Trim old points
        if latencyPoints.count > maxPoints {
            latencyPoints.removeFirst()
            throughputPoints.removeFirst()
            errorRatePoints.removeFirst()
        }
    }
    
    public func clearData() {
        latencyPoints.removeAll()
        throughputPoints.removeAll()
        errorRatePoints.removeAll()
    }
}

/// Graph data point
public struct GraphPoint: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let value: Double
}

/// Alert badges for UI
public struct AlertBadges {
    public var criticalCount = 0
    public var errorCount = 0
    public var warningCount = 0
    public var hasAlerts = false
    public var recommendations: [String] = []
}