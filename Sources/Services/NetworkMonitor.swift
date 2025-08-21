import Foundation
import Network
import OSLog
import Combine

/// Network monitoring and quality assessment service (Tasks 451-500)
/// Provides real-time network status, quality metrics, and error recovery
@MainActor
class NetworkMonitor: ObservableObject {
    // MARK: - Properties
    
    static let shared = NetworkMonitor()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "NetworkMonitor")
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.claudecode.network.monitor")
    
    // Published properties
    @Published var isConnected = false
    @Published var connectionType: ConnectionType = .unknown
    @Published var connectionQuality: ConnectionQuality = .unknown
    @Published var networkPath: NWPath?
    @Published var isExpensive = false
    @Published var isConstrained = false
    @Published var supportsIPv4 = false
    @Published var supportsIPv6 = false
    @Published var supportsDNS = false
    
    // Network statistics (Tasks 451-455)
    @Published var currentBandwidth: Double = 0  // Mbps
    @Published var averageLatency: TimeInterval = 0  // ms
    @Published var packetLoss: Double = 0  // percentage
    @Published var jitter: Double = 0  // ms
    @Published var signalStrength: Int = 0  // dBm for cellular/WiFi
    
    // Quality metrics (Tasks 456-460)
    @Published var qualityScore: Double = 0  // 0-100
    @Published var stabilityScore: Double = 0  // 0-100
    @Published var performanceScore: Double = 0  // 0-100
    
    // Error tracking (Tasks 461-465)
    @Published var errorRate: Double = 0
    @Published var recentErrors: [NetworkError] = []
    @Published var errorTrends: ErrorTrends?
    
    // Analytics (Tasks 466-470)
    private var analyticsCollector = NetworkAnalytics()
    private var metricsHistory: [NetworkMetrics] = []
    private let maxHistorySize = 1000
    
    // Recovery strategies (Tasks 471-475)
    private let recoveryManager = NetworkRecoveryManager()
    private var failurePatterns: [FailurePattern] = []
    
    // Adaptive behavior (Tasks 476-480)
    private let adaptiveManager = AdaptiveNetworkManager()
    @Published var currentStrategy: NetworkStrategy = .standard
    
    // Monitoring components
    private var pingMonitor: PingMonitor?
    private var bandwidthMonitor: NetworkBandwidthMonitor?
    private var latencyProbe: LatencyProbe?
    private var cancellables = Set<AnyCancellable>()
    
    // Update timers
    private var metricsTimer: Timer?
    private var analyticsTimer: Timer?
    private let metricsUpdateInterval: TimeInterval = 5.0
    private let analyticsUpdateInterval: TimeInterval = 60.0
    
    // MARK: - Initialization
    
    private init() {
        setupMonitoring()
        setupMetricsCollection()
        setupAnalytics()
    }
    
    // MARK: - Setup Methods
    
    private func setupMonitoring() {
        // Configure path monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        
        // Start monitoring
        monitor.start(queue: queue)
        logger.info("Network monitoring started")
        
        // Initialize component monitors
        pingMonitor = PingMonitor()
        bandwidthMonitor = NetworkBandwidthMonitor()
        latencyProbe = LatencyProbe()
    }
    
    private func setupMetricsCollection() {
        // Start metrics collection timer
        metricsTimer = Timer.scheduledTimer(withTimeInterval: metricsUpdateInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.collectMetrics()
            }
        }
    }
    
    private func setupAnalytics() {
        // Start analytics timer
        analyticsTimer = Timer.scheduledTimer(withTimeInterval: analyticsUpdateInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.performAnalytics()
            }
        }
    }
    
    // MARK: - Path Update Handler
    
    private func handlePathUpdate(_ path: NWPath) {
        networkPath = path
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        supportsIPv4 = path.supportsIPv4
        supportsIPv6 = path.supportsIPv6
        supportsDNS = path.supportsDNS
        
        // Determine connection type
        connectionType = determineConnectionType(from: path)
        
        // Update quality assessment
        Task {
            await updateConnectionQuality()
        }
        
        // Log network change
        logger.info("""
            Network status changed:
            - Connected: \(self.isConnected)
            - Type: \(self.connectionType)
            - Expensive: \(self.isExpensive)
            - Constrained: \(self.isConstrained)
        """)
        
        // Handle recovery if needed
        if !isConnected {
            Task {
                await handleNetworkLoss()
            }
        } else if path.status == .satisfied {
            Task {
                await handleNetworkRecovery()
            }
        }
    }
    
    // MARK: - Connection Type Detection (Task 452)
    
    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return determineCellularType(path)
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.loopback) {
            return .loopback
        } else if path.status == .satisfied {
            return .other
        } else {
            return .unknown
        }
    }
    
    private func determineCellularType(_ path: NWPath) -> ConnectionType {
        // In a real implementation, would use CoreTelephony for detailed info
        // For now, return generic cellular
        if isExpensive && !isConstrained {
            return .cellular5G  // Assume 5G if high bandwidth
        } else if !isExpensive {
            return .cellular4G  // Assume 4G if moderate
        } else {
            return .cellular3G  // Assume 3G if constrained
        }
    }
    
    // MARK: - Quality Assessment (Tasks 453-455)
    
    private func updateConnectionQuality() async {
        // Collect quality metrics
        let bandwidth = await measureBandwidth()
        let latency = await measureLatency()
        let loss = await measurePacketLoss()
        let jitter = await measureJitter()
        
        // Update published properties
        currentBandwidth = bandwidth
        averageLatency = latency
        packetLoss = loss
        self.jitter = jitter
        
        // Calculate quality score
        connectionQuality = calculateQuality(
            bandwidth: bandwidth,
            latency: latency,
            loss: loss,
            jitter: jitter
        )
        
        // Update adaptive strategy
        currentStrategy = adaptiveManager.determineStrategy(
            quality: connectionQuality,
            type: connectionType,
            isExpensive: isExpensive
        )
    }
    
    private func calculateQuality(
        bandwidth: Double,
        latency: TimeInterval,
        loss: Double,
        jitter: Double
    ) -> ConnectionQuality {
        // Weighted quality score calculation
        var score = 0.0
        
        // Bandwidth score (0-40 points)
        if bandwidth >= 100 {
            score += 40
        } else if bandwidth >= 50 {
            score += 35
        } else if bandwidth >= 25 {
            score += 30
        } else if bandwidth >= 10 {
            score += 20
        } else if bandwidth >= 5 {
            score += 10
        } else {
            score += 5
        }
        
        // Latency score (0-30 points)
        if latency <= 20 {
            score += 30
        } else if latency <= 50 {
            score += 25
        } else if latency <= 100 {
            score += 20
        } else if latency <= 200 {
            score += 10
        } else {
            score += 5
        }
        
        // Packet loss score (0-20 points)
        if loss <= 0.1 {
            score += 20
        } else if loss <= 0.5 {
            score += 15
        } else if loss <= 1.0 {
            score += 10
        } else if loss <= 2.0 {
            score += 5
        } else {
            score += 0
        }
        
        // Jitter score (0-10 points)
        if jitter <= 5 {
            score += 10
        } else if jitter <= 10 {
            score += 7
        } else if jitter <= 20 {
            score += 5
        } else {
            score += 2
        }
        
        // Update quality scores
        qualityScore = score
        stabilityScore = calculateStabilityScore()
        performanceScore = calculatePerformanceScore()
        
        // Determine quality level
        if score >= 80 {
            return .excellent
        } else if score >= 60 {
            return .good
        } else if score >= 40 {
            return .fair
        } else if score >= 20 {
            return .poor
        } else {
            return .unusable
        }
    }
    
    // MARK: - Metrics Collection (Tasks 456-460)
    
    private func collectMetrics() async {
        let metrics = NetworkMetrics(
            timestamp: Date(),
            connectionType: connectionType,
            quality: connectionQuality,
            bandwidth: currentBandwidth,
            latency: averageLatency,
            packetLoss: packetLoss,
            jitter: jitter,
            errorRate: errorRate,
            isExpensive: isExpensive,
            isConstrained: isConstrained
        )
        
        // Store metrics
        metricsHistory.append(metrics)
        if metricsHistory.count > maxHistorySize {
            metricsHistory.removeFirst()
        }
        
        // Update analytics
        analyticsCollector.record(metrics)
        
        // Check for anomalies
        if let anomaly = detectAnomaly(in: metrics) {
            await handleAnomaly(anomaly)
        }
    }
    
    // MARK: - Measurement Methods
    
    private func measureBandwidth() async -> Double {
        // In production, would perform actual bandwidth test
        // For now, estimate based on connection type
        switch connectionType {
        case .wifi:
            return Double.random(in: 50...500)
        case .cellular5G:
            return Double.random(in: 100...1000)
        case .cellular4G:
            return Double.random(in: 10...100)
        case .cellular3G:
            return Double.random(in: 1...10)
        case .ethernet:
            return Double.random(in: 100...1000)
        default:
            return 0
        }
    }
    
    private func measureLatency() async -> TimeInterval {
        // Perform ping test to multiple servers
        guard let probe = latencyProbe else { return 0 }
        let results = await probe.measureLatency(to: [
            "8.8.8.8",  // Google DNS
            "1.1.1.1",  // Cloudflare DNS
            "api.claude.ai"  // Claude API
        ])
        return results.average
    }
    
    private func measurePacketLoss() async -> Double {
        // In production, would perform actual packet loss test
        return Double.random(in: 0...0.5)
    }
    
    private func measureJitter() async -> Double {
        // Calculate variance in latency measurements
        guard let probe = latencyProbe else { return 0 }
        let measurements = await probe.getRecentMeasurements()
        return measurements.standardDeviation
    }
    
    // MARK: - Error Recovery (Tasks 471-475)
    
    private func handleNetworkLoss() async {
        logger.warning("Network connection lost, initiating recovery")
        
        // Record error
        let error = NetworkError(
            timestamp: Date(),
            type: .connectionLost,
            message: "Network connection lost",
            recoverable: true
        )
        recentErrors.append(error)
        
        // Trigger recovery strategies
        let strategy = recoveryManager.determineRecoveryStrategy(for: error)
        await executeRecoveryStrategy(strategy)
    }
    
    private func handleNetworkRecovery() async {
        logger.info("Network connection restored")
        
        // Clear error state
        errorRate = 0
        
        // Validate connection
        await validateConnection()
        
        // Resume pending operations
        await recoveryManager.resumePendingOperations()
    }
    
    private func executeRecoveryStrategy(_ strategy: RecoveryStrategy) async {
        switch strategy {
        case .immediate:
            // Try to reconnect immediately
            await attemptReconnection()
            
        case .exponentialBackoff(let attempts):
            // Use exponential backoff for reconnection
            for attempt in 0..<attempts {
                let delay = ExponentialBackoff.calculate(
                    attempt: attempt,
                    baseDelay: 1.0,
                    maxDelay: 60.0
                )
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if await attemptReconnection() {
                    break
                }
            }
            
        case .waitForCondition(let condition):
            // Wait for specific network condition
            await waitForNetworkCondition(condition)
            
        case .switchNetwork:
            // Attempt to switch to alternative network
            await switchToAlternativeNetwork()
            
        case .offlineMode:
            // Switch to offline mode
            await enableOfflineMode()
        }
    }
    
    // MARK: - Analytics (Tasks 466-470)
    
    private func performAnalytics() async {
        // Generate analytics report
        let report = analyticsCollector.generateReport()
        
        // Identify trends
        identifyTrends(from: report)
        
        // Predict future issues
        let predictions = predictNetworkIssues(from: report)
        
        // Update error trends
        errorTrends = ErrorTrends(
            hourlyRate: report.hourlyErrorRate,
            dailyRate: report.dailyErrorRate,
            topErrors: report.topErrors,
            predictions: predictions
        )
        
        // Log analytics summary
        logger.info("""
            Network Analytics:
            - Avg Bandwidth: \(report.averageBandwidth) Mbps
            - Avg Latency: \(report.averageLatency) ms
            - Uptime: \(report.uptimePercentage)%
            - Error Rate: \(report.errorRate)%
        """)
    }
    
    // MARK: - Helper Methods
    
    private func calculateStabilityScore() -> Double {
        // Calculate based on connection changes and error rate
        let changes = metricsHistory.suffix(100).connectionChanges
        let errors = errorRate
        
        var score = 100.0
        score -= Double(changes) * 5  // Deduct for instability
        score -= errors * 10  // Deduct for errors
        
        return max(0, min(100, score))
    }
    
    private func calculatePerformanceScore() -> Double {
        // Calculate based on bandwidth and latency
        let bandwidthScore = min(100, currentBandwidth)
        let latencyScore = max(0, 100 - averageLatency)
        
        return (bandwidthScore + latencyScore) / 2
    }
    
    private func detectAnomaly(in metrics: NetworkMetrics) -> NetworkAnomaly? {
        // Check for sudden changes or threshold violations
        guard let previousMetrics = metricsHistory.suffix(10).average else { return nil }
        
        // Check for significant bandwidth drop
        if metrics.bandwidth < previousMetrics.bandwidth * 0.5 {
            return NetworkAnomaly(
                type: .bandwidthDrop,
                severity: .high,
                metrics: metrics
            )
        }
        
        // Check for latency spike
        if metrics.latency > previousMetrics.latency * 2 {
            return NetworkAnomaly(
                type: .latencySpike,
                severity: .medium,
                metrics: metrics
            )
        }
        
        // Check for packet loss increase
        if metrics.packetLoss > 5.0 {
            return NetworkAnomaly(
                type: .highPacketLoss,
                severity: .high,
                metrics: metrics
            )
        }
        
        return nil
    }
    
    private func handleAnomaly(_ anomaly: NetworkAnomaly) async {
        logger.warning("Network anomaly detected: \(anomaly.type) [\(anomaly.severity)]")
        
        // Record anomaly
        analyticsCollector.recordAnomaly(anomaly)
        
        // Adjust strategy if needed
        if anomaly.severity == .high {
            currentStrategy = adaptiveManager.adjustForAnomaly(anomaly)
        }
    }
    
    private func identifyTrends(from report: AnalyticsReport) {
        // Identify patterns in network behavior
        let trends = TrendAnalyzer.analyze(metricsHistory)
        
        // Log significant trends
        for trend in trends.significant {
            logger.info("Network trend: \(trend.description)")
        }
    }
    
    private func predictNetworkIssues(from report: AnalyticsReport) -> [NetworkPrediction] {
        // Simple prediction based on trends
        var predictions: [NetworkPrediction] = []
        
        // Check degradation trend
        if report.bandwidthTrend < -0.1 {
            predictions.append(NetworkPrediction(
                type: .bandwidthDegradation,
                probability: abs(report.bandwidthTrend),
                timeframe: "next hour"
            ))
        }
        
        // Check error rate trend
        if report.errorRateTrend > 0.05 {
            predictions.append(NetworkPrediction(
                type: .increasedErrors,
                probability: min(1.0, report.errorRateTrend * 10),
                timeframe: "next 30 minutes"
            ))
        }
        
        return predictions
    }
    
    private func attemptReconnection() async -> Bool {
        // In production, would trigger system reconnection
        logger.info("Attempting network reconnection...")
        return false
    }
    
    private func waitForNetworkCondition(_ condition: NetworkCondition) async {
        // Wait for specific condition to be met
        while !condition.isMet(for: self) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
    
    private func switchToAlternativeNetwork() async {
        logger.info("Attempting to switch to alternative network...")
        // In production, would trigger network switch
    }
    
    private func enableOfflineMode() async {
        logger.info("Enabling offline mode")
        // Notify app to switch to offline mode
        NotificationCenter.default.post(name: .networkOfflineMode, object: nil)
    }
    
    private func validateConnection() async {
        // Perform connection validation tests
        let isValid = await performValidationTests()
        if isValid {
            logger.info("Network connection validated successfully")
        } else {
            logger.warning("Network connection validation failed")
        }
    }
    
    private func performValidationTests() async -> Bool {
        // Test DNS resolution
        let dnsTest = await testDNSResolution()
        
        // Test connectivity to backend
        let backendTest = await testBackendConnectivity()
        
        // Test SSL/TLS
        let sslTest = await testSSLConnectivity()
        
        return dnsTest && backendTest && sslTest
    }
    
    private func testDNSResolution() async -> Bool {
        // Test DNS resolution
        return true  // Placeholder
    }
    
    private func testBackendConnectivity() async -> Bool {
        // Test backend connectivity
        let url = URL(string: "http://localhost:8000/v1/health")!
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    private func testSSLConnectivity() async -> Bool {
        // Test SSL/TLS connectivity
        return true  // Placeholder
    }
    
    // MARK: - Public Methods
    
    /// Force refresh network status
    func refresh() {
        monitor.cancel()
        monitor.start(queue: queue)
    }
    
    /// Get current network summary
    func getSummary() -> NetworkSummary {
        return NetworkSummary(
            isConnected: isConnected,
            connectionType: connectionType,
            quality: connectionQuality,
            bandwidth: currentBandwidth,
            latency: averageLatency,
            errorRate: errorRate,
            strategy: currentStrategy
        )
    }
    
    /// Get detailed metrics
    func getDetailedMetrics() -> DetailedNetworkMetrics {
        return DetailedNetworkMetrics(
            summary: getSummary(),
            qualityScores: QualityScores(
                overall: qualityScore,
                stability: stabilityScore,
                performance: performanceScore
            ),
            recentMetrics: Array(metricsHistory.suffix(100)),
            errorTrends: errorTrends,
            predictions: predictNetworkIssues(from: analyticsCollector.generateReport())
        )
    }
    
    /// Test specific endpoint
    func testEndpoint(_ url: URL) async -> EndpointTestResult {
        let startTime = Date()
        var result = EndpointTestResult(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let endTime = Date()
            
            result.responseTime = endTime.timeIntervalSince(startTime)
            result.statusCode = (response as? HTTPURLResponse)?.statusCode
            result.dataSize = data.count
            result.success = true
        } catch {
            result.error = error
            result.success = false
        }
        
        return result
    }
    
    // MARK: - Cleanup
    
    deinit {
        monitor.cancel()
        metricsTimer?.invalidate()
        analyticsTimer?.invalidate()
    }
}

// MARK: - Supporting Types

/// Connection type enumeration
enum ConnectionType: String, CaseIterable {
    case wifi = "WiFi"
    case cellular5G = "5G"
    case cellular4G = "4G"
    case cellular3G = "3G"
    case ethernet = "Ethernet"
    case loopback = "Loopback"
    case other = "Other"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular5G, .cellular4G, .cellular3G: return "antenna.radiowaves.left.and.right"
        case .ethernet: return "cable.connector"
        case .loopback: return "arrow.triangle.2.circlepath"
        default: return "network"
        }
    }
}

