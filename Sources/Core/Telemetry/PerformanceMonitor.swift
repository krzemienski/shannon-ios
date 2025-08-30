// Sources/Core/Telemetry/PerformanceMonitor.swift
// Task: Performance Monitoring System Implementation
// This file handles monitoring of app performance metrics

import Foundation
import OSLog
import UIKit
import QuartzCore

/// Performance monitoring system for tracking app responsiveness and performance
public final class PerformanceMonitor: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.telemetry", category: "Performance")
    private let performanceQueue = DispatchQueue(label: "com.claudecode.telemetry.performance", attributes: .concurrent)
    
    /// Shared instance
    public static let shared = PerformanceMonitor()
    
    // Performance trackers
    private var activeTrackers: [String: PerformanceTracker] = [:]
    private var completedTrackers: [PerformanceTracker] = []
    private let maxCompletedTrackers = 100
    
    // Frame rate monitoring
    private var displayLink: CADisplayLink?
    private var frameRateMonitor: FrameRateMonitor?
    
    // Performance observers
    private var observers: [(PerformanceReport) -> Void] = []
    
    // App launch tracking
    private let appLaunchTime = Date()
    private var timeToFirstFrame: TimeInterval?
    private var timeToInteractive: TimeInterval?
    
    private init() {
        setupFrameRateMonitoring()
        observeAppLifecycle()
    }
    
    // MARK: - Public Methods
    
    /// Start tracking a performance metric
    @discardableResult
    public func startTracking(_ operation: String, metadata: [String: Any]? = nil) -> PerformanceTracker {
        let tracker = PerformanceTracker(
            id: UUID(),
            operation: operation,
            startTime: Date(),
            metadata: metadata
        )
        
        performanceQueue.async(flags: .barrier) { [weak self] in
            self?.activeTrackers[operation] = tracker
        }
        
        logger.debug("Started tracking: \(operation)")
        return tracker
    }
    
    /// End tracking a performance metric
    public func endTracking(_ operation: String, success: Bool = true, error: Error? = nil) {
        performanceQueue.async(flags: .barrier) { [weak self] in
            guard let tracker = self?.activeTrackers.removeValue(forKey: operation) else {
                self?.logger.warning("No active tracker for operation: \(operation)")
                return
            }
            
            tracker.endTime = Date()
            tracker.success = success
            tracker.error = error
            
            self?.recordCompletedTracker(tracker)
            self?.notifyObservers(tracker)
            
            self?.logger.debug("Ended tracking: \(operation), duration: \(tracker.duration ?? 0)ms")
        }
    }
    
    /// Track a synchronous operation
    public func track<T>(_ operation: String, metadata: [String: Any]? = nil, block: () throws -> T) rethrows -> T {
        let tracker = startTracking(operation, metadata: metadata)
        
        do {
            let result = try block()
            endTracking(operation, success: true)
            return result
        } catch {
            endTracking(operation, success: false, error: error)
            throw error
        }
    }
    
    /// Track an asynchronous operation
    public func trackAsync<T>(_ operation: String, metadata: [String: Any]? = nil, block: () async throws -> T) async rethrows -> T {
        let tracker = startTracking(operation, metadata: metadata)
        
        do {
            let result = try await block()
            endTracking(operation, success: true)
            return result
        } catch {
            endTracking(operation, success: false, error: error)
            throw error
        }
    }
    
    /// Mark app as interactive
    public func markInteractive() {
        if timeToInteractive == nil {
            timeToInteractive = Date().timeIntervalSince(appLaunchTime)
            logger.info("App became interactive after \(self.timeToInteractive ?? 0) seconds")
        }
    }
    
    /// Get current frame rate
    public var currentFrameRate: Double {
        frameRateMonitor?.currentFPS ?? 0
    }
    
    /// Get performance report
    public func getPerformanceReport() -> PerformanceReport {
        performanceQueue.sync {
            PerformanceReport(
                appLaunchTime: appLaunchTime,
                timeToFirstFrame: timeToFirstFrame,
                timeToInteractive: timeToInteractive,
                currentFrameRate: currentFrameRate,
                averageFrameRate: frameRateMonitor?.averageFPS ?? 0,
                activeTrackers: Array(activeTrackers.values),
                recentTrackers: Array(completedTrackers.suffix(20)),
                memoryUsage: getMemoryUsage(),
                cpuUsage: getCPUUsage()
            )
        }
    }
    
    /// Add performance observer
    public func addObserver(_ observer: @escaping (PerformanceReport) -> Void) {
        performanceQueue.async(flags: .barrier) { [weak self] in
            self?.observers.append(observer)
        }
    }
    
    /// Monitor view controller loading
    public func monitorViewController(_ viewController: UIViewController) {
        let className = String(describing: type(of: viewController))
        let tracker = startTracking("vc_load_\(className)")
        
        // Swizzle viewDidAppear to end tracking
        DispatchQueue.main.async { [weak self, weak viewController] in
            guard let viewController = viewController else { return }
            
            // Use method swizzling or observe view lifecycle
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("UIViewControllerDidAppearNotification"),
                object: viewController,
                queue: .main
            ) { [weak self] _ in
                self?.endTracking("vc_load_\(className)")
                if let token = token {
                    NotificationCenter.default.removeObserver(token)
                }
            }
        }
    }
    
    /// Monitor network request
    public func monitorNetworkRequest(url: URL, method: String) -> NetworkRequestMonitor {
        let monitor = NetworkRequestMonitor(url: url, method: method)
        let operation = "network_\(method)_\(url.host ?? "")"
        
        startTracking(operation, metadata: [
            "url": url.absoluteString,
            "method": method
        ])
        
        monitor.onComplete = { [weak self] success, statusCode, error in
            self?.endTracking(operation, success: success, error: error)
        }
        
        return monitor
    }
    
    /// Monitor SSH operation
    public func monitorSSHOperation(_ operation: String, host: String, port: Int) -> SSHOperationMonitor {
        let monitor = SSHOperationMonitor(operation: operation, host: host, port: port)
        let trackingKey = "ssh_\(operation)_\(host)"
        
        startTracking(trackingKey, metadata: [
            "operation": operation,
            "host": host,
            "port": port
        ])
        
        monitor.onComplete = { [weak self] success, error in
            self?.endTracking(trackingKey, success: success, error: error)
        }
        
        return monitor
    }
    
    // MARK: - Private Methods
    
    private func setupFrameRateMonitoring() {
        frameRateMonitor = FrameRateMonitor()
        
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func displayLinkTick(_ displayLink: CADisplayLink) {
        frameRateMonitor?.tick(displayLink)
    }
    
    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        if timeToFirstFrame == nil {
            timeToFirstFrame = Date().timeIntervalSince(appLaunchTime)
            logger.info("First frame rendered after \(self.timeToFirstFrame ?? 0) seconds")
        }
        
        displayLink?.isPaused = false
    }
    
    @objc private func appWillResignActive() {
        displayLink?.isPaused = true
    }
    
    @objc private func appDidReceiveMemoryWarning() {
        logger.warning("Received memory warning")
        
        // Clear old completed trackers
        performanceQueue.async(flags: .barrier) { [weak self] in
            if let self = self, self.completedTrackers.count > 50 {
                self.completedTrackers.removeFirst(self.completedTrackers.count - 50)
            }
        }
    }
    
    private func recordCompletedTracker(_ tracker: PerformanceTracker) {
        completedTrackers.append(tracker)
        
        if completedTrackers.count > maxCompletedTrackers {
            completedTrackers.removeFirst(completedTrackers.count - maxCompletedTrackers)
        }
        
        // Record to metrics collector
        if let duration = tracker.duration {
            Task { @MainActor in
                MetricsCollector.shared.recordPerformanceMetric(
                    name: tracker.operation,
                    value: duration
                )
            }
        }
    }
    
    private func notifyObservers(_ tracker: PerformanceTracker) {
        let report = getPerformanceReport()
        observers.forEach { $0(report) }
    }
    
    private func getMemoryUsage() -> Double {
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
        
        return result == KERN_SUCCESS ? Double(info.resident_size) / 1024.0 / 1024.0 : 0.0
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
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo))
        }
        
        return 0.0 // Simplified for now
    }
}

