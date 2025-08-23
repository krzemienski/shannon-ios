//
//  SSHSession.swift
//  ClaudeCode
//
//  SSH session state and lifecycle management (Tasks 456-460)
//

import Foundation
import Citadel
import OSLog

/// SSH session manager for handling session lifecycle and state
@MainActor
public class SSHSession: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var sessionState: SessionState = .idle
    @Published public private(set) var sessionInfo: SSHSessionInfo?
    @Published public private(set) var statistics: SessionStatistics
    @Published public private(set) var commandHistory: [ExecutedCommand] = []
    
    // MARK: - Private Properties
    
    private let id: String
    private let client: SSHClient
    private let config: ClaudeCode.SSHConfig
    private var createdAt: Date
    private var lastActivity: Date
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHSession")
    
    // Session monitoring
    private var activityTimer: Timer?
    private let idleTimeout: TimeInterval = 300 // 5 minutes
    
    // MARK: - Session State
    
    public enum SessionState: Equatable {
        case idle
        case active
        case executing(command: String)
        case transferring(operation: String)
        case suspended
        case terminated
        case error(String)
    }
    
    // MARK: - Initialization
    
    public init(client: SSHClient, config: ClaudeCode.SSHConfig) {
        self.id = UUID().uuidString
        self.client = client
        self.config = config
        self.createdAt = Date()
        self.lastActivity = Date()
        self.statistics = SessionStatistics()
        
        // Initialize session info
        self.sessionInfo = SSHSessionInfo(
            id: id,
            configId: config.id,
            status: .connecting,
            connectedAt: nil,
            lastActivity: nil,
            remoteAddress: "\(config.host):\(config.port)",
            localPort: nil,
            statistics: nil
        )
        
        startActivityMonitoring()
    }
    
    deinit {
        // stopActivityMonitoring() is called in disconnect
    }
    
    // MARK: - Session Lifecycle
    
    /// Start the session
    public func start() async throws {
        sessionState = .active
        updateActivity()
        
        // Update session info
        sessionInfo = SSHSessionInfo(
            id: id,
            configId: config.id,
            status: .connected,
            connectedAt: Date(),
            lastActivity: Date(),
            remoteAddress: "\(config.host):\(config.port)",
            localPort: nil,
            statistics: statistics.toSSHSessionStats()
        )
        
        logger.info("Session \(id) started for \(config.host)")
    }
    
    /// Suspend the session
    public func suspend() {
        guard sessionState != .terminated else { return }
        
        sessionState = .suspended
        logger.info("Session \(id) suspended")
    }
    
    /// Resume the session
    public func resume() {
        guard sessionState == .suspended else { return }
        
        sessionState = .active
        updateActivity()
        logger.info("Session \(id) resumed")
    }
    
    /// Terminate the session
    public func terminate() async {
        sessionState = .terminated
        stopActivityMonitoring()
        
        // Disconnect client if needed
        await client.disconnect()
        
        logger.info("Session \(id) terminated")
    }
    
    // MARK: - Command Execution
    
    /// Execute a command in this session
    public func executeCommand(
        _ command: String,
        timeout: TimeInterval = 30,
        environment: [String: String]? = nil
    ) async throws -> CommandResult {
        guard sessionState == .active || sessionState == .idle else {
            throw SSHSessionError.invalidState("Session is not active")
        }
        
        sessionState = .executing(command: command)
        updateActivity()
        
        let startTime = Date()
        
        do {
            // Execute command through client
            let result = try await client.executeCommand(command, timeout: timeout)
            
            // Update statistics
            statistics.commandsExecuted += 1
            statistics.totalExecutionTime += result.executionTime
            
            // Add to history
            let executedCommand = ExecutedCommand(
                id: UUID().uuidString,
                command: command,
                timestamp: startTime,
                result: result,
                environment: environment
            )
            commandHistory.append(executedCommand)
            
            // Limit history size
            if commandHistory.count > 100 {
                commandHistory.removeFirst()
            }
            
            sessionState = .active
            updateSessionInfo()
            
            return result
            
        } catch {
            sessionState = .error(error.localizedDescription)
            statistics.errors += 1
            throw error
        }
    }
    
    /// Execute multiple commands in batch
    public func batchExecute(
        _ commands: [String],
        stopOnError: Bool = true
    ) async -> BatchExecutionResult {
        var results: [CommandResult] = []
        var errors: [Error] = []
        
        for command in commands {
            do {
                let result = try await executeCommand(command)
                results.append(result)
                
                if stopOnError && result.exitCode != 0 {
                    break
                }
            } catch {
                errors.append(error)
                if stopOnError {
                    break
                }
            }
        }
        
        return BatchExecutionResult(
            results: results,
            errors: errors,
            totalCommands: commands.count,
            successCount: results.filter { $0.exitCode == 0 }.count
        )
    }
    
    // MARK: - File Transfer
    
    /// Upload a file through this session
    public func uploadFile(
        localPath: String,
        remotePath: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        guard sessionState == .active || sessionState == .idle else {
            throw SSHSessionError.invalidState("Session is not active")
        }
        
        sessionState = .transferring(operation: "Uploading \(localPath)")
        updateActivity()
        
        do {
            let sftp = try await client.openSFTP()
            
            // Read local file
            let fileURL = URL(fileURLWithPath: localPath)
            let fileData = try Data(contentsOf: fileURL)
            
            // Track transfer
            let startTime = Date()
            statistics.bytesUploaded += Int64(fileData.count)
            
            // Upload file (simplified - actual implementation would chunk)
            // TODO: Implement chunked upload with progress
            
            let transferTime = Date().timeIntervalSince(startTime)
            statistics.totalTransferTime += transferTime
            
            sessionState = .active
            updateSessionInfo()
            
        } catch {
            sessionState = .error(error.localizedDescription)
            statistics.errors += 1
            throw error
        }
    }
    
    /// Download a file through this session
    public func downloadFile(
        remotePath: String,
        localPath: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        guard sessionState == .active || sessionState == .idle else {
            throw SSHSessionError.invalidState("Session is not active")
        }
        
        sessionState = .transferring(operation: "Downloading \(remotePath)")
        updateActivity()
        
        do {
            let sftp = try await client.openSFTP()
            
            // TODO: Implement file download with progress
            
            sessionState = .active
            updateSessionInfo()
            
        } catch {
            sessionState = .error(error.localizedDescription)
            statistics.errors += 1
            throw error
        }
    }
    
    // MARK: - Activity Monitoring
    
    private func startActivityMonitoring() {
        activityTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                self.checkIdleTimeout()
            }
        }
    }
    
    private func stopActivityMonitoring() {
        activityTimer?.invalidate()
        activityTimer = nil
    }
    
    private func updateActivity() {
        lastActivity = Date()
        
        // Reset to active if was idle
        if sessionState == .idle {
            sessionState = .active
        }
    }
    
    private func checkIdleTimeout() {
        let idleTime = Date().timeIntervalSince(lastActivity)
        
        if idleTime > idleTimeout && sessionState == .active {
            sessionState = .idle
            logger.info("Session \(id) became idle after \(idleTime)s")
        }
    }
    
    private func updateSessionInfo() {
        sessionInfo = SSHSessionInfo(
            id: id,
            configId: config.id,
            status: mapSessionStateToStatus(sessionState),
            connectedAt: createdAt,
            lastActivity: lastActivity,
            remoteAddress: "\(config.host):\(config.port)",
            localPort: nil,
            statistics: statistics.toSSHSessionStats()
        )
    }
    
    private func mapSessionStateToStatus(_ state: SessionState) -> SSHSessionStatus {
        switch state {
        case .idle:
            return .idle
        case .active, .executing, .transferring:
            return .connected
        case .suspended:
            return .disconnected
        case .terminated:
            return .disconnected
        case .error:
            return .error
        }
    }
    
    // MARK: - Statistics
    
    /// Get current session statistics
    public func getStatistics() -> SessionStatistics {
        statistics.uptime = Date().timeIntervalSince(createdAt)
        return statistics
    }
    
    /// Clear command history
    public func clearHistory() {
        commandHistory.removeAll()
    }
}

