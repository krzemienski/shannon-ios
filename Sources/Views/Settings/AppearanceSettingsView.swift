//
//  AppearanceSettingsView.swift
//  ClaudeCode
//
//  Appearance and theme customization settings
//

import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var previewText = "The quick brown fox jumps over the lazy dog"
    @State private var showingColorPicker = false
    @State private var selectedColorType: ColorType = .primary
    
    var body: some View {
        List {
            // Theme Selection
            Section {
                VStack(alignment: .leading, spacing: ThemeSpacing.md) {
                    Label {
                        Text("App Theme")
                            .foregroundColor(Theme.foreground)
                    } icon: {
                        Image(systemName: "paintbrush")
                            .foregroundColor(Theme.primary)
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: ThemeSpacing.sm) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            ThemeOptionCard(
                                theme: theme,
                                isSelected: settingsStore.theme == theme
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    settingsStore.theme = theme
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("THEME")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
            .listRowBackground(Theme.card)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            
            // Typography Settings
            Section {
                // Font Size
                VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                    Label {
                        Text("Font Size")
                            .foregroundColor(Theme.foreground)
                    } icon: {
                        Image(systemName: "textformat.size")
                            .foregroundColor(Theme.secondary)
                    }
                    
                    CyberpunkSegmentedControl(
                        selection: .init(
                            get: { settingsStore.fontSize.rawValue },
                            set: { 
                                if let size = FontSize(rawValue: $0) {
                                    settingsStore.fontSize = size
                                }
                            }
                        ),
                        options: FontSize.allCases.map { ($0.rawValue, $0.displayName) }
                    )
                    
                    // Preview
                    Text(previewText)
                        .font(.system(size: 14 * settingsStore.fontSize.scaleFactor))
                        .foregroundColor(Theme.mutedForeground)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.input)
                        .cornerRadius(ThemeRadius.sm)
                }
                
                // Font Weight
                CyberpunkToggle(
                    "Bold Text",
                    subtitle: "Use heavier font weights throughout the app",
                    isOn: $settingsStore.useBoldText,
                    icon: "bold"
                )
                
                // Monospace for Code
                CyberpunkToggle(
                    "Monospace Code",
                    subtitle: "Use monospace font for code blocks",
                    isOn: $settingsStore.useMonospaceCode,
                    icon: "chevron.left.forwardslash.chevron.right"
                )
            } header: {
                Text("TYPOGRAPHY")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
            .listRowBackground(Theme.card)
            
            // Color Customization
            Section {
                // Accent Colors
                VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                    Label {
                        Text("Accent Colors")
                            .foregroundColor(Theme.foreground)
                    } icon: {
                        Image(systemName: "paintpalette")
                            .foregroundColor(Theme.accent)
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: ThemeSpacing.sm) {
                        ForEach(ColorType.allCases, id: \.self) { type in
                            ColorSwatch(
                                color: colorForType(type),
                                label: type.displayName
                            ) {
                                selectedColorType = type
                                showingColorPicker = true
                            }
                        }
                    }
                }
                
                // Contrast Settings
                CyberpunkToggle(
                    "High Contrast",
                    subtitle: "Increase contrast for better visibility",
                    isOn: $settingsStore.highContrast,
                    icon: "circle.lefthalf.filled"
                )
                
                // Reduce Transparency
                CyberpunkToggle(
                    "Reduce Transparency",
                    subtitle: "Minimize transparent UI elements",
                    isOn: $settingsStore.reduceTransparency,
                    icon: "square.fill"
                )
            } header: {
                Text("COLORS")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
            .listRowBackground(Theme.card)
            
            // Animation Settings
            Section {
                CyberpunkToggle(
                    "Enable Animations",
                    subtitle: "Show animations and transitions",
                    isOn: $settingsStore.enableAnimations,
                    icon: "wand.and.rays"
                )
                
                CyberpunkToggle(
                    "Reduce Motion",
                    subtitle: "Minimize movement in animations",
                    isOn: $settingsStore.reduceMotion,
                    icon: "figure.walk.motion"
                )
                
                // Animation Speed
                if settingsStore.enableAnimations && !settingsStore.reduceMotion {
                    VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                        HStack {
                            Label {
                                Text("Animation Speed")
                                    .foregroundColor(Theme.foreground)
                            } icon: {
                                Image(systemName: "speedometer")
                                    .foregroundColor(Theme.secondary)
                            }
                            
                            Spacer()
                            
                            Text(String(format: "%.1fx", settingsStore.animationSpeed))
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.mutedForeground)
                        }
                        
                        CyberpunkSlider(
                            value: $settingsStore.animationSpeed,
                            in: 0.5...2.0,
                            step: 0.1
                        )
                    }
                }
            } header: {
                Text("ANIMATIONS")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
            .listRowBackground(Theme.card)
            
            // Accessibility
            Section {
                CyberpunkToggle(
                    "Smart Invert",
                    subtitle: "Invert colors except for images",
                    isOn: $settingsStore.smartInvert,
                    icon: "circle.righthalf.filled"
                )
                
                CyberpunkToggle(
                    "Button Shapes",
                    subtitle: "Show shapes around interactive elements",
                    isOn: $settingsStore.buttonShapes,
                    icon: "square.dashed"
                )
                
                CyberpunkToggle(
                    "Differentiate Without Color",
                    subtitle: "Use symbols in addition to colors",
                    isOn: $settingsStore.differentiateWithoutColor,
                    icon: "circle.hexagongrid"
                )
            } header: {
                Text("ACCESSIBILITY")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerSheet(
                colorType: selectedColorType,
                currentColor: colorForType(selectedColorType)
            ) { newColor in
                updateColor(newColor, for: selectedColorType)
            }
        }
    }
    
    private func colorForType(_ type: ColorType) -> Color {
        switch type {
        case .primary: return Theme.primary
        case .secondary: return Theme.secondary
        case .accent: return Theme.accent
        case .success: return Theme.success
        case .warning: return Theme.warning
        case .destructive: return Theme.destructive
        }
    }
    
    private func updateColor(_ color: Color, for type: ColorType) {
        // Implementation for updating custom colors
        print("Updating \(type.displayName) to \(color)")
    }
}

// MARK: - Supporting Types

enum ColorType: CaseIterable {
    case primary, secondary, accent, success, warning, destructive
    
    var displayName: String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        case .accent: return "Accent"
        case .success: return "Success"
        case .warning: return "Warning"
        case .destructive: return "Error"
        }
    }
}

