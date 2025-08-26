//
//  PerformanceMonitor.swift
//  ClaudeCode
//
//  Application Performance Monitoring with real-time metrics
//

import Foundation
import UIKit
import QuartzCore
import os.log
import Combine

// MARK: - Performance Monitor

public final class PerformanceMonitor {
    
    // MARK: - Singleton
    
    public static let shared = PerformanceMonitor()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.monitoring", category: "Performance")
    private let queue = DispatchQueue(label: "com.claudecode.performance.monitor", qos: .utility, attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    
    // Tracking state
    private var isMonitoring = false
    private var displayLink: CADisplayLink?
    private var cpuTimer: Timer?
    private var memoryTimer: Timer?
    
    // Metrics storage
    private let metricsStore = PerformanceMetricsStore()
    
    // Alert thresholds
    private var thresholds = PerformanceThresholds.default
    
    // Transaction tracking
    private var activeTransactions: [String: Transaction] = [:]
    private let transactionQueue = DispatchQueue(label: "com.claudecode.performance.transactions", attributes: .concurrent)
    
    // App lifecycle metrics
    private var appLaunchStartTime: CFAbsoluteTime?
    private var coldStartTime: TimeInterval?
    private var warmStartTime: TimeInterval?
    
    // MARK: - Initialization
    
    private init() {
        setupNotifications()
        recordAppLaunchStart()
    }
    
    // MARK: - Public API
    
    public func startMonitoring(with config: PerformanceConfiguration = .default) {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        thresholds = config.thresholds
        
        startFPSMonitoring()
        startCPUMonitoring(interval: config.cpuSamplingInterval)
        startMemoryMonitoring(interval: config.memorySamplingInterval)
        startNetworkMonitoring()
        
        logger.info("Performance monitoring started")
    }
    
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        displayLink?.invalidate()
        displayLink = nil
        
        cpuTimer?.invalidate()
        cpuTimer = nil
        
        memoryTimer?.invalidate()
        memoryTimer = nil
        
        logger.info("Performance monitoring stopped")
    }
    
    // MARK: - Transaction API
    
    @discardableResult
    public func startTransaction(name: String, 
                                operation: String? = nil,
                                tags: [String: String] = [:]) -> Transaction {
        let transaction = Transaction(
            id: UUID().uuidString,
            name: name,
            operation: operation,
            startTime: CACurrentMediaTime(),
            tags: tags
        )
        
        transactionQueue.async(flags: .barrier) {
            self.activeTransactions[transaction.id] = transaction
        }
        
        logger.debug("Transaction started: \(name)")
        return transaction
    }
    
    public func finishTransaction(_ transaction: Transaction) {
        let endTime = CACurrentMediaTime()
        let duration = (endTime - transaction.startTime) * 1000 // Convert to milliseconds
        
        transactionQueue.async(flags: .barrier) {
            self.activeTransactions.removeValue(forKey: transaction.id)
        }
        
        let metric = PerformanceMetric(
            name: "transaction.\(transaction.name)",
            value: duration,
            unit: .milliseconds,
            tags: transaction.tags
        )
        
        MonitoringService.shared.trackPerformance(metric)
        
        // Check threshold
        checkTransactionThreshold(name: transaction.name, duration: duration)
        
        logger.debug("Transaction finished: \(transaction.name) - \(duration)ms")
    }
    
    // MARK: - App Launch Metrics
    
    private func recordAppLaunchStart() {
        appLaunchStartTime = CFAbsoluteTimeGetCurrent()
    }
    
    public func recordAppLaunchEnd(isColdStart: Bool = true) {
        guard let startTime = appLaunchStartTime else { return }
        
        let launchTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // ms
        
        if isColdStart {
            coldStartTime = launchTime
            recordMetric("app.launch.cold", value: launchTime, unit: .milliseconds)
        } else {
            warmStartTime = launchTime
            recordMetric("app.launch.warm", value: launchTime, unit: .milliseconds)
        }
        
        // Check launch time threshold
        if launchTime > thresholds.maxAppLaunchTime {
            triggerAlert(.appLaunchSlow, value: launchTime)
        }
        
        logger.info("App launch recorded: \(launchTime)ms (\(isColdStart ? "cold" : "warm") start)")
    }
    
    // MARK: - FPS Monitoring
    
    private func startFPSMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateFPS(_ displayLink: CADisplayLink) {
        let fps = 1.0 / (displayLink.targetTimestamp - displayLink.timestamp)
        
        metricsStore.recordFPS(fps)
        
        if fps < Double(thresholds.minFPS) {
            triggerAlert(.lowFPS, value: fps)
        }
    }
    
