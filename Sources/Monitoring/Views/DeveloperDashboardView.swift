//
//  DeveloperDashboardView.swift
//  ClaudeCode
//
//  Developer dashboard view for technical metrics and performance monitoring
//

import SwiftUI
import Charts

struct DeveloperDashboardView: View {
    @StateObject private var dashboardManager = DashboardManager.shared
    @State private var selectedMetric = MetricType.performance
    @State private var showingDetails = false
    @State private var autoRefresh = true
    
    enum MetricType: String, CaseIterable {
        case performance = "Performance"
        case errors = "Errors"
        case api = "API Health"
        case deployment = "Deployments"
        case quality = "Code Quality"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with Real-time Metrics
                realTimeMetricsHeader
                
                // Metric Selector
                metricSelector
                
                // Selected Metric Details
                selectedMetricView
                
                // Performance Graphs
                performanceGraphs
                
                // Error Analysis
                if selectedMetric == .errors {
                    errorAnalysis
                }
                
                // API Endpoint Health
                if selectedMetric == .api {
                    apiEndpointHealth
                }
                
                // Code Quality Metrics
                if selectedMetric == .quality {
                    codeQualityMetrics
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Developer Dashboard")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { autoRefresh.toggle() }) {
                    Image(systemName: autoRefresh ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                        .foregroundColor(autoRefresh ? .green : .gray)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingDetails.toggle() }) {
                    Image(systemName: "info.circle")
                }
            }
        }
        .onAppear {
            startAutoRefresh()
        }
    }
    
    // MARK: - Real-Time Metrics Header
    
    private var realTimeMetricsHeader: some View {
        VStack(spacing: 16) {
            Text("Real-Time Metrics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RealTimeMetricCard(
                    title: "RPS",
                    value: String(format: "%.0f", dashboardManager.realTimeMetrics.requestsPerSecond),
                    unit: "req/s",
                    status: .normal
                )
                
                RealTimeMetricCard(
                    title: "Latency",
                    value: String(format: "%.0f", dashboardManager.realTimeMetrics.averageLatency),
                    unit: "ms",
                    status: dashboardManager.realTimeMetrics.averageLatency > 500 ? .warning : .normal
                )
                
                RealTimeMetricCard(
                    title: "CPU",
                    value: String(format: "%.0f%%", dashboardManager.realTimeMetrics.cpuUsage),
                    unit: "",
                    status: dashboardManager.realTimeMetrics.cpuUsage > 80 ? .critical : .normal
                )
                
                RealTimeMetricCard(
                    title: "Memory",
                    value: String(format: "%.0f", dashboardManager.realTimeMetrics.memoryUsage),
                    unit: "MB",
                    status: dashboardManager.realTimeMetrics.memoryUsage > 1000 ? .warning : .normal
                )
            }
        }
    }
    
    // MARK: - Metric Selector
    
    private var metricSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MetricType.allCases, id: \.self) { metric in
                    MetricSelectorButton(
                        title: metric.rawValue,
                        isSelected: selectedMetric == metric,
                        action: { selectedMetric = metric }
                    )
                }
            }
        }
    }
    
    // MARK: - Selected Metric View
    
    @ViewBuilder
    private var selectedMetricView: some View {
        switch selectedMetric {
        case .performance:
            performanceMetricsView
        case .errors:
            errorMetricsView
        case .api:
            apiHealthView
        case .deployment:
            deploymentMetricsView
        case .quality:
            codeQualityView
        }
    }
    
    // MARK: - Performance Metrics View
    
    private var performanceMetricsView: some View {
        VStack(spacing: 16) {
            Text("Performance Overview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Response Time Distribution
            ResponseTimeCard(performance: dashboardManager.developerDashboard.performance)
            
            // Throughput Graph
            ThroughputGraph(throughput: dashboardManager.developerDashboard.performance.throughput)
        }
    }
    
    // MARK: - Error Metrics View
    
    private var errorMetricsView: some View {
        VStack(spacing: 16) {
            Text("Error Analysis")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Error Summary
            HStack(spacing: 16) {
                ErrorStatCard(
                    title: "Error Rate",
                    value: String(format: "%.2f%%", dashboardManager.developerDashboard.errors.errorRate),
                    color: .red
                )
                
                ErrorStatCard(
                    title: "Critical",
                    value: "\(dashboardManager.developerDashboard.errors.criticalErrors)",
                    color: .red
                )
                
                ErrorStatCard(
                    title: "Warnings",
                    value: "\(dashboardManager.developerDashboard.errors.warningCount)",
                    color: .orange
                )
            }
            
            // Top Errors List
            TopErrorsList(errors: dashboardManager.developerDashboard.errors.topErrors)
        }
    }
    
    // MARK: - API Health View
    
    private var apiHealthView: some View {
        VStack(spacing: 16) {
            Text("API Health")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Overall API Stats
            HStack(spacing: 16) {
                APIStatCard(
                    title: "Uptime",
                    value: String(format: "%.2f%%", dashboardManager.developerDashboard.apiHealth.uptime),
                    icon: "checkmark.shield"
                )
                
                APIStatCard(
                    title: "Latency",
                    value: String(format: "%.0fms", dashboardManager.developerDashboard.apiHealth.latency),
                    icon: "speedometer"
                )
                
                APIStatCard(
                    title: "Success",
                    value: String(format: "%.1f%%", dashboardManager.developerDashboard.apiHealth.successRate),
                    icon: "checkmark.circle"
                )
            }
        }
    }
    
    // MARK: - Deployment Metrics View
    
    private var deploymentMetricsView: some View {
        VStack(spacing: 16) {
            Text("Deployment Status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            DeploymentCard(deployment: dashboardManager.developerDashboard.deployments)
        }
    }
    
    // MARK: - Code Quality View
    
    private var codeQualityView: some View {
        VStack(spacing: 16) {
            Text("Code Quality")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            CodeQualityCard(quality: dashboardManager.developerDashboard.codeQuality)
        }
    }
    
    // MARK: - Performance Graphs
    
    private var performanceGraphs: some View {
        VStack(spacing: 16) {
            Text("Performance Trends")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Performance chart placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .frame(height: 200)
                .overlay(
                    Text("Performance Graph")
                        .foregroundColor(.secondary)
                )
        }
    }
    
    // MARK: - Error Analysis
    
    private var errorAnalysis: some View {
        VStack(spacing: 16) {
            Text("Error Breakdown")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Error distribution chart
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .frame(height: 200)
                .overlay(
                    Text("Error Distribution")
                        .foregroundColor(.secondary)
                )
        }
    }
    
    // MARK: - API Endpoint Health
    
    private var apiEndpointHealth: some View {
        VStack(spacing: 16) {
            Text("Endpoint Health")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(Array(dashboardManager.developerDashboard.apiHealth.endpointHealth.keys.sorted()), id: \.self) { endpoint in
                if let health = dashboardManager.developerDashboard.apiHealth.endpointHealth[endpoint] {
                    EndpointHealthRow(endpoint: endpoint, health: health)
                }
            }
        }
    }
    
    // MARK: - Code Quality Metrics
    
    private var codeQualityMetrics: some View {
        VStack(spacing: 16) {
            Text("Quality Metrics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Quality metrics chart
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .frame(height: 200)
                .overlay(
                    Text("Quality Trends")
                        .foregroundColor(.secondary)
                )
        }
    }
    
    // MARK: - Helper Methods
    
    private func startAutoRefresh() {
        guard autoRefresh else { return }
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if !autoRefresh {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Real-Time Metric Card

struct RealTimeMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let status: MetricStatus
    
    enum MetricStatus {
        case normal, warning, critical
        
        var color: Color {
            switch self {
            case .normal: return .green
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.semibold)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Metric Selector Button

struct MetricSelectorButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(20)
        }
    }
}

// MARK: - Response Time Card

struct ResponseTimeCard: View {
    let performance: PerformanceMetrics
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Response Time")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Last Hour")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                ResponseTimeMetric(
                    label: "Average",
                    value: String(format: "%.0fms", performance.averageResponseTime)
                )
                
                ResponseTimeMetric(
                    label: "P95",
                    value: String(format: "%.0fms", performance.p95ResponseTime)
                )
                
                ResponseTimeMetric(
                    label: "P99",
                    value: String(format: "%.0fms", performance.p99ResponseTime)
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct ResponseTimeMetric: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Throughput Graph

struct ThroughputGraph: View {
    let throughput: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Throughput")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack {
                Text(String(format: "%.0f", throughput))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("req/s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Graph placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 60)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Error Stat Card

struct ErrorStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Top Errors List

struct TopErrorsList: View {
    let errors: [(String, Int)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Errors")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            ForEach(errors, id: \.0) { error in
                HStack {
                    Text(error.0)
                        .font(.caption)
                    
                    Spacer()
                    
                    Text("\(error.1)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - API Stat Card

struct APIStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Endpoint Health Row

struct EndpointHealthRow: View {
    let endpoint: String
    let health: Double
    
    var body: some View {
        HStack {
            Text(endpoint)
                .font(.system(.caption, design: .monospaced))
            
            Spacer()
            
            ProgressView(value: health, total: 100)
                .frame(width: 100)
            
            Text(String(format: "%.0f%%", health))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(health > 95 ? .green : health > 80 ? .orange : .red)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Deployment Card

struct DeploymentCard: View {
    let deployment: DeploymentMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let lastDeploy = deployment.lastDeployment {
                HStack {
                    Text("Last Deployment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(lastDeploy, style: .relative)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            HStack(spacing: 16) {
                DeploymentMetric(label: "Frequency", value: "\(deployment.deploymentFrequency)/day")
                DeploymentMetric(label: "Rollback Rate", value: String(format: "%.1f%%", deployment.rollbackRate))
                DeploymentMetric(label: "Lead Time", value: formatDuration(deployment.leadTime))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct DeploymentMetric: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Code Quality Card

struct CodeQualityCard: View {
    let quality: CodeQualityMetrics
    
    var body: some View {
        VStack(spacing: 12) {
            QualityMetricRow(
                title: "Test Coverage",
                value: quality.testCoverage,
                target: 80,
                format: "%.0f%%"
            )
            
            QualityMetricRow(
                title: "Technical Debt",
                value: Double(quality.technicalDebt),
                target: 50,
                format: "%.0f hrs",
                inverse: true
            )
            
            QualityMetricRow(
                title: "Code Complexity",
                value: quality.codeComplexity,
                target: 5,
                format: "%.1f",
                inverse: true
            )
            
            QualityMetricRow(
                title: "Duplication",
                value: quality.duplicateCodeRatio,
                target: 5,
                format: "%.1f%%",
                inverse: true
            )
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct QualityMetricRow: View {
    let title: String
    let value: Double
    let target: Double
    let format: String
    var inverse: Bool = false
    
    private var isGood: Bool {
        inverse ? value < target : value >= target
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(String(format: format, value))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isGood ? .green : .orange)
        }
    }
}

// MARK: - Preview

struct DeveloperDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DeveloperDashboardView()
        }
    }
}