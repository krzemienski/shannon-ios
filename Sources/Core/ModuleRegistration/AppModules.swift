//
//  AppModules.swift
//  ClaudeCode
//
//  Module registration for dependency injection
//

import Foundation

/// Core module for fundamental services
struct CoreModule: ModuleRegistration {
    @MainActor
    func register() {
        let locator = ServiceLocator.shared
        let container = DIContainer.shared
        
        // Register core services
        locator.register(KeychainManager.self, lifetime: .singleton) {
            KeychainManager.shared
        }
        
        locator.register(NetworkMonitor.self, lifetime: .singleton) {
            NetworkMonitor()
        }
        
        locator.register(OfflineQueueManager.self, lifetime: .singleton) {
            OfflineQueueManager()
        }
        
        // Register in DI container as well
        container.registerSingleton(KeychainManager.self) {
            KeychainManager.shared
        }
        
        container.registerSingleton(NetworkMonitor.self) {
            NetworkMonitor()
        }
    }
}

/// API module for network services
struct APIModule: ModuleRegistration {
    @MainActor
    func register() {
        let locator = ServiceLocator.shared
        let container = DIContainer.shared
        
        // Register API services
        locator.register(APIClient.self, lifetime: .singleton) {
            APIClient()
        }
        
        locator.register(SSEClient.self, lifetime: .transient) {
            SSEClient()
        }
        
        locator.register(SSHManager.self, lifetime: .singleton) {
            SSHManager()
        }
        
        // Register in DI container
        container.registerSingleton(APIClient.self) {
            APIClient()
        }
        
        container.register(SSEClient.self) { SSEClient() }
        
        container.registerSingleton(SSHManager.self) {
            SSHManager()
        }
    }
}

/// State module for stores
struct StateModule: ModuleRegistration {
    @MainActor
    func register() {
        let locator = ServiceLocator.shared
        let container = DIContainer.shared
        
        // Register state stores
        locator.register(AppState.self, lifetime: .singleton) {
            AppState()
        }
        
        locator.register(SettingsStore.self, lifetime: .singleton) {
            SettingsStore()
        }
        
        locator.register(ChatStore.self, lifetime: .singleton) {
            let apiClient = locator.resolve(APIClient.self)
            return ChatStore(apiClient: apiClient)
        }
        
        locator.register(ProjectStore.self, lifetime: .singleton) {
            ProjectStore()
        }
        
        locator.register(ToolStore.self, lifetime: .singleton) {
            ToolStore()
        }
        
        locator.register(MonitorStore.self, lifetime: .singleton) {
            let sshManager = locator.resolve(SSHManager.self)
            return MonitorStore(sshManager: sshManager)
        }
        
        // Register in DI container
        container.registerSingleton(AppState.self) { AppState() }
        container.registerSingleton(SettingsStore.self) { SettingsStore() }
        
        container.registerSingleton(ChatStore.self) {
            let apiClient = container.resolve(APIClient.self)
            return ChatStore(apiClient: apiClient)
        }
        
        container.registerSingleton(ProjectStore.self) { ProjectStore() }
        container.registerSingleton(ToolStore.self) { ToolStore() }
        
        container.registerSingleton(MonitorStore.self) {
            let sshManager = container.resolve(SSHManager.self)
            return MonitorStore(sshManager: sshManager)
        }
    }
}

/// ViewModel module
struct ViewModelModule: ModuleRegistration {
    @MainActor
    func register() {
        let container = DIContainer.shared
        
        // Register ViewModel factories
        container.register(ChatViewModel.self) { [container] in
            let chatStore = container.resolve(ChatStore.self)
            let apiClient = container.resolve(APIClient.self)
            let appState = container.resolve(AppState.self)
            return ChatViewModel(
                conversationId: nil,
                chatStore: chatStore,
                apiClient: apiClient,
                appState: appState
            )
        }
        
        container.register(ProjectViewModel.self) { [container] in
            let projectStore = container.resolve(ProjectStore.self)
            let sshManager = container.resolve(SSHManager.self)
            let appState = container.resolve(AppState.self)
            return ProjectViewModel(
                projectId: nil,
                projectStore: projectStore,
                sshManager: sshManager,
                appState: appState
            )
        }
        
        container.register(SettingsViewModel.self) { [container] in
            let settingsStore = container.resolve(SettingsStore.self)
            let keychainManager = container.resolve(KeychainManager.self)
            let appState = container.resolve(AppState.self)
            return SettingsViewModel(
                settingsStore: settingsStore,
                keychainManager: keychainManager,
                appState: appState
            )
        }
        
        container.register(MonitorViewModel.self) { [container] in
            let monitorStore = container.resolve(MonitorStore.self)
            let sshManager = container.resolve(SSHManager.self)
            let appState = container.resolve(AppState.self)
            return MonitorViewModel(
                monitorStore: monitorStore,
                sshManager: sshManager,
                appState: appState
            )
        }
        
        container.register(ToolsViewModel.self) { [container] in
            let toolStore = container.resolve(ToolStore.self)
            let apiClient = container.resolve(APIClient.self)
            let appState = container.resolve(AppState.self)
            return ToolsViewModel(
                toolStore: toolStore,
                apiClient: apiClient,
                appState: appState
            )
        }
    }
}

/// Coordinator module
struct CoordinatorModule: ModuleRegistration {
    @MainActor
    func register() {
        let container = DIContainer.shared
        
        // Register app coordinator
        container.registerSingleton(AppCoordinator.self) {
            AppCoordinator(dependencyContainer: DependencyContainer.shared)
        }
        
        // Register feature coordinators
        container.register(ChatCoordinator.self) { [container] in
            ChatCoordinator(dependencyContainer: DependencyContainer.shared)
        }
        
        container.register(ProjectsCoordinator.self) { [container] in
            ProjectsCoordinator(dependencyContainer: DependencyContainer.shared)
        }
        
        container.register(ToolsCoordinator.self) { [container] in
            ToolsCoordinator(dependencyContainer: DependencyContainer.shared)
        }
        
        container.register(MonitorCoordinator.self) { [container] in
            MonitorCoordinator(dependencyContainer: DependencyContainer.shared)
        }
        
        container.register(SettingsCoordinator.self) { [container] in
            SettingsCoordinator(dependencyContainer: DependencyContainer.shared)
        }
    }
}

/// App module registration
public struct AppModuleRegistration {
    
    /// Register all app modules
    @MainActor
    public static func registerAllModules() {
        let modules: [ModuleRegistration] = [
            CoreModule(),
            APIModule(),
            StateModule(),
            ViewModelModule(),
            CoordinatorModule()
        ]
        
        // Register all modules
        modules.forEach { $0.register() }
    }
    
    /// Reset all registrations
    public static func reset() {
        ServiceLocator.shared.reset()
        DIContainer.shared.reset()
    }
    
    /// Clear instances but keep registrations
    public static func clearInstances() {
        ServiceLocator.shared.clearSingletons()
        DIContainer.shared.clearInstances()
    }
}