//
//  DashboardManager.swift
//  ClaudeCode
//
//  Custom dashboards with real-time metrics and automated alerts
//

import Foundation
import SwiftUI
import Combine
import os.log

// MARK: - Dashboard Manager

public final class DashboardManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = DashboardManager()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.dashboards", category: "DashboardManager")
    private let queue = DispatchQueue(label: "com.claudecode.dashboards", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    // Published dashboards
    @Published public var executiveDashboard: ExecutiveDashboard
    @Published public var developerDashboard: DeveloperDashboard
    @Published public var supportDashboard: SupportDashboard
    @Published public var userExperienceDashboard: UserExperienceDashboard
    @Published public var realTimeMetrics: RealTimeMetrics
    
    // Update timers
    private var metricsUpdateTimer: Timer?
    private var alertCheckTimer: Timer?
    
    // Alert system
    private let alertManager = AlertManager()
    
    // Data sources
    private let dataAggregator = DashboardDataAggregator()
    
    // MARK: - Initialization
    
    private init() {
        self.executiveDashboard = ExecutiveDashboard()
        self.developerDashboard = DeveloperDashboard()
        self.supportDashboard = SupportDashboard()
        self.userExperienceDashboard = UserExperienceDashboard()
        self.realTimeMetrics = RealTimeMetrics()
        
        setupDataSources()
        startMetricsUpdates()
        setupAlerts()
    }
    
    // MARK: - Setup
    
    private func setupDataSources() {
        // Connect to monitoring services
        dataAggregator.connectToMonitoringService()
        dataAggregator.connectToAnalytics()
        dataAggregator.connectToPerformanceMonitor()
        dataAggregator.connectToErrorTracker()
    }
    
    private func startMetricsUpdates() {
        // Real-time metrics update every second
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateRealTimeMetrics()
            }
            .store(in: &cancellables)
        
        // Dashboard updates every 5 seconds
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateAllDashboards()
            }
            .store(in: &cancellables)
        
        // Alert checks every 10 seconds
        Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAlerts()
            }
            .store(in: &cancellables)
    }
    
    private func setupAlerts() {
        alertManager.configure(with: AlertConfiguration.default)
        
        // Subscribe to alert notifications
        alertManager.alertPublisher
            .sink { [weak self] alert in
                self?.handleAlert(alert)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Updates
    
    private func updateRealTimeMetrics() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let metrics = self.dataAggregator.getRealTimeMetrics()
            
            DispatchQueue.main.async {
                self.realTimeMetrics = metrics
            }
        }
    }
    
    private func updateAllDashboards() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let executiveData = self.dataAggregator.getExecutiveDashboardData()
            let developerData = self.dataAggregator.getDeveloperDashboardData()
            let supportData = self.dataAggregator.getSupportDashboardData()
            let uxData = self.dataAggregator.getUserExperienceDashboardData()
            
            DispatchQueue.main.async {
                self.executiveDashboard.update(with: executiveData)
                self.developerDashboard.update(with: developerData)
                self.supportDashboard.update(with: supportData)
                self.userExperienceDashboard.update(with: uxData)
            }
        }
    }
    
    private func checkAlerts() {
        alertManager.checkThresholds(
            realTimeMetrics: realTimeMetrics,
            executiveDashboard: executiveDashboard,
            developerDashboard: developerDashboard
        )
    }
    
    private func handleAlert(_ alert: DashboardAlert) {
        logger.warning("Dashboard Alert: \(alert.title) - \(alert.message)")
        
        // Send to appropriate channels based on severity
        switch alert.severity {
        case .critical:
            sendCriticalAlert(alert)
        case .high:
            sendHighPriorityAlert(alert)
        case .medium:
            sendMediumPriorityAlert(alert)
        case .low:
            logAlert(alert)
        }
    }
    
    // MARK: - Alert Handling
    
    private func sendCriticalAlert(_ alert: DashboardAlert) {
        // Send push notification
        NotificationCenter.default.post(
            name: .criticalDashboardAlert,
            object: alert
        )
        
        // Log to monitoring
        MonitoringService.shared.trackEvent(MonitoringEvent(
            name: "dashboard.critical_alert",
            category: .system,
            properties: [
                "title": alert.title,
                "message": alert.message,
                "metric": alert.affectedMetric ?? "unknown"
            ],
            severity: .critical
        ))
    }
    
    private func sendHighPriorityAlert(_ alert: DashboardAlert) {
        NotificationCenter.default.post(
            name: .highPriorityDashboardAlert,
            object: alert
        )
        
        MonitoringService.shared.trackEvent(MonitoringEvent(
            name: "dashboard.high_priority_alert",
            category: .system,
            properties: [
                "title": alert.title,
                "message": alert.message
            ],
            severity: .error
        ))
    }
    
    private func sendMediumPriorityAlert(_ alert: DashboardAlert) {
        NotificationCenter.default.post(
            name: .mediumPriorityDashboardAlert,
            object: alert
        )
        
        MonitoringService.shared.trackEvent(MonitoringEvent(
            name: "dashboard.medium_priority_alert",
            category: .system,
            properties: [
                "title": alert.title,
                "message": alert.message
            ],
            severity: .warning
        ))
    }
    
    private func logAlert(_ alert: DashboardAlert) {
        logger.info("Dashboard Alert (Low): \(alert.title)")
    }
}

