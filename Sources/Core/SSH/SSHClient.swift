//
//  SSHClient.swift
//  ClaudeCode
//
//  Core SSH client with connection management (Tasks 451-455)
//

import Foundation
// Temporarily disabled for UI testing
// import Citadel
// import NIO
// import NIOSSH
import OSLog

/// Core SSH client for managing connections
@MainActor
public class SSHClient: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var isConnected = false
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var lastError: SSHClientError?
    
    // MARK: - Private Properties
    
    // private var client: Citadel.SSHClient?
    // private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHClient")
    private let keychain = KeychainManager.shared
    private let monitor = SSHMonitor()
    
    // Connection configuration
    private var config: SSHConfig?
    private var connectionOptions: SSHConnectionOptions?
    
    // Retry configuration
    private let maxRetries = 3
    private var currentRetryCount = 0
    private let retryDelay: TimeInterval = 2.0
    
    // MARK: - Connection State
    
    public enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case authenticating
        case connected(host: String, port: Int)
        case disconnecting
        case error(String)
    }
    
    // MARK: - Initialization
    
    public init() {
        // Stubbed for UI testing
    }
    
    deinit {
        // Stubbed for UI testing
    }
    
    // MARK: - Connection Management
    
    /// Connect to SSH server with configuration
    public func connect(with config: SSHConfig, options: SSHConnectionOptions? = nil) async throws {
        // Temporarily stubbed for UI testing
        self.config = config
        self.connectionOptions = options
        connectionState = .connected(host: config.host, port: config.port)
        isConnected = true
        logger.info("SSH connection stubbed for UI testing")
    }
    
    /// Disconnect from SSH server
    public func disconnect() async {
        // Temporarily stubbed for UI testing
        isConnected = false
        connectionState = .disconnected
        lastError = nil
        logger.info("SSH disconnection stubbed for UI testing")
    }
    
    // MARK: - Command Execution
    
    /// Execute a command on the remote server
    public func executeCommand(_ command: String, timeout: TimeInterval = 30) async throws -> CommandResult {
        // Temporarily stubbed for UI testing
        logger.info("SSH command execution stubbed for UI testing")
        return CommandResult(
            stdout: "Stubbed output",
            stderr: "",
            exitCode: 0,
            executionTime: 0.1
        )
    }
    
    // MARK: - SFTP Operations
    
    /// Open an SFTP session
    public func openSFTP() async throws -> SFTPClient {
        // Temporarily stubbed for UI testing
        throw SSHClientError.notConnected
    }
    
    // MARK: - Port Forwarding
    
    /// Create a local port forward
    public func createPortForward(
        localPort: Int,
        remoteHost: String,
        remotePort: Int,
        bindAddress: String = "127.0.0.1"
    ) async throws {
        // Temporarily stubbed for UI testing
        logger.info("Port forwarding stubbed for UI testing")
    }
    
    // MARK: - Keep-Alive
    
    private var keepAliveTimer: Timer?
    
    private func startKeepAlive(interval: TimeInterval) {
        // Stubbed for UI testing
    }
    
    private func stopKeepAlive() {
        // Stubbed for UI testing
    }
    
    private func sendKeepAlive() async {
        // Stubbed for UI testing
    }
    
    // MARK: - Credential Management
    
    private func loadPassword(for config: SSHConfig) async throws -> String? {
        // Stubbed for UI testing
        return nil
    }
    
    private func loadPrivateKey(for config: SSHConfig) async throws -> String? {
        // Stubbed for UI testing
        return nil
    }
    
    public func saveCredentials(password: String? = nil, privateKey: String? = nil) async throws {
        // Stubbed for UI testing
    }
    
    // MARK: - Monitoring Access
    
    /// Get the SSH monitor for accessing metrics
    public var sshMonitor: SSHMonitor {
        monitor
    }
    
    /// Export monitoring metrics
    public func exportMonitoringData() -> SSHMonitoringExport {
        monitor.exportMetrics()
    }
}

// MARK: - Supporting Types

/// SSH connection options
public struct SSHConnectionOptions {
    public let keepAliveInterval: TimeInterval?
    public let connectionTimeout: TimeInterval
    public let strictHostKeyChecking: Bool
    public let enableCompression: Bool
    public let autoReconnect: Bool
    public let enableAgentForwarding: Bool
    
    public init(
        keepAliveInterval: TimeInterval? = 30,
        connectionTimeout: TimeInterval = 30,
        strictHostKeyChecking: Bool = true,
        enableCompression: Bool = true,
        autoReconnect: Bool = true,
        enableAgentForwarding: Bool = false
    ) {
        self.keepAliveInterval = keepAliveInterval
        self.connectionTimeout = connectionTimeout
        self.strictHostKeyChecking = strictHostKeyChecking
        self.enableCompression = enableCompression
        self.autoReconnect = autoReconnect
        self.enableAgentForwarding = enableAgentForwarding
    }
    
    public static let `default` = SSHConnectionOptions()
}

/// Command execution result
public struct CommandResult {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int
    public let executionTime: TimeInterval
}

/// SSH client errors
public enum SSHClientError: LocalizedError {
    case notConnected
    case connectionFailed(String)
    case authenticationFailed(String)
    case commandExecutionFailed(String)
    case sftpError(String)
    case timeout
    case invalidConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to SSH server"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .commandExecutionFailed(let reason):
            return "Command execution failed: \(reason)"
        case .sftpError(let reason):
            return "SFTP error: \(reason)"
        case .timeout:
            return "Operation timed out"
        case .invalidConfiguration:
            return "Invalid SSH configuration"
        }
    }
    
    static func from(_ error: Error) -> SSHClientError {
        if let sshError = error as? SSHClientError {
            return sshError
        }
        return .connectionFailed(error.localizedDescription)
    }
}

// Stubbed types for UI testing
public struct SFTPClient {}