import Foundation
import OSLog
import Combine

/// Offline queue manager for request persistence and retry (Tasks 486-490)
@MainActor
class OfflineQueueManager: ObservableObject {
    // MARK: - Properties
    
    static let shared = OfflineQueueManager()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "OfflineQueue")
    
    // Published properties
    @Published var queuedRequests: [QueuedRequest] = []
    @Published var isProcessing = false
    @Published var processedCount = 0
    @Published var failedCount = 0
    
    // Queue management
    private let maxQueueSize = 1000
    private let maxRetries = 3
    private let persistenceManager = QueuePersistenceManager()
    private let priorityQueue = PriorityQueue<QueuedRequest>()
    
    // Processing state
    private var processingTask: Task<Void, Never>?
    private var networkMonitor: NetworkMonitor?
    private var cancellables = Set<AnyCancellable>()
    
    // Retry strategy
    private let retryStrategy = ExponentialBackoffStrategy()
    
    // MARK: - Initialization
    
    private init() {
        loadPersistedQueue()
        setupNetworkMonitoring()
    }
    
    // MARK: - Setup
    
    private func setupNetworkMonitoring() {
        networkMonitor = NetworkMonitor.shared
        
        // Monitor network status changes
        networkMonitor?.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                if isConnected {
                    Task { @MainActor in
                        await self?.processQueue()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadPersistedQueue() {
        Task {
            let persisted = await persistenceManager.loadQueue()
            queuedRequests = persisted
            
            // Add to priority queue
            for request in persisted {
                priorityQueue.enqueue(request, priority: request.priority.rawValue)
            }
            
            logger.info("Loaded \(persisted.count) persisted requests")
        }
    }
    
    // MARK: - Queue Management
    
    /// Queue a request for offline execution
    func enqueue(_ request: URLRequest, priority: RequestPriority = .normal, metadata: RequestMetadata? = nil) throws {
        guard queuedRequests.count < maxQueueSize else {
            throw OfflineQueueError.queueFull
        }
        
        let queuedRequest = QueuedRequest(
            id: UUID(),
            request: request,
            priority: priority,
            metadata: metadata ?? RequestMetadata(),
            queuedAt: Date(),
            retryCount: 0,
            lastAttempt: nil,
            error: nil
        )
        
        // Add to queue
        queuedRequests.append(queuedRequest)
        priorityQueue.enqueue(queuedRequest, priority: priority.rawValue)
        
        // Persist queue
        Task {
            await persistenceManager.saveQueue(queuedRequests)
        }
        
        logger.debug("Queued request: \(request.url?.absoluteString ?? "unknown") [Priority: \(priority)]")
        
        // Try to process immediately if online
        if networkMonitor?.isConnected == true {
            Task {
                await processQueue()
            }
        }
    }
    
    /// Remove a request from the queue
    func dequeue(_ id: UUID) {
        queuedRequests.removeAll { $0.id == id }
        Task {
            await persistenceManager.saveQueue(queuedRequests)
        }
    }
    
    /// Clear all queued requests
    func clearQueue() {
        queuedRequests.removeAll()
        priorityQueue.clear()
        Task {
            await persistenceManager.clearQueue()
        }
        logger.info("Queue cleared")
    }
    
    /// Get queue statistics
    func getStatistics() -> QueueStatistics {
        let pendingCount = queuedRequests.filter { $0.status == .pending }.count
        let retryingCount = queuedRequests.filter { $0.status == .retrying }.count
        let failedRequests = queuedRequests.filter { $0.status == .failed }
        
        return QueueStatistics(
            totalQueued: queuedRequests.count,
            pending: pendingCount,
            retrying: retryingCount,
            processed: processedCount,
            failed: failedCount,
            oldestRequest: queuedRequests.min(by: { $0.queuedAt < $1.queuedAt })?.queuedAt,
            averageRetries: calculateAverageRetries(),
            queueSizeBytes: calculateQueueSize()
        )
    }
    
    // MARK: - Queue Processing
    
    /// Process all queued requests
    func processQueue() async {
        guard !isProcessing else { return }
        guard networkMonitor?.isConnected == true else {
            logger.info("Cannot process queue: offline")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        logger.info("Starting queue processing [\(queuedRequests.count) requests]")
        
        // Process requests by priority
        while let queuedRequest = priorityQueue.dequeue() {
            await processRequest(queuedRequest)
        }
        
        // Persist updated queue
        await persistenceManager.saveQueue(queuedRequests)
        
        logger.info("Queue processing complete [Processed: \(processedCount), Failed: \(failedCount)]")
    }
    
    private func processRequest(_ queuedRequest: QueuedRequest) async {
        var request = queuedRequest
        request.lastAttempt = Date()
        request.status = .processing
        
        // Update in queue
        if let index = queuedRequests.firstIndex(where: { $0.id == request.id }) {
            queuedRequests[index] = request
        }
        
        do {
            // Execute request
            let (data, response) = try await URLSession.shared.data(for: request.request)
            
            // Check response
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode < 400 {
                    // Success
                    handleSuccess(for: request, data: data, response: httpResponse)
                } else {
                    // Server error
                    throw OfflineQueueError.serverError(statusCode: httpResponse.statusCode)
                }
            }
        } catch {
            // Handle failure
            await handleFailure(for: request, error: error)
        }
    }
    
    private func handleSuccess(for request: QueuedRequest, data: Data, response: HTTPURLResponse) {
        processedCount += 1
        
        // Remove from queue
        queuedRequests.removeAll { $0.id == request.id }
        
        // Log success
        logger.info("Request processed successfully: \(request.request.url?.absoluteString ?? "unknown")")
        
        // Notify if callback provided
        if let callback = request.metadata.successCallback {
            callback(data, response)
        }
    }
    
    private func handleFailure(for request: QueuedRequest, error: Error) async {
        var updatedRequest = request
        updatedRequest.retryCount += 1
        updatedRequest.error = error.localizedDescription
        
        // Check if should retry
        if shouldRetry(updatedRequest, error: error) {
            // Schedule retry
            updatedRequest.status = .retrying
            let retryDelay = retryStrategy.calculateDelay(for: updatedRequest.retryCount)
            updatedRequest.nextRetryAt = Date().addingTimeInterval(retryDelay)
            
            // Re-enqueue with adjusted priority
            let adjustedPriority = adjustPriorityForRetry(updatedRequest.priority, retryCount: updatedRequest.retryCount)
            priorityQueue.enqueue(updatedRequest, priority: adjustedPriority.rawValue)
            
            logger.info("Request scheduled for retry #\(updatedRequest.retryCount) in \(retryDelay)s")
        } else {
            // Max retries reached or non-retryable error
            updatedRequest.status = .failed
            failedCount += 1
            
            logger.error("Request failed permanently: \(error.localizedDescription)")
            
            // Notify if callback provided
            if let callback = request.metadata.failureCallback {
                callback(error)
            }
        }
        
        // Update in queue
        if let index = queuedRequests.firstIndex(where: { $0.id == request.id }) {
            queuedRequests[index] = updatedRequest
        }
    }
    
    private func shouldRetry(_ request: QueuedRequest, error: Error) -> Bool {
        // Don't retry if max retries reached
        if request.retryCount >= maxRetries {
            return false
        }
        
        // Check if error is retryable
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return true
            case .cannotFindHost, .cannotConnectToHost:
                return request.retryCount < 2  // Limited retries for host issues
            default:
                return false
            }
        }
        
        if let queueError = error as? OfflineQueueError {
            switch queueError {
            case .serverError(let statusCode):
                // Retry on server errors and rate limiting
                return statusCode >= 500 || statusCode == 429
            default:
                return false
            }
        }
        
        return false
    }
    
    private func adjustPriorityForRetry(_ original: RequestPriority, retryCount: Int) -> RequestPriority {
        // Lower priority with each retry
        switch original {
        case .critical:
            return retryCount > 1 ? .high : .critical
        case .high:
            return retryCount > 1 ? .normal : .high
        case .normal:
            return retryCount > 1 ? .low : .normal
        case .low:
            return .low
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateAverageRetries() -> Double {
        let totalRetries = queuedRequests.map { $0.retryCount }.reduce(0, +)
        return Double(totalRetries) / Double(max(queuedRequests.count, 1))
    }
    
    private func calculateQueueSize() -> Int {
        return queuedRequests.compactMap { try? JSONEncoder().encode($0) }
            .map { $0.count }
            .reduce(0, +)
    }
    
    // MARK: - Batch Operations
    
    /// Process requests matching a predicate
    func processBatch(matching predicate: (QueuedRequest) -> Bool) async {
        let matching = queuedRequests.filter(predicate)
        
        for request in matching {
            await processRequest(request)
        }
    }
    
    /// Remove requests matching a predicate
    func removeBatch(matching predicate: (QueuedRequest) -> Bool) {
        queuedRequests.removeAll(where: predicate)
        Task {
            await persistenceManager.saveQueue(queuedRequests)
        }
    }
    
    /// Retry all failed requests
    func retryFailed() async {
        let failed = queuedRequests.filter { $0.status == .failed }
        
        for var request in failed {
            request.status = .pending
            request.retryCount = 0
            request.error = nil
            
            if let index = queuedRequests.firstIndex(where: { $0.id == request.id }) {
                queuedRequests[index] = request
                priorityQueue.enqueue(request, priority: request.priority.rawValue)
            }
        }
        
        await processQueue()
    }
}

// MARK: - Supporting Types

/// Queued request structure
struct QueuedRequest: Codable, Identifiable {
    let id: UUID
    let request: URLRequest
    let priority: RequestPriority
    let metadata: RequestMetadata
    let queuedAt: Date
    var retryCount: Int
    var lastAttempt: Date?
    var nextRetryAt: Date?
    var status: QueueStatus = .pending
    var error: String?
}

/// Request metadata
struct RequestMetadata: Codable {
    var tag: String?
    var userInfo: [String: String] = [:]
    var expiresAt: Date?
    var requiresWiFi: Bool = false
    var allowsCellular: Bool = true
    var successCallback: ((Data, HTTPURLResponse) -> Void)?
    var failureCallback: ((Error) -> Void)?
    
    enum CodingKeys: String, CodingKey {
        case tag, userInfo, expiresAt, requiresWiFi, allowsCellular
    }
}

/// Queue status
enum QueueStatus: String, Codable {
    case pending
    case processing
    case retrying
    case failed
    case completed
}

/// Queue statistics
struct QueueStatistics {
    let totalQueued: Int
    let pending: Int
    let retrying: Int
    let processed: Int
    let failed: Int
    let oldestRequest: Date?
    let averageRetries: Double
    let queueSizeBytes: Int
}

/// Offline queue errors
enum OfflineQueueError: LocalizedError {
    case queueFull
    case persistenceError
    case serverError(statusCode: Int)
    case expired
    case networkTypeNotAllowed
    
    var errorDescription: String? {
        switch self {
        case .queueFull:
            return "Offline queue is full"
        case .persistenceError:
            return "Failed to persist queue"
        case .serverError(let statusCode):
            return "Server error: \(statusCode)"
        case .expired:
            return "Request has expired"
        case .networkTypeNotAllowed:
            return "Current network type not allowed for this request"
        }
    }
}

// MARK: - Queue Persistence

/// Manages persistent storage of the queue
class QueuePersistenceManager {
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "QueuePersistence")
    private let fileManager = FileManager.default
    private let queueFileName = "offline_queue.json"
    
    private var queueFileURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(queueFileName)
    }
    
    func saveQueue(_ queue: [QueuedRequest]) async {
        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: queueFileURL)
            logger.debug("Saved \(queue.count) requests to persistent storage")
        } catch {
            logger.error("Failed to save queue: \(error)")
        }
    }
    
    func loadQueue() async -> [QueuedRequest] {
        guard fileManager.fileExists(atPath: queueFileURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: queueFileURL)
            let queue = try JSONDecoder().decode([QueuedRequest].self, from: data)
            
            // Filter out expired requests
            let validQueue = queue.filter { request in
                if let expiresAt = request.metadata.expiresAt {
                    return expiresAt > Date()
                }
                return true
            }
            
            logger.debug("Loaded \(validQueue.count) valid requests from persistent storage")
            return validQueue
        } catch {
            logger.error("Failed to load queue: \(error)")
            return []
        }
    }
    
    func clearQueue() async {
        do {
            if fileManager.fileExists(atPath: queueFileURL.path) {
                try fileManager.removeItem(at: queueFileURL)
                logger.debug("Cleared persistent queue")
            }
        } catch {
            logger.error("Failed to clear queue: \(error)")
        }
    }
}

