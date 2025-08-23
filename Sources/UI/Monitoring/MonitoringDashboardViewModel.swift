// Sources/UI/Monitoring/MonitoringDashboardViewModel.swift
// Task: Monitoring Dashboard ViewModel Implementation
// This file provides the view model for the monitoring dashboard

import Foundation
import SwiftUI
import Combine

/// View model for the monitoring dashboard
@MainActor
public class MonitoringDashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var sessionId = UUID()
    @Published var sessionDuration: TimeInterval = 0
    @Published var totalEvents = 0
    
    @Published var currentFrameRate: Double = 60.0
    @Published var memoryUsage: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var errorCount = 0
    
    @Published var frameRateTrend = StatCard.Trend.stable
    @Published var memoryTrend = StatCard.Trend.stable
    @Published var cpuTrend = StatCard.Trend.stable
    @Published var errorTrend = StatCard.Trend.stable
    
    @Published var frameRateHistory: [ChartDataPoint] = []
    @Published var memoryHistory: [ChartDataPoint] = []
    @Published var cpuHistory: [ChartDataPoint] = []
    
    @Published var recentEvents: [TelemetryEventSummary] = []
    @Published var recentErrors: [ErrorInfo] = []
    @Published var activeTrackers: [TrackerInfo] = []
    @Published var sshConnections: [SSHConnectionInfo] = []
    @Published var customMetrics: [CustomMetricInfo] = []
    
    @Published var criticalErrorCount = 0
    @Published var warningCount = 0
    
    // MARK: - Private Properties
    
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let telemetryManager = TelemetryManager.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private let metricsCollector = MetricsCollector.shared
    
    private var previousFrameRate: Double = 60.0
    private var previousMemory: Double = 0.0
    private var previousCPU: Double = 0.0
    private var previousErrorCount = 0
    
    private let maxHistoryPoints = 60
    
    // MARK: - Initialization
    
    public init() {
        setupObservers()
        loadInitialData()
    }
    
    // MARK: - Public Methods
    
    public func startMonitoring() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateData()
            }
        }
    }
    
    public func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    public func refresh() {
        Task {
            await loadData()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe performance changes
        metricsCollector.addCollectionCallback { [weak self] snapshot in
            Task { @MainActor in
                self?.updateMetrics(snapshot)
            }
        }
        
        // Observe performance reports
        performanceMonitor.addObserver { [weak self] report in
            Task { @MainActor in
                self?.updatePerformance(report)
            }
        }
    }
    
    private func loadInitialData() {
        Task {
            await loadData()
        }
    }
    
    private func loadData() async {
        // Get telemetry statistics
        let stats = await telemetryManager.getStatistics()
        
        sessionId = stats.sessionId
        sessionDuration = stats.sessionDuration
        totalEvents = stats.totalEvents
        
        currentFrameRate = stats.frameRate
        memoryUsage = stats.memoryUsage
        cpuUsage = stats.cpuUsage
        
        // Update trends
        updateTrends()
        
        // Load recent events
        loadRecentEvents()
        
        // Load active trackers
        let performanceReport = performanceMonitor.getPerformanceReport()
        updateActiveTrackers(performanceReport.activeTrackers)
    }
    
    private func updateData() {
        sessionDuration += 1.0
        
        // Update performance data
        let report = performanceMonitor.getPerformanceReport()
        updatePerformance(report)
        
        // Update metrics
        let snapshot = metricsCollector.getCurrentSnapshot()
        updateMetrics(snapshot)
        
        // Update charts
        updateCharts()
    }
    
    private func updatePerformance(_ report: PerformanceReport) {
        currentFrameRate = report.currentFrameRate
        memoryUsage = report.memoryUsage
        cpuUsage = report.cpuUsage
        
        updateActiveTrackers(report.activeTrackers)
        updateTrends()
    }
    
    private func updateMetrics(_ snapshot: MetricsSnapshot) {
        // Update system metrics
        if let memory = snapshot.systemMetrics["memory_used_mb"] {
            memoryUsage = memory
        }
        
        if let cpu = snapshot.systemMetrics["cpu_usage_percent"] {
            cpuUsage = cpu
        }
        
        // Update custom metrics
        var metrics: [CustomMetricInfo] = []
        
        for (name, value) in snapshot.customMetrics {
            metrics.append(CustomMetricInfo(
                id: UUID(),
                name: name,
                value: value,
                unit: "units",
                timestamp: snapshot.timestamp
            ))
        }
        
        customMetrics = metrics
    }
    
    private func updateTrends() {
        // Frame rate trend
        if currentFrameRate > previousFrameRate + 5 {
            frameRateTrend = .up
        } else if currentFrameRate < previousFrameRate - 5 {
            frameRateTrend = .down
        } else {
            frameRateTrend = .stable
        }
        previousFrameRate = currentFrameRate
        
        // Memory trend
        if memoryUsage > previousMemory + 10 {
            memoryTrend = .up
        } else if memoryUsage < previousMemory - 10 {
            memoryTrend = .down
        } else {
            memoryTrend = .stable
        }
        previousMemory = memoryUsage
        
        // CPU trend
        if cpuUsage > previousCPU + 5 {
            cpuTrend = .up
        } else if cpuUsage < previousCPU - 5 {
            cpuTrend = .down
        } else {
            cpuTrend = .stable
        }
        previousCPU = cpuUsage
        
        // Error trend
        if errorCount > previousErrorCount {
            errorTrend = .up
        } else if errorCount < previousErrorCount {
            errorTrend = .down
        } else {
            errorTrend = .stable
        }
        previousErrorCount = errorCount
    }
    
    private func updateCharts() {
        let timestamp = Date()
        
        // Update frame rate history
        frameRateHistory.append(ChartDataPoint(
            timestamp: timestamp,
            value: currentFrameRate
        ))
        
        if frameRateHistory.count > maxHistoryPoints {
            frameRateHistory.removeFirst()
        }
        
        // Update memory history
        memoryHistory.append(ChartDataPoint(
            timestamp: timestamp,
            value: memoryUsage
        ))
        
        if memoryHistory.count > maxHistoryPoints {
            memoryHistory.removeFirst()
        }
        
        // Update CPU history
        cpuHistory.append(ChartDataPoint(
            timestamp: timestamp,
            value: cpuUsage
        ))
        
        if cpuHistory.count > maxHistoryPoints {
            cpuHistory.removeFirst()
        }
    }
    
    private func loadRecentEvents() {
        // Simulate loading recent events
        recentEvents = [
            TelemetryEventSummary(
                title: "App Launched",
                timestamp: Date().addingTimeInterval(-300),
                type: .appLifecycle,
                value: nil
            ),
            TelemetryEventSummary(
                title: "SSH Connection",
                timestamp: Date().addingTimeInterval(-180),
                type: .sshConnection,
                value: "192.168.1.100"
            ),
            TelemetryEventSummary(
                title: "View Loaded",
                timestamp: Date().addingTimeInterval(-60),
                type: .performance,
                value: "45ms"
            ),
            TelemetryEventSummary(
                title: "Button Tapped",
                timestamp: Date().addingTimeInterval(-30),
                type: .userAction,
                value: "Connect"
            ),
            TelemetryEventSummary(
                title: "API Request",
                timestamp: Date().addingTimeInterval(-10),
                type: .performance,
                value: "125ms"
            )
        ]
        
        // Load recent errors
        recentErrors = [
            ErrorInfo(
                id: UUID(),
                timestamp: Date().addingTimeInterval(-120),
                type: "NetworkError",
                message: "Connection timeout",
                severity: .warning,
                stackTrace: nil
            ),
            ErrorInfo(
                id: UUID(),
                timestamp: Date().addingTimeInterval(-60),
                type: "ValidationError",
                message: "Invalid SSH key format",
                severity: .error,
                stackTrace: nil
            )
        ]
        
        errorCount = recentErrors.count
        criticalErrorCount = recentErrors.filter { $0.severity == .critical }.count
        warningCount = recentErrors.filter { $0.severity == .warning }.count
        
        // Load SSH connections
        sshConnections = [
            SSHConnectionInfo(
                id: UUID(),
                host: "192.168.1.100",
                port: 22,
                status: .connected,
                duration: 300,
                bytesTransferred: 1024 * 1024 * 5
            ),
            SSHConnectionInfo(
                id: UUID(),
                host: "10.0.0.50",
                port: 22,
                status: .disconnected,
                duration: 150,
                bytesTransferred: 1024 * 512
            )
        ]
    }
    
    private func updateActiveTrackers(_ trackers: [PerformanceTracker]) {
        activeTrackers = trackers.map { tracker in
            TrackerInfo(
                id: tracker.id,
                operation: tracker.operation,
                startTime: tracker.startTime,
                duration: tracker.duration ?? 0
            )
        }
    }
}

