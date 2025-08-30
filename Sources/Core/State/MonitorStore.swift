//
//  MonitorStore.swift
//  ClaudeCode
//
//  Manages system monitoring and performance metrics
//

import SwiftUI
import Combine

/// Store for managing system monitoring and metrics
@MainActor
public final class MonitorStore: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var cpuUsage: Double = 0
    @Published public var memoryUsage: MemoryUsage = MemoryUsage()
    @Published public var diskUsage: DiskUsage = DiskUsage()
    @Published public var networkStats: NetworkStats = NetworkStats()
    @Published public var activeConnections: [SSHMonitorConnection] = []
    @Published public var processInfo: [ProcessInfo] = []
    @Published public var systemLogs: [SystemLog] = []
    @Published public var isMonitoring = false
    @Published public var refreshInterval: TimeInterval = 5.0
    
    // MARK: - Computed Properties
    
    public var hasActiveConnections: Bool {
        !activeConnections.isEmpty
    }
    
    public var totalBandwidthUsed: Int {
        networkStats.totalBytesReceived + networkStats.totalBytesSent
    }
    
    public var criticalLogs: [SystemLog] {
        systemLogs.filter { $0.level == .error || $0.level == .critical }
    }
    
    // MARK: - Private Properties
    
    private let sshManager: SSHManager
    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(sshManager: SSHManager) {
        self.sshManager = sshManager
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Initial update
        Task {
            await updateMetrics()
        }
        
        // Setup timer for periodic updates
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMetrics()
            }
        }
    }
    
    /// Stop monitoring
    public func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    /// Update refresh interval
    public func updateRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        
        if isMonitoring {
            stopMonitoring()
            startMonitoring()
        }
    }
    
    /// Clear system logs
    public func clearLogs() {
        systemLogs.removeAll()
    }
    
    /// Export monitoring data
    public func exportMonitoringData() async -> Data? {
        let exportData = MonitoringExport(
            timestamp: Date(),
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            diskUsage: diskUsage,
            networkStats: networkStats,
            activeConnections: activeConnections.map { ConnectionExport(from: $0) }
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(exportData)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Observe SSH connection changes
        // For now, we'll initialize with empty connections
        // TODO: Add proper SSH connection tracking when SSHManager is enhanced
        self.activeConnections = []
    }
    
    private func updateMetrics() async {
        // Update CPU usage
        cpuUsage = await fetchCPUUsage()
        
        // Update memory usage
        memoryUsage = await fetchMemoryUsage()
        
        // Update disk usage
        diskUsage = await fetchDiskUsage()
        
        // Update network stats
        networkStats = await fetchNetworkStats()
        
        // Update process info
        processInfo = await fetchProcessInfo()
        
        // Add monitoring log
        addLog(SystemLog(
            level: .info,
            message: "Metrics updated",
            timestamp: Date()
        ))
    }
    
    private func fetchCPUUsage() async -> Double {
        // Simulate CPU usage fetch
        // In a real app, this would use system APIs
        return Double.random(in: 10...80)
    }
    
    private func fetchMemoryUsage() async -> MemoryUsage {
        // Simulate memory usage fetch
        let total = 16 * 1024 * 1024 * 1024 // 16GB in bytes
        let used = Int.random(in: 4...12) * 1024 * 1024 * 1024
        let available = total - used
        
        return MemoryUsage(
            total: total,
            used: used,
            available: available,
            appUsage: Foundation.ProcessInfo.processInfo.physicalMemory
        )
    }
    
    private func fetchDiskUsage() async -> DiskUsage {
        // Get actual disk usage
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(
                forPath: NSHomeDirectory()
            )
            
            let total = (attributes[.systemSize] as? NSNumber)?.int64Value ?? 0
            let free = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            let used = total - free
            
            return DiskUsage(
                total: Int(total),
                used: Int(used),
                available: Int(free)
            )
        } catch {
            print("Failed to fetch disk usage: \(error)")
            return DiskUsage()
        }
    }
    
    private func fetchNetworkStats() async -> NetworkStats {
        // Simulate network stats
        // In a real app, this would use system APIs
        return NetworkStats(
            totalBytesReceived: Int.random(in: 1000000...10000000),
            totalBytesSent: Int.random(in: 500000...5000000),
            currentDownloadSpeed: Int.random(in: 0...1000000),
            currentUploadSpeed: Int.random(in: 0...500000)
        )
    }
    
    private func fetchProcessInfo() async -> [ProcessInfo] {
        // Get app process info
        let processInfo = Foundation.ProcessInfo.processInfo
        
        let pid = Int(processInfo.processIdentifier)
        return [
            ProcessInfo(
                id: String(pid),
                pid: pid,
                name: processInfo.processName,
                command: processInfo.arguments.joined(separator: " "),
                user: nil, // userName not available on iOS
                cpuUsage: cpuUsage,
                memoryUsage: Int64(processInfo.physicalMemory),
                virtualMemory: nil,
                threads: processInfo.activeProcessorCount,
                startTime: Date(),
                state: .running,
                parentPid: nil,
                priority: processInfo.processorCount
            )
        ]
    }
    
    private func addLog(_ log: SystemLog) {
        systemLogs.insert(log, at: 0)
        
        // Keep only last 1000 logs
        if systemLogs.count > 1000 {
            systemLogs.removeLast()
        }
    }
    
    /// Clear all monitoring data and reset to defaults
    public func clearAll() async {
        cpuUsage = 0
        memoryUsage = MemoryUsage()
        diskUsage = DiskUsage()
        networkStats = NetworkStats()
        activeConnections.removeAll()
        processInfo.removeAll()
        systemLogs.removeAll()
        isMonitoring = false
        
        // Stop monitoring if active
        stopMonitoring()
    }
}

