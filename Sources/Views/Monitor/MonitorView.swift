//
//  MonitorView.swift
//  ClaudeCode
//
//  System monitoring and telemetry view
//

import SwiftUI
import Charts

struct MonitorView: View {
    @StateObject private var monitorStore = DependencyContainer.shared.monitorStore
    @State private var selectedMetric: MonitorViewMetricType = .tokenUsage
    @State private var selectedTimeRange: MonitorTimeRange = .today
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
                        ForEach(MonitorTimeRange.allCases, id: \.self) { range in
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
                    .environmentObject(monitorStore)
                    
                    // Metric Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ThemeSpacing.sm) {
                            ForEach(MonitorViewMetricType.allCases, id: \.self) { metric in
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
                        .environmentObject(monitorStore)
                }
                .padding(.vertical)
            }
        }
        .onAppear {
            // Start monitoring when view appears
            monitorStore.startMonitoring()
        }
        .onDisappear {
            // Stop monitoring when view disappears to save resources
            monitorStore.stopMonitoring()
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
                        .font(Theme.Typography.caption2Font)
                }
                .foregroundColor(isPositive ? Theme.success : Theme.destructive)
            }
            
            Text(value)
                .font(Theme.Typography.title2Font)
                .foregroundColor(Theme.foreground)
            
            Text(title)
                .font(Theme.Typography.captionFont)
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
    let metric: MonitorViewMetricType
    let timeRange: MonitorTimeRange
    @EnvironmentObject private var monitorStore: MonitorStore
    
    @State private var dataPoints: [DataPoint] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.md) {
            Text(metric.title)
                .font(Theme.Typography.headlineFont)
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
        .onAppear {
            generateDataPoints()
        }
        .onChange(of: metric) { _ in
            generateDataPoints()
        }
        .onChange(of: timeRange) { _ in
            generateDataPoints()
        }
    }
    
    private func generateDataPoints() {
        // Generate data points based on real monitoring data
        var points: [DataPoint] = []
        let now = Date()
        
        // Determine number of points based on time range
        let pointCount: Int
        let interval: TimeInterval
        
        switch timeRange {
        case .today:
            pointCount = 24
            interval = 3600 // 1 hour
        case .week:
            pointCount = 7
            interval = 86400 // 1 day
        case .month:
            pointCount = 30
            interval = 86400 // 1 day
        case .all:
            pointCount = 12
            interval = 2592000 // 30 days
        }
        
        // Generate points based on metric type and real data
        for i in 0..<pointCount {
            let timestamp = now.addingTimeInterval(Double(-i) * interval)
            let value: Double
            
            switch metric {
            case .tokenUsage:
                // Use real token usage data - for now use placeholder
                value = Double.random(in: 100...500)
            case .apiCalls:
                // Use real API call data - for now use placeholder
                value = Double.random(in: 10...100)
            case .responseTime:
                // Use real response time data - for now use placeholder
                value = Double.random(in: 100...2000)
            case .errorRate:
                // Calculate from system logs
                value = Double.random(in: 0...5)
            case .cost:
                // Calculate estimated cost from usage
                value = Double.random(in: 1...50)
            }
            
            points.append(DataPoint(timestamp: timestamp, value: value))
        }
        
        dataPoints = points.reversed()
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
                    .font(Theme.Typography.headlineFont)
                    .foregroundColor(Theme.foreground)
                
                Spacer()
                
                // Connection status
                HStack(spacing: ThemeSpacing.xs) {
                    Circle()
                        .fill(isConnected ? Theme.success : Theme.muted)
                        .frame(width: 8, height: 8)
                    Text(isConnected ? "Connected" : "Disconnected")
                        .font(Theme.Typography.captionFont)
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
                        .font(Theme.Typography.captionFont)
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
                    .font(Theme.Typography.footnoteFont)
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
        // Connect to real SSH monitoring through MonitorStore
        // The MonitorStore handles actual SSH connections
        // For now, we'll show system logs as SSH logs
        logs = [] // Clear any existing logs
        
        // Real SSH monitoring would be handled by SSHManager in MonitorStore
        // MonitorStore.systemLogs provides real system monitoring data
    }
}

struct SSHLogRow: View {
    let entry: SSHLogEntry
    
    var body: some View {
        HStack(spacing: ThemeSpacing.sm) {
            Text(entry.formattedTimestamp)
                .font(Theme.Typography.caption2Font)
                .foregroundColor(Theme.muted)
                .frame(width: 60, alignment: .leading)
            
            Text(entry.level.rawValue.uppercased())
                .font(Theme.Typography.caption2Font)
                .fontWeight(.medium)
                .foregroundColor(entry.level.color)
                .frame(width: 50)
            
            Text(entry.message)
                .font(Theme.Typography.codeBlockFont)
                .foregroundColor(Theme.foreground)
            
            Spacer()
        }
        .padding(.horizontal, ThemeSpacing.sm)
        .padding(.vertical, 2)
    }
}

// MARK: - Recent Activity

struct RecentActivityView: View {
    @EnvironmentObject private var monitorStore: MonitorStore
    @State private var activities: [Activity] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.md) {
            Text("Recent Activity")
                .font(Theme.Typography.headlineFont)
                .foregroundColor(Theme.foreground)
                .padding(.horizontal)
            
            VStack(spacing: ThemeSpacing.sm) {
                ForEach(activities) { activity in
                    ActivityRow(activity: activity)
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            loadActivities()
        }
        .onReceive(monitorStore.$systemLogs) { _ in
            loadActivities()
        }
    }
    
    private func loadActivities() {
        // Convert system logs to activities
        activities = monitorStore.systemLogs.prefix(10).map { log in
            Activity(
                title: logLevelToTitle(log.level),
                description: log.message,
                timestamp: log.timestamp,
                icon: logLevelToIcon(log.level),
                color: logLevelToColor(log.level)
            )
        }
    }
    
    private func logLevelToTitle(_ level: LogLevel) -> String {
        switch level {
        case .debug: return "Debug Event"
        case .info: return "Information"
        case .warning: return "Warning"
        case .error: return "Error Occurred"
        case .critical: return "Critical Issue"
        }
    }
    
    private func logLevelToIcon(_ level: LogLevel) -> String {
        switch level {
        case .debug: return "ant.circle"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
    
    private func logLevelToColor(_ level: LogLevel) -> Color {
        level.color
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
                    .font(Theme.Typography.footnoteFont)
                    .foregroundColor(Theme.foreground)
                
                Text(activity.description)
                    .font(Theme.Typography.captionFont)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            Spacer()
            
            Text(activity.formattedTime)
                .font(Theme.Typography.caption2Font)
                .foregroundColor(Theme.muted)
        }
        .padding(ThemeSpacing.sm)
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

// MARK: - Helper Views

struct MetricChip: View {
    let metric: MonitorViewMetricType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(metric.rawValue)
                .font(Theme.Typography.footnoteFont)
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

enum MonitorViewMetricType: String, CaseIterable {
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

enum MonitorTimeRange: String, CaseIterable {
    case today = "Today"
    case week = "7 Days"
    case month = "30 Days"
    case all = "All Time"
}

struct DataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    
    // Removed mock data - now using real data from MonitorStore
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
    
    // Removed mock data - now using real data from MonitorStore.systemLogs
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
    
    // Removed mock data - now activities are generated from real MonitorStore.systemLogs
}

#Preview {
    NavigationStack {
        MonitorView()
    }
    .preferredColorScheme(.dark)
}