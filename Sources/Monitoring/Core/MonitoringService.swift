//
//  MonitoringService.swift
//  ClaudeCode
//
//  Core monitoring service that orchestrates all monitoring components
//

import Foundation
import os.log
import Combine

// MARK: - Monitoring Service Protocol

public protocol MonitoringServiceProtocol {
    func configure()
    func startSession()
    func endSession()
    func trackEvent(_ event: MonitoringEvent)
    func trackError(_ error: MonitoringError)
    func trackPerformance(_ metric: PerformanceMetric)
    func trackUserAction(_ action: UserAction)
    func setUserProperty(_ property: UserProperty)
    func flush()
}

// MARK: - Core Types

public struct MonitoringEvent {
    let name: String
    let category: EventCategory
    let properties: [String: Any]
    let timestamp: Date
    let severity: EventSeverity
    
    public init(name: String, 
                category: EventCategory = .general,
                properties: [String: Any] = [:],
                timestamp: Date = Date(),
                severity: EventSeverity = .info) {
        self.name = name
        self.category = category
        self.properties = properties
        self.timestamp = timestamp
        self.severity = severity
    }
}

public enum EventCategory: String, CaseIterable {
    case general = "general"
    case authentication = "auth"
    case network = "network"
    case ui = "ui"
    case database = "database"
    case performance = "performance"
    case security = "security"
    case crash = "crash"
    case userAction = "user_action"
    case system = "system"
}

