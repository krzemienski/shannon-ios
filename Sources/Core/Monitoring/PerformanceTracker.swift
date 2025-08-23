//
//  PerformanceTracker.swift
//  ClaudeCode
//
//  Performance tracking and profiling system (Tasks 811-820)
//

import Foundation
import OSLog
import QuartzCore

/// Performance span for distributed tracing
public class PerformanceSpan {
    public let id: String
    public let operationName: String
    public let parentId: String?
    public let startTime: Date
    public var endTime: Date?
    public var duration: TimeInterval?
    public var tags: [String: String] = [:]
    public var logs: [(Date, String)] = []
    public var status: SpanStatus = .inProgress
    public var children: [PerformanceSpan] = []
    
    public enum SpanStatus {
        case inProgress
        case completed
        case failed
        case cancelled
    }
    
    public init(operationName: String, parentId: String? = nil) {
        self.id = UUID().uuidString
        self.operationName = operationName
        self.parentId = parentId
        self.startTime = Date()
    }
    
    /// Complete the span
    public func complete(status: SpanStatus = .completed) {
        guard endTime == nil else { return }
        
        endTime = Date()
        duration = endTime?.timeIntervalSince(startTime)
        self.status = status
    }
    
    /// Add a tag to the span
    public func addTag(key: String, value: String) {
        tags[key] = value
    }
    
    /// Add a log entry to the span
    public func addLog(_ message: String) {
        logs.append((Date(), message))
    }
    
    /// Create a child span
    public func createChildSpan(operationName: String) -> PerformanceSpan {
        let child = PerformanceSpan(operationName: operationName, parentId: id)
        children.append(child)
        return child
    }
}

/// Performance measurement result
public struct PerformanceMeasurement: Codable {
    public let name: String
    public let startTime: Date
    public let endTime: Date
    public let duration: TimeInterval
    public let cpuTime: TimeInterval
    public let memoryUsed: Int64
    public let peakMemory: Int64
    public let metadata: [String: String]?
    
    public var throughput: Double {
        guard duration > 0 else { return 0 }
        return 1.0 / duration
    }
}

