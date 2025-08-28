//
//  CodeEditorView+Voice.swift
//  ClaudeCode
//
//  Voice input extension for code editor
//

import SwiftUI
import Speech
import AVFoundation

// TODO: Implement proper VoiceInputService
class VoiceInputService: NSObject, ObservableObject, @unchecked Sendable {
    nonisolated(unsafe) static let shared = VoiceInputService()
    
    @Published var isRecording = false
    @Published var transcriptionResult = ""
    @Published var error: Error?
    
    func startRecording() {
        isRecording = true
    }
    
    func stopRecording() {
        isRecording = false
    }
}

extension CodeEditorView {
    /// Voice input toolbar for code editor
    struct VoiceInputToolbar: View {
        @Binding var isVoiceInputActive: Bool
        @Binding var text: String
        let insertPosition: Int
        
        @State private var showVoiceInput = false
        @State private var voiceMode: CodeVoiceMode = .dictation
        
        var body: some View {
            HStack(spacing: ThemeSpacing.md) {
                // Voice mode selector
                Menu {
                    Button(action: { voiceMode = .dictation }) {
                        Label("Dictation", systemImage: "text.cursor")
                            .symbolRenderingMode(.hierarchical)
                    }
                    
                    Button(action: { voiceMode = .commands }) {
                        Label("Commands", systemImage: "command")
                            .symbolRenderingMode(.hierarchical)
                    }
                    
                    Button(action: { voiceMode = .codeCompletion }) {
                        Label("Code Completion", systemImage: "chevron.left.forwardslash.chevron.right")
                            .symbolRenderingMode(.hierarchical)
                    }
                } label: {
                    HStack {
                        Image(systemName: iconForMode(voiceMode))
                            .font(.system(size: 16))
                        Text(voiceMode.displayName)
                            .font(Theme.Typography.caption)
                    }
                    .padding(.horizontal, ThemeSpacing.sm)
                    .padding(.vertical, ThemeSpacing.xs)
                    .background(Theme.primary.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.sm)
                }
                
                // Voice input button
                Button(action: startVoiceInput) {
                    HStack {
                        Image(systemName: isVoiceInputActive ? "mic.fill" : "mic")
                            .font(.system(size: 16))
                            .foregroundColor(isVoiceInputActive ? .red : Theme.primary)
                        
                        if isVoiceInputActive {
                            Text("Listening...")
                                .font(Theme.Typography.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("Start Voice")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.primary)
                        }
                    }
                    .padding(.horizontal, ThemeSpacing.sm)
                    .padding(.vertical, ThemeSpacing.xs)
                    .background(isVoiceInputActive ? Color.red.opacity(0.1) : Theme.primary.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .stroke(isVoiceInputActive ? Color.red : Theme.primary, lineWidth: 1)
                    )
                }
                
                Spacer()
                
                // Voice shortcuts info
                Button(action: showVoiceShortcuts) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.mutedForeground)
                }
            }
            .sheet(isPresented: $showVoiceInput) {
                CodeVoiceInputView(
                    mode: voiceMode,
                    text: $text,
                    insertPosition: insertPosition,
                    isPresented: $showVoiceInput,
                    isActive: $isVoiceInputActive
                )
            }
        }
        
        private func iconForMode(_ mode: CodeVoiceMode) -> String {
            switch mode {
            case .dictation:
                return "text.cursor"
            case .commands:
                return "command"
            case .codeCompletion:
                return "chevron.left.forwardslash.chevron.right"
            }
        }
        
        private func startVoiceInput() {
            showVoiceInput = true
            isVoiceInputActive = true
        }
        
        private func showVoiceShortcuts() {
            // Show voice shortcuts help
        }
    }
}

// MARK: - Code Voice Mode

enum CodeVoiceMode {
    case dictation
    case commands
    case codeCompletion
    
    var displayName: String {
        switch self {
        case .dictation:
            return "Dictation"
        case .commands:
            return "Commands"
        case .codeCompletion:
            return "Code"
        }
    }
}

// MARK: - Code Voice Input View

struct CodeVoiceInputView: View {
    let mode: CodeVoiceMode
    @Binding var text: String
    let insertPosition: Int
    @Binding var isPresented: Bool
    @Binding var isActive: Bool
    