    // MARK: - CPU Monitoring
    
    private func startCPUMonitoring(interval: TimeInterval) {
        cpuTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.measureCPUUsage()
        }
    }
    
    private func measureCPUUsage() {
        let usage = getCurrentCPUUsage()
        
        metricsStore.recordCPUUsage(usage)
        recordMetric("device.cpu.usage", value: usage, unit: .percentage)
        
        if usage > thresholds.maxCPUUsage {
            triggerAlert(.highCPU, value: usage)
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usage = Double(info.resident_size) / Double(ProcessInfo.processInfo.physicalMemory) * 100.0
            return min(usage, 100.0)
        }
        
        return 0.0
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring(interval: TimeInterval) {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.measureMemoryUsage()
        }
    }
    
    private func measureMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        
        metricsStore.recordMemoryUsage(usage)
        recordMetric("device.memory.usage", value: Double(usage), unit: .megabytes)
        
        let usagePercent = Double(usage) / Double(ProcessInfo.processInfo.physicalMemory / 1024 / 1024) * 100.0
        if usagePercent > thresholds.maxMemoryUsage {
            triggerAlert(.highMemory, value: usagePercent)
        }
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size / 1024 / 1024 : 0 // Convert to MB
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        // Network monitoring will be handled by NetworkPerformanceMonitor
        NetworkPerformanceMonitor.shared.startMonitoring()
    }
    
    // MARK: - Screen Rendering
    
    public func trackScreenRender(screenName: String, startTime: CFAbsoluteTime) {
        let renderTime = (CACurrentMediaTime() - startTime) * 1000 // ms
        
        recordMetric("screen.render.\(screenName)", value: renderTime, unit: .milliseconds)
        
        if renderTime > thresholds.maxScreenRenderTime {
            triggerAlert(.slowScreenRender, value: renderTime, context: ["screen": screenName])
        }
    }
    
    // MARK: - Alerts
    
    private func triggerAlert(_ type: AlertType, value: Double, context: [String: Any] = [:]) {
        let alert = PerformanceAlert(
            type: type,
            value: value,
            threshold: getThresholdForAlert(type),
            context: context,
            timestamp: Date()
        )
        
        processAlert(alert)
    }
    
    private func getThresholdForAlert(_ type: AlertType) -> Double {
        switch type {
        case .highCPU:
            return thresholds.maxCPUUsage
        case .highMemory:
            return thresholds.maxMemoryUsage
        case .lowFPS:
            return Double(thresholds.minFPS)
        case .slowScreenRender:
            return thresholds.maxScreenRenderTime
        case .slowNetwork:
            return thresholds.maxNetworkLatency
        case .appLaunchSlow:
            return thresholds.maxAppLaunchTime
        case .transactionSlow:
            return thresholds.maxTransactionDuration
        case .diskSpaceLow:
            return thresholds.minDiskSpace
        }
    }
    
    private func processAlert(_ alert: PerformanceAlert) {
        // Log alert
        logger.warning("Performance Alert: \(alert.type) - Value: \(alert.value), Threshold: \(alert.threshold)")
        
        // Send to monitoring service
        let event = MonitoringEvent(
            name: "performance.alert",
            category: .performance,
            properties: [
                "type": alert.type.rawValue,
                "value": alert.value,
                "threshold": alert.threshold,
                "context": alert.context
            ],
            severity: .warning
        )
        
        MonitoringService.shared.trackEvent(event)
        
        // Execute automated response if configured
        executeAutomatedResponse(for: alert)
    }
    
    private func executeAutomatedResponse(for alert: PerformanceAlert) {
        switch alert.type {
        case .highMemory:
            // Clear caches
            URLCache.shared.removeAllCachedResponses()
            NotificationCenter.default.post(name: .clearMemoryCaches, object: nil)
            
        case .lowFPS:
            // Reduce animation complexity
            NotificationCenter.default.post(name: .reduceAnimations, object: nil)
            
        case .diskSpaceLow:
            // Clear temporary files
            clearTemporaryFiles()
            
        default:
            break
        }
    }
    
    // MARK: - Helper Methods
    
    private func recordMetric(_ name: String, value: Double, unit: PerformanceMetric.MetricUnit) {
        let metric = PerformanceMetric(
            name: name,
            value: value,
            unit: unit
        )
        
        MonitoringService.shared.trackPerformance(metric)
    }
    
    private func checkTransactionThreshold(name: String, duration: Double) {
        if duration > thresholds.maxTransactionDuration {
            triggerAlert(.transactionSlow, value: duration, context: ["transaction": name])
        }
    }
    
    private func clearTemporaryFiles() {
        let tmpDirectory = FileManager.default.temporaryDirectory
        do {
            let tmpContents = try FileManager.default.contentsOfDirectory(at: tmpDirectory, includingPropertiesForKeys: nil)
            for file in tmpContents {
                try FileManager.default.removeItem(at: file)
            }
        } catch {
            logger.error("Failed to clear temporary files: \(error)")
        }
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.didFinishLaunchingNotification)
            .sink { [weak self] _ in
                self?.recordAppLaunchEnd(isColdStart: true)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.recordAppLaunchEnd(isColdStart: false)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Types

public struct Transaction {
    let id: String
    let name: String
    let operation: String?
    let startTime: CFAbsoluteTime
    let tags: [String: String]
}

public struct PerformanceConfiguration {
    let cpuSamplingInterval: TimeInterval
    let memorySamplingInterval: TimeInterval
    let thresholds: PerformanceThresholds
    
    public static let `default` = PerformanceConfiguration(
        cpuSamplingInterval: 5.0,
        memorySamplingInterval: 10.0,
        thresholds: .default
    )
}

public struct PerformanceThresholds {
    let maxCPUUsage: Double // Percentage
    let maxMemoryUsage: Double // Percentage
    let minFPS: Int
    let maxScreenRenderTime: Double // Milliseconds
    let maxNetworkLatency: Double // Milliseconds
    let maxAppLaunchTime: Double // Milliseconds
    let maxTransactionDuration: Double // Milliseconds
    let minDiskSpace: Double // MB
    
    public static let `default` = PerformanceThresholds(
        maxCPUUsage: 80.0,
        maxMemoryUsage: 75.0,
        minFPS: 30,
        maxScreenRenderTime: 300.0,
        maxNetworkLatency: 3000.0,
        maxAppLaunchTime: 2000.0,
        maxTransactionDuration: 5000.0,
        minDiskSpace: 100.0
    )
}

public struct PerformanceAlert {
    let type: AlertType
    let value: Double
    let threshold: Double
    let context: [String: Any]
    let timestamp: Date
}

public enum AlertType: String {
    case highCPU = "high_cpu"
    case highMemory = "high_memory"
    case lowFPS = "low_fps"
    case slowScreenRender = "slow_screen_render"
    case slowNetwork = "slow_network"
    case appLaunchSlow = "app_launch_slow"
    case transactionSlow = "transaction_slow"
    case diskSpaceLow = "disk_space_low"
}

// MARK: - Metrics Store

private class PerformanceMetricsStore {
    private var fpsValues: [Double] = []
    private var cpuValues: [Double] = []
    private var memoryValues: [UInt64] = []
    private let maxSamples = 100
    private let queue = DispatchQueue(label: "com.claudecode.metrics.store")
    
    func recordFPS(_ fps: Double) {
        queue.async {
            self.fpsValues.append(fps)
            if self.fpsValues.count > self.maxSamples {
                self.fpsValues.removeFirst()
            }
        }
    }
    
    func recordCPUUsage(_ usage: Double) {
        queue.async {
            self.cpuValues.append(usage)
            if self.cpuValues.count > self.maxSamples {
                self.cpuValues.removeFirst()
            }
        }
    }
    
    func recordMemoryUsage(_ usage: UInt64) {
        queue.async {
            self.memoryValues.append(usage)
            if self.memoryValues.count > self.maxSamples {
                self.memoryValues.removeFirst()
            }
        }
    }
    
    func getAverageFPS() -> Double {
        return queue.sync {
            guard !fpsValues.isEmpty else { return 60.0 }
            return fpsValues.reduce(0, +) / Double(fpsValues.count)
        }
    }
    
    func getAverageCPU() -> Double {
        return queue.sync {
            guard !cpuValues.isEmpty else { return 0.0 }
            return cpuValues.reduce(0, +) / Double(cpuValues.count)
        }
    }
    
    func getAverageMemory() -> UInt64 {
        return queue.sync {
            guard !memoryValues.isEmpty else { return 0 }
            return memoryValues.reduce(0, +) / UInt64(memoryValues.count)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let clearMemoryCaches = Notification.Name("com.claudecode.clearMemoryCaches")
    static let reduceAnimations = Notification.Name("com.claudecode.reduceAnimations")
}