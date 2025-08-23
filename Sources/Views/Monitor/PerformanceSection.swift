//
//  PerformanceSection.swift
//  ClaudeCode
//
//  Performance monitoring section view (Tasks 841-843)
//

import SwiftUI
import Charts

/// Performance monitoring section
struct PerformanceSection: View {
    @ObservedObject var tracker: PerformanceTracker
    @State private var selectedTimeRange = TimeRange.lastHour
    @State private var showingBottleneckDetails = false
    @State private var selectedBottleneck: PerformanceBottleneck?
    
    enum TimeRange: String, CaseIterable {
        case lastMinute = "1m"
        case last5Minutes = "5m"
        case last15Minutes = "15m"
        case lastHour = "1h"
        case last24Hours = "24h"
        
        var seconds: TimeInterval {
            switch self {
            case .lastMinute: return 60
            case .last5Minutes: return 300
            case .last15Minutes: return 900
            case .lastHour: return 3600
            case .last24Hours: return 86400
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Performance score
            performanceScoreCard
            
            // Time range selector
            timeRangeSelector
            
            // Performance chart
            performanceChart
            
            // Active spans
            if !tracker.activeSpans.isEmpty {
                activeSpansSection
            }
            
            // Bottlenecks
            if !tracker.bottlenecks.isEmpty {
                bottlenecksSection
            }
            
            // Recent measurements
            recentMeasurementsSection
        }
        .sheet(isPresented: $showingBottleneckDetails) {
            if let bottleneck = selectedBottleneck {
                BottleneckDetailsView(bottleneck: bottleneck)
            }
        }
    }
    
    // MARK: - Performance Score
    