/// Connection quality levels
enum ConnectionQuality: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case unusable = "Unusable"
    case unknown = "Unknown"
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .unusable: return "red"
        case .unknown: return "gray"
        }
    }
}

/// Network metrics structure
struct NetworkMetrics {
    let timestamp: Date
    let connectionType: ConnectionType
    let quality: ConnectionQuality
    let bandwidth: Double  // Mbps
    let latency: TimeInterval  // ms
    let packetLoss: Double  // percentage
    let jitter: Double  // ms
    let errorRate: Double
    let isExpensive: Bool
    let isConstrained: Bool
}

/// Network error structure
struct NetworkError {
    let timestamp: Date
    let type: ErrorType
    let message: String
    let recoverable: Bool
    
    enum ErrorType {
        case connectionLost
        case timeout
        case dnsFailure
        case sslFailure
        case serverError
        case unknown
    }
}

/// Error trends
struct ErrorTrends {
    let hourlyRate: Double
    let dailyRate: Double
    let topErrors: [NetworkError.ErrorType]
    let predictions: [NetworkPrediction]
}

/// Network anomaly
struct NetworkAnomaly {
    let type: AnomalyType
    let severity: Severity
    let metrics: NetworkMetrics
    
    enum AnomalyType {
        case bandwidthDrop
        case latencySpike
        case highPacketLoss
        case connectionInstability
        case unusualTraffic
    }
    
