//
//  CyberpunkSegmentedControl.swift
//  ClaudeCode
//
//  Segmented control with cyberpunk styling
//

import SwiftUI

/// Segment item configuration
struct SegmentItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String?
    let badge: Int?
    
    init(
        title: String,
        icon: String? = nil,
        badge: Int? = nil
    ) {
        self.title = title
        self.icon = icon
        self.badge = badge
    }
}

/// Custom cyberpunk-styled segmented control
struct CyberpunkSegmentedControl: View {
    let segments: [SegmentItem]
    @Binding var selectedIndex: Int
    let style: SegmentStyle
    let size: SegmentSize
    
    @State private var hoveredIndex: Int? = nil
    @Namespace private var segmentAnimation
    
    enum SegmentStyle {
        case filled
        case outlined
        case underlined
        case pills
    }
    
    enum SegmentSize {
        case small
        case medium
        case large
        
        var padding: EdgeInsets {
            switch self {
            case .small:
                return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            case .medium:
                return EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
            case .large:
                return EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
            }
        }
        
        var fontSize: Font {
            switch self {
            case .small:
                return .caption
            case .medium:
                return .body
            case .large:
                return .title3
            }
        }
    }
    
    init(
        segments: [SegmentItem],
        selectedIndex: Binding<Int>,
        style: SegmentStyle = .filled,
        size: SegmentSize = .medium
    ) {
        self.segments = segments
        self._selectedIndex = selectedIndex
        self.style = style
        self.size = size
    }
    
    var body: some View {
        switch style {
        case .filled:
            filledStyle
        case .outlined:
            outlinedStyle
        case .underlined:
            underlinedStyle
        case .pills:
            pillsStyle
        }
    }
    
    // MARK: - Filled Style
    private var filledStyle: some View {
        HStack(spacing: 0) {
            ForEach(segments.indices, id: \.self) { index in
                SegmentButton(
                    item: segments[index],
                    isSelected: selectedIndex == index,
                    isHovered: hoveredIndex == index,
                    size: size
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedIndex = index
                    }
                }
                .background(
                    Group {
                        if selectedIndex == index {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.hsl(142, 70, 45))
                                .matchedGeometryEffect(id: "selection", in: segmentAnimation)
                        }
                    }
                )
                .onHover { hovering in
                    hoveredIndex = hovering ? index : nil
                }
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.hsl(240, 10, 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.hsl(240, 10, 25), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Outlined Style
    private var outlinedStyle: some View {
        HStack(spacing: -1) {
            ForEach(segments.indices, id: \.self) { index in
                SegmentButton(
                    item: segments[index],
                    isSelected: selectedIndex == index,
                    isHovered: hoveredIndex == index,
                    size: size
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedIndex = index
                    }
                }
                .background(
                    Rectangle()
                        .fill(
                            selectedIndex == index ?
                            Color.hsl(142, 70, 45).opacity(0.2) :
                            Color.clear
                        )
                )
                .overlay(
                    Rectangle()
                        .stroke(
                            Color.hsl(240, 10, 30),
                            lineWidth: 1
                        )
                )
                .onHover { hovering in
                    hoveredIndex = hovering ? index : nil
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Underlined Style
    private var underlinedStyle: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(segments.indices, id: \.self) { index in
                    SegmentButton(
                        item: segments[index],
                        isSelected: selectedIndex == index,
                        isHovered: hoveredIndex == index,
                        size: size
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedIndex = index
                        }
                    }
                    .onHover { hovering in
                        hoveredIndex = hovering ? index : nil
                    }
                }
            }
            
            // Underline indicator
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(segments.indices, id: \.self) { index in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: geometry.size.width / CGFloat(segments.count))
                            .overlay(
                                Group {
                                    if selectedIndex == index {
                                        VStack {
                                            Spacer()
                                            Rectangle()
                                                .fill(Color.hsl(142, 70, 45))
                                                .frame(height: 3)
                                                .matchedGeometryEffect(id: "underline", in: segmentAnimation)
                                        }
                                    }
                                }
                            )
                    }
                }
            }
            .frame(height: 3)
        }
    }
    
    // MARK: - Pills Style
    private var pillsStyle: some View {
        HStack(spacing: 8) {
            ForEach(segments.indices, id: \.self) { index in
                SegmentButton(
                    item: segments[index],
                    isSelected: selectedIndex == index,
                    isHovered: hoveredIndex == index,
                    size: size
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedIndex = index
                    }
                }
                .background(
                    Capsule()
                        .fill(
                            selectedIndex == index ?
                            Color.hsl(142, 70, 45) :
                            Color.hsl(240, 10, 15)
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    selectedIndex == index ?
                                    Color.clear :
                                    Color.hsl(240, 10, 30),
                                    lineWidth: 1
                                )
                        )
                )
                .onHover { hovering in
                    hoveredIndex = hovering ? index : nil
                }
            }
        }
    }
}

