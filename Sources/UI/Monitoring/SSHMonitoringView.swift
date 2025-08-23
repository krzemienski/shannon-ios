// Sources/UI/Monitoring/SSHMonitoringView.swift
// Task: SSH Monitoring View Implementation
// This file provides the SSH connection monitoring interface

import SwiftUI

/// SSH monitoring view
public struct SSHMonitoringView: View {
    let connections: [SSHConnectionInfo]
    
    @State private var selectedConnection: SSHConnectionInfo?
    @State private var showingConnectionDetails = false
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary card
                SSHSummaryCard(connections: connections)
                
                // Connection list
                if connections.isEmpty {
                    EmptySSHView()
                } else {
                    ForEach(connections) { connection in
                        SSHConnectionCard(
                            connection: connection,
                            onTap: {
                                selectedConnection = connection
                                showingConnectionDetails = true
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingConnectionDetails) {
            if let connection = selectedConnection {
                SSHConnectionDetailsView(connection: connection)
            }
        }
    }
}

/// SSH summary card
struct SSHSummaryCard: View {
    let connections: [SSHConnectionInfo]
    
    var activeConnections: Int {
        connections.filter { $0.status == .connected }.count
    }
    
    var totalBytesTransferred: Int64 {
        connections.reduce(0) { $0 + $1.bytesTransferred }
    }
    
    var totalDuration: TimeInterval {
        connections.reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(.purple)
                Text("SSH Overview")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(activeConnections)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(connections.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatBytes(totalBytesTransferred))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("Transferred")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

/// SSH connection card
struct SSHConnectionCard: View {
    let connection: SSHConnectionInfo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: connection.status.icon)
                        .foregroundColor(connection.status.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(connection.host):\(connection.port)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(connection.status.text)
                            .font(.caption)
                            .foregroundColor(connection.status.color)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Stats
                HStack(spacing: 20) {
                    StatItem(
                        icon: "clock",
                        value: formatDuration(connection.duration),
                        label: "Duration"
                    )
                    
                    StatItem(
                        icon: "arrow.up.arrow.down",
                        value: formatBytes(connection.bytesTransferred),
                        label: "Data"
                    )
                    
                    if connection.status == .connected {
                        StatItem(
                            icon: "antenna.radiowaves.left.and.right",
                            value: "Active",
                            label: "Status",
                            color: .green
                        )
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

/// Stat item component
struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .primary
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Empty SSH view
struct EmptySSHView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No SSH Connections")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("SSH connection monitoring will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// SSH connection details view
struct SSHConnectionDetailsView: View {
    let connection: SSHConnectionInfo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection info
                    ConnectionInfoSection(connection: connection)
                    
                    // Performance metrics
                    PerformanceMetricsSection(connection: connection)
                    
                    // Session details
                    SessionDetailsSection(connection: connection)
                    
                    // Actions
                    if connection.status == .connected {
                        ActionsSection()
                    }
                }
                .padding()
            }
            .navigationTitle("Connection Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Connection info section
struct ConnectionInfoSection: View {
    let connection: SSHConnectionInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Connection Information", systemImage: "info.circle")
                .font(.headline)
            
            Divider()
            
            DetailRow(label: "Host", value: connection.host)
            DetailRow(label: "Port", value: "\(connection.port)")
            DetailRow(label: "Status", value: connection.status.text, color: connection.status.color)
            DetailRow(label: "Connection ID", value: connection.id.uuidString.prefix(8) + "...")
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Performance metrics section
struct PerformanceMetricsSection: View {
    let connection: SSHConnectionInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Performance Metrics", systemImage: "speedometer")
                .font(.headline)
            
            Divider()
            
            DetailRow(label: "Duration", value: formatDuration(connection.duration))
            DetailRow(label: "Data Transferred", value: formatBytes(connection.bytesTransferred))
            DetailRow(label: "Average Speed", value: calculateSpeed())
            DetailRow(label: "Latency", value: "12ms") // Simulated
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func calculateSpeed() -> String {
        guard connection.duration > 0 else { return "N/A" }
        
        let bytesPerSecond = Double(connection.bytesTransferred) / connection.duration
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }
}

/// Session details section
struct SessionDetailsSection: View {
    let connection: SSHConnectionInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Session Details", systemImage: "rectangle.connected.to.line.below")
                .font(.headline)
            
            Divider()
            
            DetailRow(label: "Protocol", value: "SSH-2.0")
            DetailRow(label: "Cipher", value: "AES256-GCM")
            DetailRow(label: "Compression", value: "Enabled")
            DetailRow(label: "Keep-Alive", value: "30s")
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Actions section
struct ActionsSection: View {
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {}) {
                Label("View Logs", systemImage: "doc.text")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: {}) {
                Label("Disconnect", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Detail row component
struct DetailRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Extensions

extension SSHConnectionInfo.ConnectionStatus {
    var text: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .failed: return "Failed"
        }
    }
}