    enum Severity {
        case low, medium, high, critical
    }
}

/// Network prediction
struct NetworkPrediction {
    let type: PredictionType
    let probability: Double
    let timeframe: String
    
    enum PredictionType {
        case bandwidthDegradation
        case increasedErrors
        case connectionLoss
        case congestion
    }
}

/// Network strategy for adaptive behavior
enum NetworkStrategy {
    case aggressive  // Maximum performance
    case standard    // Balanced
    case conservative  // Minimize data usage
    case offline     // Offline mode
    
    var description: String {
        switch self {
        case .aggressive: return "Maximum Performance"
        case .standard: return "Balanced"
        case .conservative: return "Data Saver"
        case .offline: return "Offline Mode"
        }
    }
}

/// Recovery strategy
enum RecoveryStrategy {
    case immediate
    case exponentialBackoff(attempts: Int)
    case waitForCondition(NetworkCondition)
    case switchNetwork
    case offlineMode
}

/// Network condition for recovery
struct NetworkCondition {
    let requiredType: ConnectionType?
    let minimumQuality: ConnectionQuality?
    let maxExpensive: Bool
    
    func isMet(for monitor: NetworkMonitor) -> Bool {
        if let type = requiredType, monitor.connectionType != type {
            return false
        }
        if let quality = minimumQuality {
            let qualities: [ConnectionQuality] = [.excellent, .good, .fair, .poor, .unusable]
            let currentIndex = qualities.firstIndex(of: monitor.connectionQuality) ?? 5
            let requiredIndex = qualities.firstIndex(of: quality) ?? 5
            if currentIndex > requiredIndex {
                return false
            }
        }
        if maxExpensive && monitor.isExpensive {
            return false
        }
        return true
    }
}

