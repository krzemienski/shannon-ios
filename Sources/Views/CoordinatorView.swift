//
//  CoordinatorView.swift
//  ClaudeCode
//
//  Main coordinator view managing app navigation
//

import SwiftUI

/// Root view that manages navigation based on coordinator state
struct CoordinatorView: View {
    @ObservedObject var coordinator: AppCoordinator
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Main content
            if coordinator.isShowingOnboarding {
                OnboardingView {
                    coordinator.completeOnboarding()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            } else if !appState.isAuthenticated {
                AuthenticationView {
                    coordinator.handleAuthenticationSuccess()
                }
                .transition(.opacity)
            } else {
                MainNavigationView(coordinator: coordinator)
            }
        }
        .animation(.easeInOut, value: coordinator.isShowingOnboarding)
        .animation(.easeInOut, value: appState.isAuthenticated)
        .sheet(item: $coordinator.activeSheet) { sheetType in
            sheetContent(for: sheetType)
        }
        .fullScreenCover(item: $coordinator.activeFullScreenCover) { coverType in
            fullScreenCoverContent(for: coverType)
        }
        .alert(item: $coordinator.alertData) { alertData in
            Alert(
                title: Text(alertData.title),
                message: alertData.message.map { Text($0) },
                primaryButton: .default(
                    Text(alertData.primaryAction.title),
                    action: alertData.primaryAction.handler
                ),
                secondaryButton: alertData.secondaryAction.map { action in
                    .cancel(Text(action.title), action: action.handler)
                } ?? .cancel()
            )
        }
    }
    
    @ViewBuilder
    private func sheetContent(for sheetType: SheetType) -> some View {
        switch sheetType {
        case .newProject:
            NewProjectView(onSave: { project in
                // Handle project creation - implementation to be added
                print("New project created: \(project.name)")
            })
        case .projectSettings(let id):
            ProjectSettingsView(
                projectId: id,
                coordinator: coordinator.projectsCoordinator
            )
        case .newConversation:
            NewConversationView(coordinator: coordinator.chatCoordinator)
        case .conversationSettings(let id):
            ConversationSettingsView(
                conversationId: id,
                coordinator: coordinator.chatCoordinator
            )
        case .toolDetails(let id):
            ToolDetailsView(
                toolId: id,
                coordinator: coordinator.toolsCoordinator
            )
        case .exportData:
            ExportDataView(coordinator: coordinator)
        case .importData:
            ImportDataView(coordinator: coordinator)
        }
    }
    
    @ViewBuilder
    private func fullScreenCoverContent(for coverType: FullScreenCoverType) -> some View {
        switch coverType {
        case .authentication:
            AuthenticationView {
                coordinator.handleAuthenticationSuccess()
            }
        case .onboarding:
            OnboardingView {
                coordinator.completeOnboarding()
            }
        case .pdfViewer(let url):
            PDFViewerView(url: url)
        case .codeEditor(let path):
            // Create bindings for the code editor
            CodeEditorView(
                text: .constant("// File: \(path)\n// Code content would be loaded here"),
                language: .constant(.swift),
                fileName: path
            )
        }
    }
}

/// Main navigation view with tab bar
struct MainNavigationView: View {
    @ObservedObject var coordinator: AppCoordinator
    
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            ChatNavigationView(coordinator: coordinator.chatCoordinator)
                .tabItem {
                    Label(MainTab.chat.title, systemImage: MainTab.chat.icon)
                }
                .tag(MainTab.chat)
            
            ProjectsNavigationView(coordinator: coordinator.projectsCoordinator)
                .tabItem {
                    Label(MainTab.projects.title, systemImage: MainTab.projects.icon)
                }
                .tag(MainTab.projects)
            
            ToolsNavigationView(coordinator: coordinator.toolsCoordinator)
                .tabItem {
                    Label(MainTab.tools.title, systemImage: MainTab.tools.icon)
                }
                .tag(MainTab.tools)
            
            MonitorNavigationView(coordinator: coordinator.monitorCoordinator)
                .tabItem {
                    Label(MainTab.monitor.title, systemImage: MainTab.monitor.icon)
                }
                .tag(MainTab.monitor)
        }
        .overlay(alignment: .topTrailing) {
            // Settings button overlay
            Button {
                coordinator.showSettings()
            } label: {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundColor(Theme.primary)
                    .padding()
                    .background(Theme.card)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding()
        }
        .sheet(isPresented: $coordinator.isShowingSettings) {
            SettingsNavigationView(coordinator: coordinator.settingsCoordinator)
        }
    }
}

