//
//  TerminalTabsView.swift
//  ClaudeCode
//
//  Multiple terminal sessions support with tabs (Tasks 621-622)
//

import SwiftUI

/// Terminal tabs view for managing multiple sessions
public struct TerminalTabsView: View {
    @ObservedObject var viewModel: TerminalViewModel
    @State private var selectedTabId: String?
    @State private var showNewSession = false
    @State private var draggedTab: TerminalSession?
    
    public var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TerminalTabBar(
                sessions: viewModel.sessions,
                selectedId: $selectedTabId,
                onNewTab: { showNewSession = true },
                onCloseTab: viewModel.closeSession,
                draggedTab: $draggedTab
            )
            
            // Tab content
            if let tabId = selectedTabId,
               let session = viewModel.session(with: tabId) {
                TerminalTabContent(
                    session: session,
                    viewModel: viewModel
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                EmptyTerminalTabView(onNewSession: { showNewSession = true })
            }
        }
        .sheet(isPresented: $showNewSession) {
            NewTerminalSessionSheet(
                recentConnections: viewModel.settings.recentConnections,
                onCreate: { config in
                    Task {
                        if let sessionId = await viewModel.createSession(with: config) {
                            selectedTabId = sessionId
                        }
                    }
                    showNewSession = false
                }
            )
        }
        .onAppear {
            // Select first tab if none selected
            if selectedTabId == nil {
                selectedTabId = viewModel.sessions.first?.id
            }
        }
        .onChange(of: viewModel.sessions) { sessions in
            // Update selection if current tab was closed
            if let selectedId = selectedTabId,
               !sessions.contains(where: { $0.id == selectedId }) {
                selectedTabId = sessions.first?.id
            }
        }
    }
}

/// Terminal tab bar
struct TerminalTabBar: View {
    let sessions: [TerminalSession]
    @Binding var selectedId: String?
    let onNewTab: () -> Void
    let onCloseTab: (String) -> Void
    @Binding var draggedTab: TerminalSession?
    
    @State private var hoveredTabId: String?
    @State private var tabWidths: [String: CGFloat] = [:]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(sessions) { session in
                    TerminalTab(
                        session: session,
                        isSelected: session.id == selectedId,
                        isHovered: session.id == hoveredTabId,
                        onSelect: { selectedId = session.id },
                        onClose: { onCloseTab(session.id) }
                    )
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    tabWidths[session.id] = geometry.size.width
                                }
                        }
                    )
                    .onDrag {
                        draggedTab = session
                        return NSItemProvider(object: session.id as NSString)
                    }
                    .onDrop(of: [.text], delegate: TabDropDelegate(
                        session: session,
                        sessions: sessions,
                        draggedTab: $draggedTab
                    ))
                    .onHover { hovering in
                        hoveredTabId = hovering ? session.id : nil
                    }
                }
                
                // New tab button
                Button(action: onNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Theme.card.opacity(0.5))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(height: 38)
        .background(Theme.card)
    }
}

/// Individual terminal tab
struct TerminalTab: View {
    let session: TerminalSession
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var showCloseButton = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Connection status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            // Session name
            Text(session.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(isSelected ? .primary : .secondary)
            
            // Activity indicator
            if session.hasUnreadOutput && !isSelected {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4, height: 4)
            }
            
            // Close button
            if showCloseButton || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tabBackground)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(borderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            showCloseButton = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
    
    private var statusColor: Color {
        switch session.status {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        case .disconnecting:
            return .yellow
        }
    }
    
    private var tabBackground: Color {
        if isSelected {
            return Theme.background
        } else if isHovered {
            return Theme.card.opacity(0.8)
        } else {
            return Theme.card.opacity(0.5)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Theme.primary.opacity(0.5)
        } else {
            return Color.clear
        }
    }
}

/// Tab drop delegate for reordering
struct TabDropDelegate: DropDelegate {
    let session: TerminalSession
    let sessions: [TerminalSession]
    @Binding var draggedTab: TerminalSession?
    
    func performDrop(info: DropInfo) -> Bool {
        draggedTab = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedTab = draggedTab,
              draggedTab.id != session.id else { return }
        
        // TODO: Implement tab reordering
    }
}

