//
//  EnhancedTerminalViewModel.swift
//  ClaudeCode
//
//  ViewModel for enhanced terminal functionality
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for enhanced terminal with SSH support
@MainActor
public class EnhancedTerminalViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var activeSession: SSHSession?
    @Published public var secondarySession: SSHSession?
    @Published public var commandHistory: [String] = []
    @Published public var isRecording = false
    @Published public var settings = EnhancedTerminalSettings()
    @Published public var connectionStatusText = "Disconnected"
    @Published public var connectionStatusColor: Color = .gray
    
    // MARK: - Private Properties
    
    private let sessionManager = SSHSessionManager.shared
    private let credentialManager = SSHCredentialManager.shared
    private let projectId: String?
    private var recordingSession: RecordingSession?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(projectId: String? = nil) {
        self.projectId = projectId
        setupBindings()
        loadCommandHistory()
    }
    
    // MARK: - Public Methods
    
    /// Load existing sessions
    public func loadSessions() {
        if let activeId = sessionManager.activeSessionId,
           let session = sessionManager.getSession(by: activeId) {
            activeSession = session
            updateConnectionStatus(for: session)
        }
    }
    
    /// Create and connect a new session
    public func createAndConnectSession(config: SSHConfig) async {
        do {
            let sessionId = try await sessionManager.createSession(
                name: config.name,
                config: config
            )
            
            try await sessionManager.connect(sessionId: sessionId)
            sessionManager.setActiveSession(sessionId)
            
            if let session = sessionManager.getSession(by: sessionId) {
                activeSession = session
            }
        } catch {
            print("Failed to create session: \(error)")
        }
    }
    
    /// Connect to a saved credential
    public func connectToSaved(_ credential: SSHCredential) async {
        let config = SSHConfig(
            name: credential.name,
            host: credential.host,
            port: credential.port,
            username: credential.username,
            authMethod: credential.authMethod
        )
        
        await createAndConnectSession(config: config)
    }
    
    /// Connect to most recent
    public func connectToRecent() async {
        guard let recent = credentialManager.savedCredentials.first else { return }
        await connectToSaved(recent)
    }
    
    /// Send command to active session
    public func sendCommand(_ command: String) {
        guard !command.isEmpty else { return }
        
        // Add to history
        commandHistory.append(command)
        saveCommandHistory()
        
        // Send to active session
        if let sessionId = activeSession?.id,
           let service = sessionManager.getService(for: sessionId) {
            Task {
                do {
                    _ = try await service.executeCommand(command)
                } catch {
                    print("Command execution failed: \(error)")
                }
            }
        }
    }
    
    /// Clear terminal output
    public func clearTerminal() {
        // Implementation depends on terminal emulator
        print("Clear terminal")
    }
    
    /// Toggle recording
    public func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    /// Export session
    public func exportSession() {
        // Export terminal session content
        print("Export session")
    }
    
    /// Share session
    public func shareSession() {
        // Share terminal session
        print("Share session")
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind to session manager
        sessionManager.$activeSessionId
            .compactMap { [weak self] id in
                guard let id = id else { return nil }
                return self?.sessionManager.getSession(by: id)
            }
            .assign(to: &$activeSession)
        
        // Update connection status
        sessionManager.$sessions
            .sink { [weak self] _ in
                self?.updateActiveSessionStatus()
            }
            .store(in: &cancellables)
    }
    
    private func updateActiveSessionStatus() {
        guard let session = activeSession else {
            connectionStatusText = "Disconnected"
            connectionStatusColor = .gray
            return
        }
        
        updateConnectionStatus(for: session)
    }
    
    private func updateConnectionStatus(for session: SSHSession) {
        switch session.status {
        case .disconnected:
            connectionStatusText = "Disconnected"
            connectionStatusColor = .gray
            
        case .connecting:
            connectionStatusText = "Connecting..."
            connectionStatusColor = .orange
            
        case .authenticating:
            connectionStatusText = "Authenticating..."
            connectionStatusColor = .orange
            
        case .connected:
            connectionStatusText = "Connected to \(session.config.host)"
            connectionStatusColor = .green
            
        case .disconnecting:
            connectionStatusText = "Disconnecting..."
            connectionStatusColor = .orange
            
        case .error(let message):
            connectionStatusText = "Error: \(message)"
            connectionStatusColor = .red
        }
    }
    
    private func loadCommandHistory() {
        if let data = UserDefaults.standard.data(forKey: "terminal_command_history"),
           let history = try? JSONDecoder().decode([String].self, from: data) {
            commandHistory = history
        }
    }
    
    private func saveCommandHistory() {
        // Keep last 100 commands
        let recentCommands = Array(commandHistory.suffix(100))
        if let data = try? JSONEncoder().encode(recentCommands) {
            UserDefaults.standard.set(data, forKey: "terminal_command_history")
        }
    }
    
    private func startRecording() {
        recordingSession = RecordingSession(startTime: Date())
        isRecording = true
    }
    
    private func stopRecording() {
        if let session = recordingSession {
            // Save recording
            print("Recording saved: \(session.duration) seconds")
        }
        recordingSession = nil
        isRecording = false
    }
}

// MARK: - Supporting Types

/// Cursor style for enhanced terminal
public enum CursorStyle: String, Codable, CaseIterable {
    case block = "block"
    case underline = "underline"
    case bar = "bar"
}

/// Terminal settings for enhanced terminal
public struct EnhancedTerminalSettings {
    public var fontSize: CGFloat = 14
    public var fontFamily = "SF Mono"
    public var colorScheme = "cyberpunk"
    public var cursorStyle = CursorStyle.block
    public var bellSound = true
    public var scrollbackLines = 10000
    
    public init() {}
}

/// Recording session
public struct RecordingSession {
    public let startTime: Date
    public var events: [TerminalEvent] = []
    
    public init(startTime: Date = Date()) {
        self.startTime = startTime
    }
    
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}

/// Terminal event for recording
public struct TerminalEvent {
    let timestamp: TimeInterval
    let type: EventType
    let data: Data
    
    enum EventType {
        case input
        case output
    }
}