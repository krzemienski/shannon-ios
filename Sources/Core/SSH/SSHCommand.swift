//
//  SSHCommand.swift
//  ClaudeCode
//
//  Command execution with streaming output (Tasks 466-468)
//

import Foundation
// Temporarily disabled for UI testing
// import Citadel
// import NIO
import Combine
import OSLog

/// SSH command executor with streaming output support
@MainActor
public class SSHCommand: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var isExecuting = false
    @Published public private(set) var output = CommandOutput()
    @Published public private(set) var progress: CommandProgress?
    
    // MARK: - Private Properties
    
    private let client: SSHClient
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHCommand")
    private var cancellables = Set<AnyCancellable>()
    private var currentTask: Task<Void, Error>?
    private let monitor = SSHMonitoringCoordinator.shared
    
    // Stream handlers
    private var outputHandler: ((String) -> Void)?
    private var errorHandler: ((String) -> Void)?
    private var progressHandler: ((CommandProgress) -> Void)?
    
    // Session tracking
    private var sessionId: String?
    private var hostInfo: (host: String, port: Int)?
    
    // MARK: - Initialization
    
    public init(client: SSHClient, sessionId: String? = nil, host: String? = nil, port: Int? = nil) {
        self.client = client
        self.sessionId = sessionId
        if let host = host, let port = port {
            self.hostInfo = (host, port)
        }
    }
    
    // MARK: - Command Execution
    
    /// Execute a command with streaming output
    public func execute(
        _ command: String,
        environment: [String: String]? = nil,
        workingDirectory: String? = nil,
        timeout: TimeInterval = 30,
        outputHandler: ((String) -> Void)? = nil,
        errorHandler: ((String) -> Void)? = nil,
        progressHandler: ((CommandProgress) -> Void)? = nil
    ) async throws -> CommandResult {
        
        guard !isExecuting else {
            throw SSHCommandError.alreadyExecuting
        }
        
        self.outputHandler = outputHandler
        self.errorHandler = errorHandler
        self.progressHandler = progressHandler
        
        isExecuting = true
        output = CommandOutput()
        progress = CommandProgress(command: command)
        
        defer {
            isExecuting = false
            currentTask = nil
        }
        
        logger.info("Executing command: \(command)")
        
        // Build command with environment and working directory
        let fullCommand = buildFullCommand(
            command,
            environment: environment,
            workingDirectory: workingDirectory
        )
        
        // Start monitoring
        let host = hostInfo?.host ?? "unknown"
        let port = hostInfo?.port ?? 22
        let operationId = monitor.startOperation(
            type: .command,
            host: host,
            port: port,
            sessionId: sessionId,
            metadata: ["command": command, "timeout": "\(timeout)"]
        )
        
        // Track command in session monitor if available
        if let sessionId = sessionId {
            monitor.trackCommand(command, host: host, port: port, sessionId: sessionId)
        }
        
        let startTime = Date()
        progress?.startTime = startTime
        
        do {
            // Execute command with streaming
            let result = try await executeWithStreaming(
                fullCommand,
                timeout: timeout
            )
            
            let executionTime = Date().timeIntervalSince(startTime)
            progress?.endTime = Date()
            progress?.executionTime = executionTime
            progress?.exitCode = result.exitCode
            
            // Update final output
            output.stdout = result.stdout
            output.stderr = result.stderr
            output.exitCode = result.exitCode
            output.isComplete = true
            
            // Complete monitoring with success
            let outputLength = Int64(result.stdout.count + result.stderr.count)
            monitor.completeOperation(
                operationId,
                success: result.exitCode == 0,
                sessionId: sessionId,
                bytesTransferred: outputLength,
                output: String(result.stdout.prefix(1000)), // First 1000 chars for monitoring
                error: result.exitCode != 0 ? "Exit code: \(result.exitCode)" : nil
            )
            
            logger.info("Command completed with exit code: \(result.exitCode)")
            
            return result
            
        } catch {
            progress?.error = error.localizedDescription
            output.error = error.localizedDescription
            output.isComplete = true
            
            // Complete monitoring with failure
            monitor.completeOperation(
                operationId,
                success: false,
                sessionId: sessionId,
                error: error.localizedDescription
            )
            
            logger.error("Command execution failed: \(error)")
            throw error
        }
    }
    
    /// Execute command with real-time streaming
    private func executeWithStreaming(
        _ command: String,
        timeout: TimeInterval
    ) async throws -> CommandResult {
        
        // Create a task with timeout
        let task = Task<CommandResult, Error> {
            try await withThrowingTaskGroup(of: CommandResult.self) { group in
                // Add timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw SSHCommandError.timeout(timeout)
                }
                
                // Add execution task
                group.addTask { [weak self] in
                    guard let self = self else {
                        throw SSHCommandError.clientNotAvailable
                    }
                    
                    // Execute through client
                    let result = try await self.client.executeCommand(command, timeout: timeout)
                    
                    // Stream output in chunks
                    await self.streamOutput(result.stdout, isError: false)
                    await self.streamOutput(result.stderr, isError: true)
                    
                    return result
                }
                
                // Return first completed (either result or timeout)
                for try await result in group {
                    group.cancelAll()
                    return result
                }
                
                throw SSHCommandError.executionFailed("No result received")
            }
        }
        
        currentTask = task
        return try await task.value
    }
    
    /// Stream output in chunks
    private func streamOutput(_ text: String, isError: Bool) async {
        guard !text.isEmpty else { return }
        
        // Split into lines for streaming
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            if !line.isEmpty {
                if isError {
                    output.appendStderr(line + "\n")
                    errorHandler?(line)
                } else {
                    output.appendStdout(line + "\n")
                    outputHandler?(line)
                }
                
                // Update progress
                progress?.linesProcessed += 1
                if let progress = progress {
                    progressHandler?(progress)
                }
                
                // Small delay to simulate streaming
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }
    
    /// Build full command with environment and working directory
    private func buildFullCommand(
        _ command: String,
        environment: [String: String]?,
        workingDirectory: String?
    ) -> String {
        var parts: [String] = []
        
        // Add environment variables
        if let environment = environment {
            for (key, value) in environment {
                parts.append("export \(key)=\"\(value)\"")
            }
        }
        
        // Add working directory change
        if let workingDirectory = workingDirectory {
            parts.append("cd \"\(workingDirectory)\"")
        }
        
        // Add the actual command
        parts.append(command)
        
        // Join with && to ensure each part succeeds
        return parts.joined(separator: " && ")
    }
    
    // MARK: - Advanced Execution
    
    /// Execute command with input stream
    public func executeWithInput(
        _ command: String,
        input: String,
        timeout: TimeInterval = 30
    ) async throws -> CommandResult {
        
        // Use echo to pipe input to command
        let fullCommand = "echo '\(input.replacingOccurrences(of: "'", with: "'\\''"))' | \(command)"
        
        return try await execute(
            fullCommand,
            timeout: timeout
        )
    }
    
    /// Execute interactive command with expect-style automation
    public func executeInteractive(
        _ command: String,
        interactions: [CommandInteraction],
        timeout: TimeInterval = 60
    ) async throws -> CommandResult {
        
        guard !isExecuting else {
            throw SSHCommandError.alreadyExecuting
        }
        
        isExecuting = true
        output = CommandOutput()
        
        defer {
            isExecuting = false
        }
        
        logger.info("Executing interactive command: \(command)")
        
        // Build expect script for interactions
        let expectScript = buildExpectScript(command, interactions: interactions)
        
        // Execute expect script
        return try await execute(
            "expect -c '\(expectScript)'",
            timeout: timeout
        )
    }
    
    /// Build expect script for interactive commands
    private func buildExpectScript(
        _ command: String,
        interactions: [CommandInteraction]
    ) -> String {
        var script = "spawn \(command)\n"
        
        for interaction in interactions {
            if let expect = interaction.expect {
                script += "expect \"\(expect)\"\n"
            }
            if let send = interaction.send {
                script += "send \"\(send)\\r\"\n"
            }
            if interaction.waitForExit {
                script += "expect eof\n"
            }
        }
        
        script += "wait\n"
        return script
    }
    
    // MARK: - Batch Execution
    
    /// Execute multiple commands in sequence
    public func executeBatch(
        _ commands: [String],
        stopOnError: Bool = true,
        progressHandler: ((BatchProgress) -> Void)? = nil
    ) async -> BatchExecutionResult {
        
        var results: [CommandResult] = []
        var errors: [Error] = []
        let batchProgress = BatchProgress(totalCommands: commands.count)
        
        for (index, command) in commands.enumerated() {
            batchProgress.currentCommand = index + 1
            batchProgress.currentCommandText = command
            progressHandler?(batchProgress)
            
            do {
                let result = try await execute(command)
                results.append(result)
                batchProgress.successCount += 1
                
                if stopOnError && result.exitCode != 0 {
                    batchProgress.stoppedOnError = true
                    break
                }
            } catch {
                errors.append(error)
                batchProgress.errorCount += 1
                
                if stopOnError {
                    batchProgress.stoppedOnError = true
                    break
                }
            }
            
            progressHandler?(batchProgress)
        }
        
        return BatchExecutionResult(
            results: results,
            errors: errors,
            totalCommands: commands.count,
            successCount: results.filter { $0.exitCode == 0 }.count
        )
    }
    
    // MARK: - Command Pipeline
    
    /// Execute commands in a pipeline (command1 | command2 | command3)
    public func executePipeline(
        _ commands: [String],
        timeout: TimeInterval = 30
    ) async throws -> CommandResult {
        
        let pipelineCommand = commands.joined(separator: " | ")
        return try await execute(pipelineCommand, timeout: timeout)
    }
    
    /// Execute command and process output with a filter
    public func executeWithFilter(
        _ command: String,
        filter: String,
        timeout: TimeInterval = 30
    ) async throws -> CommandResult {
        
        return try await executePipeline([command, filter], timeout: timeout)
    }
    
    // MARK: - Cancellation
    
    /// Cancel current execution
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isExecuting = false
        output.isComplete = true
        progress?.wasCancelled = true
        
        logger.info("Command execution cancelled")
    }
}