public enum EventSeverity: Int, Comparable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5
    
    public static func < (lhs: EventSeverity, rhs: EventSeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public struct MonitoringError {
    let error: Error
    let context: ErrorContext
    let stackTrace: [String]?
    let timestamp: Date
    let isFatal: Bool
    
    public init(error: Error,
                context: ErrorContext,
                stackTrace: [String]? = nil,
                timestamp: Date = Date(),
                isFatal: Bool = false) {
        self.error = error
        self.context = context
        self.stackTrace = stackTrace
        self.timestamp = timestamp
        self.isFatal = isFatal
    }
}

public struct ErrorContext {
    let file: String
    let function: String
    let line: Int
    let additionalInfo: [String: Any]
    
    public init(file: String = #file,
                function: String = #function,
                line: Int = #line,
                additionalInfo: [String: Any] = [:]) {
        self.file = file
        self.function = function
        self.line = line
        self.additionalInfo = additionalInfo
    }
}

public struct PerformanceMetric {
    let name: String
    let value: Double
    let unit: MetricUnit
    let tags: [String: String]
    let timestamp: Date
    
    public enum MetricUnit {
        case milliseconds
        case seconds
        case bytes
        case kilobytes
        case megabytes
        case percentage
        case count
        case custom(String)
    }
    
    public init(name: String,
                value: Double,
                unit: MetricUnit,
                tags: [String: String] = [:],
                timestamp: Date = Date()) {
        self.name = name
        self.value = value
        self.unit = unit
        self.tags = tags
        self.timestamp = timestamp
    }
}

public struct UserAction {
    let action: String
    let target: String?
    let value: Any?
    let metadata: [String: Any]
    let timestamp: Date
    
    public init(action: String,
                target: String? = nil,
                value: Any? = nil,
                metadata: [String: Any] = [:],
                timestamp: Date = Date()) {
        self.action = action
        self.target = target
        self.value = value
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

public struct UserProperty {
    let key: String
    let value: Any
    let persistent: Bool
    
    public init(key: String, value: Any, persistent: Bool = true) {
        self.key = key
        self.value = value
        self.persistent = persistent
    }
}

// MARK: - Main Monitoring Service

public final class MonitoringService: MonitoringServiceProtocol {
    
    // MARK: - Singleton
    
    public static let shared = MonitoringService()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.monitoring", category: "MonitoringService")
    private var providers: [MonitoringProvider] = []
    private let queue = DispatchQueue(label: "com.claudecode.monitoring.queue", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    
    // Session tracking
    private var sessionId: String?
    private var sessionStartTime: Date?
    private var isSessionActive = false
    
    // Configuration
    private var config: MonitoringConfiguration
    
    // Metrics aggregation
    private let metricsAggregator = MetricsAggregator()
    
    // MARK: - Initialization
    
    private init() {
        self.config = MonitoringConfiguration.default
        setupProviders()
        setupNotifications()
    }
    
    // MARK: - Configuration
    
    public func configure(with configuration: MonitoringConfiguration? = nil) {
        if let configuration = configuration {
            self.config = configuration
        }
        
        queue.async(flags: .barrier) {
            self.setupProviders()
            self.providers.forEach { provider in
                provider.configure(with: self.config)
            }
        }
        
        logger.info("Monitoring service configured")
    }
    
    private func setupProviders() {
        providers = [
            // Add provider instances here as they're implemented
            // SentryProvider(),
            // FirebaseProvider(),
            // MixpanelProvider(),
            // AmplitudeProvider(),
            // CustomTelemetryProvider()
        ]
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.startSession()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.endSession()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Session Management
    
    public func startSession() {
        guard !isSessionActive else { return }
        
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        isSessionActive = true
        
        let event = MonitoringEvent(
            name: "session_start",
            category: .system,
            properties: [
                "session_id": sessionId ?? "",
                "timestamp": sessionStartTime?.timeIntervalSince1970 ?? 0
            ],
            severity: .info
        )
        
        trackEvent(event)
        
        providers.forEach { $0.startSession(sessionId: sessionId ?? "") }
        
        logger.info("Session started: \(self.sessionId ?? "unknown")")
    }
    
    public func endSession() {
        guard isSessionActive else { return }
        
        let duration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        let event = MonitoringEvent(
            name: "session_end",
            category: .system,
            properties: [
                "session_id": sessionId ?? "",
                "duration": duration,
                "events_count": metricsAggregator.getSessionEventCount()
            ],
            severity: .info
        )
        
        trackEvent(event)
        
        providers.forEach { $0.endSession() }
        
        isSessionActive = false
        sessionId = nil
        sessionStartTime = nil
        
        logger.info("Session ended after \(duration) seconds")
    }
    
    // MARK: - Event Tracking
    
    public func trackEvent(_ event: MonitoringEvent) {
        guard isSessionActive || event.category == .crash else {
            logger.warning("Event tracked without active session: \(event.name)")
            startSession()
            return
        }
        
        queue.async { [weak self] in
            self?.metricsAggregator.recordEvent(event)
            
            self?.providers.forEach { provider in
                provider.trackEvent(event)
            }
            
            if event.severity >= .warning {
                self?.logger.warning("Event: \(event.name) - \(event.properties)")
            } else {
                self?.logger.debug("Event: \(event.name)")
            }
        }
    }
    
    // MARK: - Error Tracking
    
    public func trackError(_ error: MonitoringError) {
        queue.async { [weak self] in
            self?.metricsAggregator.recordError(error)
            
            self?.providers.forEach { provider in
                provider.trackError(error)
            }
            
            if error.isFatal {
                self?.logger.critical("Fatal error: \(error.error.localizedDescription)")
                self?.handleFatalError(error)
            } else {
                self?.logger.error("Error: \(error.error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Performance Tracking
    
    public func trackPerformance(_ metric: PerformanceMetric) {
        queue.async { [weak self] in
            self?.metricsAggregator.recordMetric(metric)
            
            self?.providers.forEach { provider in
                provider.trackPerformance(metric)
            }
            
            self?.logger.debug("Performance metric: \(metric.name) = \(metric.value) \(metric.unit)")
        }
    }
    
    // MARK: - User Action Tracking
    
    public func trackUserAction(_ action: UserAction) {
        queue.async { [weak self] in
            self?.metricsAggregator.recordUserAction(action)
            
            self?.providers.forEach { provider in
                provider.trackUserAction(action)
            }
            
            self?.logger.debug("User action: \(action.action) on \(action.target ?? "unknown")")
        }
    }
    
    // MARK: - User Properties
    
    public func setUserProperty(_ property: UserProperty) {
        queue.async { [weak self] in
            self?.providers.forEach { provider in
                provider.setUserProperty(property)
            }
            
            self?.logger.debug("User property set: \(property.key) = \(property.value)")
        }
    }
    
    // MARK: - Flush
    
    public func flush() {
        queue.async(flags: .barrier) { [weak self] in
            self?.providers.forEach { provider in
                provider.flush()
            }
            
            self?.metricsAggregator.flush()
            
            self?.logger.info("Monitoring data flushed")
        }
    }
    
    // MARK: - Private Methods
    
    private func handleMemoryWarning() {
        let event = MonitoringEvent(
            name: "memory_warning",
            category: .system,
            properties: [
                "available_memory": ProcessInfo.processInfo.physicalMemory,
                "active_memory": getMemoryUsage()
            ],
            severity: .warning
        )
        
        trackEvent(event)
        flush()
    }
    
    private func handleFatalError(_ error: MonitoringError) {
        // Send critical alert
        let alert = MonitoringEvent(
            name: "fatal_error_alert",
            category: .crash,
            properties: [
                "error": error.error.localizedDescription,
                "file": error.context.file,
                "function": error.context.function,
                "line": error.context.line
            ],
            severity: .critical
        )
        
        trackEvent(alert)
        flush()
        
        // Additional crash handling logic
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}

// MARK: - Monitoring Configuration

public struct MonitoringConfiguration {
    public let isEnabled: Bool
    public let environment: Environment
    public let apiKey: String?
    public let endpoint: URL?
    public let sampleRate: Double
    public let sessionTimeout: TimeInterval
    public let maxEventsPerBatch: Int
    public let flushInterval: TimeInterval
    public let enableCrashReporting: Bool
    public let enablePerformanceMonitoring: Bool
    public let enableUserAnalytics: Bool
    public let debugMode: Bool
    
    public enum Environment: String {
        case development = "development"
        case staging = "staging"
        case production = "production"
    }
    
    public static let `default` = MonitoringConfiguration(
        isEnabled: true,
        environment: .development,
        apiKey: nil,
        endpoint: nil,
        sampleRate: 1.0,
        sessionTimeout: 30 * 60, // 30 minutes
        maxEventsPerBatch: 100,
        flushInterval: 60, // 1 minute
        enableCrashReporting: true,
        enablePerformanceMonitoring: true,
        enableUserAnalytics: true,
        debugMode: true
    )
}

// MARK: - Monitoring Provider Protocol

public protocol MonitoringProvider {
    func configure(with config: MonitoringConfiguration)
    func startSession(sessionId: String)
    func endSession()
    func trackEvent(_ event: MonitoringEvent)
    func trackError(_ error: MonitoringError)
    func trackPerformance(_ metric: PerformanceMetric)
    func trackUserAction(_ action: UserAction)
    func setUserProperty(_ property: UserProperty)
    func flush()
}

// MARK: - Metrics Aggregator

private class MetricsAggregator {
    private var eventCount = 0
    private var errorCount = 0
    private var performanceMetrics: [String: [Double]] = [:]
    private let queue = DispatchQueue(label: "com.claudecode.metrics.aggregator")
    
    func recordEvent(_ event: MonitoringEvent) {
        queue.async {
            self.eventCount += 1
        }
    }
    
    func recordError(_ error: MonitoringError) {
        queue.async {
            self.errorCount += 1
        }
    }
    
    func recordMetric(_ metric: PerformanceMetric) {
        queue.async {
            if self.performanceMetrics[metric.name] == nil {
                self.performanceMetrics[metric.name] = []
            }
            self.performanceMetrics[metric.name]?.append(metric.value)
        }
    }
    
    func recordUserAction(_ action: UserAction) {
        queue.async {
            self.eventCount += 1
        }
    }
    
    func getSessionEventCount() -> Int {
        return queue.sync { eventCount }
    }
    
    func flush() {
        queue.async {
            self.eventCount = 0
            self.errorCount = 0
            self.performanceMetrics.removeAll()
        }
    }
}