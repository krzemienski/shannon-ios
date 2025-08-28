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
final class MonitorStore: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var cpuUsage: Double = 0
    @Published var memoryUsage: MemoryUsage = MemoryUsage()
    @Published var diskUsage: DiskUsage = DiskUsage()
    @Published var networkStats: NetworkStats = NetworkStats()
    @Published var activeConnections: [SSHMonitorConnection] = []
    @Published var processInfo: [ProcessInfo] = []
    @Published var systemLogs: [SystemLog] = []
    @Published var isMonitoring = false
    @Published var refreshInterval: TimeInterval = 5.0
    
    // MARK: - Computed Properties
    
    var hasActiveConnections: Bool {
        !activeConnections.isEmpty
    }
    
    var totalBandwidthUsed: Int {
        networkStats.totalBytesReceived + networkStats.totalBytesSent
    }
    
    var criticalLogs: [SystemLog] {
        systemLogs.filter { $0.level == .error || $0.level == .critical }
    }
    
    // MARK: - Private Properties
    
    private let sshManager: SSHManager
    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(sshManager: SSHManager) {
        self.sshManager = sshManager
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring
    func startMonitoring() {
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
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    /// Update refresh interval
    func updateRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        
        if isMonitoring {
            stopMonitoring()
            startMonitoring()
        }
    }
    
    /// Clear system logs
    func clearLogs() {
        systemLogs.removeAll()
    }
    
    /// Export monitoring data
    func exportMonitoringData() async -> Data? {
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
        sshManager.$connections
            .sink { [weak self] connections in
                self?.activeConnections = connections
            }
            .store(in: &cancellables)
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
            appUsage: ProcessInfo.processInfo.physicalMemory
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
        
        return [
            ProcessInfo(
                name: processInfo.processName,
                pid: Int(processInfo.processIdentifier),
                cpuUsage: cpuUsage,
                memoryUsage: Int(processInfo.physicalMemory),
                status: .running
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
    func clearAll() async {
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

struct MemoryUsage {
    let total: Int
    let used: Int
    let available: Int
    let appUsage: UInt64
    
    init(total: Int = 0, used: Int = 0, available: Int = 0, appUsage: UInt64 = 0) {
        self.total = total
        self.used = used
        self.available = available
        self.appUsage = appUsage
    }
    
    var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

struct DiskUsage {
    let total: Int
    let used: Int
    let available: Int
    
    init(total: Int = 0, used: Int = 0, available: Int = 0) {
        self.total = total
        self.used = used
        self.available = available
    }
    
    var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

struct NetworkStats {
    let totalBytesReceived: Int
    let totalBytesSent: Int
    let currentDownloadSpeed: Int
    let currentUploadSpeed: Int
    
    init(totalBytesReceived: Int = 0,
         totalBytesSent: Int = 0,
         currentDownloadSpeed: Int = 0,
         currentUploadSpeed: Int = 0) {
        self.totalBytesReceived = totalBytesReceived
        self.totalBytesSent = totalBytesSent
        self.currentDownloadSpeed = currentDownloadSpeed
        self.currentUploadSpeed = currentUploadSpeed
    }
}

struct SSHMonitorConnection: Identifiable {
    let id: String
    let host: String
    let port: Int
    let username: String
    let status: ConnectionStatus
    let connectedAt: Date
    let bytesTransferred: Int
}

// ProcessInfo is defined in Models/Network/MonitoringModels.swift

// ProcessStatus is defined in MonitoringModels.swift (if not already there)
enum ProcessStatus {
    case running
    case sleeping
    case stopped
    case zombie
    
    var color: Color {
        switch self {
        case .running: return .green
        case .sleeping: return .blue
        case .stopped: return .orange
        case .zombie: return .red
        }
    }
}

struct SystemLog: Identifiable {
    let id = UUID()
    let level: LogLevel
    let message: String
    let timestamp: Date
    let source: String?
    
    init(level: LogLevel, message: String, timestamp: Date, source: String? = nil) {
        self.level = level
        self.message = message
        self.timestamp = timestamp
        self.source = source
    }
}

enum LogLevel {
    case debug
    case info
    case warning
    case error
    case critical
    
    var color: Color {
        switch self {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    var icon: String {
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

struct MonitoringExport: Codable {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: MemoryUsage
    let diskUsage: DiskUsage
    let networkStats: NetworkStats
    let activeConnections: [ConnectionExport]
}

struct ConnectionExport: Codable {
    let host: String
    let port: Int
    let username: String
    let connectedAt: Date
    
    init(from connection: SSHMonitorConnection) {
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