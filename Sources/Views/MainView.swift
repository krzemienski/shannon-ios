//
//  MainView.swift
//  ClaudeCode
//
//  Main view wrapper with WebSocket support
//

import SwiftUI

struct MainView: View {
    @StateObject var appState = AppState()
    @State var showSettings = false
    
    var body: some View {
        MainTabView()
            .environmentObject(appState)
    }
}

#Preview {
    MainView()
        .preferredColorScheme(.dark)
}