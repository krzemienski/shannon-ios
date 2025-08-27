//
//  TerminalSettingsView.swift
//  ClaudeCode
//
//  Terminal settings configuration view
//

import SwiftUI

/// Terminal settings view
public struct TerminalSettingsView: View {
    @Binding var settings: TerminalSettings
    @Environment(\.dismiss) private var dismiss
    
    // Color schemes
    private let colorSchemes = [
        "cyberpunk": "Cyberpunk",
        "monokai": "Monokai", 
        "solarized-dark": "Solarized Dark",
        "solarized-light": "Solarized Light",
        "dracula": "Dracula",
        "nord": "Nord",
        "gruvbox": "Gruvbox"
    ]
    
    // Font families
    private let fontFamilies = [
        "SF Mono": "SF Mono",
        "Menlo": "Menlo",
        "Monaco": "Monaco",
        "Courier": "Courier",
        "Fira Code": "Fira Code"
    ]
    
    public var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                behaviorSection
                performanceSection
                keyboardSection
            }
            .navigationTitle("Terminal Settings")
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
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        Section("Appearance") {
            // Font family
            Picker("Font", selection: $settings.fontFamily) {
                ForEach(fontFamilies.keys.sorted(), id: \.self) { key in
                    Text(fontFamilies[key] ?? key)
                        .tag(key)
                }
            }
            
            // Font size
            HStack {
                Text("Font Size")
                Spacer()
                Stepper("\(Int(settings.fontSize))pt", value: $settings.fontSize, in: 10...24)
            }
            
            // Color scheme
            Picker("Color Scheme", selection: $settings.colorScheme) {
                ForEach(colorSchemes.keys.sorted(), id: \.self) { key in
                    Text(colorSchemes[key] ?? key)
                        .tag(key)
                }
            }
            
            // Cursor style
            Picker("Cursor Style", selection: $settings.cursorStyle) {
                Text("Block").tag(CursorStyle.block)
                Text("Underline").tag(CursorStyle.underline)
                Text("Bar").tag(CursorStyle.bar)
            }
        }
    }
    
    // MARK: - Behavior Section
    
    private var behaviorSection: some View {
        Section("Behavior") {
            // Bell sound
            Toggle("Bell Sound", isOn: $settings.bellSound)
            
            // Scrollback lines
            HStack {
                Text("Scrollback Lines")
                Spacer()
                TextField("10000", value: $settings.scrollbackLines, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }
            
            // Auto-copy selection
            Toggle("Auto-copy Selection", isOn: $settings.autoCopySelection)
            
            // Mouse reporting
            Toggle("Mouse Reporting", isOn: $settings.mouseReporting)
        }
    }
    
    // MARK: - Performance Section
    
    private var performanceSection: some View {
        Section("Performance") {
            // GPU acceleration
            Toggle("GPU Acceleration", isOn: $settings.gpuAcceleration)
            
            // Smooth scrolling
            Toggle("Smooth Scrolling", isOn: $settings.smoothScrolling)
            
            // Render throttling
            HStack {
                Text("Max FPS")
                Spacer()
                Picker("", selection: $settings.maxFPS) {
                    Text("30").tag(30)
                    Text("60").tag(60)
                    Text("120").tag(120)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }
    
    // MARK: - Keyboard Section
    
    private var keyboardSection: some View {
        Section("Keyboard") {
            // Option as Meta
            Toggle("Option as Meta Key", isOn: $settings.optionAsMeta)
            
            // Keyboard shortcuts
            NavigationLink("Keyboard Shortcuts") {
                KeyboardShortcutsView()
            }
            
            // Input method
            Picker("Input Method", selection: $settings.inputMethod) {
                Text("System").tag("system")
                Text("Direct").tag("direct")
                Text("Legacy").tag("legacy")
            }
        }
    }
    
    private func saveSettings() {
        // Save settings to UserDefaults
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "terminal_settings")
        }
    }
}

/// Keyboard shortcuts configuration view
struct KeyboardShortcutsView: View {
    var body: some View {
        List {
            Section("Navigation") {
                ShortcutRow(action: "Previous Tab", shortcut: "⌘[")
                ShortcutRow(action: "Next Tab", shortcut: "⌘]")
                ShortcutRow(action: "New Tab", shortcut: "⌘T")
                ShortcutRow(action: "Close Tab", shortcut: "⌘W")
            }
            
            Section("Terminal") {
                ShortcutRow(action: "Clear Screen", shortcut: "⌘K")
                ShortcutRow(action: "Reset Terminal", shortcut: "⌘R")
                ShortcutRow(action: "Find", shortcut: "⌘F")
                ShortcutRow(action: "Paste", shortcut: "⌘V")
            }
            
            Section("Session") {
                ShortcutRow(action: "Disconnect", shortcut: "⌘D")
                ShortcutRow(action: "Reconnect", shortcut: "⌘⇧R")
                ShortcutRow(action: "Session Info", shortcut: "⌘I")
            }
        }
        .navigationTitle("Keyboard Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ShortcutRow: View {
    let action: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Extended Terminal Settings

extension TerminalSettings {
    public var autoCopySelection: Bool {
        get { UserDefaults.standard.bool(forKey: "terminal_auto_copy") }
        set { UserDefaults.standard.set(newValue, forKey: "terminal_auto_copy") }
    }
    
    public var mouseReporting: Bool {
        get { UserDefaults.standard.bool(forKey: "terminal_mouse_reporting") }
        set { UserDefaults.standard.set(newValue, forKey: "terminal_mouse_reporting") }
    }
    
    public var gpuAcceleration: Bool {
        get { UserDefaults.standard.bool(forKey: "terminal_gpu_acceleration") }
        set { UserDefaults.standard.set(newValue, forKey: "terminal_gpu_acceleration") }
    }
    
    public var smoothScrolling: Bool {
        get { UserDefaults.standard.bool(forKey: "terminal_smooth_scrolling") }
        set { UserDefaults.standard.set(newValue, forKey: "terminal_smooth_scrolling") }
    }
    
    public var maxFPS: Int {
        get { UserDefaults.standard.integer(forKey: "terminal_max_fps") != 0 ? UserDefaults.standard.integer(forKey: "terminal_max_fps") : 60 }
        set { UserDefaults.standard.set(newValue, forKey: "terminal_max_fps") }
    }
    
    public var optionAsMeta: Bool {
        get { UserDefaults.standard.bool(forKey: "terminal_option_meta") }
        set { UserDefaults.standard.set(newValue, forKey: "terminal_option_meta") }
    }
    
    public var inputMethod: String {
        get { UserDefaults.standard.string(forKey: "terminal_input_method") ?? "system" }
        set { UserDefaults.standard.set(newValue, forKey: "terminal_input_method") }
    }
}