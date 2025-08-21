//
//  CyberpunkTabBar.swift
//  ClaudeCode
//
//  Custom tab bar with cyberpunk styling
//

import SwiftUI

/// Tab item configuration
struct TabItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let selectedIcon: String?
    let badge: Int?
    
    init(
        title: String,
        icon: String,
        selectedIcon: String? = nil,
        badge: Int? = nil
    ) {
        self.title = title
        self.icon = icon
        self.selectedIcon = selectedIcon
        self.badge = badge
    }
}

/// Custom cyberpunk-styled tab bar
struct CyberpunkTabBar: View {
    let items: [TabItem]
    @Binding var selectedIndex: Int
    let showLabels: Bool
    let animateSelection: Bool
    
    @State private var hoveredIndex: Int? = nil
    @Namespace private var tabAnimation
    
    init(
        items: [TabItem],
        selectedIndex: Binding<Int>,
        showLabels: Bool = true,
        animateSelection: Bool = true
    ) {
        self.items = items
        self._selectedIndex = selectedIndex
        self.showLabels = showLabels
        self.animateSelection = animateSelection
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                TabBarItem(
                    item: items[index],
                    isSelected: selectedIndex == index,
                    isHovered: hoveredIndex == index,
                    showLabel: showLabels,
                    namespace: tabAnimation,
                    animateSelection: animateSelection
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedIndex = index
                    }
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
                .onHover { hovering in
                    withAnimation(.spring(response: 0.2)) {
                        hoveredIndex = hovering ? index : nil
                    }
                }
                
                if index < items.count - 1 {
                    Divider()
                        .frame(height: 20)
                        .background(Color.hsl(240, 10, 20))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.hsl(240, 10, 8),
                            Color.hsl(240, 10, 10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.hsl(240, 10, 20), lineWidth: 1)
                )
        )
        .shadow(
            color: Color.black.opacity(0.3),
            radius: 10,
            x: 0,
            y: 5
        )
    }
}

/// Individual tab bar item
private struct TabBarItem: View {
    let item: TabItem
    let isSelected: Bool
    let isHovered: Bool
    let showLabel: Bool
    let namespace: Namespace.ID
    let animateSelection: Bool
    let action: () -> Void
    
    @State private var iconRotation = 0.0
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Selection indicator background
                    if isSelected && animateSelection {
                        Circle()
                            .fill(Color.hsl(142, 70, 45).opacity(0.2))
                            .frame(width: 40, height: 40)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    }
                    
                    // Icon
                    Image(systemName: isSelected && item.selectedIcon != nil ? item.selectedIcon! : item.icon)
                        .font(.system(size: 20))
                        .foregroundColor(
                            isSelected ? Color.hsl(142, 70, 45) :
                            isHovered ? Color.hsl(0, 0, 85) :
                            Color.hsl(240, 10, 65)
                        )
                        .rotationEffect(.degrees(isSelected ? iconRotation : 0))
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .overlay(
                            // Badge
                            Group {
                                if let badge = item.badge {
                                    CyberpunkNotificationBadge(
                                        count: badge,
                                        variant: isSelected ? .primary : .error
                                    )
                                    .offset(x: 12, y: -12)
                                }
                            }
                        )
                }
                .frame(width: 44, height: 44)
                
                // Label
                if showLabel {
                    Text(item.title)
                        .font(.caption2)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(
                            isSelected ? Color.hsl(142, 70, 45) :
                            Color.hsl(240, 10, 65)
                        )
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3), value: isSelected)
        .onChange(of: isSelected) { newValue in
            if newValue {
                withAnimation(.spring(response: 0.5)) {
                    iconRotation = 360
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    iconRotation = 0
                }
            }
        }
    }
}

/// Floating action button for tab bar
struct CyberpunkFloatingTabButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var glowAnimation = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2)) {
                isPressed = true
            }
            
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }) {
            ZStack {
                // Glow effect
                Circle()
                    .fill(Color.hsl(142, 70, 45).opacity(0.3))
                    .frame(width: 64, height: 64)
                    .blur(radius: glowAnimation ? 8 : 4)
                    .scaleEffect(glowAnimation ? 1.2 : 1.0)
                
                // Button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.hsl(142, 70, 45),
                                Color.hsl(142, 70, 35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Color.hsl(142, 70, 55), lineWidth: 1)
                    )
                
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .shadow(
            color: Color.hsl(142, 70, 45).opacity(0.4),
            radius: 12,
            x: 0,
            y: 4
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    struct TabBarPreview: View {
        @State private var selectedTab = 0
        @State private var selectedTabWithBadges = 0
        
        let tabs = [
            TabItem(title: "Home", icon: "house", selectedIcon: "house.fill"),
            TabItem(title: "Search", icon: "magnifyingglass"),
            TabItem(title: "Projects", icon: "folder", selectedIcon: "folder.fill"),
            TabItem(title: "Settings", icon: "gearshape", selectedIcon: "gearshape.fill")
        ]
        
        let tabsWithBadges = [
            TabItem(title: "Chat", icon: "message", selectedIcon: "message.fill", badge: 3),
            TabItem(title: "Tools", icon: "wrench.and.screwdriver", selectedIcon: "wrench.and.screwdriver.fill"),
            TabItem(title: "Monitor", icon: "chart.line.uptrend.xyaxis", badge: 12),
            TabItem(title: "Profile", icon: "person.circle", selectedIcon: "person.circle.fill", badge: 1)
        ]
        
        var body: some View {
            VStack(spacing: 40) {
                // Standard tab bar
                VStack(spacing: 20) {
                    Text("Standard Tab Bar")
                        .font(.headline)
                        .foregroundColor(Color.hsl(0, 0, 95))
                    
                    CyberpunkTabBar(
                        items: tabs,
                        selectedIndex: $selectedTab
                    )
                    .padding(.horizontal)
                }
                
                // Tab bar with badges
                VStack(spacing: 20) {
                    Text("Tab Bar with Badges")
                        .font(.headline)
                        .foregroundColor(Color.hsl(0, 0, 95))
                    
                    CyberpunkTabBar(
                        items: tabsWithBadges,
                        selectedIndex: $selectedTabWithBadges
                    )
                    .padding(.horizontal)
                }
                
                // Tab bar without labels
                VStack(spacing: 20) {
                    Text("Compact Tab Bar")
                        .font(.headline)
                        .foregroundColor(Color.hsl(0, 0, 95))
                    
                    CyberpunkTabBar(
                        items: tabs,
                        selectedIndex: $selectedTab,
                        showLabels: false
                    )
                    .padding(.horizontal)
                }
                
                // Floating action button
                VStack(spacing: 20) {
                    Text("Floating Action Button")
                        .font(.headline)
                        .foregroundColor(Color.hsl(0, 0, 95))
                    
                    CyberpunkFloatingTabButton(icon: "plus") {
                        print("FAB tapped")
                    }
                }
                
                Spacer()
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.hsl(240, 10, 5))
        }
    }
    
    return TabBarPreview()
}