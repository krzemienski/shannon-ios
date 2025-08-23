//
//  RequestPrioritizer.swift
//  ClaudeCode
//
//  Request prioritization system for optimized network performance
//

import Foundation

/// Priority levels for network requests
enum RequestPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    static func < (lhs: RequestPriority, rhs: RequestPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Manages prioritized execution of network requests
actor RequestPrioritizer {
    
    // MARK: - Types
    
    struct PrioritizedRequest {
        let id: UUID
        let request: URLRequest
        let priority: RequestPriority
        let timestamp: Date
        let completion: (Result<Data, Error>) -> Void
        
        var score: Double {
            // Higher priority = higher score
            // Older requests get slight boost to prevent starvation
            let priorityScore = Double(priority.rawValue) * 1000
            let ageBonus = min(Date().timeIntervalSince(timestamp) * 10, 100)
            return priorityScore + ageBonus
        }
    }
    
    // MARK: - Properties
    
    private var pendingRequests: [PrioritizedRequest] = []
    private var activeRequests: [UUID: URLSessionDataTask] = [:]
    private let maxConcurrentRequests: Int
    private let session: URLSession
    private let debouncer = Debouncer(delay: 0.1)
    
    // Metrics
    private var requestMetrics: [RequestMetric] = []
    private var priorityStats: [RequestPriority: Int] = [:]
    
    // MARK: - Initialization
    
    init(maxConcurrentRequests: Int = 6, session: URLSession = .shared) {
        self.maxConcurrentRequests = maxConcurrentRequests
        self.session = session
    }
    
    // MARK: - Public Methods
    
    /// Add a request to the priority queue
    func enqueue(
        request: URLRequest,
        priority: RequestPriority = .normal,
        completion: @escaping (Result<Data, Error>) -> Void
    ) -> UUID {
        let requestId = UUID()
        
        let prioritizedRequest = PrioritizedRequest(
            id: requestId,
            request: request,
            priority: priority,
            timestamp: Date(),
            completion: completion
        )
        
        // Add to pending queue
        pendingRequests.append(prioritizedRequest)
        
        // Update statistics
        priorityStats[priority, default: 0] += 1
        
        // Process queue
        Task {
            await processQueue()
        }
        
        return requestId
    }
    
    /// Cancel a pending or active request
    func cancel(requestId: UUID) {
        // Remove from pending
        pendingRequests.removeAll { $0.id == requestId }
        
        // Cancel if active
        if let task = activeRequests[requestId] {
            task.cancel()
            activeRequests.removeValue(forKey: requestId)
        }
    }
    
    /// Cancel all requests
    func cancelAll() {
        pendingRequests.removeAll()
        
        for (_, task) in activeRequests {
            task.cancel()
        }
        activeRequests.removeAll()
    }
    
    /// Get current queue status
    func getQueueStatus() -> (pending: Int, active: Int) {
        (pending: pendingRequests.count, active: activeRequests.count)
    }
    
    /// Get priority statistics
    func getPriorityStats() -> [RequestPriority: Int] {
        priorityStats
    }
    
    // MARK: - Private Methods
    
    private func processQueue() async {
        // Check if we can process more requests
        guard activeRequests.count < maxConcurrentRequests,
              !pendingRequests.isEmpty else { return }
        
        // Sort by priority score (highest first)
        pendingRequests.sort { $0.score > $1.score }
        
        // Process highest priority requests
        while activeRequests.count < maxConcurrentRequests,
              !pendingRequests.isEmpty {
            
            let prioritizedRequest = pendingRequests.removeFirst()
            await executeRequest(prioritizedRequest)
        }
    }
    
    private func executeRequest(_ prioritizedRequest: PrioritizedRequest) async {
        let startTime = Date()
        
        let task = session.dataTask(with: prioritizedRequest.request) { [weak self] data, response, error in
            Task {
                await self?.handleRequestCompletion(
                    requestId: prioritizedRequest.id,
                    priority: prioritizedRequest.priority,
                    startTime: startTime,
                    data: data,
                    response: response,
                    error: error,
                    completion: prioritizedRequest.completion
                )
            }
        }
        
        activeRequests[prioritizedRequest.id] = task
        task.resume()
    }
    
    private func handleRequestCompletion(
        requestId: UUID,
        priority: RequestPriority,
        startTime: Date,
        data: Data?,
        response: URLResponse?,
        error: Error?,
        completion: @escaping (Result<Data, Error>) -> Void
    ) async {
        // Remove from active requests
        activeRequests.removeValue(forKey: requestId)
        
        // Record metrics
        let duration = Date().timeIntervalSince(startTime)
        let metric = RequestMetric(
            priority: priority,
            duration: duration,
            success: error == nil,
            timestamp: Date()
        )
        requestMetrics.append(metric)
        
        // Cleanup old metrics (keep last 100)
        if requestMetrics.count > 100 {
            requestMetrics.removeFirst(requestMetrics.count - 100)
        }
        
        // Call completion handler
        if let error = error {
            completion(.failure(error))
        } else if let data = data {
            completion(.success(data))
        } else {
            completion(.failure(NetworkError.noData))
        }
        
        // Process next requests
        await processQueue()
    }
    
    /// Get average request duration by priority
    func getAverageDuration(for priority: RequestPriority) -> TimeInterval? {
        let priorityMetrics = requestMetrics.filter { $0.priority == priority }
        guard !priorityMetrics.isEmpty else { return nil }
        
        let totalDuration = priorityMetrics.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(priorityMetrics.count)
    }
    
    /// Get success rate by priority
    func getSuccessRate(for priority: RequestPriority) -> Double? {
        let priorityMetrics = requestMetrics.filter { $0.priority == priority }
        guard !priorityMetrics.isEmpty else { return nil }
        
        let successCount = priorityMetrics.filter { $0.success }.count
        return Double(successCount) / Double(priorityMetrics.count)
    }
}

// MARK: - Supporting Types

struct RequestMetric {
    let priority: RequestPriority
    let duration: TimeInterval
    let success: Bool
    let timestamp: Date
}

enum NetworkError: LocalizedError {
    case noData
    case invalidResponse
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data received from server"
        case .invalidResponse:
            return "Invalid response from server"
        case .timeout:
            return "Request timed out"
        }
    }
}

// MARK: - URLRequest Extension

extension URLRequest {
    /// Set request priority hint
    mutating func setPriority(_ priority: RequestPriority) {
        switch priority {
        case .critical:
            self.networkServiceType = .responsiveData
            self.allowsCellularAccess = true
        case .high:
            self.networkServiceType = .default
            self.allowsCellularAccess = true
        case .normal:
            self.networkServiceType = .default
            self.allowsCellularAccess = true
        case .low:
            self.networkServiceType = .background
            self.allowsCellularAccess = false
        }
    }
}