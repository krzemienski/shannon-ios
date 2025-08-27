//
//  CodeEditorSettingsView.swift
//  ClaudeCode
//
//  Editor preferences and configuration view
//

import SwiftUI

/// Code editor settings view
struct CodeEditorSettingsView: View {
    @Binding var configuration: EditorConfiguration
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTheme: String = "Default"
    
    private let themes = ["Default", "Dark", "Light", "Monokai", "Solarized", "Dracula"]
    private let fontSizes: [CGFloat] = [10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24]
    private let tabSizes: [Int] = [2, 4, 8]
    
    var body: some View {
        NavigationStack {
            Form {
                // Appearance Section
                Section("Appearance") {
                    // Theme
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    }
                    
                    // Font Size
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Menu {
                            ForEach(fontSizes, id: \.self) { size in
                                Button("\(Int(size))pt") {
                                    updateFontSize(size)
                                }
                            }
                        } label: {
                            Text("\(Int(configuration.font.pointSize))pt")
                                .foregroundColor(Theme.accent)
                        }
                    }
                    
                    // Line Numbers
                    Toggle("Show Line Numbers", isOn: $configuration.showLineNumbers)
                    
                    // Show Invisibles
                    Toggle("Show Invisible Characters", isOn: $configuration.showInvisibles)
                    
                    // Word Wrap
                    Toggle("Word Wrap", isOn: $configuration.wordWrap)
                }
                
                // Editor Behavior Section
                Section("Editor Behavior") {
                    // Tab Size
                    Picker("Tab Size", selection: $configuration.tabSize) {
                        ForEach(tabSizes, id: \.self) { size in
                            Text("\(size) spaces").tag(size)
                        }
                    }
                    
                    // Use Tabs
                    Toggle("Use Tabs Instead of Spaces", isOn: $configuration.useTabs)
                    
                    // Auto Indent
                    Toggle("Auto Indent", isOn: $configuration.autoIndent)
                    
                    // Auto Close Brackets
                    Toggle("Auto Close Brackets", isOn: $configuration.autoCloseBrackets)
                }
                
                // Code Completion Section
                Section("Code Completion") {
                    Toggle("Enable Code Completion", isOn: .constant(true))
                    Toggle("Show Snippets", isOn: .constant(true))
                    Toggle("Auto Import Suggestions", isOn: .constant(true))
                    
                    HStack {
                        Text("Completion Trigger")
                        Spacer()
                        Menu {
                            Button("Automatic") { }
                            Button("Manual (Ctrl+Space)") { }
                            Button("On Typing") { }
                        } label: {
                            Text("Automatic")
                                .foregroundColor(Theme.accent)
                        }
                    }
                }
                
                // Syntax Highlighting Section
                Section("Syntax Highlighting") {
                    Toggle("Enable Syntax Highlighting", isOn: .constant(true))
                    Toggle("Highlight Current Line", isOn: .constant(true))
                    Toggle("Highlight Matching Brackets", isOn: .constant(true))
                    Toggle("Semantic Highlighting", isOn: .constant(false))
                }
                
                // Performance Section
                Section("Performance") {
                    HStack {
                        Text("Max File Size")
                        Spacer()
                        Text("10 MB")
                            .foregroundColor(Theme.muted)
                    }
                    
                    HStack {
                        Text("Syntax Highlight Delay")
                        Spacer()
                        Text("100ms")
                            .foregroundColor(Theme.muted)
                    }
                    
                    Toggle("Use Background Parsing", isOn: .constant(true))
                    Toggle("Enable File Caching", isOn: .constant(true))
                }
                
                // Advanced Section
                Section("Advanced") {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(Theme.destructive)
                    
                    Button("Export Settings") {
                        exportSettings()
                    }
                    
                    Button("Import Settings") {
                        importSettings()
                    }
                }
            }
            .navigationTitle("Editor Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Methods
    
    private func updateFontSize(_ size: CGFloat) {
        configuration.font = .monospacedSystemFont(ofSize: size, weight: .regular)
        configuration.boldFont = .monospacedSystemFont(ofSize: size, weight: .semibold)
    }
    
    private func resetToDefaults() {
        configuration = .default
        selectedTheme = "Default"
    }
    
    private func saveSettings() {
        // Save settings to UserDefaults or persistent storage
        UserDefaults.standard.set(configuration.tabSize, forKey: "editor.tabSize")
        UserDefaults.standard.set(configuration.useTabs, forKey: "editor.useTabs")
        UserDefaults.standard.set(configuration.showLineNumbers, forKey: "editor.showLineNumbers")
        UserDefaults.standard.set(configuration.autoIndent, forKey: "editor.autoIndent")
        UserDefaults.standard.set(configuration.autoCloseBrackets, forKey: "editor.autoCloseBrackets")
        UserDefaults.standard.set(configuration.wordWrap, forKey: "editor.wordWrap")
        UserDefaults.standard.set(configuration.showInvisibles, forKey: "editor.showInvisibles")
        UserDefaults.standard.set(selectedTheme, forKey: "editor.theme")
    }
    
    private func exportSettings() {
        // Export settings to file
        print("Export settings")
    }
    
    private func importSettings() {
        // Import settings from file
        print("Import settings")
    }
}

// MARK: - Theme Presets

extension EditorTheme {
    static let monokai = EditorTheme(
        name: "Monokai",
        textColor: UIColor(red: 0.97, green: 0.97, blue: 0.94, alpha: 1.0),
        backgroundColor: UIColor(red: 0.15, green: 0.16, blue: 0.13, alpha: 1.0),
        lineNumberColor: UIColor(red: 0.54, green: 0.54, blue: 0.50, alpha: 1.0),
        currentLineColor: UIColor(red: 0.24, green: 0.24, blue: 0.20, alpha: 1.0),
        selectionColor: UIColor(red: 0.30, green: 0.30, blue: 0.25, alpha: 1.0),
        keywordColor: UIColor(red: 0.98, green: 0.15, blue: 0.45, alpha: 1.0),
        typeColor: UIColor(red: 0.40, green: 0.85, blue: 0.94, alpha: 1.0),
        stringColor: UIColor(red: 0.90, green: 0.86, blue: 0.45, alpha: 1.0),
        numberColor: UIColor(red: 0.68, green: 0.51, blue: 1.0, alpha: 1.0),
        commentColor: UIColor(red: 0.46, green: 0.44, blue: 0.37, alpha: 1.0),
        functionColor: UIColor(red: 0.65, green: 0.89, blue: 0.18, alpha: 1.0),
        operatorColor: UIColor(red: 0.98, green: 0.15, blue: 0.45, alpha: 1.0)
    )
    
