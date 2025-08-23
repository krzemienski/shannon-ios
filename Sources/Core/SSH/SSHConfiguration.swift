//
//  SSHConfiguration.swift
//  ClaudeCode
//
//  SSH config file parsing and host profile management (Tasks 486-490)
//

import Foundation
import OSLog

/// SSH configuration manager for host profiles and config file parsing
@MainActor
public final class SSHConfiguration: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var hostProfiles: [SSHHostProfile] = []
    @Published public private(set) var globalConfig: SSHGlobalConfig
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: SSHConfigError?
    
    // MARK: - Private Properties
    
    private let keychain = KeychainManager.shared
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHConfiguration")
    private let fileManager = FileManager.default
    
    // Configuration paths
    private lazy var sshDirectory: URL = {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(".ssh", isDirectory: true)
    }()
    
    private lazy var configPath: URL = {
        sshDirectory.appendingPathComponent("config")
    }()
    
    private lazy var knownHostsPath: URL = {
        sshDirectory.appendingPathComponent("known_hosts")
    }()
    
    // MARK: - Initialization
    
    public init() {
        self.globalConfig = SSHGlobalConfig()
        
        Task {
            await setupConfigDirectory()
            await loadConfiguration()
        }
    }
    
    // MARK: - Configuration Loading
    
    /// Load SSH configuration from file
    public func loadConfiguration() async {
        logger.info("Loading SSH configuration")
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load config file if it exists
            if fileManager.fileExists(atPath: configPath.path) {
                let configContent = try String(contentsOf: configPath, encoding: .utf8)
                let profiles = try parseConfigFile(configContent)
                hostProfiles = profiles
                logger.info("Loaded \(profiles.count) host profiles")
            } else {
                // Create default config
                try await createDefaultConfig()
            }
            
            // Load known hosts
            await loadKnownHosts()
            
        } catch {
            logger.error("Failed to load configuration: \(error.localizedDescription)")
            lastError = .loadFailed(error.localizedDescription)
        }
    }
    
    /// Save configuration to file
    public func saveConfiguration() async throws {
        logger.info("Saving SSH configuration")
        
        let configContent = generateConfigContent()
        
        do {
            try configContent.write(to: configPath, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configPath.path)
            logger.info("Configuration saved successfully")
        } catch {
            logger.error("Failed to save configuration: \(error.localizedDescription)")
            throw SSHConfigError.saveFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Host Profile Management
    
    /// Add or update host profile
    public func addHostProfile(_ profile: SSHHostProfile) async throws {
        logger.info("Adding host profile: \(profile.name)")
        
        // Check for duplicates
        if let index = hostProfiles.firstIndex(where: { $0.id == profile.id }) {
            hostProfiles[index] = profile
        } else {
            hostProfiles.append(profile)
        }
        
        // Save configuration
        try await saveConfiguration()
        
        // Store credentials in keychain if present
        if let password = profile.password {
            try await storeCredentials(for: profile, password: password)
        }
        
        logger.info("Host profile added: \(profile.name)")
    }
    
    /// Remove host profile
    public func removeHostProfile(_ profile: SSHHostProfile) async throws {
        logger.info("Removing host profile: \(profile.name)")
        
        hostProfiles.removeAll { $0.id == profile.id }
        
        // Save configuration
        try await saveConfiguration()
        
        // Remove credentials from keychain
        try await removeCredentials(for: profile)
        
        logger.info("Host profile removed: \(profile.name)")
    }
    
    /// Get host profile by name or hostname
    public func getHostProfile(for host: String) -> SSHHostProfile? {
        // First check by profile name
        if let profile = hostProfiles.first(where: { $0.name == host }) {
            return profile
        }
        
        // Then check by hostname
        return hostProfiles.first(where: { $0.hostname == host })
    }
    
    /// Import SSH config from file or string
    public func importConfig(from source: ConfigSource) async throws {
        logger.info("Importing SSH configuration")
        
        let content: String
        
        switch source {
        case .file(let url):
            content = try String(contentsOf: url, encoding: .utf8)
        case .string(let configString):
            content = configString
        case .data(let data):
            guard let string = String(data: data, encoding: .utf8) else {
                throw SSHConfigError.invalidFormat
            }
            content = string
        }
        
        let profiles = try parseConfigFile(content)
        
        // Merge with existing profiles
        for profile in profiles {
            if !hostProfiles.contains(where: { $0.name == profile.name }) {
                hostProfiles.append(profile)
            }
        }
        
        try await saveConfiguration()
        logger.info("Imported \(profiles.count) host profiles")
    }
    
    /// Export SSH config
    public func exportConfig(profiles: [SSHHostProfile]? = nil) -> String {
        let profilesToExport = profiles ?? hostProfiles
        return generateConfigContent(for: profilesToExport)
    }
    
    // MARK: - Global Configuration
    
    /// Update global SSH configuration
    public func updateGlobalConfig(_ config: SSHGlobalConfig) async throws {
        globalConfig = config
        try await saveConfiguration()
        logger.info("Updated global SSH configuration")
    }
    
    // MARK: - Known Hosts Management
    
    /// Add known host
    public func addKnownHost(_ host: KnownHost) async throws {
        globalConfig.knownHosts.append(host)
        try await saveKnownHosts()
    }
    
    /// Remove known host
    public func removeKnownHost(_ host: KnownHost) async throws {
        globalConfig.knownHosts.removeAll { $0.id == host.id }
        try await saveKnownHosts()
    }
    
    /// Verify host key
    public func verifyHostKey(hostname: String, port: Int, key: String) -> HostKeyStatus {
        let hostIdentifier = port == 22 ? hostname : "[\(hostname)]:\(port)"
        
        if let knownHost = globalConfig.knownHosts.first(where: { $0.hostname == hostIdentifier }) {
            if knownHost.publicKey == key {
                return .trusted
            } else {
                return .changed(previous: knownHost.publicKey)
            }
        }
        
        return .unknown
    }
    
    // MARK: - Private Methods
    
    private func setupConfigDirectory() async {
        if !fileManager.fileExists(atPath: sshDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: sshDirectory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
                logger.debug("Created SSH configuration directory")
            } catch {
                logger.error("Failed to create SSH directory: \(error.localizedDescription)")
            }
        }
    }
    
    private func createDefaultConfig() async throws {
        logger.info("Creating default SSH configuration")
        
        // Create default global config
        globalConfig = SSHGlobalConfig(
            serverAliveInterval: 60,
            serverAliveCountMax: 3,
            compression: true,
            compressionLevel: 6,
            connectionAttempts: 3,
            connectTimeout: 30,
            strictHostKeyChecking: .ask,
            userKnownHostsFile: knownHostsPath.path,
            preferredAuthentications: [.publicKey, .password]
        )
        
        // Create example host profile
        let exampleProfile = SSHHostProfile(
            name: "example",
            hostname: "example.com",
            port: 22,
            username: "user",
            identityFile: "~/.ssh/id_rsa",
            forwardAgent: false,
            forwardX11: false,
            compression: true
        )
        
        hostProfiles = [exampleProfile]
        
        try await saveConfiguration()
    }
    
    private func parseConfigFile(_ content: String) throws -> [SSHHostProfile] {
        var profiles: [SSHHostProfile] = []
        var currentProfile: SSHHostProfile?
        var globalSettings: [String: String] = [:]
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            // Parse key-value pairs
            let components = trimmedLine.components(separatedBy: .whitespaces)
            guard components.count >= 2 else { continue }
            
            let key = components[0].lowercased()
            let value = components.dropFirst().joined(separator: " ")
            
            switch key {
            case "host":
                // Save current profile if exists
                if let profile = currentProfile {
                    profiles.append(profile)
                }
                // Start new profile
                currentProfile = SSHHostProfile(name: value)
                
            case "hostname":
                currentProfile?.hostname = value
                
            case "port":
                if let port = Int(value) {
                    currentProfile?.port = port
                }
                
            case "user":
                currentProfile?.username = value
                
            case "identityfile":
                currentProfile?.identityFile = expandPath(value)
                
            case "forwardagent":
                currentProfile?.forwardAgent = parseBool(value)
                
            case "forwardx11":
                currentProfile?.forwardX11 = parseBool(value)
                
            case "compression":
                currentProfile?.compression = parseBool(value)
                
            case "proxycommand":
                currentProfile?.proxyCommand = value
                
            case "proxyjump":
                currentProfile?.proxyJump = value
                
            case "localforward":
                if let forward = parsePortForward(value) {
                    currentProfile?.localForwards.append(forward)
                }
                
            case "remoteforward":
                if let forward = parsePortForward(value) {
                    currentProfile?.remoteForwards.append(forward)
                }
                
            case "serveraliveinterval":
                if currentProfile == nil {
                    globalConfig.serverAliveInterval = Int(value) ?? 60
                }
                
            case "serveralivecountmax":
                if currentProfile == nil {
                    globalConfig.serverAliveCountMax = Int(value) ?? 3
                }
                
            case "stricthostkeychecking":
                if currentProfile == nil {
                    globalConfig.strictHostKeyChecking = StrictHostKeyChecking(rawValue: value) ?? .ask
                }
                
            default:
                // Store as custom option
                if currentProfile != nil {
                    currentProfile?.customOptions[key] = value
                } else {
                    globalSettings[key] = value
                }
            }
        }
        
        // Save last profile
        if let profile = currentProfile {
            profiles.append(profile)
        }
        
        return profiles
    }
    
    private func generateConfigContent(for profiles: [SSHHostProfile]? = nil) -> String {
        var lines: [String] = []
        
        // Add header
        lines.append("# SSH Configuration")
        lines.append("# Generated by Claude Code iOS")
        lines.append("")
        
        // Add global settings
        lines.append("# Global Settings")
        lines.append("ServerAliveInterval \(globalConfig.serverAliveInterval)")
        lines.append("ServerAliveCountMax \(globalConfig.serverAliveCountMax)")
        lines.append("Compression \(globalConfig.compression ? "yes" : "no")")
        lines.append("CompressionLevel \(globalConfig.compressionLevel)")
        lines.append("ConnectionAttempts \(globalConfig.connectionAttempts)")
        lines.append("ConnectTimeout \(globalConfig.connectTimeout)")
        lines.append("StrictHostKeyChecking \(globalConfig.strictHostKeyChecking.rawValue)")
        lines.append("")
        
        // Add host profiles
        let profilesToWrite = profiles ?? hostProfiles
        for profile in profilesToWrite {
            lines.append("Host \(profile.name)")
            lines.append("    HostName \(profile.hostname)")
            lines.append("    Port \(profile.port)")
            
            if let username = profile.username {
                lines.append("    User \(username)")
            }
            
            if let identityFile = profile.identityFile {
                lines.append("    IdentityFile \(identityFile)")
            }
            
            lines.append("    ForwardAgent \(profile.forwardAgent ? "yes" : "no")")
            lines.append("    ForwardX11 \(profile.forwardX11 ? "yes" : "no")")
            lines.append("    Compression \(profile.compression ? "yes" : "no")")
            
            if let proxyCommand = profile.proxyCommand {
                lines.append("    ProxyCommand \(proxyCommand)")
            }
            
            if let proxyJump = profile.proxyJump {
                lines.append("    ProxyJump \(proxyJump)")
            }
            
            for forward in profile.localForwards {
                lines.append("    LocalForward \(forward.localPort) \(forward.remoteHost):\(forward.remotePort)")
            }
            
            for forward in profile.remoteForwards {
                lines.append("    RemoteForward \(forward.localPort) \(forward.remoteHost):\(forward.remotePort)")
            }
            
            for (key, value) in profile.customOptions {
                lines.append("    \(key) \(value)")
            }
            
            lines.append("")
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func loadKnownHosts() async {
        guard fileManager.fileExists(atPath: knownHostsPath.path) else { return }
        
        do {
            let content = try String(contentsOf: knownHostsPath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            globalConfig.knownHosts = lines.compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { return nil }
                
                let components = trimmed.components(separatedBy: .whitespaces)
                guard components.count >= 3 else { return nil }
                
                return KnownHost(
                    hostname: components[0],
                    keyType: components[1],
                    publicKey: components[2]
                )
            }
            
            logger.info("Loaded \(globalConfig.knownHosts.count) known hosts")
        } catch {
            logger.error("Failed to load known hosts: \(error.localizedDescription)")
        }
    }
    
    private func saveKnownHosts() async throws {
        var lines: [String] = []
        
        for host in globalConfig.knownHosts {
            lines.append("\(host.hostname) \(host.keyType) \(host.publicKey)")
        }
        
        let content = lines.joined(separator: "\n")
        
        try content.write(to: knownHostsPath, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: knownHostsPath.path)
    }
    
    private func storeCredentials(for profile: SSHHostProfile, password: String) async throws {
        let key = "ssh_password_\(profile.id.uuidString)"
        try await keychain.saveString(password, for: key)
    }
    
    private func removeCredentials(for profile: SSHHostProfile) async throws {
        let key = "ssh_password_\(profile.id.uuidString)"
        try await keychain.delete(for: key)
    }
    
    private func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            let home = fileManager.homeDirectoryForCurrentUser.path
            return path.replacingOccurrences(of: "~", with: home, range: path.startIndex..<path.index(after: path.startIndex))
        }
        return path
    }
    
    private func parseBool(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        return lowercased == "yes" || lowercased == "true" || lowercased == "1"
    }
    
    private func parsePortForward(_ value: String) -> PortForward? {
        let components = value.components(separatedBy: .whitespaces)
        guard components.count == 2 else { return nil }
        
        guard let localPort = Int(components[0]) else { return nil }
        
        let remoteComponents = components[1].components(separatedBy: ":")
        guard remoteComponents.count == 2,
              let remotePort = Int(remoteComponents[1]) else { return nil }
        
        return PortForward(
            localPort: localPort,
            remoteHost: remoteComponents[0],
            remotePort: remotePort
        )
    }
}