/// Terminal tab content
struct TerminalTabContent: View {
    @ObservedObject var session: TerminalSession
    let viewModel: TerminalViewModel
    
    @State private var scrollToBottom = true
    @State private var searchText = ""
    @State private var showSearch = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal header
            TerminalHeader(
                session: session,
                showSearch: $showSearch,
                onReconnect: {
                    Task {
                        await viewModel.reconnect(sessionId: session.id)
                    }
                },
                onClear: {
                    viewModel.clearTerminal(sessionId: session.id)
                },
                onExport: {
                    exportSession()
                }
            )
            
            // Terminal content
            ZStack {
                // Terminal emulator
                TerminalEmulatorView(
                    terminal: session.terminal,
                    scrollToBottom: $scrollToBottom,
                    searchText: searchText,
                    onResize: { size in
                        viewModel.resizeTerminal(sessionId: session.id, size: size)
                    }
                )
                
                // Connection overlay
                if session.status != .connected {
                    TerminalConnectionOverlay(
                        session: session,
                        onConnect: {
                            Task {
                                await viewModel.connect(sessionId: session.id)
                            }
                        }
                    )
                }
            }
            
            // Input area
            if session.status == .connected {
                TerminalInputView(
                    onCommand: { command in
                        viewModel.sendCommand(to: session.id, command: command)
                    },
                    history: session.commandHistory
                )
            }
        }
        .searchable(text: $searchText, isPresented: $showSearch)
    }
    
    private func exportSession() {
        let content = viewModel.exportSession(session.id)
        
        // Share exported content
        let activityVC = UIActivityViewController(
            activityItems: [content],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

/// Terminal header
struct TerminalHeader: View {
    let session: TerminalSession
    @Binding var showSearch: Bool
    let onReconnect: () -> Void
    let onClear: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        HStack {
            // Session info
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.system(.headline, design: .monospaced))
                
                if let config = session.config {
                    Text("\(config.username)@\(config.host):\(config.port)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                if session.status == .disconnected || session.status == .error(_) {
                    Button("Reconnect", action: onReconnect)
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
                
                Button(action: { showSearch.toggle() }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(showSearch ? Theme.primary : .secondary)
                }
                
                Button(action: onClear) {
                    Image(systemName: "trash")
                }
                
                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

/// Terminal connection overlay
struct TerminalConnectionOverlay: View {
    let session: TerminalSession
    let onConnect: () -> Void
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.6)
                .background(.ultraThinMaterial)
            
            // Connection status
            VStack(spacing: 20) {
                switch session.status {
                case .connecting:
                    ProgressView("Connecting...")
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                    
                case .disconnected:
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Not Connected")
                            .font(.title3)
                        
                        Button("Connect", action: onConnect)
                            .buttonStyle(.borderedProminent)
                    }
                    
                case .error(let message):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        
                        Text("Connection Error")
                            .font(.title3)
                        
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                        
                        Button("Retry", action: onConnect)
                            .buttonStyle(.borderedProminent)
                    }
                    
                default:
                    EmptyView()
                }
            }
        }
    }
}

/// Empty terminal tab view
struct EmptyTerminalTabView: View {
    let onNewSession: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Terminal Session")
                    .font(.title2)
                
                Text("Create a new session to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Button("New Session", action: onNewSession)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

/// New terminal session sheet
struct NewTerminalSessionSheet: View {
    let recentConnections: [SSHConfig]
    let onCreate: (SSHConfig) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // New connection form
                NewConnectionForm(onCreate: onCreate)
                    .tabItem {
                        Label("New", systemImage: "plus.circle")
                    }
                    .tag(0)
                
                // Recent connections
                RecentConnectionsList(
                    connections: recentConnections,
                    onSelect: onCreate
                )
                .tabItem {
                    Label("Recent", systemImage: "clock")
                }
                .tag(1)
                
                // Saved connections
                SavedConnectionsList(onSelect: onCreate)
                    .tabItem {
                        Label("Saved", systemImage: "star")
                    }
                    .tag(2)
            }
            .navigationTitle("New Terminal Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// Additional supporting views would go here...

// MARK: - Preview

#Preview {
    TerminalTabsView(viewModel: TerminalViewModel.preview)
        .preferredColorScheme(.dark)
}