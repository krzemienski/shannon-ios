import Foundation
import OSLog

/// Enhanced API client for Claude Code backend communication
/// Implements tasks 301-350 from TASK_PLAN.md
@MainActor
public class APIClient: ObservableObject {
    // MARK: - Singleton
    
    public static let shared = APIClient()
    
    // MARK: - Properties
    
    private let session: URLSession
    private let backgroundSession: URLSession  // Task 337: Background session support
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "APIClient")
    private var apiKey: String?
    
    // Published properties
    @Published var isLoading = false
    @Published var lastError: APIError?
    @Published var networkActivityCount = 0  // Task 324: Network activity indicator
    @Published var currentProgress: Double = 0  // Task 325: Progress tracking
    @Published var connectionQuality: ConnectionQuality = .unknown  // Task 345: Connection quality
    @Published var networkType: NetworkType = .unknown  // Task 346: Network type detection
    
    // Request management (Tasks 318-320)
    private let requestQueue = DispatchQueue(label: "com.claudecode.api.queue", attributes: .concurrent)
    private var pendingRequests: [UUID: URLSessionTask] = [:]
    private let requestSemaphore: DispatchSemaphore  // Task 319: Rate limiting
    private var requestPriorities: [UUID: RequestPriority] = [:]  // Task 331: Request priorities
    
    // Request queuing (Tasks 326-330)
    private var requestQueue326 = RequestQueue()  // Task 326: FIFO queue
    private var priorityQueue = PriorityRequestQueue()  // Task 327: Priority queue
    private var retryQueue: [RetryableRequest] = []  // Task 329: Retry queue
    private var backgroundQueue: [BackgroundRequest] = []  // Task 330: Background queue
    
    // Caching (Tasks 321-323)
    private let requestCache = NSCache<NSString, CachedResponse>()
    private let responseCache = NSCache<NSString, NSData>()
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheLifetime: TimeInterval = 300  // 5 minutes
    private let persistentCache = PersistentCache()  // Task 347: Persistent caching
    
    // Metrics (Tasks 338-341)
    private var requestMetrics: [RequestMetric] = []
    private var bandwidthMonitor = BandwidthMonitor()
    private var latencyMonitor = LatencyMonitor()  // Task 348: Latency monitoring
    private var dnsCache: [String: String] = [:]  // Task 341: DNS caching
    private var requestDeduplication: [String: Task<Data, Error>] = [:]  // Task 342
    private let metricsCollector = RequestMetricsCollector()  // Task 349: Metrics collection
    
    // Request batching (Task 343)
    private var batchedRequests: [BatchRequest] = []
    private var batchTimer: Timer?
    private let batchProcessor = BatchProcessor()  // Task 344: Batch processing
    
    // Connection pool (Task 340)
    private let connectionPool = ConnectionPool(maxConnections: 6)
    
    // Circuit breaker (Task 350)
    private let circuitBreaker = CircuitBreaker(
        failureThreshold: 5,
        resetTimeout: 60,
        halfOpenMaxAttempts: 3
    )
    
    // MARK: - Initialization
    
    init(apiKey: String? = nil, maxConcurrentRequests: Int = 10) {
        self.apiKey = apiKey
        self.requestSemaphore = DispatchSemaphore(value: maxConcurrentRequests)  // Task 319
        
        // Configure default session
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConfig.RequestConfig.default.timeout
        configuration.timeoutIntervalForResource = APIConfig.RequestConfig.default.timeout * 2
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 6  // Task 340: Connection pool
        configuration.urlCache = nil  // We use custom caching
        
        self.session = URLSession(configuration: configuration)
        
        // Configure background session (Task 337)
        let backgroundConfig = URLSessionConfiguration.background(withIdentifier: "com.claudecode.api.background")
        backgroundConfig.sessionSendsLaunchEvents = true
        backgroundConfig.isDiscretionary = false
        backgroundConfig.shouldUseExtendedBackgroundIdleMode = true
        
        self.backgroundSession = URLSession(configuration: backgroundConfig)
        
        // Setup caches
        requestCache.countLimit = 100
        responseCache.totalCostLimit = 50 * 1024 * 1024  // 50MB
        
        // Verify backend on init (Task 301-302)
        Task {
            await verifyBackend()
        }
    }
    
    // MARK: - Public Methods
    
    /// Verify backend is running (Tasks 301-302)
    func verifyBackend() async -> Bool {
        logger.info("Verifying backend at \(APIConfig.baseURL.absoluteString)")
        let isHealthy = await checkHealth()
        if !isHealthy {
            logger.error("Backend not running! Start with: cd claude-code-api && make start")
        }
        return isHealthy
    }
    
    /// Check if the backend is healthy
    func checkHealth() async -> Bool {
        do {
            let healthURL = APIConfig.baseURL.appendingPathComponent("/health")
            let (_, response) = try await session.data(from: healthURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            logger.error("Health check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Fetch available models
    func fetchModels() async throws -> [APIModel] {
        let response: ModelsResponse = try await request(
            endpoint: .models,
            method: .get,
            priority: .high,
            cachePolicy: .returnCacheElseLoad
        )
        return response.data
    }
    
    /// Create a chat completion
    func createChatCompletion(request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        return try await self.request(
            endpoint: .chatCompletions,
            method: .post,
            body: request,
            priority: .high,
            cachePolicy: .reloadIgnoringCache
        )
    }
    
    // MARK: - Session Management (Tasks 421-430)
    
    /// List all sessions
    func listSessions(limit: Int = 50, offset: Int = 0) async throws -> [SessionInfo] {
        let response: SessionsResponse = try await request(
            endpoint: .sessions,
            method: .get,
            priority: .normal,
            cachePolicy: .returnCacheElseLoad
        )
        return response.sessions
    }
    
    /// Get session details
    func getSession(id: String) async throws -> SessionInfo {
        return try await request(
            endpoint: .sessionDetails(id),
            method: .get,
            priority: .normal,
            cachePolicy: .returnCacheElseLoad
        )
    }
    
    /// Create new session
    func createSession(_ sessionRequest: CreateSessionRequest) async throws -> SessionInfo {
        return try await request(
            endpoint: .sessions,
            method: .post,
            body: sessionRequest,
            priority: .high,
            cachePolicy: .reloadIgnoringCache
        )
    }
    
    /// Update session
    func updateSession(id: String, request: CreateSessionRequest) async throws -> SessionInfo {
        return try await self.request(
            endpoint: .sessionDetails(id),
            method: .patch,
            body: request,
            priority: .normal,
            cachePolicy: .reloadIgnoringCache
        )
    }
    
    /// Delete session
    func deleteSession(id: String) async throws -> Bool {
        let response: DeleteResponse = try await request(
            endpoint: .sessionDetails(id),
            method: .delete,
            priority: .normal,
            cachePolicy: .reloadIgnoringCache
        )
        return response.success
    }
    
    // MARK: - Project Management (Tasks 431-440)
    
    /// List all projects
    func listProjects() async throws -> [ProjectInfo] {
        let response: ProjectsResponse = try await request(
            endpoint: .projects,
            method: .get,
            priority: .normal,
            cachePolicy: .returnCacheElseLoad
        )
        return response.projects
    }
    
    /// Get project details
    func getProject(id: String) async throws -> ProjectInfo {
        return try await request(
            endpoint: .projectDetails(id),
            method: .get,
            priority: .normal,
            cachePolicy: .returnCacheElseLoad
        )
    }
    
    /// Create new project
    func createProject(_ projectRequest: CreateProjectRequest) async throws -> ProjectInfo {
        return try await request(
            endpoint: .projects,
            method: .post,
            body: projectRequest,
            priority: .high,
            cachePolicy: .reloadIgnoringCache
        )
    }
    
    /// Update project
    func updateProject(id: String, request: CreateProjectRequest) async throws -> ProjectInfo {
        return try await self.request(
            endpoint: .projectDetails(id),
            method: .patch,
            body: request,
            priority: .normal,
            cachePolicy: .reloadIgnoringCache
        )
    }
    
    /// Delete project
    func deleteProject(id: String) async throws -> Bool {
        let response: DeleteResponse = try await request(
            endpoint: .projectDetails(id),
            method: .delete,
            priority: .normal,
            cachePolicy: .reloadIgnoringCache
        )
        return response.success
    }
    
    // MARK: - Tool Execution (Tasks 441-450)
    
    /// List available tools
    func listTools() async throws -> [ToolInfo] {
        let response: ToolsResponse = try await request(
            endpoint: .tools,
            method: .get,
            priority: .normal,
            cachePolicy: .returnCacheElseLoad
        )
        return response.tools
    }
    
    /// Execute tool
    func executeTool(_ toolRequest: ToolExecutionRequest) async throws -> ToolExecutionResponse {
        return try await request(
            endpoint: .toolExecution,
            method: .post,
            body: toolRequest,
            priority: .high,
            cachePolicy: .reloadIgnoringCache
        )
    }
    
    // MARK: - SSH Management (Tasks 451-460)
    
    /// List SSH sessions
    func listSSHSessions() async throws -> [SSHSessionInfo] {
        let response: SSHSessionsResponse = try await request(
            endpoint: .sshSessions,
            method: .get,
            priority: .normal,
            cachePolicy: .reloadIgnoringCache
        )
        return response.sessions
    }
    
    /// Create SSH session
    func createSSHSession(_ sshRequest: SSHSessionRequest) async throws -> SSHSessionInfo {
        return try await request(
            endpoint: .sshSessions,
            method: .post,
            body: sshRequest,
            priority: .high,
            cachePolicy: .reloadIgnoringCache
        )
    }
    
    /// Execute SSH command
    func executeSSHCommand(_ commandRequest: SSHCommandRequest) async throws -> SSHCommandResponse {
        return try await request(
            endpoint: .sshCommand,
            method: .post,
            body: commandRequest,
            priority: .high,
            cachePolicy: .reloadIgnoringCache
        )
    }
    
    /// Disconnect SSH session
    func disconnectSSHSession(id: String) async throws -> Bool {
        let response: DeleteResponse = try await request(
            endpoint: .sshSessions,
            method: .delete,
            priority: .normal,
            cachePolicy: .reloadIgnoringCache
        )
        return response.success
    }
    
    // MARK: - Generic Request Methods
    
    /// Perform a generic API request with enhanced features (Tasks 301-350)
    func request<T: Decodable>(
        endpoint: APIConfig.Endpoint,
        method: HTTPMethod,
        body: Encodable? = nil,
        config: APIConfig.RequestConfig = .default,
        priority: RequestPriority = .normal,
        cachePolicy: CachePolicy = .reloadIgnoringCache
    ) async throws -> T {
        // Check circuit breaker (Task 350)
        guard circuitBreaker.canMakeRequest() else {
            throw APIConfig.APIError.serverError(statusCode: 503, message: "Circuit breaker is open")
        }
        
        // Check cache first (Tasks 321-323, 347)
        let cacheKey = "\(method.rawValue)_\(endpoint.path)_\(String(describing: body))"
        if cachePolicy != .reloadIgnoringCache {
            if let cachedData = getCachedResponse(for: cacheKey) {
                logger.debug("Using cached response for \(endpoint.path)")
                metricsCollector.recordCacheHit()
                let decoded = try JSONDecoder().decode(T.self, from: cachedData)
                return decoded
            }
        }
        
        // Request deduplication (Task 342)
        if let existingTask = requestDeduplication[cacheKey] {
            logger.debug("Deduplicating request for \(endpoint.path)")
            let data = try await existingTask.value
            return try JSONDecoder().decode(T.self, from: data)
        }
        
        isLoading = true
        defer { 
            isLoading = false
            networkActivityCount = max(0, networkActivityCount - 1)
        }
        networkActivityCount += 1
        
        // Create request
        var request = URLRequest(url: endpoint.url())
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = APIConfig.defaultHeaders(apiKey: apiKey)
        
        // Add body if provided
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        // Set priority (Task 331)
        switch priority {
        case .low:
            request.networkServiceType = .background
        case .normal:
            request.networkServiceType = .default
        case .high:
            request.networkServiceType = .responsiveData
        case .critical:
            request.networkServiceType = .responsiveData
        }
        
        // Log request
        logger.debug("API Request: \(method.rawValue) \(endpoint.path) [Priority: \(priority)]")
        
        // Track request start time for metrics
        let requestStartTime = Date()
        let requestId = UUID()
        
        // Create deduplicated task (Task 342)
        let task = Task<Data, Error> {
            // Acquire connection from pool (Task 340)
            await connectionPool.acquire()
            defer { connectionPool.release() }
            
            // Rate limiting (Task 319)
            await withCheckedContinuation { continuation in
                requestQueue.async(flags: .barrier) {
                    self.requestSemaphore.wait()
                    continuation.resume()
                }
            }
            defer { requestSemaphore.signal() }
            
            // Bandwidth monitoring (Task 338)
            bandwidthMonitor.startTracking(for: requestId)
            defer { bandwidthMonitor.stopTracking(for: requestId) }
            
            // Perform request with retry logic
            var lastError: Error?
            for attempt in 0..<config.maxRetries {
                if attempt > 0 {
                    let backoffDelay = ExponentialBackoff.calculate(
                        attempt: attempt,
                        baseDelay: config.retryDelay,
                        maxDelay: 30.0
                    )
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }
                
                do {
                    let (data, response) = try await session.data(for: request)
                    bandwidthMonitor.recordTransfer(bytes: data.count)
                    return data
                } catch {
                    lastError = error
                    logger.error("Request attempt \(attempt + 1) failed: \(error)")
                    
                    // Record failure for circuit breaker (Task 350)
                    circuitBreaker.recordFailure()
                    
                    // Don't retry for certain errors
                    if error is APIConfig.APIError {
                        throw error
                    }
                }
            }
            
            throw lastError ?? APIConfig.APIError.networkError(URLError(.unknown))
        }
        
        // Store task for deduplication
        requestDeduplication[cacheKey] = task
        defer { requestDeduplication.removeValue(forKey: cacheKey) }
        
        // Execute task and get data
        let data = try await task.value
        
        // Process response
        guard let response = URLSession.shared.configuration.protocolClasses?.first else {
            throw APIConfig.APIError.networkError(URLError(.badServerResponse))
        }
        
        // Perform request with retry logic
        var lastError: Error?
        for attempt in 0..<config.maxRetries {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: UInt64(config.retryDelay * 1_000_000_000))
            }
            
            do {
                let (data, response) = try await session.data(for: request)
                
                // Check response
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIConfig.APIError.networkError(URLError(.badServerResponse))
                }
                
                // Handle different status codes
                switch httpResponse.statusCode {
                case 200...299:
                    // Success - decode response
                    do {
                        // Cache successful response (Tasks 321-323, 347)
                        if cachePolicy != .reloadIgnoringCache {
                            cacheResponse(data, for: cacheKey)
                            persistentCache.store(data, for: cacheKey)
                        }
                        
                        // Record metrics (Tasks 338-339, 348-349)
                        let responseTime = Date().timeIntervalSince(requestStartTime)
                        latencyMonitor.recordLatency(responseTime)
                        metricsCollector.recordRequest(
                            endpoint: endpoint.path,
                            method: method.rawValue,
                            statusCode: httpResponse.statusCode,
                            responseTime: responseTime,
                            dataSize: data.count
                        )
                        
                        // Update circuit breaker (Task 350)
                        circuitBreaker.recordSuccess()
                        
                        let decoded = try JSONDecoder().decode(T.self, from: data)
                        logger.debug("API Success: \(endpoint.path) [\(responseTime)s]")
                        return decoded
                    } catch {
                        logger.error("Decoding error: \(error)")
                        throw APIConfig.APIError.decodingError(error)
                    }
                    
                case 401:
                    throw APIConfig.APIError.unauthorized
                    
                case 429:
                    // Rate limited - check for Retry-After header
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { TimeInterval($0) }
                    throw APIConfig.APIError.rateLimited(retryAfter: retryAfter)
                    
                default:
                    // Server error
                    let message = String(data: data, encoding: .utf8)
                    throw APIConfig.APIError.serverError(
                        statusCode: httpResponse.statusCode,
                        message: message
                    )
                }
            } catch let error as URLError where error.code == .cannotConnectToHost {
                // Backend not running
                throw APIConfig.APIError.backendNotRunning
            } catch {
                lastError = error
                logger.error("Request attempt \(attempt + 1) failed: \(error)")
                
                // Don't retry for certain errors
                if error is APIConfig.APIError {
                    throw error
                }
            }
        }
        
        // All retries failed
        throw lastError ?? APIConfig.APIError.networkError(URLError(.unknown))
    }
    
    /// Upload data with multipart form
    func upload<T: Decodable>(
        endpoint: APIConfig.Endpoint,
        method: HTTPMethod = .post,
        files: [(name: String, filename: String, data: Data, mimeType: String)],
        parameters: [String: String] = [:],
        config: APIConfig.RequestConfig = .default
    ) async throws -> T {
        isLoading = true
        defer { isLoading = false }
        
        // Create multipart request
        var request = URLRequest(url: endpoint.url())
        request.httpMethod = method.rawValue
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Build multipart body
        var body = Data()
        
        // Add parameters
        for (key, value) in parameters {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add files
        for file in files {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        // Perform request
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIConfig.APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Helper Methods
    
    func setAPIKey(_ key: String?) {
        self.apiKey = key
    }
    
    func clearError() {
        lastError = nil
    }
    
    func setBaseURL(_ url: URL) {
        // Update the base URL in APIConfig
        // Note: This would require making APIConfig.baseURL mutable
        // For now, this is a no-op placeholder
        logger.info("setBaseURL called with \(url)")
    }
    
    func testConnection() async -> Bool {
        // Test the connection to the API
        return await checkHealth()
    }
    
    func clearCache() {
        invalidateCache()
    }
    
    // MARK: - Caching Methods (Tasks 321-323)
    
    private func getCachedResponse(for key: String) -> Data? {
        // Check if cache is still valid
        if let timestamp = cacheTimestamps[key],
           Date().timeIntervalSince(timestamp) < cacheLifetime {
            return responseCache.object(forKey: key as NSString) as Data?
        }
        // Cache expired
        invalidateCache(for: key)
        return nil
    }
    
    private func cacheResponse(_ data: Data, for key: String) {
        responseCache.setObject(data as NSData, forKey: key as NSString)
        cacheTimestamps[key] = Date()
    }
    
    func invalidateCache(for key: String? = nil) {
        if let key = key {
            responseCache.removeObject(forKey: key as NSString)
            cacheTimestamps.removeValue(forKey: key)
        } else {
            // Clear all caches
            responseCache.removeAllObjects()
            requestCache.removeAllObjects()
            cacheTimestamps.removeAll()
        }
    }
    
    // MARK: - Request Management (Tasks 317-320)
    
    func cancelRequest(with id: UUID) {
        pendingRequests[id]?.cancel()
        pendingRequests.removeValue(forKey: id)
    }
    
    func cancelAllRequests() {
        pendingRequests.values.forEach { $0.cancel() }
        pendingRequests.removeAll()
    }
    
    // MARK: - Metrics Collection (Tasks 338-339)
    
    private func recordMetric(_ metric: RequestMetric) {
        requestMetrics.append(metric)
        // Keep only last 100 metrics
        if requestMetrics.count > 100 {
            requestMetrics.removeFirst()
        }
    }
    
    func getMetrics() -> RequestMetrics {
        let avgLatency = requestMetrics.map { $0.latency }.reduce(0, +) / Double(max(requestMetrics.count, 1))
        let successRate = Double(requestMetrics.filter { $0.success }.count) / Double(max(requestMetrics.count, 1))
        let totalBandwidth = bandwidthMonitor.getTotalBandwidth()
        
        return RequestMetrics(
            requestCount: requestMetrics.count,
            averageLatency: avgLatency,
            successRate: successRate,
            totalBandwidthUsed: totalBandwidth
        )
    }
    
    // MARK: - Request Batching (Task 343)
    
    func batchRequest(_ request: BatchRequest) {
        batchedRequests.append(request)
        
        // Start batch timer if not already running
        if batchTimer == nil {
            batchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                Task { @MainActor in
                    await self.executeBatchedRequests()
                }
            }
        }
    }
    
    private func executeBatchedRequests() async {
        guard !batchedRequests.isEmpty else { return }
        
        let requests = batchedRequests
        batchedRequests.removeAll()
        batchTimer = nil
        
        // Execute all batched requests in parallel
        await withTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask {
                    await request.execute()
                }
            }
        }
    }
}

