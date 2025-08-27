//
//  CodeEditorView.swift
//  ClaudeCode
//
//  Main SwiftUI code editor view with syntax highlighting
//

import SwiftUI
import UIKit

/// Main code editor view with syntax highlighting and advanced features
struct CodeEditorView: View {
    // MARK: - Properties
    
    @Binding var text: String
    @Binding var language: ProgrammingLanguage
    @State private var editorCore: CodeEditorCore
    @State private var configuration: EditorConfiguration
    @State private var showLineNumbers: Bool = true
    @State private var showMinimap: Bool = false
    @State private var currentLineNumber: Int = 1
    @State private var searchText: String = ""
    @State private var showFindReplace: Bool = false
    @State private var showSettings: Bool = false
    @State private var fontSize: CGFloat = 14
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    
    init(text: Binding<String>, language: Binding<ProgrammingLanguage>, fileName: String? = nil) {
        self._text = text
        self._language = language
        
        let config = EditorConfiguration.default
        self._configuration = State(initialValue: config)
        self._editorCore = State(initialValue: CodeEditorCore(text: text.wrappedValue, configuration: config))
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Editor toolbar
                CodeEditorToolbar(
                    language: $language,
                    showLineNumbers: $showLineNumbers,
                    showMinimap: $showMinimap,
                    showFindReplace: $showFindReplace,
                    showSettings: $showSettings,
                    fontSize: $fontSize,
                    onUndo: { editorCore.undoManager.undo() },
                    onRedo: { editorCore.undoManager.redo() },
                    onSave: saveFile
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Theme.card)
                
                // Find & Replace bar
                if showFindReplace {
                    FindReplaceBar(
                        searchText: $searchText,
                        onFind: { direction in
                            findText(searchText, direction: direction)
                        },
                        onReplace: { replacement in
                            replaceText(searchText, with: replacement)
                        },
                        onReplaceAll: { replacement in
                            replaceAllText(searchText, with: replacement)
                        },
                        onClose: {
                            showFindReplace = false
                        }
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Theme.card)
                }
                
                // Main editor area
                HStack(spacing: 0) {
                    // Line numbers
                    if showLineNumbers {
                        LineNumbersView(
                            lineNumbers: editorCore.lineNumbers,
                            currentLine: currentLineNumber,
                            fontSize: fontSize
                        )
                        .frame(width: 50)
                        .background(Theme.card.opacity(0.5))
                    }
                    
                    // Code editor
                    CodeTextView(
                        text: $text,
                        language: $language,
                        editorCore: editorCore,
                        configuration: configuration,
                        fontSize: fontSize
                    )
                    .background(Theme.background)
                    
                    // Minimap
                    if showMinimap {
                        CodeMinimapView(
                            text: text,
                            language: language,
                            visibleRange: NSRange(location: 0, length: text.count)
                        )
                        .frame(width: 100)
                        .background(Theme.card.opacity(0.3))
                    }
                }
                
                // Status bar
                CodeEditorStatusBar(
                    lineNumber: currentLineNumber,
                    columnNumber: 1,
                    language: language,
                    totalLines: editorCore.lineNumbers.count,
                    selection: editorCore.cursorPosition
                )
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Theme.card)
            }
        }
        .onChange(of: text) { newValue in
            editorCore.text = newValue
        }
        .onChange(of: language) { newLanguage in
            editorCore.language = newLanguage
        }
        .sheet(isPresented: $showSettings) {
            CodeEditorSettingsView(configuration: $configuration)
        }
    }
    
    // MARK: - Methods
    
    private func saveFile() {
        // TODO: Implement file saving
        print("Save file")
    }
    
    private func findText(_ text: String, direction: FindDirection) {
        // TODO: Implement text finding
        print("Find: \(text), direction: \(direction)")
    }
    
    private func replaceText(_ text: String, with replacement: String) {
        // TODO: Implement text replacement
        print("Replace: \(text) with: \(replacement)")
    }
    
    private func replaceAllText(_ text: String, with replacement: String) {
        // TODO: Implement replace all
        print("Replace all: \(text) with: \(replacement)")
    }
}

// MARK: - CodeTextView