/// Performance tracker for monitoring app performance
@MainActor
public class PerformanceTracker: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var isTracking = true
    @Published public private(set) var activeSpans: [String: PerformanceSpan] = [:]
    @Published public private(set) var measurements: [PerformanceMeasurement] = []
    @Published public private(set) var performanceScore: Double = 100.0
    @Published public private(set) var bottlenecks: [PerformanceBottleneck] = []
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "PerformanceTracker")
    private let telemetry = TelemetryManager.shared
    private let metricsCollector = MetricsCollector()
    private var measurementHistory = CircularBuffer<PerformanceMeasurement>(capacity: 1000)
    private let queue = DispatchQueue(label: "com.claudecode.performance", qos: .utility)
    
    // Performance thresholds
    private let slowOperationThreshold: TimeInterval = 1.0
    private let criticalOperationThreshold: TimeInterval = 5.0
    private let highMemoryThreshold: Int64 = 100_000_000 // 100 MB
    
    // MARK: - Initialization
    
    public init() {
        startMonitoring()
    }
    
    // MARK: - Span Management
    
    /// Start a new performance span
    @discardableResult
    public func startSpan(_ operationName: String, parentId: String? = nil) -> String {
        let span = PerformanceSpan(operationName: operationName, parentId: parentId)
        activeSpans[span.id] = span
        
        // Record metric
        metricsCollector.incrementCounter("performance.spans.started")
        
        logger.debug("Started span: \(operationName) (ID: \(span.id))")
        
        return span.id
    }
    
    /// Complete a span
    public func completeSpan(_ spanId: String, status: PerformanceSpan.SpanStatus = .completed) {
        guard let span = activeSpans[spanId] else {
            logger.warning("Attempted to complete unknown span: \(spanId)")
            return
        }
        
        span.complete(status: status)
        activeSpans.removeValue(forKey: spanId)
        
        // Record metrics
        if let duration = span.duration {
            metricsCollector.recordTiming("performance.span.duration", duration: duration)
            metricsCollector.incrementCounter("performance.spans.completed")
            
            // Check for slow operations
            if duration > slowOperationThreshold {
                identifyBottleneck(span: span, duration: duration)
            }
            
            // Log to telemetry
            telemetry.logPerformance(
                operation: span.operationName,
                duration: duration,
                success: status == .completed,
                metadata: span.tags
            )
        }
        
        logger.debug("Completed span: \(span.operationName) - Duration: \(span.duration ?? 0)s")
    }
    
    /// Add tag to active span
    public func addSpanTag(_ spanId: String, key: String, value: String) {
        activeSpans[spanId]?.addTag(key: key, value: value)
    }
    
    /// Add log to active span
    public func addSpanLog(_ spanId: String, message: String) {
        activeSpans[spanId]?.addLog(message)
    }
    
    // MARK: - Performance Measurement
    
    /// Measure a block of code
    public func measure<T>(
        _ name: String,
        metadata: [String: String]? = nil,
        block: () async throws -> T
    ) async rethrows -> T {
        let startTime = Date()
        let startCPUTime = CACurrentMediaTime()
        let startMemory = currentMemoryUsage()
        
        let spanId = startSpan(name)
        defer {
            completeSpan(spanId)
        }
        
        do {
            let result = try await block()
            
            let endTime = Date()
            let endCPUTime = CACurrentMediaTime()
            let endMemory = currentMemoryUsage()
            
            let measurement = PerformanceMeasurement(
                name: name,
                startTime: startTime,
                endTime: endTime,
                duration: endTime.timeIntervalSince(startTime),
                cpuTime: endCPUTime - startCPUTime,
                memoryUsed: endMemory - startMemory,
                peakMemory: endMemory,
                metadata: metadata
            )
            
            recordMeasurement(measurement)
            
            return result
        } catch {
            completeSpan(spanId, status: .failed)
            throw error
        }
    }
    
    /// Measure synchronous code
    public func measureSync<T>(
        _ name: String,
        metadata: [String: String]? = nil,
        block: () throws -> T
    ) rethrows -> T {
        let startTime = Date()
        let startCPUTime = CACurrentMediaTime()
        let startMemory = currentMemoryUsage()
        
        let spanId = startSpan(name)
        defer {
            completeSpan(spanId)
        }
        
        do {
            let result = try block()
            
            let endTime = Date()
            let endCPUTime = CACurrentMediaTime()
            let endMemory = currentMemoryUsage()
            
            let measurement = PerformanceMeasurement(
                name: name,
                startTime: startTime,
                endTime: endTime,
                duration: endTime.timeIntervalSince(startTime),
                cpuTime: endCPUTime - startCPUTime,
                memoryUsed: endMemory - startMemory,
                peakMemory: endMemory,
                metadata: metadata
            )
            
            recordMeasurement(measurement)
            
            return result
        } catch {
            completeSpan(spanId, status: .failed)
            throw error
        }
    }
    
    // MARK: - Recording
    
    private func recordMeasurement(_ measurement: PerformanceMeasurement) {
        measurementHistory.append(measurement)
        
        Task { @MainActor in
            measurements.append(measurement)
            if measurements.count > 100 {
                measurements.removeFirst()
            }
            
            // Update metrics
            metricsCollector.recordTiming("performance.operation.duration", duration: measurement.duration)
            metricsCollector.setGauge("performance.memory.used", value: Double(measurement.memoryUsed))
            
            // Check thresholds
            checkPerformanceThresholds(measurement)
            
            // Update performance score
            updatePerformanceScore()
        }
    }
    
    // MARK: - Bottleneck Detection
    
    private func identifyBottleneck(span: PerformanceSpan, duration: TimeInterval) {
        let bottleneck = PerformanceBottleneck(
            id: UUID(),
            operation: span.operationName,
            duration: duration,
            timestamp: span.startTime,
            severity: categorizeBottleneckSeverity(duration),
            suggestions: generateOptimizationSuggestions(span)
        )
        
        Task { @MainActor in
            bottlenecks.append(bottleneck)
            
            // Keep only recent bottlenecks
            if bottlenecks.count > 50 {
                bottlenecks.removeFirst()
            }
            
            // Sort by severity and duration
            bottlenecks.sort { $0.severity.rawValue > $1.severity.rawValue }
        }
        
        logger.warning("Performance bottleneck detected: \(span.operationName) took \(String(format: "%.2f", duration))s")
    }
    
    private func categorizeBottleneckSeverity(_ duration: TimeInterval) -> BottleneckSeverity {
        if duration > criticalOperationThreshold {
            return .critical
        } else if duration > slowOperationThreshold * 2 {
            return .high
        } else if duration > slowOperationThreshold {
            return .medium
        } else {
            return .low
        }
    }
    
    private func generateOptimizationSuggestions(_ span: PerformanceSpan) -> [String] {
        var suggestions: [String] = []
        
        // Analyze operation name for common patterns
        let operation = span.operationName.lowercased()
        
        if operation.contains("network") || operation.contains("api") {
            suggestions.append("Consider implementing caching for network requests")
            suggestions.append("Use batch API calls where possible")
            suggestions.append("Implement request debouncing")
        }
        
        if operation.contains("database") || operation.contains("query") {
            suggestions.append("Optimize database queries with proper indexing")
            suggestions.append("Use query result caching")
            suggestions.append("Consider database connection pooling")
        }
        
        if operation.contains("image") || operation.contains("render") {
            suggestions.append("Implement image caching and lazy loading")
            suggestions.append("Use appropriate image formats and compression")
            suggestions.append("Consider off-screen rendering")
        }
        
        if operation.contains("file") || operation.contains("disk") {
            suggestions.append("Use asynchronous file operations")
            suggestions.append("Implement file caching in memory")
            suggestions.append("Consider chunked file processing")
        }
        
        // Generic suggestions
        if suggestions.isEmpty {
            suggestions.append("Profile the operation to identify specific bottlenecks")
            suggestions.append("Consider moving to background queue")
            suggestions.append("Implement progressive loading if applicable")
        }
        
        return suggestions
    }
    
    // MARK: - Performance Monitoring
    
    private func startMonitoring() {
        // Monitor frame rate
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { [weak self] in
                await self?.monitorPerformance()
            }
        }
    }
    
    private func monitorPerformance() async {
        // Calculate FPS (simplified)
        let fps = 60.0 // iOS target frame rate
        metricsCollector.setGauge("performance.fps", value: fps)
        
        // Monitor memory
        let memoryUsage = currentMemoryUsage()
        metricsCollector.setGauge("performance.memory.current", value: Double(memoryUsage))
        
        // Check for memory pressure
        if memoryUsage > highMemoryThreshold {
            logger.warning("High memory usage detected: \(memoryUsage / 1_000_000) MB")
            
            telemetry.logEvent(
                "performance.memory.pressure",
                category: .performance,
                level: .warning,
                measurements: ["memory_mb": Double(memoryUsage) / 1_000_000]
            )
        }
    }
    
    private func checkPerformanceThresholds(_ measurement: PerformanceMeasurement) {
        // Check duration threshold
        if measurement.duration > criticalOperationThreshold {
            telemetry.logEvent(
                "performance.critical.operation",
                category: .performance,
                level: .critical,
                properties: [
                    "operation": measurement.name,
                    "duration": String(format: "%.2f", measurement.duration)
                ]
            )
        }
        
        // Check memory threshold
        if measurement.memoryUsed > highMemoryThreshold {
            telemetry.logEvent(
                "performance.high.memory",
                category: .performance,
                level: .warning,
                properties: [
                    "operation": measurement.name,
                    "memory_mb": String(format: "%.2f", Double(measurement.memoryUsed) / 1_000_000)
                ]
            )
        }
    }
    
    // MARK: - Performance Score
    
    private func updatePerformanceScore() {
        var score = 100.0
        
        // Deduct points for bottlenecks
        for bottleneck in bottlenecks {
            switch bottleneck.severity {
            case .critical:
                score -= 20
            case .high:
                score -= 10
            case .medium:
                score -= 5
            case .low:
                score -= 2
            }
        }
        
        // Deduct points for active spans (operations taking too long)
        let longRunningSpans = activeSpans.values.filter {
            Date().timeIntervalSince($0.startTime) > slowOperationThreshold
        }
        score -= Double(longRunningSpans.count) * 5
        
        // Ensure score stays within bounds
        performanceScore = max(0, min(100, score))
        
        // Record score
        metricsCollector.setGauge("performance.score", value: performanceScore)
    }
    
    // MARK: - Utilities
    
    private func currentMemoryUsage() -> Int64 {
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
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    // MARK: - Export
    
    /// Export performance data
    public func exportPerformanceData() -> PerformanceExport {
        PerformanceExport(
            exportDate: Date(),
            performanceScore: performanceScore,
            measurements: measurements,
            bottlenecks: bottlenecks,
            activeSpansCount: activeSpans.count,
            metrics: metricsCollector.exportMetrics()
        )
    }
}