// MARK: - Supporting Types

/// SSH host profile
public struct SSHHostProfile: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var hostname: String
    public var port: Int
    public var username: String?
    public var password: String?
    public var identityFile: String?
    public var forwardAgent: Bool
    public var forwardX11: Bool
    public var compression: Bool
    public var proxyCommand: String?
    public var proxyJump: String?
    public var localForwards: [PortForward]
    public var remoteForwards: [PortForward]
    public var customOptions: [String: String]
    
    public init(
        id: UUID = UUID(),
        name: String,
        hostname: String = "",
        port: Int = 22,
        username: String? = nil,
        password: String? = nil,
        identityFile: String? = nil,
        forwardAgent: Bool = false,
        forwardX11: Bool = false,
        compression: Bool = true,
        proxyCommand: String? = nil,
        proxyJump: String? = nil
    ) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
        self.identityFile = identityFile
        self.forwardAgent = forwardAgent
        self.forwardX11 = forwardX11
        self.compression = compression
        self.proxyCommand = proxyCommand
        self.proxyJump = proxyJump
        self.localForwards = []
        self.remoteForwards = []
        self.customOptions = [:]
    }
}

/// Global SSH configuration
public struct SSHGlobalConfig: Codable {
    public var serverAliveInterval: Int
    public var serverAliveCountMax: Int
    public var compression: Bool
    public var compressionLevel: Int
    public var connectionAttempts: Int
    public var connectTimeout: Int
    public var strictHostKeyChecking: StrictHostKeyChecking
    public var userKnownHostsFile: String
    public var preferredAuthentications: [AuthenticationMethod]
    public var knownHosts: [KnownHost]
    
