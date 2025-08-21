//
//  DependencyContainer.swift
//  ClaudeCode
//
//  Centralized dependency injection container for the application
//

import SwiftUI
import Combine

/// Main dependency injection container for the application
/// Provides centralized management of services and dependencies
@MainActor
final class DependencyContainer: ObservableObject {
    
    // MARK: - Singleton
    static let shared = DependencyContainer()
    
    // MARK: - Core Services
    private(set) lazy var appState = AppState()
    private(set) lazy var keychainManager = KeychainManager.shared
    private(set) lazy var apiClient = APIClient()
    private(set) lazy var sshManager = SSHManager()
    private(set) lazy var settingsStore = SettingsStore()
    private(set) lazy var chatStore = ChatStore(apiClient: apiClient)
    private(set) lazy var projectStore = ProjectStore()
    private(set) lazy var toolStore = ToolStore()
    private(set) lazy var monitorStore = MonitorStore(sshManager: sshManager)
    
    // MARK: - View Models
    private var viewModels: [String: Any] = [:]
    private let viewModelQueue = DispatchQueue(label: "com.claudecode.viewmodels", attributes: .concurrent)
    
    // MARK: - Initialization
    private init() {
        setupServices()
        observeAppLifecycle()
    }
    
    // MARK: - Setup
    
    private func setupServices() {
        // Initialize core services
        Task {
            await initializeServices()
        }
    }
    
    private func initializeServices() async {
        // Load saved settings
        await settingsStore.loadSettings()
        
        // Configure API client with saved credentials
        if let apiKey = await settingsStore.apiKey {
            apiClient.setAPIKey(apiKey)
        }
        
        // Initialize app state
        await appState.initialize()
        
        // Setup SSH manager if enabled
        if settingsStore.sshEnabled {
            await sshManager.initialize()
        }
    }
    
    // MARK: - View Model Management
    
    /// Register a view model for reuse
    func register<T: ObservableObject>(_ viewModel: T, for key: String) {
        viewModelQueue.async(flags: .barrier) {
            self.viewModels[key] = viewModel
        }
    }
    
    /// Retrieve a registered view model
    func resolve<T: ObservableObject>(_ type: T.Type, for key: String) -> T? {
        viewModelQueue.sync {
            viewModels[key] as? T
        }
    }
    
    /// Create or retrieve a view model
    func viewModel<T: ObservableObject>(_ type: T.Type, key: String, factory: () -> T) -> T {
        if let existing = resolve(type, for: key) {
            return existing
        }
        
        let newViewModel = factory()
        register(newViewModel, for: key)
        return newViewModel
    }
    
    // MARK: - Factory Methods
    
    /// Create a new ChatViewModel
    func makeChatViewModel(conversationId: String? = nil) -> ChatViewModel {
        ChatViewModel(
            conversationId: conversationId,
            chatStore: chatStore,
            apiClient: apiClient,
            appState: appState
        )
    }
    
    /// Create a new ProjectViewModel
    func makeProjectViewModel(projectId: String? = nil) -> ProjectViewModel {
        ProjectViewModel(
            projectId: projectId,
            projectStore: projectStore,
            sshManager: sshManager,
            appState: appState
        )
    }
    
    /// Create a new SettingsViewModel
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            settingsStore: settingsStore,
            keychainManager: keychainManager,
            appState: appState
        )
    }
    
    /// Create a new MonitorViewModel
    func makeMonitorViewModel() -> MonitorViewModel {
        MonitorViewModel(
            monitorStore: monitorStore,
            sshManager: sshManager,
            appState: appState
        )
    }
    
    /// Create a new ToolsViewModel
    func makeToolsViewModel() -> ToolsViewModel {
        ToolsViewModel(
            toolStore: toolStore,
            apiClient: apiClient,
            appState: appState
        )
    }
    
    // MARK: - Lifecycle Management
    
    private func observeAppLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.handleAppWillEnterForeground()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.handleAppDidEnterBackground()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleAppWillEnterForeground() async {
        // Refresh services when app comes to foreground
        await appState.resumeOperations()
        
        // Refresh API health if connected
        if appState.isConnected {
            await apiClient.checkHealth()
        }
    }
    
    private func handleAppDidEnterBackground() async {
        // Save state when app goes to background
        await appState.saveState()
        await settingsStore.saveSettings()
        await chatStore.savePendingChanges()
    }
    
    // MARK: - Cleanup
    
    func cleanup() async {
        // Save all pending changes
        await appState.saveState()
        await settingsStore.saveSettings()
        await chatStore.savePendingChanges()
        await projectStore.savePendingChanges()
        
        // Cleanup services
        await sshManager.disconnect()
        apiClient.cancelAllRequests()
        
        // Clear view models
        viewModelQueue.async(flags: .barrier) {
            self.viewModels.removeAll()
        }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Environment Key

struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Inject the dependency container into the environment
    func withDependencyContainer(_ container: DependencyContainer = .shared) -> some View {
        self.environment(\.dependencyContainer, container)
    }
}