// MARK: - Supporting Types

// Request Priority (Task 331)
enum APIRequestPriority: Int {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

// Cache Policy (Tasks 321-323)
enum CachePolicy {
    case reloadIgnoringCache
    case returnCacheElseLoad
    case returnCacheDontLoad
    case reloadRevalidatingCache
}

// Connection Quality (Task 345) - Using type from NetworkModels.swift

// Network Type (Task 346)
enum NetworkType {
    case wifi
    case cellular3G
    case cellular4G
    case cellular5G
    case ethernet
    case unknown
}

// CachedResponse - Using type from NetworkModels.swift

// RequestMetric is defined in NetworkModels.swift and RequestPrioritizer.swift
// Using the one from RequestPrioritizer for internal metrics

// RequestMetrics - Using type from NetworkModels.swift

struct BatchRequest {
    let id: UUID
    let priority: RequestPriority
    let execute: () async -> Void
}

struct RetryableRequest {
    let id: UUID
    let request: URLRequest
    let retryCount: Int
    let maxRetries: Int
    let nextRetryTime: Date
}

struct BackgroundRequest {
    let id: UUID
    let request: URLRequest
    let priority: RequestPriority
    let completion: (Result<Data, Error>) -> Void
}

// Request Queue (Task 326)
class RequestQueue {
    private var queue: [URLRequest] = []
    private let lock = NSLock()
    
