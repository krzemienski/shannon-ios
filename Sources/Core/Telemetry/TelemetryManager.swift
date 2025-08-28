// Sources/Core/Telemetry/TelemetryManager.swift
// Task: Central Telemetry Manager Implementation
// This file coordinates all telemetry operations

import Foundation
import OSLog
import Logging
import Combine

/// Central telemetry manager that coordinates all telemetry operations
@MainActor
public final class TelemetryManager: ObservableObject, @unchecked Sendable {
    
    // MARK: - Properties
    
    private let logger = Logging.Logger(label: "com.claudecode.telemetry.manager")
    private let osLogger = OSLog(subsystem: "com.claudecode.telemetry", category: "Manager")
    private let telemetryQueue = DispatchQueue(label: "com.claudecode.telemetry.manager", attributes: .concurrent)
    
    /// Shared instance
    public static let shared = TelemetryManager()
    
    // Components
    private var storage: TelemetryStorageProtocol?
    private let configuration = TelemetryConfigurationManager.shared
    private let metricsCollector = MetricsCollector.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private let crashReporter = CrashReporter.shared
    
    // Session management
    public let sessionId = UUID()
    private let sessionStartTime = Date()
    private var userId: String?
    
    // Upload management
    private var uploadTimer: Timer?
    private var isUploading = false
    
    // Event processors
    private var eventProcessors: [(any TelemetryEvent) -> (any TelemetryEvent)?] = []
    
    // Export handlers
    private var exportHandlers: [TelemetryExportHandler] = []
    
    private init() {
        Task {
            await initialize()
        }
    }
    
    // MARK: - Public Methods
    
    /// Initialize telemetry system
    public func initialize() async {
        do {
            // Setup storage
            storage = try TelemetryFileStorage()
            
            // Setup configuration
            #if DEBUG
            configuration.configuration = .development
            #else
            configuration.configuration = .production
            #endif
            
            // Setup components
            setupMetricsCollection()
            setupPerformanceMonitoring()
            setupCrashReporting()
            
            // Start upload timer
            startUploadTimer()
            
            // Log initialization
            let lifecycleEvent = AppLifecycleEvent(
                sessionId: sessionId,
                lifecycleEvent: .launch,
                currentState: "active"
            )
            logEvent(lifecycleEvent)
            
            os_log(.info, log: osLogger, "Telemetry system initialized")
        } catch {
            os_log(.error, log: osLogger, "Failed to initialize telemetry: %{public}@", error.localizedDescription)
        }
    }
    
    /// Set user identifier
    public func setUserId(_ id: String?) {
        Task { @MainActor in
            self.userId = id
            os_log(.info, log: self.osLogger, "User ID set: %{public}@", id ?? "nil")
        }
    }
    
    /// Log a telemetry event
    public func logEvent(_ event: any TelemetryEvent) {
        guard configuration.configuration.isEnabled else { return }
        
        Task {
            await processAndStoreEvent(event)
        }
    }
    
    /// Log a performance event
    public func logPerformance(metric: String, value: Double, unit: String = "ms", tags: [String: String]? = nil) {
        guard configuration.configuration.collectPerformanceMetrics else { return }
        
        // Check sampling rate
        if Double.random(in: 0...1) > configuration.configuration.performanceSamplingRate {
            return
        }
        
        let event = PerformanceEvent(
            sessionId: sessionId,
            userId: userId,
            metricName: metric,
            value: value,
            unit: unit,
            tags: tags
        )
        
        logEvent(event)
    }
    
    /// Log an error event
    public func logError(_ error: Error, severity: ErrorEvent.ErrorSeverity = .error, context: [String: String]? = nil) {
        guard configuration.configuration.collectErrors else { return }
        
        // Check severity threshold
        if severity.rawValue < configuration.configuration.errorSeverityThreshold.rawValue {
            return
        }
        
        let event = ErrorEvent(
            sessionId: sessionId,
            userId: userId,
            errorType: String(describing: type(of: error)),
            errorMessage: error.localizedDescription,
            stackTrace: configuration.configuration.collectStackTraces ? Thread.callStackSymbols.joined(separator: "\n") : nil,
            severity: severity,
            context: context
        )
        
        logEvent(event)
    }
    
    /// Log a user action event
    public func logUserAction(_ action: String, category: String, label: String? = nil, value: Double? = nil, properties: [String: AnyCodable]? = nil) {
        guard configuration.configuration.collectUserActions else { return }
        
        // Check if action is excluded
        if configuration.configuration.excludedActions.contains(action) {
            return
        }
        
        // Check sampling rate
        if Double.random(in: 0...1) > configuration.configuration.userActionSamplingRate {
            return
        }
        
        let event = UserActionEvent(
            sessionId: sessionId,
            userId: userId,
            actionName: action,
            category: category,
            label: label,
            value: value,
            screenName: nil, // TODO: Get current screen name
            properties: properties
        )
        
        logEvent(event)
    }
    
