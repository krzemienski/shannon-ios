//
//  ContentView_MVP.swift
//  ClaudeCode
//
//  MVP: Minimal content view for initial build
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        TabView {
            // Simple Chat placeholder
            NavigationStack {
                VStack {
                    Text("Chat")
                        .font(.largeTitle)
                        .foregroundColor(Theme.primary)
                    
                    Spacer()
                    
                    Text("Connect to backend at")
                        .foregroundColor(Theme.mutedForeground)
                    Text("http://localhost:8000")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Theme.accent)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
                .navigationTitle("Claude Code")
            }
            .tabItem {
                Label("Chat", systemImage: "message.fill")
            }
            
            // Simple Settings placeholder
            NavigationStack {
                VStack {
                    Text("Settings")
                        .font(.largeTitle)
                        .foregroundColor(Theme.primary)
                    
                    Spacer()
                    
                    Text("MVP Build")
                        .foregroundColor(Theme.mutedForeground)
                    Text("Version 1.0.0")
                        .foregroundColor(Theme.accent)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
                .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .tint(Theme.primary)
        .preferredColorScheme(.dark)
        .environmentObject(appState)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}