// MARK: - Supporting Types

/// Performance tracker for individual operations
public final class PerformanceTracker: ObservableObject, @unchecked Sendable {
    public let id: UUID
    public let operation: String
    public let startTime: Date
    public var endTime: Date?
    public var success: Bool?
    public var error: Error?
    public let metadata: [String: Any]?
    
    // Additional properties for PerformanceSection
    @Published public var overallScore: Double = 85.0
    @Published public var responseTime: Double = 0.150
    @Published public var throughput: Double = 45.0
    @Published public var errorRate: Double = 0.5
    @Published public var cpuUsage: Double = 35.0
    @Published public var memoryUsage: Double = 512.0
    @Published public var activeSpans: [PerformanceSpan] = []
    @Published public var bottlenecks: [PerformanceBottleneck] = []
    @Published public var measurements: [PerformanceMeasurement] = []
    
    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime) * 1000 // Convert to milliseconds
    }
    
    public var isActive: Bool {
        endTime == nil
    }
    
    init(id: UUID, operation: String, startTime: Date, metadata: [String: Any]? = nil) {
        self.id = id
        self.operation = operation
        self.startTime = startTime
        self.metadata = metadata
    }
}

// Performance types (PerformanceSpan, PerformanceBottleneck, PerformanceMeasurement) 
// are defined in Sources/Models/ViewModels.swift

