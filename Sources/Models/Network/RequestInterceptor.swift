import Foundation
import OSLog

/// Protocol for request/response interception (Tasks 481-485)
protocol RequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws
    func intercept(_ response: URLResponse, data: Data) async throws -> Data
}

/// Chain of responsibility for interceptors
class InterceptorChain {
    private var interceptors: [RequestInterceptor] = []
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "InterceptorChain")
    
    func add(_ interceptor: RequestInterceptor) {
        interceptors.append(interceptor)
    }
    
    func remove(_ interceptor: RequestInterceptor) {
        interceptors.removeAll { $0 as AnyObject === interceptor as AnyObject }
    }
    
    func processRequest(_ request: inout URLRequest) async throws {
        for interceptor in interceptors {
            try await interceptor.intercept(&request)
        }
    }
    
    func processResponse(_ response: URLResponse, data: Data) async throws -> Data {
        var processedData = data
        for interceptor in interceptors {
            processedData = try await interceptor.intercept(response, data: processedData)
        }
        return processedData
    }
}

// MARK: - Built-in Interceptors

/// Authentication interceptor
class AuthenticationInterceptor: RequestInterceptor {
    private var apiKey: String?
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "AuthInterceptor")
    
    init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }
    
    func updateAPIKey(_ key: String?) {
        self.apiKey = key
    }
    
    func intercept(_ request: inout URLRequest) async throws {
        guard let apiKey = apiKey else { return }
        
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        logger.debug("Added authentication header to request")
    }
    
    func intercept(_ response: URLResponse, data: Data) async throws -> Data {
        // Check for 401 and trigger re-authentication if needed
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 401 {
            logger.warning("Authentication failed, may need to refresh token")
            // Could trigger token refresh here
        }
        return data
    }
}

/// Logging interceptor
class LoggingInterceptor: RequestInterceptor {
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "NetworkLog")
    var logLevel: LogLevel = .info
    
    enum LogLevel {
        case verbose, info, error
    }
    
    func intercept(_ request: inout URLRequest) async throws {
        guard logLevel != .error else { return }
        
        logger.info("""
            🔵 Request:
            Method: \(request.httpMethod ?? "GET")
            URL: \(request.url?.absoluteString ?? "unknown")
            Headers: \(request.allHTTPHeaderFields ?? [:])
        """)
        
        if logLevel == .verbose, let body = request.httpBody {
            logger.debug("Body: \(String(data: body, encoding: .utf8) ?? "binary")")
        }
    }
    
    func intercept(_ response: URLResponse, data: Data) async throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else { return data }
        
        let emoji = httpResponse.statusCode >= 400 ? "🔴" : "🟢"
        logger.info("""
            \(emoji) Response:
            Status: \(httpResponse.statusCode)
            URL: \(httpResponse.url?.absoluteString ?? "unknown")
        """)
        
        if logLevel == .verbose {
            logger.debug("Data: \(String(data: data, encoding: .utf8)?.prefix(500) ?? "binary")")
        }
        
        return data
    }
}

/// Retry interceptor
class RetryInterceptor: RequestInterceptor {
    var maxRetries = 3
    var retryDelay: TimeInterval = 1.0
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "RetryInterceptor")
    
    func intercept(_ request: inout URLRequest) async throws {
        // Add retry count header if retrying
        if let retryCount = request.value(forHTTPHeaderField: "X-Retry-Count") {
            logger.info("Retry attempt \(retryCount)")
        }
    }
    
    func intercept(_ response: URLResponse, data: Data) async throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else { return data }
        
        // Check if should retry
        let shouldRetry = shouldRetryForStatus(httpResponse.statusCode)
        if shouldRetry {
            logger.info("Will retry request for status \(httpResponse.statusCode)")
            // Retry logic would be handled at the APIClient level
        }
        
        return data
    }
    
    private func shouldRetryForStatus(_ status: Int) -> Bool {
        // Retry on server errors and rate limiting
        return status >= 500 || status == 429 || status == 408
    }
}

/// Caching interceptor
class CachingInterceptor: RequestInterceptor {
    private let cache = URLCache.shared
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "CacheInterceptor")
    
    func intercept(_ request: inout URLRequest) async throws {
        // Add cache headers
        if request.cachePolicy == .useProtocolCachePolicy {
            request.setValue("max-age=300", forHTTPHeaderField: "Cache-Control")
        }
    }
    
    func intercept(_ response: URLResponse, data: Data) async throws -> Data {
        // Cache response if appropriate
        guard let httpResponse = response as? HTTPURLResponse,
              let url = httpResponse.url else { return data }
        
        if httpResponse.statusCode == 200 {
            let cachedResponse = CachedURLResponse(response: httpResponse, data: data)
            cache.storeCachedResponse(cachedResponse, for: URLRequest(url: url))
            logger.debug("Cached response for \(url)")
        }
        
        return data
    }
}

