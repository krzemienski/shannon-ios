//
//  WebSocketService.swift
//  ClaudeCode
//
//  Service layer for WebSocket management and event coordination
//

import Foundation
import Combine
import SwiftUI
import OSLog

/// WebSocket service for managing real-time connections
@MainActor
public class WebSocketService: ObservableObject {
    // MARK: - Singleton
    
    public static let shared = WebSocketService()
    
    // MARK: - Published Properties
    
    @Published public private(set) var connectionState: WebSocketClient.ConnectionState = .disconnected
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var lastError: Error?
    @Published public private(set) var reconnectAttempts: Int = 0
    
    // MARK: - Properties
    
    private var webSocketClient: WebSocketClient?
    private var eventHandler: WebSocketEventHandler
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "WebSocketService")
    
    // Configuration
    private var baseURL: String = "ws://192.168.0.155:8000/ws"
    private var authToken: String?
    
    // Event subjects
    private let projectUpdateSubject = PassthroughSubject<ProjectUpdateEvent, Never>()
    private let chatUpdateSubject = PassthroughSubject<ChatUpdateEvent, Never>()
    private let fileChangeSubject = PassthroughSubject<FileChangeEvent, Never>()
    private let terminalOutputSubject = PassthroughSubject<TerminalOutputEvent, Never>()
    private let collaborationSubject = PassthroughSubject<CollaborationEvent, Never>()
    private let systemNotificationSubject = PassthroughSubject<SystemNotificationEvent, Never>()
    
    // Public event publishers
    public var projectUpdates: AnyPublisher<ProjectUpdateEvent, Never> {
        projectUpdateSubject.eraseToAnyPublisher()
    }
    
    public var chatUpdates: AnyPublisher<ChatUpdateEvent, Never> {
        chatUpdateSubject.eraseToAnyPublisher()
    }
    
    public var fileChanges: AnyPublisher<FileChangeEvent, Never> {
        fileChangeSubject.eraseToAnyPublisher()
    }
    
    public var terminalOutput: AnyPublisher<TerminalOutputEvent, Never> {
        terminalOutputSubject.eraseToAnyPublisher()
    }
    
    public var collaborationEvents: AnyPublisher<CollaborationEvent, Never> {
        collaborationSubject.eraseToAnyPublisher()
    }
    
    public var systemNotifications: AnyPublisher<SystemNotificationEvent, Never> {
        systemNotificationSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    private init() {
        self.eventHandler = WebSocketEventHandler()
        setupEventHandling()
        observeAppLifecycle()
    }
    
    // MARK: - Public Methods
    
    /// Configure the WebSocket service
    public func configure(baseURL: String, authToken: String? = nil) {
        self.baseURL = baseURL.replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        self.authToken = authToken
        
        // If already connected, reconnect with new configuration
        if isConnected {
            Task {
                await disconnect()
                try? await connect()
            }
        }
    }
    
    /// Connect to the WebSocket server
    public func connect() async throws {
        guard let url = URL(string: baseURL) else {
            throw WebSocketClient.WebSocketError.invalidURL
        }
        
        // Create new WebSocket client
        let client = WebSocketClient(url: url, authToken: authToken)
        self.webSocketClient = client
        
        // Subscribe to connection state changes
        Task {
            await client.observeConnectionState { [weak self] state in
                await MainActor.run {
                    self?.handleConnectionStateChange(state)
                }
            }
        }
        
        // Subscribe to messages
        Task {
            await client.observeMessages { [weak self] message in
                await MainActor.run {
                    self?.handleMessage(message)
                }
            }
        }
        
        // Connect
        try await client.connect()
        
        // Send initial authentication if needed
        if authToken != nil {
            try await authenticate()
        }
    }
    
    /// Disconnect from the WebSocket server
    public func disconnect() async {
        await webSocketClient?.disconnect()
        webSocketClient = nil
        cancellables.removeAll()
    }
    
    /// Send a message to the server
    public func send<T: Encodable>(_ message: T) async throws {
        guard let client = webSocketClient else {
            throw WebSocketClient.WebSocketError.notConnected
        }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let text = String(data: data, encoding: .utf8) ?? ""
        try await client.send(text: text)
    }
    
    /// Send a raw text message
    public func sendText(_ text: String) async throws {
        guard let client = webSocketClient else {
            throw WebSocketClient.WebSocketError.notConnected
        }
        
        try await client.send(text: text)
    }
    
    /// Request project updates
    public func subscribeToProject(_ projectId: String) async throws {
        let subscription = WebSocketMessage(
            type: .subscribe,
            channel: "project",
            data: ["projectId": projectId]
        )
        try await send(subscription)
    }
    
    /// Request chat session updates
    public func subscribeToChat(_ chatId: String) async throws {
        let subscription = WebSocketMessage(
            type: .subscribe,
            channel: "chat",
            data: ["chatId": chatId]
        )
        try await send(subscription)
    }
    
    /// Request terminal output streaming
    public func subscribeToTerminal(_ sessionId: String) async throws {
        let subscription = WebSocketMessage(
            type: .subscribe,
            channel: "terminal",
            data: ["sessionId": sessionId]
        )
        try await send(subscription)
    }
    
    // MARK: - Private Methods
    
    private func setupEventHandling() {
        // Route events from handler to appropriate subjects
        eventHandler.projectUpdatePublisher
            .sink { [weak self] event in
                self?.projectUpdateSubject.send(event)
                self?.updateAppState(with: event)
            }
            .store(in: &cancellables)
        
        eventHandler.chatUpdatePublisher
            .sink { [weak self] event in
                self?.chatUpdateSubject.send(event)
                self?.updateAppState(with: event)
            }
            .store(in: &cancellables)
        
        eventHandler.fileChangePublisher
            .sink { [weak self] event in
                self?.fileChangeSubject.send(event)
            }
            .store(in: &cancellables)
        
        eventHandler.terminalOutputPublisher
            .sink { [weak self] event in
                self?.terminalOutputSubject.send(event)
            }
            .store(in: &cancellables)
        
        eventHandler.collaborationPublisher
            .sink { [weak self] event in
                self?.collaborationSubject.send(event)
            }
            .store(in: &cancellables)
        
        eventHandler.systemNotificationPublisher
            .sink { [weak self] event in
                self?.systemNotificationSubject.send(event)
                self?.showSystemNotification(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleConnectionStateChange(_ state: WebSocketClient.ConnectionState) {
        connectionState = state
        
        switch state {
        case .connected:
            isConnected = true
            lastError = nil
            reconnectAttempts = 0
            logger.info("WebSocket connected")
            
        case .disconnected:
            isConnected = false
            logger.info("WebSocket disconnected")
            
        case .connecting:
            logger.info("WebSocket connecting...")
            
        case .disconnecting:
            logger.info("WebSocket disconnecting...")
            
        case .failed(let error):
            isConnected = false
            lastError = error
            reconnectAttempts += 1
            logger.error("WebSocket failed: \(error)")
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            eventHandler.handleMessage(text)
            
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                eventHandler.handleMessage(text)
            }
            
        @unknown default:
            logger.warning("Received unknown message type")
        }
    }
    
    private func authenticate() async throws {
        let authMessage = WebSocketMessage(
            type: .authenticate,
            channel: "auth",
            data: ["token": authToken ?? ""]
        )
        try await send(authMessage)
    }
    
    private func updateAppState(with event: ProjectUpdateEvent) {
        // Update ProjectStore based on event
        Task { @MainActor in
            switch event.action {
            case .created:
                // Handle project creation
                logger.info("Project created: \(event.projectId)")
                
            case .updated:
                // Handle project update
                logger.info("Project updated: \(event.projectId)")
                
            case .deleted:
                // Handle project deletion
                logger.info("Project deleted: \(event.projectId)")
            }
        }
    }
    
    private func updateAppState(with event: ChatUpdateEvent) {
        // Update ChatStore based on event
        Task { @MainActor in
            switch event.action {
            case .messageAdded:
                logger.info("Message added to chat: \(event.chatId)")
                
            case .messageUpdated:
                logger.info("Message updated in chat: \(event.chatId)")
                
            case .streamStarted:
                logger.info("Stream started for chat: \(event.chatId)")
                
            case .streamEnded:
                logger.info("Stream ended for chat: \(event.chatId)")
            }
        }
    }
    
    private func showSystemNotification(_ event: SystemNotificationEvent) {
        // Show system notification to user
        logger.info("System notification: \(event.title) - \(event.message)")
        
        // You could integrate with iOS notifications here
        // or update a notification center in the app
    }
    
    private func observeAppLifecycle() {
        // Handle app going to background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task {
                    // Optionally disconnect when app goes to background
                    // await self?.disconnect()
                    self?.logger.info("App entered background")
                }
            }
            .store(in: &cancellables)
        
        // Handle app coming to foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task {
                    // Reconnect when app comes to foreground
                    if self?.webSocketClient == nil {
                        try? await self?.connect()
                    }
                    self?.logger.info("App will enter foreground")
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - WebSocket Message Types

struct WebSocketMessage: Codable {
    enum MessageType: String, Codable {
        case authenticate
        case subscribe
        case unsubscribe
        case message
        case ping
        case pong
    }
    
    let type: MessageType
    let channel: String
    let data: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case type
        case channel
        case data
    }
    
    init(type: MessageType, channel: String, data: [String: Any]) {
        self.type = type
        self.channel = channel
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(MessageType.self, forKey: .type)
        channel = try container.decode(String.self, forKey: .channel)
        
        // Decode data as AnyCodable to handle heterogeneous types
        if container.contains(.data) {
            let anyCodableDict = try container.decode([String: AnyCodable].self, forKey: .data)
            data = anyCodableDict.mapValues { $0.value }
        } else {
            data = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(channel, forKey: .channel)
        
        // Convert data dictionary to AnyCodable for encoding
        let anyCodableDict = data.mapValues { AnyCodable($0) }
        try container.encode(anyCodableDict, forKey: .data)
    }
}