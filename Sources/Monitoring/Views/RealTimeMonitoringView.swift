//
//  RealTimeMonitoringView.swift
//  ClaudeCode
//
//  Real-time monitoring view with live metrics and animated charts
//

import SwiftUI
import Charts
import Combine

struct RealTimeMonitoringView: View {
    @StateObject private var viewModel = RealTimeMonitoringViewModel()
    @State private var selectedTimeWindow = TimeWindow.minute
    @State private var isPaused = false
    @State private var showingAlertDetails = false
    @State private var selectedAlert: MonitoringAlert?
    
    enum TimeWindow: String, CaseIterable {
        case minute = "1 Min"
        case fiveMinutes = "5 Min"
        case fifteenMinutes = "15 Min"
        case hour = "1 Hour"
        
        var seconds: Int {
            switch self {
            case .minute: return 60
            case .fiveMinutes: return 300
            case .fifteenMinutes: return 900
            case .hour: return 3600
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with controls
                headerSection
                
                // Live Metrics Grid
                liveMetricsGrid
                
                // Real-time Charts
                realTimeCharts
                
                // Active Alerts
                activeAlerts
                
                // System Status
                systemStatus
                
                // Network Activity
                networkActivity
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Real-Time Monitoring")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { isPaused.toggle() }) {
                    Image(systemName: isPaused ? "play.circle" : "pause.circle")
                        .foregroundColor(isPaused ? .orange : .green)
                }
                
                Button(action: { viewModel.exportMetrics() }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingAlertDetails) {
            if let alert = selectedAlert {
                AlertDetailView(alert: alert)
            }
        }
        .onAppear {
            if !isPaused {
                viewModel.startMonitoring()
            }
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Monitoring")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Updated: \(Date(), formatter: timeFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(isPaused ? Color.orange : Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: !isPaused)
                    
                    Text(isPaused ? "Paused" : "Live")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(20)
            }
            
            // Time Window Selector
            Picker("Time Window", selection: $selectedTimeWindow) {
                ForEach(TimeWindow.allCases, id: \.self) { window in
                    Text(window.rawValue).tag(window)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Live Metrics Grid
    
    private var liveMetricsGrid: some View {
        VStack(spacing: 12) {
            Text("Live Metrics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                LiveMetricCard(
                    metric: viewModel.cpuMetric,
                    icon: "cpu",
                    color: .blue
                )
                
                LiveMetricCard(
                    metric: viewModel.memoryMetric,
                    icon: "memorychip",
                    color: .purple
                )
                
                LiveMetricCard(
                    metric: viewModel.networkMetric,
                    icon: "network",
                    color: .green
                )
                
                LiveMetricCard(
                    metric: viewModel.diskMetric,
                    icon: "internaldrive",
                    color: .orange
                )
                
                LiveMetricCard(
                    metric: viewModel.requestMetric,
                    icon: "arrow.up.arrow.down.circle",
                    color: .cyan
                )
                
                LiveMetricCard(
                    metric: viewModel.errorMetric,
                    icon: "exclamationmark.triangle",
                    color: .red
                )
            }
        }
    }
    
    // MARK: - Real-Time Charts
    
    private var realTimeCharts: some View {
        VStack(spacing: 16) {
            Text("Performance Trends")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // CPU & Memory Chart
            ChartCard(
                title: "CPU & Memory",
                data: viewModel.performanceHistory,
                primaryColor: .blue,
                secondaryColor: .purple
            )
            
            // Network Activity Chart
            ChartCard(
                title: "Network Activity",
                data: viewModel.networkHistory,
                primaryColor: .green,
                secondaryColor: .orange
            )
            
            // Request/Error Rate Chart
            ChartCard(
                title: "Request & Error Rates",
                data: viewModel.requestHistory,
                primaryColor: .cyan,
                secondaryColor: .red
            )
        }
    }
    
    // MARK: - Active Alerts
    
    private var activeAlerts: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Active Alerts")
                    .font(.headline)
                
                Spacer()
                
                if !viewModel.activeAlerts.isEmpty {
                    Text("\(viewModel.activeAlerts.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
            if viewModel.activeAlerts.isEmpty {
                Text("No active alerts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(8)
            } else {
                ForEach(viewModel.activeAlerts) { alert in
                    AlertRow(alert: alert) {
                        selectedAlert = alert
                        showingAlertDetails = true
                    }
                }
            }
        }
    }
    
    // MARK: - System Status
    
    private var systemStatus: some View {
        VStack(spacing: 12) {
            Text("System Status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            SystemStatusGrid(status: viewModel.systemStatus)
        }
    }
    
    // MARK: - Network Activity
    
    private var networkActivity: some View {
        VStack(spacing: 12) {
            Text("Network Activity")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            NetworkActivityList(activities: viewModel.recentNetworkActivities)
        }
    }
    
    // MARK: - Helpers
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Live Metric Card

struct LiveMetricCard: View {
    let metric: LiveMetric
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(metric.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if metric.trend != .stable {
                    Image(systemName: metric.trend == .increasing ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                        .foregroundColor(metric.trend == .increasing ? .green : .red)
                }
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(metric.formattedValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .animation(.default, value: metric.value)
                
                Text(metric.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Mini sparkline
            SparklineView(data: metric.history, color: color)
                .frame(height: 30)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Sparkline View

struct SparklineView: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }
                
                let maxValue = data.max() ?? 1
                let minValue = data.min() ?? 0
                let range = maxValue - minValue
                
                let xStep = geometry.size.width / CGFloat(data.count - 1)
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * xStep
                    let normalizedValue = range > 0 ? (value - minValue) / range : 0.5
                    let y = geometry.size.height * (1 - normalizedValue)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 2)
        }
    }
}

// MARK: - Chart Card

struct ChartCard: View {
    let title: String
    let data: [ChartDataPoint]
    let primaryColor: Color
    let secondaryColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Chart placeholder with animated gradient
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [primaryColor.opacity(0.2), secondaryColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                if !data.isEmpty {
                    LineChartView(data: data, primaryColor: primaryColor, secondaryColor: secondaryColor)
                        .padding()
                }
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Line Chart View

struct LineChartView: View {
    let data: [ChartDataPoint]
    let primaryColor: Color
    let secondaryColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Primary line
                Path { path in
                    guard !data.isEmpty else { return }
                    
                    let xStep = geometry.size.width / CGFloat(data.count - 1)
                    let maxValue = data.map(\.primaryValue).max() ?? 1
                    
                    for (index, point) in data.enumerated() {
                        let x = CGFloat(index) * xStep
                        let y = geometry.size.height * (1 - point.primaryValue / maxValue)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(primaryColor, lineWidth: 2)
                
                // Secondary line
                if data.first?.secondaryValue != nil {
                    Path { path in
                        let xStep = geometry.size.width / CGFloat(data.count - 1)
                        let maxValue = data.compactMap(\.secondaryValue).max() ?? 1
                        
                        for (index, point) in data.enumerated() {
                            guard let value = point.secondaryValue else { continue }
                            
                            let x = CGFloat(index) * xStep
                            let y = geometry.size.height * (1 - value / maxValue)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(secondaryColor, lineWidth: 2)
                }
            }
        }
    }
}

// MARK: - Alert Row

struct AlertRow: View {
    let alert: MonitoringAlert
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(alert.severityColor)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(alert.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Text(alert.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - System Status Grid

struct SystemStatusGrid: View {
    let status: SystemStatus
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatusIndicator(
                title: "API",
                status: status.apiStatus,
                icon: "server.rack"
            )
            
            StatusIndicator(
                title: "Database",
                status: status.databaseStatus,
                icon: "cylinder"
            )
            
            StatusIndicator(
                title: "Cache",
                status: status.cacheStatus,
                icon: "memorychip"
            )
            
            StatusIndicator(
                title: "Queue",
                status: status.queueStatus,
                icon: "tray.full"
            )
            
            StatusIndicator(
                title: "Storage",
                status: status.storageStatus,
                icon: "externaldrive"
            )
            
            StatusIndicator(
                title: "CDN",
                status: status.cdnStatus,
                icon: "globe"
            )
        }
    }
}

struct StatusIndicator: View {
    let title: String
    let status: ServiceStatus
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(status.color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
                
                Text(status.description)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Network Activity List

struct NetworkActivityList: View {
    let activities: [NetworkActivity]
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(activities) { activity in
                HStack {
                    Circle()
                        .fill(activity.statusColor)
                        .frame(width: 6, height: 6)
                    
                    Text(activity.endpoint)
                        .font(.system(.caption, design: .monospaced))
                    
                    Spacer()
                    
                    Text("\(activity.responseTime)ms")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(activity.statusCode)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(activity.statusColor)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Alert Detail View

struct AlertDetailView: View {
    let alert: MonitoringAlert
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Alert Header
                    HStack {
                        Circle()
                            .fill(alert.severityColor)
                            .frame(width: 12, height: 12)
                        
                        Text(alert.severity.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(alert.severityColor)
                        
                        Spacer()
                        
                        Text(alert.timestamp, formatter: dateFormatter)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Alert Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text(alert.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(alert.message)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Affected Services
                    if !alert.affectedServices.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Affected Services")
                                .font(.headline)
                            
                            ForEach(alert.affectedServices, id: \.self) { service in
                                Label(service, systemImage: "server.rack")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // Recommended Actions
                    if !alert.recommendedActions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommended Actions")
                                .font(.headline)
                            
                            ForEach(alert.recommendedActions, id: \.self) { action in
                                Label(action, systemImage: "checkmark.circle")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // Metrics
                    if !alert.metrics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Related Metrics")
                                .font(.headline)
                            
                            ForEach(Array(alert.metrics.keys.sorted()), id: \.self) { key in
                                if let value = alert.metrics[key] {
                                    HStack {
                                        Text(key)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text("\(value)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Alert Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Preview

struct RealTimeMonitoringView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RealTimeMonitoringView()
        }
    }
}