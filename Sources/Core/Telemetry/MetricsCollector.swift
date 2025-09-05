// Sources/Core/Telemetry/MetricsCollector.swift
// Task: Metrics Collection System Implementation
// This file handles collection of various app metrics

import Foundation
import OSLog
#if os(iOS)
import UIKit
import Combine

/// Metrics collector for gathering app performance and usage data
@MainActor
public final class MetricsCollector: ObservableObject, @unchecked Sendable {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.telemetry", category: "Metrics")
    private var metricsTimer: Timer?
    private var collectionInterval: TimeInterval = 60.0 // Default 1 minute
    
    // Metric storage
    private var performanceMetrics: [String: Double] = [:]
    private var systemMetrics: [String: Double] = [:]
    private var customMetrics: [String: Double] = [:]
    
    // Metric aggregators
    private var aggregators: [String: MetricAggregator] = [:]
    
    // Collection callbacks
    private var collectionCallbacks: [(MetricsSnapshot) -> Void] = []
    
    /// Shared instance
    public static let shared = MetricsCollector()
    
    public init() {
        setupDefaultAggregators()
        startCollectionTimer()
    }
    
    // MARK: - Public Methods
    
    /// Start collecting metrics
    public func startCollecting(interval: TimeInterval = 60.0) {
        Task { @MainActor in
            self.collectionInterval = interval
            self.startCollectionTimer()
        }
        
        logger.info("Started metrics collection with interval: \(interval)s")
    }
    
    /// Stop collecting metrics
    public func stopCollecting() {
        Task { @MainActor in
            self.metricsTimer?.invalidate()
            self.metricsTimer = nil
        }
        
        logger.info("Stopped metrics collection")
    }
    
    /// Record a performance metric
    public func recordPerformanceMetric(name: String, value: Double, unit: String = "ms") {
        Task { @MainActor in
            self.performanceMetrics[name] = value
            
            // Update aggregator if exists
            if let aggregator = self.aggregators[name] {
                aggregator.addValue(value)
            }
        }
        
        logger.debug("Recorded performance metric: \(name) = \(value)\(unit)")
    }
    
    /// Record a system metric
    public func recordSystemMetric(name: String, value: Double) {
        Task { @MainActor in
            self.systemMetrics[name] = value
        }
    }
    
    /// Record a custom metric
    public func recordCustomMetric(name: String, value: Double) {
        Task { @MainActor in
            self.customMetrics[name] = value
        }
    }
    
    /// Start timing an operation
    public func startTiming(operation: String) -> TimingToken {
        TimingToken(operation: operation, startTime: Date())
    }
    
    /// End timing and record the metric
    public func endTiming(_ token: TimingToken) {
        let duration = Date().timeIntervalSince(token.startTime) * 1000 // Convert to milliseconds
        recordPerformanceMetric(name: token.operation, value: duration)
    }
    
    /// Add a metric aggregator
    public func addAggregator(for metric: String, type: AggregationType = .average) {
        Task { @MainActor in
            self.aggregators[metric] = MetricAggregator(type: type)
        }
    }
    
    /// Get current metrics snapshot
    @MainActor
    public func getCurrentSnapshot() -> MetricsSnapshot {
        MetricsSnapshot(
            timestamp: Date(),
            performanceMetrics: performanceMetrics,
            systemMetrics: collectSystemMetrics(),
            customMetrics: customMetrics,
            aggregatedMetrics: getAggregatedMetrics()
        )
    }
    
    /// Add collection callback
    public func addCollectionCallback(_ callback: @escaping (MetricsSnapshot) -> Void) {
        Task { @MainActor in
            self.collectionCallbacks.append(callback)
        }
    }
    
