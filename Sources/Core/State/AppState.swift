//
//  AppState.swift
//  ClaudeCode
//
//  Global application state management
//

import SwiftUI
import Combine
import BackgroundTasks

/// Global application state manager
@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties (Original)
    @Published var selectedChatId: String?
    @Published var selectedProjectId: String?
    @Published var isConnected: Bool = false
    @Published var currentModel: String = "claude-3-5-haiku-20241022"
    @Published var apiKey: String = ""
    @Published var baseURL: String = "http://localhost:8000/v1"
    
    // MARK: - Published Properties (Enhanced)
    @Published var isActive = true
    @Published var isInitialized = false
    @Published var isLoading = false
    @Published var error: AppError?
    @Published var apiHealth: APIHealth?
    @Published var isFirstLaunch = false
    @Published var isAuthenticated = true // Default to true for now
    
    // Selection State
    @Published var selectedToolId: String?
    @Published var selectedMonitorId: String?
    @Published var selectedSettingPath: String?
    @Published var apiHealthy = false
    
    // WebSocket Connection Status
    @Published var webSocketConnected = false
    @Published var webSocketReconnecting = false
    
    // MARK: - Settings
    @AppStorage("enableTelemetry") var enableTelemetry = true
    @AppStorage("enableBackgroundRefresh") var enableBackgroundRefresh = true
    @AppStorage("sshMonitoringEnabled") var sshMonitoringEnabled = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let webSocketService = WebSocketService.shared
    
    // MARK: - Initialization
    init() {
        setupObservers()
        loadSavedState()
        checkFirstLaunch()
        setupWebSocketObservers()
    }
    
    // MARK: - Public Methods
    
    /// Initialize app state on launch
    func initialize() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Check API health
            await checkAPIHealth()
            
            // Load user preferences
            loadUserPreferences()
            
            // Initialize WebSocket connection
            await initializeWebSocket()
            
            isInitialized = true
            print("AppState initialized successfully")
            
        } catch {
            self.error = AppError.initialization(error.localizedDescription)
            print("AppState initialization failed: \(error)")
        }
    }
    
    /// Resume operations when app becomes active
    func resumeOperations() async {
        // Refresh API health
        await checkAPIHealth()
        
        // Resume any paused SSE connections
        NotificationCenter.default.post(name: .resumeSSEConnections, object: nil)
        
        // Reconnect WebSocket if needed
        if !webSocketConnected {
            await initializeWebSocket()
        }
    }
    
    /// Save current app state
    func saveState() async {
        // Save current IDs
        userDefaults.set(selectedChatId, forKey: "selectedChatId")
        userDefaults.set(selectedProjectId, forKey: "selectedProjectId")
        userDefaults.set(currentModel, forKey: "currentModel")
        userDefaults.set(baseURL, forKey: "baseURL")
        userDefaults.synchronize()
        print("AppState saved successfully")
    }
    
    /// Sync telemetry data in background
    func syncTelemetry() async {
        guard enableTelemetry else { return }
        
        // TODO: Implement telemetry sync
        print("Syncing telemetry data...")
    }
    
    /// Check API health status
    func checkAPIHealth() async {
        do {
            // TODO: Implement actual API health check
            // For now, create a mock health status
            apiHealth = APIHealth(
                status: "healthy",
                version: "1.0.0",
                timestamp: Date(),
                services: [:]
            )
            isConnected = true
        } catch {
            apiHealth = APIHealth(
                status: "unhealthy",
                version: "unknown",
                timestamp: Date(),
                services: [:]
            )
            isConnected = false
        }
    }
    
    /// Complete onboarding process
    func completeOnboarding() async {
        hasCompletedOnboarding = true
        isFirstLaunch = false
        userDefaults.set(true, forKey: "hasCompletedOnboarding")
    }
    
    /// Refresh authentication status
    func refreshAuthenticationStatus() async {
        // Check if API key is valid
        if !apiKey.isEmpty {
            isAuthenticated = true
        } else {
            // Check keychain for stored credentials
            if let storedKey = try? await KeychainManager.shared.getAPIKey() {
                apiKey = storedKey
                isAuthenticated = true
            } else {
                isAuthenticated = false
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe app lifecycle notifications
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.saveState()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.resumeOperations()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadSavedState() {
        // Load saved IDs
        selectedChatId = userDefaults.string(forKey: "selectedChatId")
        selectedProjectId = userDefaults.string(forKey: "selectedProjectId")
        
        // Load saved settings
        if let savedModel = userDefaults.string(forKey: "currentModel") {
            currentModel = savedModel
        }
        if let savedURL = userDefaults.string(forKey: "baseURL") {
            baseURL = savedURL
        }
    }
    
    private func loadUserPreferences() {
        // Load any additional user preferences
        // This is where we'd load theme preferences, shortcuts, etc.
    }
    
    private func checkFirstLaunch() {
        isFirstLaunch = !hasCompletedOnboarding
    }
    
    // MARK: - WebSocket Methods
    
    private func setupWebSocketObservers() {
        // Observe WebSocket connection state
        webSocketService.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .connected:
                    self?.webSocketConnected = true
                    self?.webSocketReconnecting = false
                    
                case .disconnected:
                    self?.webSocketConnected = false
                    self?.webSocketReconnecting = false
                    
                case .connecting:
                    self?.webSocketReconnecting = true
                    
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to WebSocket events
        subscribeToWebSocketEvents()
    }
    
    private func initializeWebSocket() async {
        // Configure WebSocket with base URL and auth token
        let wsURL = baseURL.replacingOccurrences(of: "/v1", with: "/ws")
        webSocketService.configure(baseURL: wsURL, authToken: apiKey)
        
        do {
            try await webSocketService.connect()
            print("WebSocket connected successfully")
            
            // Subscribe to relevant channels
            if let projectId = selectedProjectId {
                try? await webSocketService.subscribeToProject(projectId)
            }
            
            if let chatId = selectedChatId {
                try? await webSocketService.subscribeToChat(chatId)
            }
            
        } catch {
            print("Failed to connect WebSocket: \(error)")
        }
    }
    
    private func subscribeToWebSocketEvents() {
        // Project updates
        webSocketService.projectUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleProjectUpdate(event)
            }
            .store(in: &cancellables)
        
        // Chat updates
        webSocketService.chatUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleChatUpdate(event)
            }
            .store(in: &cancellables)
        
        // System notifications
        webSocketService.systemNotifications
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleSystemNotification(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleProjectUpdate(_ event: ProjectUpdateEvent) {
        print("Received project update: \(event.action) for \(event.projectId)")
        // Update project state as needed
    }
    
    private func handleChatUpdate(_ event: ChatUpdateEvent) {
        print("Received chat update: \(event.action) for \(event.chatId)")
        // Update chat state as needed
    }
    
    private func handleSystemNotification(_ event: SystemNotificationEvent) {
        print("System notification: \(event.title) - \(event.message)")
        // Show notification to user
    }
    
    /// Subscribe to project updates
    func subscribeToProject(_ projectId: String) async {
        selectedProjectId = projectId
        
        if webSocketConnected {
            try? await webSocketService.subscribeToProject(projectId)
        }
    }
    
    /// Subscribe to chat updates
    func subscribeToChat(_ chatId: String) async {
        selectedChatId = chatId
        
        if webSocketConnected {
            try? await webSocketService.subscribeToChat(chatId)
        }
    }
    
    // MARK: - Missing Methods
    
    func reset() {
        // Reset app state
        selectedChatId = nil
        selectedProjectId = nil
        selectedToolId = nil
        selectedMonitorId = nil
        selectedSettingPath = nil
        
        isInitialized = false
        apiHealthy = false
        webSocketConnected = false
        
        // Clear preferences
        userDefaults.removeObject(forKey: "selectedChatId")
        userDefaults.removeObject(forKey: "selectedProjectId")
        userDefaults.removeObject(forKey: "selectedToolId")
        userDefaults.removeObject(forKey: "selectedMonitorId")
        userDefaults.removeObject(forKey: "selectedSettingPath")
    }
    
    func requestNotificationPermission() async -> Bool {
        // Request notification permission (stub implementation)
        // This would normally integrate with UNUserNotificationCenter
        // For now, return true to indicate success
        return true
    }
}

// MARK: - APIHealth Type
// APIHealth is now defined in APIModels.swift
// ServiceHealth is also defined there

// MARK: - Supporting Types


// MARK: - Notification Names
extension Notification.Name {
    static let resumeSSEConnections = Notification.Name("resumeSSEConnections")
    static let pauseSSEConnections = Notification.Name("pauseSSEConnections")
}