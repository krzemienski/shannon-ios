//
//  SyntaxHighlighter.swift
//  ClaudeCode
//
//  Language-aware syntax highlighting engine
//

import Foundation
import UIKit

/// Token type for syntax highlighting
enum TokenType {
    case keyword
    case type
    case string
    case number
    case comment
    case function
    case variable
    case constant
    case `operator`
    case punctuation
    case attribute
    case preprocessor
    case regex
    case url
    case plain
}

/// Highlighted range with token type
struct HighlightedRange {
    let range: NSRange
    let type: TokenType
}

/// Syntax highlighter for various programming languages
final class SyntaxHighlighter {
    
    // MARK: - Properties
    
    private let queue = DispatchQueue(label: "com.claudecode.syntaxhighlighter", qos: .userInitiated)
    private var languageDefinitions: [ProgrammingLanguage: LanguageDefinition] = [:]
    
    // MARK: - Initialization
    
    init() {
        loadLanguageDefinitions()
    }
    
    // MARK: - Public Methods
    
    /// Highlight text for the specified language
    func highlight(text: String, language: ProgrammingLanguage) -> [HighlightedRange] {
        guard let definition = languageDefinitions[language] else {
            return []
        }
        
        var highlights: [HighlightedRange] = []
        let nsString = text as NSString
        
        // Process different token types
        highlights.append(contentsOf: highlightKeywords(in: nsString, definition: definition))
        highlights.append(contentsOf: highlightTypes(in: nsString, definition: definition))
        highlights.append(contentsOf: highlightStrings(in: nsString, definition: definition))
        highlights.append(contentsOf: highlightNumbers(in: nsString))
        highlights.append(contentsOf: highlightComments(in: nsString, definition: definition))
        highlights.append(contentsOf: highlightFunctions(in: nsString, definition: definition))
        highlights.append(contentsOf: highlightOperators(in: nsString, definition: definition))
        
        // Sort by range location for efficient rendering
        highlights.sort { $0.range.location < $1.range.location }
        
        return highlights
    }
    