/// UIViewRepresentable for the actual text editing view
struct CodeTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var language: ProgrammingLanguage
    let editorCore: CodeEditorCore
    let configuration: EditorConfiguration
    let fontSize: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = UIColor(Theme.foreground)
        textView.backgroundColor = UIColor(Theme.background)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.keyboardType = .asciiCapable
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.text = text
        
        // Configure text container
        textView.textContainer.lineFragmentPadding = 0
        
        // Add custom input accessory view for code completion
        textView.inputAccessoryView = createInputAccessoryView()
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
            highlightSyntax(in: textView)
        }
        
        textView.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
    
    private func highlightSyntax(in textView: UITextView) {
        let highlighter = SyntaxHighlighter()
        let highlights = highlighter.highlight(text: text, language: language)
        
        let attributedString = NSMutableAttributedString(string: text)
        
        // Apply base attributes
        let fullRange = NSRange(location: 0, length: text.count)
        attributedString.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular), range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor(Theme.foreground), range: fullRange)
        
        // Apply syntax highlights
        for highlight in highlights {
            if let color = configuration.theme.color(for: highlight.type) {
                attributedString.addAttribute(.foregroundColor, value: color, range: highlight.range)
            }
        }
        
        textView.attributedText = attributedString
    }
    
    private func createInputAccessoryView() -> UIView {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.barStyle = .default
        
        let tabButton = UIBarButtonItem(title: "Tab", style: .plain, target: nil, action: nil)
        let bracketButton = UIBarButtonItem(title: "{ }", style: .plain, target: nil, action: nil)
        let parenButton = UIBarButtonItem(title: "( )", style: .plain, target: nil, action: nil)
        let quoteButton = UIBarButtonItem(title: "\" \"", style: .plain, target: nil, action: nil)
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: nil)
        
        toolbar.setItems([tabButton, bracketButton, parenButton, quoteButton, flexSpace, doneButton], animated: false)
        
        return toolbar
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeTextView
        
        init(_ parent: CodeTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.highlightSyntax(in: textView)
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Handle auto-indentation
            if text == "\n" && parent.configuration.autoIndent {
                let currentLine = getCurrentLine(in: textView.text, at: range.location)
                let indentation = getIndentation(from: currentLine)
                let newText = "\n" + indentation
                textView.insertText(newText)
                return false
            }
            
            // Handle auto-closing brackets
            if parent.configuration.autoCloseBrackets {
                let brackets: [String: String] = [
                    "{": "}",
                    "[": "]",
                    "(": ")",
                    "\"": "\"",
                    "'": "'"
                ]
                
                if let closingBracket = brackets[text] {
                    textView.insertText(text + closingBracket)
                    let newPosition = textView.position(from: textView.selectedTextRange!.start, offset: -1)!
                    textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
                    return false
                }
            }
            
            return true
        }
        
        private func getCurrentLine(in text: String, at position: Int) -> String {
            guard position <= text.count else { return "" }
            
            let beforeIndex = text.index(text.startIndex, offsetBy: position)
            let beforeText = String(text[..<beforeIndex])
            let lines = beforeText.components(separatedBy: .newlines)
            return lines.last ?? ""
        }
        
        private func getIndentation(from line: String) -> String {
            var indentation = ""
            for char in line {
                if char == " " || char == "\t" {
                    indentation.append(char)
                } else {
                    break
                }
            }
            return indentation
        }
    }
}

// MARK: - Supporting Types

enum FindDirection {
    case next
    case previous
}

/// Editor theme definition
struct EditorTheme {
    let name: String
    let textColor: UIColor
    let backgroundColor: UIColor
    let lineNumberColor: UIColor
    let currentLineColor: UIColor
    let selectionColor: UIColor
    let keywordColor: UIColor
    let typeColor: UIColor
    let stringColor: UIColor
    let numberColor: UIColor
    let commentColor: UIColor
    let functionColor: UIColor
    let operatorColor: UIColor
    
    func color(for tokenType: TokenType) -> UIColor? {
        switch tokenType {
        case .keyword: return keywordColor
        case .type: return typeColor
        case .string: return stringColor
        case .number: return numberColor
        case .comment: return commentColor
        case .function: return functionColor
        case .operator: return operatorColor
        default: return textColor
        }
    }
    
    static let `default` = EditorTheme(
        name: "Default",
        textColor: UIColor(Theme.foreground),
        backgroundColor: UIColor(Theme.background),
        lineNumberColor: UIColor(Theme.muted),
        currentLineColor: UIColor(Theme.accent.opacity(0.1)),
        selectionColor: UIColor(Theme.accent.opacity(0.3)),
        keywordColor: UIColor(red: 0.68, green: 0.18, blue: 0.89, alpha: 1.0), // Purple
        typeColor: UIColor(red: 0.0, green: 0.68, blue: 0.94, alpha: 1.0), // Blue
        stringColor: UIColor(red: 0.77, green: 0.10, blue: 0.09, alpha: 1.0), // Red
        numberColor: UIColor(red: 0.13, green: 0.43, blue: 0.85, alpha: 1.0), // Blue
        commentColor: UIColor(red: 0.42, green: 0.47, blue: 0.53, alpha: 1.0), // Gray
        functionColor: UIColor(red: 0.0, green: 0.46, blue: 0.46, alpha: 1.0), // Teal
        operatorColor: UIColor(Theme.muted)
    )
    
    static let dark = EditorTheme(
        name: "Dark",
        textColor: UIColor(white: 0.9, alpha: 1.0),
        backgroundColor: UIColor(white: 0.1, alpha: 1.0),
        lineNumberColor: UIColor(white: 0.4, alpha: 1.0),
        currentLineColor: UIColor(white: 0.2, alpha: 0.5),
        selectionColor: UIColor(white: 0.3, alpha: 0.5),
        keywordColor: UIColor(red: 0.78, green: 0.38, blue: 0.99, alpha: 1.0),
        typeColor: UIColor(red: 0.2, green: 0.78, blue: 1.0, alpha: 1.0),
        stringColor: UIColor(red: 0.87, green: 0.30, blue: 0.29, alpha: 1.0),
        numberColor: UIColor(red: 0.33, green: 0.63, blue: 0.95, alpha: 1.0),
        commentColor: UIColor(white: 0.5, alpha: 1.0),
        functionColor: UIColor(red: 0.2, green: 0.66, blue: 0.66, alpha: 1.0),
        operatorColor: UIColor(white: 0.7, alpha: 1.0)
    )
}