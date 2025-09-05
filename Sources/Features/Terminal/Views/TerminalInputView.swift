//
//  TerminalInputView.swift
//  ClaudeCode
//
//  Terminal command input handling (Tasks 611-615)
//

import SwiftUI
import Combine

/// Terminal input view with command history and auto-completion
public struct TerminalInputView: View {
    let onCommand: (String) -> Void
    let history: CommandHistory
    
    @State private var commandText = ""
    @State private var historyIndex = -1
    @State private var savedCommand = ""
    @State private var showAutoComplete = false
    @State private var autoCompleteOptions: [String] = []
    @State private var selectedAutoCompleteIndex = 0
    @FocusState private var isInputFocused: Bool
    
    @AppStorage("terminal_enable_autocomplete") private var enableAutoComplete = true
    @AppStorage("terminal_history_size") private var historySize = 1000
    
    private let autoCompleteProvider = TerminalAutoCompleteProvider()
    
    public var body: some View {
        VStack(spacing: 0) {
            // Auto-complete suggestions
            if showAutoComplete && !autoCompleteOptions.isEmpty {
                AutoCompleteSuggestions(
                    options: autoCompleteOptions,
                    selectedIndex: $selectedAutoCompleteIndex,
                    onSelect: { option in
                        applyAutoComplete(option)
                    }
                )
            }
            
            // Input field
            HStack(spacing: 8) {
                // Prompt
                Text("$")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Theme.primary)
                
                // Command input
                TextField("Enter command", text: $commandText)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isInputFocused)
                    .onSubmit {
                        executeCommand()
                    }
                    .onChange(of: commandText) { newValue in
                        updateAutoComplete(for: newValue)
                    }
                    // MVP: Comment out onKeyPress as KeyPress type not available
                    /*
                    .onKeyPress { key in
                        handleKeyPress(key)
                    }
                    */
                
                // Action buttons
                HStack(spacing: 4) {
                    // History navigation
                    Button(action: navigateHistoryUp) {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(history.isEmpty)
                    
                    Button(action: navigateHistoryDown) {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(history.isEmpty)
                    
                    // Clear
                    Button(action: clearInput) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(commandText.isEmpty ? 0.3 : 1)
                    .disabled(commandText.isEmpty)
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Theme.card)
        }
        .onAppear {
            isInputFocused = true
        }
    }
    
    // MARK: - Command Execution
    
    private func executeCommand() {
        guard !commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add to history
        history.add(commandText)
        
        // Send command
        onCommand(commandText)
        
        // Clear input
        commandText = ""
        historyIndex = -1
        savedCommand = ""
        showAutoComplete = false
    }
    
    // MARK: - History Navigation
    
    private func navigateHistoryUp() {
        guard !history.isEmpty else { return }
        
        if historyIndex == -1 {
            // Save current command
            savedCommand = commandText
            historyIndex = history.count - 1
        } else if historyIndex > 0 {
            historyIndex -= 1
        }
        
        commandText = history[historyIndex] ?? ""
    }
    
    private func navigateHistoryDown() {
        guard historyIndex >= 0 else { return }
        
        if historyIndex < history.count - 1 {
            historyIndex += 1
            commandText = history[historyIndex] ?? ""
        } else {
            // Restore saved command
            historyIndex = -1
            commandText = savedCommand
            savedCommand = ""
        }
    }
    
    // MARK: - Auto-Complete
    
    private func updateAutoComplete(for text: String) {
        guard enableAutoComplete else {
            showAutoComplete = false
            return
        }
        
        guard !text.isEmpty else {
            showAutoComplete = false
            return
        }
        
        // Get auto-complete suggestions
        let suggestions = autoCompleteProvider.getSuggestions(for: text, history: history)
        
        if suggestions.isEmpty {
            showAutoComplete = false
        } else {
            autoCompleteOptions = suggestions
            selectedAutoCompleteIndex = 0
            showAutoComplete = true
        }
    }
    
    private func applyAutoComplete(_ option: String) {
        commandText = option
        showAutoComplete = false
        isInputFocused = true
    }
    
    // MARK: - Key Handling
    
    // MVP: Comment out handleKeyPress as KeyPress type doesn't exist
    /*
    private func handleKeyPress(_ key: KeyEquivalent) -> KeyPress.Result {
        if showAutoComplete {
            switch key {
            case .upArrow:
                if selectedAutoCompleteIndex > 0 {
                    selectedAutoCompleteIndex -= 1
                }
                return .handled
                
            case .downArrow:
                if selectedAutoCompleteIndex < autoCompleteOptions.count - 1 {
                    selectedAutoCompleteIndex += 1
                }
                return .handled
                
            case .tab:
                if !autoCompleteOptions.isEmpty {
                    applyAutoComplete(autoCompleteOptions[selectedAutoCompleteIndex])
                }
                return .handled
                
            case .escape:
                showAutoComplete = false
                return .handled
                
            default:
                break
            }
        } else {
            switch key {
            case .upArrow:
                navigateHistoryUp()
                return .handled
                
            case .downArrow:
                navigateHistoryDown()
                return .handled
                
            case .tab:
                updateAutoComplete(for: commandText)
                return .handled
                
            default:
                break
            }
        }
        
        return .ignored
    }
    */
    
    private func clearInput() {
        commandText = ""
        historyIndex = -1
        savedCommand = ""
        showAutoComplete = false
    }
}

/// Auto-complete suggestions view
struct AutoCompleteSuggestions: View {
    let options: [String]
    @Binding var selectedIndex: Int
    let onSelect: (String) -> Void
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    AutoCompleteSuggestionRow(
                        option: option,
                        isSelected: index == selectedIndex,
                        onTap: {
                            onSelect(option)
                        }
                    )
                }
            }
        }
        .frame(maxHeight: 150)
        .background(Theme.card)
        .cornerRadius(8)
        .shadow(radius: 4)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}

