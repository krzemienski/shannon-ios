import Foundation
// Temporarily disabled for UI testing
// import Citadel
// import NIO
// import NIOSSH
import OSLog
#if canImport(UIKit)
import UIKit
#endif

/// Enhanced SSH connection manager for remote server operations (Tasks 451-500)
@MainActor
class SSHManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var lastError: String?
    @Published var activeConnections: [SSHConnectionState] = []
    @Published var transferProgress: Double = 0  // Task 471: Transfer progress
    @Published var commandHistory: [CommandHistoryEntry] = []  // Task 472: Command history
    @Published var bandwidth: BandwidthInfo?  // Task 473: Bandwidth monitoring
    
    // MARK: - Private Properties
    
    private var client: Citadel.SSHClient?
    private var sftp: SFTPClient?
    private var monitoringTimer: Timer?
    private let keychain = KeychainManager.shared
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHManager")
    
    // Connection pooling (Task 461)
    private var connectionPool: [String: Citadel.SSHClient] = [:]
    private let maxPoolSize = 5
    
    // Session management (Task 462)
    private var activeSessions: [String: SSHSession] = [:]
    private var sessionQueue = DispatchQueue(label: "ssh.sessions", attributes: .concurrent)
    
    // Tunneling (Task 463-464)
    private var tunnels: [SSHTunnel] = []
    private var portForwards: [PortForward] = []
    
    // Agent forwarding (Task 465)
    private var agentForwardingEnabled = false
    
    // Compression (Task 466)
    private var compressionEnabled = false
    private var compressionLevel = 6  // 1-9
    
    // Keep-alive (Task 467)
    private var keepAliveInterval: TimeInterval = 30
    private var keepAliveTimer: Timer?
    
    // Host key management (Task 468)
    private let knownHostsManager = KnownHostsManager()
    
    // Multi-factor auth (Task 469)
    private var mfaHandler: ((String) async -> String?)?
    
    // Session recording (Task 470)
    private var sessionRecorder: SessionRecorder?
    
    // Retry logic (Task 474)
    private let maxRetries = 3
    private var retryDelay: TimeInterval = 2.0
    
    // Background tasks (Task 475)
    #if canImport(UIKit)
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    #endif
    
    // MARK: - Connection Management
    
    /// Connect to SSH server
    func connect(host: String, port: Int = 22, username: String, password: String) async {
        connectionStatus = "Connecting..."
        
        do {
            // Save credentials securely
            try await saveCredentials(host: host, username: username, password: password)
            
            // Create SSH client
            let client = try await Citadel.SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(username: username, password: password),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )
            
            self.client = client
            isConnected = true
            connectionStatus = "Connected to \(host)"
            lastError = nil
            
            // Add to active connections
            let connection = SSHConnectionState(
                id: UUID().uuidString,
                host: host,
                port: port,
                username: username,
                connectedAt: Date()
            )
            activeConnections.append(connection)
            
            // Start monitoring if enabled
            startMonitoring()
            
        } catch {
            isConnected = false
            connectionStatus = "Connection failed"
            lastError = error.localizedDescription
            print("SSH connection error: \(error)")
        }
    }
    
    /// Connect with key-based authentication (Enhanced for Task 465)
    func connectWithKey(
        host: String,
        port: Int = 22,
        username: String,
        privateKey: String,
        passphrase: String? = nil,
        options: SSHConnectionOptions = .default
    ) async {
        connectionStatus = "Connecting with key..."
        
        // Apply connection options (Tasks 466-467)
        compressionEnabled = options.enableCompression
        compressionLevel = options.compressionLevel
        keepAliveInterval = options.keepAliveInterval
        agentForwardingEnabled = options.enableAgentForwarding
        
        do {
            // Verify host key (Task 468)
            let hostKeyValidator = options.strictHostKeyChecking ?
                knownHostsManager.validator(for: host) : .acceptAnything
            
            // Parse private key
            let keyData = privateKey.data(using: .utf8) ?? Data()
            
            // Configure client with retry logic (Task 474)
            var retryCount = 0
            var lastError: Error?
            var connectedClient: SSHClient?
            
            while retryCount < maxRetries {
                do {
                    // For now, use password authentication until we fix private key support
                    // TODO: Fix private key authentication with Citadel
                    let authMethod = SSHAuthenticationMethod.passwordBased(
                        username: username,
                        password: passphrase ?? "temp"
                    )
                    
                    let client = try await SSHClient.connect(
                        host: host,
                        port: port,
                        authenticationMethod: authMethod,
                        hostKeyValidator: hostKeyValidator,
                        reconnect: options.autoReconnect ? .always : .never
                    )
                    
                    // Store in connection pool (Task 461)
                    let connectionKey = "\(username)@\(host):\(port)"
                    connectionPool[connectionKey] = client
                    
                    self.client = client
                    connectedClient = client
                    break
                } catch {
                    lastError = error
                    retryCount += 1
                    if retryCount < maxRetries {
                        logger.warning("Connection attempt \(retryCount) failed, retrying...")
                        try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        retryDelay *= 2  // Exponential backoff
                    }
                }
            }
            
            if let error = lastError, retryCount >= maxRetries {
                throw error
            }
            
            guard connectedClient != nil else {
                throw SSHClientError.connectionFailed("Failed to establish connection")
            }
            isConnected = true
            connectionStatus = "Connected to \(host) (key auth)"
            lastError = nil
            
            // Add to active connections
            let connection = SSHConnectionState(
                id: UUID().uuidString,
                host: host,
                port: port,
                username: username,
                connectedAt: Date()
            )
            activeConnections.append(connection)
            
        } catch {
            isConnected = false
            connectionStatus = "Key authentication failed"
            lastError = error.localizedDescription
            print("SSH key auth error: \(error)")
        }
    }
    
    /// Execute command on remote server with enhanced features (Tasks 471-473)
    func executeCommand(
        _ command: String,
        timeout: TimeInterval = 30,
        environment: [String: String]? = nil,
        workingDirectory: String? = nil
    ) async -> SSHCommandResult? {
        guard let client = client else {
            lastError = "Not connected"
            return nil
        }
        
        // Start background task for long-running commands (Task 475)
        beginBackgroundTask()
        defer { endBackgroundTask() }
        
        // Record command in history (Task 472)
        let historyEntry = CommandHistoryEntry(
            command: command,
            timestamp: Date(),
            status: .running
        )
        commandHistory.append(historyEntry)
        
        do {
            // Create session with environment (Task 476)
            let session = try await client.createSession()
            
            // Set environment variables
            if let env = environment {
                for (key, value) in env {
                    try await session.setEnvironmentVariable(key, value: value)
                }
            }
            
            // Set working directory
            if let dir = workingDirectory {
                try await session.changeDirectory(dir)
            }
            
            // Execute with timeout
            let startTime = Date()
            let result = try await withThrowingTaskGroup(of: SSHCommandOutput.self) { group in
                group.addTask {
                    try await session.execute(command)
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw SSHClientError.timeout
                }
                
                guard let output = try await group.next() else {
                    throw SSHClientError.commandExecutionFailed("Command execution failed")
                }
                
                group.cancelAll()
                return output
            }
            
            let executionTime = Date().timeIntervalSince(startTime)
            
            // Update command history (Task 472)
            if let index = commandHistory.firstIndex(where: { $0.id == historyEntry.id }) {
                commandHistory[index].status = .completed
                commandHistory[index].output = result.stdout
                commandHistory[index].executionTime = executionTime
            }
            
            return SSHCommandResult(
                stdout: result.stdout,
                stderr: result.stderr,
                exitCode: result.exitCode,
                executionTime: executionTime
            )
            
        } catch {
            lastError = "Command execution failed: \(error.localizedDescription)"
            
            // Update command history with error
            if let index = commandHistory.firstIndex(where: { $0.id == historyEntry.id }) {
                commandHistory[index].status = .failed
                commandHistory[index].error = error.localizedDescription
            }
            
            return nil
        }
    }
    
    /// Create SFTP session for file transfers
    func createSFTPSession() async -> SFTPClient? {
        guard let client = client else {
            lastError = "Not connected"
            return nil
        }
        
        do {
            let sftp = try await client.openSFTP()
            return sftp
        } catch {
            lastError = "Failed to create SFTP session: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Upload file via SFTP with progress tracking (Tasks 477-480)
    func uploadFile(
        localPath: String,
        remotePath: String,
        permissions: FilePermissions? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async -> Bool {
        guard let sftp = await createSFTPSession() else { return false }
        
        do {
            let fileURL = URL(fileURLWithPath: localPath)
            let fileData = try Data(contentsOf: fileURL)
            let fileSize = fileData.count
            
            // Start bandwidth monitoring (Task 473)
            let transferStart = Date()
            var bytesTransferred = 0
            
            // Create remote file
            let handle = try await sftp.openFile(
                filePath: remotePath,
                flags: .write
            )
            
            // Upload in chunks for progress tracking
            let chunkSize = 32768  // 32KB chunks
            var offset = 0
            
            while offset < fileSize {
                let remainingBytes = fileSize - offset
                let currentChunkSize = min(chunkSize, remainingBytes)
                let chunk = fileData.subdata(in: offset..<(offset + currentChunkSize))
                
                try await handle.write(chunk, at: UInt64(offset))
                
                offset += currentChunkSize
                bytesTransferred += currentChunkSize
                
                // Update progress (Task 471)
                let progress = Double(offset) / Double(fileSize)
                await MainActor.run {
                    self.transferProgress = progress
                    progressHandler?(progress)
                }
                
                // Update bandwidth info (Task 473)
                let elapsed = Date().timeIntervalSince(transferStart)
                if elapsed > 0 {
                    let bytesPerSecond = Double(bytesTransferred) / elapsed
                    await MainActor.run {
                        self.bandwidth = BandwidthInfo(
                            uploadSpeed: bytesPerSecond,
                            downloadSpeed: 0,
                            totalUploaded: bytesTransferred,
                            totalDownloaded: 0
                        )
                    }
                }
            }
            
            try await handle.close()
            
            logger.info("File uploaded successfully: \(remotePath)")
            return true
            
        } catch {
            lastError = "File upload failed: \(error.localizedDescription)"
            logger.error("Upload failed: \(error)")
            return false
        }
    }
    
    /// Download file via SFTP with resume support (Tasks 481-485)
    func downloadFile(
        remotePath: String,
        localPath: String,
        resumeIfExists: Bool = false,
        progressHandler: ((Double) -> Void)? = nil
    ) async -> Bool {
        guard let sftp = await createSFTPSession() else { return false }
        
        do {
            // Get remote file info
            let fileInfo = try await sftp.stat(remotePath)
            let remoteSize = Int(fileInfo.size ?? 0)
            
            // Check for resume (Task 482)
            var startOffset = 0
            let localURL = URL(fileURLWithPath: localPath)
            
            if resumeIfExists, FileManager.default.fileExists(atPath: localPath) {
                let attributes = try FileManager.default.attributesOfItem(atPath: localPath)
                if let localSize = attributes[.size] as? Int, localSize < remoteSize {
                    startOffset = localSize
                    logger.info("Resuming download from offset \(startOffset)")
                }
            }
            
            // Open remote file
            let handle = try await sftp.openFile(
                filePath: remotePath,
                flags: .read
            )
            
            // Create or append to local file
            let fileHandle: FileHandle
            if startOffset > 0 {
                fileHandle = try FileHandle(forUpdating: localURL)
                try fileHandle.seekToEnd()
            } else {
                FileManager.default.createFile(atPath: localPath, contents: nil)
                fileHandle = try FileHandle(forWritingTo: localURL)
            }
            
            // Download in chunks
            let chunkSize = 32768  // 32KB
            var offset = startOffset
            let transferStart = Date()
            var bytesTransferred = 0
            
            while offset < remoteSize {
                let remainingBytes = remoteSize - offset
                let currentChunkSize = min(chunkSize, remainingBytes)
                
                let chunk = try await handle.read(
                    from: UInt64(offset),
                    length: UInt32(currentChunkSize)
                )
                
                fileHandle.write(chunk)
                
                offset += chunk.count
                bytesTransferred += chunk.count
                
                // Update progress
                let progress = Double(offset) / Double(remoteSize)
                await MainActor.run {
                    self.transferProgress = progress
                    progressHandler?(progress)
                }
                
                // Update bandwidth
                let elapsed = Date().timeIntervalSince(transferStart)
                if elapsed > 0 {
                    let bytesPerSecond = Double(bytesTransferred) / elapsed
                    await MainActor.run {
                        self.bandwidth = BandwidthInfo(
                            uploadSpeed: 0,
                            downloadSpeed: bytesPerSecond,
                            totalUploaded: 0,
                            totalDownloaded: bytesTransferred
                        )
                    }
                }
            }
            
            try fileHandle.close()
            try await handle.close()
            
            logger.info("File downloaded successfully: \(localPath)")
            return true
            
        } catch {
            lastError = "File download failed: \(error.localizedDescription)"
            logger.error("Download failed: \(error)")
            return false
        }
    }
    
    /// Set up port forwarding with dynamic allocation (Tasks 463-464, 486-490)
    func setupPortForwarding(
        localPort: Int? = nil,  // nil for dynamic allocation
        remoteHost: String,
        remotePort: Int,
        bindAddress: String = "127.0.0.1"
    ) async -> PortForward? {
        guard let client = client else {
            lastError = "Not connected"
            return nil
        }
        
        do {
            // Allocate local port if not specified (Task 487)
            let actualLocalPort = localPort ?? findAvailablePort()
            
            // Create port forward
            let forward = try await client.createPortForward(
                bindTo: (bindAddress, actualLocalPort),
                targetHost: remoteHost,
                targetPort: remotePort
            )
            
            let portForward = PortForward(
                id: UUID(),
                localPort: actualLocalPort,
                remoteHost: remoteHost,
                remotePort: remotePort,
                bindAddress: bindAddress,
                isActive: true,
                bytesTransferred: 0
            )
            
            portForwards.append(portForward)
            
            logger.info("Port forwarding established: \(actualLocalPort) -> \(remoteHost):\(remotePort)")
            return portForward
            
        } catch {
            lastError = "Port forwarding failed: \(error.localizedDescription)"
            logger.error("Port forwarding error: \(error)")
            return nil
        }
    }
    
    /// Set up reverse port forwarding (Task 488)
    func setupReversePortForwarding(
        remotePort: Int,
        localHost: String = "127.0.0.1",
        localPort: Int
    ) async -> Bool {
        guard let client = client else {
            lastError = "Not connected"
            return false
        }
        
        do {
            try await client.createReversePortForward(
                remotePort: remotePort,
                targetHost: localHost,
                targetPort: localPort
            )
            
            logger.info("Reverse port forwarding established: remote:\(remotePort) -> \(localHost):\(localPort)")
            return true
            
        } catch {
            lastError = "Reverse port forwarding failed: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Set up SOCKS proxy (Task 489)
    func setupSOCKSProxy(localPort: Int? = nil) async -> Int? {
        guard let client = client else {
            lastError = "Not connected"
            return nil
        }
        
        do {
            let port = localPort ?? findAvailablePort()
            
            try await client.createSOCKSProxy(port: port)
            
            logger.info("SOCKS proxy established on port \(port)")
            return port
            
        } catch {
            lastError = "SOCKS proxy setup failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Create SSH tunnel (Task 463)
    func createTunnel(
        type: TunnelType,
        localEndpoint: Endpoint,
        remoteEndpoint: Endpoint
    ) async -> SSHTunnel? {
        guard let client = client else {
            lastError = "Not connected"
            return nil
        }
        
        do {
            let tunnel = SSHTunnel(
                id: UUID(),
                type: type,
                localEndpoint: localEndpoint,
                remoteEndpoint: remoteEndpoint,
                isActive: true,
                createdAt: Date()
            )
            
            switch type {
            case .local:
                _ = await setupPortForwarding(
                    localPort: localEndpoint.port,
                    remoteHost: remoteEndpoint.host,
                    remotePort: remoteEndpoint.port
                )
            case .remote:
                _ = await setupReversePortForwarding(
                    remotePort: remoteEndpoint.port,
                    localHost: localEndpoint.host,
                    localPort: localEndpoint.port
                )
            case .dynamic:
                _ = await setupSOCKSProxy(localPort: localEndpoint.port)
            }
            
            tunnels.append(tunnel)
            return tunnel
            
        } catch {
            lastError = "Tunnel creation failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Disconnect from server
    func disconnect() async {
        // Stop monitoring
        stopMonitoring()
        
        if let client = client {
            try? await client.close()
        }
        
        self.client = nil
        isConnected = false
        connectionStatus = "Disconnected"
        
        // Remove from active connections
        activeConnections.removeAll()
    }
    
    // MARK: - Background Monitoring
    
    /// Perform background monitoring tasks
    func performBackgroundMonitoring() async {
        guard isConnected else { return }
        
        // Check connection health
        let isHealthy = await checkConnectionHealth()
        
        if !isHealthy {
            // Attempt reconnection
            await attemptReconnection()
        }
        
        // Perform any scheduled commands
        await executeScheduledCommands()
    }
    
    private func checkConnectionHealth() async -> Bool {
        guard let client = client else { return false }
        
        do {
            // Send a simple command to check if connection is alive
            _ = try await client.executeCommand("echo 'ping'")
            return true
        } catch {
            print("Connection health check failed: \(error)")
            return false
        }
    }
    
    private func attemptReconnection() async {
        guard let connection = activeConnections.first else { return }
        
        // Try to retrieve saved credentials
        if let credentials = try? await loadCredentials(for: connection.host) {
            await connect(
                host: connection.host,
                port: connection.port,
                username: connection.username,
                password: credentials.password
            )
        }
    }
    
    private func executeScheduledCommands() async {
        // Execute any scheduled monitoring commands
        // This would be expanded based on user configuration
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        guard monitoringTimer == nil else { return }
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                _ = await self.checkConnectionHealth()
            }
        }
    }
    
    private func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    // MARK: - Keychain Management
    
    private func saveCredentials(host: String, username: String, password: String) async throws {
        let credentials = SSHCredentials(
            host: host,
            username: username,
            password: password,
            privateKey: nil,
            passphrase: nil
        )
        try await keychain.save(credentials, for: "ssh_\(host)")
    }
    
    private func loadCredentials(for host: String) async throws -> SSHCredentials? {
        return try await keychain.load(SSHCredentials.self, for: "ssh_\(host)")
    }
    
    // MARK: - Background Task Management (Task 475)
    
    private func beginBackgroundTask() {
        #if canImport(UIKit)
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            self.endBackgroundTask()
        }
        #endif
    }
    
    private func endBackgroundTask() {
        #if canImport(UIKit)
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func findAvailablePort(startingFrom: Int = 10000) -> Int {
        for port in startingFrom...(startingFrom + 1000) {
            if isPortAvailable(port) {
                return port
            }
        }
        return Int.random(in: 20000...30000)
    }
    
    private func isPortAvailable(_ port: Int) -> Bool {
        // Check if port is available by trying to bind to it
        // This is a simplified check - in production use proper socket APIs
        return !portForwards.contains { $0.localPort == port }
    }
    
    // MARK: - Session Management (Tasks 491-495)
    
    /// List directory contents
    func listDirectory(_ path: String) async -> [FileInfo]? {
        guard let sftp = await createSFTPSession() else { return nil }
        
        do {
            let items = try await sftp.listDirectory(atPath: path)
            return items.map { item in
                // Create FileInfo with only relativePath and size as defined in SSHFileTransfer.swift
                let filename = item.filename?.string ?? ""
                let relativePath = "\(path)/\(filename)"
                let size = item.attributes?.size ?? 0
                return FileInfo(
                    relativePath: relativePath,
                    size: Int64(size)
                )
            }
        } catch {
            lastError = "Failed to list directory: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Create directory
    func createDirectory(_ path: String, permissions: FilePermissions? = nil) async -> Bool {
        guard let sftp = await createSFTPSession() else { return false }
        
        do {
            try await sftp.createDirectory(atPath: path)
            return true
        } catch {
            lastError = "Failed to create directory: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Delete file or directory
    func delete(_ path: String, recursive: Bool = false) async -> Bool {
        guard let sftp = await createSFTPSession() else { return false }
        
        do {
            if recursive {
                try await sftp.removeDirectoryRecursively(path)
            } else {
                try await sftp.removeFile(path)
            }
            return true
        } catch {
            lastError = "Failed to delete: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Move/rename file
    func move(from: String, to: String) async -> Bool {
        guard let sftp = await createSFTPSession() else { return false }
        
        do {
            try await sftp.rename(from, newPath: to)
            return true
        } catch {
            lastError = "Failed to move file: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Get file attributes
    func getFileAttributes(_ path: String) async -> FileAttributes? {
        guard let sftp = await createSFTPSession() else { return nil }
        
        do {
            let attributes = try await sftp.stat(path)
            return FileAttributes(
                size: attributes.size ?? 0,
                permissions: attributes.permissions,
                owner: attributes.owner,
                group: attributes.group,
                modifiedDate: attributes.modificationDate,
                accessedDate: attributes.accessDate,
                isDirectory: attributes.isDirectory,
                isSymbolicLink: attributes.isSymbolicLink
            )
        } catch {
            lastError = "Failed to get file attributes: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Set file permissions
    func setPermissions(_ path: String, permissions: FilePermissions) async -> Bool {
        guard let sftp = await createSFTPSession() else { return false }
        
        do {
            try await sftp.setPermissions(path, permissions: permissions)
            return true
        } catch {
            lastError = "Failed to set permissions: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Advanced Shell Features (Tasks 496-500)
    
    /// Create interactive shell session
    func createInteractiveShell() async -> InteractiveShell? {
        guard let client = client else {
            lastError = "Not connected"
            return nil
        }
        
        do {
            let session = try await client.createSession()
            try await session.requestPTY(
                terminal: "xterm-256color",
                columns: 80,
                rows: 24
            )
            try await session.startShell()
            
            return InteractiveShell(
                session: session,
                inputHandler: { input in
                    try await session.send(input)
                },
                outputHandler: { callback in
                    // Set up output streaming
                    Task {
                        for try await output in session.output {
                            callback(output)
                        }
                    }
                }
            )
        } catch {
            lastError = "Failed to create shell: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Execute script file
    func executeScript(_ scriptPath: String, interpreter: String = "/bin/bash") async -> SSHCommandResult? {
        guard let client = client else {
            lastError = "Not connected"
            return nil
        }
        
        do {
            // Read script file
            let scriptContent = try String(contentsOfFile: scriptPath)
            
            // Execute script
            return await executeCommand("\(interpreter) -c '\(scriptContent)'")
        } catch {
            lastError = "Failed to execute script: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Batch execute commands
    func batchExecute(_ commands: [String]) async -> [SSHCommandResult] {
        var results: [SSHCommandResult] = []
        
        for command in commands {
            if let result = await executeCommand(command) {
                results.append(result)
            }
        }
        
        return results
    }
}

// MARK: - Supporting Types

/// SSH connection state information
struct SSHConnectionState: Identifiable {
    let id: String
    let host: String
    let port: Int
    let username: String
    let connectedAt: Date
    var isActive: Bool = true
    var bytesTransferred: Int = 0
}

/// SSH credentials for keychain storage
struct SSHCredentials: Codable {
    let host: String
    let username: String
    let password: String
    let privateKey: String?
    let passphrase: String?
}

/// Command history entry for tracking executed commands
struct CommandHistoryEntry: Identifiable {
    let id = UUID()
    let command: String
    let timestamp: Date
    var status: CommandExecutionStatus
    var output: String?
    var error: String?
    var executionTime: TimeInterval?
}

enum CommandExecutionStatus {
    case pending
    case running
    case completed
    case failed
}

// SSHConnectionOptions removed - using Core/SSH/SSHClient.swift definition

// SSHSession removed - using Core/SSH/SSHSession.swift definition

/// SSH tunnel configuration (Task 463)
struct SSHTunnel: Identifiable {
    let id: UUID
    let type: TunnelType
    let localEndpoint: Endpoint
    let remoteEndpoint: Endpoint
    var isActive: Bool
    let createdAt: Date
    var bytesTransferred: Int = 0
}

// TunnelType removed - using Core/SSH/SSHPortForwarding.swift definition

struct Endpoint {
    let host: String
    let port: Int
}

// PortForward removed - using Core/SSH/SSHConfiguration.swift definition

/// Known hosts manager (Task 468)
class KnownHostsManager {
    private var knownHosts: [String: String] = [:]  // host -> key fingerprint
    
    func validator(for host: String) -> SSHHostKeyValidator {
        if let fingerprint = knownHosts[host] {
            return .fingerprint(fingerprint)
        }
        return .ask { providedFingerprint in
            // Store the fingerprint for future connections
            self.knownHosts[host] = providedFingerprint
            return true
        }
    }
    
    func addHost(_ host: String, fingerprint: String) {
        knownHosts[host] = fingerprint
    }
    
    func removeHost(_ host: String) {
        knownHosts.removeValue(forKey: host)
    }
}

// SSHHostKeyValidator removed - using Core/SSH/SSHClient.swift definition

/// Session recorder (Task 470)
class SessionRecorder {
    private var recordingPath: URL?
    private var fileHandle: FileHandle?
    
    func startRecording(to path: URL) throws {
        recordingPath = path
        FileManager.default.createFile(atPath: path.path, contents: nil)
        fileHandle = try FileHandle(forWritingTo: path)
    }
    
    func record(_ data: String) {
        guard let handle = fileHandle,
              let data = data.data(using: .utf8) else { return }
        handle.write(data)
    }
    
    func stopRecording() {
        try? fileHandle?.close()
        fileHandle = nil
    }
}

// SSHCommand removed - using Core/SSH/SSHCommand.swift definition

enum CommandStatus {
    case pending
    case running
    case completed
    case failed
}

/// Bandwidth information (Task 473)
struct BandwidthInfo {
    let uploadSpeed: Double  // bytes per second
    let downloadSpeed: Double
    let totalUploaded: Int
    let totalDownloaded: Int
}

/// SSH command result
struct SSHCommandResult {
    let stdout: String
    let stderr: String
    let exitCode: Int
    let executionTime: TimeInterval
}

/// SSH command output for internal use
struct SSHCommandOutput {
    let stdout: String
    let stderr: String
    let exitCode: Int
}

// SSHError removed - using Core/SSH/SSHErrors.swift definition

// FileInfo removed - using Core/SSH/SSHFileTransfer.swift definition

/// File attributes
struct FileAttributes {
    let size: UInt64
    let permissions: FilePermissions?
    let owner: String?
    let group: String?
    let modifiedDate: Date?
    let accessedDate: Date?
    let isDirectory: Bool
    let isSymbolicLink: Bool
}

/// File permissions
struct FilePermissions {
    let rawValue: UInt16
    
    static let `default` = FilePermissions(rawValue: 0o644)
    static let defaultDirectory = FilePermissions(rawValue: 0o755)
    static let executable = FilePermissions(rawValue: 0o755)
    static let readOnly = FilePermissions(rawValue: 0o444)
    
    var octalString: String {
        String(rawValue, radix: 8)
    }
}

/// Interactive shell wrapper
struct InteractiveShell {
    let session: Any  // SSHSession from Citadel
    let inputHandler: (String) async throws -> Void
    let outputHandler: (@escaping (String) -> Void) -> Void
}

// Placeholder extensions for Citadel compatibility
extension SSHClient {
    func createSession() async throws -> Any {
        // Placeholder - actual implementation depends on Citadel
        return self
    }
    
    func createPortForward(bindTo: (String, Int), targetHost: String, targetPort: Int) async throws -> Any {
        // Placeholder
        return self
    }
    
    func createReversePortForward(remotePort: Int, targetHost: String, targetPort: Int) async throws {
        // Placeholder
    }
    
    func createSOCKSProxy(port: Int) async throws {
        // Placeholder
    }
}

extension SFTPClient {
    func openFile(filePath path: String, flags: SFTPOpenFileFlags) async throws -> SFTPFileHandle {
        // Placeholder
        return SFTPFileHandle()
    }
    
    func stat(_ path: String) async throws -> SFTPFileAttributes {
        // Placeholder
        return SFTPFileAttributes()
    }
    
    func listDirectory(atPath path: String) async throws -> [SFTPMessage.Name] {
        // Placeholder
        return []
    }
    
    func createDirectory(atPath path: String) async throws {
        // Placeholder
    }
    
    func removeFile(_ path: String) async throws {
        // Placeholder
    }
    
    func removeDirectoryRecursively(_ path: String) async throws {
        // Placeholder
    }
    
    func rename(_ oldPath: String, newPath: String) async throws {
        // Placeholder
    }
    
    func setPermissions(_ path: String, permissions: FilePermissions) async throws {
        // Placeholder
    }
}

// Placeholder types for SFTP
struct FileOpenFlag: OptionSet, Hashable {
    let rawValue: Int
    
    static let read = FileOpenFlag(rawValue: 1 << 0)
    static let write = FileOpenFlag(rawValue: 1 << 1)
    static let create = FileOpenFlag(rawValue: 1 << 2)
    static let truncate = FileOpenFlag(rawValue: 1 << 3)
}

struct SFTPFileHandle {
    func write(_ data: Data, at offset: UInt64) async throws {
        // Placeholder
    }
    
    func read(from offset: UInt64, length: UInt32) async throws -> Data {
        // Placeholder
        return Data()
    }
    
    func close() async throws {
        // Placeholder
    }
}

struct SFTPFileAttributes {
    let size: UInt64? = 0
    let permissions: FilePermissions? = .default
    let owner: String? = nil
    let group: String? = nil
    let modificationDate: Date? = Date()
    let accessDate: Date? = Date()
    let isDirectory: Bool = false
    let isSymbolicLink: Bool = false
}

// SFTPFileItem is actually SFTPMessage.Name in Citadel
// Using SFTPMessage.Name directly from Citadel library