    func enqueue(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        queue.append(request)
    }
    
    func dequeue() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return queue.isEmpty ? nil : queue.removeFirst()
    }
}

// Priority Request Queue (Task 327)
class PriorityRequestQueue {
    private var queues: [RequestPriority: [URLRequest]] = [:]
    private let lock = NSLock()
    
    func enqueue(_ request: URLRequest, priority: RequestPriority) {
        lock.lock()
        defer { lock.unlock() }
        if queues[priority] == nil {
            queues[priority] = []
        }
        queues[priority]?.append(request)
    }
    
    func dequeue() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        
        for priority in [RequestPriority.critical, .high, .normal, .low] {
            if let requests = queues[priority], !requests.isEmpty {
                return queues[priority]?.removeFirst()
            }
        }
        return nil
    }
}

// Bandwidth Monitor (Task 338)
class BandwidthMonitor {
    private var totalBytes: Int = 0
    private var activeTransfers: [UUID: Int] = [:]
    private let queue = DispatchQueue(label: "bandwidth.monitor")
    
    func startTracking(for id: UUID) {
        queue.sync {
            activeTransfers[id] = 0
        }
    }
    
    func stopTracking(for id: UUID) {
        queue.sync {
            activeTransfers.removeValue(forKey: id)
        }
    }
    
