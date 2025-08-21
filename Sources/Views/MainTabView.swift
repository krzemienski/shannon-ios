//
//  MainTabView.swift
//  ClaudeCode
//
//  Main tab-based navigation view
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var appState = AppState()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Chat Tab
            NavigationStack {
                ChatListView()
                    .navigationTitle("Chats")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Chat", systemImage: "message.fill")
            }
            .tag(0)
            
            // Projects Tab
            NavigationStack {
                ProjectsView()
                    .navigationTitle("Projects")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Projects", systemImage: "folder.fill")
            }
            .tag(1)
            
            // Tools Tab
            NavigationStack {
                ToolsView()
                    .navigationTitle("Tools")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Tools", systemImage: "wrench.and.screwdriver.fill")
            }
            .tag(2)
            
            // Monitor Tab
            NavigationStack {
                MonitorView()
                    .navigationTitle("Monitor")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Monitor", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(3)
            
            // Settings Tab
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(4)
        }
        .tint(Theme.primary)
        .environmentObject(appState)
        .onAppear {
            setupTabBarAppearance()
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
    MainTabView()
        .preferredColorScheme(.dark)
}