// MARK: - Supporting Types

/// Performance bottleneck
public struct PerformanceBottleneck: Codable, Identifiable {
    public let id: UUID
    public let operation: String
    public let duration: TimeInterval
    public let timestamp: Date
    public let severity: BottleneckSeverity
    public let suggestions: [String]
}

/// Bottleneck severity
public enum BottleneckSeverity: Int, Codable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
}

/// Performance export data
public struct PerformanceExport: Codable {
    public let exportDate: Date
    public let performanceScore: Double
    public let measurements: [PerformanceMeasurement]
    public let bottlenecks: [PerformanceBottleneck]
    public let activeSpansCount: Int
    public let metrics: MetricsExport
}

// MARK: - Performance Profiler

/// Performance profiler for detailed analysis
public class PerformanceProfiler {
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "Profiler")
    private var profiles: [String: Profile] = [:]
    
    public struct Profile {
        public let name: String
        public var callCount: Int = 0
        public var totalTime: TimeInterval = 0
        public var minTime: TimeInterval = .infinity
        public var maxTime: TimeInterval = 0
        public var averageTime: TimeInterval {
            callCount > 0 ? totalTime / Double(callCount) : 0
        }
    }
    
    /// Start profiling
    public func startProfiling(_ name: String) -> ProfileSession {
        ProfileSession(name: name, profiler: self)
    }
    
    /// Record profile data
    fileprivate func recordProfile(name: String, duration: TimeInterval) {
        var profile = profiles[name] ?? Profile(name: name)
        
        profile.callCount += 1
        profile.totalTime += duration
        profile.minTime = min(profile.minTime, duration)
        profile.maxTime = max(profile.maxTime, duration)
        
        profiles[name] = profile
    }
    
    /// Get all profiles
    public func getAllProfiles() -> [Profile] {
        Array(profiles.values).sorted { $0.totalTime > $1.totalTime }
    }
    
    /// Clear all profiles
    public func clearProfiles() {
        profiles.removeAll()
    }
}

/// Profile session
public class ProfileSession {
    private let name: String
    private let startTime: Date
    private weak var profiler: PerformanceProfiler?
    
    init(name: String, profiler: PerformanceProfiler) {
        self.name = name
        self.startTime = Date()
        self.profiler = profiler
    }
    
    /// End the profiling session
    public func end() {
        let duration = Date().timeIntervalSince(startTime)
        profiler?.recordProfile(name: name, duration: duration)
    }
    
    deinit {
        end()
    }
}