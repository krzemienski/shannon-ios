//
//  MonitoringDashboardView.swift
//  ClaudeCode
//
//  Main monitoring dashboard view (Tasks 831-835)
//

import SwiftUI
import Charts

/// Main monitoring dashboard view
struct MonitoringDashboardView: View {
    @StateObject private var telemetry = TelemetryManager.shared
    @StateObject private var metricsCollector = MetricsCollector()
    @StateObject private var performanceTracker = PerformanceTracker()
    @StateObject private var crashReporter = CrashReporter.shared
    @State private var selectedTab = MonitoringTab.overview
    @State private var refreshTimer: Timer?
    
    enum MonitoringTab: String, CaseIterable {
        case overview = "Overview"
        case ssh = "SSH"
        case performance = "Performance"
        case metrics = "Metrics"
        case crashes = "Crashes"
        case logs = "Logs"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar.xaxis"
            case .ssh: return "terminal"
            case .performance: return "speedometer"
            case .metrics: return "chart.line.uptrend.xyaxis"
            case .crashes: return "exclamationmark.triangle"
            case .logs: return "doc.text"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(MonitoringTab.allCases, id: \.self) { tab in
                            TabButton(
                                title: tab.rawValue,
                                icon: tab.icon,
                                isSelected: selectedTab == tab
                            ) {
                                withAnimation(.spring()) {
                                    selectedTab = tab
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                
                // Content
                ScrollView {
                    contentView
                        .padding()
                }
            }
            .navigationTitle("Monitoring Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: exportData) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .overview:
            OverviewSection(
                telemetry: telemetry,
                performance: performanceTracker,
                crashes: crashReporter
            )
            
        case .ssh:
            SSHMonitoringSection()
            
        case .performance:
            PerformanceSection(tracker: performanceTracker)
            
        case .metrics:
            MetricsSection(collector: metricsCollector)
            
        case .crashes:
            CrashesSection(reporter: crashReporter)
            
        case .logs:
            LogsSection(telemetry: telemetry)
        }
    }
    
    private func refreshData() {
        // Refresh data from all sources
        Task {
            await telemetry.flush()
        }
    }
    
    private func exportData() {
        // Export monitoring data
        // Implementation would show share sheet with exported data
    }
    
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            refreshData()
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Overview Section

struct OverviewSection: View {
    @ObservedObject var telemetry: TelemetryManager
    @ObservedObject var performance: PerformanceTracker
    @ObservedObject var crashes: CrashReporter
    
    var body: some View {
        VStack(spacing: 20) {
            // Key metrics cards
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(
                    title: "Performance Score",
                    value: String(format: "%.0f", performance.performanceScore),
                    subtitle: "Overall health",
                    color: performance.performanceScore > 80 ? .green : 
                           performance.performanceScore > 60 ? .orange : .red
                )
                
                MetricCard(
                    title: "Success Rate",
                    value: String(format: "%.1f%%", telemetry.metrics.successRate * 100),
                    subtitle: "\(telemetry.metrics.successfulOperations)/\(telemetry.metrics.totalOperations)",
                    color: telemetry.metrics.successRate > 0.95 ? .green : .orange
                )
                
                MetricCard(
                    title: "Active Operations",
                    value: "\(performance.activeSpans.count)",
                    subtitle: "Currently running",
                    color: .blue
                )
                
                MetricCard(
                    title: "Crash Count",
                    value: "\(crashes.crashCount)",
                    subtitle: crashes.crashCount == 0 ? "No crashes" : "Needs attention",
                    color: crashes.crashCount == 0 ? .green : .red
                )
            }
            
            // Recent activity chart
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity")
                    .font(.headline)
                
                if #available(iOS 16.0, *) {
                    Chart(telemetry.recentEvents.suffix(20)) { event in
                        BarMark(
                            x: .value("Time", event.timestamp),
                            y: .value("Level", event.level.rawValue)
                        )
                        .foregroundStyle(colorForLevel(event.level))
                    }
                    .frame(height: 150)
                } else {
                    // Fallback for older iOS versions
                    SimpleBarChart(
                        data: telemetry.recentEvents.suffix(20).map { 
                            Double(levelValue($0.level))
                        }
                    )
                    .frame(height: 150)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // System health indicators
            VStack(alignment: .leading, spacing: 12) {
                Text("System Health")
                    .font(.headline)
                
                HealthIndicator(
                    label: "Memory Usage",
                    value: getMemoryUsage(),
                    maxValue: 100,
                    unit: "%",
                    warningThreshold: 80,
                    criticalThreshold: 90
                )
                
                HealthIndicator(
                    label: "Error Rate",
                    value: telemetry.metrics.errorCount > 0 ? 
                           Double(telemetry.metrics.errorCount) / Double(telemetry.metrics.totalOperations) * 100 : 0,
                    maxValue: 100,
                    unit: "%",
                    warningThreshold: 5,
                    criticalThreshold: 10
                )
                
                HealthIndicator(
                    label: "Avg Response Time",
                    value: telemetry.metrics.averageOperationTime * 1000,
                    maxValue: 5000,
                    unit: "ms",
                    warningThreshold: 2000,
                    criticalThreshold: 4000
                )
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func colorForLevel(_ level: TelemetryLevel) -> Color {
        switch level {
        case .verbose: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    private func levelValue(_ level: TelemetryLevel) -> Int {
        switch level {
        case .verbose: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        case .critical: return 5
        }
    }
    
    private func getMemoryUsage() -> Double {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            return (usedMemory / Double(totalMemory)) * 100
        }
        
        return 0
    }
}

// MARK: - Components

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .accentColor : .gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct HealthIndicator: View {
    let label: String
    let value: Double
    let maxValue: Double
    let unit: String
    let warningThreshold: Double
    let criticalThreshold: Double
    
    private var normalizedValue: Double {
        min(1.0, max(0, value / maxValue))
    }
    
    private var color: Color {
        if value >= criticalThreshold {
            return .red
        } else if value >= warningThreshold {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(String(format: "%.1f", value))\(unit)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * normalizedValue)
                }
            }
            .frame(height: 8)
        }
    }
}

struct SimpleBarChart: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<data.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.7))
                        .frame(height: geometry.size.height * CGFloat(data[index] / 5.0))
                }
            }
        }
    }
}

// MARK: - Previews

struct MonitoringDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        MonitoringDashboardView()
    }
}