/// Auto-complete suggestion row
struct AutoCompleteSuggestionRow: View {
    let option: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            // Icon based on suggestion type
            Image(systemName: suggestionIcon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            // Suggestion text
            Text(option)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Theme.primary.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var suggestionIcon: String {
        if option.hasPrefix("cd ") {
            return "folder"
        } else if option.hasPrefix("git ") {
            return "square.stack.3d.up"
        } else if option.hasPrefix("ssh ") {
            return "network"
        } else if option.hasPrefix("docker ") {
            return "shippingbox"
        } else if option.contains("|") || option.contains(">") {
            return "arrow.right.circle"
        } else {
            return "terminal"
        }
    }
}


/// Terminal auto-complete provider
class TerminalAutoCompleteProvider {
    private let commonCommands = [
        "ls", "cd", "pwd", "mkdir", "rm", "cp", "mv", "cat", "echo", "grep",
        "find", "chmod", "chown", "ps", "kill", "top", "df", "du", "tar", "zip",
        "git", "docker", "kubectl", "npm", "yarn", "python", "node", "ruby",
        "ssh", "scp", "rsync", "wget", "curl", "ping", "traceroute", "netstat",
        "vim", "nano", "less", "head", "tail", "sort", "uniq", "wc", "sed", "awk"
    ]
    
    private let gitSubcommands = [
        "status", "add", "commit", "push", "pull", "fetch", "merge", "rebase",
        "checkout", "branch", "log", "diff", "stash", "reset", "revert", "cherry-pick",
        "tag", "remote", "clone", "init"
    ]
    
    private let dockerSubcommands = [
        "run", "ps", "images", "pull", "push", "build", "exec", "stop", "start",
        "restart", "rm", "rmi", "logs", "inspect", "network", "volume", "compose"
    ]
    
    func getSuggestions(for text: String, history: CommandHistory) -> [String] {
        var suggestions: [String] = []
        
        // Add history matches first
        let historyMatches = history.search(text).prefix(5)
        suggestions.append(contentsOf: historyMatches)
        
        // Add command suggestions
        let parts = text.split(separator: " ")
        
        if parts.count == 1 {
            // Complete command name
            let prefix = String(parts[0]).lowercased()
            let commandMatches = commonCommands.filter { $0.hasPrefix(prefix) }
            suggestions.append(contentsOf: commandMatches.prefix(5))
        } else if parts.count == 2 {
            // Complete subcommand
            let command = String(parts[0]).lowercased()
            let prefix = String(parts[1]).lowercased()
            
            switch command {
            case "git":
                let subcommandMatches = gitSubcommands.filter { $0.hasPrefix(prefix) }
                suggestions.append(contentsOf: subcommandMatches.map { "git \($0)" }.prefix(5))
                
            case "docker":
                let subcommandMatches = dockerSubcommands.filter { $0.hasPrefix(prefix) }
                suggestions.append(contentsOf: subcommandMatches.map { "docker \($0)" }.prefix(5))
                
            default:
                break
            }
        }
        
        // Remove duplicates while preserving order
        var seen = Set<String>()
        return suggestions.filter { seen.insert($0).inserted }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        
        TerminalInputView(
            onCommand: { command in
                print("Command: \(command)")
            },
            history: CommandHistory()
        )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}