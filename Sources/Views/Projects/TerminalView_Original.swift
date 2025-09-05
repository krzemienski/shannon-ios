//
//  TerminalView.swift
//  ClaudeCode
//
//  Terminal view for SSH connections
//

import SwiftUI

struct TerminalView: View {
    let projectId: String?
    @EnvironmentObject var coordinator: ProjectsCoordinator
    @StateObject private var sshSessionManager = SSHSessionManager.shared
    @State private var showConnectionSheet = false
    @State private var showEnhancedTerminal = false
    
    init(projectId: String? = nil) {
        self.projectId = projectId
    }
    
    var body: some View {
        Group {
            if sshSessionManager.sessions.isEmpty {
                emptyStateView
            } else {
                EnhancedTerminalView(projectId: projectId)
            }
        }
        .navigationTitle("Terminal")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showConnectionSheet = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(Theme.primary)
                }
            }
        }
        .sheet(isPresented: $showConnectionSheet) {
            SSHConnectionSheet { config in
                Task {
                    do {
                        let sessionId = try await sshSessionManager.createSession(
                            name: config.name,
                            config: config
                        )
                        try await sshSessionManager.connect(sessionId: sessionId)
                        showEnhancedTerminal = true
                    } catch {
                        print("Failed to create SSH session: \(error)")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showEnhancedTerminal) {
            NavigationStack {
                EnhancedTerminalView(projectId: projectId)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showEnhancedTerminal = false
                            }
                        }
                    }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 60))
                .foregroundColor(Theme.primary.opacity(0.5))
            
            Text("No SSH Sessions")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Connect to a server to start using the terminal")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showConnectionSheet = true
            } label: {
                Label("New Connection", systemImage: "plus.circle")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.primary)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }
}