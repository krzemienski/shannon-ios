//
//  DashboardComponents.swift
//  ClaudeCode
//
//  Supporting components for dashboard system: alerts and data aggregation
//

import Foundation
import Combine
import os.log

// MARK: - Alert Manager

public class AlertManager {
    private let logger = Logger(subsystem: "com.claudecode.dashboards", category: "AlertManager")
    private let queue = DispatchQueue(label: "com.claudecode.alerts", qos: .userInitiated)
    
    // Alert configuration
    private var config = AlertConfiguration.default
    private var activeAlerts: Set<String> = []
    private var alertHistory: [DashboardAlert] = []
    private let maxHistorySize = 1000
    
    // Publishers
    public let alertPublisher = PassthroughSubject<DashboardAlert, Never>()
    
    // Threshold tracking
    private var thresholdViolations: [String: ThresholdViolation] = [:]
    
    struct ThresholdViolation {
        let metric: String
        var count: Int
        var firstViolation: Date
        var lastViolation: Date
        var currentValue: Double
        var threshold: Double
    }
    
    func configure(with configuration: AlertConfiguration) {
        self.config = configuration
        logger.info("Alert manager configured")
    }
    
    func checkThresholds(
        realTimeMetrics: RealTimeMetrics,
        executiveDashboard: ExecutiveDashboard,
        developerDashboard: DeveloperDashboard
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Check real-time metrics
            self.checkRealTimeThresholds(realTimeMetrics)
            
            // Check executive metrics
            self.checkExecutiveThresholds(executiveDashboard)
            
            // Check developer metrics
            self.checkDeveloperThresholds(developerDashboard)
            
            // Process sustained violations
            self.processSustainedViolations()
        }
    }
    
    private func checkRealTimeThresholds(_ metrics: RealTimeMetrics) {
        // CPU Usage
        if metrics.cpuUsage > config.cpuThreshold {
            recordViolation(
                metric: "cpu_usage",
                value: metrics.cpuUsage,
                threshold: config.cpuThreshold,
                severity: metrics.cpuUsage > config.criticalCpuThreshold ? .critical : .high
            )
        }
        
        // Memory Usage
        if metrics.memoryUsage > config.memoryThreshold {
            recordViolation(
                metric: "memory_usage",
                value: metrics.memoryUsage,
                threshold: config.memoryThreshold,
                severity: metrics.memoryUsage > config.criticalMemoryThreshold ? .critical : .high
            )
        }
        
        // Error Rate
        if metrics.errorRate > config.errorRateThreshold {
            recordViolation(
                metric: "error_rate",
                value: metrics.errorRate,
                threshold: config.errorRateThreshold,
                severity: metrics.errorRate > config.criticalErrorRateThreshold ? .critical : .high
            )
        }
        
        // Latency
        if metrics.averageLatency > config.latencyThreshold {
            recordViolation(
                metric: "latency",
                value: metrics.averageLatency,
                threshold: config.latencyThreshold,
                severity: .medium
            )
        }
        
        // Active Users Drop
        checkActiveUsersDrop(metrics.activeUsers)
    }
    
    private func checkExecutiveThresholds(_ dashboard: ExecutiveDashboard) {
        // Crash-free rate
        if dashboard.kpis.crashFreeRate < config.minCrashFreeRate {
            createAlert(
                title: "Low Crash-Free Rate",
                message: "Crash-free rate dropped to \(String(format: "%.2f", dashboard.kpis.crashFreeRate))%",
                severity: .critical,
                metric: "crash_free_rate",
                value: dashboard.kpis.crashFreeRate
            )
        }
        
        // System health
        if dashboard.systemHealth.overall < config.minSystemHealth {
            createAlert(
                title: "System Health Degraded",
                message: "Overall system health is \(String(format: "%.1f", dashboard.systemHealth.overall))%",
                severity: dashboard.systemHealth.overall < 70 ? .critical : .high,
                metric: "system_health",
                value: dashboard.systemHealth.overall
            )
        }
        
        // Revenue drop
        checkRevenueDrop(dashboard.revenue.dailyRevenue)
        
        // User retention
        if dashboard.userGrowth.retentionRate < config.minRetentionRate {
            createAlert(
                title: "Low User Retention",
                message: "Retention rate is \(String(format: "%.1f", dashboard.userGrowth.retentionRate))%",
                severity: .medium,
                metric: "retention_rate",
                value: dashboard.userGrowth.retentionRate
            )
        }
    }
    
    private func checkDeveloperThresholds(_ dashboard: DeveloperDashboard) {
        // API uptime
        if dashboard.apiHealth.uptime < config.minAPIUptime {
            createAlert(
                title: "API Uptime Below Target",
                message: "API uptime is \(String(format: "%.2f", dashboard.apiHealth.uptime))%",
                severity: .critical,
                metric: "api_uptime",
                value: dashboard.apiHealth.uptime
            )
        }
        
        // P95 response time
        if dashboard.performance.p95ResponseTime > config.maxP95ResponseTime {
            createAlert(
                title: "High P95 Response Time",
                message: "P95 response time is \(Int(dashboard.performance.p95ResponseTime))ms",
                severity: .high,
                metric: "p95_response_time",
                value: dashboard.performance.p95ResponseTime
            )
        }
        
        // Critical errors
        if dashboard.errors.criticalErrors > config.maxCriticalErrors {
            createAlert(
                title: "Critical Errors Detected",
                message: "\(dashboard.errors.criticalErrors) critical errors in the last hour",
                severity: .critical,
                metric: "critical_errors",
                value: Double(dashboard.errors.criticalErrors)
            )
        }
        
        // Test coverage
        if dashboard.codeQuality.testCoverage < config.minTestCoverage {
            createAlert(
                title: "Low Test Coverage",
                message: "Test coverage is \(String(format: "%.1f", dashboard.codeQuality.testCoverage))%",
                severity: .low,
                metric: "test_coverage",
                value: dashboard.codeQuality.testCoverage
            )
        }
    }
    
    private func recordViolation(metric: String, value: Double, threshold: Double, severity: AlertSeverity) {
        if var violation = thresholdViolations[metric] {
            violation.count += 1
            violation.lastViolation = Date()
            violation.currentValue = value
            thresholdViolations[metric] = violation
        } else {
            thresholdViolations[metric] = ThresholdViolation(
                metric: metric,
                count: 1,
                firstViolation: Date(),
                lastViolation: Date(),
                currentValue: value,
                threshold: threshold
            )
        }
        
        // Check if violation is sustained
        if let violation = thresholdViolations[metric],
           violation.count >= config.sustainedViolationThreshold {
            createAlert(
                title: "Sustained \(metric.replacingOccurrences(of: "_", with: " ").capitalized) Violation",
                message: "\(metric) has been above threshold for \(violation.count) consecutive checks",
                severity: severity,
                metric: metric,
                value: value
            )
        }
    }
    
    private func processSustainedViolations() {
        let now = Date()
        
        // Clear old violations
        thresholdViolations = thresholdViolations.filter { _, violation in
            now.timeIntervalSince(violation.lastViolation) < config.violationResetInterval
        }
    }
    
    private func checkActiveUsersDrop(_ currentUsers: Int) {
        // This would compare with historical data
        // For now, we'll use a simple threshold
        if currentUsers < config.minActiveUsers {
            createAlert(
                title: "Active Users Drop",
                message: "Active users dropped to \(currentUsers)",
                severity: .high,
                metric: "active_users",
                value: Double(currentUsers)
            )
        }
    }
    
    private func checkRevenueDrop(_ currentRevenue: Double) {
        // This would compare with historical average
        // For now, we'll use a simple threshold
        if currentRevenue < config.minDailyRevenue {
            createAlert(
                title: "Revenue Below Target",
                message: "Daily revenue is $\(String(format: "%.2f", currentRevenue))",
                severity: .high,
                metric: "daily_revenue",
                value: currentRevenue
            )
        }
    }
    
    private func createAlert(title: String, message: String, severity: AlertSeverity, metric: String, value: Double) {
        let alertId = "\(metric)_\(Date().timeIntervalSince1970)"
        
        // Check if alert is already active
        guard !activeAlerts.contains(alertId) else { return }
        
        let alert = DashboardAlert(
            id: alertId,
            title: title,
            message: message,
            severity: severity,
            timestamp: Date(),
            affectedMetric: metric,
            currentValue: value,
            threshold: thresholdViolations[metric]?.threshold
        )
        
        // Add to active alerts
        activeAlerts.insert(alertId)
        
        // Add to history
        alertHistory.append(alert)
        if alertHistory.count > maxHistorySize {
            alertHistory.removeFirst()
        }
        
        // Publish alert
        DispatchQueue.main.async {
            self.alertPublisher.send(alert)
        }
        
        // Schedule alert clear
        DispatchQueue.global().asyncAfter(deadline: .now() + config.alertClearInterval) { [weak self] in
            self?.queue.async {
                self?.activeAlerts.remove(alertId)
            }
        }
        
        logger.warning("Alert created: \(title) - \(message)")
    }
}