    public init(
        serverAliveInterval: Int = 60,
        serverAliveCountMax: Int = 3,
        compression: Bool = true,
        compressionLevel: Int = 6,
        connectionAttempts: Int = 3,
        connectTimeout: Int = 30,
        strictHostKeyChecking: StrictHostKeyChecking = .ask,
        userKnownHostsFile: String = "~/.ssh/known_hosts",
        preferredAuthentications: [AuthenticationMethod] = [.publicKey, .password],
        knownHosts: [KnownHost] = []
    ) {
        self.serverAliveInterval = serverAliveInterval
        self.serverAliveCountMax = serverAliveCountMax
        self.compression = compression
        self.compressionLevel = compressionLevel
        self.connectionAttempts = connectionAttempts
        self.connectTimeout = connectTimeout
        self.strictHostKeyChecking = strictHostKeyChecking
        self.userKnownHostsFile = userKnownHostsFile
        self.preferredAuthentications = preferredAuthentications
        self.knownHosts = knownHosts
    }
}

/// Port forwarding configuration
public struct PortForward: Codable, Hashable {
    public let localPort: Int
    public let remoteHost: String
    public let remotePort: Int
}

/// Known host entry
public struct KnownHost: Identifiable, Codable, Hashable {
    public let id: UUID
    public let hostname: String
    public let keyType: String
    public let publicKey: String
    public let addedAt: Date
    
