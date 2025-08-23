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
    @State private var selectedTab = Tab.chat
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
        TabView(selection: $selectedTab) {
            // Chat Tab
            NavigationStack(path: $navigationCoordinator.chatPath) {
                ChatListView()
                    .navigationTitle("Chat")
                    .navigationBarTitleDisplayMode(.large)
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
            }
            .tabItem {
                Label(Tab.projects.title, systemImage: Tab.projects.icon)
            }
            .tag(Tab.projects)
            
            // Terminal Tab
            NavigationStack(path: $navigationCoordinator.terminalPath) {
                TerminalView()
                    .navigationTitle("Terminal")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label(Tab.terminal.title, systemImage: Tab.terminal.icon)
            }
            .tag(Tab.terminal)
            
            // Settings Tab
            NavigationStack(path: $navigationCoordinator.settingsPath) {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label(Tab.settings.title, systemImage: Tab.settings.icon)
            }
            .tag(Tab.settings)
        }
        .tint(Theme.primary)
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .environmentObject(themeManager)
        .environmentObject(navigationCoordinator)
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
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}