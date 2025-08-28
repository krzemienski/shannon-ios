//
//  SSHManager.swift
//  ClaudeCode
//
//  SSH connection management service
//

import Foundation

/// SSH connection manager
@MainActor
public final class SSHManager: ObservableObject {
    @Published public var isConnected = false
    @Published public var activeSession: SSHSession?
    @Published public var error: Error?
    
    public init() {}
    
    // MARK: - Connection Management
    
    public func connect(config: AppSSHConfig) async throws {
        isConnected = false
        error = nil
        
        // Mock connection - would use Citadel in production
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        activeSession = SSHSession(
            id: UUID().uuidString,
            name: config.name,
            isActive: true
        )
        isConnected = true
    }
    
    public func disconnect() async {
        isConnected = false
        activeSession = nil
        error = nil
    }
    
    public func testConnection(config: AppSSHConfig) async -> Bool {
        do {
            // Mock connection test
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            return true
        } catch {
            self.error = error
            return false
        }
    }
    
    // MARK: - Command Execution
    
    public func executeCommand(_ command: String) async throws -> String {
        guard isConnected else {
            throw SSHError.connectionFailed("Not connected")
        }
        
        // Mock command execution
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 second delay
        return "Mock output for: \(command)"
    }
}