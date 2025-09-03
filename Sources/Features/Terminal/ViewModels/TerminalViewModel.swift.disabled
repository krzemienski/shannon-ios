//
//  TerminalViewModel.swift
//  ClaudeCode
//
//  Terminal business logic and session management (Tasks 621-625)
//

import Foundation
import SwiftUI
import Combine
import OSLog

/// Terminal view model for managing terminal sessions
@MainActor
public class TerminalViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var sessions: [TerminalSession] = []
    @Published public private(set) var activeSessionId: String?
    @Published public var settings: TerminalSettings
    @Published public private(set) var isConnecting = false
    @Published public private(set) var lastError: Error?
    
    // MARK: - Private Properties
    
    private let sshManager: SSHManager
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "TerminalViewModel")
    private var cancellables = Set<AnyCancellable>()
    private let maxSessions = 10
    private let webSocketService = WebSocketService.shared
    
    // Session management
    private var sessionConnections: [String: SSHClient] = [:]
    private var sessionStreams: [String: AnyCancellable] = [:]
    
    // MARK: - Initialization
    
    public init(projectId: String? = nil, sshConfig: SSHConfig? = nil) {
        self.sshManager = SSHManager.shared
        self.settings = TerminalSettings.load()
        
        setupBindings()
        
        // Create initial session if config provided
        if let config = sshConfig {
            Task {
                await createSession(with: config)
            }
        }
    }
    
    deinit {
        // Close all sessions
        for session in sessions {
            closeSession(session.id)
        }
    }
    
    // MARK: - Public Methods
    
    /// Create a new terminal session
    public func createSession(with config: SSHConfig) async -> String? {
        guard sessions.count < maxSessions else {
            lastError = TerminalError.maxSessionsReached
            return nil
        }
        
        let session = TerminalSession(
            name: config.name,
            config: config,
            terminal: SSHTerminal()
        )
        
        sessions.append(session)
        
        // Connect if auto-connect is enabled
        if settings.autoConnect {
            await connect(sessionId: session.id)
        }
        
        return session.id
    }
    
    /// Connect a session
    public func connect(sessionId: String) async {
        guard let session = session(with: sessionId),
              let config = session.config else { return }
        
        isConnecting = true
        updateSessionStatus(sessionId, status: .connecting)
        
        do {
            // Create SSH client
            let client = SSHClient()
            
            // Connect to server
            let connectionOptions = SSHConnectionOptions(
                keepAliveInterval: settings.keepAliveInterval,
                connectionTimeout: settings.connectionTimeout,
                strictHostKeyChecking: settings.strictHostKeyChecking,
                enableCompression: settings.enableCompression,
                autoReconnect: settings.autoReconnect
            )
            
            try await client.connect(with: config, options: connectionOptions)
            
            // Store connection
            sessionConnections[sessionId] = client
            
            // Setup terminal session
            await setupTerminalSession(sessionId: sessionId, client: client)
            
            updateSessionStatus(sessionId, status: .connected)
            
            // Add to recent connections
            addToRecentConnections(config)
            
            logger.info("Connected session \(sessionId) to \(config.host)")
            
        } catch {
            logger.error("Failed to connect session \(sessionId): \(error)")
            lastError = error
            updateSessionStatus(sessionId, status: .error(error.localizedDescription))
        }
        
        isConnecting = false
    }
    
    /// Disconnect a session
    public func disconnect(sessionId: String) {
        guard let client = sessionConnections[sessionId] else { return }
        
        updateSessionStatus(sessionId, status: .disconnecting)
        
        Task {
            await client.disconnect()
            sessionConnections.removeValue(forKey: sessionId)
            sessionStreams[sessionId]?.cancel()
            sessionStreams.removeValue(forKey: sessionId)
            
            updateSessionStatus(sessionId, status: .disconnected)
            
            logger.info("Disconnected session \(sessionId)")
        }
    }
    
    /// Reconnect a session
    public func reconnect(sessionId: String) async {
        disconnect(sessionId)
        await connect(sessionId: sessionId)
    }
    
    /// Close and remove a session
    public func closeSession(_ sessionId: String) {
        disconnect(sessionId)
        sessions.removeAll { $0.id == sessionId }
        
        if activeSessionId == sessionId {
            activeSessionId = sessions.first?.id
        }
    }
    
    /// Send command to a session
    public func sendCommand(to sessionId: String, command: String) {
        guard let session = session(with: sessionId),
              let client = sessionConnections[sessionId] else { return }
        
        // Add to command history
        session.commandHistory.add(command)
        
        // Send to terminal
        session.terminal.processInput(command + "\n")
        
        // Execute on remote
        Task {
            do {
                let result = try await client.executeCommand(command)
                
                // Process output
                session.terminal.processOutput(result.stdout.data(using: .utf8) ?? Data())
                
                if !result.stderr.isEmpty {
                    session.terminal.processOutput(result.stderr.data(using: .utf8) ?? Data())
                }
                
            } catch {
                logger.error("Command execution failed: \(error)")
                let errorMessage = "Error: \(error.localizedDescription)\n"
                session.terminal.processOutput(errorMessage.data(using: .utf8) ?? Data())
            }
        }
    }
    
    /// Resize terminal
    public func resizeTerminal(sessionId: String, size: TerminalSize) {
        guard let session = session(with: sessionId) else { return }
        
        session.terminal.resize(columns: size.columns, rows: size.rows)
        
        // TODO: Send resize command to remote PTY
    }
    
    /// Get session by ID
    public func session(with id: String) -> TerminalSession? {
        sessions.first { $0.id == id }
    }
    
    /// Clear terminal output
    public func clearTerminal(sessionId: String) {
        guard let session = session(with: sessionId) else { return }
        session.terminal.clearScreen()
    }
    
    /// Export terminal session
    public func exportSession(_ sessionId: String) -> String {
        guard let session = session(with: sessionId) else { return "" }
        
        var output = "Terminal Session Export\n"
        output += "Session: \(session.name)\n"
        if let config = session.config {
            output += "Host: \(config.host):\(config.port)\n"
            output += "User: \(config.username)\n"
        }
        output += "Date: \(Date().formatted())\n"
        output += String(repeating: "-", count: 50) + "\n\n"
        
        // Export terminal buffer
        for line in session.terminal.getVisibleLines() {
            output += line.text + "\n"
        }
        
        return output
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Auto-save settings on change
        settings.$autoConnect
            .sink { [weak self] _ in
                self?.settings.save()
            }
            .store(in: &cancellables)
        
        // Subscribe to WebSocket terminal output events
        webSocketService.terminalOutput
            .sink { [weak self] event in
                self?.handleWebSocketTerminalOutput(event)
            }
            .store(in: &cancellables)
    }
    
    private func setupTerminalSession(sessionId: String, client: SSHClient) async {
        guard let session = session(with: sessionId) else { return }
        
        // Connect terminal input to SSH client
        let cancellable = session.terminal.inputStream
            .sink { [weak self] input in
                Task {
                    guard let self = self else { return }
                    do {
                        _ = try await client.executeCommand(input)
                    } catch {
                        self.logger.error("Failed to send input: \(error)")
                    }
                }
            }
        
        sessionStreams[sessionId] = cancellable
        
        // Start terminal session
        session.terminal.connect()
    }
    
    private func updateSessionStatus(_ sessionId: String, status: TerminalSessionStatus) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        
        sessions[index].status = status
        
        if case .error(let message) = status {
            sessions[index].lastError = message
        }
    }
    
    private func addToRecentConnections(_ config: SSHConfig) {
        var recent = settings.recentConnections
        
        // Remove if already exists
        recent.removeAll { $0.id == config.id }
        
        // Add to front
        recent.insert(config, at: 0)
        
        // Limit to 10 recent connections
        if recent.count > 10 {
            recent = Array(recent.prefix(10))
        }
        
        settings.recentConnections = recent
        settings.save()
    }
}

