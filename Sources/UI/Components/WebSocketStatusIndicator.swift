//
//  WebSocketStatusIndicator.swift
//  ClaudeCode
//
//  WebSocket connection status indicator UI component
//

import SwiftUI

/// Visual indicator for WebSocket connection status
struct WebSocketStatusIndicator: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var webSocketService = WebSocketService.shared
    @State private var isAnimating = false
    @State private var showDetails = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: appState.webSocketReconnecting ? 2 : 0)
                        .scaleEffect(isAnimating ? 1.5 : 1.0)
                        .opacity(isAnimating ? 0 : 1)
                )
                .animation(
                    appState.webSocketReconnecting ?
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: false) : .default,
                    value: isAnimating
                )
            
            // Status text
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.secondarySystemBackground))
        )
        .onTapGesture {
            showDetails.toggle()
        }
        .popover(isPresented: $showDetails) {
            WebSocketDetailsView()
                .frame(width: 280, height: 200)
        }
        .onAppear {
            if appState.webSocketReconnecting {
                isAnimating = true
            }
        }
        .onChange(of: appState.webSocketReconnecting) { reconnecting in
            isAnimating = reconnecting
        }
    }
    
    private var statusColor: Color {
        if appState.webSocketConnected {
            return .green
        } else if appState.webSocketReconnecting {
            return .orange
        } else {
            return .red
        }
    }
    
    private var statusText: String {
        if appState.webSocketConnected {
            return "Connected"
        } else if appState.webSocketReconnecting {
            return "Reconnecting..."
        } else {
            return "Disconnected"
        }
    }
}

/// Detailed WebSocket connection information
struct WebSocketDetailsView: View {
    @StateObject private var webSocketService = WebSocketService.shared
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundColor(statusColor)
                
                Text("WebSocket Status")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    Task {
                        if appState.webSocketConnected {
                            await webSocketService.disconnect()
                        } else {
                            try? await webSocketService.connect()
                        }
                    }
                }) {
                    Image(systemName: appState.webSocketConnected ? "stop.circle" : "play.circle")
                        .foregroundColor(appState.webSocketConnected ? .red : .green)
                }
            }
            
            Divider()
            
            // Connection info
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(
                    label: "Status",
                    value: connectionStateText,
                    color: statusColor
                )
                
                if webSocketService.reconnectAttempts > 0 {
                    StatusRow(
                        label: "Reconnect Attempts",
                        value: "\(webSocketService.reconnectAttempts)",
                        color: .orange
                    )
                }
                
                if let error = webSocketService.lastError {
                    StatusRow(
                        label: "Last Error",
                        value: error.localizedDescription,
                        color: .red
                    )
                    .lineLimit(2)
                    .font(.caption)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var statusColor: Color {
        switch webSocketService.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected, .disconnecting:
            return .gray
        case .failed:
            return .red
        }
    }
    
    private var connectionStateText: String {
        switch webSocketService.connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .disconnecting:
            return "Disconnecting..."
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        }
    }
}

/// Status row component for details view
struct StatusRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

struct WebSocketStatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Connected state
            WebSocketStatusIndicator()
                .environmentObject({
                    let state = AppState()
                    state.webSocketConnected = true
                    return state
                }())
            
            // Reconnecting state
            WebSocketStatusIndicator()
                .environmentObject({
                    let state = AppState()
                    state.webSocketReconnecting = true
                    return state
                }())
            
            // Disconnected state
            WebSocketStatusIndicator()
                .environmentObject({
                    let state = AppState()
                    state.webSocketConnected = false
                    return state
                }())
        }
        .padding()
    }
}