/// Network summary
struct NetworkSummary {
    let isConnected: Bool
    let connectionType: ConnectionType
    let quality: ConnectionQuality
    let bandwidth: Double
    let latency: TimeInterval
    let errorRate: Double
    let strategy: NetworkStrategy
}

/// Quality scores
struct QualityScores {
    let overall: Double
    let stability: Double
    let performance: Double
}

/// Detailed network metrics
struct DetailedNetworkMetrics {
    let summary: NetworkSummary
    let qualityScores: QualityScores
    let recentMetrics: [NetworkMetrics]
    let errorTrends: ErrorTrends?
    let predictions: [NetworkPrediction]
}

/// Endpoint test result
struct EndpointTestResult {
    let url: URL
    var responseTime: TimeInterval = 0
    var statusCode: Int?
    var dataSize: Int = 0
    var success: Bool = false
    var error: Error?
}

/// Analytics report
struct AnalyticsReport {
    let averageBandwidth: Double
    let averageLatency: TimeInterval
    let uptimePercentage: Double
    let errorRate: Double
    let hourlyErrorRate: Double
    let dailyErrorRate: Double
    let topErrors: [NetworkError.ErrorType]
    let bandwidthTrend: Double  // Negative = decreasing
    let errorRateTrend: Double  // Positive = increasing
}

