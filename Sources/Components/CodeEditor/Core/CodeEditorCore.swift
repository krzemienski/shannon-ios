//
//  CodeEditorCore.swift
//  ClaudeCode
//
//  Core text editing engine with efficient text management
//

import SwiftUI
#if os(iOS)
import UIKit

/// Core text storage and management for the code editor
final class CodeEditorCore: NSObject, ObservableObject {
    // MARK: - Properties
    
    /// The text storage backing the editor
    private(set) var textStorage: NSTextStorage
    
    /// Layout manager for text rendering
    private let layoutManager: NSLayoutManager
    
    /// Text container for layout bounds
    private let textContainer: NSTextContainer
    
    /// Current text content
    @Published var text: String {
        didSet {
            guard text != oldValue else { return }
            updateTextStorage()
        }
    }
    
    /// Current language for syntax highlighting
    @Published var language: ProgrammingLanguage = .plainText {
        didSet {
            guard language != oldValue else { return }
            applyHighlighting()
        }
    }
    
    /// Editor configuration
    @Published var configuration: EditorConfiguration
    
    /// Line numbers for the current text
    @Published private(set) var lineNumbers: [Int] = []
    
    /// Current cursor position
    @Published var cursorPosition: NSRange = NSRange(location: 0, length: 0)
    
    /// Selection ranges for multiple cursors
    @Published var selections: [NSRange] = []
    
    /// Undo manager
    let undoManager = UndoManager()
    
    /// Syntax highlighter
    private lazy var highlighter = SyntaxHighlighter()
    
    /// Code completion engine
    private lazy var completionEngine = CodeCompletionEngine()
    
    /// Performance optimization: batch updates
    private var pendingUpdates: Set<EditorUpdate> = []
    private var updateTimer: Timer?
    
    // MARK: - Initialization
    
    init(text: String = "", configuration: EditorConfiguration = .default) {
        self.text = text
        self.configuration = configuration
        
        // Initialize text kit components
        self.textStorage = NSTextStorage(string: text)
        self.layoutManager = NSLayoutManager()
        self.textContainer = NSTextContainer()
        
        super.init()
        
        // Configure text kit
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        // Configure text container
        textContainer.widthTracksTextView = true
        textContainer.size = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        // Set up text storage delegate
        textStorage.delegate = self
        
        // Initial setup
        updateLineNumbers()
        applyHighlighting()
    }
    
    // MARK: - Text Management
    
    /// Update text storage with new content
    private func updateTextStorage() {
        let range = NSRange(location: 0, length: textStorage.length)
        textStorage.replaceCharacters(in: range, with: text)
        
        // Update line numbers
        updateLineNumbers()
        
        // Schedule highlighting update
        scheduleUpdate(.highlighting)
    }
    
    /// Apply syntax highlighting to the text
    private func applyHighlighting() {
        guard language != .plainText else {
            // Clear all attributes for plain text
            let range = NSRange(location: 0, length: textStorage.length)
            textStorage.removeAttribute(.foregroundColor, range: range)
            textStorage.removeAttribute(.font, range: range)
            return
        }
        
        // Apply syntax highlighting
        let highlights = highlighter.highlight(text: text, language: language)
        
        textStorage.beginEditing()
        
        // Clear existing attributes
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.foregroundColor, range: fullRange)
        textStorage.removeAttribute(.font, range: fullRange)
        
