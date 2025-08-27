//
//  SSHSessionManager.swift
//  ClaudeCode
//
//  SSH session management service
//

import Foundation
import SwiftUI

@MainActor
final class SSHSessionManager: ObservableObject {
    static let shared = SSHSessionManager()
    
    @Published var activeSessions: [SSHSession] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    private init() {}
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    func connect(with config: SSHConfig) async throws {
        connectionStatus = .connecting
        // Implement connection logic
        connectionStatus = .connected
    }
    
    func disconnect() {
        connectionStatus = .disconnected
        activeSessions.removeAll()
    }
    
    func createSession(name: String) -> SSHSession {
        let session = SSHSession(id: UUID().uuidString, name: name)
        activeSessions.append(session)
        return session
    }
}

struct SSHSession: Identifiable {
    let id: String
    let name: String
    var isActive: Bool = false
}