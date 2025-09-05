//
//  SSHManager.swift
//  ClaudeCode
//
//  SSH connection management service
//

import Foundation
import Combine

/// SSH Manager for managing SSH connections
@MainActor
public class SSHManager: ObservableObject {
    public static let shared = SSHManager()
    
    @Published public var activeConnections: [String: SSHClient] = [:]
    @Published public var connectionStates: [String: ConnectionState] = [:]
    
    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    private init() {}
    
    /// Connect to SSH server
    public func connect(with config: SSHConfig) async throws -> SSHClient {
        let client = SSHClient()
        // Stub implementation - would normally establish SSH connection
        return client
    }
    
    /// Disconnect from SSH server
    public func disconnect(_ sessionId: String) async {
        activeConnections.removeValue(forKey: sessionId)
        connectionStates[sessionId] = .disconnected
    }
    
    /// Get connection state
    public func connectionState(for sessionId: String) -> ConnectionState {
        connectionStates[sessionId] ?? .disconnected
    }
}

// SSHConnectionOptions is defined in SSHClient.swift

/// Terminal size
public struct TerminalSize {
    public var columns: Int
    public var rows: Int
    
    public init(columns: Int = 80, rows: Int = 24) {
        self.columns = columns
        self.rows = rows
    }
}

/// Terminal output event for WebSocket integration
public struct TerminalOutputEvent {
    public let sessionId: String
    public let content: String
    public let outputType: OutputType
    public let timestamp: Date
    
    public enum OutputType {
        case stdout
        case stderr
        case command
    }
    
    public init(sessionId: String, content: String, outputType: OutputType, timestamp: Date = Date()) {
        self.sessionId = sessionId
        self.content = content
        self.outputType = outputType
        self.timestamp = timestamp
    }
}

/// WebSocket service stub
public class WebSocketService {
    public static let shared = WebSocketService()
    
    public let terminalOutput = PassthroughSubject<TerminalOutputEvent, Never>()
    
    private init() {}
    
    public func subscribeToTerminal(_ sessionId: String) async throws {
        // Stub implementation
    }
    
    public func unsubscribeFromTerminal(_ sessionId: String) async {
        // Stub implementation
    }
}