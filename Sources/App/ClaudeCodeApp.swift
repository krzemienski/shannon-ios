//
//  ClaudeCodeApp.swift
//  ClaudeCode
//
//  Main application entry point
//

import SwiftUI
import BackgroundTasks

@main
struct ClaudeCodeApp: App {
    @StateObject private var dependencyContainer = DependencyContainer.shared
    @StateObject private var appCoordinator: AppCoordinator
    @StateObject private var appState = DependencyContainer.shared.appState
    @StateObject private var sshManager = DependencyContainer.shared.sshManager
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Register all modules
        AppModuleRegistration.registerAllModules()
        
        // Initialize coordinator
        let coordinator = AppCoordinator(dependencyContainer: DependencyContainer.shared)
        _appCoordinator = StateObject(wrappedValue: coordinator)
        
        // Configure app-wide settings
        configureAppearance()
        registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            CoordinatorView(coordinator: appCoordinator)
                .withDependencyContainer(dependencyContainer)
                .environmentObject(appState)
                .environmentObject(sshManager)
                .environmentObject(dependencyContainer.settingsStore)
                .environmentObject(dependencyContainer.chatStore)
                .environmentObject(dependencyContainer.projectStore)
                .environmentObject(appCoordinator)
                .preferredColorScheme(.dark) // Force dark mode for consistent theming
                .tint(Theme.primary)
                .task {
                    // Initialize app on launch
                    await appState.initialize()
                    appCoordinator.start()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
                .onOpenURL { url in
                    // Handle deep links
                    appCoordinator.handleDeepLink(url)
                }
        }
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.card)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Theme.foreground)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.foreground)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Theme.card)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Configure table view appearance
        UITableView.appearance().backgroundColor = UIColor(Theme.background)
        UITableViewCell.appearance().backgroundColor = UIColor(Theme.card)
        
        // Configure text view appearance
        UITextView.appearance().backgroundColor = .clear
        UITextView.appearance().textColor = UIColor(Theme.foreground)
    }
    
    private func registerBackgroundTasks() {
        // Register background task for SSH monitoring
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.shannon.ClaudeCode.ssh-monitor",
            using: nil
        ) { task in
            handleSSHMonitoringTask(task as! BGProcessingTask)
        }
        
        // Register background task for telemetry sync
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.shannon.ClaudeCode.telemetry-sync",
            using: nil
        ) { task in
            handleTelemetrySyncTask(task as! BGAppRefreshTask)
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            print("App became active")
            // Resume any paused operations
            
        case .inactive:
            print("App became inactive")
            
        case .background:
            print("App entered background")
            // Schedule background tasks
            scheduleBackgroundTasks()
            // Save app state
            
        @unknown default:
            break
        }
    }
    
    private func scheduleBackgroundTasks() {
        // Schedule SSH monitoring task
        let sshRequest = BGProcessingTaskRequest(
            identifier: "com.shannon.ClaudeCode.ssh-monitor"
        )
        sshRequest.requiresNetworkConnectivity = true
        sshRequest.requiresExternalPower = false
        sshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes
        
        do {
            try BGTaskScheduler.shared.submit(sshRequest)
        } catch {
            print("Failed to schedule SSH monitoring task: \(error)")
        }
        
        // Schedule telemetry sync task
        let telemetryRequest = BGAppRefreshTaskRequest(
            identifier: "com.shannon.ClaudeCode.telemetry-sync"
        )
        telemetryRequest.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(telemetryRequest)
        } catch {
            print("Failed to schedule telemetry sync task: \(error)")
        }
    }
    
    private func handleSSHMonitoringTask(_ task: BGProcessingTask) {
        // Set expiration handler
        task.expirationHandler = {
            // Clean up any ongoing operations
            task.setTaskCompleted(success: false)
        }
        
        // Perform SSH monitoring
        Task {
            do {
                // Check SSH connections and perform monitoring
                await sshManager.performBackgroundMonitoring()
                task.setTaskCompleted(success: true)
            } catch {
                print("SSH monitoring failed: \(error)")
                task.setTaskCompleted(success: false)
            }
            
            // Schedule next monitoring task
            scheduleBackgroundTasks()
        }
    }
    
    private func handleTelemetrySyncTask(_ task: BGAppRefreshTask) {
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Sync telemetry data
        Task {
            // TODO: Implement telemetry sync
            task.setTaskCompleted(success: true)
            
            // Schedule next sync
            scheduleBackgroundTasks()
        }
    }
}