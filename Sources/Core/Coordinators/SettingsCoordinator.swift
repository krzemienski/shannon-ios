//
//  SettingsCoordinator.swift
//  ClaudeCode
//
//  Coordinator for settings navigation and flow
//

import SwiftUI
import Combine

/// Coordinator managing settings navigation and flow
@MainActor
final class SettingsCoordinator: BaseCoordinator, ObservableObject {
    
    // MARK: - Navigation State
    
    @Published var navigationPath = NavigationPath()
    @Published var selectedSection: SettingsSection = .general
    @Published var isShowingAPIConfig = false
    @Published var isShowingSSHConfig = false
    @Published var isShowingThemeSelector = false
    @Published var isShowingDataManagement = false
    @Published var isTestingConnection = false
    
    // MARK: - Dependencies
    
    weak var appCoordinator: AppCoordinator?
    private let dependencyContainer: DependencyContainer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - View Models
    
    private var settingsViewModel: SettingsViewModel?
    
    // MARK: - Initialization
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        super.init()
    }
    
    // MARK: - Coordinator Lifecycle
    
    override func start() {
        // Load current settings
        Task {
            await dependencyContainer.settingsStore.loadSettings()
        }
    }
    
    // MARK: - Navigation
    
    func selectSection(_ section: SettingsSection) {
        selectedSection = section
        navigationPath.append(SettingsRoute.section(section))
    }
    
    func showAPIConfiguration() {
        isShowingAPIConfig = true
        navigationPath.append(SettingsRoute.apiConfig)
    }
    
    func showSSHConfiguration() {
        isShowingSSHConfig = true
        navigationPath.append(SettingsRoute.sshConfig)
    }
    
    func showThemeSelector() {
        isShowingThemeSelector = true
        navigationPath.append(SettingsRoute.theme)
    }
    
    func showDataManagement() {
        isShowingDataManagement = true
        navigationPath.append(SettingsRoute.dataManagement)
    }
    
    func showAbout() {
        navigationPath.append(SettingsRoute.about)
    }
    
    func showLicenses() {
        navigationPath.append(SettingsRoute.licenses)
    }
    
    // MARK: - API Configuration
    
    func updateAPIConfiguration(apiKey: String, baseURL: String?) {
        Task {
            await dependencyContainer.settingsStore.updateAPIConfiguration(
                apiKey: apiKey,
                baseURL: baseURL
            )
            
            // Update API client
            dependencyContainer.apiClient.setAPIKey(apiKey)
            if let baseURL = baseURL {
                dependencyContainer.apiClient.setBaseURL(baseURL)
            }
        }
    }
    
    func testAPIConnection() async -> Bool {
        isTestingConnection = true
        defer { isTestingConnection = false }
        
        do {
            return try await dependencyContainer.apiClient.testConnection()
        } catch {
            handleSettingsError(error)
            return false
        }
    }
    
    // MARK: - SSH Configuration
    
    func updateSSHConfiguration(config: SSHConfiguration) {
        Task {
            await dependencyContainer.settingsStore.updateSSHConfiguration(config)
        }
    }
    
    func testSSHConnection() async -> Bool {
        isTestingConnection = true
        defer { isTestingConnection = false }
        
        guard let config = dependencyContainer.settingsStore.sshConfiguration else {
            return false
        }
        
        return await dependencyContainer.sshManager.testConnection(config: config)
    }
    
    // MARK: - Theme Management
    
    func selectTheme(_ theme: AppTheme) {
        Task {
            await dependencyContainer.settingsStore.updateTheme(theme)
        }
    }
    
    func updateFontSize(_ size: FontSize) {
        Task {
            await dependencyContainer.settingsStore.updateFontSize(size)
        }
    }
    
    func toggleReduceMotion(_ enabled: Bool) {
        Task {
            await dependencyContainer.settingsStore.toggleReduceMotion(enabled)
        }
    }
    
    // MARK: - Data Management
    
    func exportSettings() async throws -> URL {
        try await dependencyContainer.settingsStore.exportSettings()
    }
    
    func importSettings(from url: URL) async throws {
        try await dependencyContainer.settingsStore.importSettings(from: url)
        
        // Reload UI
        await MainActor.run {
            objectWillChange.send()
        }
    }
    
    func clearAllData() async {
        let alertData = AlertData(
            title: "Clear All Data?",
            message: "This will delete all conversations, projects, and settings. This action cannot be undone.",
            primaryAction: AlertAction(
                title: "Clear",
                style: .destructive,
                handler: { [weak self] in
                    Task {
                        await self?.performClearAllData()
                    }
                }
            ),
            secondaryAction: AlertAction(
                title: "Cancel",
                style: .cancel,
                handler: nil
            )
        )
        appCoordinator?.showAlert(alertData)
    }
    
    private func performClearAllData() async {
        // Clear all stores
        await dependencyContainer.chatStore.clearAll()
        await dependencyContainer.projectStore.clearAll()
        await dependencyContainer.toolStore.clearAll()
        await dependencyContainer.monitorStore.clearAll()
        await dependencyContainer.settingsStore.resetToDefaults()
        
        // Reset app state
        await dependencyContainer.appState.reset()
        
        // Show completion
        let alertData = AlertData(
            title: "Data Cleared",
            message: "All data has been successfully cleared.",
            primaryAction: AlertAction(
                title: "OK",
                style: .default,
                handler: nil
            ),
            secondaryAction: nil
        )
        appCoordinator?.showAlert(alertData)
    }
    
    func clearCache() async {
        await dependencyContainer.apiClient.clearCache()
        await dependencyContainer.toolStore.clearCache()
        
        let alertData = AlertData(
            title: "Cache Cleared",
            message: "All cached data has been cleared.",
            primaryAction: AlertAction(
                title: "OK",
                style: .default,
                handler: nil
            ),
            secondaryAction: nil
        )
        appCoordinator?.showAlert(alertData)
    }
    
    // MARK: - Notifications
    
    func updateNotificationSettings(_ settings: NotificationSettings) {
        Task {
            await dependencyContainer.settingsStore.updateNotificationSettings(settings)
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        await dependencyContainer.appState.requestNotificationPermission()
    }
    
    // MARK: - Privacy
    
    func updatePrivacySettings(_ settings: PrivacySettings) {
        Task {
            await dependencyContainer.settingsStore.updatePrivacySettings(settings)
        }
    }
    
    func toggleAnalytics(_ enabled: Bool) {
        Task {
            await dependencyContainer.settingsStore.toggleAnalytics(enabled)
        }
    }
    
    // MARK: - View Model Management
    
    func getSettingsViewModel() -> SettingsViewModel {
        if let existing = settingsViewModel {
            return existing
        }
        
        let viewModel = dependencyContainer.makeSettingsViewModel()
        settingsViewModel = viewModel
        return viewModel
    }
    
    // MARK: - Error Handling
    
    func handleSettingsError(_ error: Error) {
        appCoordinator?.showError(error)
    }
}

// MARK: - Navigation Routes

enum SettingsRoute: Hashable {
    case section(SettingsSection)
    case apiConfig
    case sshConfig
    case theme
    case dataManagement
    case notifications
    case privacy
    case about
    case licenses
}

// MARK: - Supporting Types

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case api = "API"
    case ssh = "SSH"
    case appearance = "Appearance"
    case data = "Data"
    case notifications = "Notifications"
    case privacy = "Privacy"
    case about = "About"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .api: return "cloud.fill"
        case .ssh: return "terminal.fill"
        case .appearance: return "paintbrush.fill"
        case .data: return "externaldrive.fill"
        case .notifications: return "bell.fill"
        case .privacy: return "lock.fill"
        case .about: return "info.circle.fill"
        }
    }
}

// AppTheme and FontSize are defined in SettingsStore.swift

struct NotificationSettings {
    var enabled: Bool
    var soundEnabled: Bool
    var vibrationEnabled: Bool
    var showPreviews: Bool
    var chatNotifications: Bool
    var toolNotifications: Bool
    var systemNotifications: Bool
}

struct PrivacySettings {
    var analyticsEnabled: Bool
    var crashReportingEnabled: Bool
    var telemetryEnabled: Bool
    var shareUsageData: Bool
}