// MARK: - Terminal Session

/// Terminal session model
public class TerminalSession: ObservableObject, Identifiable {
    public let id = UUID().uuidString
    @Published public var name: String
    @Published public var config: SSHConfig?
    @Published public var status: TerminalSessionStatus = .disconnected
    @Published public var terminal: SSHTerminal
    @Published public var commandHistory: CommandHistory
    @Published public var lastError: String?
    @Published public var hasUnreadOutput = false
    
    public init(
        name: String,
        config: SSHConfig? = nil,
        terminal: SSHTerminal = SSHTerminal(),
        commandHistory: CommandHistory = CommandHistory()
    ) {
        self.name = name
        self.config = config
        self.terminal = terminal
        self.commandHistory = commandHistory
    }
}

/// Terminal session status
public enum TerminalSessionStatus: Equatable {
    case connecting
    case connected
    case disconnecting
    case disconnected
    case error(String)
}

// MARK: - Terminal Settings

/// Terminal settings
public struct TerminalSettings: Codable {
    public var fontSize: Double = 13
    public var fontFamily: String = "SF Mono"
    public var cursorBlink: Bool = true
    public var cursorStyle: CursorStyle = .block
    public var scrollbackLines: Int = 10000
    public var bellStyle: BellStyle = .visual
    public var enableColors: Bool = true
    public var colorScheme: ColorScheme = .default
    