/// Chat navigation view
struct ChatNavigationView: View {
    @ObservedObject var coordinator: ChatCoordinator
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            ChatListView()
                .environmentObject(coordinator)
                .navigationDestination(for: ChatRoute.self) { route in
                    chatDestination(for: route)
                }
        }
    }
    
    @ViewBuilder
    private func chatDestination(for route: ChatRoute) -> some View {
        switch route {
        case .conversation(let id):
            // Create a temporary ChatSession for the given ID
            // In production, this should fetch from state/store
            ChatView(session: ChatSession(
                id: id,
                title: "Conversation",
                lastMessage: "",
                timestamp: Date(),
                icon: "message",
                tags: []
            ))
                .environmentObject(coordinator)
        case .search:
            ChatSearchView()
                .environmentObject(coordinator)
        case .settings(let id):
            ConversationSettingsView(
                conversationId: id,
                coordinator: coordinator
            )
        case .toolExecution(let toolId, let conversationId):
            ToolExecutionView(
                toolId: toolId,
                conversationId: conversationId
            )
            .environmentObject(coordinator)
        }
    }
}

/// Projects navigation view
struct ProjectsNavigationView: View {
    @ObservedObject var coordinator: ProjectsCoordinator
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            ProjectsView()
                .environmentObject(coordinator)
                .navigationDestination(for: ProjectRoute.self) { route in
                    projectDestination(for: route)
                }
        }
    }
    
    @ViewBuilder
    private func projectDestination(for route: ProjectRoute) -> some View {
        switch route {
        case .detail(let id):
            // TODO: Get project name from store/state
            ProjectDetailView(projectId: id, projectName: "Project")
                .environmentObject(coordinator)
        case .sshConfig(let id):
            SSHConfigurationView(projectId: id)
                .environmentObject(coordinator)
        case .environmentVariables(let id):
            EnvironmentVariablesView(projectId: id)
                .environmentObject(coordinator)
        case .fileEditor(let projectId, let filePath):
            FileEditorView(projectId: projectId, filePath: filePath)
                .environmentObject(coordinator)
        case .terminal(let id):
            TerminalView(projectId: id)
                .environmentObject(coordinator)
        }
    }
}

/// Tools navigation view
struct ToolsNavigationView: View {
    @ObservedObject var coordinator: ToolsCoordinator
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            ToolsView()
                .environmentObject(coordinator)
                .navigationDestination(for: ToolRoute.self) { route in
                    toolDestination(for: route)
                }
        }
    }
    
    @ViewBuilder
    private func toolDestination(for route: ToolRoute) -> some View {
        switch route {
        case .category(let category):
            ToolCategoryView(category: category)
                .environmentObject(coordinator)
        case .detail(let id):
            ToolDetailView(toolId: id)
                .environmentObject(coordinator)
        case .execution(let id, let parameters):
            ToolExecutionView(toolId: id, parameters: parameters)
                .environmentObject(coordinator)
        }
    }
}

/// Monitor navigation view
struct MonitorNavigationView: View {
    @ObservedObject var coordinator: MonitorCoordinator
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            MonitorView()
                .environmentObject(coordinator)
                .navigationDestination(for: MonitorRoute.self) { route in
                    monitorDestination(for: route)
                }
        }
    }
    
    @ViewBuilder
    private func monitorDestination(for route: MonitorRoute) -> some View {
        switch route {
        case .detail(let type):
            MonitorDetailView(monitorType: type)
                .environmentObject(coordinator)
        case .settings:
            MonitorSettingsView()
                .environmentObject(coordinator)
        case .export:
            MonitorExportView()
                .environmentObject(coordinator)
        case .alertConfig(let metric):
            AlertConfigurationView(metricType: metric)
                .environmentObject(coordinator)
        }
    }
}

/// Settings navigation view
struct SettingsNavigationView: View {
    @ObservedObject var coordinator: SettingsCoordinator
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            SettingsView()
                .environmentObject(coordinator)
                .navigationDestination(for: SettingsRoute.self) { route in
                    settingsDestination(for: route)
                }
        }
    }
    
    @ViewBuilder
    private func settingsDestination(for route: SettingsRoute) -> some View {
        switch route {
        case .section(let section):
            SettingsSectionView(section: section)
                .environmentObject(coordinator)
        case .apiConfig:
            APIConfigurationView()
                .environmentObject(coordinator)
        case .sshConfig:
            SSHGlobalConfigView()
                .environmentObject(coordinator)
        case .theme:
            ThemeSelectorView()
                .environmentObject(coordinator)
        case .dataManagement:
            DataManagementView()
                .environmentObject(coordinator)
        case .notifications:
            NotificationSettingsView()
                .environmentObject(coordinator)
        case .privacy:
            PrivacySettingsView()
                .environmentObject(coordinator)
        case .about:
            AboutView()
        case .licenses:
            LicensesView()
        }
    }
}