// MARK: - Supporting Types

/// Session statistics
public struct SessionStatistics {
    public var commandsExecuted: Int = 0
    public var errors: Int = 0
    public var bytesUploaded: Int64 = 0
    public var bytesDownloaded: Int64 = 0
    public var totalExecutionTime: TimeInterval = 0
    public var totalTransferTime: TimeInterval = 0
    public var uptime: TimeInterval = 0
    
    public var averageExecutionTime: TimeInterval {
        commandsExecuted > 0 ? totalExecutionTime / Double(commandsExecuted) : 0
    }
    
    public var successRate: Double {
        let total = commandsExecuted + errors
        return total > 0 ? Double(commandsExecuted) / Double(total) : 1.0
    }
    
    func toSSHSessionStats() -> SSHSessionStats {
        SSHSessionStats(
            bytesSent: bytesUploaded,
            bytesReceived: bytesDownloaded,
            commandsExecuted: commandsExecuted,
            errors: errors,
            uptime: uptime
        )
    }
}

/// Executed command record
public struct ExecutedCommand: Identifiable {
    public let id: String
    public let command: String
    public let timestamp: Date
    public let result: CommandResult
    public let environment: [String: String]?
}

/// Batch execution result
public struct BatchExecutionResult {
    public let results: [CommandResult]
    public let errors: [Error]
    public let totalCommands: Int
    public let successCount: Int
    
    public var successRate: Double {
        totalCommands > 0 ? Double(successCount) / Double(totalCommands) : 0
    }
}

/// SSH session errors
public enum SSHSessionError: LocalizedError {
    case invalidState(String)
    case executionFailed(String)
    case transferFailed(String)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .invalidState(let reason):
            return "Invalid session state: \(reason)"
        case .executionFailed(let reason):
            return "Command execution failed: \(reason)"
        case .transferFailed(let reason):
            return "File transfer failed: \(reason)"
        case .timeout:
            return "Operation timed out"
        }
    }
}