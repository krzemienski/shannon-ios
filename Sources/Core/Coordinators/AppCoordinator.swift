//
//  AppCoordinator.swift
//  ClaudeCode
//
//  Main application coordinator managing app-wide navigation
//

import SwiftUI
import Combine

/// Main application coordinator
@MainActor
public final class AppCoordinator: BaseCoordinator, ObservableObject {
    
    // MARK: - Navigation State
    
    @Published var selectedTab: MainTab = .chat
    @Published var isShowingOnboarding = false
    @Published var isShowingSettings = false
    @Published var activeSheet: SheetType?
    @Published var activeFullScreenCover: FullScreenCoverType?
    @Published var alertData: AlertData?
    
    // MARK: - Dependencies
    
    private let dependencyContainer: DependencyContainer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Child Coordinators
    
    private(set) lazy var chatCoordinator = ChatCoordinator(dependencyContainer: dependencyContainer)
    private(set) lazy var projectsCoordinator = ProjectsCoordinator(dependencyContainer: dependencyContainer)
    private(set) lazy var toolsCoordinator = ToolsCoordinator(dependencyContainer: dependencyContainer)
    private(set) lazy var monitorCoordinator = MonitorCoordinator(dependencyContainer: dependencyContainer)
    private(set) lazy var settingsCoordinator = SettingsCoordinator(dependencyContainer: dependencyContainer)
    
    // MARK: - Initialization
    
    init(dependencyContainer: DependencyContainer = .shared) {
        self.dependencyContainer = dependencyContainer
        super.init()
        setupCoordinators()
        observeAppState()
    }
    
    // MARK: - Setup
    
    private func setupCoordinators() {
        // Add child coordinators
        addChild(chatCoordinator)
        addChild(projectsCoordinator)
        addChild(toolsCoordinator)
        addChild(monitorCoordinator)
        addChild(settingsCoordinator)
        
        // Set self as parent coordinator
        chatCoordinator.appCoordinator = self
        projectsCoordinator.appCoordinator = self
        toolsCoordinator.appCoordinator = self
        monitorCoordinator.appCoordinator = self
        settingsCoordinator.appCoordinator = self
    }
    
