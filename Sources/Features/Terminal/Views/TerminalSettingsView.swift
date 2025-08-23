//
//  TerminalSettingsView.swift
//  ClaudeCode
//
//  Terminal preferences and configuration (Tasks 623-625)
//

import SwiftUI

/// Terminal settings view
public struct TerminalSettingsView: View {
    @State var settings: TerminalSettings
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showColorSchemePreview = false
    @State private var testText = "user@host:~$ echo 'Hello, Terminal!'\nHello, Terminal!\nuser@host:~$ "
    
    public var body: some View {
        NavigationView {
            Form {
                // Settings sections based on selected tab
                Picker("Category", selection: $selectedTab) {
                    Text("Appearance").tag(0)
                    Text("Terminal").tag(1)
                    Text("Connection").tag(2)
                    Text("Advanced").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.vertical)
                
                switch selectedTab {
                case 0:
                    appearanceSettings
                case 1:
                    terminalSettings
                case 2:
                    connectionSettings
                case 3:
                    advancedSettings
                default:
                    EmptyView()
                }
            }
            .navigationTitle("Terminal Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settings.save()
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Appearance Settings
    
    private var appearanceSettings: some View {
        Group {
            Section("Font") {
                HStack {
                    Text("Font Family")
                    Spacer()
                    Picker("Font", selection: $settings.fontFamily) {
                        Text("SF Mono").tag("SF Mono")
                        Text("Menlo").tag("Menlo")
                        Text("Monaco").tag("Monaco")
                        Text("Courier New").tag("Courier New")
                        Text("Fira Code").tag("Fira Code")
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(Int(settings.fontSize))pt")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $settings.fontSize, in: 9...24, step: 1)
                
                Toggle("Enable Ligatures", isOn: $settings.enableLigatures)
                    .disabled(settings.fontFamily != "Fira Code")
            }
            
            Section("Colors") {
                HStack {
                    Text("Color Scheme")
                    Spacer()
                    Picker("Scheme", selection: $settings.colorScheme) {
                        ForEach(TerminalSettings.ColorScheme.allCases, id: \.self) { scheme in
                            Text(schemeDisplayName(scheme)).tag(scheme)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Toggle("Enable Colors", isOn: $settings.enableColors)
                
                Button("Preview Color Scheme") {
                    showColorSchemePreview = true
                }
            }
            
            Section("Cursor") {
                Picker("Cursor Style", selection: $settings.cursorStyle) {
                    ForEach(TerminalSettings.CursorStyle.allCases, id: \.self) { style in
                        Label(
                            cursorStyleName(style),
                            systemImage: cursorStyleIcon(style)
                        ).tag(style)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Toggle("Cursor Blink", isOn: $settings.cursorBlink)
            }
            
            Section("Display") {
                Toggle("Show Timestamps", isOn: $settings.showTimestamps)
                Toggle("Wrap Lines", isOn: $settings.wrapLines)
                Toggle("Show Scrollbar", isOn: $settings.showScrollbar)
            }
        }
    }
    
    // MARK: - Terminal Settings
    
    private var terminalSettings: some View {
        Group {
            Section("Scrollback") {
                HStack {
                    Text("Buffer Lines")
                    Spacer()
                    TextField("Lines", value: $settings.scrollbackLines, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }
                
                Text("Maximum number of lines to keep in scrollback buffer")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Bell") {
                Picker("Bell Style", selection: $settings.bellStyle) {
                    ForEach(TerminalSettings.BellStyle.allCases, id: \.self) { style in
                        Text(bellStyleName(style)).tag(style)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                if settings.bellStyle == .visual || settings.bellStyle == .both {
                    Button("Test Visual Bell") {
                        // TODO: Trigger visual bell test
                    }
                }
                
                if settings.bellStyle == .sound || settings.bellStyle == .both {
                    Button("Test Sound Bell") {
                        // TODO: Trigger sound bell test
                    }
                }
            }
            
            Section("Input") {
                Toggle("Enable Auto-complete", isOn: .constant(true))
                Toggle("Enable Command History", isOn: .constant(true))
                
                HStack {
                    Text("History Size")
                    Spacer()
                    TextField("Commands", value: .constant(1000), format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
    
    // MARK: - Connection Settings
    
    private var connectionSettings: some View {
        Group {
            Section("Connection") {
                Toggle("Auto Connect", isOn: $settings.autoConnect)
                Toggle("Auto Reconnect", isOn: $settings.autoReconnect)
                
                HStack {
                    Text("Connection Timeout")
                    Spacer()
                    TextField("Seconds", value: $settings.connectionTimeout, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("sec")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Keep Alive") {
                HStack {
                    Text("Keep Alive Interval")
                    Spacer()
                    TextField("Seconds", value: $settings.keepAliveInterval, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Text("sec")
                        .foregroundColor(.secondary)
                }
                
                Text("Send keep-alive packets to prevent connection timeout")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Security") {
                Toggle("Strict Host Key Checking", isOn: $settings.strictHostKeyChecking)
                
                Text("When enabled, connections will fail if the host key doesn't match known hosts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Performance") {
                Toggle("Enable Compression", isOn: $settings.enableCompression)
                
                Text("Compress data for slower connections")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Advanced Settings
    
    private var advancedSettings: some View {
        Group {
            Section("Export & Import") {
                Button("Export Settings") {
                    exportSettings()
                }
                
                Button("Import Settings") {
                    importSettings()
                }
                
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .foregroundColor(.red)
            }
            
            Section("Clear Data") {
                Button("Clear Command History") {
                    clearCommandHistory()
                }
                
                Button("Clear Recent Connections") {
                    settings.recentConnections = []
                }
                
                Button("Clear All Terminal Data") {
                    clearAllData()
                }
                .foregroundColor(.red)
            }
            
            Section("Debug") {
                Toggle("Enable Debug Logging", isOn: .constant(false))
                Toggle("Show Raw ANSI Output", isOn: .constant(false))
                
                Button("Export Debug Logs") {
                    exportDebugLogs()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func schemeDisplayName(_ scheme: TerminalSettings.ColorScheme) -> String {
        switch scheme {
        case .default: return "Default"
        case .solarizedDark: return "Solarized Dark"
        case .solarizedLight: return "Solarized Light"
        case .monokai: return "Monokai"
        case .dracula: return "Dracula"
        case .nord: return "Nord"
        case .gruvbox: return "Gruvbox"
        case .oneDark: return "One Dark"
        }
    }
    
    private func cursorStyleName(_ style: TerminalSettings.CursorStyle) -> String {
        switch style {
        case .block: return "Block"
        case .underline: return "Underline"
        case .bar: return "Bar"
        }
    }
    
    private func cursorStyleIcon(_ style: TerminalSettings.CursorStyle) -> String {
        switch style {
        case .block: return "square.fill"
        case .underline: return "underline"
        case .bar: return "line.vertical"
        }
    }
    
    private func bellStyleName(_ style: TerminalSettings.BellStyle) -> String {
        switch style {
        case .none: return "None"
        case .visual: return "Visual"
        case .sound: return "Sound"
        case .both: return "Both"
        }
    }
    
    private func exportSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [data],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func importSettings() {
        // TODO: Implement settings import
    }
    
    private func resetToDefaults() {
        settings = TerminalSettings()
    }
    
    private func clearCommandHistory() {
        // TODO: Clear command history
    }
    
    private func clearAllData() {
        // TODO: Clear all terminal data
    }
    
    private func exportDebugLogs() {
        // TODO: Export debug logs
    }
}

/// Color scheme preview view
struct ColorSchemePreview: View {
    let scheme: TerminalSettings.ColorScheme
    let testText: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // Preview area
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(previewLines, id: \.self) { line in
                            Text(line.text)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(line.color)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(backgroundColor)
                
                // Color palette
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color Palette")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ForEach(0..<16, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(paletteColor(index))
                                .frame(height: 30)
                                .overlay(
                                    Text("\(index)")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(schemeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var previewLines: [(text: String, color: Color)] {
        // Generate preview lines with different colors
        [
            (text: "# Terminal Color Scheme Preview", color: .green),
            (text: "user@host:~$ ls -la", color: .white),
            (text: "drwxr-xr-x  10 user  staff   320 Jan  1 12:00 .", color: .cyan),
            (text: "drwxr-xr-x   5 user  staff   160 Jan  1 11:00 ..", color: .cyan),
            (text: "-rw-r--r--   1 user  staff  1024 Jan  1 10:00 README.md", color: .white),
            (text: "user@host:~$ git status", color: .white),
            (text: "On branch main", color: .green),
            (text: "Changes not staged for commit:", color: .red),
            (text: "  modified:   src/main.swift", color: .red),
            (text: "user@host:~$ echo \"Hello, World!\"", color: .white),
            (text: "Hello, World!", color: .yellow),
            (text: "user@host:~$ ", color: .white)
        ]
    }
    
    private var backgroundColor: Color {
        switch scheme {
        case .default: return Color.black
        case .solarizedDark: return Color(hex: "002b36")
        case .solarizedLight: return Color(hex: "fdf6e3")
        case .monokai: return Color(hex: "272822")
        case .dracula: return Color(hex: "282a36")
        case .nord: return Color(hex: "2e3440")
        case .gruvbox: return Color(hex: "282828")
        case .oneDark: return Color(hex: "282c34")
        }
    }
    
    private var schemeName: String {
        switch scheme {
        case .default: return "Default"
        case .solarizedDark: return "Solarized Dark"
        case .solarizedLight: return "Solarized Light"
        case .monokai: return "Monokai"
        case .dracula: return "Dracula"
        case .nord: return "Nord"
        case .gruvbox: return "Gruvbox"
        case .oneDark: return "One Dark"
        }
    }
    
    private func paletteColor(_ index: Int) -> Color {
        // Return color based on scheme and index
        // Simplified for preview
        switch index {
        case 0: return .black
        case 1: return .red
        case 2: return .green
        case 3: return .yellow
        case 4: return .blue
        case 5: return .purple
        case 6: return .cyan
        case 7: return .white
        default: return .gray
        }
    }
}

// MARK: - Supporting Views

struct RecentConnectionsList: View {
    let connections: [SSHConfig]
    let onSelect: (SSHConfig) -> Void
    
    var body: some View {
        List(connections) { config in
            ConnectionRow(config: config) {
                onSelect(config)
            }
        }
    }
}

struct SavedConnectionsList: View {
    let onSelect: (SSHConfig) -> Void
    @State private var savedConnections: [SSHConfig] = []
    
    var body: some View {
        List(savedConnections) { config in
            ConnectionRow(config: config) {
                onSelect(config)
            }
        }
        .onAppear {
            loadSavedConnections()
        }
    }
    
    private func loadSavedConnections() {
        // TODO: Load saved connections from storage
    }
}

struct ConnectionRow: View {
    let config: SSHConfig
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.name)
                        .font(.headline)
                    Text("\(config.username)@\(config.host):\(config.port)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NewConnectionForm: View {
    let onCreate: (SSHConfig) -> Void
    
    @State private var name = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var authMethod = SSHAuthMethod.password
    @State private var password = ""
    @State private var privateKeyPath = ""
    @State private var passphrase = ""
    
    var body: some View {
        Form {
            Section("Connection Details") {
                TextField("Session Name", text: $name)
                TextField("Host", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            Section("Authentication") {
                Picker("Method", selection: $authMethod) {
                    Text("Password").tag(SSHAuthMethod.password)
                    Text("Public Key").tag(SSHAuthMethod.publicKey)
                    Text("Keyboard Interactive").tag(SSHAuthMethod.keyboardInteractive)
                }
                
                switch authMethod {
                case .password:
                    SecureField("Password", text: $password)
                    
                case .publicKey:
                    TextField("Private Key Path", text: $privateKeyPath)
                    SecureField("Passphrase", text: $passphrase)
                    
                case .keyboardInteractive:
                    Text("Authentication will be requested during connection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                default:
                    EmptyView()
                }
            }
            
            Section {
                Button("Create Session") {
                    let config = SSHConfig(
                        name: name.isEmpty ? host : name,
                        host: host,
                        port: Int(port) ?? 22,
                        username: username,
                        authMethod: authMethod,
                        privateKeyPath: privateKeyPath.isEmpty ? nil : privateKeyPath,
                        password: password.isEmpty ? nil : password,
                        passphrase: passphrase.isEmpty ? nil : passphrase
                    )
                    onCreate(config)
                }
                .disabled(host.isEmpty || username.isEmpty)
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    TerminalSettingsView(settings: TerminalSettings())
        .preferredColorScheme(.dark)
}