// MARK: - Priority Queue

/// Generic priority queue implementation
class PriorityQueue<T> {
    private var heap: [(element: T, priority: Int)] = []
    
    var isEmpty: Bool { heap.isEmpty }
    var count: Int { heap.count }
    
    func enqueue(_ element: T, priority: Int) {
        heap.append((element, priority))
        heapifyUp(from: heap.count - 1)
    }
    
    func dequeue() -> T? {
        guard !heap.isEmpty else { return nil }
        
        if heap.count == 1 {
            return heap.removeFirst().element
        }
        
        let item = heap[0].element
        heap[0] = heap.removeLast()
        heapifyDown(from: 0)
        
        return item
    }
    
    func clear() {
        heap.removeAll()
    }
    
    private func heapifyUp(from index: Int) {
        var childIndex = index
        let child = heap[childIndex]
        var parentIndex = (childIndex - 1) / 2
        
        while childIndex > 0 && heap[parentIndex].priority < child.priority {
            heap[childIndex] = heap[parentIndex]
            childIndex = parentIndex
            parentIndex = (childIndex - 1) / 2
        }
        
        heap[childIndex] = child
    }
    
    private func heapifyDown(from index: Int) {
        var parentIndex = index
        
        while true {
            let leftChildIndex = 2 * parentIndex + 1
            let rightChildIndex = leftChildIndex + 1
            var largest = parentIndex
            
            if leftChildIndex < heap.count && heap[leftChildIndex].priority > heap[largest].priority {
                largest = leftChildIndex
            }
            
            if rightChildIndex < heap.count && heap[rightChildIndex].priority > heap[largest].priority {
                largest = rightChildIndex
            }
            
            if largest == parentIndex {
                break
            }
            
            heap.swapAt(parentIndex, largest)
            parentIndex = largest
        }
    }
}

// MARK: - Retry Strategy

/// Exponential backoff retry strategy
struct ExponentialBackoffStrategy {
    let baseDelay: TimeInterval = 1.0
    let maxDelay: TimeInterval = 300.0  // 5 minutes
    let multiplier: Double = 2.0
    let jitterFactor: Double = 0.1
    
    func calculateDelay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(multiplier, Double(attempt - 1))
        let clampedDelay = min(exponentialDelay, maxDelay)
        let jitter = clampedDelay * jitterFactor * Double.random(in: -1...1)
        return clampedDelay + jitter
    }
}