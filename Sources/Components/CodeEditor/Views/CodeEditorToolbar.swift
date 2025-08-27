//
//  CodeEditorToolbar.swift
//  ClaudeCode
//
//  Editor toolbar with actions and controls
//

import SwiftUI

/// Code editor toolbar with common actions
struct CodeEditorToolbar: View {
    @Binding var language: ProgrammingLanguage
    @Binding var showLineNumbers: Bool
    @Binding var showMinimap: Bool
    @Binding var showFindReplace: Bool
    @Binding var showSettings: Bool
    @Binding var fontSize: CGFloat
    
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Language selector
            Menu {
                ForEach(ProgrammingLanguage.allCases) { lang in
                    Button(action: { language = lang }) {
                        HStack {
                            Text(lang.displayName)
                            if language == lang {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12))
                    Text(language.displayName)
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(Theme.foreground)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.card)
                .cornerRadius(6)
            }
            
            Divider()
                .frame(height: 20)
            
            // Undo/Redo
            HStack(spacing: 8) {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
                
                Button(action: onRedo) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .frame(height: 20)
            
            // View options
            HStack(spacing: 8) {
                Button(action: { showLineNumbers.toggle() }) {
                    Image(systemName: "number")
                        .font(.system(size: 14))
                        .foregroundColor(showLineNumbers ? Theme.accent : Theme.muted)
                }
                .buttonStyle(.plain)
                
                Button(action: { showMinimap.toggle() }) {
                    Image(systemName: "map")
                        .font(.system(size: 14))
                        .foregroundColor(showMinimap ? Theme.accent : Theme.muted)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .frame(height: 20)
            
            // Font size
            HStack(spacing: 4) {
                Button(action: { 
                    if fontSize > 10 { 
                        fontSize -= 1 
                    }
                }) {
                    Image(systemName: "textformat.size.smaller")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
                
                Text("\(Int(fontSize))pt")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.muted)
                    .frame(minWidth: 30)
                
                Button(action: { 
                    if fontSize < 24 { 
                        fontSize += 1 
                    }
                }) {
                    Image(systemName: "textformat.size.larger")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button(action: { showFindReplace.toggle() }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(showFindReplace ? Theme.accent : Theme.muted)
                }
                .buttonStyle(.plain)
                
                Button(action: onSave) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
                
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 32)
    }
}

/// Find and replace bar
struct FindReplaceBar: View {
    @Binding var searchText: String
    @State private var replaceText: String = ""
    @State private var caseSensitive: Bool = false
    @State private var useRegex: Bool = false
    @State private var matchWholeWord: Bool = false
    
    let onFind: (FindDirection) -> Void
    let onReplace: (String) -> Void
    let onReplaceAll: (String) -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Find row
            HStack(spacing: 8) {
                Text("Find:")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)
                    .frame(width: 60, alignment: .trailing)
                
                TextField("Search text", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.background)
                    .cornerRadius(4)
                
                // Search options
                HStack(spacing: 4) {
                    Toggle("", isOn: $caseSensitive)
                        .toggleStyle(OptionToggleStyle(
                            label: "Aa",
                            tooltip: "Case sensitive"
                        ))
                    
                    Toggle("", isOn: $matchWholeWord)
                        .toggleStyle(OptionToggleStyle(
                            label: "W",
                            tooltip: "Match whole word"
                        ))
                    
                    Toggle("", isOn: $useRegex)
                        .toggleStyle(OptionToggleStyle(
                            label: ".*",
                            tooltip: "Use regular expression"
                        ))
                }
                
                // Navigation buttons
                HStack(spacing: 4) {
                    Button(action: { onFind(.previous) }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { onFind(.next) }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
            }
            
            // Replace row
            HStack(spacing: 8) {
                Text("Replace:")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)
                    .frame(width: 60, alignment: .trailing)
                
                TextField("Replace with", text: $replaceText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.background)
                    .cornerRadius(4)
                
                Button("Replace") {
                    onReplace(replaceText)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Theme.accent.opacity(0.2))
                .foregroundColor(Theme.accent)
                .cornerRadius(4)
                
                Button("Replace All") {
                    onReplaceAll(replaceText)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Theme.accent.opacity(0.2))
                .foregroundColor(Theme.accent)
                .cornerRadius(4)
            }
        }
    }
}

/// Custom toggle style for options
struct OptionToggleStyle: ToggleStyle {
    let label: String
    let tooltip: String
    
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(configuration.isOn ? Theme.accent : Theme.muted)
                .frame(width: 24, height: 24)
                .background(configuration.isOn ? Theme.accent.opacity(0.2) : Theme.card)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

/// Line numbers view
struct LineNumbersView: View {
    let lineNumbers: [Int]
    let currentLine: Int
    let fontSize: CGFloat
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(lineNumbers, id: \.self) { lineNumber in
                    Text("\(lineNumber)")
                        .font(.system(size: fontSize * 0.9, design: .monospaced))
                        .foregroundColor(lineNumber == currentLine ? Theme.accent : Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 8)
                        .padding(.vertical, 2)
                        .background(
                            lineNumber == currentLine ?
                            Theme.accent.opacity(0.1) : Color.clear
                        )
                }
            }
            .padding(.top, 16)
        }
    }
}