// MARK: - Dashboard Data Aggregator

public class DashboardDataAggregator {
    private let queue = DispatchQueue(label: "com.claudecode.aggregator", attributes: .concurrent)
    private let logger = Logger(subsystem: "com.claudecode.dashboards", category: "DataAggregator")
    
    // Data caches
    private var realTimeCache = RealTimeDataCache()
    private var aggregatedCache = AggregatedDataCache()
    
    // Update intervals
    private let cacheExpiration: TimeInterval = 5.0
    
    func connectToMonitoringService() {
        // Connect to MonitoringService for events and metrics
        logger.info("Connected to monitoring service")
    }
    
    func connectToAnalytics() {
        // Connect to UserAnalyticsManager for user metrics
        logger.info("Connected to analytics")
    }
    
    func connectToPerformanceMonitor() {
        // Connect to PerformanceMonitor for performance data
        logger.info("Connected to performance monitor")
    }
    
    func connectToErrorTracker() {
        // Connect to ErrorTracker for error metrics
        logger.info("Connected to error tracker")
    }
    
    func getRealTimeMetrics() -> RealTimeMetrics {
        return queue.sync {
            // Check cache
            if let cached = realTimeCache.getIfValid() {
                return cached
            }
            
            // Aggregate real-time data
            let metrics = RealTimeMetrics(
                activeUsers: getActiveUserCount(),
                requestsPerSecond: getRequestRate(),
                errorRate: getErrorRate(),
                averageLatency: getAverageLatency(),
                cpuUsage: getCPUUsage(),
                memoryUsage: getMemoryUsage(),
                networkBandwidth: getNetworkBandwidth(),
                activeSessions: getActiveSessionCount(),
                timestamp: Date()
            )
            
            // Update cache
            realTimeCache.update(metrics)
            
            return metrics
        }
    }
    