    // Connection settings
    public var autoConnect: Bool = true
    public var autoReconnect: Bool = true
    public var keepAliveInterval: TimeInterval = 30
    public var connectionTimeout: TimeInterval = 10
    public var strictHostKeyChecking: Bool = false
    public var enableCompression: Bool = true
    
    // Display settings
    public var showTimestamps: Bool = false
    public var wrapLines: Bool = true
    public var showScrollbar: Bool = true
    public var enableLigatures: Bool = false
    
    // Recent connections
    public var recentConnections: [SSHConfig] = []
    
    public enum CursorStyle: String, Codable, CaseIterable {
        case block = "block"
        case underline = "underline"
        case bar = "bar"
    }
    
    public enum BellStyle: String, Codable, CaseIterable {
        case none = "none"
        case visual = "visual"
        case sound = "sound"
        case both = "both"
    }
    
    public enum ColorScheme: String, Codable, CaseIterable {
        case `default` = "default"
        case solarizedDark = "solarized-dark"
        case solarizedLight = "solarized-light"
        case monokai = "monokai"
        case dracula = "dracula"
        case nord = "nord"
        case gruvbox = "gruvbox"
        case oneDark = "one-dark"
    }
    
    private static let storageKey = "terminal_settings"
    
    public static func load() -> TerminalSettings {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let settings = try? JSONDecoder().decode(TerminalSettings.self, from: data) {
            return settings
        }
        return TerminalSettings()
    }
    
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Terminal Errors

/// Terminal errors
public enum TerminalError: LocalizedError {
    case maxSessionsReached
    case sessionNotFound
    case connectionFailed(String)
    case commandFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .maxSessionsReached:
            return "Maximum number of terminal sessions reached"
        case .sessionNotFound:
            return "Terminal session not found"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .commandFailed(let reason):
            return "Command failed: \(reason)"
        }
    }
}

// MARK: - Preview Helpers

extension TerminalViewModel {
    static var preview: TerminalViewModel {
        let vm = TerminalViewModel()
        
        // Add sample sessions
        let config1 = SSHConfig(
            name: "Development Server",
            host: "dev.example.com",
            port: 22,
            username: "developer",
            authMethod: .password
        )
        
        let session1 = TerminalSession(name: "Dev Server", config: config1)
        session1.status = .connected
        vm.sessions.append(session1)
        
        let config2 = SSHConfig(
            name: "Production Server",
            host: "prod.example.com",
            port: 22,
            username: "admin",
            authMethod: .publicKey
        )
        
        let session2 = TerminalSession(name: "Prod Server", config: config2)
        session2.status = .disconnected
        vm.sessions.append(session2)
        
        return vm
    }
    
    // MARK: - WebSocket Integration
    
    private func handleWebSocketTerminalOutput(_ event: TerminalOutputEvent) {
        guard let session = session(with: event.sessionId) else {
            logger.warning("Received terminal output for unknown session: \(event.sessionId)")
            return
        }
        
        // Process output through the terminal
        let content: String
        switch event.outputType {
        case .stdout:
            content = event.content
            
        case .stderr:
            // Could apply different formatting for stderr
            content = "\u{001b}[31m\(event.content)\u{001b}[0m" // Red color for errors
            
        case .command:
            // Handle command echo or history
            content = "> \(event.content)\n"
        }
        
        // Convert to data and process through terminal
        if let data = content.data(using: .utf8) {
            session.terminal.processOutput(data)
        }
    }
    
    /// Subscribe to WebSocket terminal output for a session
    public func subscribeToTerminalOutput(sessionId: String) async {
        guard session(with: sessionId) != nil else { return }
        
        do {
            try await webSocketService.subscribeToTerminal(sessionId)
            logger.info("Subscribed to terminal output for session: \(sessionId)")
        } catch {
            logger.error("Failed to subscribe to terminal output: \(error)")
        }
    }
}