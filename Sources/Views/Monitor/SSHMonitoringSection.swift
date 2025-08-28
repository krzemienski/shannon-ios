//
//  SSHMonitoringSection.swift
//  ClaudeCode
//
//  SSH monitoring dashboard section (Tasks 836-840)
//

import SwiftUI
import Charts

/// SSH monitoring section view
struct SSHMonitoringSection: View {
    @StateObject private var sshMonitor = SSHMonitor()
    @State private var selectedHost: String?
    @State private var showingExportSheet = false
    @State private var exportedData: Data?
    
    var body: some View {
        VStack(spacing: 20) {
            // Connection overview
            connectionOverview
            
            // Active operations
            if !sshMonitor.activeOperations.isEmpty {
                activeOperationsSection
            }
            
            // Connection stats by host
            if !sshMonitor.connectionStats.isEmpty {
                hostStatsSection
            }
            
            // Performance metrics
            performanceMetricsSection
            
            // Recent operations
            recentOperationsSection
            
            // Alerts
            if !sshMonitor.alerts.isEmpty {
                alertsSection
            }
        }
    }
    
    // MARK: - Connection Overview
    
    private var connectionOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Overview")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Active Connections",
                    value: "\(sshMonitor.globalStats.activeConnections)",
                    icon: "network",
                    color: .green
                )
                
                StatCard(
                    title: "Total Connections",
                    value: "\(sshMonitor.globalStats.totalConnections)",
                    icon: "link",
                    color: .blue
                )
                
                StatCard(
                    title: "Commands Executed",
                    value: "\(sshMonitor.globalStats.totalCommands)",
                    icon: "terminal",
                    color: sshMonitor.globalStats.successRate > 0.95 ? .green : .orange
                )
                
                StatCard(
                    title: "Data Transferred",
                    value: formatBytes(sshMonitor.globalStats.totalBytesTransferred),
                    icon: "arrow.up.arrow.down",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Active Operations
    
    private var activeOperationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Operations")
                    .font(.headline)
                Spacer()
                Text("\(sshMonitor.activeOperations.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            ForEach(Array(sshMonitor.activeOperations.values), id: \.startTime) { operation in
                ActiveOperationRow(operation: operation)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Host Stats
    
    private var hostStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Stats by Host")
                .font(.headline)
            
            ForEach(Array(sshMonitor.connectionStats.keys.sorted()), id: \.self) { hostKey in
                if let stats = sshMonitor.connectionStats[hostKey] {
                    HostStatsRow(
                        host: hostKey,
                        stats: stats,
                        isSelected: selectedHost == hostKey
                    ) {
                        withAnimation {
                            selectedHost = selectedHost == hostKey ? nil : hostKey
                        }
                    }
                    
                    if selectedHost == hostKey {
                        HostDetailsView(host: hostKey, stats: stats)
                            .transition(.opacity)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Performance Metrics
    
    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
            
            // Metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                PerformanceMetricView(
                    title: "Avg Latency",
                    value: String(format: "%.2fs", sshMonitor.performanceMetrics.averageLatency),
                    isGood: sshMonitor.performanceMetrics.averageLatency < 1.0
                )
                
                PerformanceMetricView(
                    title: "Throughput",
                    value: String(format: "%.0f ops/min", sshMonitor.performanceMetrics.throughput),
                    isGood: sshMonitor.performanceMetrics.throughput > 10
                )
                
                PerformanceMetricView(
                    title: "Error Rate",
                    value: String(format: "%.1f%%", sshMonitor.performanceMetrics.errorRate * 100),
                    isGood: sshMonitor.performanceMetrics.errorRate < 0.05
                )
                
                PerformanceMetricView(
                    title: "Load",
                    value: String(format: "%.0f%%", sshMonitor.performanceMetrics.currentLoad * 100),
                    isGood: sshMonitor.performanceMetrics.currentLoad < 0.8
                )
            }
            
            // Command frequency chart
            if !sshMonitor.performanceMetrics.commandFrequency.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Most Used Commands")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(sshMonitor.performanceMetrics.commandFrequency.sorted(by: { $0.value > $1.value }).prefix(5)), id: \.key) { command, count in
                        HStack {
                            Text(command)
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 8)
            }
            
            // Slowest commands
            if !sshMonitor.performanceMetrics.slowestCommands.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Slowest Commands")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(sshMonitor.performanceMetrics.slowestCommands.prefix(3), id: \.timestamp) { slow in
                        HStack {
                            Text(slow.command)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.2fs", slow.duration))
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Recent Operations
    
    private var recentOperationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Operations")
                    .font(.headline)
                Spacer()
                Button(action: exportOperations) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                }
            }
            
            if sshMonitor.recentOperations.isEmpty {
                Text("No recent operations")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(sshMonitor.recentOperations.suffix(10)), id: \.id) { operation in
                            OperationCard(operation: operation)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .sheet(isPresented: $showingExportSheet) {
            if let data = exportedData {
                SSHShareSheet(activityItems: [data])
            }
        }
    }
    
    // MARK: - Alerts
    
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Alerts")
                    .font(.headline)
                Spacer()
                Button(action: { sshMonitor.alerts.removeAll() }) {
                    Text("Clear")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            ForEach(sshMonitor.alerts.prefix(5)) { alert in
                AlertRow(alert: alert)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func exportOperations() {
        do {
            let exportData = SSHExportData(
                exportDate: Date(),
                globalStats: sshMonitor.globalStats,
                performanceMetrics: sshMonitor.performanceMetrics,
                recentOperations: sshMonitor.recentOperations,
                connectionStats: Array(sshMonitor.connectionStats.values)
            )
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            exportedData = try encoder.encode(exportData)
            showingExportSheet = true
        } catch {
            // Handle error
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Component Views

struct SSHStatCard: View {
    let title: String
    let value: String
    let trend: String?
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            if let trend = trend {
                Text(trend)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
}

struct ActiveOperationRow: View {
    let operation: SSHOperationMetrics
    
    private var duration: String {
        let elapsed = Date().timeIntervalSince(operation.startTime)
        return String(format: "%.1fs", elapsed)
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 8)
                        .scaleEffect(1.5)
                        .opacity(0.5)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: UUID()
                        )
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(operation.command)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(operation.host)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(duration)
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.vertical, 4)
    }
}

struct HostStatsRow: View {
    let host: String
    let stats: SSHConnectionStats
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(host)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Label(stats.isActive ? "Active" : "Idle", systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundColor(stats.isActive ? .green : .gray)
                        
                        Label("\(stats.totalCommands)", systemImage: "terminal")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HostDetailsView: View {
    let host: String
    let stats: SSHConnectionStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                DetailItem(label: "Total Connections", value: "\(stats.totalConnections)")
                DetailItem(label: "Success Rate", value: String(format: "%.1f%%", stats.successRate * 100))
            }
            
            HStack(spacing: 16) {
                DetailItem(label: "Commands", value: "\(stats.totalCommands)")
                DetailItem(label: "Failed", value: "\(stats.failedCommands)")
            }
            
            HStack(spacing: 16) {
                DetailItem(label: "Avg Connection Time", value: String(format: "%.2fs", stats.averageConnectionTime))
                DetailItem(label: "Avg Latency", value: String(format: "%.2fs", stats.averageLatency))
            }
            
            if stats.totalBytesTransferred > 0 {
                DetailItem(label: "Data Transferred", value: formatBytes(stats.totalBytesTransferred))
            }
            
            if let lastConnection = stats.lastConnectionTime {
                DetailItem(label: "Last Connection", value: RelativeDateTimeFormatter.shared.string(for: lastConnection)!)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

struct DetailItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PerformanceMetricView: View {
    let title: String
    let value: String
    let isGood: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(isGood ? .green : .orange)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
}

struct OperationCard: View {
    let operation: SSHOperation
    
    private var statusColor: Color {
        operation.success ? .green : .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                
                Text(operation.command)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            Text(operation.host)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text(String(format: "%.2fs", operation.duration))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(width: 100)
        .background(Color.white)
        .cornerRadius(8)
    }
}

struct AlertRow: View {
    let alert: SSHAlert
    
    private var alertColor: Color {
        switch alert.severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: iconForLevel(alert.severity))
                .font(.caption)
                .foregroundColor(alertColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.message)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text(RelativeDateTimeFormatter.shared.string(for: alert.timestamp)!)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func iconForLevel(_ level: SSHAlert.AlertSeverity) -> String {
        switch level {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
}

// MARK: - Share Sheet

struct SSHShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Date Formatter

extension RelativeDateTimeFormatter {
    nonisolated(unsafe) static let shared: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

// MARK: - Export Data

struct SSHExportData: Codable {
    let exportDate: Date
    let globalStats: SSHGlobalStats
    let performanceMetrics: SSHPerformanceMetrics
    let recentOperations: [SSHOperation]
    let connectionStats: [SSHConnectionStats]
}

// MARK: - Previews

struct SSHMonitoringSection_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            SSHMonitoringSection()
                .padding()
        }
    }
}