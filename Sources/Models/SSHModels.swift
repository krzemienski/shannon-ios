import Foundation

// Type alias for compatibility
public typealias SSHConfig = AppSSHConfig

// MARK: - SSH Configuration

/// Configuration for SSH connections
public struct AppSSHConfig: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var host: String
    public var port: UInt16
    public var username: String
    public var authMethod: AppSSHAuthMethod
    public var password: String?
    public var privateKey: String?
    public var privateKeyPath: String?
    public var passphrase: String?
    public var timeout: TimeInterval
    public var keepAliveInterval: TimeInterval
    public var strictHostKeyChecking: Bool
    public var compression: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        host: String,
        port: UInt16 = 22,
        username: String,
        authMethod: AppSSHAuthMethod = .password,
        password: String? = nil,
        privateKey: String? = nil,
        privateKeyPath: String? = nil,
        passphrase: String? = nil,
        timeout: TimeInterval = 30,
        keepAliveInterval: TimeInterval = 60,
        strictHostKeyChecking: Bool = true,
        compression: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.password = password
        self.privateKey = privateKey
        self.privateKeyPath = privateKeyPath
        self.passphrase = passphrase
        self.timeout = timeout
        self.keepAliveInterval = keepAliveInterval
        self.strictHostKeyChecking = strictHostKeyChecking
        self.compression = compression
    }
    
    /// Default configuration for quick testing
    public static var `default`: AppSSHConfig {
        AppSSHConfig(
            name: "New Connection",
            host: "localhost",
            username: "user"
        )
    }
}

// MARK: - SSH Auth Method

public enum AppSSHAuthMethod: String, Codable, CaseIterable, Hashable {
    case password
    case publicKey
    case keyboardInteractive
    case none
    
    public var displayName: String {
        switch self {
        case .password:
            return "Password"
        case .publicKey:
            return "Public Key"
        case .keyboardInteractive:
            return "Keyboard Interactive"
        case .none:
            return "None"
        }
    }
}

// MARK: - SSH Service

/// Mock SSH service for basic connection testing
public final class SSHService {
    public init() {}
    
    public func connect(
        host: String,
        port: UInt16,
        username: String,
        password: String
    ) async throws {
        // Mock implementation - would use Citadel in real app
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
    }
    
    public func connect(
        host: String,
        port: UInt16,
        username: String,
        privateKey: String,
        passphrase: String?
    ) async throws {
        // Mock implementation - would use Citadel in real app
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
    }
    
    public func disconnect() async {
        // Mock implementation
    }
}

// MARK: - SSH Credential Extensions

/// Extension to help with loading SSH credentials
public extension SSHCredentialManager {
    func loadCredential(id: String) async throws -> SSHCredential {
        guard let credential = savedCredentials.first(where: { $0.id == id }) else {
            throw SSHError.credentialNotFound
        }
        return credential
    }
    
    func loadKey(id: String) async throws -> SSHKey {
        guard let key = savedKeys.first(where: { $0.id == id }) else {
            throw SSHError.keyNotFound
        }
        return key
    }
}

// MARK: - SSH Errors

public enum SSHError: LocalizedError {
    case credentialNotFound
    case keyNotFound
    case connectionFailed(String)
    case authenticationFailed
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .credentialNotFound:
            return "SSH credential not found"
        case .keyNotFound:
            return "SSH key not found"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .authenticationFailed:
            return "Authentication failed"
        case .timeout:
            return "Connection timeout"
        }
    }
}

// MARK: - SSH Credential Extension

/// Extension for SSHCredential to include missing properties
public extension SSHCredential {
    var password: String? { passphrase }
    var privateKey: String? { privateKeyPath }
}

// Type alias for compatibility
public typealias SSHConfiguration = AppSSHConfig

// MARK: - Monitoring Types

/// SSH metrics for monitoring
public struct SSHMetrics: Codable {
    public let connectedSessions: Int
    public let totalBytesReceived: Int64
    public let totalBytesSent: Int64
    public let averageLatency: TimeInterval
    public let sessionDurations: [TimeInterval]
    