// MARK: - Executive Dashboard

public class ExecutiveDashboard: ObservableObject {
    @Published public var kpis: KeyPerformanceIndicators
    @Published public var revenue: RevenueMetrics
    @Published public var userGrowth: UserGrowthMetrics
    @Published public var systemHealth: SystemHealthScore
    @Published public var trends: BusinessTrends
    
    init() {
        self.kpis = KeyPerformanceIndicators()
        self.revenue = RevenueMetrics()
        self.userGrowth = UserGrowthMetrics()
        self.systemHealth = SystemHealthScore()
        self.trends = BusinessTrends()
    }
    
    func update(with data: ExecutiveDashboardData) {
        self.kpis = data.kpis
        self.revenue = data.revenue
        self.userGrowth = data.userGrowth
        self.systemHealth = data.systemHealth
        self.trends = data.trends
    }
}

public struct KeyPerformanceIndicators {
    public var dailyActiveUsers: Int = 0
    public var monthlyActiveUsers: Int = 0
    public var averageSessionLength: TimeInterval = 0
    public var crashFreeRate: Double = 99.9
    public var userSatisfactionScore: Double = 0
    public var conversionRate: Double = 0
}

public struct RevenueMetrics {
    public var dailyRevenue: Double = 0
    public var monthlyRevenue: Double = 0
    public var averageRevenuePerUser: Double = 0
    public var subscriptionChurnRate: Double = 0
    public var lifetimeValue: Double = 0
}

public struct UserGrowthMetrics {
    public var newUsers: Int = 0
    public var retentionRate: Double = 0
    public var growthRate: Double = 0
    public var activationRate: Double = 0
}

public struct SystemHealthScore {
    public var overall: Double = 100
    public var performance: Double = 100
    public var stability: Double = 100
    public var security: Double = 100
    public var userExperience: Double = 100
}

public struct BusinessTrends {
    public var userGrowthTrend: TrendDirection = .stable
    public var revenueTrend: TrendDirection = .stable
    public var engagementTrend: TrendDirection = .stable
    public var performanceTrend: TrendDirection = .stable
    
    public enum TrendDirection {
        case increasing
        case decreasing
        case stable
    }
}

// MARK: - Developer Dashboard

public class DeveloperDashboard: ObservableObject {
    @Published public var performance: PerformanceMetrics
    @Published public var errors: ErrorMetrics
    @Published public var apiHealth: APIHealthMetrics
    @Published public var deployments: DeploymentMetrics
    @Published public var codeQuality: CodeQualityMetrics
    
    init() {
        self.performance = PerformanceMetrics()
        self.errors = ErrorMetrics()
        self.apiHealth = APIHealthMetrics()
        self.deployments = DeploymentMetrics()
        self.codeQuality = CodeQualityMetrics()
    }
    
    func update(with data: DeveloperDashboardData) {
        self.performance = data.performance
        self.errors = data.errors
        self.apiHealth = data.apiHealth
        self.deployments = data.deployments
        self.codeQuality = data.codeQuality
    }
}

public struct PerformanceMetrics {
    public var averageResponseTime: Double = 0
    public var p95ResponseTime: Double = 0
    public var p99ResponseTime: Double = 0
    public var throughput: Double = 0
    public var cpuUsage: Double = 0
    public var memoryUsage: Double = 0
}

public struct ErrorMetrics {
    public var errorRate: Double = 0
    public var criticalErrors: Int = 0
    public var warningCount: Int = 0
    public var topErrors: [(String, Int)] = []
}

public struct APIHealthMetrics {
    public var uptime: Double = 99.9
    public var latency: Double = 0
    public var successRate: Double = 100
    public var endpointHealth: [String: Double] = [:]
}

public struct DeploymentMetrics {
    public var lastDeployment: Date?
    public var deploymentFrequency: Int = 0
    public var rollbackRate: Double = 0
    public var leadTime: TimeInterval = 0
}

public struct CodeQualityMetrics {
    public var testCoverage: Double = 0
    public var technicalDebt: Int = 0
    public var codeComplexity: Double = 0
    public var duplicateCodeRatio: Double = 0
}

// MARK: - Support Dashboard

