//
//  MonitorCoordinator.swift
//  ClaudeCode
//
//  Coordinator for monitoring navigation and flow
//

import SwiftUI
import Combine

/// Coordinator managing monitoring navigation and flow
@MainActor
final class MonitorCoordinator: BaseCoordinator, ObservableObject {
    
    // MARK: - Navigation State
    
    @Published var navigationPath = NavigationPath()
    @Published var selectedMonitorType: MonitorType = .system
    @Published var isShowingExport = false
    @Published var isShowingSettings = false
    @Published var timeRange: TimeRange = .lastHour
    
    // MARK: - Dependencies
    
    weak var appCoordinator: AppCoordinator?
    private let dependencyContainer: DependencyContainer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - View Models
    
    private var monitorViewModel: MonitorViewModel?
    
    // MARK: - Initialization
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        super.init()
        observeMonitorStore()
    }
    
    // MARK: - Setup
    
    private func observeMonitorStore() {
        // Observe monitor store updates
        dependencyContainer.monitorStore.$isMonitoring
            .sink { [weak self] isMonitoring in
                if isMonitoring {
                    self?.startMonitoring()
                } else {
                    self?.stopMonitoring()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Coordinator Lifecycle
    
    override func start() {
        // Start monitoring if enabled
        if dependencyContainer.settingsStore.monitoringEnabled {
            startMonitoring()
        }
    }
    
    // MARK: - Navigation
    
    func handleTabSelection() {
        // Called when monitor tab is selected
        if !dependencyContainer.monitorStore.isMonitoring {
            // Prompt to start monitoring
            showMonitoringPrompt()
        }
    }
    
    func selectMonitorType(_ type: MonitorType) {
        selectedMonitorType = type
        navigationPath.append(MonitorRoute.detail(type))
    }
    
    func showSettings() {
        isShowingSettings = true
        navigationPath.append(MonitorRoute.settings)
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        Task {
            await dependencyContainer.monitorStore.startMonitoring()
            await getMonitorViewModel().startUpdates()
        }
    }
    
    func stopMonitoring() {
        Task {
            await dependencyContainer.monitorStore.stopMonitoring()
            await getMonitorViewModel().stopUpdates()
        }
    }
    
    func toggleMonitoring() {
        if dependencyContainer.monitorStore.isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    private func showMonitoringPrompt() {
        let alertData = AlertData(
            title: "Start Monitoring?",
            message: "Would you like to start system monitoring?",
            primaryAction: AlertAction(
                title: "Start",
                style: .default,
                handler: { [weak self] in
                    self?.startMonitoring()
                }
            ),
            secondaryAction: AlertAction(
                title: "Cancel",
                style: .cancel,
                handler: nil
            )
        )
        appCoordinator?.showAlert(alertData)
    }
    
    // MARK: - Time Range
    
    func selectTimeRange(_ range: TimeRange) {
        timeRange = range
        Task {
            await getMonitorViewModel().updateTimeRange(range)
        }
    }
    
    // MARK: - Data Export
    
    func showExport() {
        isShowingExport = true
        navigationPath.append(MonitorRoute.export)
    }
    
    func exportData(type: MonitorType, format: MonitorExportFormat) async throws -> URL {
        try await dependencyContainer.monitorStore.exportData(
            type: type,
            format: format,
            timeRange: timeRange
        )
    }
    
    func exportAllData(format: MonitorExportFormat) async throws -> URL {
        try await dependencyContainer.monitorStore.exportAllData(
            format: format,
            timeRange: timeRange
        )
    }
    
    // MARK: - Metrics Access
    
    func getSystemMetrics() -> SystemMetrics? {
        dependencyContainer.monitorStore.currentSystemMetrics
    }
    
    func getNetworkMetrics() -> NetworkMetrics? {
        dependencyContainer.monitorStore.currentNetworkMetrics
    }
    
    func getSSHMetrics() -> SSHMetrics? {
        dependencyContainer.monitorStore.currentSSHMetrics
    }
    
    func getPerformanceMetrics() -> PerformanceMetrics? {
        dependencyContainer.monitorStore.currentPerformanceMetrics
    }
    
    func getHistoricalData(for type: MonitorType, range: TimeRange) -> [MetricDataPoint] {
        dependencyContainer.monitorStore.getHistoricalData(
            for: type,
            range: range
        )
    }
    
    // MARK: - Alerts
    
    func configureAlert(for metric: MetricType, threshold: Double, condition: AlertCondition) {
        Task {
            await dependencyContainer.monitorStore.configureAlert(
                metric: metric,
                threshold: threshold,
                condition: condition
            )
        }
    }
    
    func removeAlert(for metric: MetricType) {
        Task {
            await dependencyContainer.monitorStore.removeAlert(for: metric)
        }
    }
    
    func getActiveAlerts() -> [MetricAlert] {
        dependencyContainer.monitorStore.activeAlerts
    }
    
    // MARK: - View Model Management
    
    func getMonitorViewModel() -> MonitorViewModel {
        if let existing = monitorViewModel {
            return existing
        }
        
        let viewModel = dependencyContainer.makeMonitorViewModel()
        monitorViewModel = viewModel
        return viewModel
    }
    
    // MARK: - Error Handling
    
    func handleMonitorError(_ error: Error) {
        appCoordinator?.showError(error) { [weak self] in
            // Retry monitoring
            self?.startMonitoring()
        }
    }
}

// MARK: - Navigation Routes

enum MonitorRoute: Hashable {
    case detail(MonitorType)
    case settings
    case export
    case alertConfig(MetricType)
}

// MARK: - Supporting Types

enum MonitorType: String, CaseIterable, Identifiable {
    case system = "System"
    case network = "Network"
    case ssh = "SSH"
    case performance = "Performance"
    case logs = "Logs"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .system: return "cpu"
        case .network: return "network"
        case .ssh: return "terminal.fill"
        case .performance: return "speedometer"
        case .logs: return "doc.text.fill"
        }
    }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case lastMinute = "1m"
    case lastFiveMinutes = "5m"
    case lastFifteenMinutes = "15m"
    case lastHour = "1h"
    case lastSixHours = "6h"
    case lastDay = "24h"
    case lastWeek = "7d"
    case lastMonth = "30d"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .lastMinute: return "Last Minute"
        case .lastFiveMinutes: return "Last 5 Minutes"
        case .lastFifteenMinutes: return "Last 15 Minutes"
        case .lastHour: return "Last Hour"
        case .lastSixHours: return "Last 6 Hours"
        case .lastDay: return "Last Day"
        case .lastWeek: return "Last Week"
        case .lastMonth: return "Last Month"
        }
    }
    
    var seconds: TimeInterval {
        switch self {
        case .lastMinute: return 60
        case .lastFiveMinutes: return 300
        case .lastFifteenMinutes: return 900
        case .lastHour: return 3600
        case .lastSixHours: return 21600
        case .lastDay: return 86400
        case .lastWeek: return 604800
        case .lastMonth: return 2592000
        }
    }
}

enum MonitorExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
    case pdf = "PDF"
    
    var fileExtension: String {
        rawValue.lowercased()
    }
}

enum MetricType: String, CaseIterable {
    case cpuUsage = "CPU Usage"
    case memoryUsage = "Memory Usage"
    case diskUsage = "Disk Usage"
    case networkBandwidth = "Network Bandwidth"
    case responseTime = "Response Time"
    case errorRate = "Error Rate"
}

enum AlertCondition: String, CaseIterable {
    case above = "Above"
    case below = "Below"
    case equals = "Equals"
}

struct MetricAlert: Identifiable {
    let id = UUID()
    let metric: MetricType
    let threshold: Double
    let condition: AlertCondition
    let triggered: Bool
    let timestamp: Date
}