//
//  TimelineComponents.swift
//  ClaudeCode
//
//  Timeline and history visualization components
//

import SwiftUI

// MARK: - Timeline View

struct TimelineView<Item: TimelineItem>: View {
    let items: [Item]
    let style: TimelineStyle
    let onItemTap: ((Item) -> Void)?
    
    init(
        items: [Item],
        style: TimelineStyle = .vertical,
        onItemTap: ((Item) -> Void)? = nil
    ) {
        self.items = items
        self.style = style
        self.onItemTap = onItemTap
    }
    
    var body: some View {
        switch style {
        case .vertical:
            VerticalTimeline(items: items, onItemTap: onItemTap)
        case .horizontal:
            HorizontalTimeline(items: items, onItemTap: onItemTap)
        case .compact:
            CompactTimeline(items: items, onItemTap: onItemTap)
        }
    }
}

// MARK: - Vertical Timeline

struct VerticalTimeline<Item: TimelineItem>: View {
    let items: [Item]
    let onItemTap: ((Item) -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: ThemeSpacing.md) {
                        // Timeline line and node
                        VStack(spacing: 0) {
                            // Top line
                            if index > 0 {
                                Rectangle()
                                    .fill(Theme.border)
                                    .frame(width: 2)
                                    .frame(height: 20)
                            }
                            
                            // Node
                            TimelineNode(
                                type: item.nodeType,
                                isActive: item.isActive
                            )
                            
                            // Bottom line
                            if index < items.count - 1 {
                                Rectangle()
                                    .fill(Theme.border)
                                    .frame(width: 2)
                            }
                        }
                        .frame(width: 32)
                        
                        // Content
                        VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                            // Header
                            HStack {
                                Text(item.title)
                                    .font(Theme.Typography.headline)
                                    .foregroundColor(Theme.foreground)
                                
                                Spacer()
                                
                                Text(item.formattedTime)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.mutedForeground)
                            }
                            
                            // Description
                            if let description = item.description {
                                Text(description)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.mutedForeground)
                            }
                            
                            // Custom content
                            if let content = item.content {
                                AnyView(content)
                            }
                            
                            // Metadata
                            if !item.metadata.isEmpty {
                                HStack(spacing: ThemeSpacing.sm) {
                                    ForEach(item.metadata, id: \.key) { meta in
                                        MetadataBadge(
                                            key: meta.key,
                                            value: meta.value
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.bottom, ThemeSpacing.lg)
                        .onTapGesture {
                            if let onItemTap = onItemTap {
                                onItemTap(item)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Horizontal Timeline

struct HorizontalTimeline<Item: TimelineItem>: View {
    let items: [Item]
    let onItemTap: ((Item) -> Void)?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: ThemeSpacing.sm) {
                        // Time label
                        Text(item.formattedTime)
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.mutedForeground)
                        
                        // Timeline line and node
                        HStack(spacing: 0) {
                            // Left line
                            if index > 0 {
                                Rectangle()
                                    .fill(Theme.border)
                                    .frame(height: 2)
                            }
                            
                            // Node
                            TimelineNode(
                                type: item.nodeType,
                                isActive: item.isActive
                            )
                            
                            // Right line
                            if index < items.count - 1 {
                                Rectangle()
                                    .fill(Theme.border)
                                    .frame(height: 2)
                            }
                        }
                        .frame(height: 32)
                        
                        // Content card
                        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                            Text(item.title)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.foreground)
                                .lineLimit(2)
                            
                            if let description = item.description {
                                Text(description)
                                    .font(Theme.Typography.caption2)
                                    .foregroundColor(Theme.mutedForeground)
                                    .lineLimit(3)
                            }
                        }
                        .frame(width: 120)
                        .padding(ThemeSpacing.sm)
                        .background(Theme.card)
                        .cornerRadius(Theme.Radius.sm)
                        .onTapGesture {
                            if let onItemTap = onItemTap {
                                onItemTap(item)
                            }
                        }
                    }
                    .frame(width: 140)
                }
            }
            .padding()
        }
    }
}

// MARK: - Compact Timeline

struct CompactTimeline<Item: TimelineItem>: View {
    let items: [Item]
    let onItemTap: ((Item) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                HStack(spacing: ThemeSpacing.md) {
                    // Time
                    Text(item.formattedTime)
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.mutedForeground)
                        .frame(width: 60, alignment: .trailing)
                    
                    // Node
                    TimelineNode(
                        type: item.nodeType,
                        isActive: item.isActive,
                        size: .small
                    )
                    
                    // Content
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.foreground)
                            .lineLimit(1)
                        
                        if let description = item.description {
                            Text(description)
                                .font(Theme.Typography.caption2)
                                .foregroundColor(Theme.mutedForeground)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, ThemeSpacing.xs)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let onItemTap = onItemTap {
                        onItemTap(item)
                    }
                }
                
                if item.id != items.last?.id {
                    Divider()
                        .background(Theme.border.opacity(0.5))
                        .padding(.leading, 60 + ThemeSpacing.md + 20)
                }
            }
        }
        .padding()
    }
}

// MARK: - Timeline Node

struct TimelineNode: View {
    let type: TimelineNodeType
    let isActive: Bool
    let size: NodeSize
    
    init(
        type: TimelineNodeType,
        isActive: Bool = false,
        size: NodeSize = .medium
    ) {
        self.type = type
        self.isActive = isActive
        self.size = size
    }
    
    enum NodeSize {
        case small
        case medium
        case large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 20
            case .large: return 28
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(isActive ? nodeColor : Theme.card)
                .frame(width: size.dimension, height: size.dimension)
            
