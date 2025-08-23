// Sources/UI/Monitoring/Charts/PerformanceChartCard.swift
// Task: Performance Chart Card UI Implementation
// This file provides chart components for performance visualization

import SwiftUI
import Charts

/// Performance chart card component
public struct PerformanceChartCard: View {
    let title: String
    let data: [ChartDataPoint]
    let unit: String
    let color: Color
    let threshold: Double?
    
    @State private var selectedPoint: ChartDataPoint?
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
                
                if let last = data.last {
                    HStack(spacing: 4) {
                        Text(String(format: "%.1f", last.value))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Chart
            if !data.isEmpty {
                Chart(data) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    if let selectedPoint = selectedPoint, selectedPoint.id == point.id {
                        PointMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(color)
                        .symbolSize(100)
                        
                        RuleMark(x: .value("Time", point.timestamp))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(0.1))
                        AxisValueLabel()
                            .font(.caption)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(0.1))
                        AxisValueLabel()
                            .font(.caption)
                    }
                }
                .chartBackground { proxy in
                    if let threshold = threshold {
                        GeometryReader { geometry in
                            let yPosition = proxy.position(forY: threshold) ?? 0
                            
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: yPosition))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: yPosition))
                            }
                            .stroke(Color.red.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            
                            Text("Threshold")
                                .font(.caption2)
                                .foregroundColor(.red.opacity(0.7))
                                .position(x: geometry.size.width - 30, y: yPosition - 10)
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let xPosition = location.x
                                if let date = proxy.value(atX: xPosition, as: Date.self) {
                                    selectedPoint = data.min(by: {
                                        abs($0.timestamp.timeIntervalSince(date)) <
                                        abs($1.timestamp.timeIntervalSince(date))
                                    })
                                }
                            }
                    }
                }
            } else {
                // Empty state
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            }
            
            // Selected point details
            if let selectedPoint = selectedPoint {
                HStack {
                    Text(selectedPoint.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f %@", selectedPoint.value, unit))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Active trackers card
public struct ActiveTrackersCard: View {
    let trackers: [TrackerInfo]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
                Text("Active Operations")
                    .font(.headline)
                Spacer()
                
                if !trackers.isEmpty {
                    Text("\(trackers.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Divider()
            
            if trackers.isEmpty {
                Text("No active operations")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(trackers) { tracker in
                        TrackerRow(tracker: tracker)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Tracker row component
struct TrackerRow: View {
    let tracker: TrackerInfo
    @State private var elapsedTime: TimeInterval = 0
    
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
                            value: elapsedTime
                        )
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tracker.operation)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(formatDuration(elapsedTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.7)
        }
        .onAppear {
            elapsedTime = Date().timeIntervalSince(tracker.startTime)
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                elapsedTime = Date().timeIntervalSince(tracker.startTime)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration) % 60
        let minutes = (Int(duration) / 60) % 60
        
        if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

/// Error summary card
public struct ErrorSummaryCard: View {
    let totalErrors: Int
    let criticalErrors: Int
    let warningCount: Int
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text("Error Summary")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            HStack(spacing: 20) {
                ErrorStatView(
                    title: "Total",
                    count: totalErrors,
                    color: .red
                )
                
                ErrorStatView(
                    title: "Critical",
                    count: criticalErrors,
                    color: .purple
                )
                
                ErrorStatView(
                    title: "Warnings",
                    count: warningCount,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Error stat view
struct ErrorStatView: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Error card component
public struct ErrorCard: View {
    let error: ErrorInfo
    @State private var isExpanded = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: error.severity.icon)
                    .foregroundColor(error.severity.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.type)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(error.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            Text(error.message)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)
            
            if isExpanded, let stackTrace = error.stackTrace {
                Divider()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(stackTrace)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(4)
                }
                .frame(height: 100)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Metric card component
public struct MetricCard: View {
    let metric: CustomMetricInfo
    
    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.name)
                    .font(.subheadline)
                
                Text(metric.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text(String(format: "%.2f", metric.value))
                    .font(.headline)
                    .foregroundColor(.accentColor)
                
                Text(metric.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}