    @StateObject private var voiceService = VoiceInputService.shared
    @StateObject private var codeProcessor = CodeVoiceProcessor()
    @State private var transcribedCode = ""
    @State private var formattedCode = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Voice visualization
            VoiceWaveformView(
                audioLevel: voiceService.audioLevel,
                isRecording: voiceService.isRecording
            )
            .frame(height: 100)
            .padding()
            .background(Theme.card)
            
            // Mode-specific content
            ScrollView {
                VStack(spacing: ThemeSpacing.lg) {
                    switch mode {
                    case .dictation:
                        dictationView
                    case .commands:
                        commandsView
                    case .codeCompletion:
                        codeCompletionView
                    }
                }
                .padding()
            }
            
            // Controls
            controlsView
        }
        .background(Theme.background)
        .onAppear {
            setupVoiceService()
            startListening()
        }
        .onDisappear {
            stopListening()
            isActive = false
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.mutedForeground)
            }
            
            Spacer()
            
            Text("Voice Input - \(mode.displayName)")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.foreground)
            
            Spacer()
            
            Button(action: showHelp) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.mutedForeground)
            }
        }
        .padding()
        .background(Theme.card)
    }
    
    private var dictationView: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.md) {
            Text("Code Dictation")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.foreground)
            
            Text("Speak your code naturally. Say 'new line' for line breaks, 'tab' for indentation.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.mutedForeground)
            
            // Transcribed code
            ScrollView {
                Text(formattedCode.isEmpty ? "Start speaking..." : formattedCode)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 200)
            .background(Theme.card)
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
    
    private var commandsView: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.md) {
            Text("Voice Commands")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.foreground)
            
            // Available commands
            ScrollView {
                VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                    CommandRow(command: "Go to line", example: "Go to line 42")
                    CommandRow(command: "Select", example: "Select line 10 to 20")
                    CommandRow(command: "Find", example: "Find function main")
                    CommandRow(command: "Replace", example: "Replace foo with bar")
                    CommandRow(command: "Comment", example: "Comment line")
                    CommandRow(command: "Uncomment", example: "Uncomment selection")
                    CommandRow(command: "Format", example: "Format code")
                    CommandRow(command: "Indent", example: "Indent selection")
                    CommandRow(command: "Save", example: "Save file")
                }
            }
            .frame(height: 200)
            .padding()
            .background(Theme.card)
            .cornerRadius(Theme.CornerRadius.md)
            
            // Last command
            if !transcribedCode.isEmpty {
                HStack {
                    Image(systemName: "chevron.right.circle")
                        .foregroundColor(Theme.primary)
                    Text(transcribedCode)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.foreground)
                }
                .padding()
                .background(Theme.primary.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.sm)
            }
        }
    }
    
    private var codeCompletionView: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.md) {
            Text("Code Completion")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.foreground)
            
            Text("Describe what you want to code, and it will be generated for you.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.mutedForeground)
            
            // Description input
            ScrollView {
                Text(transcribedCode.isEmpty ? "Describe your code..." : transcribedCode)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 100)
            .background(Theme.card)
            .cornerRadius(Theme.CornerRadius.md)
            
            // Generated code preview
            if !formattedCode.isEmpty {
                Text("Generated Code:")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.mutedForeground)
                
                ScrollView {
                    Text(formattedCode)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Theme.foreground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 150)
                .background(Theme.card)
                .cornerRadius(Theme.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(Theme.primary.opacity(0.5), lineWidth: 1)
                )
            }
        }
    }
    
    private var controlsView: some View {
        HStack(spacing: ThemeSpacing.md) {
            // Clear button
            Button(action: clear) {
                Label("Clear", systemImage: "trash")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            Spacer()
            
            // Cancel button
            Button(action: cancel) {
                Text("Cancel")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            // Insert button
            Button(action: insertCode) {
                Text("Insert")
                    .font(Theme.Typography.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, ThemeSpacing.lg)
                    .padding(.vertical, ThemeSpacing.sm)
                    .background(Theme.primary)
                    .cornerRadius(Theme.CornerRadius.md)
            }
            .disabled(formattedCode.isEmpty && transcribedCode.isEmpty)
        }
        .padding()
        .background(Theme.card)
    }
    
    private func setupVoiceService() {
        voiceService.onTranscriptionUpdate = { text in
            handleTranscription(text, isFinal: false)
        }
        
        voiceService.onFinalTranscription = { text in
            handleTranscription(text, isFinal: true)
        }
    }
    
    private func handleTranscription(_ text: String, isFinal: Bool) {
        switch mode {
        case .dictation:
            let formatted = codeProcessor.processCodeDictation(text)
            transcribedCode = text
            formattedCode = formatted
        case .commands:
            transcribedCode = text
            if isFinal {
                executeCommand(text)
            }
        case .codeCompletion:
            transcribedCode = text
            if isFinal {
                generateCode(from: text)
            }
        }
    }
    
    private func startListening() {
        do {
            var config = VoiceInputConfiguration()
            config.continuousRecognition = (mode == .dictation)
            config.addsPunctuation = false
            voiceService.updateConfiguration(config)
            try voiceService.startRecording()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func stopListening() {
        voiceService.stopRecording()
    }
    
    private func clear() {
        transcribedCode = ""
        formattedCode = ""
    }
    
    private func cancel() {
        isPresented = false
    }
    
    private func insertCode() {
        let codeToInsert = formattedCode.isEmpty ? transcribedCode : formattedCode
        
        // Insert at position
        if insertPosition <= text.count {
            let index = text.index(text.startIndex, offsetBy: insertPosition)
            text.insert(contentsOf: codeToInsert, at: index)
        } else {
            text.append(codeToInsert)
        }
        
        isPresented = false
    }
    
    private func executeCommand(_ command: String) {
        // Execute code editor command
        print("Execute command: \(command)")
    }
    
    private func generateCode(from description: String) {
        // Generate code from description
        // This would integrate with AI code generation
        formattedCode = "// Generated code for: \(description)\n// Implementation pending..."
    }
    
    private func showHelp() {
        // Show voice input help
    }
}

// MARK: - Command Row

struct CommandRow: View {
    let command: String
    let example: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(command)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.foreground)
            Text(example)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.mutedForeground)
        }
    }
}