    /// Collect memory metrics
    public func collectMemoryMetrics() -> TelemetryMemoryMetrics {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        let memoryUsage = result == KERN_SUCCESS ? Double(info.resident_size) / 1024.0 / 1024.0 : 0.0
        
        return TelemetryMemoryMetrics(
            usedMemory: memoryUsage,
            availableMemory: Double(Foundation.ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0,
            memoryPressure: getMemoryPressure()
        )
    }
    
    /// Collect CPU metrics
    public func collectCPUMetrics() -> TelemetryCPUMetrics {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        _ = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        let cpuUsage = getCPUUsage()
        
        return TelemetryCPUMetrics(
            usage: cpuUsage,
            systemTime: Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1_000_000,
            userTime: Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1_000_000,
            processCount: Foundation.ProcessInfo.processInfo.activeProcessorCount
        )
    }
    
    /// Collect network metrics
    public func collectNetworkMetrics() -> TelemetryNetworkMetrics {
        // This would integrate with network monitoring
        return TelemetryNetworkMetrics(
            bytesReceived: 0,
            bytesSent: 0,
            packetsReceived: 0,
            packetsSent: 0,
            errors: 0,
            latency: 0
        )
    }
    
    /// Collect battery metrics
    @MainActor
    public func collectBatteryMetrics() -> BatteryMetrics {
        // Since we're already on MainActor, we can directly access UIDevice
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        
        return BatteryMetrics(
            level: batteryLevel,
            state: batteryState,
            isLowPowerMode: Foundation.ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
    
    /// Export metrics for external use
    @MainActor
    public func exportMetrics() -> MetricsExport {
        MetricsExport(
            exportDate: Date(),
            counters: [:],  // TODO: Implement counter tracking
            timers: [:],   // TODO: Implement timer tracking
            gauges: [:]    // TODO: Implement gauge tracking
        )
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultAggregators() {
        // Setup default aggregators for common metrics
        addAggregator(for: "app_launch_time", type: .average)
        addAggregator(for: "view_load_time", type: .average)
        addAggregator(for: "api_response_time", type: .average)
        addAggregator(for: "ssh_connection_time", type: .average)
        addAggregator(for: "memory_usage", type: .average)
        addAggregator(for: "cpu_usage", type: .average)
    }
    
    private func startCollectionTimer() {
        metricsTimer?.invalidate()
        
        metricsTimer = Timer.scheduledTimer(withTimeInterval: collectionInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.collectAndNotify()
            }
        }
    }
    
    @MainActor
    private func collectAndNotify() {
        let snapshot = getCurrentSnapshot()
        
        for callback in collectionCallbacks {
            callback(snapshot)
        }
    }
    
    private func collectSystemMetrics() -> [String: Double] {
        var metrics = systemMetrics
        
        // Add current system metrics
        let memoryMetrics = collectMemoryMetrics()
        metrics["memory_used_mb"] = memoryMetrics.usedMemory
        metrics["memory_available_mb"] = memoryMetrics.availableMemory
        
        let cpuMetrics = collectCPUMetrics()
        metrics["cpu_usage_percent"] = cpuMetrics.usage
        metrics["cpu_system_time"] = cpuMetrics.systemTime
        metrics["cpu_user_time"] = cpuMetrics.userTime
        
        let batteryMetrics = collectBatteryMetrics()
        metrics["battery_level"] = Double(batteryMetrics.level)
        metrics["battery_low_power"] = batteryMetrics.isLowPowerMode ? 1.0 : 0.0
        
        return metrics
    }
    
    private func getAggregatedMetrics() -> [String: AggregatedMetric] {
        var aggregated: [String: AggregatedMetric] = [:]
        
        for (name, aggregator) in aggregators {
            aggregated[name] = aggregator.getAggregatedMetric()
        }
        
        return aggregated
    }
    
    private func getMemoryPressure() -> Double {
        let memoryUsage = collectMemoryMetrics().usedMemory
        let totalMemory = Double(Foundation.ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
        return (memoryUsage / totalMemory) * 100.0
    }
    
    private func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                        PROCESSOR_CPU_LOAD_INFO,
                                        &numCpus,
                                        &cpuInfo,
                                        &numCpuInfo)
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        var totalUsage = 0.0
        let cpuLoadInfo = cpuInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(numCpus)) { ptr in
            return ptr
        }
        
        for i in 0..<Int(numCpus) {
            let cpu = cpuLoadInfo[i]
            let userTime = Double(cpu.cpu_ticks.0)
            let systemTime = Double(cpu.cpu_ticks.1)
            let idleTime = Double(cpu.cpu_ticks.2)
            let niceTime = Double(cpu.cpu_ticks.3)
            
            let total = userTime + systemTime + idleTime + niceTime
            if total > 0 {
                totalUsage += ((userTime + systemTime) / total) * 100.0
            }
        }
        
        return totalUsage / Double(numCpus)
    }
}

// MARK: - Supporting Types

/// Token for timing operations
public struct TimingToken {
    let operation: String
    let startTime: Date
}

/// Metrics snapshot
public struct MetricsSnapshot: Sendable {
    public let timestamp: Date
    public let performanceMetrics: [String: Double]
    public let systemMetrics: [String: Double]
    public let customMetrics: [String: Double]
    public let aggregatedMetrics: [String: AggregatedMetric]
}

/// Memory metrics for telemetry
public struct TelemetryMemoryMetrics {
    public let usedMemory: Double // MB
    public let availableMemory: Double // MB
    public let memoryPressure: Double // Percentage
}

/// CPU metrics for telemetry
public struct TelemetryCPUMetrics {
    public let usage: Double // Percentage
    public let systemTime: Double
    public let userTime: Double
    public let processCount: Int
}

/// Network metrics for telemetry
public struct TelemetryNetworkMetrics {
    public let bytesReceived: Int64
    public let bytesSent: Int64
    public let packetsReceived: Int64
    public let packetsSent: Int64
    public let errors: Int64
    public let latency: Double // ms
}

/// Battery metrics
public struct BatteryMetrics {
    public let level: Float
    public let state: UIDevice.BatteryState
    public let isLowPowerMode: Bool
}

/// Aggregation types
public enum AggregationType: Sendable {
    case average
    case sum
    case min
    case max
    case count
    case percentile(Double)
}

/// Metric aggregator
public class MetricAggregator {
    private var values: [Double] = []
    private let type: AggregationType
    private let maxValues = 1000
    
