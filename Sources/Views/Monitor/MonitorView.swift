//
//  MonitorView.swift
//  ClaudeCode
//
//  System monitoring and telemetry view
//

import SwiftUI
import Charts

struct MonitorView: View {
    @State private var selectedMetric: MetricType = .tokenUsage
    @State private var selectedTimeRange: TimeRange = .today
    @State private var isSSHConnected = false
    @State private var sshLogs: [SSHLogEntry] = []
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: ThemeSpacing.lg) {
                    // Quick Stats
                    QuickStatsView()
                    
                    // Time Range Selector
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Metrics Chart
                    MetricsChartView(
                        metric: selectedMetric,
                        timeRange: selectedTimeRange
                    )
                    
                    // Metric Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ThemeSpacing.sm) {
                            ForEach(MetricType.allCases, id: \.self) { metric in
                                MetricChip(
                                    metric: metric,
                                    isSelected: selectedMetric == metric
                                ) {
                                    selectedMetric = metric
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // SSH Monitor Section
                    SSHMonitorSection(
                        isConnected: $isSSHConnected,
                        logs: $sshLogs
                    )
                    
                    // Recent Activity
                    RecentActivityView()
                }
                .padding(.vertical)
            }
        }
    }
}

// MARK: - Quick Stats

struct QuickStatsView: View {
    var body: some View {
        VStack(spacing: ThemeSpacing.md) {
            HStack(spacing: ThemeSpacing.md) {
                QuickStatCard(
                    title: "Total Tokens",
                    value: "128.5K",
                    change: "+12.3%",
                    isPositive: false,
                    icon: "cube"
                )
                
                QuickStatCard(
                    title: "API Calls",
                    value: "342",
                    change: "+8.7%",
                    isPositive: true,
                    icon: "network"
                )
            }
            
            HStack(spacing: ThemeSpacing.md) {
                QuickStatCard(
                    title: "Avg Response",
                    value: "1.2s",
                    change: "-15%",
                    isPositive: true,
                    icon: "timer"
                )
                
                QuickStatCard(
                    title: "Success Rate",
                    value: "99.2%",
                    change: "+0.3%",
                    isPositive: true,
                    icon: "checkmark.circle"
                )
            }
        }
        .padding(.horizontal)
    }
}

struct QuickStatCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.muted)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10))
                    Text(change)
                        .font(Theme.Typography.caption2)
                }
                .foregroundColor(isPositive ? Theme.success : Theme.destructive)
            }
            
            Text(value)
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.foreground)
            
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.mutedForeground)
        }
        .padding(ThemeSpacing.md)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Metrics Chart

struct MetricsChartView: View {
    let metric: MetricType
    let timeRange: TimeRange
    
    @State private var dataPoints: [DataPoint] = DataPoint.mockData
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.md) {
            Text(metric.title)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.foreground)
                .padding(.horizontal)
            
            Chart(dataPoints) { point in
                if metric == .tokenUsage || metric == .apiCalls {
                    BarMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.primary, Theme.accent],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                } else {
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(Theme.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.primary.opacity(0.3), Theme.primary.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(preset: .aligned) { value in
                    AxisValueLabel()
                        .foregroundStyle(Theme.mutedForeground)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(Theme.mutedForeground)
                    AxisGridLine()
                        .foregroundStyle(Theme.border.opacity(0.5))
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.md)
        .padding(.horizontal)
    }
}

// MARK: - SSH Monitor Section

struct SSHMonitorSection: View {
    @Binding var isConnected: Bool
    @Binding var logs: [SSHLogEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.md) {
            // Header
            HStack {
                Label("SSH Monitor", systemImage: "terminal")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.foreground)
                
                Spacer()
                
                // Connection status
                HStack(spacing: ThemeSpacing.xs) {
                    Circle()
                        .fill(isConnected ? Theme.success : Theme.muted)
                        .frame(width: 8, height: 8)
                    Text(isConnected ? "Connected" : "Disconnected")
                        .font(Theme.Typography.caption)
                        .foregroundColor(isConnected ? Theme.success : Theme.muted)
                }
                
                // Connect button
                Button {
                    isConnected.toggle()
                    if isConnected {
                        startSSHMonitoring()
                    }
                } label: {
                    Text(isConnected ? "Disconnect" : "Connect")
                        .font(Theme.Typography.caption)
                }
                .secondaryButton()
            }
            
            // Logs view
            if isConnected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(logs) { log in
                            SSHLogRow(entry: log)
                        }
                    }
                }
                .frame(height: 200)
                .background(Theme.codeBackground)
                .cornerRadius(Theme.CornerRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .stroke(Theme.border, lineWidth: 1)
                )
            } else {
                Text("Connect to SSH to view live logs")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ThemeSpacing.xl)
                    .background(Theme.card)
                    .cornerRadius(Theme.CornerRadius.sm)
            }
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.md)
        .padding(.horizontal)
    }
    
    private func startSSHMonitoring() {
        // Simulate SSH logs
        logs = SSHLogEntry.mockData
        
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            if isConnected {
                let newLog = SSHLogEntry(
                    timestamp: Date(),
                    level: SSHLogEntry.Level.allCases.randomElement()!,
                    message: ["Process started", "File updated", "Connection established", "Task completed"].randomElement()!
                )
                logs.append(newLog)
                if logs.count > 100 {
                    logs.removeFirst()
                }
            }
        }
    }
}