// MARK: - Models

public struct MemoryUsage {
    public let total: Int
    public let used: Int
    public let available: Int
    public let appUsage: UInt64
    
    public init(total: Int = 0, used: Int = 0, available: Int = 0, appUsage: UInt64 = 0) {
        self.total = total
        self.used = used
        self.available = available
        self.appUsage = appUsage
    }
    
    public var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

public struct DiskUsage {
    public let total: Int
    public let used: Int
    public let available: Int
    
    public init(total: Int = 0, used: Int = 0, available: Int = 0) {
        self.total = total
        self.used = used
        self.available = available
    }
    
    public var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

public struct NetworkStats {
    public let totalBytesReceived: Int
    public let totalBytesSent: Int
    public let currentDownloadSpeed: Int
    public let currentUploadSpeed: Int
    
    public init(totalBytesReceived: Int = 0,
         totalBytesSent: Int = 0,
         currentDownloadSpeed: Int = 0,
         currentUploadSpeed: Int = 0) {
        self.totalBytesReceived = totalBytesReceived
        self.totalBytesSent = totalBytesSent
        self.currentDownloadSpeed = currentDownloadSpeed
        self.currentUploadSpeed = currentUploadSpeed
    }
}

public struct SSHMonitorConnection: Identifiable {
    public let id: String
    public let host: String
    public let port: Int
    public let username: String
    public let status: ConnectionStatus
    public let connectedAt: Date
    public let bytesTransferred: Int
}

// ProcessInfo is defined in Models/Network/MonitoringModels.swift

// ProcessStatus is defined in MonitoringModels.swift (if not already there)
public enum ProcessStatus {
    case running
    case sleeping
    case stopped
    case zombie
    
    public var color: Color {
        switch self {
        case .running: return .green
        case .sleeping: return .blue
        case .stopped: return .orange
        case .zombie: return .red
        }
    }
}

public struct SystemLog: Identifiable {
    public let id = UUID()
    public let level: LogLevel
    public let message: String
    public let timestamp: Date
    public let source: String?
    
    public init(level: LogLevel, message: String, timestamp: Date, source: String? = nil) {
        self.level = level
        self.message = message
        self.timestamp = timestamp
        self.source = source
    }
}

public enum LogLevel {
    case debug
    case info
    case warning
    case error
    case critical
    
    public var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    public var icon: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
}

// MARK: - Export Models

public struct MonitoringExport: Codable {
    public let timestamp: Date
    public let cpuUsage: Double
    public let memoryUsage: MemoryUsage
    public let diskUsage: DiskUsage
    public let networkStats: NetworkStats
    public let activeConnections: [ConnectionExport]
}

public struct ConnectionExport: Codable {
    public let host: String
    public let port: Int
    public let username: String
    public let connectedAt: Date
    
    public init(from connection: SSHMonitorConnection) {
        self.host = connection.host
        self.port = connection.port
        self.username = connection.username
        self.connectedAt = connection.connectedAt
    }
}

// Make structs Codable for export
extension MemoryUsage: Codable {}
extension DiskUsage: Codable {}
extension NetworkStats: Codable {}