import Foundation

// MARK: - Task 184: SSHConfig Model
/// SSH configuration
public struct SSHConfig: Codable, Equatable {
    public let id: String
    public let name: String
    public let host: String
    public let port: Int
    public let username: String
    public let authMethod: SSHAuthMethod
    public let privateKeyPath: String?
    public let password: String?
    public let passphrase: String?
    public let jumpHost: JumpHostConfig?
    public let options: SSHOptions?
    public let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case host
        case port
        case username
        case authMethod = "auth_method"
        case privateKeyPath = "private_key_path"
        case password
        case passphrase
        case jumpHost = "jump_host"
        case options
        case tags
    }
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authMethod: SSHAuthMethod,
        privateKeyPath: String? = nil,
        password: String? = nil,
        passphrase: String? = nil,
        jumpHost: JumpHostConfig? = nil,
        options: SSHOptions? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.privateKeyPath = privateKeyPath
        self.password = password
        self.passphrase = passphrase
        self.jumpHost = jumpHost
        self.options = options
        self.tags = tags
    }
}

/// SSH authentication method
public enum SSHAuthMethod: String, Codable {
    case password
    case publicKey = "public_key"
    case keyboardInteractive = "keyboard_interactive"
    case agent
}

/// Jump host configuration
public struct JumpHostConfig: Codable, Equatable {
    public let host: String
    public let port: Int
    public let username: String
    public let authMethod: SSHAuthMethod
    public let privateKeyPath: String?
    public let password: String?
    
    enum CodingKeys: String, CodingKey {
        case host
        case port
        case username
        case authMethod = "auth_method"
        case privateKeyPath = "private_key_path"
        case password
    }
}

/// SSH connection options
public struct SSHOptions: Codable, Equatable {
    public let keepAlive: Bool
    public let keepAliveInterval: TimeInterval?
    public let connectionTimeout: TimeInterval?
    public let strictHostKeyChecking: Bool
    public let compression: Bool
    public let forwardAgent: Bool
    public let x11Forwarding: Bool
    
    enum CodingKeys: String, CodingKey {
        case keepAlive = "keep_alive"
        case keepAliveInterval = "keep_alive_interval"
        case connectionTimeout = "connection_timeout"
        case strictHostKeyChecking = "strict_host_key_checking"
        case compression
        case forwardAgent = "forward_agent"
        case x11Forwarding = "x11_forwarding"
    }
    
    public init(
        keepAlive: Bool = true,
        keepAliveInterval: TimeInterval? = 30,
        connectionTimeout: TimeInterval? = 10,
        strictHostKeyChecking: Bool = true,
        compression: Bool = false,
        forwardAgent: Bool = false,
        x11Forwarding: Bool = false
    ) {
        self.keepAlive = keepAlive
        self.keepAliveInterval = keepAliveInterval
        self.connectionTimeout = connectionTimeout
        self.strictHostKeyChecking = strictHostKeyChecking
        self.compression = compression
        self.forwardAgent = forwardAgent
        self.x11Forwarding = x11Forwarding
    }
}

/// SSH session information
public struct SSHSessionInfo: Codable, Identifiable, Equatable {
    public let id: String
    public let configId: String
    public let status: SSHSessionStatus
    public let connectedAt: Date?
    public let lastActivity: Date?
    public let remoteAddress: String?
    public let localPort: Int?
    public let statistics: SSHSessionStats?
    
    enum CodingKeys: String, CodingKey {
        case id
        case configId = "config_id"
        case status
        case connectedAt = "connected_at"
        case lastActivity = "last_activity"
        case remoteAddress = "remote_address"
        case localPort = "local_port"
        case statistics
    }
}

/// SSH session status
public enum SSHSessionStatus: String, Codable {
    case connecting
    case connected
    case disconnecting
    case disconnected
    case error
    case authenticated
    case idle
}

/// SSH session statistics
public struct SSHSessionStats: Codable, Equatable {
    public let bytesSent: Int64
    public let bytesReceived: Int64
    public let commandsExecuted: Int
    public let errors: Int
    public let uptime: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case bytesSent = "bytes_sent"
        case bytesReceived = "bytes_received"
        case commandsExecuted = "commands_executed"
        case errors
        case uptime
    }
}

/// SSH session request
public struct SSHSessionRequest: Codable {
    public let configId: String
    public let autoConnect: Bool
    
    enum CodingKeys: String, CodingKey {
        case configId = "config_id"
        case autoConnect = "auto_connect"
    }
    
    public init(configId: String, autoConnect: Bool = true) {
        self.configId = configId
        self.autoConnect = autoConnect
    }
}