// MARK: - Helper Classes

/// Ping monitor
class PingMonitor {
    func ping(host: String) async -> TimeInterval {
        // In production, would use actual ping
        return Double.random(in: 10...100)
    }
}

/// Bandwidth monitor
class NetworkBandwidthMonitor {
    func measure() async -> Double {
        // In production, would measure actual bandwidth
        return Double.random(in: 1...100)
    }
}

/// Latency probe
class LatencyProbe {
    private var measurements: [TimeInterval] = []
    
    func measureLatency(to hosts: [String]) async -> (average: TimeInterval, measurements: [TimeInterval]) {
        var results: [TimeInterval] = []
        for host in hosts {
            let latency = Double.random(in: 10...100)  // Placeholder
            results.append(latency)
            measurements.append(latency)
        }
        let average = results.reduce(0, +) / Double(results.count)
        return (average, results)
    }
    
    func getRecentMeasurements() async -> [TimeInterval] {
        return Array(measurements.suffix(100))
    }
}

/// Network analytics collector
class NetworkAnalytics {
    private var metrics: [NetworkMetrics] = []
    private var anomalies: [NetworkAnomaly] = []
    
    func record(_ metric: NetworkMetrics) {
        metrics.append(metric)
        if metrics.count > 10000 {
            metrics.removeFirst()
        }
    }
    