    public init(
        id: UUID = UUID(),
        hostname: String,
        keyType: String,
        publicKey: String,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.hostname = hostname
        self.keyType = keyType
        self.publicKey = publicKey
        self.addedAt = addedAt
    }
}

/// Authentication method
public enum AuthenticationMethod: String, Codable, CaseIterable {
    case publicKey = "publickey"
    case password = "password"
    case keyboardInteractive = "keyboard-interactive"
    case hostBased = "hostbased"
}

/// Strict host key checking mode
public enum StrictHostKeyChecking: String, Codable {
    case yes = "yes"
    case no = "no"
    case ask = "ask"
    case accept = "accept-new"
}

/// Host key verification status
public enum HostKeyStatus {
    case trusted
    case unknown
    case changed(previous: String)
}

/// Configuration source
public enum ConfigSource {
    case file(URL)
    case string(String)
    case data(Data)
}

/// SSH configuration errors
public enum SSHConfigError: LocalizedError {
    case loadFailed(String)
    case saveFailed(String)
    case invalidFormat
    case profileNotFound(String)
    case duplicateProfile(String)
    
    public var errorDescription: String? {
        switch self {
        case .loadFailed(let reason):
            return "Failed to load configuration: \(reason)"
        case .saveFailed(let reason):
            return "Failed to save configuration: \(reason)"
        case .invalidFormat:
            return "Invalid configuration format"
        case .profileNotFound(let name):
            return "Host profile not found: \(name)"
        case .duplicateProfile(let name):
            return "Duplicate host profile: \(name)"
        }
    }
}