    static let solarized = EditorTheme(
        name: "Solarized Dark",
        textColor: UIColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1.0),
        backgroundColor: UIColor(red: 0.0, green: 0.17, blue: 0.21, alpha: 1.0),
        lineNumberColor: UIColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 1.0),
        currentLineColor: UIColor(red: 0.03, green: 0.21, blue: 0.26, alpha: 1.0),
        selectionColor: UIColor(red: 0.03, green: 0.21, blue: 0.26, alpha: 1.0),
        keywordColor: UIColor(red: 0.52, green: 0.60, blue: 0.0, alpha: 1.0),
        typeColor: UIColor(red: 0.71, green: 0.54, blue: 0.0, alpha: 1.0),
        stringColor: UIColor(red: 0.16, green: 0.63, blue: 0.60, alpha: 1.0),
        numberColor: UIColor(red: 0.86, green: 0.20, blue: 0.18, alpha: 1.0),
        commentColor: UIColor(red: 0.35, green: 0.43, blue: 0.46, alpha: 1.0),
        functionColor: UIColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0),
        operatorColor: UIColor(red: 0.52, green: 0.60, blue: 0.0, alpha: 1.0)
    )
    
    static let dracula = EditorTheme(
        name: "Dracula",
        textColor: UIColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1.0),
        backgroundColor: UIColor(red: 0.16, green: 0.16, blue: 0.21, alpha: 1.0),
        lineNumberColor: UIColor(red: 0.38, green: 0.42, blue: 0.52, alpha: 1.0),
        currentLineColor: UIColor(red: 0.27, green: 0.28, blue: 0.35, alpha: 1.0),
        selectionColor: UIColor(red: 0.27, green: 0.28, blue: 0.35, alpha: 1.0),
        keywordColor: UIColor(red: 1.0, green: 0.47, blue: 0.60, alpha: 1.0),
        typeColor: UIColor(red: 0.54, green: 0.91, blue: 0.99, alpha: 1.0),
        stringColor: UIColor(red: 0.95, green: 0.98, blue: 0.55, alpha: 1.0),
        numberColor: UIColor(red: 0.74, green: 0.58, blue: 0.98, alpha: 1.0),
        commentColor: UIColor(red: 0.38, green: 0.42, blue: 0.64, alpha: 1.0),
        functionColor: UIColor(red: 0.31, green: 0.98, blue: 0.48, alpha: 1.0),
        operatorColor: UIColor(red: 1.0, green: 0.47, blue: 0.60, alpha: 1.0)
    )
    
    static let light = EditorTheme(
        name: "Light",
        textColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0),
        backgroundColor: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        lineNumberColor: UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0),
        currentLineColor: UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0),
        selectionColor: UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0),
        keywordColor: UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0),
        typeColor: UIColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 1.0),
        stringColor: UIColor(red: 0.64, green: 0.08, blue: 0.08, alpha: 1.0),
        numberColor: UIColor(red: 0.0, green: 0.0, blue: 0.81, alpha: 1.0),
        commentColor: UIColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0),
        functionColor: UIColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0),
        operatorColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
    )
    
    static func theme(named name: String) -> EditorTheme {
        switch name {
        case "Dark":
            return .dark
        case "Light":
            return .light
        case "Monokai":
            return .monokai
        case "Solarized":
            return .solarized
        case "Dracula":
            return .dracula
        default:
            return .default
        }
    }
}