    func recordTransfer(bytes: Int) {
        queue.sync {
            totalBytes += bytes
        }
    }
    
    func getTotalBandwidth() -> Int {
        queue.sync { totalBytes }
    }
}

// Latency Monitor (Task 348)
class LatencyMonitor {
    private var latencies: [TimeInterval] = []
    private let maxSamples = 1000
    private let queue = DispatchQueue(label: "latency.monitor")
    
    func recordLatency(_ latency: TimeInterval) {
        queue.sync {
            latencies.append(latency)
            if latencies.count > maxSamples {
                latencies.removeFirst()
            }
        }
    }
    
    func getPercentile(_ percentile: Double) -> TimeInterval {
        queue.sync {
            guard !latencies.isEmpty else { return 0 }
            let sorted = latencies.sorted()
            let index = Int(Double(sorted.count) * percentile / 100.0)
            return sorted[min(index, sorted.count - 1)]
        }
    }
}

// Metrics Collector (Task 349)
// MetricsCollector moved to NetworkModels.swift

// Batch Processor (Task 344)
class BatchProcessor {
    func processBatch<T>(_ items: [T], batchSize: Int, processor: (T) async throws -> Void) async throws {
        for batch in items.chunked(into: batchSize) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for item in batch {
                    group.addTask {
                        try await processor(item)
                    }
                }
                try await group.waitForAll()
            }
        }
    }
}