        // Apply base attributes
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: configuration.font,
            .foregroundColor: configuration.theme.textColor
        ]
        textStorage.addAttributes(baseAttributes, range: fullRange)
        
        // Apply syntax highlights
        for highlight in highlights {
            if let color = configuration.theme.color(for: highlight.type) {
                textStorage.addAttribute(.foregroundColor, value: color, range: highlight.range)
            }
            if highlight.type == .keyword || highlight.type == .type {
                textStorage.addAttribute(.font, value: configuration.boldFont, range: highlight.range)
            }
        }
        
        textStorage.endEditing()
    }
    
    /// Update line numbers
    private func updateLineNumbers() {
        let lines = text.components(separatedBy: .newlines)
        lineNumbers = Array(1...max(1, lines.count))
    }
    
    // MARK: - Editing Operations
    
    /// Insert text at the current cursor position
    func insertText(_ text: String) {
        guard cursorPosition.location <= self.text.count else { return }
        
        // Register undo
        let oldText = self.text
        let oldCursor = cursorPosition
        
        undoManager.registerUndo(withTarget: self) { target in
            target.text = oldText
            target.cursorPosition = oldCursor
        }
        
        // Insert text
        let index = self.text.index(self.text.startIndex, offsetBy: cursorPosition.location)
        self.text.insert(contentsOf: text, at: index)
        
        // Update cursor position
        cursorPosition = NSRange(location: cursorPosition.location + text.count, length: 0)
    }
    
    /// Delete text in range
    func deleteText(in range: NSRange) {
        guard let textRange = Range(range, in: text) else { return }
        
        // Register undo
        let oldText = self.text
        let oldCursor = cursorPosition
        
        undoManager.registerUndo(withTarget: self) { target in
            target.text = oldText
            target.cursorPosition = oldCursor
        }
        
        // Delete text
        text.removeSubrange(textRange)
        
        // Update cursor position
        cursorPosition = NSRange(location: range.location, length: 0)
    }
    
    /// Replace text in range
    func replaceText(in range: NSRange, with replacement: String) {
        guard let textRange = Range(range, in: text) else { return }
        
        // Register undo
        let oldText = self.text
        let oldCursor = cursorPosition
        
        undoManager.registerUndo(withTarget: self) { target in
            target.text = oldText
            target.cursorPosition = oldCursor
        }
        
        // Replace text
        text.replaceSubrange(textRange, with: replacement)
        
        // Update cursor position
        cursorPosition = NSRange(location: range.location + replacement.count, length: 0)
    }
    
    // MARK: - Selection Management
    
    /// Add a new selection range
    func addSelection(_ range: NSRange) {
        selections.append(range)
        selections.sort { $0.location < $1.location }
    }
    
    /// Clear all selections
    func clearSelections() {
        selections.removeAll()
    }
    
    /// Get selected text
    func selectedText() -> String? {
        guard cursorPosition.length > 0,
              let range = Range(cursorPosition, in: text) else { return nil }
        return String(text[range])
    }
    
    // MARK: - Code Features
    
    /// Get code completions at the current cursor position
    func getCompletions() -> [CodeCompletion] {
        return completionEngine.completions(
            for: text,
            at: cursorPosition.location,
            language: language
        )
    }
    
    /// Find matching bracket for the bracket at the given position
    func findMatchingBracket(at position: Int) -> Int? {
        guard position < text.count else { return nil }
        
        let index = text.index(text.startIndex, offsetBy: position)
        let char = text[index]
        
        let brackets: [Character: Character] = [
            "(": ")", "[": "]", "{": "}",
            ")": "(", "]": "[", "}": "{"
        ]
        
        guard let match = brackets[char] else { return nil }
        
        let isOpening = "([{".contains(char)
        var depth = 0
        
        if isOpening {
            // Search forward
            var searchIndex = text.index(after: index)
            while searchIndex < text.endIndex {
                let currentChar = text[searchIndex]
                if currentChar == char {
                    depth += 1
                } else if currentChar == match {
                    if depth == 0 {
                        return text.distance(from: text.startIndex, to: searchIndex)
                    }
                    depth -= 1
                }
                searchIndex = text.index(after: searchIndex)
            }
        } else {
            // Search backward
            var searchIndex = index
            while searchIndex > text.startIndex {
                searchIndex = text.index(before: searchIndex)
                let currentChar = text[searchIndex]
                if currentChar == char {
                    depth += 1
                } else if currentChar == match {
                    if depth == 0 {
                        return text.distance(from: text.startIndex, to: searchIndex)
                    }
                    depth -= 1
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Performance Optimization
    
    private func scheduleUpdate(_ update: EditorUpdate) {
        pendingUpdates.insert(update)
        
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.processPendingUpdates()
        }
    }
    
    private func processPendingUpdates() {
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        
        for update in updates {
            switch update {
            case .highlighting:
                applyHighlighting()
            case .lineNumbers:
                updateLineNumbers()
            case .completion:
                // Trigger completion update
                objectWillChange.send()
            }
        }
    }
}

// MARK: - NSTextStorageDelegate

extension CodeEditorCore: NSTextStorageDelegate {
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        
        // Update text property
        self.text = textStorage.string
        
        // Schedule updates
        scheduleUpdate(.highlighting)
        scheduleUpdate(.lineNumbers)
    }
}

// MARK: - Supporting Types

/// Editor configuration
struct EditorConfiguration {
    var font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    var boldFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .semibold)
    var theme: EditorTheme = .default
    var tabSize: Int = 4
    var useTabs: Bool = false
    var showLineNumbers: Bool = true
    var showInvisibles: Bool = false
    var wordWrap: Bool = false
    var autoIndent: Bool = true
    var autoCloseBrackets: Bool = true
    
    static let `default` = EditorConfiguration()
}

/// Editor update types for batching
enum EditorUpdate: Hashable {
    case highlighting
    case lineNumbers
    case completion
}

/// Programming language enumeration
enum ProgrammingLanguage: String, CaseIterable, Identifiable {
    case plainText = "plain"
    case swift = "swift"
    case python = "python"
    case javascript = "javascript"
    case typescript = "typescript"
    case go = "go"
    case rust = "rust"
    case html = "html"
    case css = "css"
    case json = "json"
    case yaml = "yaml"
    case markdown = "markdown"
    case cpp = "cpp"
    case java = "java"
    case kotlin = "kotlin"
    case ruby = "ruby"
    case php = "php"
    case sql = "sql"
    case shell = "shell"
    case xml = "xml"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .plainText: return "Plain Text"
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .go: return "Go"
        case .rust: return "Rust"
        case .html: return "HTML"
        case .css: return "CSS"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .markdown: return "Markdown"
        case .cpp: return "C++"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .ruby: return "Ruby"
        case .php: return "PHP"
        case .sql: return "SQL"
        case .shell: return "Shell"
        case .xml: return "XML"
        }
    }
    
    var fileExtensions: [String] {
        switch self {
        case .plainText: return ["txt"]
        case .swift: return ["swift"]
        case .python: return ["py", "pyw"]
        case .javascript: return ["js", "mjs"]
        case .typescript: return ["ts", "tsx"]
        case .go: return ["go"]
        case .rust: return ["rs"]
        case .html: return ["html", "htm"]
        case .css: return ["css", "scss", "sass"]
        case .json: return ["json"]
        case .yaml: return ["yaml", "yml"]
        case .markdown: return ["md", "markdown"]
        case .cpp: return ["cpp", "cc", "cxx", "hpp", "h"]
        case .java: return ["java"]
        case .kotlin: return ["kt", "kts"]
        case .ruby: return ["rb"]
        case .php: return ["php"]
        case .sql: return ["sql"]
        case .shell: return ["sh", "bash", "zsh"]
        case .xml: return ["xml"]
        }
    }
    
    static func from(fileExtension: String) -> ProgrammingLanguage {
        let ext = fileExtension.lowercased()
        for language in Self.allCases {
            if language.fileExtensions.contains(ext) {
                return language
            }
        }
        return .plainText
    }
}
#endif // os(iOS)