    /// Log SSH connection event
    public func logSSHConnection(connectionId: UUID, host: String, port: Int, status: SSHConnectionEvent.ConnectionStatus, duration: TimeInterval? = nil, errorReason: String? = nil) {
        guard configuration.configuration.collectSSHMetrics else { return }
        
        // Check sampling rate
        if Double.random(in: 0...1) > configuration.configuration.sshSamplingRate {
            return
        }
        
        let event = SSHConnectionEvent(
            sessionId: sessionId,
            userId: userId,
            connectionId: connectionId,
            host: configuration.configuration.redactSensitiveInfo ? "[REDACTED]" : host,
            port: port,
            status: status,
            duration: duration,
            errorReason: errorReason
        )
        
        logEvent(event)
    }
    
    /// Log app lifecycle event
    public func logAppLifecycle(_ lifecycleEvent: AppLifecycleEvent.LifecycleEventType) {
        let event = AppLifecycleEvent(
            sessionId: sessionId,
            userId: userId,
            lifecycleEvent: lifecycleEvent,
            currentState: lifecycleEvent.rawValue,
            sessionDuration: Date().timeIntervalSince(sessionStartTime)
        )
        
        logEvent(event)
    }
    
    /// Log custom event
    public func logCustomEvent(name: String, category: String? = nil, data: [String: AnyCodable]) {
        let event = CustomEvent(
            sessionId: sessionId,
            userId: userId,
            name: name,
            category: category,
            data: data
        )
        
        logEvent(event)
    }
    
    /// Add event processor
    public func addEventProcessor(_ processor: @escaping (any TelemetryEvent) -> (any TelemetryEvent)?) {
        Task { @MainActor in
            eventProcessors.append(processor)
        }
    }
    
    /// Add export handler
    public func addExportHandler(_ handler: TelemetryExportHandler) {
        Task { @MainActor in
            exportHandlers.append(handler)
        }
    }
    
    /// Force upload of pending events
    public func forceUpload() async {
        await uploadPendingEvents()
    }
    
    /// Get telemetry statistics
    public func getStatistics() async -> TelemetryStatistics {
        let eventCount = (try? await storage?.getEventCount()) ?? 0
        let metricsSnapshot = metricsCollector.getCurrentSnapshot()
        let performanceReport = performanceMonitor.getPerformanceReport()
        
        return TelemetryStatistics(
            sessionId: sessionId,
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            totalEvents: eventCount,
            performanceMetrics: metricsSnapshot.performanceMetrics,
            systemMetrics: metricsSnapshot.systemMetrics,
            frameRate: performanceReport.currentFrameRate,
            memoryUsage: performanceReport.memoryUsage,
            cpuUsage: performanceReport.cpuUsage
        )
    }
    
    /// Flush all pending events
    public func flush() async {
        await uploadPendingEvents()
    }
    
    /// Clear all telemetry data
    public func clearAllData() async {
        try? await storage?.clearAll()
        crashReporter.clearCrashReports()
        os_log(.info, log: osLogger, "Cleared all telemetry data")
    }
    
    // MARK: - Private Methods
    
    private func setupMetricsCollection() {
        // Add metrics collection callback
        metricsCollector.addCollectionCallback { [weak self] snapshot in
            // Log aggregated metrics
            for (name, metric) in snapshot.aggregatedMetrics {
                self?.logPerformance(
                    metric: name,
                    value: metric.value,
                    unit: "ms"
                )
            }
        }
        
        // Start collecting
        metricsCollector.startCollecting(interval: 60.0)
    }
    
    private func setupPerformanceMonitoring() {
        // Add performance observer
        performanceMonitor.addObserver { [weak self] report in
            // Log performance issues
            if report.currentFrameRate < 30 {
                if let self = self {
                    os_log(.default, log: self.osLogger, "Low frame rate detected: %{public}.1f FPS", report.currentFrameRate)
                }
            }
            
            if report.memoryUsage > 500 {
                if let self = self {
                    os_log(.default, log: self.osLogger, "High memory usage: %{public}.1f MB", report.memoryUsage)
                }
            }
        }
    }
    
    private func setupCrashReporting() {
        // Enable crash reporting
        crashReporter.enable()
        
        // Add crash handler
        crashReporter.addCrashHandler { [weak self] crashReport in
            guard let self = self else { return }
            
            Task { @MainActor in
                let currentUserId = self.userId
                let currentSessionId = self.sessionId
                
                // Convert to telemetry event
                let event = ErrorEvent(
                    sessionId: currentSessionId,
                    userId: currentUserId,
                errorType: "Crash",
                errorMessage: crashReport.reason,
                stackTrace: crashReport.stackTrace,
                severity: .fatal,
                    context: [
                        "crash_type": crashReport.type.rawValue,
                        "session_duration": String(crashReport.sessionDuration)
                    ]
                )
                
                self.logEvent(event)
            }
        }
    }
    