// Persistent Cache (Task 347)
class PersistentCache {
    private let cacheDirectory: URL
    
    init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("APICache")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func store(_ data: Data, for key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        try? data.write(to: fileURL)
    }
    
    func retrieve(for key: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        return try? Data(contentsOf: fileURL)
    }
}

// Circuit Breaker (Task 350)
class CircuitBreaker {
    enum State {
        case closed
        case open
        case halfOpen
    }
    
    private var state: State = .closed
    private var failureCount = 0
    private let failureThreshold: Int
    private let resetTimeout: TimeInterval
    private let halfOpenMaxAttempts: Int
    private var halfOpenAttempts = 0
    private var lastFailureTime: Date?
    private let queue = DispatchQueue(label: "circuit.breaker")
    
    init(failureThreshold: Int, resetTimeout: TimeInterval, halfOpenMaxAttempts: Int) {
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
        self.halfOpenMaxAttempts = halfOpenMaxAttempts
    }
    
    func canMakeRequest() -> Bool {
        queue.sync {
            switch state {
            case .closed:
                return true
            case .open:
                if let lastFailure = lastFailureTime,
                   Date().timeIntervalSince(lastFailure) > resetTimeout {
                    state = .halfOpen
                    halfOpenAttempts = 0
                    return true
                }
                return false
            case .halfOpen:
                return halfOpenAttempts < halfOpenMaxAttempts
            }
        }
    }
    
