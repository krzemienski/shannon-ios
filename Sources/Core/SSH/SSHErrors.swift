//
//  SSHErrors.swift
//  ClaudeCode
//
//  Comprehensive SSH error types and handling (Tasks 496-497)
//

import Foundation

/// Comprehensive SSH error types
public enum SSHConnectionError: LocalizedError, Equatable {
    // MARK: - Connection Errors
    case connectionFailed(reason: ConnectionFailureReason)
    case connectionTimeout(seconds: TimeInterval)
    case connectionLost(reason: String)
    case connectionRefused
    case hostUnreachable(host: String)
    case portUnavailable(port: Int)
    case networkUnavailable
    case dnsResolutionFailed(host: String)
    
    // MARK: - Authentication Errors
    case authenticationFailed(reason: AuthenticationFailureReason)
    case invalidCredentials
    case passwordRequired
    case passphraseRequired
    case keyNotFound(path: String)
    case keyLoadFailed(reason: String)
    case unsupportedAuthMethod(method: String)
    case tooManyAuthAttempts(maxAttempts: Int)
    case publicKeyRejected
    case hostKeyVerificationFailed(reason: HostKeyFailureReason)
    
    // MARK: - Session Errors
    case sessionCreationFailed(reason: String)
    case sessionTimeout
    case sessionClosed
    case channelOpenFailed(type: String)
    case channelClosedUnexpectedly
    case executionFailed(command: String, exitCode: Int?)
    
    // MARK: - File Transfer Errors
    case fileTransferFailed(reason: FileTransferFailureReason)
    case fileNotFound(path: String)
    case permissionDenied(path: String)
    case diskFull
    case quotaExceeded
    case invalidPath(path: String)
    case directoryNotEmpty(path: String)
    case fileAlreadyExists(path: String)
    
    // MARK: - Port Forwarding Errors
    case portForwardingFailed(reason: PortForwardingFailureReason)
    case localPortInUse(port: Int)
    case remotePortUnavailable(port: Int)
    case forwardingNotPermitted
    
    // MARK: - Protocol Errors
    case protocolError(reason: String)
    case unsupportedProtocolVersion(version: String)
    case invalidPacket(description: String)
    case checksumMismatch
    case compressionError(reason: String)
    case encryptionError(reason: String)
    case decryptionError(reason: String)
    
    // MARK: - Configuration Errors
    case configurationError(reason: ConfigurationFailureReason)
    case invalidConfiguration(key: String, value: String)
    case missingConfiguration(key: String)
    case configParseError(line: Int, error: String)
    
    // MARK: - Resource Errors
    case resourceUnavailable(resource: String)
    case memoryAllocationFailed
    case tooManyConnections(max: Int)
    case quotaLimitReached(limit: String)
    
    // MARK: - Timeout Errors
    case operationTimeout(operation: String, timeout: TimeInterval)
    case keepAliveTimeout
    case idleTimeout(seconds: TimeInterval)
    
    // MARK: - General Errors
    case unknown(description: String)
    case internalError(reason: String)
    case notImplemented(feature: String)
    case cancelled
    
    // MARK: - LocalizedError
    
