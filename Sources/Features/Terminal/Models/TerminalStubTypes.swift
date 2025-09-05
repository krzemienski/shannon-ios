//
//  TerminalStubTypes.swift
//  ClaudeCode
//
//  MVP: Stub types to resolve compilation errors
//

import Foundation

// MVP: All types have been moved to SSHTerminal.swift to avoid module boundary issues
// This file is kept empty to satisfy the build system
// TODO: Reorganize module structure to have shared types in a common location

// MARK: - SSH Session Manager Extension (Keep this as it's not duplicated)

extension SSHSessionManager {
    public func getService(for sessionId: String) -> TerminalService? {
        // MVP: Return stub service
        return TerminalService()
    }
}

// MVP: Simple stub for TerminalService
public class TerminalService: ObservableObject {
    @Published public var output: String = ""
    @Published public var isConnected: Bool = false
    
    public init() {}
    
    public func connect() async throws {
        // MVP: Stub implementation
        isConnected = true
    }
    
    public func disconnect() {
        // MVP: Stub implementation
        isConnected = false
    }
    
    public func sendCommand(_ command: String) async throws -> String {
        // MVP: Stub implementation
        return "Command executed: \(command)"
    }
}