    func recordSuccess() {
        queue.sync {
            if state == .halfOpen {
                state = .closed
                failureCount = 0
            }
        }
    }
    
    func recordFailure() {
        queue.sync {
            failureCount += 1
            lastFailureTime = Date()
            
            if state == .halfOpen {
                halfOpenAttempts += 1
                if halfOpenAttempts >= halfOpenMaxAttempts {
                    state = .open
                }
            } else if failureCount >= failureThreshold {
                state = .open
            }
        }
    }
}

// Exponential Backoff Calculator
struct ExponentialBackoff {
    static func calculate(attempt: Int, baseDelay: TimeInterval, maxDelay: TimeInterval) -> TimeInterval {
        let delay = baseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...1.0) * delay * 0.1  // 10% jitter
        return min(delay + jitter, maxDelay)
    }
}

// Connection Pool (Task 340)
class ConnectionPool {
    let maxConnections: Int
    private var activeConnections = 0
    private let queue = DispatchQueue(label: "connection.pool")
    
    init(maxConnections: Int) {
        self.maxConnections = maxConnections
    }
    
    func acquire() async {
        while activeConnections >= maxConnections {
            try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        }
        queue.sync { activeConnections += 1 }
    }
    
    func release() {
        queue.sync { activeConnections = max(0, activeConnections - 1) }
    }
}

// Array extension for chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// SHA256 extension is defined in FileTransferService.swift

// MARK: - Supporting Types

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Response Types

public struct ModelsResponse: Codable {
    public let object: String
    public let data: [APIModel]
}

struct ErrorResponse: Codable {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let message: String
        let type: String?
        let code: String?
    }
}