/// Frame rate monitor
class FrameRateMonitor {
    private var frameCount = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var fps: Double = 0
    private var fpsHistory: [Double] = []
    private let maxHistory = 60
    
    var currentFPS: Double { fps }
    
    var averageFPS: Double {
        guard !fpsHistory.isEmpty else { return 0 }
        return fpsHistory.reduce(0, +) / Double(fpsHistory.count)
    }
    
    func tick(_ displayLink: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }
        
        frameCount += 1
        let elapsed = displayLink.timestamp - lastTimestamp
        
        if elapsed >= 1.0 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            lastTimestamp = displayLink.timestamp
            
            fpsHistory.append(fps)
            if fpsHistory.count > maxHistory {
                fpsHistory.removeFirst()
            }
        }
    }
}

/// Performance report
public struct PerformanceReport {
    public let appLaunchTime: Date
    public let timeToFirstFrame: TimeInterval?
    public let timeToInteractive: TimeInterval?
    public let currentFrameRate: Double
    public let averageFrameRate: Double
    public let activeTrackers: [PerformanceTracker]
    public let recentTrackers: [PerformanceTracker]
    public let memoryUsage: Double
    public let cpuUsage: Double
}

/// Network request monitor
public class NetworkRequestMonitor {
    public let url: URL
    public let method: String
    public let startTime = Date()
    public var onComplete: ((Bool, Int?, Error?) -> Void)?
    
    init(url: URL, method: String) {
        self.url = url
        self.method = method
    }
    
    public func complete(success: Bool, statusCode: Int? = nil, error: Error? = nil) {
        onComplete?(success, statusCode, error)
    }
}

/// SSH operation monitor
public class SSHOperationMonitor {
    public let operation: String
    public let host: String
    public let port: Int
    public let startTime = Date()
    public var onComplete: ((Bool, Error?) -> Void)?
    
    init(operation: String, host: String, port: Int) {
        self.operation = operation
        self.host = host
        self.port = port
    }
    
    public func complete(success: Bool, error: Error? = nil) {
        onComplete?(success, error)
    }
}