            // Border
            Circle()
                .stroke(nodeColor, lineWidth: isActive ? 2 : 1)
                .frame(width: size.dimension, height: size.dimension)
            
            // Icon
            if case .icon(let systemName) = type {
                Image(systemName: systemName)
                    .font(.system(size: size.iconSize))
                    .foregroundColor(isActive ? .white : nodeColor)
            }
        }
    }
    
    private var nodeColor: Color {
        switch type {
        case .default:
            return Theme.primary
        case .success:
            return Theme.success
        case .error:
            return Theme.destructive
        case .warning:
            return Theme.warning
        case .info:
            return Theme.info
        case .icon:
            return Theme.primary
        }
    }
}

// MARK: - Metadata Badge

struct MetadataBadge: View {
    let key: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.mutedForeground)
            
            Text(value)
                .font(Theme.Typography.caption2)
                .fontWeight(.medium)
                .foregroundColor(Theme.foreground)
        }
        .padding(.horizontal, ThemeSpacing.xs)
        .padding(.vertical, 2)
        .background(Theme.card)
        .cornerRadius(Theme.Radius.xs)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xs)
                .stroke(Theme.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Activity Graph

struct ActivityGraph: View {
    let data: [ActivityData]
    let style: GraphStyle
    
    enum GraphStyle {
        case bar
        case line
        case dots
    }
    
    var body: some View {
        GeometryReader { geometry in
            switch style {
            case .bar:
                BarGraph(data: data, size: geometry.size)
            case .line:
                LineGraph(data: data, size: geometry.size)
            case .dots:
                DotGraph(data: data, size: geometry.size)
            }
        }
    }
}

struct BarGraph: View {
    let data: [ActivityData]
    let size: CGSize
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(data) { item in
                Rectangle()
                    .fill(Theme.primary.opacity(item.intensity))
                    .frame(height: size.height * CGFloat(item.value))
            }
        }
    }
}

struct LineGraph: View {
    let data: [ActivityData]
    let size: CGSize
    
    var body: some View {
        Path { path in
            guard data.count > 1 else { return }
            
            let xStep = size.width / CGFloat(data.count - 1)
            
            for (index, item) in data.enumerated() {
                let x = CGFloat(index) * xStep
                let y = size.height - (size.height * CGFloat(item.value))
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(Theme.primary, lineWidth: 2)
    }
}

struct DotGraph: View {
    let data: [ActivityData]
    let size: CGSize
    
    var body: some View {
        ZStack {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                Circle()
                    .fill(Theme.primary.opacity(item.intensity))
                    .frame(width: 8, height: 8)
                    .position(
                        x: CGFloat(index) * (size.width / CGFloat(data.count - 1)),
                        y: size.height - (size.height * CGFloat(item.value))
                    )
            }
        }
    }
}

// MARK: - Supporting Types

protocol TimelineItem: Identifiable {
    var id: String { get }
    var title: String { get }
    var description: String? { get }
    var timestamp: Date { get }
    var nodeType: TimelineNodeType { get }
    var isActive: Bool { get }
    var metadata: [(key: String, value: String)] { get }
    var content: AnyView? { get }
    var formattedTime: String { get }
}

enum TimelineStyle {
    case vertical
    case horizontal
    case compact
}

enum TimelineNodeType {
    case `default`
    case success
    case error
    case warning
    case info
    case icon(String)
}

struct ActivityData: Identifiable {
    let id = UUID().uuidString
    let value: Double // 0.0 to 1.0
    let intensity: Double // 0.0 to 1.0
    let label: String?
}

// MARK: - Sample Timeline Item

struct SampleTimelineItem: TimelineItem {
    let id: String
    let title: String
    let description: String?
    let timestamp: Date
    let nodeType: TimelineNodeType
    let isActive: Bool
    let metadata: [(key: String, value: String)]
    let content: AnyView?
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - Preview

struct TimelineComponents_Previews: PreviewProvider {
    static let sampleItems: [SampleTimelineItem] = [
        SampleTimelineItem(
            id: "1",
            title: "Chat Started",
            description: "New conversation initiated",
            timestamp: Date().addingTimeInterval(-3600),
            nodeType: .default,
            isActive: false,
            metadata: [],
            content: nil
        ),
        SampleTimelineItem(
            id: "2",
            title: "Tool Executed",
            description: "Read file operation completed",
            timestamp: Date().addingTimeInterval(-2400),
            nodeType: .success,
            isActive: false,
            metadata: [("Duration", "23ms"), ("Files", "3")],
            content: nil
        ),
        SampleTimelineItem(
            id: "3",
            title: "Error Occurred",
            description: "Failed to write file",
            timestamp: Date().addingTimeInterval(-1200),
            nodeType: .error,
            isActive: false,
            metadata: [("Error", "Permission denied")],
            content: nil
        ),
        SampleTimelineItem(
            id: "4",
            title: "Processing",
            description: "Analyzing code structure",
            timestamp: Date(),
            nodeType: .info,
            isActive: true,
            metadata: [],
            content: nil
        )
    ]
    
    static var previews: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            TabView {
                TimelineView(
                    items: sampleItems,
                    style: .vertical
                )
                .tabItem {
                    Label("Vertical", systemImage: "arrow.down")
                }
                
                TimelineView(
                    items: sampleItems,
                    style: .horizontal
                )
                .tabItem {
                    Label("Horizontal", systemImage: "arrow.right")
                }
                
                TimelineView(
                    items: sampleItems,
                    style: .compact
                )
                .tabItem {
                    Label("Compact", systemImage: "list.bullet")
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}