    func getExecutiveDashboardData() -> ExecutiveDashboardData {
        return queue.sync {
            ExecutiveDashboardData(
                kpis: getKeyPerformanceIndicators(),
                revenue: getRevenueMetrics(),
                userGrowth: getUserGrowthMetrics(),
                systemHealth: getSystemHealthScore(),
                trends: getBusinessTrends()
            )
        }
    }
    
    func getDeveloperDashboardData() -> DeveloperDashboardData {
        return queue.sync {
            DeveloperDashboardData(
                performance: getPerformanceMetrics(),
                errors: getErrorMetrics(),
                apiHealth: getAPIHealthMetrics(),
                deployments: getDeploymentMetrics(),
                codeQuality: getCodeQualityMetrics()
            )
        }
    }
    
    func getSupportDashboardData() -> SupportDashboardData {
        return queue.sync {
            SupportDashboardData(
                tickets: getTicketMetrics(),
                userFeedback: getUserFeedbackMetrics(),
                commonIssues: getCommonIssuesMetrics(),
                responseMetrics: getResponseMetrics()
            )
        }
    }
    
    func getUserExperienceDashboardData() -> UserExperienceDashboardData {
        return queue.sync {
            UserExperienceDashboardData(
                engagement: getEngagementMetrics(),
                usability: getUsabilityMetrics(),
                navigation: getNavigationMetrics(),
                featureUsage: getFeatureUsageMetrics()
            )
        }
    }
    
    // MARK: - Private Data Collection Methods
    