/// Individual segment button
private struct SegmentButton: View {
    let item: SegmentItem
    let isSelected: Bool
    let isHovered: Bool
    let size: CyberpunkSegmentedControl.SegmentSize
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(size.fontSize)
                }
                
                Text(item.title)
                    .font(size.fontSize)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if let badge = item.badge {
                    Text("\(badge)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(
                                    isSelected ?
                                    Color.white.opacity(0.3) :
                                    Color.hsl(0, 80, 60)
                                )
                        )
                }
            }
            .padding(size.padding)
            .frame(maxWidth: .infinity)
            .foregroundColor(
                isSelected ? Color.white :
                isHovered ? Color.hsl(0, 0, 85) :
                Color.hsl(240, 10, 75)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    struct SegmentedControlPreview: View {
        @State private var selected1 = 0
        @State private var selected2 = 0
        @State private var selected3 = 0
        @State private var selected4 = 0
        
        let segments = [
            SegmentItem(title: "All"),
            SegmentItem(title: "Active"),
            SegmentItem(title: "Completed")
        ]
        
        let segmentsWithIcons = [
            SegmentItem(title: "Grid", icon: "square.grid.2x2"),
            SegmentItem(title: "List", icon: "list.bullet"),
            SegmentItem(title: "Cards", icon: "rectangle.stack")
        ]
        
        let segmentsWithBadges = [
            SegmentItem(title: "Inbox", badge: 12),
            SegmentItem(title: "Sent"),
            SegmentItem(title: "Drafts", badge: 3),
            SegmentItem(title: "Spam", badge: 99)
        ]
        
        var body: some View {
            ScrollView {
                VStack(spacing: 32) {
                    // Filled style
                    VStack(spacing: 16) {
                        Text("Filled Style")
                            .font(.headline)
                            .foregroundColor(Color.hsl(0, 0, 95))
                        
                        CyberpunkSegmentedControl(
                            segments: segments,
                            selectedIndex: $selected1,
                            style: .filled
                        )
                        
                        CyberpunkSegmentedControl(
                            segments: segmentsWithIcons,
                            selectedIndex: $selected2,
                            style: .filled,
                            size: .large
                        )
                    }
                    
                    // Outlined style
                    VStack(spacing: 16) {
                        Text("Outlined Style")
                            .font(.headline)
                            .foregroundColor(Color.hsl(0, 0, 95))
                        
                        CyberpunkSegmentedControl(
                            segments: segments,
                            selectedIndex: $selected1,
                            style: .outlined
                        )
                    }
                    
                    // Underlined style
                    VStack(spacing: 16) {
                        Text("Underlined Style")
                            .font(.headline)
                            .foregroundColor(Color.hsl(0, 0, 95))
                        
                        CyberpunkSegmentedControl(
                            segments: segmentsWithBadges,
                            selectedIndex: $selected3,
                            style: .underlined
                        )
                    }
                    
                    // Pills style
                    VStack(spacing: 16) {
                        Text("Pills Style")
                            .font(.headline)
                            .foregroundColor(Color.hsl(0, 0, 95))
                        
                        CyberpunkSegmentedControl(
                            segments: segments,
                            selectedIndex: $selected4,
                            style: .pills
                        )
                        
                        CyberpunkSegmentedControl(
                            segments: segmentsWithIcons,
                            selectedIndex: $selected2,
                            style: .pills,
                            size: .small
                        )
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.hsl(240, 10, 5))
        }
    }
    
    return SegmentedControlPreview()
}