//
//  EnhancedTerminalView.swift
//  ClaudeCode
//
//  Full-featured terminal UI with SSH support
//

import SwiftUI
import Combine

/// Enhanced terminal view with full SSH and terminal emulation features
public struct EnhancedTerminalView: View {
    @StateObject private var viewModel: EnhancedTerminalViewModel
    @StateObject private var sessionManager = SSHSessionManager.shared
    @StateObject private var credentialManager = SSHCredentialManager.shared
    
    @State private var showConnectionSheet = false
    @State private var showSettingsSheet = false
    @State private var showKeyManagementSheet = false
    @State private var selectedTab: String?
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var splitViewMode: SplitViewMode = .none
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - Initialization
    
    public init(projectId: String? = nil) {
        _viewModel = StateObject(wrappedValue: EnhancedTerminalViewModel(projectId: projectId))
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationStack {
            ZStack {
                terminalBackground
                
                VStack(spacing: 0) {
                    // Tab bar for multiple sessions
                    if sessionManager.sessions.count > 1 {
                        terminalTabBar
                    }
                    
                    // Main terminal content
                    terminalContent
                    
                    // Bottom toolbar
                    terminalToolbar
                }
            }
            .navigationTitle("Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showConnectionSheet) {
                SSHConnectionSheet(
                    onConnect: { config in
                        Task {
                            await viewModel.createAndConnectSession(config: config)
                        }
                    }
                )
            }
            .sheet(isPresented: $showSettingsSheet) {
                TerminalSettingsView(settings: $viewModel.settings)
            }
            .sheet(isPresented: $showKeyManagementSheet) {
                SSHKeyManagementView()
            }
            .searchable(
                text: $searchText,
                isPresented: $isSearching,
                placement: .toolbar,
                prompt: "Search terminal output..."
            )
            .onAppear {
                viewModel.loadSessions()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Terminal Background
    
    private var terminalBackground: some View {
        ZStack {
            Color.black.opacity(0.95)
            
            // Cyberpunk grid effect
            GeometryReader { geometry in
                Path { path in
                    let gridSize: CGFloat = 30
                    let columns = Int(geometry.size.width / gridSize)
                    let rows = Int(geometry.size.height / gridSize)
                    
                    // Vertical lines
                    for col in 0...columns {
                        let x = CGFloat(col) * gridSize
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    
                    // Horizontal lines
                    for row in 0...rows {
                        let y = CGFloat(row) * gridSize
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Theme.primary.opacity(0.1),
                            Theme.primary.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Terminal Tab Bar
    
    private var terminalTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(sessionManager.sessions) { session in
                    TerminalTab(
                        session: session,
                        isActive: sessionManager.activeSessionId == session.id,
                        onSelect: {
                            sessionManager.setActiveSession(session.id)
                        },
                        onClose: {
                            Task {
                                await sessionManager.closeSession(session.id)
                            }
                        }
                    )
                }
                
                // New tab button
                Button(action: {
                    showConnectionSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Terminal Content
    
    private var terminalContent: some View {
        Group {
            if let activeSession = viewModel.activeSession {
                switch splitViewMode {
                case .none:
                    TerminalSessionView(
                        session: activeSession,
                        searchText: searchText
                    )
                    
                case .horizontal:
                    HSplitView {
                        TerminalSessionView(
                            session: activeSession,
                            searchText: searchText
                        )
                        
                        if let secondSession = viewModel.secondarySession {
                            TerminalSessionView(
                                session: secondSession,
                                searchText: searchText
                            )
                        }
                    }
                    
                case .vertical:
                    VSplitView {
                        TerminalSessionView(
                            session: activeSession,
                            searchText: searchText
                        )
                        
                        if let secondSession = viewModel.secondarySession {
                            TerminalSessionView(
                                session: secondSession,
                                searchText: searchText
                            )
                        }
                    }
                }
            } else {
                emptyStateView
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 60))
                .foregroundColor(Theme.primary.opacity(0.5))
            
            Text("No Active Sessions")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Connect to a server to start a terminal session")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button(action: {
                    showConnectionSheet = true
                }) {
                    Label("New Connection", systemImage: "plus.circle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
                
                if !credentialManager.savedCredentials.isEmpty {
                    Button(action: {
                        Task {
                            await viewModel.connectToRecent()
                        }
                    }) {
                        Label("Recent", systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                            .foregroundColor(Theme.primary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .overlay(
                                Capsule()
                                    .stroke(Theme.primary, lineWidth: 2)
                            )
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Terminal Toolbar
    
    private var terminalToolbar: some View {
        HStack(spacing: 16) {
            // Connection status
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.connectionStatusColor)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.connectionStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Quick actions
            HStack(spacing: 12) {
                // Clear terminal
                Button(action: {
                    viewModel.clearTerminal()
                }) {
                    Image(systemName: "clear")
                        .font(.system(size: 14))
                }
                
                // Command history
                Menu {
                    ForEach(viewModel.commandHistory.reversed().prefix(10), id: \.self) { command in
                        Button(command) {
                            viewModel.sendCommand(command)
                        }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                }
                
                // Split view
                Menu {
                    Button("No Split") {
                        splitViewMode = .none
                    }
                    
                    Button("Split Horizontal") {
                        splitViewMode = .horizontal
                    }
                    
                    Button("Split Vertical") {
                        splitViewMode = .vertical
                    }
                } label: {
                    Image(systemName: "square.split.2x2")
                        .font(.system(size: 14))
                }
                
                // Recording
                Button(action: {
                    viewModel.toggleRecording()
                }) {
                    Image(systemName: viewModel.isRecording ? "record.circle.fill" : "record.circle")
                        .font(.system(size: 14))
                        .foregroundColor(viewModel.isRecording ? .red : .primary)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Button(action: {
                    showConnectionSheet = true
                }) {
                    Label("New Connection", systemImage: "plus.circle")
                }
                
                Divider()
                
                ForEach(credentialManager.savedCredentials) { credential in
                    Button(action: {
                        Task {
                            await viewModel.connectToSaved(credential)
                        }
                    }) {
                        Label(credential.name, systemImage: "server.rack")
                    }
                }
            } label: {
                Image(systemName: "plus")
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button(action: {
                    showSettingsSheet = true
                }) {
                    Label("Settings", systemImage: "gearshape")
                }
                
                Button(action: {
                    showKeyManagementSheet = true
                }) {
                    Label("SSH Keys", systemImage: "key")
                }
                
                Divider()
                
                Button(action: {
                    viewModel.exportSession()
                }) {
                    Label("Export Session", systemImage: "square.and.arrow.up")
                }
                
                Button(action: {
                    viewModel.shareSession()
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Terminal Tab

struct TerminalTab: View {
    let session: SSHSession
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Connection indicator
            Circle()
                .fill(session.status.isActive ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            
            // Session name
            Text(session.name)
                .font(.caption)
                .lineLimit(1)
            
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Theme.primary.opacity(0.2) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? Theme.primary : Color.clear, lineWidth: 1)
                )
        )
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Split View Mode

enum SplitViewMode {
    case none
    case horizontal
    case vertical
}

// MARK: - Preview

#Preview {
    EnhancedTerminalView()
        .preferredColorScheme(.dark)
}