/// SSH command request
public struct SSHCommandRequest: Codable {
    public let sessionId: String
    public let command: String
    public let timeout: TimeInterval?
    public let environment: [String: String]?
    public let workingDirectory: String?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case command
        case timeout
        case environment
        case workingDirectory = "working_directory"
    }
    
    public init(
        sessionId: String,
        command: String,
        timeout: TimeInterval? = nil,
        environment: [String: String]? = nil,
        workingDirectory: String? = nil
    ) {
        self.sessionId = sessionId
        self.command = command
        self.timeout = timeout
        self.environment = environment
        self.workingDirectory = workingDirectory
    }
}

/// SSH command response
public struct SSHCommandResponse: Codable {
    public let id: String
    public let sessionId: String
    public let command: String
    public let output: String
    public let error: String?
    public let exitCode: Int
    public let executionTime: TimeInterval
    public let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case command
        case output
        case error
        case exitCode = "exit_code"
        case executionTime = "execution_time"
        case timestamp
    }
}

/// SSH sessions response
public struct SSHSessionsResponse: Codable {
    public let sessions: [SSHSessionInfo]
    public let totalCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case sessions
        case totalCount = "total_count"
    }
}

// MARK: - Task 185: HostSnapshot Model
/// Host system snapshot
public struct HostSnapshot: Codable, Equatable {
    public let id: String
    public let hostname: String
    public let timestamp: Date
    public let system: SystemInfo
    public let cpu: CPUInfo
    public let memory: MemoryInfo
    public let disk: [DiskInfo]
    public let network: [NetworkInterface]
    public let processes: [ProcessInfo]?
    public let services: [ServiceInfo]?
    
    public init(
        id: String = UUID().uuidString,
        hostname: String,
        timestamp: Date = Date(),
        system: SystemInfo,
        cpu: CPUInfo,
        memory: MemoryInfo,
        disk: [DiskInfo],
        network: [NetworkInterface],
        processes: [ProcessInfo]? = nil,
        services: [ServiceInfo]? = nil
    ) {
        self.id = id
        self.hostname = hostname
        self.timestamp = timestamp
        self.system = system
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
        self.processes = processes
        self.services = services
    }
}

/// System information
public struct SystemInfo: Codable, Equatable {
    public let os: String
    public let kernel: String
    public let architecture: String
    public let uptime: TimeInterval
    public let loadAverage: [Double]
    
    enum CodingKeys: String, CodingKey {
        case os
        case kernel
        case architecture
        case uptime
        case loadAverage = "load_average"
    }
}

/// CPU information
public struct CPUInfo: Codable, Equatable {
    public let model: String
    public let cores: Int
    public let threads: Int
    public let frequency: Double // in GHz
    public let usage: Double // percentage
    public let temperature: Double? // in Celsius
}

/// Memory information
public struct MemoryInfo: Codable, Equatable {
    public let total: Int64
    public let used: Int64
    public let free: Int64
    public let available: Int64
    public let cached: Int64
    public let buffers: Int64
    public let swapTotal: Int64
    public let swapUsed: Int64
    
    enum CodingKeys: String, CodingKey {
        case total
        case used
        case free
        case available
        case cached
        case buffers
        case swapTotal = "swap_total"
        case swapUsed = "swap_used"
    }
}

/// Disk information
public struct DiskInfo: Codable, Equatable {
    public let device: String
    public let mountPoint: String
    public let filesystem: String
    public let total: Int64
    public let used: Int64
    public let free: Int64
    public let usage: Double // percentage
    
    enum CodingKeys: String, CodingKey {
        case device
        case mountPoint = "mount_point"
        case filesystem
        case total
        case used
        case free
        case usage
    }
}

/// Network interface information
public struct NetworkInterface: Codable, Equatable {
    public let name: String
    public let ipAddress: String?
    public let macAddress: String?
    public let status: String
    public let speed: Int64? // in Mbps
    public let bytesReceived: Int64
    public let bytesSent: Int64
    public let packetsReceived: Int64
    public let packetsSent: Int64
    
    enum CodingKeys: String, CodingKey {
        case name
        case ipAddress = "ip_address"
        case macAddress = "mac_address"
        case status
        case speed
        case bytesReceived = "bytes_received"
        case bytesSent = "bytes_sent"
        case packetsReceived = "packets_received"
        case packetsSent = "packets_sent"
    }
}

/// Service information
public struct ServiceInfo: Codable, Equatable {
    public let name: String
    public let status: String
    public let pid: Int?
    public let memory: Int64?
    public let cpu: Double?
    public let uptime: TimeInterval?
}