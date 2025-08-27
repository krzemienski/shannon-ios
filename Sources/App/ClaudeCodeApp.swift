//
//  ClaudeCodeApp.swift
//  ClaudeCode
//
//  Main application entry point
//

import SwiftUI

@main
struct ClaudeCodeApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // Configure appearance on launch
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        
        // Configure tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}