    /// Asynchronous highlighting for large files
    func highlightAsync(text: String, language: ProgrammingLanguage, completion: @escaping ([HighlightedRange]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let highlights = self.highlight(text: text, language: language)
            DispatchQueue.main.async {
                completion(highlights)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadLanguageDefinitions() {
        // Swift
        languageDefinitions[.swift] = LanguageDefinition(
            keywords: ["func", "var", "let", "if", "else", "for", "while", "switch", "case", "default",
                      "return", "break", "continue", "import", "class", "struct", "enum", "protocol",
                      "extension", "init", "deinit", "self", "super", "static", "private", "public",
                      "internal", "fileprivate", "open", "final", "lazy", "weak", "unowned", "guard",
                      "defer", "async", "await", "throws", "try", "catch", "as", "is", "nil", "true",
                      "false", "where", "typealias", "associatedtype", "inout", "operator", "precedencegroup",
                      "@available", "@objc", "@escaping", "@autoclosure", "@discardableResult",
                      "@propertyWrapper", "@main", "@UIApplicationMain", "mutating", "nonmutating",
                      "override", "required", "convenience"],
            types: ["Int", "Double", "Float", "Bool", "String", "Character", "Array", "Dictionary",
                   "Set", "Optional", "Any", "AnyObject", "Void", "Never", "Self", "Type",
                   "UIView", "UIViewController", "UIButton", "UILabel", "UITableView", "UICollectionView",
                   "NSObject", "NSString", "NSArray", "NSDictionary", "NSNumber", "NSData",
                   "SwiftUI", "View", "Text", "Image", "Button", "List", "NavigationView"],
            stringDelimiters: [("\"", "\""), ("\"\"\"", "\"\"\"")],
            commentDelimiters: [("//", "\n"), ("/*", "*/")],
            functionPattern: "\\b(func)\\s+(\\w+)",
            operatorCharacters: "+-*/=%<>!&|^~?.:"
        )
        
        // Python
        languageDefinitions[.python] = LanguageDefinition(
            keywords: ["def", "class", "if", "elif", "else", "for", "while", "try", "except",
                      "finally", "with", "as", "import", "from", "return", "yield", "break",
                      "continue", "pass", "raise", "assert", "del", "global", "nonlocal",
                      "lambda", "and", "or", "not", "in", "is", "None", "True", "False",
                      "async", "await", "__init__", "__name__", "__main__", "self", "cls"],
            types: ["int", "float", "str", "bool", "list", "dict", "tuple", "set", "frozenset",
                   "bytes", "bytearray", "memoryview", "range", "object", "type", "callable",
                   "property", "staticmethod", "classmethod", "super"],
            stringDelimiters: [("\"\"\"", "\"\"\""), ("'''", "'''"), ("\"", "\""), ("'", "'")],
            commentDelimiters: [("#", "\n")],
            functionPattern: "\\b(def)\\s+(\\w+)",
            operatorCharacters: "+-*/=%<>!&|^~@:"
        )
        
        // JavaScript/TypeScript
        let jsKeywords = ["function", "var", "let", "const", "if", "else", "for", "while", "do",
                         "switch", "case", "default", "break", "continue", "return", "try",
                         "catch", "finally", "throw", "new", "delete", "typeof", "instanceof",
                         "void", "this", "super", "class", "extends", "static", "async", "await",
                         "import", "export", "default", "from", "as", "null", "undefined", "true",
                         "false", "debugger", "with", "yield", "of", "in", "get", "set"]
        
        languageDefinitions[.javascript] = LanguageDefinition(
            keywords: jsKeywords,
            types: ["Object", "Array", "String", "Number", "Boolean", "Function", "Symbol",
                   "Map", "Set", "WeakMap", "WeakSet", "Promise", "Date", "RegExp", "Error",
                   "JSON", "Math", "console", "window", "document"],
            stringDelimiters: [("\"", "\""), ("'", "'"), ("`", "`")],
            commentDelimiters: [("//", "\n"), ("/*", "*/")],
            functionPattern: "\\b(function)\\s+(\\w+)|\\b(\\w+)\\s*=\\s*\\([^)]*\\)\\s*=>",
            operatorCharacters: "+-*/=%<>!&|^~?:.,"
        )
        
        languageDefinitions[.typescript] = LanguageDefinition(
            keywords: jsKeywords + ["interface", "type", "enum", "namespace", "module", "declare",
                                   "abstract", "implements", "private", "protected", "public",
                                   "readonly", "keyof", "infer", "never", "unknown", "any"],
            types: ["string", "number", "boolean", "void", "never", "any", "unknown", "object",
                   "symbol", "bigint"] + languageDefinitions[.javascript]!.types,
            stringDelimiters: [("\"", "\""), ("'", "'"), ("`", "`")],
            commentDelimiters: [("//", "\n"), ("/*", "*/")],
            functionPattern: "\\b(function)\\s+(\\w+)|\\b(\\w+)\\s*=\\s*\\([^)]*\\)\\s*=>",
            operatorCharacters: "+-*/=%<>!&|^~?:.,"
        )
        
        // Go
        languageDefinitions[.go] = LanguageDefinition(
            keywords: ["package", "import", "func", "var", "const", "type", "struct", "interface",
                      "map", "chan", "if", "else", "for", "range", "switch", "case", "default",
                      "break", "continue", "return", "go", "defer", "select", "fallthrough",
                      "nil", "true", "false", "iota", "make", "new", "cap", "len", "copy",
                      "append", "delete", "close", "panic", "recover"],
            types: ["bool", "string", "int", "int8", "int16", "int32", "int64", "uint", "uint8",
                   "uint16", "uint32", "uint64", "uintptr", "byte", "rune", "float32", "float64",
                   "complex64", "complex128", "error"],
            stringDelimiters: [("\"", "\""), ("`", "`"), ("'", "'")],
            commentDelimiters: [("//", "\n"), ("/*", "*/")],
            functionPattern: "\\b(func)\\s+(\\w+)",
            operatorCharacters: "+-*/=%<>!&|^~:."
        )
        
        // Rust
        languageDefinitions[.rust] = LanguageDefinition(
            keywords: ["fn", "let", "mut", "const", "static", "if", "else", "match", "for", "while",
                      "loop", "break", "continue", "return", "use", "mod", "pub", "impl", "trait",
                      "struct", "enum", "type", "where", "async", "await", "move", "ref", "as",
                      "in", "extern", "crate", "self", "super", "Self", "true", "false", "unsafe",
                      "macro_rules!", "dyn", "abstract", "become", "box", "do", "final", "macro",
                      "override", "priv", "typeof", "unsized", "virtual", "yield"],
            types: ["i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64", "u128",
                   "usize", "f32", "f64", "bool", "char", "str", "String", "Vec", "HashMap",
                   "Option", "Result", "Box", "Rc", "Arc", "RefCell", "Mutex"],
            stringDelimiters: [("\"", "\""), ("r#\"", "\"#"), ("'", "'")],
            commentDelimiters: [("//", "\n"), ("/*", "*/")],
            functionPattern: "\\b(fn)\\s+(\\w+)",
            operatorCharacters: "+-*/=%<>!&|^~?:."
        )
        
        // HTML
        languageDefinitions[.html] = LanguageDefinition(
            keywords: ["DOCTYPE", "html", "head", "body", "title", "meta", "link", "script", "style",
                      "div", "span", "p", "a", "img", "ul", "ol", "li", "table", "tr", "td", "th",
                      "form", "input", "button", "select", "option", "textarea", "label", "nav",
                      "header", "footer", "section", "article", "aside", "main", "figure", "figcaption",
                      "video", "audio", "canvas", "svg", "iframe", "h1", "h2", "h3", "h4", "h5", "h6"],
            types: [],
            stringDelimiters: [("\"", "\""), ("'", "'")],
            commentDelimiters: [("<!--", "-->")],
            functionPattern: "",
            operatorCharacters: "="
        )
        
        // CSS
        languageDefinitions[.css] = LanguageDefinition(
            keywords: ["important", "auto", "inherit", "initial", "unset", "none", "block", "inline",
                      "inline-block", "flex", "grid", "absolute", "relative", "fixed", "static",
                      "sticky", "left", "right", "top", "bottom", "center", "solid", "dotted",
                      "dashed", "bold", "italic", "normal", "uppercase", "lowercase", "capitalize"],
            types: ["px", "em", "rem", "vh", "vw", "%", "deg", "rad", "turn", "s", "ms", "rgb",
                   "rgba", "hsl", "hsla", "hex"],
            stringDelimiters: [("\"", "\""), ("'", "'")],
            commentDelimiters: [("/*", "*/")],
            functionPattern: "",
            operatorCharacters: ":;{}[](),.>#~+*/"
        )
        
        // JSON
        languageDefinitions[.json] = LanguageDefinition(
            keywords: ["null", "true", "false"],
            types: [],
            stringDelimiters: [("\"", "\"")],
            commentDelimiters: [],
            functionPattern: "",
            operatorCharacters: ":,{}[]"
        )
        
        // Add more language definitions as needed...
    }
    
    private func highlightKeywords(in string: NSString, definition: LanguageDefinition) -> [HighlightedRange] {
        var highlights: [HighlightedRange] = []
        
        for keyword in definition.keywords {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
                for match in matches {
                    highlights.append(HighlightedRange(range: match.range, type: .keyword))
                }
            }
        }
        
        return highlights
    }
    
    private func highlightTypes(in string: NSString, definition: LanguageDefinition) -> [HighlightedRange] {
        var highlights: [HighlightedRange] = []
        
        for type in definition.types {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: type))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
                for match in matches {
                    highlights.append(HighlightedRange(range: match.range, type: .type))
                }
            }
        }
        