// MARK: - Code Voice Processor

class CodeVoiceProcessor: ObservableObject {
    func processCodeDictation(_ text: String) -> String {
        var processed = text
        
        // Code-specific replacements
        let replacements = [
            "new line": "\n",
            "newline": "\n",
            "tab": "\t",
            "open brace": "{",
            "close brace": "}",
            "open bracket": "[",
            "close bracket": "]",
            "open paren": "(",
            "close paren": ")",
            "semicolon": ";",
            "colon": ":",
            "comma": ",",
            "dot": ".",
            "arrow": "->",
            "equals": "=",
            "plus": "+",
            "minus": "-",
            "times": "*",
            "divided by": "/",
            "percent": "%",
            "ampersand": "&",
            "pipe": "|",
            "less than": "<",
            "greater than": ">",
            "double quote": "\"",
            "single quote": "'",
            "backslash": "\\",
            "forward slash": "/"
        ]
        
        for (spoken, code) in replacements {
            processed = processed.replacingOccurrences(
                of: " \(spoken) ",
                with: code,
                options: .caseInsensitive
            )
        }
        
        // Handle common programming constructs
        processed = processSwiftConstructs(processed)
        
        return processed
    }
    
    private func processSwiftConstructs(_ text: String) -> String {
        var processed = text
        
        // Swift-specific patterns
        let patterns = [
            ("function (\\w+)", "func $1() {\n\t\n}"),
            ("class (\\w+)", "class $1 {\n\t\n}"),
            ("struct (\\w+)", "struct $1 {\n\t\n}"),
            ("if (.*?) then", "if $1 {\n\t\n}"),
            ("for (\\w+) in (\\w+)", "for $1 in $2 {\n\t\n}"),
            ("let (\\w+) equals (.*)", "let $1 = $2"),
            ("var (\\w+) equals (.*)", "var $1 = $2")
        ]
        
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(processed.startIndex..., in: processed)
                processed = regex.stringByReplacingMatches(
                    in: processed,
                    range: range,
                    withTemplate: replacement
                )
            }
        }
        
        return processed
    }
}