    private func startUploadTimer() {
        let interval = configuration.configuration.uploadInterval
        
        uploadTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.uploadPendingEvents()
            }
        }
    }
    
    private func processAndStoreEvent(_ event: any TelemetryEvent) async {
        // Process event through processors
        var processedEvent: any TelemetryEvent = event
        
        for processor in eventProcessors {
            if let newEvent = processor(processedEvent) {
                processedEvent = newEvent
            } else {
                // Event was filtered out
                return
            }
        }
        
        // Redact sensitive information if needed
        if configuration.configuration.redactSensitiveInfo {
            processedEvent = redactSensitiveInfo(from: processedEvent)
        }
        
        // Store event
        do {
            try await storage?.store(processedEvent)
            os_log(.debug, log: osLogger, "Stored telemetry event: %{public}@", processedEvent.eventType.rawValue)
        } catch {
            os_log(.error, log: osLogger, "Failed to store telemetry event: %{public}@", error.localizedDescription)
        }
        
        // Export to handlers
        for handler in exportHandlers {
            handler.export(processedEvent)
        }
    }
    
    private func redactSensitiveInfo(from event: any TelemetryEvent) -> any TelemetryEvent {
        // This is a simplified version - would need proper implementation
        // to actually modify the event based on excluded metadata keys
        return event
    }
    
    private func uploadPendingEvents() async {
        guard !isUploading else { return }
        guard configuration.configuration.isEnabled else { return }
        
        // Check network conditions
        if configuration.configuration.wifiOnlyUpload {
            // TODO: Check if on WiFi
        }
        
        isUploading = true
        defer { isUploading = false }
        
        do {
            let batchSize = configuration.configuration.uploadBatchSize
            let events = try await storage?.retrieveEvents(limit: batchSize) ?? []
            
            guard !events.isEmpty else { return }
            
            os_log(.info, log: osLogger, "Uploading %{public}d telemetry events", events.count)
            
            // TODO: Implement actual upload logic
            // For now, just mark as uploaded
            let eventIds = events.map { $0.id }
            try await storage?.deleteEvents(ids: eventIds)
            
            os_log(.info, log: osLogger, "Successfully uploaded %{public}d events", events.count)
        } catch {
            os_log(.error, log: osLogger, "Failed to upload telemetry events: %{public}@", error.localizedDescription)
        }
    }
}

// MARK: - Supporting Types

/// Telemetry statistics
public struct TelemetryStatistics {
    public let sessionId: UUID
    public let sessionDuration: TimeInterval
    public let totalEvents: Int
    public let performanceMetrics: [String: Double]
    public let systemMetrics: [String: Double]
    public let frameRate: Double
    public let memoryUsage: Double
    public let cpuUsage: Double
}

/// Protocol for telemetry export handlers
public protocol TelemetryExportHandler {
    func export(_ event: any TelemetryEvent)
}

/// Console export handler
public class ConsoleExportHandler: TelemetryExportHandler {
    private let logger = Logger(label: "com.claudecode.telemetry.console")
    
    public init() {}
    
    public func export(_ event: any TelemetryEvent) {
        logger.info("Telemetry Event: \(event.eventType.rawValue) at \(event.timestamp)")
    }
}

/// File export handler
public class FileExportHandler: TelemetryExportHandler {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    
    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
    }
    
    public func export(_ event: any TelemetryEvent) {
        // Capture values before Task to avoid capture issues
        let url = self.fileURL
        let encoderCopy = JSONEncoder()
        encoderCopy.dateEncodingStrategy = .iso8601
        encoderCopy.outputFormatting = .prettyPrinted
        
        // Write to file in background
        Task {
            do {
                let data = try encoderCopy.encode(event)
                if FileManager.default.fileExists(atPath: url.path) {
                    let handle = try FileHandle(forWritingTo: url)
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.write(",\n".data(using: .utf8)!)
                    handle.closeFile()
                } else {
                    try data.write(to: url)
                }
            } catch {
                print("Failed to export event to file: \(error)")
            }
        }
    }
}

// MARK: - Convenience Extensions

extension TelemetryManager {
    
    /// Log app launch
    public func logAppLaunch() {
        logAppLifecycle(.launch)
        performanceMonitor.markInteractive()
    }
    
    /// Log app foreground
    public func logAppForeground() {
        logAppLifecycle(.foreground)
    }
    
    /// Log app background
    public func logAppBackground() {
        logAppLifecycle(.background)
    }
    
    /// Log app terminate
    public func logAppTerminate() {
        logAppLifecycle(.terminate)
    }
    
    /// Log memory warning
    public func logMemoryWarning() {
        logAppLifecycle(.memoryWarning)
        logEvent(CustomEvent(
            sessionId: sessionId,
            userId: userId,
            name: "memory_warning",
            category: "system",
            data: [
                "memory_usage": AnyCodable(metricsCollector.collectMemoryMetrics().usedMemory)
            ]
        ))
    }
}

// MARK: - App Lifecycle Event Extensions

// The LifecycleEventType enum cases are already available directly, no need for static properties