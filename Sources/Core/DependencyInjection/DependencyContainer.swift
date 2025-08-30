//
//  DependencyContainer.swift
//  ClaudeCode
//
//  Unified dependency container for coordinators and view models
//

import Foundation
import SwiftUI

/// Main dependency container for the application
public final class DependencyContainer: ObservableObject, @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = DependencyContainer()
    
    // MARK: - Properties
    
    private let diContainer = DIContainer.shared
    private let serviceLocator = ServiceLocator.shared
    
    // MARK: - Initialization
    
    private init() {
        // Container is initialized through AppModuleRegistration
    }
    
    // MARK: - Core Services
    
    public var keychainManager: KeychainManager {
        diContainer.resolve(KeychainManager.self)
    }
    
    public var networkMonitor: NetworkMonitor {
        diContainer.resolve(NetworkMonitor.self)
    }
    
    public var offlineQueueManager: OfflineQueueManager {
        diContainer.resolve(OfflineQueueManager.self)
    }
    
    // MARK: - API Services
    
    public var apiClient: APIClient {
        diContainer.resolve(APIClient.self)
    }
    
    public var sseClient: SSEClient {
        diContainer.resolve(SSEClient.self)
    }
    
    public var sshManager: SSHManager {
        diContainer.resolve(SSHManager.self)
    }
    
    // MARK: - State Stores
    
    public var appState: AppState {
        diContainer.resolve(AppState.self)
    }
    
    public var settingsStore: SettingsStore {
        diContainer.resolve(SettingsStore.self)
    }
    
    public var chatStore: ChatStore {
        diContainer.resolve(ChatStore.self)
    }
    
    public var projectStore: ProjectStore {
        diContainer.resolve(ProjectStore.self)
    }
    
    public var toolStore: ToolStore {
        diContainer.resolve(ToolStore.self)
    }
    
    public var monitorStore: MonitorStore {
        diContainer.resolve(MonitorStore.self)
    }
    
    // MARK: - View Models
    
    @MainActor
    public func makeChatViewModel(conversationId: String? = nil) -> ChatViewModel {
        ChatViewModel(
            conversationId: conversationId,
            chatStore: chatStore,
            apiClient: apiClient,
            appState: appState
        )
    }
    
    @MainActor
    public func makeProjectViewModel(projectId: String? = nil) -> ProjectViewModel {
        ProjectViewModel(
            projectId: projectId,
            projectStore: projectStore,
            sshManager: sshManager,
            appState: appState
        )
    }
    
    @MainActor
    public func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            settingsStore: settingsStore,
            keychainManager: keychainManager,
            appState: appState
        )
    }
    
    @MainActor
    public func makeMonitorViewModel() -> MonitorViewModel {
        MonitorViewModel(
            monitorStore: monitorStore,
            sshManager: sshManager,
            appState: appState
        )
    }
    
    @MainActor
    public func makeToolsViewModel() -> ToolsViewModel {
        ToolsViewModel(
            toolStore: toolStore,
            apiClient: apiClient,
            appState: appState
        )
    }
    
    // MARK: - Coordinators
    
    public var appCoordinator: AppCoordinator {
        diContainer.resolve(AppCoordinator.self)
    }
    
    public func makeChatCoordinator() -> ChatCoordinator {
        diContainer.resolve(ChatCoordinator.self)
    }
    
    public func makeProjectsCoordinator() -> ProjectsCoordinator {
        diContainer.resolve(ProjectsCoordinator.self)
    }
    
    public func makeToolsCoordinator() -> ToolsCoordinator {
        diContainer.resolve(ToolsCoordinator.self)
    }
    
    public func makeMonitorCoordinator() -> MonitorCoordinator {
        diContainer.resolve(MonitorCoordinator.self)
    }
    
    public func makeSettingsCoordinator() -> SettingsCoordinator {
        diContainer.resolve(SettingsCoordinator.self)
    }
}

// MARK: - Environment Key

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    public var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    public func withDependencyContainer(_ container: DependencyContainer = .shared) -> some View {
        self.environment(\.dependencyContainer, container)
    }
}