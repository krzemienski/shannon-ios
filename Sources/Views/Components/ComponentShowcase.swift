//
//  ComponentShowcase.swift
//  ClaudeCode
//
//  Showcase view demonstrating all cyberpunk UI components
//

import SwiftUI

struct ComponentShowcase: View {
    @State private var selectedTab = 0
    @State private var toggleState = false
    @State private var textFieldValue = ""
    @State private var sliderValue = 50.0
    @State private var selectedSegment = 0
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero Section
                    heroSection
                    
                    // Core Components
                    coreComponentsSection
                    
                    // Form Components
                    formComponentsSection
                    
                    // Feedback Components
                    feedbackSection
                    
                    // Navigation Components
                    navigationSection
                }
                .padding()
            }
            .navigationTitle("Component Showcase")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.hsl(240, 10, 5))
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        CyberpunkCard(elevation: .floating, glowEffect: true) {
            VStack(spacing: 16) {
                Image(systemName: "cpu")
                    .font(.system(size: 48))
                    .foregroundColor(Color.hsl(142, 70, 45))
                
                Text("Claude Code iOS")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color.hsl(0, 0, 95))
                
                Text("Cyberpunk UI Components")
                    .font(.body)
                    .foregroundColor(Color.hsl(240, 10, 65))
                
                HStack(spacing: 12) {
                    CyberpunkBadge("v1.0", variant: .primary, animated: true)
                    CyberpunkBadge("iOS 18+", variant: .info)
                    CyberpunkBadge("SwiftUI", variant: .success)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Core Components
    private var coreComponentsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Core Components")
            
            // Buttons
            VStack(spacing: 12) {
                CyberpunkButton("Primary Action", icon: "bolt.fill", variant: .primary) {
                    print("Primary action")
                }
                
                HStack(spacing: 12) {
                    CyberpunkButton("Secondary", variant: .secondary, size: .small) {
                        print("Secondary")
                    }
                    
                    CyberpunkButton("Ghost", variant: .ghost, size: .small) {
                        print("Ghost")
                    }
                    
                    CyberpunkButton("Danger", icon: "trash", variant: .destructive, size: .small) {
                        print("Delete")
                    }
                }
            }
            
            // Cards
            CyberpunkHeaderCard(elevation: .elevated) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(Color.hsl(142, 70, 45))
                    Text("Feature Card")
                        .font(.headline)
                        .foregroundColor(Color.hsl(0, 0, 95))
                    Spacer()
                    CyberpunkBadge("New", variant: .primary, size: .small)
                }
            } content: {
                Text("This is a card with a header section and content area. Perfect for organizing information.")
                    .font(.body)
                    .foregroundColor(Color.hsl(240, 10, 75))
            }
            
            // Badges and Chips
            VStack(alignment: .leading, spacing: 12) {
                Text("Badges & Chips")
                    .font(.caption)
                    .foregroundColor(Color.hsl(240, 10, 65))
                
                HStack(spacing: 8) {
                    CyberpunkChip("Swift", icon: "swift")
                    CyberpunkChip("iOS", variant: .primary)
                    CyberpunkChip("Removable", onDismiss: {})
                }
            }
        }
    }
    
    // MARK: - Form Components
    private var formComponentsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Form Components")
            
            // Text Field
            CyberpunkTextField(
                "Username",
                placeholder: "Enter your username",
                text: $textFieldValue,
                icon: "person.fill",
                state: textFieldValue.isEmpty ? .normal : .success,
                helperText: textFieldValue.isEmpty ? nil : "Username looks good!"
            )
            
            // Toggle
            CyberpunkToggle(
                "Enable Features",
                subtitle: "Activate advanced features",
                isOn: $toggleState,
                icon: "sparkles"
            )
            
            // Slider
            CyberpunkSlider(
                value: $sliderValue,
                in: 0...100,
                label: "Performance",
                variant: sliderValue > 80 ? .success : sliderValue > 50 ? .primary : .warning
            )
            
            // Segmented Control
            CyberpunkSegmentedControl(
                segments: [
                    SegmentItem(title: "Day"),
                    SegmentItem(title: "Week"),
                    SegmentItem(title: "Month")
                ],
                selectedIndex: $selectedSegment,
                style: .filled
            )
        }
    }
    
    // MARK: - Feedback Section
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Feedback Components")
            
            // Progress Indicators
            VStack(spacing: 16) {
                CyberpunkProgressBar(
                    value: 0.7,
                    label: "Processing",
                    variant: .primary
                )
                
                HStack(spacing: 20) {
                    CyberpunkCircularProgress(
                        value: 0.6,
                        size: 60
                    )
                    
                    CyberpunkSpinner(size: 40)
                    
                    Spacer()
                }
            }
            
            // Alerts
            CyberpunkAlert(
                title: "Success!",
                message: "Operation completed successfully",
                type: .success
            )
            
            CyberpunkToast(
                message: "3 new notifications",
                type: .info
            )
        }
    }
    
    // MARK: - Navigation Section
    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Navigation Components")
            
            // Tab Bar
            CyberpunkTabBar(
                items: [
                    TabItem(title: "Home", icon: "house", selectedIcon: "house.fill"),
                    TabItem(title: "Search", icon: "magnifyingglass"),
                    TabItem(title: "Profile", icon: "person", selectedIcon: "person.fill", badge: 2)
                ],
                selectedIndex: $selectedTab
            )
            
            // List Items
            VStack(spacing: 0) {
                CyberpunkListSection("Settings")
                
                CyberpunkIconListItem(
                    icon: "gear",
                    title: "General",
                    subtitle: "App preferences",
                    action: .chevron
                )
                
                CyberpunkIconListItem(
                    icon: "bell.fill",
                    iconColor: Color.hsl(45, 80, 60),
                    title: "Notifications",
                    badge: 3,
                    action: .toggle(isOn: $toggleState)
                )
                
                CyberpunkIconListItem(
                    icon: "moon.fill",
                    iconColor: Color.hsl(280, 70, 50),
                    title: "Appearance",
                    subtitle: "Dark mode enabled",
                    action: .chevron
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hsl(240, 10, 8))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Helper Views
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(Color.hsl(142, 70, 45))
    }
}

// MARK: - Preview
#Preview {
    ComponentShowcase()
        .preferredColorScheme(.dark)
}