    private func observeAppState() {
        // Observe app state for navigation changes
        dependencyContainer.appState.$isFirstLaunch
            .removeDuplicates()
            .sink { [weak self] isFirstLaunch in
                if isFirstLaunch {
                    self?.showOnboarding()
                }
            }
            .store(in: &cancellables)
        
        // Observe authentication state
        dependencyContainer.appState.$isAuthenticated
            .removeDuplicates()
            .sink { [weak self] isAuthenticated in
                if !isAuthenticated {
                    self?.handleAuthenticationRequired()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Coordinator Lifecycle
    
    override func start() {
        Task { @MainActor in
            // Check if onboarding is needed
            if dependencyContainer.appState.isFirstLaunch {
                showOnboarding()
            } else if !dependencyContainer.appState.isAuthenticated {
                handleAuthenticationRequired()
            }
            
            // Start child coordinators
            children.forEach { $0.start() }
        }
    }
    
    // MARK: - Navigation
    
    func selectTab(_ tab: MainTab) {
        selectedTab = tab
        
        // Notify appropriate coordinator
        switch tab {
        case .chat:
            chatCoordinator.handleTabSelection()
        case .projects:
            projectsCoordinator.handleTabSelection()
        case .tools:
            toolsCoordinator.handleTabSelection()
        case .monitor:
            monitorCoordinator.handleTabSelection()
        }
    }
    
    // MARK: - Modal Presentation
    
    func presentSheet(_ sheet: SheetType) {
        activeSheet = sheet
    }
    
    func dismissSheet() {
        activeSheet = nil
    }
    
    func presentFullScreenCover(_ cover: FullScreenCoverType) {
        activeFullScreenCover = cover
    }
    
    func dismissFullScreenCover() {
        activeFullScreenCover = nil
    }
    
    // MARK: - Alerts
    
    func showAlert(_ alertData: AlertData) {
        self.alertData = alertData
    }
    
    func dismissAlert() {
        alertData = nil
    }
    
    func showError(_ error: Error, retryAction: (() -> Void)? = nil) {
        let alertData = AlertData(
            title: "Error",
            message: error.localizedDescription,
            primaryAction: AlertAction(
                title: "OK",
                style: .default,
                handler: nil
            ),
            secondaryAction: retryAction != nil ? AlertAction(
                title: "Retry",
                style: .default,
                handler: retryAction
            ) : nil
        )
        showAlert(alertData)
    }
    
    // MARK: - Onboarding
    
    func showOnboarding() {
        isShowingOnboarding = true
    }
    
    func completeOnboarding() {
        isShowingOnboarding = false
        Task {
            await dependencyContainer.appState.completeOnboarding()
        }
    }
    
    // MARK: - Settings
    
    func showSettings() {
        isShowingSettings = true
        settingsCoordinator.start()
    }
    
    func dismissSettings() {
        isShowingSettings = false
    }
    
    // MARK: - Authentication
    
    private func handleAuthenticationRequired() {
        // Present authentication flow
        presentFullScreenCover(.authentication)
    }
    
    func handleAuthenticationSuccess() {
        dismissFullScreenCover()
        // Refresh app state
        Task {
            await dependencyContainer.appState.refreshAuthenticationStatus()
        }
    }
    
    // MARK: - Deep Linking
    
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        
        switch components.host {
        case "chat":
            handleChatDeepLink(components: components)
        case "project":
            handleProjectDeepLink(components: components)
        case "tool":
            handleToolDeepLink(components: components)
        default:
            break
        }
    }
    
    private func handleChatDeepLink(components: URLComponents) {
        selectTab(.chat)
        if let conversationId = components.queryItems?.first(where: { $0.name == "id" })?.value {
            chatCoordinator.openConversation(id: conversationId)
        }
    }
    
    private func handleProjectDeepLink(components: URLComponents) {
        selectTab(.projects)
        if let projectId = components.queryItems?.first(where: { $0.name == "id" })?.value {
            projectsCoordinator.openProject(id: projectId)
        }
    }
    
    private func handleToolDeepLink(components: URLComponents) {
        selectTab(.tools)
        if let toolId = components.queryItems?.first(where: { $0.name == "id" })?.value {
            toolsCoordinator.openTool(id: toolId)
        }
    }
}

// MARK: - Supporting Types

enum MainTab: String, CaseIterable, Identifiable {
    case chat
    case projects
    case tools
    case monitor
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .chat: return "Chat"
        case .projects: return "Projects"
        case .tools: return "Tools"
        case .monitor: return "Monitor"
        }
    }
    
    var icon: String {
        switch self {
        case .chat: return "message.fill"
        case .projects: return "folder.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .monitor: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum SheetType: Identifiable {
    case newProject
    case projectSettings(String)
    case newConversation
    case conversationSettings(String)
    case toolDetails(String)
    case exportData
    case importData
    
    var id: String {
        switch self {
        case .newProject: return "newProject"
        case .projectSettings(let id): return "projectSettings_\(id)"
        case .newConversation: return "newConversation"
        case .conversationSettings(let id): return "conversationSettings_\(id)"
        case .toolDetails(let id): return "toolDetails_\(id)"
        case .exportData: return "exportData"
        case .importData: return "importData"
        }
    }
}

enum FullScreenCoverType: Identifiable {
    case authentication
    case onboarding
    case pdfViewer(URL)
    case codeEditor(String)
    
    var id: String {
        switch self {
        case .authentication: return "authentication"
        case .onboarding: return "onboarding"
        case .pdfViewer: return "pdfViewer"
        case .codeEditor(let path): return "codeEditor_\(path)"
        }
    }
}

struct AlertData: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
    let primaryAction: AlertAction
    let secondaryAction: AlertAction?
}