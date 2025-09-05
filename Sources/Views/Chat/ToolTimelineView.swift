//
//  ToolTimelineView.swift
//  ClaudeCode
//
//  Timeline view showing tool usage during chat
//

import SwiftUI

// MVP: Stub implementation - Tool functionality to be implemented later
struct ToolUsage: Identifiable {
    let id = UUID().uuidString
    let name: String
    let description: String
    let timestamp: Date
    let duration: TimeInterval
    let status: Status
    
    enum Status {
        case success
        case error
        case running
    }
}

struct ToolTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    let tools: [ToolUsage]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                if tools.isEmpty {
                    EmptyStateView(
                        icon: "wrench.and.screwdriver",
                        title: "No Tools Used",
                        message: "No tools have been used in this conversation yet",
                        action: nil
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                                ToolTimelineRow(
                                    tool: tool,
                                    isFirst: index == 0,
                                    isLast: index == tools.count - 1
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Tool Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .tint(Theme.primary)
                }
            }
        }
    }
}

// MARK: - Tool Timeline Row

struct ToolTimelineRow: View {
    let tool: ToolUsage
    let isFirst: Bool
    let isLast: Bool
    
    private var statusColor: Color {
        switch tool.status {
        case .success:
            return Theme.success
        case .error:
            return Theme.destructive
        case .running:
            return Theme.warning
        }
    }
    
    private var statusIcon: String {
        switch tool.status {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .running:
            return "circle.dotted"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: ThemeSpacing.md) {
            // Timeline line and dot
            VStack(spacing: 0) {
                // Top line
                if !isFirst {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: 2)
                        .frame(height: 20)
                }
                
                // Status dot
                ZStack {
                    Circle()
                        .fill(Theme.card)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: statusIcon)
                        .font(.system(size: 16))
                        .foregroundColor(statusColor)
                }
                
                // Bottom line
                if !isLast {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 32)
            
            // Tool details
            VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                // Tool name and status
                HStack {
                    Text(tool.name)
                        .font(Theme.Typography.headlineFont)
                        .foregroundColor(Theme.foreground)
                    
                    Spacer()
                    
                    // Duration badge
                    if tool.duration > 0 {
                        Text(formatDuration(tool.duration))
                            .font(Theme.Typography.captionFont)
                            .foregroundColor(Theme.mutedForeground)
                            .padding(.horizontal, ThemeSpacing.xs)
                            .padding(.vertical, 2)
                            .background(Theme.muted.opacity(0.2))
                            .cornerRadius(Theme.CornerRadius.sm)
                    }
                }
                
                // Description
                Text(tool.description)
                    .font(Theme.Typography.subheadlineFont)
                    .foregroundColor(Theme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Timestamp
                Text(formatTimestamp(tool.timestamp))
                    .font(Theme.Typography.captionFont)
                    .foregroundColor(Theme.muted)
                
                // Tool details card
                if tool.status == .error {
                    Text("Error: Failed to execute tool")
                        .font(Theme.Typography.captionFont)
                        .foregroundColor(Theme.destructive)
                        .padding(ThemeSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.destructive.opacity(0.1))
                        .cornerRadius(Theme.CornerRadius.sm)
                }
            }
            .padding(.bottom, isLast ? 0 : ThemeSpacing.lg)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%dm %ds", minutes, seconds)
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    ToolTimelineView(tools: [
        ToolUsage(
            name: "Read File",
            description: "Reading configuration from project.json",
            timestamp: Date().addingTimeInterval(-300),
            duration: 0.234,
            status: .success
        ),
        ToolUsage(
            name: "Execute Command",
            description: "Running npm install to update dependencies",
            timestamp: Date().addingTimeInterval(-240),
            duration: 15.6,
            status: .success
        ),
        ToolUsage(
            name: "Write File",
            description: "Updating package.json with new dependencies",
            timestamp: Date().addingTimeInterval(-180),
            duration: 0.089,
            status: .success
        ),
        ToolUsage(
            name: "Search Files",
            description: "Searching for usage of deprecated API",
            timestamp: Date().addingTimeInterval(-120),
            duration: 2.45,
            status: .error
        ),
        ToolUsage(
            name: "Analyze Code",
            description: "Running static analysis on source files",
            timestamp: Date().addingTimeInterval(-60),
            duration: 0,
            status: .running
        )
    ])
    .preferredColorScheme(.dark)
}