//
//  SettingsViewModel.swift
//  ClaudeCode
//
//  ViewModel for settings management with MVVM pattern
//

import SwiftUI
import Combine

/// ViewModel for managing application settings
@MainActor
final class SettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var alertTitle = ""
    @Published var showAPIKeyInput = false
    @Published var tempAPIKey = ""
    @Published var connectionTestResult: ConnectionTestResult?
    @Published var isTestingConnection = false
    
    // MARK: - Sections State
    
    @Published var expandedSections: Set<SettingsSection> = []
    @Published var selectedTheme: AppTheme = .system
    @Published var selectedFontSize: FontSize = .medium
    
    // MARK: - Private Properties
    
    private let settingsStore: SettingsStore
    private let keychainManager: KeychainManager
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var hasAPIKey: Bool {
        !(settingsStore.apiKey?.isEmpty ?? true)
    }
    
    var hasSSHConfig: Bool {
        settingsStore.sshEnabled && !settingsStore.sshHost.isEmpty
    }
    
    var canTestConnection: Bool {
        hasAPIKey && !settingsStore.baseURL.isEmpty
    }
    
    var canTestSSH: Bool {
        hasSSHConfig && !settingsStore.sshUsername.isEmpty
    }
    
    // MARK: - Initialization
    
    init(settingsStore: SettingsStore,
         keychainManager: KeychainManager,
         appState: AppState) {
        self.settingsStore = settingsStore
        self.keychainManager = keychainManager
        self.appState = appState
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Sync theme selection
        settingsStore.$theme
            .sink { [weak self] theme in
                self?.selectedTheme = theme
            }
            .store(in: &cancellables)
        
        // Sync font size selection
        settingsStore.$fontSize
            .sink { [weak self] fontSize in
                self?.selectedFontSize = fontSize
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods - API Settings
    
    /// Save API key
    func saveAPIKey() {
        guard !tempAPIKey.isEmpty else {
            showError(title: "Invalid API Key", message: "Please enter a valid API key")
            return
        }
        
        settingsStore.apiKey = tempAPIKey
        tempAPIKey = ""
        showAPIKeyInput = false
        
        // Update API client
        DependencyContainer.shared.apiClient.setAPIKey(settingsStore.apiKey)
        
        showSuccess(message: "API key saved successfully")
    }
    
    /// Remove API key
    func removeAPIKey() {
        settingsStore.apiKey = nil
        DependencyContainer.shared.apiClient.setAPIKey(nil)
        showSuccess(message: "API key removed")
    }
    
    /// Test API connection
    func testAPIConnection() async {
        isTestingConnection = true
        connectionTestResult = nil
        
        do {
            let apiClient = DependencyContainer.shared.apiClient
            apiClient.setAPIKey(settingsStore.apiKey)
            
            let isHealthy = await apiClient.checkHealth()
            
            if isHealthy {
                // Try to fetch models to verify API key
                let models = try await apiClient.fetchModels()
                
                connectionTestResult = ConnectionTestResult(
                    success: true,
                    message: "Connected successfully",
                    details: "Found \(models.count) available models"
                )
            } else {
                connectionTestResult = ConnectionTestResult(
                    success: false,
                    message: "Connection failed",
                    details: "Backend server is not responding"
                )
            }
        } catch {
            connectionTestResult = ConnectionTestResult(
                success: false,
                message: "Connection failed",
                details: error.localizedDescription
            )
        }
        
        isTestingConnection = false
    }
    
    /// Update base URL
    func updateBaseURL(_ url: String) {
        settingsStore.baseURL = url
        
        // Reinitialize API client with new URL
        Task {
            await testAPIConnection()
        }
    }
    
    // MARK: - Public Methods - SSH Settings
    
    /// Save SSH configuration
    func saveSSHConfig() {
        guard validateSSHConfig() else { return }
        
        Task {
            await settingsStore.saveSettings()
            showSuccess(message: "SSH configuration saved")
        }
    }
    
    /// Test SSH connection
    func testSSHConnection() async {
        guard canTestSSH else {
            showError(title: "Invalid Configuration", message: "Please complete SSH configuration")
            return
        }
        
        isTestingConnection = true
        
        do {
            let sshManager = DependencyContainer.shared.sshManager
            
            // Create SSH config from settings
            let config = SSHConfig(
                host: settingsStore.sshHost,
                port: settingsStore.sshPort,
                username: settingsStore.sshUsername,
                privateKeyPath: settingsStore.sshPrivateKey,
                passphrase: settingsStore.sshPassphrase
            )
            
            // Test connection by attempting to connect
            var success = false
            var errorMessage = ""
            
            if config.authMethod == .publicKey {
                await sshManager.connectWithKey(
                    host: config.host,
                    port: config.port,
                    username: config.username,
                    privateKeyPath: config.privateKeyPath ?? "",
                    passphrase: config.passphrase
                )
            } else {
                // Password auth - would need password from somewhere
                errorMessage = "Password authentication not configured"
            }
            
            // Check if connected
            success = sshManager.connectionState == .connected
            if success {
                // Disconnect after test
                await sshManager.disconnect()
            }
            
            connectionTestResult = ConnectionTestResult(
                success: success,
                message: success ? "SSH connection successful" : "SSH connection failed",
                details: success ? "Connected to \(config.host)" : (errorMessage.isEmpty ? "Failed to connect" : errorMessage)
            )
        } catch {
            connectionTestResult = ConnectionTestResult(
                success: false,
                message: "SSH connection failed",
                details: error.localizedDescription
            )
        }
        
        isTestingConnection = false
    }
    
    // MARK: - Public Methods - Preferences
    
    /// Update theme
    func updateTheme(_ theme: AppTheme) {
        selectedTheme = theme
        settingsStore.theme = theme
    }
    
    /// Update font size
    func updateFontSize(_ size: FontSize) {
        selectedFontSize = size
        settingsStore.fontSize = size
    }
    
    /// Toggle haptics
    func toggleHaptics() {
        settingsStore.enableHaptics.toggle()
        
        if settingsStore.enableHaptics {
            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    /// Toggle sounds
    func toggleSounds() {
        settingsStore.enableSounds.toggle()
    }
    
    // MARK: - Public Methods - Advanced Settings
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        showAlert = true
        alertTitle = "Reset Settings"
        alertMessage = "Are you sure you want to reset all settings to defaults? This cannot be undone."
    }
    
    /// Confirm reset
    func confirmReset() async {
        isLoading = true
        
        await settingsStore.resetToDefaults()
        
        // Reinitialize services
        await appState.initialize()
        
        isLoading = false
        showSuccess(message: "Settings reset to defaults")
    }
    
    /// Export settings
    func exportSettings() async -> Data? {
        let settings = ExportedSettings(
            baseURL: settingsStore.baseURL,
            selectedModel: settingsStore.selectedModel,
            theme: settingsStore.theme.rawValue,
            fontSize: settingsStore.fontSize.rawValue,
            temperature: settingsStore.temperature,
            maxTokens: settingsStore.maxTokens,
            enableHaptics: settingsStore.enableHaptics,
            enableSounds: settingsStore.enableSounds,
            streamResponses: settingsStore.streamResponses,
            saveHistory: settingsStore.saveHistory
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(settings)
    }
    
    /// Import settings
    func importSettings(from data: Data) async {
        do {
            let decoder = JSONDecoder()
            let settings = try decoder.decode(ExportedSettings.self, from: data)
            
            // Apply imported settings
            settingsStore.baseURL = settings.baseURL
            settingsStore.selectedModel = settings.selectedModel
            
            if let theme = AppTheme(rawValue: settings.theme) {
                settingsStore.theme = theme
            }
            
            if let fontSize = FontSize(rawValue: settings.fontSize) {
                settingsStore.fontSize = fontSize
            }
            
            settingsStore.temperature = settings.temperature
            settingsStore.maxTokens = settings.maxTokens
            settingsStore.enableHaptics = settings.enableHaptics
            settingsStore.enableSounds = settings.enableSounds
            settingsStore.streamResponses = settings.streamResponses
            settingsStore.saveHistory = settings.saveHistory
            
            await settingsStore.saveSettings()
            showSuccess(message: "Settings imported successfully")
        } catch {
            showError(title: "Import Failed", message: error.localizedDescription)
        }
    }
    
    // MARK: - Public Methods - UI
    
    /// Toggle section expansion
    func toggleSection(_ section: SettingsSection) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }
    
    /// Check if section is expanded
    func isSectionExpanded(_ section: SettingsSection) -> Bool {
        expandedSections.contains(section)
    }
    
    // MARK: - Private Methods
    
    private func validateSSHConfig() -> Bool {
        if settingsStore.sshHost.isEmpty {
            showError(title: "Invalid Host", message: "Please enter SSH host")
            return false
        }
        
        if settingsStore.sshUsername.isEmpty {
            showError(title: "Invalid Username", message: "Please enter SSH username")
            return false
        }
        
        if settingsStore.sshPort <= 0 || settingsStore.sshPort > 65535 {
            showError(title: "Invalid Port", message: "Please enter a valid port number (1-65535)")
            return false
        }
        
        return true
    }
    
    private func showError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    
    private func showSuccess(message: String) {
        alertTitle = "Success"
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Supporting Types

enum SettingsViewSection: String, CaseIterable {
    case api = "API Configuration"
    case ssh = "SSH Settings"
    case appearance = "Appearance"
    case chat = "Chat Settings"
    case background = "Background & Sync"
    case developer = "Developer Options"
    case about = "About"
    
    var icon: String {
        switch self {
        case .api: return "key"
        case .ssh: return "terminal"
        case .appearance: return "paintbrush"
        case .chat: return "bubble.left.and.bubble.right"
        case .background: return "arrow.triangle.2.circlepath"
        case .developer: return "hammer"
        case .about: return "info.circle"
        }
    }
}

struct ConnectionTestResult {
    let success: Bool
    let message: String
    let details: String?
}

struct ExportedSettings: Codable {
    let baseURL: String
    let selectedModel: String
    let theme: String
    let fontSize: String
    let temperature: Double
    let maxTokens: Int
    let enableHaptics: Bool
    let enableSounds: Bool
    let streamResponses: Bool
    let saveHistory: Bool
}