public class SupportDashboard: ObservableObject {
    @Published public var tickets: TicketMetrics
    @Published public var userFeedback: UserFeedbackMetrics
    @Published public var commonIssues: CommonIssuesMetrics
    @Published public var responseMetrics: ResponseMetrics
    
    init() {
        self.tickets = TicketMetrics()
        self.userFeedback = UserFeedbackMetrics()
        self.commonIssues = CommonIssuesMetrics()
        self.responseMetrics = ResponseMetrics()
    }
    
    func update(with data: SupportDashboardData) {
        self.tickets = data.tickets
        self.userFeedback = data.userFeedback
        self.commonIssues = data.commonIssues
        self.responseMetrics = data.responseMetrics
    }
}

public struct TicketMetrics {
    public var openTickets: Int = 0
    public var resolvedToday: Int = 0
    public var averageResolutionTime: TimeInterval = 0
    public var ticketsByPriority: [String: Int] = [:]
}

public struct UserFeedbackMetrics {
    public var averageRating: Double = 0
    public var reviewCount: Int = 0
    public var sentimentScore: Double = 0
    public var npsScore: Int = 0
}

public struct CommonIssuesMetrics {
    public var topIssues: [(String, Int)] = []
    public var issueCategories: [String: Int] = [:]
    public var resolutionRate: Double = 0
}

public struct ResponseMetrics {
    public var firstResponseTime: TimeInterval = 0
    public var averageResponseTime: TimeInterval = 0
    public var customerSatisfaction: Double = 0
}

// MARK: - User Experience Dashboard

public class UserExperienceDashboard: ObservableObject {
    @Published public var engagement: EngagementMetrics
    @Published public var usability: UsabilityMetrics
    @Published public var navigation: NavigationMetrics
    @Published public var featureUsage: FeatureUsageMetrics
    
    init() {
        self.engagement = EngagementMetrics()
        self.usability = UsabilityMetrics()
        self.navigation = NavigationMetrics()
        self.featureUsage = FeatureUsageMetrics()
    }
    
    func update(with data: UserExperienceDashboardData) {
        self.engagement = data.engagement
        self.usability = data.usability
        self.navigation = data.navigation
        self.featureUsage = data.featureUsage
    }
}

public struct EngagementMetrics {
    public var sessionLength: TimeInterval = 0
    public var screenViews: Int = 0
    public var interactions: Int = 0
    public var bounceRate: Double = 0
}

public struct UsabilityMetrics {
    public var taskCompletionRate: Double = 0
    public var errorRecoveryRate: Double = 0
    public var averageTaskTime: TimeInterval = 0
    public var userFlowCompletion: Double = 0
}

public struct NavigationMetrics {
    public var topScreens: [(String, Int)] = []
    public var navigationPaths: [(String, Int)] = []
    public var dropOffPoints: [(String, Double)] = []
}

public struct FeatureUsageMetrics {
    public var featureAdoption: [String: Double] = [:]
    public var featureRetention: [String: Double] = [:]
    public var featureEngagement: [String: Double] = [:]
}

// MARK: - Real-Time Metrics

public struct RealTimeMetrics {
    public var activeUsers: Int = 0
    public var requestsPerSecond: Double = 0
    public var errorRate: Double = 0
    public var averageLatency: Double = 0
    public var cpuUsage: Double = 0
    public var memoryUsage: Double = 0
    public var networkBandwidth: Double = 0
    public var activeSessions: Int = 0
    
    public var timestamp: Date = Date()
}

// MARK: - Supporting Types

struct ExecutiveDashboardData {
    let kpis: KeyPerformanceIndicators
    let revenue: RevenueMetrics
    let userGrowth: UserGrowthMetrics
    let systemHealth: SystemHealthScore
    let trends: BusinessTrends
}

struct DeveloperDashboardData {
    let performance: PerformanceMetrics
    let errors: ErrorMetrics
    let apiHealth: APIHealthMetrics
    let deployments: DeploymentMetrics
    let codeQuality: CodeQualityMetrics
}

struct SupportDashboardData {
    let tickets: TicketMetrics
    let userFeedback: UserFeedbackMetrics
    let commonIssues: CommonIssuesMetrics
    let responseMetrics: ResponseMetrics
}

struct UserExperienceDashboardData {
    let engagement: EngagementMetrics
    let usability: UsabilityMetrics
    let navigation: NavigationMetrics
    let featureUsage: FeatureUsageMetrics
}

// MARK: - Notification Names

extension Notification.Name {
    static let criticalDashboardAlert = Notification.Name("com.claudecode.dashboard.criticalAlert")
    static let highPriorityDashboardAlert = Notification.Name("com.claudecode.dashboard.highPriorityAlert")
    static let mediumPriorityDashboardAlert = Notification.Name("com.claudecode.dashboard.mediumPriorityAlert")
}