//
//  ContentView.swift
//  ClaudeCode
//
//  Main app entry with TabView
//

import SwiftUI

struct ContentView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @StateObject private var featureFlags = FeatureFlagService.shared
    @StateObject private var onboardingService = OnboardingService.shared
    @StateObject private var tooltipService = TooltipService.shared
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = Tab.chat
    @State private var showOnboarding = false
    @State private var showHelpCenter = false
    @Environment(\.colorScheme) private var colorScheme
    
    enum Tab: Int, CaseIterable {
        case chat = 0
        case projects = 1
        case terminal = 2
        case settings = 3
        
        var title: String {
            switch self {
            case .chat: return "Chat"
            case .projects: return "Projects"
            case .terminal: return "Terminal"
            case .settings: return "Settings"
            }
        }
        
        var icon: String {
            switch self {
            case .chat: return "message.fill"
            case .projects: return "folder.fill"
            case .terminal: return "terminal.fill"
            case .settings: return "gear"
            }
        }
    }
    
    var body: some View {
        ZStack {
            if showOnboarding {
                EnhancedOnboardingView {
                    withAnimation {
                        showOnboarding = false
                        appState.hasCompletedOnboarding = true
                    }
                }
                .transition(.opacity)
            } else {
                mainTabView
            }
        }
        .onAppear {
            checkOnboardingStatus()
            initializeServices()
        }
        .sheet(isPresented: $showHelpCenter) {
            HelpCenterView()
        }
    }
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            // Chat Tab
            NavigationStack(path: $navigationCoordinator.chatPath) {
                ChatListView()
                    .navigationTitle("Chat")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            helpButton
                        }
                    }
                    .tooltip("chat_input", show: appState.isFirstLaunch)
            }
            .tabItem {
                Label(Tab.chat.title, systemImage: Tab.chat.icon)
            }
            .tag(Tab.chat)
            
            // Projects Tab
            NavigationStack(path: $navigationCoordinator.projectsPath) {
                ProjectsView()
                    .navigationTitle("Projects")
                    .navigationBarTitleDisplayMode(.large)
                    .tooltip("project_create", show: appState.isFirstLaunch)
            }
            .tabItem {
                Label(Tab.projects.title, systemImage: Tab.projects.icon)
            }
            .tag(Tab.projects)
            
            // Terminal Tab - with feature flag
            if featureFlags.isEnabled("advanced_terminal") {
                NavigationStack(path: $navigationCoordinator.terminalPath) {
                    TerminalView()
                        .tooltip("terminal_access")
                }
                .tabItem {
                    Label(Tab.terminal.title, systemImage: Tab.terminal.icon)
                }
                .tag(Tab.terminal)
            }
            
            // Settings Tab
            NavigationStack(path: $navigationCoordinator.settingsPath) {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            helpButton
                        }
                    }
            }
            .tabItem {
                Label(Tab.settings.title, systemImage: Tab.settings.icon)
            }
            .tag(Tab.settings)
        }
        .tint(Theme.primary)
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .environmentObject(themeManager)
        .environmentObject(navigationCoordinator)
        .environmentObject(featureFlags)
        .environmentObject(tooltipService)
        .onAppear {
            setupTabBarAppearance()
        }
        .onOpenURL { url in
            navigationCoordinator.handleDeepLink(url)
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.card)
        
        // Configure item appearance
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Theme.muted)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Theme.muted)
        ]
        
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Theme.primary)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Theme.primary)
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func checkOnboardingStatus() {
        showOnboarding = !appState.hasCompletedOnboarding
    }
    
    private func initializeServices() {
        Task {
            // Initialize feature flags
            await featureFlags.initialize()
            
            // Track app open
            AnalyticsService.shared.track(event: "app_opened", properties: [
                "has_completed_onboarding": appState.hasCompletedOnboarding,
                "is_first_launch": appState.isFirstLaunch
            ])
        }
    }
    
    private var helpButton: some View {
        Button {
            showHelpCenter = true
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundColor(Theme.primary)
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
        .environmentObject(AppState())
}