        return highlights
    }
    
    private func highlightStrings(in string: NSString, definition: LanguageDefinition) -> [HighlightedRange] {
        var highlights: [HighlightedRange] = []
        
        for (start, end) in definition.stringDelimiters {
            let pattern = "\(NSRegularExpression.escapedPattern(for: start))(.*?)\(NSRegularExpression.escapedPattern(for: end))"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let matches = regex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
                for match in matches {
                    highlights.append(HighlightedRange(range: match.range, type: .string))
                }
            }
        }
        
        return highlights
    }
    
    private func highlightNumbers(in string: NSString) -> [HighlightedRange] {
        var highlights: [HighlightedRange] = []
        
        let pattern = "\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b|\\b0x[0-9a-fA-F]+\\b|\\b0b[01]+\\b|\\b0o[0-7]+\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
            for match in matches {
                highlights.append(HighlightedRange(range: match.range, type: .number))
            }
        }
        
        return highlights
    }
    
    private func highlightComments(in string: NSString, definition: LanguageDefinition) -> [HighlightedRange] {
        var highlights: [HighlightedRange] = []
        
        for (start, end) in definition.commentDelimiters {
            let pattern: String
            if end == "\n" {
                // Single-line comment
                pattern = "\(NSRegularExpression.escapedPattern(for: start)).*$"
            } else {
                // Multi-line comment
                pattern = "\(NSRegularExpression.escapedPattern(for: start))(.*?)\(NSRegularExpression.escapedPattern(for: end))"
            }
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .dotMatchesLineSeparators]) {
                let matches = regex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
                for match in matches {
                    highlights.append(HighlightedRange(range: match.range, type: .comment))
                }
            }
        }
        
        return highlights
    }
    
    private func highlightFunctions(in string: NSString, definition: LanguageDefinition) -> [HighlightedRange] {
        guard !definition.functionPattern.isEmpty else { return [] }
        
        var highlights: [HighlightedRange] = []
        
        if let regex = try? NSRegularExpression(pattern: definition.functionPattern, options: []) {
            let matches = regex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
            for match in matches {
                if match.numberOfRanges > 2 {
                    let functionNameRange = match.range(at: 2)
                    if functionNameRange.location != NSNotFound {
                        highlights.append(HighlightedRange(range: functionNameRange, type: .function))
                    }
                }
            }
        }
        
        return highlights
    }
    
    private func highlightOperators(in string: NSString, definition: LanguageDefinition) -> [HighlightedRange] {
        var highlights: [HighlightedRange] = []
        
        let operatorSet = CharacterSet(charactersIn: definition.operatorCharacters)
        var currentIndex = 0
        
        while currentIndex < string.length {
            let char = string.character(at: currentIndex)
            let unicodeScalar = UnicodeScalar(char)!
            
            if operatorSet.contains(unicodeScalar) {
                highlights.append(HighlightedRange(
                    range: NSRange(location: currentIndex, length: 1),
                    type: .operator
                ))
            }
            
            currentIndex += 1
        }
        
        return highlights
    }
}

// MARK: - Supporting Types

/// Language definition for syntax highlighting
struct LanguageDefinition {
    let keywords: [String]
    let types: [String]
    let stringDelimiters: [(String, String)]
    let commentDelimiters: [(String, String)]
    let functionPattern: String
    let operatorCharacters: String
}