    private var performanceScoreCard: some View {
        VStack(spacing: 16) {
            Text("Performance Score")
                .font(.headline)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: tracker.performanceScore / 100)
                    .stroke(
                        scoreGradient,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: tracker.performanceScore)
                
                VStack(spacing: 4) {
                    Text("\(Int(tracker.performanceScore))")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor)
                    
                    Text(scoreLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 150, height: 150)
            
            // Score breakdown
            HStack(spacing: 20) {
                ScoreComponent(
                    label: "Latency",
                    value: latencyScore,
                    color: latencyColor
                )
                
                ScoreComponent(
                    label: "Throughput",
                    value: throughputScore,
                    color: throughputColor
                )
                
                ScoreComponent(
                    label: "Stability",
                    value: stabilityScore,
                    color: stabilityColor
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button(action: {
                        withAnimation {
                            selectedTimeRange = range
                        }
                    }) {
                        Text(range.rawValue)
                            .font(.caption)
                            .fontWeight(selectedTimeRange == range ? .semibold : .regular)
                            .foregroundColor(selectedTimeRange == range ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedTimeRange == range ? Color.accentColor : Color.gray.opacity(0.2)
                            )
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    // MARK: - Performance Chart
    
    private var performanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Operation Duration")
                .font(.headline)
            
            let filteredMeasurements = getFilteredMeasurements()
            
            if filteredMeasurements.isEmpty {
                Text("No data for selected time range")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                if #available(iOS 16.0, *) {
                    Chart(filteredMeasurements) { measurement in
                        LineMark(
                            x: .value("Time", measurement.startTime),
                            y: .value("Duration", measurement.duration * 1000) // Convert to ms
                        )
                        .foregroundStyle(Color.blue)
                        
                        PointMark(
                            x: .value("Time", measurement.startTime),
                            y: .value("Duration", measurement.duration * 1000)
                        )
                        .foregroundStyle(colorForDuration(measurement.duration))
                    }
                    .frame(height: 200)
                    .chartYAxisLabel("Duration (ms)")
                    .chartXAxis {
                        AxisMarks(preset: .aligned)
                    }
                } else {
                    // Fallback for older iOS versions
                    SimpleLineChart(
                        data: filteredMeasurements.map { $0.duration * 1000 }
                    )
                    .frame(height: 200)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Active Spans
    
    private var activeSpansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Operations")
                    .font(.headline)
                Spacer()
                Text("\(tracker.activeSpans.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            ForEach(Array(tracker.activeSpans.values.prefix(5)), id: \.id) { span in
                ActiveSpanRow(span: span)
            }
            
            if tracker.activeSpans.count > 5 {
                Text("And \(tracker.activeSpans.count - 5) more...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Bottlenecks
    
    private var bottlenecksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Performance Bottlenecks")
                    .font(.headline)
                Spacer()
                if !tracker.bottlenecks.isEmpty {
                    Button(action: { tracker.bottlenecks.removeAll() }) {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            ForEach(tracker.bottlenecks.prefix(5)) { bottleneck in
                BottleneckRow(bottleneck: bottleneck) {
                    selectedBottleneck = bottleneck
                    showingBottleneckDetails = true
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Recent Measurements
    
    private var recentMeasurementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Measurements")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tracker.measurements.suffix(10), id: \.startTime) { measurement in
                        MeasurementCard(measurement: measurement)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    
    private var scoreGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                tracker.performanceScore > 80 ? .green : 
                tracker.performanceScore > 60 ? .yellow : .red,
                tracker.performanceScore > 80 ? .blue : 
                tracker.performanceScore > 60 ? .orange : .orange
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var scoreColor: Color {
        if tracker.performanceScore > 80 {
            return .green
        } else if tracker.performanceScore > 60 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var scoreLabel: String {
        if tracker.performanceScore > 80 {
            return "Excellent"
        } else if tracker.performanceScore > 60 {
            return "Good"
        } else if tracker.performanceScore > 40 {
            return "Fair"
        } else {
            return "Poor"
        }
    }
    
    private var latencyScore: Double {
        // Calculate based on average operation time
        100 // Placeholder
    }
    
    private var throughputScore: Double {
        // Calculate based on operations per minute
        100 // Placeholder
    }
    
    private var stabilityScore: Double {
        // Calculate based on error rate and crashes
        100 // Placeholder
    }
    
    private var latencyColor: Color { .blue }
    private var throughputColor: Color { .green }
    private var stabilityColor: Color { .purple }
    
    // MARK: - Helper Methods
    
    private func getFilteredMeasurements() -> [PerformanceMeasurement] {
        let cutoff = Date().addingTimeInterval(-selectedTimeRange.seconds)
        return tracker.measurements.filter { $0.startTime > cutoff }
    }
    
    private func colorForDuration(_ duration: TimeInterval) -> Color {
        if duration < 0.1 {
            return .green
        } else if duration < 0.5 {
            return .yellow
        } else if duration < 1.0 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Component Views

struct ScoreComponent: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(Int(value))")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct ActiveSpanRow: View {
    let span: PerformanceSpan
    
    private var duration: String {
        let elapsed = Date().timeIntervalSince(span.startTime)
        return String(format: "%.2fs", elapsed)
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
            
            Text(span.operationName)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            Text(duration)
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.vertical, 4)
    }
}

struct BottleneckRow: View {
    let bottleneck: PerformanceBottleneck
    let action: () -> Void
    
    private var severityColor: Color {
        switch bottleneck.severity {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(bottleneck.operation)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(String(format: "%.2fs - %@", bottleneck.duration, bottleneck.severity == .critical ? "Critical" : bottleneck.severity == .high ? "High" : "Medium"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MeasurementCard: View {
    let measurement: PerformanceMeasurement
    
    private var durationColor: Color {
        if measurement.duration < 0.1 {
            return .green
        } else if measurement.duration < 0.5 {
            return .yellow
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(measurement.name)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(2)
            
            Text(String(format: "%.0fms", measurement.duration * 1000))
                .font(.caption)
                .foregroundColor(durationColor)
            
            if measurement.memoryUsed > 0 {
                Text(formatBytes(measurement.memoryUsed))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .frame(width: 100)
        .background(Color.white)
        .cornerRadius(8)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: bytes)
    }
}

struct SimpleLineChart: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let maxValue = data.max() ?? 1
                let xStep = geometry.size.width / CGFloat(data.count - 1)
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * xStep
                    let y = geometry.size.height - (CGFloat(value / maxValue) * geometry.size.height)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.blue, lineWidth: 2)
        }
    }
}

// MARK: - Bottleneck Details

struct BottleneckDetailsView: View {
    let bottleneck: PerformanceBottleneck
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Operation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(bottleneck.operation)
                            .font(.headline)
                    }
                    
                    // Metrics
                    HStack(spacing: 20) {
                        MetricItem(
                            label: "Duration",
                            value: String(format: "%.2fs", bottleneck.duration)
                        )
                        
                        MetricItem(
                            label: "Severity",
                            value: bottleneck.severity == .critical ? "Critical" : 
                                   bottleneck.severity == .high ? "High" :
                                   bottleneck.severity == .medium ? "Medium" : "Low"
                        )
                        
                        MetricItem(
                            label: "Occurred",
                            value: RelativeDateFormatter.shared.string(from: bottleneck.timestamp)
                        )
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Suggestions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Optimization Suggestions")
                            .font(.headline)
                        
                        ForEach(bottleneck.suggestions, id: \.self) { suggestion in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                    .frame(width: 20)
                                
                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Bottleneck Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct MetricItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

// MARK: - Previews

struct PerformanceSection_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            PerformanceSection(tracker: PerformanceTracker())
                .padding()
        }
    }
}