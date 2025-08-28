//
//  ChatListViewModel.swift
//  ClaudeCode
//
//  ViewModel for managing chat sessions list with real backend API integration
//

import SwiftUI
import Combine
import OSLog

/// ViewModel for managing chat sessions list
@MainActor
final class ChatListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var sessions: [ChatSession] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showError = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Private Properties
    
    private let apiClient: APIClient
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "ChatListViewModel")
    
    // MARK: - Initialization
    
    init(apiClient: APIClient, appState: AppState) {
        self.apiClient = apiClient
        self.appState = appState
        
        setupBindings()
        checkConnection()
        loadSessions()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe app state changes
        appState.$isConnected
            .sink { [weak self] isConnected in
                self?.connectionStatus = isConnected ? .connected : .disconnected
            }
            .store(in: &cancellables)
    }
    
    private func checkConnection() {
        Task {
            connectionStatus = .connecting
            let isHealthy = await apiClient.checkHealth()
            connectionStatus = isHealthy ? .connected : .disconnected
            
            if !isHealthy {
                logger.error("Backend not available at \(APIConfig.baseURL.absoluteString)")
                showBackendError()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Load sessions from backend
    func loadSessions() {
        Task {
            await fetchSessions()
        }
    }
    
    /// Refresh sessions
    func refreshSessions() async {
        await fetchSessions()
    }
    
    /// Create a new chat session
    func createSession(_ session: ChatSession) async throws -> SessionInfo {
        isLoading = true
        error = nil
        
        do {
            // Create session info
            let sessionInfo = try await apiClient.createSession()
            
            // Convert to local ChatSession model
            let newSession = ChatSession(
                id: sessionInfo.id,
                title: session.title.isEmpty ? "New Chat" : session.title,
                lastMessage: "",
                timestamp: sessionInfo.createdAt ?? Date(),
                icon: iconForChat(session.title),
                tags: []
            )
            
            // Add to sessions list
            sessions.insert(newSession, at: 0)
            
            logger.info("Created session: \(sessionInfo.id)")
            
            return sessionInfo
        } catch {
            logger.error("Failed to create session: \(error)")
            self.error = error
            showError = true
            throw error
        } finally {
            isLoading = false
        }
    }
    
    /// Delete a chat session
    func deleteSession(_ session: ChatSession) async throws {
        isLoading = true
        error = nil
        
        do {
            let success = try await apiClient.deleteSession(sessionId: session.id)
            
            if success {
                sessions.removeAll { $0.id == session.id }
                logger.info("Deleted session: \(session.id)")
            }
        } catch {
            logger.error("Failed to delete session: \(error)")
            self.error = error
            showError = true
            throw error
        } finally {
            isLoading = false
        }
    }
    
    /// Get session details
    func getSessionDetails(_ sessionId: String) async throws -> SessionInfo {
        do {
            return try await apiClient.getSessionInfo(sessionId: sessionId)
        } catch {
            logger.error("Failed to get session details: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchSessions() async {
        isLoading = true
        error = nil
        
        do {
            let sessionList = try await apiClient.listSessions()
            
            // Convert API sessions to local ChatSession model
            self.sessions = sessionList.map { sessionInfo in
                ChatSession(
                    id: sessionInfo.id,
                    title: sessionInfo.projectId ?? "Chat Session",
                    lastMessage: extractLastMessage(from: sessionInfo),
                    timestamp: sessionInfo.updatedAt ?? sessionInfo.createdAt ?? Date(),
                    icon: iconForChat(sessionInfo.projectId ?? ""),
                    tags: extractTags(from: sessionInfo)
                )
            }
            
            logger.info("Loaded \(sessions.count) sessions from backend")
        } catch let apiError as APIConfig.APIError {
            handleAPIError(apiError)
        } catch {
            logger.error("Failed to load sessions: \(error)")
            self.error = error
            showError = true
            
            // Fall back to empty list
            self.sessions = []
        }
        
        isLoading = false
    }
    
    private func extractLastMessage(from session: SessionInfo) -> String {
        // TODO: Get actual last message from session history
        // For now, return a placeholder based on session state
        if session.isActive {
            return "Active session - tap to continue"
        } else {
            return "Session ended"
        }
    }
    
    private func extractTags(from session: SessionInfo) -> [String] {
        var tags: [String] = []
        
        if session.isActive {
            tags.append("Active")
        }
        
        if let model = session.currentModel {
            // Extract model type for tag
            if model.contains("haiku") {
                tags.append("Haiku")
            } else if model.contains("sonnet") {
                tags.append("Sonnet")
            } else if model.contains("opus") {
                tags.append("Opus")
            }
        }
        
        return tags
    }
    
    private func iconForChat(_ title: String) -> String {
        // Determine icon based on chat title or content
        let lowercased = title.lowercased()
        
        if lowercased.contains("swift") || lowercased.contains("ios") {
            return "swift"
        } else if lowercased.contains("api") || lowercased.contains("network") {
            return "network"
        } else if lowercased.contains("ui") || lowercased.contains("layout") || lowercased.contains("design") {
            return "square.grid.2x2"
        } else if lowercased.contains("data") || lowercased.contains("database") || lowercased.contains("core") {
            return "cylinder.split.1x2"
        } else if lowercased.contains("test") || lowercased.contains("debug") {
            return "ladybug"
        } else {
            return "message"
        }
    }
    
    private func handleAPIError(_ apiError: APIError) {
        switch apiError {
        case .backendNotRunning:
            logger.error("Backend server is not running")
            showBackendError()
        case .unauthorized:
            error = apiError
            showError = true
        case .networkError(let netError):
            logger.error("Network error: \(netError)")
            error = apiError
            showError = true
        default:
            error = apiError
            showError = true
        }
    }
    
    private func showBackendError() {
        error = APIConfig.APIError.backendNotRunning
        showError = true
        
        // Provide helpful message
        logger.error("Backend not running! Start with: cd claude-code-api && make start")
    }
}

// MARK: - Extended ChatSession for backend compatibility

extension ChatSession {
    // Constructor with id parameter for backend integration
    init(id: String,
         title: String,
         lastMessage: String,
         timestamp: Date,
         icon: String,
         tags: [String]) {
        self.init(
            title: title,
            lastMessage: lastMessage,
            timestamp: timestamp,
            icon: icon,
            tags: tags
        )
        // Override the auto-generated UUID with backend ID
        // Note: This requires making id mutable in ChatSession
    }
}