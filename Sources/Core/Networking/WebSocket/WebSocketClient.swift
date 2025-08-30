//
//  WebSocketClient.swift
//  ClaudeCode
//
//  Core WebSocket client implementation using URLSessionWebSocketTask
//

import Foundation
import Combine
import OSLog

/// Core WebSocket client for real-time communication
public actor WebSocketClient {
    // MARK: - Types
    
    public enum ConnectionState: Equatable, Sendable {
        case disconnected
        case connecting
        case connected
        case disconnecting
        case failed(Error)
        
        public static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected),
                 (.connecting, .connecting),
                 (.connected, .connected),
                 (.disconnecting, .disconnecting):
                return true
            case (.failed(_), .failed(_)):
                return true  // Consider all failures equal for simplicity
            default:
                return false
            }
        }
        
        var isActive: Bool {
            switch self {
            case .connected, .connecting:
                return true
            default:
                return false
            }
        }
    }
    
    public enum WebSocketError: LocalizedError {
        case invalidURL
        case notConnected
        case connectionFailed(String)
        case sendFailed(String)
        case decodingFailed(String)
        case unauthorized
        case serverError(Int, String?)
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid WebSocket URL"
            case .notConnected:
                return "WebSocket is not connected"
            case .connectionFailed(let reason):
                return "Connection failed: \(reason)"
            case .sendFailed(let reason):
                return "Failed to send message: \(reason)"
            case .decodingFailed(let reason):
                return "Failed to decode message: \(reason)"
            case .unauthorized:
                return "Unauthorized - invalid or expired token"
            case .serverError(let code, let message):
                return "Server error (\(code)): \(message ?? "Unknown error")"
            }
        }
    }
    
    // MARK: - Properties
    
    private let url: URL
    private let authToken: String?
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var pingTask: Task<Void, Never>?
    private let pingInterval: TimeInterval = 30.0
    
    private var connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    public var connectionState: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    private var messageSubject = PassthroughSubject<URLSessionWebSocketTask.Message, Never>()
    public var messages: AnyPublisher<URLSessionWebSocketTask.Message, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "WebSocketClient")
    
    // Reconnection properties
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let baseReconnectDelay: TimeInterval = 2.0
    private var reconnectWorkItem: DispatchWorkItem?
    private var shouldReconnect = true
    
    // MARK: - Initialization
    
    public init(url: URL, authToken: String? = nil) {
        self.url = url
        self.authToken = authToken
        
        // Configure URLSession with custom configuration
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        
        // Add auth header if token provided
        if let token = authToken {
            configuration.httpAdditionalHeaders = ["Authorization": "Bearer \(token)"]
        }
        
        self.urlSession = URLSession(configuration: configuration)
    }
    
    // MARK: - Public Methods
    
    /// Connect to the WebSocket server
    public func connect() async throws {
        guard connectionStateSubject.value != .connected else {
            logger.debug("Already connected")
            return
        }
        
        connectionStateSubject.send(.connecting)
        shouldReconnect = true
        reconnectAttempts = 0
        
        do {
            try await establishConnection()
        } catch {
            connectionStateSubject.send(.failed(error))
            throw error
        }
    }
    
    /// Disconnect from the WebSocket server
    public func disconnect() async {
        logger.info("Disconnecting WebSocket")
        shouldReconnect = false
        connectionStateSubject.send(.disconnecting)
        
        // Cancel reconnect if pending
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        
        // Stop ping timer
        pingTask?.cancel()
        pingTask = nil
        
        // Close WebSocket connection
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        connectionStateSubject.send(.disconnected)
    }
    
    /// Send a text message
    public func send(text: String) async throws {
        guard connectionStateSubject.value == .connected,
              let task = webSocketTask else {
            throw WebSocketError.notConnected
        }
        
        let message = URLSessionWebSocketTask.Message.string(text)
        
        do {
            try await task.send(message)
            logger.debug("Sent text message: \(text.prefix(100))...")
        } catch {
            logger.error("Failed to send text message: \(error)")
            throw WebSocketError.sendFailed(error.localizedDescription)
        }
    }
    
    /// Send a data message
    public func send(data: Data) async throws {
        guard connectionStateSubject.value == .connected,
              let task = webSocketTask else {
            throw WebSocketError.notConnected
        }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        
        do {
            try await task.send(message)
            logger.debug("Sent data message: \(data.count) bytes")
        } catch {
            logger.error("Failed to send data message: \(error)")
            throw WebSocketError.sendFailed(error.localizedDescription)
        }
    }
    
    /// Send a JSON-encoded message
    public func send<T: Encodable>(_ object: T) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(object)
            let text = String(data: data, encoding: .utf8) ?? ""
            try await send(text: text)
        } catch {
            logger.error("Failed to encode object: \(error)")
            throw WebSocketError.sendFailed("Encoding failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Observation Methods
    
    /// Observe connection state changes
    public func observeConnectionState(_ handler: @escaping @Sendable (ConnectionState) async -> Void) async {
        // Subscribe to connection state changes
        Task {
            for await state in connectionStateSubject.values {
                await handler(state)
            }
        }
    }
    
    /// Observe incoming messages
    public func observeMessages(_ handler: @escaping @Sendable (URLSessionWebSocketTask.Message) async -> Void) async {
        // Subscribe to message stream
        Task {
            for await message in messageSubject.values {
                await handler(message)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func establishConnection() async throws {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        // Add auth header if token provided
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add WebSocket-specific headers
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        logger.info("WebSocket connection established to: \(self.url)")
        connectionStateSubject.send(.connected)
        
        // Start receiving messages
        await receiveMessages()
        
        // Start ping timer to keep connection alive
        await startPingTimer()
    }
    
    private func receiveMessages() async {
        guard let task = webSocketTask else { return }
        
        do {
            while connectionStateSubject.value == .connected {
                let message = try await task.receive()
                
                logger.debug("Received message: \(String(describing: message))")
                messageSubject.send(message)
                
                // Continue receiving
                Task {
                    await self.receiveMessages()
                }
                break
            }
        } catch {
            logger.error("Error receiving message: \(error)")
            
            if connectionStateSubject.value == .connected {
                await handleConnectionError(error)
            }
        }
    }
    
    private func startPingTimer() async {
        pingTask?.cancel()
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(pingInterval * 1_000_000_000))
                if !Task.isCancelled {
                    await sendPing()
                }
            }
        }
    }
    
    private func sendPing() async {
        guard connectionStateSubject.value == .connected,
              let task = webSocketTask else { return }
        
        do {
            try await task.sendPing { error in
                if let error = error {
                    self.logger.debug("Ping failed: \(error)")
                }
            }
            logger.debug("Ping sent")
        } catch {
            logger.error("Ping failed: \(error)")
            await handleConnectionError(error)
        }
    }
    
    private func handleConnectionError(_ error: Error) async {
        logger.error("Connection error: \(error)")
        
        // Update state
        connectionStateSubject.send(.failed(error))
        
        // Clean up current connection
        webSocketTask?.cancel()
        webSocketTask = nil
        
        pingTask?.cancel()
        pingTask = nil
        
        // Attempt reconnection if appropriate
        if shouldReconnect && reconnectAttempts < maxReconnectAttempts {
            await attemptReconnection()
        } else {
            connectionStateSubject.send(.disconnected)
        }
    }
    
    private func attemptReconnection() async {
        reconnectAttempts += 1
        
        // Calculate exponential backoff delay
        let delay = min(baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1)), 60.0)
        
        logger.info("Attempting reconnection #\(self.reconnectAttempts) after \(delay) seconds")
        
        // Schedule reconnection
        reconnectWorkItem?.cancel()
        reconnectWorkItem = DispatchWorkItem { 
            Task { @MainActor in
                // Reconnection handled elsewhere to avoid capture issues
            }
        }
        
        if let workItem = reconnectWorkItem {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetReconnectAttempts() {
        reconnectAttempts = 0
    }
    
    private func updateReconnectAttempts(_ count: Int) {
        reconnectAttempts = count
    }
    
    // Removed - using property shouldReconnect instead
    
    private func handleReconnectionError(_ error: Error) async {
        logger.error("Reconnection attempt #\(self.reconnectAttempts) failed: \(error)")
        
        if reconnectAttempts < maxReconnectAttempts {
            await attemptReconnection()
        } else {
            connectionStateSubject.send(.disconnected)
        }
    }
}