    public var errorDescription: String? {
        switch self {
        // Connection Errors
        case .connectionFailed(let reason):
            return "Connection failed: \(reason.description)"
        case .connectionTimeout(let seconds):
            return "Connection timed out after \(Int(seconds)) seconds"
        case .connectionLost(let reason):
            return "Connection lost: \(reason)"
        case .connectionRefused:
            return "Connection refused by server"
        case .hostUnreachable(let host):
            return "Host unreachable: \(host)"
        case .portUnavailable(let port):
            return "Port \(port) is not available"
        case .networkUnavailable:
            return "Network is unavailable"
        case .dnsResolutionFailed(let host):
            return "Failed to resolve hostname: \(host)"
            
        // Authentication Errors
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason.description)"
        case .invalidCredentials:
            return "Invalid username or password"
        case .passwordRequired:
            return "Password is required"
        case .passphraseRequired:
            return "Passphrase is required for private key"
        case .keyNotFound(let path):
            return "Private key not found: \(path)"
        case .keyLoadFailed(let reason):
            return "Failed to load private key: \(reason)"
        case .unsupportedAuthMethod(let method):
            return "Unsupported authentication method: \(method)"
        case .tooManyAuthAttempts(let max):
            return "Too many authentication attempts (max: \(max))"
        case .publicKeyRejected:
            return "Public key was rejected by server"
        case .hostKeyVerificationFailed(let reason):
            return "Host key verification failed: \(reason.description)"
            
        // Session Errors
        case .sessionCreationFailed(let reason):
            return "Failed to create session: \(reason)"
        case .sessionTimeout:
            return "Session timed out"
        case .sessionClosed:
            return "Session has been closed"
        case .channelOpenFailed(let type):
            return "Failed to open channel: \(type)"
        case .channelClosedUnexpectedly:
            return "Channel closed unexpectedly"
        case .executionFailed(let command, let exitCode):
            if let code = exitCode {
                return "Command failed with exit code \(code): \(command)"
            } else {
                return "Command execution failed: \(command)"
            }
            
        // File Transfer Errors
        case .fileTransferFailed(let reason):
            return "File transfer failed: \(reason.description)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .diskFull:
            return "Disk is full"
        case .quotaExceeded:
            return "Quota exceeded"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .directoryNotEmpty(let path):
            return "Directory is not empty: \(path)"
        case .fileAlreadyExists(let path):
            return "File already exists: \(path)"
            
        // Port Forwarding Errors
        case .portForwardingFailed(let reason):
            return "Port forwarding failed: \(reason.description)"
        case .localPortInUse(let port):
            return "Local port \(port) is already in use"
        case .remotePortUnavailable(let port):
            return "Remote port \(port) is not available"
        case .forwardingNotPermitted:
            return "Port forwarding is not permitted"
            
        // Protocol Errors
        case .protocolError(let reason):
            return "Protocol error: \(reason)"
        case .unsupportedProtocolVersion(let version):
            return "Unsupported protocol version: \(version)"
        case .invalidPacket(let description):
            return "Invalid packet: \(description)"
        case .checksumMismatch:
            return "Checksum mismatch"
        case .compressionError(let reason):
            return "Compression error: \(reason)"
        case .encryptionError(let reason):
            return "Encryption error: \(reason)"
        case .decryptionError(let reason):
            return "Decryption error: \(reason)"
            
        // Configuration Errors
        case .configurationError(let reason):
            return "Configuration error: \(reason.description)"
        case .invalidConfiguration(let key, let value):
            return "Invalid configuration: \(key) = \(value)"
        case .missingConfiguration(let key):
            return "Missing required configuration: \(key)"
        case .configParseError(let line, let error):
            return "Configuration parse error at line \(line): \(error)"
            
        // Resource Errors
        case .resourceUnavailable(let resource):
            return "Resource unavailable: \(resource)"
        case .memoryAllocationFailed:
            return "Memory allocation failed"
        case .tooManyConnections(let max):
            return "Too many connections (max: \(max))"
        case .quotaLimitReached(let limit):
            return "Quota limit reached: \(limit)"
            
        // Timeout Errors
        case .operationTimeout(let operation, let timeout):
            return "\(operation) timed out after \(Int(timeout)) seconds"
        case .keepAliveTimeout:
            return "Keep-alive timeout"
        case .idleTimeout(let seconds):
            return "Idle timeout after \(Int(seconds)) seconds"
            
        // General Errors
        case .unknown(let description):
            return "Unknown error: \(description)"
        case .internalError(let reason):
            return "Internal error: \(reason)"
        case .notImplemented(let feature):
            return "Feature not implemented: \(feature)"
        case .cancelled:
            return "Operation was cancelled"
        }
    }
    
    public var failureReason: String? {
        errorDescription
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .connectionFailed:
            return "Check your network connection and server address"
        case .connectionTimeout:
            return "Try increasing the connection timeout or check network latency"
        case .invalidCredentials:
            return "Verify your username and password are correct"
        case .keyNotFound:
            return "Ensure the private key file exists and has correct permissions"
        case .hostKeyVerificationFailed:
            return "Verify the server's host key or update known_hosts file"
        case .permissionDenied:
            return "Check file permissions and user access rights"
        case .localPortInUse:
            return "Choose a different local port or stop the conflicting service"
        case .networkUnavailable:
            return "Check your internet connection"
        case .tooManyAuthAttempts:
            return "Wait before trying again or contact the server administrator"
        default:
            return nil
        }
    }
}

// MARK: - Failure Reason Types

/// Connection failure reasons
public enum ConnectionFailureReason: CustomStringConvertible, Equatable, Sendable {
    case networkError(String)
    case timeout
    case refused
    case unreachable
    case protocolMismatch
    case tlsError(String)
    case proxyError(String)
    case unknown
    
    public var description: String {
        switch self {
        case .networkError(let error):
            return "Network error: \(error)"
        case .timeout:
            return "Connection timeout"
        case .refused:
            return "Connection refused"
        case .unreachable:
            return "Host unreachable"
        case .protocolMismatch:
            return "Protocol mismatch"
        case .tlsError(let error):
            return "TLS error: \(error)"
        case .proxyError(let error):
            return "Proxy error: \(error)"
        case .unknown:
            return "Unknown connection error"
        }
    }
}

/// Authentication failure reasons
public enum AuthenticationFailureReason: CustomStringConvertible, Equatable, Sendable {
    case invalidPassword
    case invalidKey
    case keyRejected
    case methodNotSupported(String)
    case tooManyAttempts
    case accountLocked
    case expired
    case cancelled
    