// MARK: - Supporting Types

public struct ChartDataPoint: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let value: Double
}

public struct ErrorInfo: Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let type: String
    public let message: String
    public let severity: ErrorSeverity
    public let stackTrace: String?
    
    public enum ErrorSeverity {
        case warning, error, critical
        
        var color: Color {
            switch self {
            case .warning: return .orange
            case .error: return .red
            case .critical: return .purple
            }
        }
        
        var icon: String {
            switch self {
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            case .critical: return "exclamationmark.octagon"
            }
        }
    }
}

public struct TrackerInfo: Identifiable {
    public let id: UUID
    public let operation: String
    public let startTime: Date
    public let duration: TimeInterval
}

public struct SSHConnectionInfo: Identifiable {
    public let id: UUID
    public let host: String
    public let port: Int
    public let status: ConnectionStatus
    public let duration: TimeInterval
    public let bytesTransferred: Int64
    
    public enum ConnectionStatus {
        case connected, disconnected, connecting, failed
        
        var color: Color {
            switch self {
            case .connected: return .green
            case .disconnected: return .gray
            case .connecting: return .orange
            case .failed: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .connected: return "checkmark.circle.fill"
            case .disconnected: return "xmark.circle"
            case .connecting: return "arrow.triangle.2.circlepath"
            case .failed: return "exclamationmark.triangle.fill"
            }
        }
    }
}

public struct CustomMetricInfo: Identifiable {
    public let id: UUID
    public let name: String
    public let value: Double
    public let unit: String
    public let timestamp: Date
}