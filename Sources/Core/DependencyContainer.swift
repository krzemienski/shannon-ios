//
//  DependencyContainer.swift
//  ClaudeCode
//
//  Central dependency injection container
//

import Foundation
import SwiftUI

/// Protocol for module registration
protocol ModuleRegistration {
    func register()
}

/// Central dependency injection container
@MainActor
final class DependencyContainer {
    
    // MARK: - Singleton
    
    static let shared = DependencyContainer()
    
    // MARK: - State Stores
    
    // MARK: - Services
    
    let apiClient = APIClient.shared
    let sshManager = SSHManager()
    
    // MARK: - State Stores
    
    let settingsStore = SettingsStore()
    lazy var chatStore = ChatStore(apiClient: apiClient)
    let projectStore = ProjectStore()
    let toolStore = ToolStore()
    lazy var monitorStore = MonitorStore(sshManager: sshManager)
    let appState = AppState()
    
    // MARK: - Initialization
    
    private init() {
        setupServices()
    }
    
    // MARK: - Setup
    
    private func setupServices() {
        // Initialize services here
    }
    
    // MARK: - Factory Methods
    
    func makeSettingsViewModel() -> SettingsViewModel {
        return SettingsViewModel(
            settingsStore: settingsStore,
            keychainManager: KeychainManager.shared,
            appState: appState
        )
    }
}