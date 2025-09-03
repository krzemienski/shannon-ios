//
//  SSHClient.swift
//  ClaudeCode
//
//  SSH client implementation wrapper
//

import Foundation
import Combine
@preconcurrency import Citadel
import CryptoKit

/// SSH client for managing SSH connections
@MainActor
public class SSHClient: ObservableObject {
    @Published public var isConnected: Bool = false
    @Published public var lastError: Error?
    
    private var client: Citadel.SSHClient?
    private var cancellables = Set<AnyCancellable>()
    
    public init() {}
    
    /// Connect to SSH server
    public func connect(with config: SSHConfig, options: SSHConnectionOptions? = nil) async throws {
        // Create authentication method
        let authMethod: SSHAuthenticationMethod
        switch config.authMethod {
        case .password:
            guard let password = config.password else {
                throw SSHError.authenticationFailed("Password required")
            }
            authMethod = .passwordBased(username: config.username, password: password)
            
        case .publicKey:
            guard let privateKeyString = config.privateKey else {
                throw SSHError.authenticationFailed("Private key required")
            }
            
            // For now, assume Ed25519 keys (most common modern SSH keys)
            // TODO: Add proper key type detection and parsing
            guard let privateKeyData = Data(base64Encoded: privateKeyString),
                  let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData) else {
                throw SSHError.authenticationFailed("Invalid private key format")
            }
            
            authMethod = .ed25519(username: config.username, privateKey: privateKey)
            
        case .keyboardInteractive:
            // Simplified - would need callback handling
            authMethod = .passwordBased(username: config.username, password: config.password ?? "")
            
        case .none:
            // For servers that allow no authentication (rare)
            authMethod = .passwordBased(username: config.username, password: "")
        }
        
        do {
            // Connect using Citadel
            self.client = try await Citadel.SSHClient.connect(
                host: config.host,
                port: Int(config.port), // Convert UInt16 to Int
                authenticationMethod: authMethod,
                hostKeyValidator: .acceptAnything(), // For development - should validate in production
                reconnect: .never
            )
            
            isConnected = true
        } catch {
            lastError = error
            isConnected = false
            throw SSHError.connectionFailed(error.localizedDescription)
        }
    }
    
    /// Disconnect from SSH server
    public func disconnect() async {
        if let client = client {
            try? await client.close()
        }
        client = nil
        isConnected = false
    }
    
    /// Execute command on remote server
    public func executeCommand(_ command: String) async throws -> CommandResult {
        guard let client = client else {
            throw SSHError.notConnected
        }
        
        do {
            let output = try await client.executeCommand(command)
            return CommandResult(
                stdout: String(buffer: output),
                stderr: "",
                exitCode: 0
            )
        } catch {
            throw SSHError.commandFailed(error.localizedDescription)
        }
    }
    
    /// Create shell session
    public func createShellSession() async throws -> ShellSession {
        guard let client = client else {
            throw SSHError.notConnected
        }
        
        // Create and return shell session
        return ShellSession(client: client)
    }
}

/// Command execution result
public struct CommandResult {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    
    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

/// SSH connection options
public struct SSHConnectionOptions {
    public var keepAliveInterval: TimeInterval
    public var connectionTimeout: TimeInterval
    public var strictHostKeyChecking: Bool
    public var enableCompression: Bool
    public var autoReconnect: Bool
    
    public init(
        keepAliveInterval: TimeInterval = 30,
        connectionTimeout: TimeInterval = 10,
        strictHostKeyChecking: Bool = false,
        enableCompression: Bool = true,
        autoReconnect: Bool = true
    ) {
        self.keepAliveInterval = keepAliveInterval
        self.connectionTimeout = connectionTimeout
        self.strictHostKeyChecking = strictHostKeyChecking
        self.enableCompression = enableCompression
        self.autoReconnect = autoReconnect
    }
}

/// Shell session for interactive terminal
public class ShellSession {
    public let outputStream = PassthroughSubject<Data, Never>()
    public var cancellables = Set<AnyCancellable>()
    
    private let client: Citadel.SSHClient
    
    init(client: Citadel.SSHClient) {
        self.client = client
    }
    
    public func write(_ data: Data) async throws {
        // Write data to shell
        // This would integrate with Citadel's shell functionality
    }
}

/// SSH errors
public enum SSHError: LocalizedError {
    case notConnected
    case connectionFailed(String)
    case authenticationFailed(String)
    case commandFailed(String)
    case sessionCreationFailed(String)
    case credentialNotFound
    case keyNotFound
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to SSH server"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .commandFailed(let reason):
            return "Command failed: \(reason)"
        case .sessionCreationFailed(let reason):
            return "Session creation failed: \(reason)"
        case .credentialNotFound:
            return "SSH credential not found"
        case .keyNotFound:
            return "SSH key not found"
        }
    }
}