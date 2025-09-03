//
//  MonitorViewModel.swift
//  ClaudeCode
//
//  ViewModel for system monitoring with MVVM pattern
//

import SwiftUI
import Combine

/// ViewModel for system monitoring interface
@MainActor
public final class MonitorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var cpuUsage: Double = 0
    @Published public var memoryUsage: MemoryUsage = MemoryUsage()
    @Published public var diskUsage: DiskUsage = DiskUsage()
    @Published public var networkStats: NetworkStats = NetworkStats()
    @Published public var activeConnections: [SSHConnection] = []
    @Published public var systemLogs: [SystemLog] = []
    @Published public var processInfo: [ProcessInfo] = []
    
    // MARK: - UI State
    
    @Published public var isMonitoring = false
    @Published public var selectedTab: MonitorTab = .overview
    @Published public var showExportOptions = false
    @Published public var showSettings = false
    @Published public var refreshInterval: TimeInterval = 5.0
    @Published public var selectedLogLevel: LogLevel? = nil
    @Published public var searchText = ""
    
    // MARK: - Charts Data
    
    @Published public var cpuHistory: [ChartDataPoint] = []
    @Published public var memoryHistory: [ChartDataPoint] = []
    @Published public var networkHistory: [NetworkChartData] = []
    
    // MARK: - Private Properties
    
    private let monitorStore: MonitorStore
    private let sshManager: SSHManager
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private let maxHistoryPoints = 60 // Keep last 60 data points
    
    // MARK: - Computed Properties
    
    public var filteredLogs: [SystemLog] {
        var logs = systemLogs
        
        // Filter by log level
        if let level = selectedLogLevel {
            logs = logs.filter { $0.level == level }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            logs = logs.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.source?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return logs
    }
    
    public var criticalMetrics: [MetricAlert] {
        var alerts: [MetricAlert] = []
        
        // CPU usage alert
        if cpuUsage > 80 {
            alerts.append(MetricAlert(
                type: .cpu,
                severity: cpuUsage > 90 ? .critical : .warning,
                message: "High CPU usage: \(Int(cpuUsage))%"
            ))
        }
        
        // Memory usage alert
        if memoryUsage.usedPercentage > 85 {
            alerts.append(MetricAlert(
                type: .memory,
                severity: memoryUsage.usedPercentage > 95 ? .critical : .warning,
                message: "High memory usage: \(Int(memoryUsage.usedPercentage))%"
            ))
        }
        
        // Disk usage alert
        if diskUsage.usedPercentage > 90 {
            alerts.append(MetricAlert(
                type: .disk,
                severity: .warning,
                message: "Low disk space: \(Int(diskUsage.available / 1024 / 1024 / 1024))GB remaining"
            ))
        }
        
        return alerts
    }
    
    public var hasActiveAlerts: Bool {
        !criticalMetrics.isEmpty
    }
    
    // MARK: - Initialization
    
    public init(monitorStore: MonitorStore,
         sshManager: SSHManager,
         appState: AppState) {
        self.monitorStore = monitorStore
        self.sshManager = sshManager
        self.appState = appState
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind to monitor store updates
        monitorStore.$cpuUsage
            .sink { [weak self] usage in
                self?.cpuUsage = usage
                self?.updateCPUHistory(usage)
            }
            .store(in: &cancellables)
        
        monitorStore.$memoryUsage
            .sink { [weak self] usage in
                self?.memoryUsage = usage
                self?.updateMemoryHistory(usage)
            }
            .store(in: &cancellables)
        
        monitorStore.$diskUsage
            .sink { [weak self] usage in
                self?.diskUsage = usage
            }
            .store(in: &cancellables)
        
        monitorStore.$networkStats
            .sink { [weak self] stats in
                self?.networkStats = stats
                self?.updateNetworkHistory(stats)
            }
            .store(in: &cancellables)
        
        monitorStore.$activeConnections
            .sink { [weak self] connections in
                self?.activeConnections = connections
            }
            .store(in: &cancellables)
        
        monitorStore.$systemLogs
            .sink { [weak self] logs in
                self?.systemLogs = logs
            }
            .store(in: &cancellables)
        
        monitorStore.$processInfo
            .sink { [weak self] processes in
                self?.processInfo = processes
            }
            .store(in: &cancellables)
        
        monitorStore.$isMonitoring
            .sink { [weak self] isMonitoring in
                self?.isMonitoring = isMonitoring
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods - Monitoring Control
    
    /// Start monitoring
    public func startMonitoring() {
        monitorStore.startMonitoring()
    }
    
    /// Stop monitoring
    public func stopMonitoring() {
        monitorStore.stopMonitoring()
    }
    
    /// Toggle monitoring
    public func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    /// Update refresh interval
    public func updateRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        monitorStore.updateRefreshInterval(interval)
    }
    
    /// Start automatic updates
    public func startUpdates() {
        startMonitoring()
    }
    
    /// Stop automatic updates
    public func stopUpdates() {
        stopMonitoring()
    }
    
    /// Update time range for data display
    public func updateTimeRange(_ range: TimeRange) {
        // Update the displayed data based on time range
        // This would filter historical data if we were storing it
        // For now, just trigger a refresh
        Task {
            await refreshMetrics()
        }
    }
    
    /// Refresh metrics manually
    public func refreshMetrics() async {
        // Trigger manual refresh
        // The monitor store will handle the actual update
    }
    
    // MARK: - Public Methods - Logs
    
    /// Clear system logs
    public func clearLogs() {
        monitorStore.clearLogs()
    }
    
    /// Filter logs by level
    public func filterByLogLevel(_ level: LogLevel?) {
        selectedLogLevel = level
    }
    
    /// Export logs
    public func exportLogs() async -> Data? {
        let logsToExport = filteredLogs
        
        let export = LogsExport(
            timestamp: Date(),
            logCount: logsToExport.count,
            logs: logsToExport.map { LogEntry(from: $0) }
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(export)
    }
    
    // MARK: - Public Methods - Data Export
    
    /// Export monitoring data
    public func exportMonitoringData() async -> Data? {
        await monitorStore.exportMonitoringData()
    }
    
    /// Export as CSV
    public func exportAsCSV() -> String {
        var csv = "Timestamp,CPU %,Memory Used,Memory Total,Disk Used,Disk Total,Network In,Network Out\n"
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        csv += "\(timestamp),"
        csv += "\(cpuUsage),"
        csv += "\(memoryUsage.used),\(memoryUsage.total),"
        csv += "\(diskUsage.used),\(diskUsage.total),"
        csv += "\(networkStats.totalBytesReceived),\(networkStats.totalBytesSent)\n"
        
        return csv
    }
    
    // MARK: - Public Methods - UI
    
    /// Select monitoring tab
    public func selectTab(_ tab: MonitorTab) {
        selectedTab = tab
    }
    
    /// Format bytes for display
    public func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Format percentage
    public func formatPercentage(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
    
    // MARK: - Private Methods - History Management
    
    private func updateCPUHistory(_ usage: Double) {
        let dataPoint = ChartDataPoint(
            timestamp: Date(),
            value: usage
        )
        
        cpuHistory.append(dataPoint)
        
        // Keep only last N points
        if cpuHistory.count > maxHistoryPoints {
            cpuHistory.removeFirst()
        }
    }
    
    private func updateMemoryHistory(_ usage: MemoryUsage) {
        let dataPoint = ChartDataPoint(
            timestamp: Date(),
            value: usage.usedPercentage
        )
        
        memoryHistory.append(dataPoint)
        
        if memoryHistory.count > maxHistoryPoints {
            memoryHistory.removeFirst()
        }
    }
    
    private func updateNetworkHistory(_ stats: NetworkStats) {
        let dataPoint = NetworkChartData(
            timestamp: Date(),
            downloadSpeed: stats.currentDownloadSpeed,
            uploadSpeed: stats.currentUploadSpeed
        )
        
        networkHistory.append(dataPoint)
        
        if networkHistory.count > maxHistoryPoints {
            networkHistory.removeFirst()
        }
    }
}

// MARK: - Supporting Types

public enum MonitorTab: String, CaseIterable {
    case overview = "Overview"
    case performance = "Performance"
    case network = "Network"
    case connections = "Connections"
    case logs = "Logs"
    case processes = "Processes"
    
    var icon: String {
        switch self {
        case .overview: return "gauge"
        case .performance: return "speedometer"
        case .network: return "network"
        case .connections: return "link"
        case .logs: return "doc.text"
        case .processes: return "cpu"
        }
    }
}

struct ChartDataPoint {
    let timestamp: Date
    let value: Double
}

struct NetworkChartData {
    let timestamp: Date
    let downloadSpeed: Int
    let uploadSpeed: Int
}

public struct MetricAlert: Identifiable {
    let id = UUID()
    let type: MetricType
    let severity: AlertSeverity
    let message: String
    let timestamp = Date()
}

// MetricType is now defined in NetworkModels.swift

enum AlertSeverity {
    case info
    case warning
    case critical
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Export Types

public struct LogsExport: Codable {
    let timestamp: Date
    let logCount: Int
    let logs: [LogEntry]
}

public struct LogEntry: Codable {
    let level: String
    let message: String
    let timestamp: Date
    let source: String?
    
    public     init(from log: SystemLog) {
        self.level = String(describing: log.level)
        self.message = log.message
        self.timestamp = log.timestamp
        self.source = log.source
    }
}