// MARK: - Supporting Types

/// Command output container
public class CommandOutput: ObservableObject {
    @Published public var stdout = ""
    @Published public var stderr = ""
    @Published public var exitCode: Int?
    @Published public var error: String?
    @Published public var isComplete = false
    
    public func appendStdout(_ text: String) {
        stdout.append(text)
    }
    
    public func appendStderr(_ text: String) {
        stderr.append(text)
    }
}

/// Command execution progress
public struct CommandProgress {
    public let command: String
    public var startTime: Date?
    public var endTime: Date?
    public var executionTime: TimeInterval?
    public var linesProcessed: Int = 0
    public var exitCode: Int?
    public var error: String?
    public var wasCancelled: Bool = false
    
    public var isComplete: Bool {
        endTime != nil || wasCancelled
    }
}

/// Command interaction for expect-style automation
public struct CommandInteraction {
    public let expect: String?
    public let send: String?
    public let waitForExit: Bool
    
    public init(
        expect: String? = nil,
        send: String? = nil,
        waitForExit: Bool = false
    ) {
        self.expect = expect
        self.send = send
        self.waitForExit = waitForExit
    }
}

/// Batch execution progress
public class BatchProgress {
    public let totalCommands: Int
    public var currentCommand: Int = 0
    public var currentCommandText: String = ""
    public var successCount: Int = 0
    public var errorCount: Int = 0
    public var stoppedOnError: Bool = false
    
    public init(totalCommands: Int) {
        self.totalCommands = totalCommands
    }
    
    public var progress: Double {
        totalCommands > 0 ? Double(currentCommand) / Double(totalCommands) : 0
    }
    
    public var isComplete: Bool {
        currentCommand >= totalCommands || stoppedOnError
    }
}

/// SSH command errors
public enum SSHCommandError: LocalizedError {
    case alreadyExecuting
    case clientNotAvailable
    case timeout(TimeInterval)
    case executionFailed(String)
    case invalidCommand
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .alreadyExecuting:
            return "A command is already executing"
        case .clientNotAvailable:
            return "SSH client is not available"
        case .timeout(let duration):
            return "Command timed out after \(Int(duration)) seconds"
        case .executionFailed(let reason):
            return "Command execution failed: \(reason)"
        case .invalidCommand:
            return "Invalid command"
        case .cancelled:
            return "Command was cancelled"
        }
    }
}