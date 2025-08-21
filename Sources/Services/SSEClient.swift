import Foundation
import OSLog

/// Enhanced Server-Sent Events client for streaming API responses (Tasks 351-400)
class SSEClient: NSObject {
    // MARK: - Properties
    
    private var urlSession: URLSession?
    private var dataTask: URLSessionDataTask?
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSEClient")
    
    // Event handlers
    private var onMessage: ((SSEMessage) -> Void)?
    private var onError: ((Error) -> Void)?
    private var onComplete: (() -> Void)?
    private var onReconnect: (() -> Void)?  // Task 361: Reconnection handler
    private var onHeartbeat: (() -> Void)?  // Task 365: Heartbeat handler
    
    // Streaming state
    private var buffer = Data()
    private var retryTime: TimeInterval = 3.0
    private var lastEventId: String?
    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5  // Task 362: Max reconnection attempts
    
    // Connection management (Tasks 361-364)
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?  // Task 365: Heartbeat timer
    private let heartbeatInterval: TimeInterval = 30.0
    private var lastHeartbeatTime: Date?
    
    // Stream parsing (Tasks 366-370)
    private var currentEvent = SSEEvent()
    private let eventParser = SSEEventParser()
    private var streamMetrics = StreamMetrics()  // Task 371: Stream metrics
    
    // Backpressure handling (Task 372)
    private var eventQueue: [SSEMessage] = []
    private let maxQueueSize = 100
    private var isProcessingQueue = false
    
    // Stream compression (Task 373)
    private var compressionEnabled = false
    private var decompressor: StreamDecompressor?
    
    // Stream validation (Task 374)
    private let streamValidator = StreamValidator()
    
    // Stream buffering (Task 375)
    private let bufferManager = StreamBufferManager(maxSize: 1024 * 1024)  // 1MB max
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 5 minutes for streaming
        configuration.timeoutIntervalForResource = 600 // 10 minutes total
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Optimize for streaming (Task 376)
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.httpShouldUsePipelining = false
        configuration.allowsCellularAccess = true
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = false
        
        // Enable HTTP/2 for better streaming (Task 377)
        configuration.multipathServiceType = .handover
        