    init(type: AggregationType) {
        self.type = type
    }
    
    func addValue(_ value: Double) {
        values.append(value)
        
        // Keep only recent values
        if values.count > maxValues {
            values.removeFirst(values.count - maxValues)
        }
    }
    
    func getAggregatedMetric() -> AggregatedMetric {
        guard !values.isEmpty else {
            return AggregatedMetric(type: type, value: 0, count: 0, min: 0, max: 0)
        }
        
        let sortedValues = values.sorted()
        let count = values.count
        let sum = values.reduce(0, +)
        let min = sortedValues.first ?? 0
        let max = sortedValues.last ?? 0
        
        let value: Double
        switch type {
        case .average:
            value = sum / Double(count)
        case .sum:
            value = sum
        case .min:
            value = min
        case .max:
            value = max
        case .count:
            value = Double(count)
        case .percentile(let p):
            let index = Int(Double(count - 1) * p / 100.0)
            value = sortedValues[index]
        }
        
        return AggregatedMetric(
            type: type,
            value: value,
            count: count,
            min: min,
            max: max,
            average: sum / Double(count),
            sum: sum
        )
    }
}

/// Aggregated metric result
public struct AggregatedMetric: Sendable {
    public let type: AggregationType
    public let value: Double
    public let count: Int
    public let min: Double
    public let max: Double
    public var average: Double?
    public var sum: Double?
}

/// Metrics export data
public struct MetricsExport: Codable {
    public let exportDate: Date
    public let counters: [String: Int]
    public let timers: [String: TimeInterval]
    public let gauges: [String: Double]
    
    public init(
        exportDate: Date = Date(),
        counters: [String: Int] = [:],
        timers: [String: TimeInterval] = [:],
        gauges: [String: Double] = [:]
    ) {
        self.exportDate = exportDate
        self.counters = counters
        self.timers = timers
        self.gauges = gauges
    }
}
#endif // os(iOS)