    public var description: String {
        switch self {
        case .invalidPassword:
            return "Invalid password"
        case .invalidKey:
            return "Invalid private key"
        case .keyRejected:
            return "Key rejected by server"
        case .methodNotSupported(let method):
            return "Method not supported: \(method)"
        case .tooManyAttempts:
            return "Too many attempts"
        case .accountLocked:
            return "Account is locked"
        case .expired:
            return "Credentials expired"
        case .cancelled:
            return "Authentication cancelled"
        }
    }
}

/// Host key failure reasons
public enum HostKeyFailureReason: CustomStringConvertible, Equatable, Sendable {
    case unknown
    case changed(previous: String, current: String)
    case invalid
    case mismatch
    case notTrusted
    
    public var description: String {
        switch self {
        case .unknown:
            return "Unknown host key"
        case .changed:
            return "Host key has changed"
        case .invalid:
            return "Invalid host key"
        case .mismatch:
            return "Host key mismatch"
        case .notTrusted:
            return "Host key not trusted"
        }
    }
}

/// File transfer failure reasons
public enum FileTransferFailureReason: CustomStringConvertible, Equatable, Sendable {
    case connectionLost
    case permissionDenied
    case fileNotFound
    case diskFull
    case quotaExceeded
    case checksumMismatch
    case cancelled
    case timeout
    
    public var description: String {
        switch self {
        case .connectionLost:
            return "Connection lost during transfer"
        case .permissionDenied:
            return "Permission denied"
        case .fileNotFound:
            return "File not found"
        case .diskFull:
            return "Disk is full"
        case .quotaExceeded:
            return "Quota exceeded"
        case .checksumMismatch:
            return "Checksum mismatch"
        case .cancelled:
            return "Transfer cancelled"
        case .timeout:
            return "Transfer timeout"
        }
    }
}

/// Port forwarding failure reasons
public enum PortForwardingFailureReason: CustomStringConvertible, Equatable, Sendable {
    case portInUse(Int)
    case permissionDenied
    case connectionFailed
    case notSupported
    case administrativelyProhibited
    
    public var description: String {
        switch self {
        case .portInUse(let port):
            return "Port \(port) is in use"
        case .permissionDenied:
            return "Permission denied"
        case .connectionFailed:
            return "Connection failed"
        case .notSupported:
            return "Not supported by server"
        case .administrativelyProhibited:
            return "Administratively prohibited"
        }
    }
}

/// Configuration failure reasons
public enum ConfigurationFailureReason: CustomStringConvertible, Equatable, Sendable {
    case invalid(key: String)
    case missing(key: String)
    case parseError(String)
    case incompatible
    case fileNotFound(String)
    
    public var description: String {
        switch self {
        case .invalid(let key):
            return "Invalid configuration: \(key)"
        case .missing(let key):
            return "Missing configuration: \(key)"
        case .parseError(let error):
            return "Parse error: \(error)"
        case .incompatible:
            return "Incompatible configuration"
        case .fileNotFound(let file):
            return "Configuration file not found: \(file)"
        }
    }
}

// MARK: - Error Recovery

/// SSH error recovery strategies
public enum ErrorRecoveryStrategy {
    case retry(delay: TimeInterval, maxAttempts: Int)
    case reconnect
    case reauthenticate
    case updateConfiguration
    case fallbackMethod(String)
    case userIntervention(String)
    case abort
}

/// SSH error handler protocol
public protocol SSHErrorHandler {
    func handle(_ error: SSHConnectionError) -> ErrorRecoveryStrategy
    func shouldRetry(for error: SSHConnectionError, attempt: Int) -> Bool
    func logError(_ error: SSHConnectionError, context: String?)
}

/// Default SSH error handler
public class DefaultSSHErrorHandler: SSHErrorHandler {
    public func handle(_ error: SSHConnectionError) -> ErrorRecoveryStrategy {
        switch error {
        case .connectionTimeout, .connectionLost:
            return .retry(delay: 2.0, maxAttempts: 3)
        case .authenticationFailed(.invalidPassword):
            return .reauthenticate
        case .hostKeyVerificationFailed(.changed):
            return .userIntervention("Host key has changed. Please verify the server identity.")
        case .networkUnavailable:
            return .retry(delay: 5.0, maxAttempts: 5)
        case .sessionTimeout, .idleTimeout:
            return .reconnect
        default:
            return .abort
        }
    }
    
    public func shouldRetry(for error: SSHConnectionError, attempt: Int) -> Bool {
        switch error {
        case .connectionTimeout, .connectionLost, .networkUnavailable:
            return attempt < 3
        case .operationTimeout:
            return attempt < 2
        default:
            return false
        }
    }
    
    public func logError(_ error: SSHConnectionError, context: String?) {
        let contextString = context.map { " [\($0)]" } ?? ""
        print("SSH Error\(contextString): \(error.localizedDescription)")
    }
}