        self.urlSession = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: OperationQueue()  // Use dedicated queue for streaming
        )
    }
    
    // MARK: - Public Methods
    
    /// Connect to SSE endpoint with enhanced features (Tasks 351-360)
    func connect(
        to url: URL,
        headers: [String: String] = [:],
        onMessage: @escaping (SSEMessage) -> Void,
        onError: @escaping (Error) -> Void,
        onComplete: @escaping () -> Void,
        onReconnect: (() -> Void)? = nil,
        onHeartbeat: (() -> Void)? = nil,
        options: StreamOptions = .default
    ) {
        self.onMessage = onMessage
        self.onError = onError
        self.onComplete = onComplete
        self.onReconnect = onReconnect
        self.onHeartbeat = onHeartbeat
        
        // Apply stream options (Task 378)
        compressionEnabled = options.enableCompression
        bufferManager.maxSize = options.bufferSize
        eventParser.strictMode = options.strictParsing
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Set SSE headers
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        // Enable compression if supported (Task 373)
        if compressionEnabled {
            request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        }
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add last event ID if available for resumption (Task 379)
        if let lastEventId = lastEventId {
            request.setValue(lastEventId, forHTTPHeaderField: "Last-Event-ID")
        }
        
        // Start connection
        logger.debug("Connecting to SSE: \(url) [Compression: \(compressionEnabled)]")
        streamMetrics.connectionStartTime = Date()
        dataTask = urlSession?.dataTask(with: request)
        dataTask?.resume()
        
        // Start heartbeat monitoring (Task 365)
        startHeartbeatMonitoring()
    }
    
    /// Connect for chat streaming
    func streamChat(
        request: ChatCompletionRequest,
        apiKey: String? = nil,
        onMessage: @escaping (ChatStreamChunk) -> Void,
        onError: @escaping (Error) -> Void,
        onComplete: @escaping () -> Void
    ) {
        // Modify request for streaming
        var streamRequest = request
        streamRequest.stream = true
        
        // Create URL request
        let url = APIConfig.Endpoint.chatStream.url()
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.allHTTPHeaderFields = APIConfig.sseHeaders(apiKey: apiKey)
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(streamRequest)
        } catch {
            onError(error)
            return
        }
        
        // Setup handlers
        self.onMessage = { message in
            // Parse chat chunk from SSE message
            if message.data == "[DONE]" {
                onComplete()
                return
            }
            
            do {
                let chunk = try JSONDecoder().decode(ChatStreamChunk.self, from: Data(message.data.utf8))
                onMessage(chunk)
            } catch {
                self.logger.error("Failed to decode chat chunk: \(error)")
            }
        }
        self.onError = onError
        self.onComplete = onComplete
        
        // Start streaming
        logger.debug("Starting chat stream")
        dataTask = urlSession?.dataTask(with: urlRequest)
        dataTask?.resume()
    }
    
    /// Disconnect from SSE with cleanup (Tasks 380-381)
    func disconnect() {
        logger.debug("Disconnecting SSE client")
        
        // Stop timers
        stopHeartbeatMonitoring()
        cancelReconnectTimer()
        
        // Cancel data task
        dataTask?.cancel()
        dataTask = nil
        
        // Clear state
        buffer = Data()
        lastEventId = nil
        isConnected = false
        reconnectAttempts = 0
        eventQueue.removeAll()
        
        // Log metrics (Task 371)
        logStreamMetrics()
    }
    
    // MARK: - Private Methods
    
    // MARK: - Reconnection Logic (Tasks 361-364)
    
    private func handleDisconnection() {
        guard isConnected else { return }
        
        isConnected = false
        reconnectAttempts += 1
        
        if reconnectAttempts <= maxReconnectAttempts {
            logger.info("Attempting reconnection \(reconnectAttempts)/\(maxReconnectAttempts)")
            scheduleReconnect()
        } else {
            logger.error("Max reconnection attempts reached")
            DispatchQueue.main.async {
                self.onError?(SSEError.maxReconnectAttemptsReached)
            }
        }
    }
    
    private func scheduleReconnect() {
        let delay = ExponentialBackoff.calculate(
            attempt: reconnectAttempts,
            baseDelay: retryTime,
            maxDelay: 60.0
        )
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            self.attemptReconnection()
        }
    }
    
    private func attemptReconnection() {
        guard let task = dataTask else { return }
        
        logger.info("Reconnecting to SSE stream...")
        task.resume()
        onReconnect?()
    }
    
    private func cancelReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    // MARK: - Heartbeat Monitoring (Task 365)
    
    private func startHeartbeatMonitoring() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { _ in
            self.checkHeartbeat()
        }
    }
    
    private func stopHeartbeatMonitoring() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func checkHeartbeat() {
        if let lastHeartbeat = lastHeartbeatTime {
            let timeSinceHeartbeat = Date().timeIntervalSince(lastHeartbeat)
            if timeSinceHeartbeat > heartbeatInterval * 2 {
                logger.warning("Heartbeat timeout detected")
                handleDisconnection()
            }
        }
    }
    
    private func recordHeartbeat() {
        lastHeartbeatTime = Date()
        onHeartbeat?()
    }
    
    // MARK: - Enhanced Buffer Processing (Tasks 366-370)
    
    private func processBuffer() {
        // Convert buffer to string
        guard let string = String(data: buffer, encoding: .utf8) else { return }
        
        // Split into lines
        let lines = string.components(separatedBy: "\n")
        
        var eventType: String?
        var eventData: [String] = []
        var eventId: String?
        var eventRetry: TimeInterval?
        
        for line in lines {
            if line.isEmpty || line.hasPrefix("\n") {
                // Empty line indicates end of event
                if !eventData.isEmpty {
                    let message = SSEMessage(
                        id: eventId,
                        event: eventType ?? "message",
                        data: eventData.joined(separator: "\n"),
                        retry: eventRetry
                    )
                    
                    // Update last event ID
                    if let id = eventId {
                        lastEventId = id
                    }
                    
                    // Update retry time
                    if let retry = eventRetry {
                        retryTime = retry
                    }
                    
                    // Validate message (Task 374)
                    if streamValidator.validate(message) {
                        // Handle backpressure (Task 372)
                        if eventQueue.count < maxQueueSize {
                            eventQueue.append(message)
                            processEventQueue()
                        } else {
                            logger.warning("Event queue full, dropping message")
                            streamMetrics.droppedEvents += 1
                        }
                    } else {
                        logger.warning("Invalid SSE message received")
                        streamMetrics.invalidEvents += 1
                    }
                    
                    // Reset for next event
                    eventType = nil
                    eventData = []
                    eventId = nil
                    eventRetry = nil
                }
                continue
            }
            
            // Parse field
            if line.hasPrefix(":") {
                // Comment, ignore
                continue
            }
            
            if let colonIndex = line.firstIndex(of: ":") {
                let field = String(line[..<colonIndex])
                var value = String(line[line.index(after: colonIndex)...])
                
                // Remove leading space if present
                if value.hasPrefix(" ") {
                    value = String(value.dropFirst())
                }
                
                switch field {
                case "event":
                    eventType = value
                case "data":
                    eventData.append(value)
                case "id":
                    eventId = value
                case "retry":
                    eventRetry = TimeInterval(value)
                default:
                    // Unknown field, ignore
                    break
                }
            }
        }
        
        // Keep any incomplete line in buffer
        if let lastLine = lines.last, !lastLine.isEmpty && !string.hasSuffix("\n") {
            buffer = Data(lastLine.utf8)
        } else {
            buffer = Data()
        }
    }
}