/// Compression interceptor
class CompressionInterceptor: RequestInterceptor {
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "CompressionInterceptor")
    
    func intercept(_ request: inout URLRequest) async throws {
        // Request compressed responses
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
    }
    
    func intercept(_ response: URLResponse, data: Data) async throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse,
              let encoding = httpResponse.value(forHTTPHeaderField: "Content-Encoding") else {
            return data
        }
        
        // Decompress if needed (URLSession usually handles this automatically)
        logger.debug("Response encoding: \(encoding)")
        return data
    }
}

/// Metrics interceptor
class MetricsInterceptor: RequestInterceptor {
    private var requestStartTimes: [URLRequest: Date] = [:]
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "MetricsInterceptor")
    
    func intercept(_ request: inout URLRequest) async throws {
        requestStartTimes[request] = Date()
    }
    
    func intercept(_ response: URLResponse, data: Data) async throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse,
              let request = httpResponse.url.flatMap({ URLRequest(url: $0) }),
              let startTime = requestStartTimes[request] else {
            return data
        }
        
        let duration = Date().timeIntervalSince(startTime)
        requestStartTimes.removeValue(forKey: request)
        
        // Record metrics
        let metrics = RequestMetrics(
            url: httpResponse.url,
            method: request.httpMethod ?? "GET",
            statusCode: httpResponse.statusCode,
            duration: duration,
            dataSize: data.count,
            timestamp: Date()
        )
        
        await MetricsCollector.shared.record(metrics)
        logger.debug("Request completed in \(duration)s")
        
        return data
    }
}

/// Header manipulation interceptor
class HeaderInterceptor: RequestInterceptor {
    private var requestHeaders: [String: String] = [:]
    private var responseHeaderHandlers: [(String, (String) -> Void)] = []
    
    func addRequestHeader(_ key: String, value: String) {
        requestHeaders[key] = value
    }
    
    func removeRequestHeader(_ key: String) {
        requestHeaders.removeValue(forKey: key)
    }
    
    func onResponseHeader(_ key: String, handler: @escaping (String) -> Void) {
        responseHeaderHandlers.append((key, handler))
    }
    
    func intercept(_ request: inout URLRequest) async throws {
        for (key, value) in requestHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
    
    func intercept(_ response: URLResponse, data: Data) async throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else { return data }
        
        for (headerKey, handler) in responseHeaderHandlers {
            if let value = httpResponse.value(forHTTPHeaderField: headerKey) {
                handler(value)
            }
        }
        
        return data
    }
}

/// Error transformation interceptor
class ErrorInterceptor: RequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws {
        // No-op for requests
    }
    
    func intercept(_ response: URLResponse, data: Data) async throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else { return data }
        
        // Transform error responses into structured errors
        if httpResponse.statusCode >= 400 {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJSON["error"] as? String ?? errorJSON["message"] as? String {
                
                // Create enhanced error
                let enhancedError = EnhancedError(
                    statusCode: httpResponse.statusCode,
                    message: message,
                    details: errorJSON,
                    timestamp: Date()
                )
                
                // Encode enhanced error
                if let enhancedData = try? JSONEncoder().encode(enhancedError) {
                    return enhancedData
                }
            }
        }
        
        return data
    }
}

// MARK: - Supporting Types

struct RequestMetrics {
    let url: URL?
    let method: String
    let statusCode: Int
    let duration: TimeInterval
    let dataSize: Int
    let timestamp: Date
}

struct EnhancedError: Codable {
    let statusCode: Int
    let message: String
    let details: [String: Any]
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case statusCode, message, details, timestamp
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(statusCode, forKey: .statusCode)
        try container.encode(message, forKey: .message)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Encode details as JSON string
        if let detailsData = try? JSONSerialization.data(withJSONObject: details),
           let detailsString = String(data: detailsData, encoding: .utf8) {
            try container.encode(detailsString, forKey: .details)
        }
    }
}

/// Metrics collector singleton
@MainActor
class MetricsCollector: ObservableObject {
    static let shared = MetricsCollector()
    
    @Published var metrics: [RequestMetrics] = []
    private let maxMetrics = 1000
    
    private init() {}
    
    func record(_ metric: RequestMetrics) {
        metrics.append(metric)
        if metrics.count > maxMetrics {
            metrics.removeFirst()
        }
    }
    
    func getStatistics() -> NetworkStatistics {
        let totalRequests = metrics.count
        let successfulRequests = metrics.filter { $0.statusCode < 400 }.count
        let averageDuration = metrics.map { $0.duration }.reduce(0, +) / Double(max(totalRequests, 1))
        let totalDataTransferred = metrics.map { $0.dataSize }.reduce(0, +)
        
        return NetworkStatistics(
            totalRequests: totalRequests,
            successfulRequests: successfulRequests,
            successRate: Double(successfulRequests) / Double(max(totalRequests, 1)),
            averageDuration: averageDuration,
            totalDataTransferred: totalDataTransferred
        )
    }
}

struct NetworkStatistics {
    let totalRequests: Int
    let successfulRequests: Int
    let successRate: Double
    let averageDuration: TimeInterval
    let totalDataTransferred: Int
}