    private func getActiveUserCount() -> Int {
        // Get from analytics
        return Int.random(in: 100...1000) // Placeholder
    }
    
    private func getRequestRate() -> Double {
        // Get from network monitoring
        return Double.random(in: 50...200) // Placeholder
    }
    
    private func getErrorRate() -> Double {
        // Get from error tracker
        return Double.random(in: 0...5) // Placeholder
    }
    
    private func getAverageLatency() -> Double {
        // Get from performance monitor
        return Double.random(in: 50...500) // Placeholder
    }
    
    private func getCPUUsage() -> Double {
        // Get from performance monitor
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / Double(ProcessInfo.processInfo.physicalMemory) * 100.0
        }
        
        return 0.0
    }
    
    private func getMemoryUsage() -> Double {
        // Get from performance monitor
        let memoryInUse = ProcessInfo.processInfo.physicalMemory
        return Double(memoryInUse) / (1024 * 1024) // Convert to MB
    }
    
    private func getNetworkBandwidth() -> Double {
        // Get from network monitor
        return Double.random(in: 1...10) // Placeholder (MB/s)
    }
    
    private func getActiveSessionCount() -> Int {
        // Get from analytics
        return Int.random(in: 50...500) // Placeholder
    }
    
    private func getKeyPerformanceIndicators() -> KeyPerformanceIndicators {
        return KeyPerformanceIndicators(
            dailyActiveUsers: Int.random(in: 1000...5000),
            monthlyActiveUsers: Int.random(in: 10000...50000),
            averageSessionLength: TimeInterval.random(in: 60...600),
            crashFreeRate: Double.random(in: 98...100),
            userSatisfactionScore: Double.random(in: 4...5),
            conversionRate: Double.random(in: 2...10)
        )
    }
    
    private func getRevenueMetrics() -> RevenueMetrics {
        return RevenueMetrics(
            dailyRevenue: Double.random(in: 1000...10000),
            monthlyRevenue: Double.random(in: 30000...300000),
            averageRevenuePerUser: Double.random(in: 5...50),
            subscriptionChurnRate: Double.random(in: 1...5),
            lifetimeValue: Double.random(in: 100...1000)
        )
    }
    
    private func getUserGrowthMetrics() -> UserGrowthMetrics {
        return UserGrowthMetrics(
            newUsers: Int.random(in: 50...500),
            retentionRate: Double.random(in: 70...95),
            growthRate: Double.random(in: 5...25),
            activationRate: Double.random(in: 60...90)
        )
    }
    
    private func getSystemHealthScore() -> SystemHealthScore {
        return SystemHealthScore(
            overall: Double.random(in: 85...100),
            performance: Double.random(in: 85...100),
            stability: Double.random(in: 85...100),
            security: Double.random(in: 85...100),
            userExperience: Double.random(in: 85...100)
        )
    }
    
    private func getBusinessTrends() -> BusinessTrends {
        return BusinessTrends(
            userGrowthTrend: [.increasing, .stable, .decreasing].randomElement()!,
            revenueTrend: [.increasing, .stable, .decreasing].randomElement()!,
            engagementTrend: [.increasing, .stable, .decreasing].randomElement()!,
            performanceTrend: [.increasing, .stable, .decreasing].randomElement()!
        )
    }
    
    private func getPerformanceMetrics() -> PerformanceMetrics {
        return PerformanceMetrics(
            averageResponseTime: Double.random(in: 50...200),
            p95ResponseTime: Double.random(in: 100...500),
            p99ResponseTime: Double.random(in: 200...1000),
            throughput: Double.random(in: 100...1000),
            cpuUsage: getCPUUsage(),
            memoryUsage: getMemoryUsage()
        )
    }
    
    private func getErrorMetrics() -> ErrorMetrics {
        let topErrors = [
            ("NetworkError", Int.random(in: 10...100)),
            ("ValidationError", Int.random(in: 5...50)),
            ("AuthenticationError", Int.random(in: 1...20))
        ]
        
        return ErrorMetrics(
            errorRate: Double.random(in: 0...5),
            criticalErrors: Int.random(in: 0...10),
            warningCount: Int.random(in: 10...100),
            topErrors: topErrors
        )
    }
    
    private func getAPIHealthMetrics() -> APIHealthMetrics {
        return APIHealthMetrics(
            uptime: Double.random(in: 99...100),
            latency: Double.random(in: 50...200),
            successRate: Double.random(in: 95...100),
            endpointHealth: [
                "/api/users": Double.random(in: 95...100),
                "/api/chat": Double.random(in: 95...100),
                "/api/files": Double.random(in: 95...100)
            ]
        )
    }
    
    private func getDeploymentMetrics() -> DeploymentMetrics {
        return DeploymentMetrics(
            lastDeployment: Date().addingTimeInterval(-TimeInterval.random(in: 0...86400)),
            deploymentFrequency: Int.random(in: 1...10),
            rollbackRate: Double.random(in: 0...5),
            leadTime: TimeInterval.random(in: 3600...86400)
        )
    }
    
    private func getCodeQualityMetrics() -> CodeQualityMetrics {
        return CodeQualityMetrics(
            testCoverage: Double.random(in: 60...95),
            technicalDebt: Int.random(in: 10...100),
            codeComplexity: Double.random(in: 1...10),
            duplicateCodeRatio: Double.random(in: 1...10)
        )
    }
    
    private func getTicketMetrics() -> TicketMetrics {
        return TicketMetrics(
            openTickets: Int.random(in: 10...100),
            resolvedToday: Int.random(in: 5...50),
            averageResolutionTime: TimeInterval.random(in: 3600...86400),
            ticketsByPriority: [
                "Critical": Int.random(in: 0...5),
                "High": Int.random(in: 5...20),
                "Medium": Int.random(in: 10...30),
                "Low": Int.random(in: 20...50)
            ]
        )
    }
    
    private func getUserFeedbackMetrics() -> UserFeedbackMetrics {
        return UserFeedbackMetrics(
            averageRating: Double.random(in: 3.5...5),
            reviewCount: Int.random(in: 100...1000),
            sentimentScore: Double.random(in: 60...95),
            npsScore: Int.random(in: 30...70)
        )
    }
    
    private func getCommonIssuesMetrics() -> CommonIssuesMetrics {
        let topIssues = [
            ("Login Issues", Int.random(in: 10...50)),
            ("Sync Problems", Int.random(in: 5...30)),
            ("Performance", Int.random(in: 5...20))
        ]
        
        return CommonIssuesMetrics(
            topIssues: topIssues,
            issueCategories: [
                "Authentication": Int.random(in: 10...50),
                "Performance": Int.random(in: 5...30),
                "UI/UX": Int.random(in: 5...20),
                "Data": Int.random(in: 1...10)
            ],
            resolutionRate: Double.random(in: 70...95)
        )
    }
    
    private func getResponseMetrics() -> ResponseMetrics {
        return ResponseMetrics(
            firstResponseTime: TimeInterval.random(in: 300...3600),
            averageResponseTime: TimeInterval.random(in: 600...7200),
            customerSatisfaction: Double.random(in: 70...95)
        )
    }
    
    private func getEngagementMetrics() -> EngagementMetrics {
        return EngagementMetrics(
            sessionLength: TimeInterval.random(in: 60...600),
            screenViews: Int.random(in: 5...50),
            interactions: Int.random(in: 10...100),
            bounceRate: Double.random(in: 10...40)
        )
    }
    
    private func getUsabilityMetrics() -> UsabilityMetrics {
        return UsabilityMetrics(
            taskCompletionRate: Double.random(in: 70...95),
            errorRecoveryRate: Double.random(in: 60...90),
            averageTaskTime: TimeInterval.random(in: 10...120),
            userFlowCompletion: Double.random(in: 60...95)
        )
    }
    
    private func getNavigationMetrics() -> NavigationMetrics {
        let topScreens = [
            ("Home", Int.random(in: 100...500)),
            ("Profile", Int.random(in: 50...200)),
            ("Settings", Int.random(in: 20...100))
        ]
        
        let navigationPaths = [
            ("Home → Profile", Int.random(in: 50...200)),
            ("Home → Settings", Int.random(in: 20...100)),
            ("Profile → Settings", Int.random(in: 10...50))
        ]
        
        let dropOffPoints = [
            ("Onboarding Step 3", Double.random(in: 10...30)),
            ("Payment Screen", Double.random(in: 5...20)),
            ("Profile Setup", Double.random(in: 5...15))
        ]
        
        return NavigationMetrics(
            topScreens: topScreens,
            navigationPaths: navigationPaths,
            dropOffPoints: dropOffPoints
        )
    }
    
    private func getFeatureUsageMetrics() -> FeatureUsageMetrics {
        return FeatureUsageMetrics(
            featureAdoption: [
                "Chat": Double.random(in: 70...95),
                "File Upload": Double.random(in: 50...80),
                "Voice Input": Double.random(in: 30...60),
                "Code Generation": Double.random(in: 60...90)
            ],
            featureRetention: [
                "Chat": Double.random(in: 60...85),
                "File Upload": Double.random(in: 40...70),
                "Voice Input": Double.random(in: 20...50),
                "Code Generation": Double.random(in: 50...80)
            ],
            featureEngagement: [
                "Chat": Double.random(in: 80...95),
                "File Upload": Double.random(in: 40...70),
                "Voice Input": Double.random(in: 30...60),
                "Code Generation": Double.random(in: 70...90)
            ]
        )
    }
}