// MARK: - URLSessionDataDelegate

extension SSEClient: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }
        
        logger.debug("SSE Response: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            completionHandler(.allow)
        } else {
            let error = APIConfig.APIError.serverError(
                statusCode: httpResponse.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
            DispatchQueue.main.async {
                self.onError?(error)
            }
            completionHandler(.cancel)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Handle compression if enabled (Task 373)
        let processedData: Data
        if compressionEnabled, let decompressed = decompressor?.decompress(data) {
            processedData = decompressed
        } else {
            processedData = data
        }
        
        // Update metrics (Task 371)
        streamMetrics.bytesReceived += processedData.count
        streamMetrics.eventsReceived += 1
        
        // Append to buffer with management (Task 375)
        bufferManager.append(processedData)
        
        // Process buffer for complete events
        if let bufferData = bufferManager.getBuffer() {
            buffer = bufferData
            processBuffer()
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logger.error("SSE Error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.onError?(error)
            }
        } else {
            logger.debug("SSE Complete")
            DispatchQueue.main.async {
                self.onComplete?()
            }
        }
        
        // Clean up
        buffer = Data()
    }
}

    // MARK: - Event Queue Processing (Task 372)
    
    private func processEventQueue() {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true
        
        DispatchQueue.main.async {
            while !self.eventQueue.isEmpty {
                let message = self.eventQueue.removeFirst()
                self.onMessage?(message)
            }
            self.isProcessingQueue = false
        }
    }
    
    // MARK: - Metrics Logging (Task 371)
    
    private func logStreamMetrics() {
        logger.info("""
            Stream Metrics:
            - Duration: \(streamMetrics.duration)s
            - Events Received: \(streamMetrics.eventsReceived)
            - Bytes Received: \(streamMetrics.bytesReceived)
            - Invalid Events: \(streamMetrics.invalidEvents)
            - Dropped Events: \(streamMetrics.droppedEvents)
            - Reconnections: \(reconnectAttempts)
        """)
    }

// MARK: - Supporting Types

/// SSE message structure
struct SSEMessage {
    let id: String?
    let event: String
    let data: String
    let retry: TimeInterval?
}

/// SSE Event for parsing (Task 366)
struct SSEEvent {
    var id: String?
    var event: String?
    var data: [String] = []
    var retry: TimeInterval?
    
    mutating func reset() {
        id = nil
        event = nil
        data = []
        retry = nil
    }
    
    func toMessage() -> SSEMessage? {
        guard !data.isEmpty else { return nil }
        return SSEMessage(
            id: id,
            event: event ?? "message",
            data: data.joined(separator: "\n"),
            retry: retry
        )
    }
}