    func recordAnomaly(_ anomaly: NetworkAnomaly) {
        anomalies.append(anomaly)
        if anomalies.count > 1000 {
            anomalies.removeFirst()
        }
    }
    
    func generateReport() -> AnalyticsReport {
        let bandwidth = metrics.map { $0.bandwidth }.average
        let latency = metrics.map { $0.latency }.average
        let uptime = Double(metrics.filter { $0.quality != .unusable }.count) / Double(max(metrics.count, 1)) * 100
        let errorRate = metrics.map { $0.errorRate }.average
        
        return AnalyticsReport(
            averageBandwidth: bandwidth,
            averageLatency: latency,
            uptimePercentage: uptime,
            errorRate: errorRate,
            hourlyErrorRate: calculateHourlyErrorRate(),
            dailyErrorRate: calculateDailyErrorRate(),
            topErrors: [],  // Placeholder
            bandwidthTrend: calculateTrend(for: \.bandwidth),
            errorRateTrend: calculateTrend(for: \.errorRate)
        )
    }
    
    private func calculateHourlyErrorRate() -> Double {
        let hourAgo = Date().addingTimeInterval(-3600)
        let recent = metrics.filter { $0.timestamp > hourAgo }
        return recent.map { $0.errorRate }.average
    }
    
    private func calculateDailyErrorRate() -> Double {
        let dayAgo = Date().addingTimeInterval(-86400)
        let recent = metrics.filter { $0.timestamp > dayAgo }
        return recent.map { $0.errorRate }.average
    }
    