struct SSHLogRow: View {
    let entry: SSHLogEntry
    
    var body: some View {
        HStack(spacing: ThemeSpacing.sm) {
            Text(entry.formattedTimestamp)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.muted)
                .frame(width: 60, alignment: .leading)
            
            Text(entry.level.rawValue.uppercased())
                .font(Theme.Typography.caption2)
                .fontWeight(.medium)
                .foregroundColor(entry.level.color)
                .frame(width: 50)
            
            Text(entry.message)
                .font(Theme.Typography.codeBlock)
                .foregroundColor(Theme.foreground)
            
            Spacer()
        }
        .padding(.horizontal, ThemeSpacing.sm)
        .padding(.vertical, 2)
    }
}

// MARK: - Recent Activity

struct RecentActivityView: View {
    @State private var activities: [Activity] = Activity.mockData
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.md) {
            Text("Recent Activity")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.foreground)
                .padding(.horizontal)
            
            VStack(spacing: ThemeSpacing.sm) {
                ForEach(activities) { activity in
                    ActivityRow(activity: activity)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ActivityRow: View {
    let activity: Activity
    
    var body: some View {
        HStack(spacing: ThemeSpacing.md) {
            Image(systemName: activity.icon)
                .font(.system(size: 20))
                .foregroundColor(activity.color)
                .frame(width: 32, height: 32)
                .background(activity.color.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.sm)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.foreground)
                
                Text(activity.description)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            Spacer()
            
            Text(activity.formattedTime)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.muted)
        }
        .padding(ThemeSpacing.sm)
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

// MARK: - Helper Views

struct MetricChip: View {
    let metric: MetricType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(metric.rawValue)
                .font(Theme.Typography.footnote)
                .foregroundColor(isSelected ? Theme.foreground : Theme.mutedForeground)
                .padding(.horizontal, ThemeSpacing.md)
                .padding(.vertical, ThemeSpacing.xs)
                .background(isSelected ? Theme.primary : Theme.card)
                .cornerRadius(Theme.CornerRadius.full)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.full)
                        .stroke(isSelected ? Color.clear : Theme.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - Models

enum MetricType: String, CaseIterable {
    case tokenUsage = "Tokens"
    case apiCalls = "API Calls"
    case responseTime = "Response Time"
    case errorRate = "Error Rate"
    case cost = "Cost"
    
    var title: String {
        switch self {
        case .tokenUsage: return "Token Usage"
        case .apiCalls: return "API Calls"
        case .responseTime: return "Response Time (ms)"
        case .errorRate: return "Error Rate (%)"
        case .cost: return "Estimated Cost ($)"
        }
    }
}

enum TimeRange: String, CaseIterable {
    case today = "Today"
    case week = "7 Days"
    case month = "30 Days"
    case all = "All Time"
}

struct DataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    
    static let mockData: [DataPoint] = {
        var data: [DataPoint] = []
        let now = Date()
        for i in 0..<24 {
            data.append(DataPoint(
                timestamp: now.addingTimeInterval(Double(-i) * 3600),
                value: Double.random(in: 100...500)
            ))
        }
        return data.reversed()
    }()
}

struct SSHLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: Level
    let message: String
    
    enum Level: String, CaseIterable {
        case info, warning, error, debug
        
        var color: Color {
            switch self {
            case .info: return Theme.info
            case .warning: return Theme.warning
            case .error: return Theme.destructive
            case .debug: return Theme.muted
            }
        }
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    static let mockData: [SSHLogEntry] = [
        SSHLogEntry(timestamp: Date(), level: .info, message: "SSH connection established"),
        SSHLogEntry(timestamp: Date().addingTimeInterval(-5), level: .debug, message: "Authenticating with public key"),
        SSHLogEntry(timestamp: Date().addingTimeInterval(-10), level: .info, message: "Starting system monitor"),
        SSHLogEntry(timestamp: Date().addingTimeInterval(-15), level: .warning, message: "High memory usage detected"),
        SSHLogEntry(timestamp: Date().addingTimeInterval(-20), level: .error, message: "Failed to read log file"),
    ]
}

struct Activity: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let timestamp: Date
    let icon: String
    let color: Color
    
    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    static let mockData: [Activity] = [
        Activity(
            title: "Chat Started",
            description: "New conversation with Claude 3.5 Haiku",
            timestamp: Date().addingTimeInterval(-300),
            icon: "message.fill",
            color: Theme.primary
        ),
        Activity(
            title: "Tool Executed",
            description: "Read File: package.json",
            timestamp: Date().addingTimeInterval(-600),
            icon: "wrench.fill",
            color: Theme.accent
        ),
        Activity(
            title: "API Request",
            description: "Streaming response completed",
            timestamp: Date().addingTimeInterval(-900),
            icon: "network",
            color: Theme.info
        ),
        Activity(
            title: "Error Occurred",
            description: "Connection timeout",
            timestamp: Date().addingTimeInterval(-1200),
            icon: "exclamationmark.triangle",
            color: Theme.destructive
        )
    ]
}

#Preview {
    NavigationStack {
        MonitorView()
    }
    .preferredColorScheme(.dark)
}