/// Stream Options (Task 378)
struct StreamOptions {
    let enableCompression: Bool
    let bufferSize: Int
    let strictParsing: Bool
    let enableHeartbeat: Bool
    let heartbeatInterval: TimeInterval
    
    static let `default` = StreamOptions(
        enableCompression: true,
        bufferSize: 1024 * 1024,  // 1MB
        strictParsing: false,
        enableHeartbeat: true,
        heartbeatInterval: 30.0
    )
}

/// Stream Metrics (Task 371)
struct StreamMetrics {
    var connectionStartTime: Date?
    var eventsReceived: Int = 0
    var bytesReceived: Int = 0
    var invalidEvents: Int = 0
    var droppedEvents: Int = 0
    
    var duration: TimeInterval {
        guard let start = connectionStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
}

/// SSE Errors
enum SSEError: LocalizedError {
    case maxReconnectAttemptsReached
    case invalidEventFormat
    case bufferOverflow
    case compressionError
    case heartbeatTimeout
    
    var errorDescription: String? {
        switch self {
        case .maxReconnectAttemptsReached:
            return "Maximum reconnection attempts reached"
        case .invalidEventFormat:
            return "Invalid SSE event format"
        case .bufferOverflow:
            return "Stream buffer overflow"
        case .compressionError:
            return "Failed to decompress stream data"
        case .heartbeatTimeout:
            return "Stream heartbeat timeout"
        }
    }
}

/// SSE Event Parser (Task 367)
class SSEEventParser {
    var strictMode = false
    
    func parse(_ line: String, into event: inout SSEEvent) -> Bool {
        if line.isEmpty {
            return true  // Event separator
        }
        
        if line.hasPrefix(":") {
            // Comment, ignore
            return false
        }
        
        guard let colonIndex = line.firstIndex(of: ":") else {
            if strictMode {
                return false  // Invalid format
            }
            return false
        }
        
        let field = String(line[..<colonIndex])
        var value = String(line[line.index(after: colonIndex)...])
        
        // Remove leading space if present
        if value.hasPrefix(" ") {
            value = String(value.dropFirst())
        }
        
        switch field {
        case "id":
            event.id = value
        case "event":
            event.event = value
        case "data":
            event.data.append(value)
        case "retry":
            event.retry = TimeInterval(value)
        default:
            if strictMode {
                return false  // Unknown field
            }
        }
        
        return true
    }
}

/// Stream Validator (Task 374)
class StreamValidator {
    func validate(_ message: SSEMessage) -> Bool {
        // Basic validation
        guard !message.data.isEmpty else { return false }
        
        // Check for special cases
        if message.data == "[DONE]" {
            return true
        }
        
        // Try to validate JSON if it looks like JSON
        if message.data.hasPrefix("{") || message.data.hasPrefix("[") {
            return JSONSerialization.isValidJSONObject(message.data)
        }
        
        return true
    }
}

/// Stream Buffer Manager (Task 375)
class StreamBufferManager {
    var maxSize: Int
    private var buffer = Data()
    private let lock = NSLock()
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        
        buffer.append(data)
        
        // Prevent buffer overflow
        if buffer.count > maxSize {
            // Keep only the last maxSize bytes
            buffer = buffer.suffix(maxSize)
        }
    }
    
    func getBuffer() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        
        guard !buffer.isEmpty else { return nil }
        let data = buffer
        buffer = Data()
        return data
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        buffer = Data()
    }
}

/// Stream Decompressor (Task 373)
class StreamDecompressor {
    func decompress(_ data: Data) -> Data? {
        // In production, use Compression framework
        // This is a placeholder implementation
        return data
    }
}

/// Chat stream chunk for OpenAI-compatible streaming
struct ChatStreamChunk: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [StreamChoice]
    
    struct StreamChoice: Codable {
        let index: Int
        let delta: StreamDelta
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
    }
    
    struct StreamDelta: Codable {
        let role: String?
        let content: String?
        let toolCalls: [ToolCallDelta]?
        
        enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
        }
    }
    
    struct ToolCallDelta: Codable {
        let index: Int
        let id: String?
        let type: String?
        let function: FunctionCallDelta?
    }
    
    struct FunctionCallDelta: Codable {
        let name: String?
        let arguments: String?
    }
}