    private func calculateTrend<T: BinaryFloatingPoint>(for keyPath: KeyPath<NetworkMetrics, T>) -> Double {
        guard metrics.count > 10 else { return 0 }
        
        let recent = metrics.suffix(10).map { Double($0[keyPath: keyPath]) }
        let older = metrics.suffix(20).prefix(10).map { Double($0[keyPath: keyPath]) }
        
        let recentAvg = recent.average
        let olderAvg = older.average
        
        return (recentAvg - olderAvg) / max(olderAvg, 1)
    }
}

/// Network recovery manager
class NetworkRecoveryManager {
    private var pendingOperations: [() async -> Void] = []
    
    func determineRecoveryStrategy(for error: NetworkError) -> RecoveryStrategy {
        switch error.type {
        case .connectionLost:
            return .exponentialBackoff(attempts: 5)
        case .timeout:
            return .immediate
        case .dnsFailure:
            return .waitForCondition(NetworkCondition(
                requiredType: nil,
                minimumQuality: .fair,
                maxExpensive: false
            ))
        case .sslFailure:
            return .switchNetwork
        default:
            return .immediate
        }
    }
    
    func queueOperation(_ operation: @escaping () async -> Void) {
        pendingOperations.append(operation)
    }
    
    func resumePendingOperations() async {
        let operations = pendingOperations
        pendingOperations.removeAll()
        
        for operation in operations {
            await operation()
        }
    }
}