// MARK: - Theme Option Card

struct ThemeOptionCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Preview
                ZStack {
                    RoundedRectangle(cornerRadius: ThemeRadius.sm)
                        .fill(backgroundColor)
                        .frame(height: 60)
                    
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(foregroundColor)
                            .frame(width: 30, height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(foregroundColor.opacity(0.6))
                            .frame(width: 20, height: 3)
                    }
                }
                
                Text(theme.displayName)
                    .font(Theme.Typography.caption)
                    .foregroundColor(isSelected ? Theme.primary : Theme.mutedForeground)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: ThemeRadius.md)
                    .fill(isSelected ? Theme.primary.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeRadius.md)
                            .stroke(isSelected ? Theme.primary : Theme.border, lineWidth: 1)
                    )
            )
        }
    }
    
    private var backgroundColor: Color {
        switch theme {
        case .light: return Color.white
        case .dark: return Color.black
        case .system: return Theme.background
        }
    }
    
    private var foregroundColor: Color {
        switch theme {
        case .light: return Color.black
        case .dark: return Color.white
        case .system: return Theme.foreground
        }
    }
}

// MARK: - Color Swatch

struct ColorSwatch: View {
    let color: Color
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(Theme.border, lineWidth: 1)
                    )
                
                Text(label)
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.muted)
            }
        }
    }
}

// MARK: - Color Picker Sheet

struct ColorPickerSheet: View {
    let colorType: ColorType
    let currentColor: Color
    let onSave: (Color) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedColor: Color
    
    init(colorType: ColorType, currentColor: Color, onSave: @escaping (Color) -> Void) {
        self.colorType = colorType
        self.currentColor = currentColor
        self.onSave = onSave
        self._selectedColor = State(initialValue: currentColor)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: ThemeSpacing.lg) {
                ColorPicker("Select Color", selection: $selectedColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(height: 200)
                
                Spacer()
            }
            .padding()
            .navigationTitle("\(colorType.displayName) Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedColor)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings Store Extensions

extension SettingsStore {
    @Published var useBoldText: Bool = false
    @Published var useMonospaceCode: Bool = true
    @Published var highContrast: Bool = false
    @Published var reduceTransparency: Bool = false
    @Published var enableAnimations: Bool = true
    @Published var reduceMotion: Bool = false
    @Published var animationSpeed: Double = 1.0
    @Published var smartInvert: Bool = false
    @Published var buttonShapes: Bool = false
    @Published var differentiateWithoutColor: Bool = false
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
            .environmentObject(SettingsStore())
    }
    .preferredColorScheme(.dark)
}