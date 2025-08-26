//
//  ExecutiveDashboardView.swift
//  ClaudeCode
//
//  Executive dashboard view for high-level business metrics
//

import SwiftUI
import Charts

struct ExecutiveDashboardView: View {
    @StateObject private var dashboardManager = DashboardManager.shared
    @State private var selectedTimeRange = TimeRange.today
    @State private var showingAlerts = false
    
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "7 Days"
        case month = "30 Days"
        case quarter = "Quarter"
        
        var days: Int {
            switch self {
            case .today: return 1
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // KPI Cards
                kpiSection
                
                // System Health
                systemHealthSection
                
                // Revenue & Growth Charts
                HStack(spacing: 16) {
                    revenueChart
                    userGrowthChart
                }
                .frame(height: 300)
                
                // Business Trends
                businessTrendsSection
                
                // Alerts Summary
                if showingAlerts {
                    alertsSummary
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Executive Dashboard")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button(range.rawValue) {
                            selectedTimeRange = range
                        }
                    }
                } label: {
                    Label(selectedTimeRange.rawValue, systemImage: "calendar")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAlerts.toggle() }) {
                    Image(systemName: showingAlerts ? "bell.fill" : "bell")
                        .foregroundColor(hasActiveAlerts ? .red : .primary)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Business Overview")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Last updated: \(Date(), formatter: dateFormatter)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - KPI Section
    
    private var kpiSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            KPICard(
                title: "DAU",
                value: formatNumber(dashboardManager.executiveDashboard.kpis.dailyActiveUsers),
                change: "+12%",
                isPositive: true,
                icon: "person.3.fill"
            )
            
            KPICard(
                title: "MAU",
                value: formatNumber(dashboardManager.executiveDashboard.kpis.monthlyActiveUsers),
                change: "+8%",
                isPositive: true,
                icon: "person.crop.circle.fill"
            )
            
            KPICard(
                title: "Session Length",
                value: formatDuration(dashboardManager.executiveDashboard.kpis.averageSessionLength),
                change: "+5%",
                isPositive: true,
                icon: "clock.fill"
            )
            
            KPICard(
                title: "Crash Free",
                value: String(format: "%.1f%%", dashboardManager.executiveDashboard.kpis.crashFreeRate),
                change: "+0.2%",
                isPositive: true,
                icon: "checkmark.shield.fill"
            )
            
            KPICard(
                title: "Conversion",
                value: String(format: "%.1f%%", dashboardManager.executiveDashboard.kpis.conversionRate),
                change: "-1%",
                isPositive: false,
                icon: "cart.fill"
            )
            
            KPICard(
                title: "User Score",
                value: String(format: "%.1f", dashboardManager.executiveDashboard.kpis.userSatisfactionScore),
                change: "+0.1",
                isPositive: true,
                icon: "star.fill"
            )
        }
    }
    
    // MARK: - System Health Section
    
    private var systemHealthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Health")
                .font(.headline)
            
            SystemHealthCard(health: dashboardManager.executiveDashboard.systemHealth)
        }
    }
    
    // MARK: - Revenue Chart
    
    private var revenueChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revenue")
                .font(.headline)
            
            RevenueChartView(revenue: dashboardManager.executiveDashboard.revenue)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - User Growth Chart
    
    private var userGrowthChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("User Growth")
                .font(.headline)
            
            UserGrowthChartView(growth: dashboardManager.executiveDashboard.userGrowth)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Business Trends Section
    
    private var businessTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Business Trends")
                .font(.headline)
            
            HStack(spacing: 16) {
                TrendIndicator(
                    title: "User Growth",
                    trend: dashboardManager.executiveDashboard.trends.userGrowthTrend
                )
                
                TrendIndicator(
                    title: "Revenue",
                    trend: dashboardManager.executiveDashboard.trends.revenueTrend
                )
                
                TrendIndicator(
                    title: "Engagement",
                    trend: dashboardManager.executiveDashboard.trends.engagementTrend
                )
                
                TrendIndicator(
                    title: "Performance",
                    trend: dashboardManager.executiveDashboard.trends.performanceTrend
                )
            }
        }
    }
    
    // MARK: - Alerts Summary
    
    private var alertsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Alerts")
                .font(.headline)
            
            // Alert items would be displayed here
            Text("No active alerts")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Helpers
    
    private var hasActiveAlerts: Bool {
        // Check for active alerts
        false
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - KPI Card Component

struct KPICard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                
                Text(change)
                    .font(.caption)
            }
            .foregroundColor(isPositive ? .green : .red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - System Health Card

struct SystemHealthCard: View {
    let health: SystemHealthScore
    
    var body: some View {
        VStack(spacing: 12) {
            // Overall Score
            HStack {
                Text("Overall Health")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(String(format: "%.0f%%", health.overall))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(colorForScore(health.overall))
            }
            
            // Individual Metrics
            VStack(spacing: 8) {
                HealthMetricRow(title: "Performance", value: health.performance)
                HealthMetricRow(title: "Stability", value: health.stability)
                HealthMetricRow(title: "Security", value: health.security)
                HealthMetricRow(title: "User Experience", value: health.userExperience)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func colorForScore(_ score: Double) -> Color {
        if score >= 90 {
            return .green
        } else if score >= 70 {
            return .orange
        } else {
            return .red
        }
    }
}

struct HealthMetricRow: View {
    let title: String
    let value: Double
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            ProgressView(value: value, total: 100)
                .frame(width: 100)
            
            Text(String(format: "%.0f%%", value))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Trend Indicator

struct TrendIndicator: View {
    let title: String
    let trend: BusinessTrends.TrendDirection
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Image(systemName: trendIcon)
                    .font(.title3)
                    .foregroundColor(trendColor)
                
                Text(trendText)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
    }
    
    private var trendIcon: String {
        switch trend {
        case .increasing:
            return "arrow.up.right.circle.fill"
        case .decreasing:
            return "arrow.down.right.circle.fill"
        case .stable:
            return "equal.circle.fill"
        }
    }
    
    private var trendColor: Color {
        switch trend {
        case .increasing:
            return .green
        case .decreasing:
            return .red
        case .stable:
            return .blue
        }
    }
    
    private var trendText: String {
        switch trend {
        case .increasing:
            return "Up"
        case .decreasing:
            return "Down"
        case .stable:
            return "Stable"
        }
    }
}

// MARK: - Revenue Chart View

struct RevenueChartView: View {
    let revenue: RevenueMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(String(format: "%.0f", revenue.dailyRevenue))")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Chart placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(height: 150)
            
            HStack(spacing: 16) {
                MetricLabel(title: "ARPU", value: "$\(String(format: "%.2f", revenue.averageRevenuePerUser))")
                MetricLabel(title: "Churn", value: "\(String(format: "%.1f%%", revenue.subscriptionChurnRate))")
                MetricLabel(title: "LTV", value: "$\(String(format: "%.0f", revenue.lifetimeValue))")
            }
        }
    }
}

// MARK: - User Growth Chart View

struct UserGrowthChartView: View {
    let growth: UserGrowthMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("+\(growth.newUsers)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("New Users Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Chart placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [.green.opacity(0.3), .green.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(height: 150)
            
            HStack(spacing: 16) {
                MetricLabel(title: "Retention", value: "\(String(format: "%.0f%%", growth.retentionRate))")
                MetricLabel(title: "Growth", value: "\(String(format: "%.0f%%", growth.growthRate))")
                MetricLabel(title: "Activation", value: "\(String(format: "%.0f%%", growth.activationRate))")
            }
        }
    }
}

struct MetricLabel: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Preview

struct ExecutiveDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ExecutiveDashboardView()
        }
    }
}