    public init(
        connectedSessions: Int = 0,
        totalBytesReceived: Int64 = 0,
        totalBytesSent: Int64 = 0,
        averageLatency: TimeInterval = 0,
        sessionDurations: [TimeInterval] = []
    ) {
        self.connectedSessions = connectedSessions
        self.totalBytesReceived = totalBytesReceived
        self.totalBytesSent = totalBytesSent
        self.averageLatency = averageLatency
        self.sessionDurations = sessionDurations
    }
}

/// System metrics for monitoring
public struct SystemMetrics: Codable {
    public let cpu: CPUMetrics
    public let memory: MemoryMetrics
    public let disk: DiskMetrics
    public let network: NetworkMetrics
    
    public init(
        cpu: CPUMetrics = CPUMetrics(),
        memory: MemoryMetrics = MemoryMetrics(),
        disk: DiskMetrics = DiskMetrics(),
        network: NetworkMetrics = NetworkMetrics()
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
    }
}

/// CPU metrics
public struct CPUMetrics: Codable {
    public let usage: Double
    public let cores: Int
    public let temperature: Double?
    
    public init(usage: Double = 0, cores: Int = 1, temperature: Double? = nil) {
        self.usage = usage
        self.cores = cores
        self.temperature = temperature
    }
}

/// Memory metrics
public struct MemoryMetrics: Codable {
    public let total: Int64
    public let used: Int64
    public let free: Int64
    public let cached: Int64
    
    public init(total: Int64 = 0, used: Int64 = 0, free: Int64 = 0, cached: Int64 = 0) {
        self.total = total
        self.used = used
        self.free = free
        self.cached = cached
    }
}

/// Disk metrics
public struct DiskMetrics: Codable {
    public let total: Int64
    public let used: Int64
    public let free: Int64
    public let readBytes: Int64
    public let writeBytes: Int64
    
    public init(
        total: Int64 = 0,
        used: Int64 = 0,
        free: Int64 = 0,
        readBytes: Int64 = 0,
        writeBytes: Int64 = 0
    ) {
        self.total = total
        self.used = used
        self.free = free
        self.readBytes = readBytes
        self.writeBytes = writeBytes
    }
}

/// Network metrics
public struct NetworkMetrics: Codable {
    public let bytesIn: Int64
    public let bytesOut: Int64
    public let packetsIn: Int64
    public let packetsOut: Int64
    public let errors: Int64
    
    public init(
        bytesIn: Int64 = 0,
        bytesOut: Int64 = 0,
        packetsIn: Int64 = 0,
        packetsOut: Int64 = 0,
        errors: Int64 = 0
    ) {
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.packetsIn = packetsIn
        self.packetsOut = packetsOut
        self.errors = errors
    }
}

/// Host snapshot for monitoring
public struct HostSnapshot: Codable {
    public let timestamp: Date
    public let cpu: Double
    public let memory: Double
    public let disk: Double
    public let network: NetworkSnapshot
    public let processes: [ProcessMetrics]
    
    public init(
        timestamp: Date = Date(),
        cpu: Double = 0,
        memory: Double = 0,
        disk: Double = 0,
        network: NetworkSnapshot = NetworkSnapshot(),
        processes: [ProcessMetrics] = []
    ) {
        self.timestamp = timestamp
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
        self.processes = processes
    }
}

/// Network snapshot
public struct NetworkSnapshot: Codable {
    public let bytesIn: Int64
    public let bytesOut: Int64
    public let packetsIn: Int64
    public let packetsOut: Int64
    
    public init(
        bytesIn: Int64 = 0,
        bytesOut: Int64 = 0,
        packetsIn: Int64 = 0,
        packetsOut: Int64 = 0
    ) {
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.packetsIn = packetsIn
        self.packetsOut = packetsOut
    }
}

/// Process information for monitoring
public struct ProcessMetrics: Codable {
    public let pid: Int32
    public let name: String
    public let cpu: Double
    public let memory: Double
    
    public init(
        pid: Int32,
        name: String,
        cpu: Double = 0,
        memory: Double = 0
    ) {
        self.pid = pid
        self.name = name
        self.cpu = cpu
        self.memory = memory
    }
}