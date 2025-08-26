//
//  NetworkPerformanceMonitor.swift
//  ClaudeCode
//
//  Network performance monitoring and metrics collection
//

import Foundation
import Network
import os.log
import Combine

// MARK: - Network Performance Monitor

public final class NetworkPerformanceMonitor: NSObject {
    
    // MARK: - Singleton
    
    public static let shared = NetworkPerformanceMonitor()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.monitoring", category: "Network")
    private let queue = DispatchQueue(label: "com.claudecode.network.monitor", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // Network monitoring
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "com.claudecode.network.path")
    private var currentPath: NWPath?
    
    // Request tracking
    private var activeRequests: [String: NetworkRequest] = [:]
    private let requestQueue = DispatchQueue(label: "com.claudecode.network.requests", attributes: .concurrent)
    
    // Metrics
    private let metricsCollector = NetworkMetricsCollector()
    
    // Configuration
    private var config = NetworkMonitoringConfiguration.default
    
    // URLSession monitoring
    private var originalSessionConfig: URLSessionConfiguration?
    private var monitoringSession: URLSession?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupPathMonitor()
        injectURLSessionMonitoring()
    }
    
    // MARK: - Public API
    
    public func startMonitoring(with configuration: NetworkMonitoringConfiguration = .default) {
        self.config = configuration
        
        pathMonitor.start(queue: pathQueue)
        
        logger.info("Network performance monitoring started")
    }
    
    public func stopMonitoring() {
        pathMonitor.cancel()
        activeRequests.removeAll()
        
        logger.info("Network performance monitoring stopped")
    }
    
    public func trackRequest(url: URL, method: String = "GET", headers: [String: String]? = nil) -> String {
        let requestId = UUID().uuidString
        let request = NetworkRequest(
            id: requestId,
            url: url,
            method: method,
            headers: headers,
            startTime: Date(),
            startTimestamp: CACurrentMediaTime()
        )
        
        requestQueue.async(flags: .barrier) {
            self.activeRequests[requestId] = request
        }
        
        return requestId
    }
    
    public func finishRequest(
        id: String,
        statusCode: Int? = nil,
        responseSize: Int64? = nil,
        error: Error? = nil,
        cached: Bool = false
    ) {
        requestQueue.sync {
            guard let request = activeRequests[id] else { return }
            
            let duration = (CACurrentMediaTime() - request.startTimestamp) * 1000 // ms
            
            requestQueue.async(flags: .barrier) {
                self.activeRequests.removeValue(forKey: id)
            }
            
            // Record metrics
            recordRequestMetrics(
                request: request,
                duration: duration,
                statusCode: statusCode,
                responseSize: responseSize,
                error: error,
                cached: cached
            )
        }
    }
    
    // MARK: - Network Path Monitoring
    
    private func setupPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        let previousPath = currentPath
        currentPath = path
        
        // Track network type change
        if let previous = previousPath {
            if previous.status != path.status {
                trackNetworkStatusChange(from: previous.status, to: path.status)
            }
            
            if !previous.isExpensive && path.isExpensive {
                trackExpensiveNetworkChange(isExpensive: true)
            }
        }
        
        // Record current network info
        let networkInfo = NetworkInfo(
            status: path.status,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            connectionType: getConnectionType(from: path)
        )
        
        metricsCollector.updateNetworkInfo(networkInfo)
        
        logger.debug("Network path updated: \(networkInfo)")
    }
    
    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
    
    private func trackNetworkStatusChange(from: NWPath.Status, to: NWPath.Status) {
        let event = MonitoringEvent(
            name: "network.status_change",
            category: .network,
            properties: [
                "from_status": statusString(from),
                "to_status": statusString(to),
                "timestamp": Date().timeIntervalSince1970
            ],
            severity: to == .satisfied ? .info : .warning
        )
        
        MonitoringService.shared.trackEvent(event)
    }
    
    private func trackExpensiveNetworkChange(isExpensive: Bool) {
        let event = MonitoringEvent(
            name: "network.expensive_change",
            category: .network,
            properties: [
                "is_expensive": isExpensive,
                "timestamp": Date().timeIntervalSince1970
            ],
            severity: .info
        )
        
        MonitoringService.shared.trackEvent(event)
    }
    
    private func statusString(_ status: NWPath.Status) -> String {
        switch status {
        case .satisfied:
            return "satisfied"
        case .unsatisfied:
            return "unsatisfied"
        case .requiresConnection:
            return "requires_connection"
        @unknown default:
            return "unknown"
        }
    }
    
    // MARK: - Request Metrics
    
    private func recordRequestMetrics(
        request: NetworkRequest,
        duration: Double,
        statusCode: Int?,
        responseSize: Int64?,
        error: Error?,
        cached: Bool
    ) {
        // Basic metrics
        let metric = PerformanceMetric(
            name: "network.request.duration",
            value: duration,
            unit: .milliseconds,
            tags: [
                "method": request.method,
                "host": request.url.host ?? "unknown",
                "cached": String(cached)
            ]
        )
        
        MonitoringService.shared.trackPerformance(metric)
        
        // Response size metric
        if let size = responseSize {
            let sizeMetric = PerformanceMetric(
                name: "network.response.size",
                value: Double(size),
                unit: .bytes,
                tags: ["host": request.url.host ?? "unknown"]
            )
            MonitoringService.shared.trackPerformance(sizeMetric)
        }
        
        // Status code tracking
        if let code = statusCode {
            trackStatusCode(code, for: request)
        }
        
        // Error tracking
        if let error = error {
            trackNetworkError(error, for: request, duration: duration)
        }
        
        // Update collector
        metricsCollector.recordRequest(
            duration: duration,
            statusCode: statusCode,
            responseSize: responseSize,
            error: error,
            cached: cached
        )
        
        // Check thresholds
        checkNetworkThresholds(duration: duration, statusCode: statusCode, error: error)
    }
    
    private func trackStatusCode(_ code: Int, for request: NetworkRequest) {
        let event = MonitoringEvent(
            name: "network.status_code",
            category: .network,
            properties: [
                "code": code,
                "method": request.method,
                "host": request.url.host ?? "unknown",
                "path": request.url.path
            ],
            severity: code >= 400 ? .warning : .debug
        )
        
        MonitoringService.shared.trackEvent(event)
    }
    
    private func trackNetworkError(_ error: Error, for request: NetworkRequest, duration: Double) {
        let context = ErrorContext(
            additionalInfo: [
                "url": request.url.absoluteString,
                "method": request.method,
                "duration": duration
            ]
        )
        
        let monitoringError = MonitoringError(
            error: error,
            context: context,
            isFatal: false
        )
        
        MonitoringService.shared.trackError(monitoringError)
    }
    
    private func checkNetworkThresholds(duration: Double, statusCode: Int?, error: Error?) {
        // Check latency threshold
        if duration > config.maxAcceptableLatency {
            let alert = NetworkAlert(
                type: .highLatency,
                value: duration,
                threshold: config.maxAcceptableLatency
            )
            processNetworkAlert(alert)
        }
        
        // Check error rate
        let errorRate = metricsCollector.getCurrentErrorRate()
        if errorRate > config.maxErrorRate {
            let alert = NetworkAlert(
                type: .highErrorRate,
                value: errorRate,
                threshold: config.maxErrorRate
            )
            processNetworkAlert(alert)
        }
        
        // Check for consecutive failures
        if metricsCollector.getConsecutiveFailures() >= config.maxConsecutiveFailures {
            let alert = NetworkAlert(
                type: .consecutiveFailures,
                value: Double(metricsCollector.getConsecutiveFailures()),
                threshold: Double(config.maxConsecutiveFailures)
            )
            processNetworkAlert(alert)
        }
    }
    
    private func processNetworkAlert(_ alert: NetworkAlert) {
        logger.warning("Network Alert: \(alert.type) - Value: \(alert.value), Threshold: \(alert.threshold)")
        
        let event = MonitoringEvent(
            name: "network.alert",
            category: .network,
            properties: [
                "type": alert.type.rawValue,
                "value": alert.value,
                "threshold": alert.threshold
            ],
            severity: .warning
        )
        
        MonitoringService.shared.trackEvent(event)
    }
    
    // MARK: - URLSession Injection
    
    private func injectURLSessionMonitoring() {
        swizzleURLSessionMethods()
    }
    
    private func swizzleURLSessionMethods() {
        // Swizzle dataTask methods to inject monitoring
        let originalSelector = #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask)
        let swizzledSelector = #selector(URLSession.monitored_dataTask(with:completionHandler:))
        
        guard let originalMethod = class_getInstanceMethod(URLSession.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(URLSession.self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

// MARK: - URLSession Extension

extension URLSession {
    @objc func monitored_dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        let requestId = NetworkPerformanceMonitor.shared.trackRequest(
            url: request.url ?? URL(string: "unknown://")!,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields
        )
        
        let wrappedHandler: (Data?, URLResponse?, Error?) -> Void = { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                NetworkPerformanceMonitor.shared.finishRequest(
                    id: requestId,
                    statusCode: httpResponse.statusCode,
                    responseSize: Int64(data?.count ?? 0),
                    error: error,
                    cached: false
                )
            } else {
                NetworkPerformanceMonitor.shared.finishRequest(
                    id: requestId,
                    error: error,
                    cached: false
                )
            }
            
            completionHandler(data, response, error)
        }
        
        // Call original implementation with wrapped handler
        return monitored_dataTask(with: request, completionHandler: wrappedHandler)
    }
}

// MARK: - Supporting Types

struct NetworkRequest {
    let id: String
    let url: URL
    let method: String
    let headers: [String: String]?
    let startTime: Date
    let startTimestamp: CFAbsoluteTime
}

struct NetworkInfo {
    let status: NWPath.Status
    let isExpensive: Bool
    let isConstrained: Bool
    let connectionType: ConnectionType
}

enum ConnectionType: String {
    case wifi = "wifi"
    case cellular = "cellular"
    case ethernet = "ethernet"
    case unknown = "unknown"
}

struct NetworkAlert {
    let type: NetworkAlertType
    let value: Double
    let threshold: Double
}

enum NetworkAlertType: String {
    case highLatency = "high_latency"
    case highErrorRate = "high_error_rate"
    case consecutiveFailures = "consecutive_failures"
}

public struct NetworkMonitoringConfiguration {
    let maxAcceptableLatency: Double // milliseconds
    let maxErrorRate: Double // percentage
    let maxConsecutiveFailures: Int
    let sampleRate: Double
    
    public static let `default` = NetworkMonitoringConfiguration(
        maxAcceptableLatency: 3000.0,
        maxErrorRate: 5.0,
        maxConsecutiveFailures: 3,
        sampleRate: 1.0
    )
}

// MARK: - Network Metrics Collector

private class NetworkMetricsCollector {
    private var requestCount = 0
    private var errorCount = 0
    private var totalDuration: Double = 0
    private var consecutiveFailures = 0
    private var lastHourRequests: [(Date, Bool)] = [] // (timestamp, isError)
    private var currentNetworkInfo: NetworkInfo?
    private let queue = DispatchQueue(label: "com.claudecode.network.metrics")
    
    func recordRequest(
        duration: Double,
        statusCode: Int?,
        responseSize: Int64?,
        error: Error?,
        cached: Bool
    ) {
        queue.async {
            self.requestCount += 1
            self.totalDuration += duration
            
            let isError = error != nil || (statusCode ?? 200) >= 400
            
            if isError {
                self.errorCount += 1
                self.consecutiveFailures += 1
            } else {
                self.consecutiveFailures = 0
            }
            
            // Track for error rate calculation
            self.lastHourRequests.append((Date(), isError))
            self.cleanOldRequests()
        }
    }
    
    func updateNetworkInfo(_ info: NetworkInfo) {
        queue.async {
            self.currentNetworkInfo = info
        }
    }
    
    func getCurrentErrorRate() -> Double {
        return queue.sync {
            guard !lastHourRequests.isEmpty else { return 0 }
            let errors = lastHourRequests.filter { $0.1 }.count
            return Double(errors) / Double(lastHourRequests.count) * 100.0
        }
    }
    
    func getConsecutiveFailures() -> Int {
        return queue.sync { consecutiveFailures }
    }
    
    func getAverageLatency() -> Double {
        return queue.sync {
            guard requestCount > 0 else { return 0 }
            return totalDuration / Double(requestCount)
        }
    }
    
    private func cleanOldRequests() {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        lastHourRequests.removeAll { $0.0 < oneHourAgo }
    }
}