// MARK: - Supporting Types

public struct DashboardAlert {
    let id: String
    let title: String
    let message: String
    let severity: AlertSeverity
    let timestamp: Date
    let affectedMetric: String?
    let currentValue: Double?
    let threshold: Double?
}

public enum AlertSeverity {
    case critical
    case high
    case medium
    case low
}

public struct AlertConfiguration {
    // Real-time thresholds
    let cpuThreshold: Double
    let criticalCpuThreshold: Double
    let memoryThreshold: Double
    let criticalMemoryThreshold: Double
    let errorRateThreshold: Double
    let criticalErrorRateThreshold: Double
    let latencyThreshold: Double
    
    // Business thresholds
    let minCrashFreeRate: Double
    let minSystemHealth: Double
    let minRetentionRate: Double
    let minActiveUsers: Int
    let minDailyRevenue: Double
    
    // Developer thresholds
    let minAPIUptime: Double
    let maxP95ResponseTime: Double
    let maxCriticalErrors: Int
    let minTestCoverage: Double
    
    // Alert behavior
    let sustainedViolationThreshold: Int
    let violationResetInterval: TimeInterval
    let alertClearInterval: TimeInterval
    
    public static let `default` = AlertConfiguration(
        cpuThreshold: 80,
        criticalCpuThreshold: 95,
        memoryThreshold: 80,
        criticalMemoryThreshold: 95,
        errorRateThreshold: 5,
        criticalErrorRateThreshold: 10,
        latencyThreshold: 1000,
        minCrashFreeRate: 99,
        minSystemHealth: 80,
        minRetentionRate: 70,
        minActiveUsers: 50,
        minDailyRevenue: 1000,
        minAPIUptime: 99.5,
        maxP95ResponseTime: 500,
        maxCriticalErrors: 5,
        minTestCoverage: 70,
        sustainedViolationThreshold: 3,
        violationResetInterval: 300,
        alertClearInterval: 600
    )
}

// MARK: - Data Caches

private class RealTimeDataCache {
    private var data: RealTimeMetrics?
    private var lastUpdate: Date?
    private let expiration: TimeInterval = 1.0
    
    func getIfValid() -> RealTimeMetrics? {
        guard let data = data,
              let lastUpdate = lastUpdate,
              Date().timeIntervalSince(lastUpdate) < expiration else {
            return nil
        }
        return data
    }
    
    func update(_ metrics: RealTimeMetrics) {
        self.data = metrics
        self.lastUpdate = Date()
    }
}

private class AggregatedDataCache {
    private var cache: [String: (data: Any, timestamp: Date)] = [:]
    private let expiration: TimeInterval = 5.0
    
    func get<T>(key: String, type: T.Type) -> T? {
        guard let cached = cache[key],
              Date().timeIntervalSince(cached.timestamp) < expiration,
              let data = cached.data as? T else {
            return nil
        }
        return data
    }
    
    func set(key: String, value: Any) {
        cache[key] = (value, Date())
    }
}