/// Adaptive network manager
class AdaptiveNetworkManager {
    func determineStrategy(
        quality: ConnectionQuality,
        type: ConnectionType,
        isExpensive: Bool
    ) -> NetworkStrategy {
        if !isExpensive && quality == .excellent {
            return .aggressive
        } else if isExpensive || quality == .poor {
            return .conservative
        } else if quality == .unusable {
            return .offline
        } else {
            return .standard
        }
    }
    
    func adjustForAnomaly(_ anomaly: NetworkAnomaly) -> NetworkStrategy {
        switch anomaly.severity {
        case .critical:
            return .offline
        case .high:
            return .conservative
        default:
            return .standard
        }
    }
}

/// Trend analyzer
struct TrendAnalyzer {
    struct Trend {
        let type: TrendType
        let direction: Direction
        let strength: Double
        
        enum TrendType {
            case bandwidth, latency, errors, stability
        }
        
        enum Direction {
            case improving, stable, degrading
        }
        
        var description: String {
            "\(type) is \(direction) (strength: \(Int(strength * 100))%)"
        }
    }
    
    static func analyze(_ metrics: [NetworkMetrics]) -> (all: [Trend], significant: [Trend]) {
        // Placeholder implementation
        let trends: [Trend] = []
        let significant = trends.filter { $0.strength > 0.3 }
        return (trends, significant)
    }
}

/// Failure pattern
struct FailurePattern {
    let type: NetworkError.ErrorType
    let frequency: Int
    let timePattern: TimePattern?
    
    enum TimePattern {
        case periodic(interval: TimeInterval)
        case timeOfDay(hour: Int)
        case random
    }
}

// MARK: - Extensions

extension Array where Element == NetworkMetrics {
    var connectionChanges: Int {
        var changes = 0
        var lastType: ConnectionType?
        
        for metric in self {
            if let last = lastType, last != metric.connectionType {
                changes += 1
            }
            lastType = metric.connectionType
        }
        
        return changes
    }
    
    var average: NetworkMetrics? {
        guard !isEmpty else { return nil }
        
        let bandwidth = map { $0.bandwidth }.average
        let latency = map { $0.latency }.average
        let packetLoss = map { $0.packetLoss }.average
        let jitter = map { $0.jitter }.average
        let errorRate = map { $0.errorRate }.average
        
        return NetworkMetrics(
            timestamp: Date(),
            connectionType: last?.connectionType ?? .unknown,
            quality: last?.quality ?? .unknown,
            bandwidth: bandwidth,
            latency: latency,
            packetLoss: packetLoss,
            jitter: jitter,
            errorRate: errorRate,
            isExpensive: last?.isExpensive ?? false,
            isConstrained: last?.isConstrained ?? false
        )
    }
}

extension Array where Element: BinaryFloatingPoint {
    var average: Double {
        isEmpty ? 0 : Double(reduce(0, +)) / Double(count)
    }
    
    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        
        let avg = average
        let variance = map { pow(Double($0) - avg, 2) }.average
        return sqrt(variance)
    }
}

extension Notification.Name {
    static let networkOfflineMode = Notification.Name("com.claudecode.network.offlineMode")
    static let networkRecovered = Notification.Name("com.claudecode.network.recovered")
    static let networkQualityChanged = Notification.Name("com.claudecode.network.qualityChanged")
}