/// Code minimap view
struct CodeMinimapView: View {
    let text: String
    let language: ProgrammingLanguage
    let visibleRange: NSRange
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            // Simplified minimap representation
            Text(text)
                .font(.system(size: 2, design: .monospaced))
                .foregroundColor(Theme.muted.opacity(0.5))
                .blur(radius: 0.5)
                .scaleEffect(x: 0.1, y: 0.1, anchor: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            // Visible area indicator
            RoundedRectangle(cornerRadius: 2)
                .stroke(Theme.accent, lineWidth: 1)
                .frame(height: 50)
                .opacity(0.3)
                .offset(y: CGFloat(visibleRange.location) / CGFloat(max(1, text.count)) * 300)
        )
    }
}

/// Status bar at bottom of editor
struct CodeEditorStatusBar: View {
    let lineNumber: Int
    let columnNumber: Int
    let language: ProgrammingLanguage
    let totalLines: Int
    let selection: NSRange
    
    var body: some View {
        HStack(spacing: 16) {
            // Line and column
            HStack(spacing: 4) {
                Text("Ln")
                    .foregroundColor(Theme.muted)
                Text("\(lineNumber)")
                    .foregroundColor(Theme.foreground)
                Text(",")
                    .foregroundColor(Theme.muted)
                Text("Col")
                    .foregroundColor(Theme.muted)
                Text("\(columnNumber)")
                    .foregroundColor(Theme.foreground)
            }
            .font(.system(size: 11))
            
            Divider()
                .frame(height: 12)
            
            // Selection info
            if selection.length > 0 {
                HStack(spacing: 4) {
                    Text("Selected:")
                        .foregroundColor(Theme.muted)
                    Text("\(selection.length) chars")
                        .foregroundColor(Theme.foreground)
                }
                .font(.system(size: 11))
                
                Divider()
                    .frame(height: 12)
            }
            
            // Total lines
            HStack(spacing: 4) {
                Text("Lines:")
                    .foregroundColor(Theme.muted)
                Text("\(totalLines)")
                    .foregroundColor(Theme.foreground)
            }
            .font(.system(size: 11))
            
            Spacer()
            
            // Language
            Text(language.displayName)
                .font(.system(size: 11))
                .foregroundColor(Theme.muted)
            
            // Encoding
            Text("UTF-8")
                .font(.system(size: 11))
                .foregroundColor(Theme.muted)
            
            // Line ending
            Text("LF")
                .font(.system(size: 11))
                .foregroundColor(Theme.muted)
        }
    }
}