//
//  ThemeSelectorView.swift
//  ClaudeCode
//
//  Theme selection view
//

import SwiftUI

struct ThemeSelectorView: View {
    @EnvironmentObject var coordinator: SettingsCoordinator
    @State private var selectedTheme = ThemeOption.dark
    @State private var accentColor = Color.blue
    
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $selectedTheme) {
                    ForEach(ThemeOption.allCases, id: \.self) { theme in
                        Label(theme.title, systemImage: theme.icon)
                            .tag(theme)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section("Accent Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5)) {
                    ForEach(AccentColor.allCases, id: \.self) { color in
                        Circle()
                            .fill(color.color)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: accentColor == color.color ? 3 : 0)
                            )
                            .onTapGesture {
                                accentColor = color.color
                            }
                    }
                }
                .padding(.vertical)
            }
            
            Section("Preview") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sample Title")
                        .font(Theme.Typography.titleFont)
                        .foregroundColor(Theme.foreground)
                    
                    Text("This is sample body text to preview the theme.")
                        .font(Theme.Typography.bodyFont)
                        .foregroundColor(Theme.mutedForeground)
                    
                    Button("Sample Button") {}
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)
                }
                .padding()
                .background(Theme.card)
                .cornerRadius(Theme.Radius.sm)
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum ThemeOption: String, CaseIterable {
    case light
    case dark
    case system
    
    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

enum AccentColor: CaseIterable {
    case blue
    case purple
    case green
    case orange
    case red
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        }
    }
}