//
//  CodeCompletionEngine.swift
//  ClaudeCode
//
//  Intelligent code completion and suggestions engine
//

import Foundation

/// Code completion suggestion
struct CodeCompletion {
    let text: String
    let type: CompletionType
    let detail: String?
    let insertText: String
    let documentation: String?
    let score: Double // Relevance score for sorting
    
    enum CompletionType {
        case keyword
        case type
        case function
        case method
        case property
        case variable
        case constant
        case snippet
        case module
    }
}

/// Code snippet template
struct CodeSnippet {
    let name: String
    let prefix: String
    let body: String
    let description: String
    let language: ProgrammingLanguage
    
    var insertText: String {
        // Convert snippet placeholders to proper format
        body.replacingOccurrences(of: "${1:", with: "")
            .replacingOccurrences(of: "${2:", with: "")
            .replacingOccurrences(of: "${3:", with: "")
            .replacingOccurrences(of: "}", with: "")
    }
}

/// Intelligent code completion engine
final class CodeCompletionEngine {
    
    // MARK: - Properties
    
    private var languageCompletions: [ProgrammingLanguage: [CodeCompletion]] = [:]
    private var snippets: [ProgrammingLanguage: [CodeSnippet]] = [:]
    private let contextAnalyzer = ContextAnalyzer()
    
    // MARK: - Initialization
    
    init() {
        loadCompletions()
        loadSnippets()
    }
    
    // MARK: - Public Methods
    
    /// Get completions for the current context
    func completions(for text: String, at position: Int, language: ProgrammingLanguage) -> [CodeCompletion] {
        // Get the current word being typed
        let currentWord = getCurrentWord(in: text, at: position)
        
        // Get context (what comes before the cursor)
        let context = getContext(in: text, at: position)
        
        // Get base completions for the language
        var completions = languageCompletions[language] ?? []
        
        // Add snippet completions
        let snippetCompletions = snippets[language]?.compactMap { snippet -> CodeCompletion? in
            guard snippet.prefix.hasPrefix(currentWord.lowercased()) else { return nil }
            return CodeCompletion(
                text: snippet.name,
                type: .snippet,
                detail: snippet.description,
                insertText: snippet.insertText,
                documentation: snippet.description,
                score: 0.8
            )
        } ?? []
        completions.append(contentsOf: snippetCompletions)
        
        // Filter by current word
        if !currentWord.isEmpty {
            completions = completions.filter { completion in
                completion.text.lowercased().hasPrefix(currentWord.lowercased())
            }
        }
        
        // Score and sort by relevance
        completions = scoreCompletions(completions, context: context, currentWord: currentWord)
        
        // Limit to top results
        return Array(completions.prefix(20))
    }
    
    /// Get contextual snippets
    func getSnippets(for language: ProgrammingLanguage, context: String? = nil) -> [CodeSnippet] {
        guard let allSnippets = snippets[language] else { return [] }
        
        if let context = context {
            // Filter snippets by context
            return allSnippets.filter { snippet in
                snippet.prefix.contains(context) || snippet.description.lowercased().contains(context.lowercased())
            }
        }
        
        return allSnippets
    }
    
    // MARK: - Private Methods
    
    private func loadCompletions() {
        // Swift completions
        languageCompletions[.swift] = [
            // Keywords
            CodeCompletion(text: "func", type: .keyword, detail: "Function declaration", insertText: "func ", documentation: "Declare a new function", score: 1.0),
            CodeCompletion(text: "var", type: .keyword, detail: "Variable declaration", insertText: "var ", documentation: "Declare a mutable variable", score: 1.0),
            CodeCompletion(text: "let", type: .keyword, detail: "Constant declaration", insertText: "let ", documentation: "Declare an immutable constant", score: 1.0),
            CodeCompletion(text: "if", type: .keyword, detail: "Conditional statement", insertText: "if ", documentation: "Conditional execution", score: 1.0),
            CodeCompletion(text: "guard", type: .keyword, detail: "Guard statement", insertText: "guard ", documentation: "Early exit with guard", score: 1.0),
            CodeCompletion(text: "for", type: .keyword, detail: "For loop", insertText: "for ", documentation: "Iterate over a sequence", score: 1.0),
            CodeCompletion(text: "while", type: .keyword, detail: "While loop", insertText: "while ", documentation: "Loop while condition is true", score: 1.0),
            CodeCompletion(text: "switch", type: .keyword, detail: "Switch statement", insertText: "switch ", documentation: "Multi-way branch", score: 1.0),
            CodeCompletion(text: "class", type: .keyword, detail: "Class declaration", insertText: "class ", documentation: "Define a new class", score: 1.0),
            CodeCompletion(text: "struct", type: .keyword, detail: "Struct declaration", insertText: "struct ", documentation: "Define a new struct", score: 1.0),
            CodeCompletion(text: "enum", type: .keyword, detail: "Enum declaration", insertText: "enum ", documentation: "Define a new enumeration", score: 1.0),
            CodeCompletion(text: "protocol", type: .keyword, detail: "Protocol declaration", insertText: "protocol ", documentation: "Define a new protocol", score: 1.0),
            CodeCompletion(text: "extension", type: .keyword, detail: "Extension declaration", insertText: "extension ", documentation: "Extend an existing type", score: 1.0),
            
            // Types
            CodeCompletion(text: "String", type: .type, detail: "String type", insertText: "String", documentation: "A Unicode string value", score: 0.9),
            CodeCompletion(text: "Int", type: .type, detail: "Integer type", insertText: "Int", documentation: "A signed integer value", score: 0.9),
            CodeCompletion(text: "Double", type: .type, detail: "Double type", insertText: "Double", documentation: "A double-precision floating-point value", score: 0.9),
            CodeCompletion(text: "Bool", type: .type, detail: "Boolean type", insertText: "Bool", documentation: "A Boolean value", score: 0.9),
            CodeCompletion(text: "Array", type: .type, detail: "Array type", insertText: "Array<", documentation: "An ordered collection", score: 0.9),
            CodeCompletion(text: "Dictionary", type: .type, detail: "Dictionary type", insertText: "Dictionary<", documentation: "A collection of key-value pairs", score: 0.9),
            CodeCompletion(text: "Optional", type: .type, detail: "Optional type", insertText: "Optional<", documentation: "A type that can be nil", score: 0.9),
            
            // Common methods
            CodeCompletion(text: "print", type: .function, detail: "Print to console", insertText: "print(", documentation: "Write to standard output", score: 0.8),
            CodeCompletion(text: "append", type: .method, detail: "Append to collection", insertText: "append(", documentation: "Add element to end of array", score: 0.8),
            CodeCompletion(text: "count", type: .property, detail: "Collection count", insertText: "count", documentation: "Number of elements", score: 0.8),
            CodeCompletion(text: "isEmpty", type: .property, detail: "Check if empty", insertText: "isEmpty", documentation: "Returns true if empty", score: 0.8),
        ]
        
        // Python completions
        languageCompletions[.python] = [
            CodeCompletion(text: "def", type: .keyword, detail: "Function definition", insertText: "def ", documentation: "Define a function", score: 1.0),
            CodeCompletion(text: "class", type: .keyword, detail: "Class definition", insertText: "class ", documentation: "Define a class", score: 1.0),
            CodeCompletion(text: "if", type: .keyword, detail: "If statement", insertText: "if ", documentation: "Conditional execution", score: 1.0),
            CodeCompletion(text: "elif", type: .keyword, detail: "Else if statement", insertText: "elif ", documentation: "Else if condition", score: 1.0),
            CodeCompletion(text: "else", type: .keyword, detail: "Else statement", insertText: "else:", documentation: "Else clause", score: 1.0),
            CodeCompletion(text: "for", type: .keyword, detail: "For loop", insertText: "for ", documentation: "Iterate over sequence", score: 1.0),
            CodeCompletion(text: "while", type: .keyword, detail: "While loop", insertText: "while ", documentation: "Loop while true", score: 1.0),
            CodeCompletion(text: "import", type: .keyword, detail: "Import module", insertText: "import ", documentation: "Import a module", score: 1.0),
            CodeCompletion(text: "from", type: .keyword, detail: "From import", insertText: "from ", documentation: "Import from module", score: 1.0),
            CodeCompletion(text: "return", type: .keyword, detail: "Return statement", insertText: "return ", documentation: "Return from function", score: 1.0),
            CodeCompletion(text: "print", type: .function, detail: "Print function", insertText: "print(", documentation: "Print to stdout", score: 0.8),
            CodeCompletion(text: "len", type: .function, detail: "Length function", insertText: "len(", documentation: "Get length of object", score: 0.8),
            CodeCompletion(text: "range", type: .function, detail: "Range function", insertText: "range(", documentation: "Generate range of numbers", score: 0.8),
        ]
        
        // JavaScript/TypeScript completions
        let jsCompletions = [
            CodeCompletion(text: "function", type: .keyword, detail: "Function declaration", insertText: "function ", documentation: "Declare a function", score: 1.0),
            CodeCompletion(text: "const", type: .keyword, detail: "Constant declaration", insertText: "const ", documentation: "Declare a constant", score: 1.0),
            CodeCompletion(text: "let", type: .keyword, detail: "Variable declaration", insertText: "let ", documentation: "Declare a block-scoped variable", score: 1.0),
            CodeCompletion(text: "var", type: .keyword, detail: "Variable declaration", insertText: "var ", documentation: "Declare a function-scoped variable", score: 1.0),
            CodeCompletion(text: "if", type: .keyword, detail: "If statement", insertText: "if ", documentation: "Conditional execution", score: 1.0),
            CodeCompletion(text: "else", type: .keyword, detail: "Else statement", insertText: "else ", documentation: "Else clause", score: 1.0),
            CodeCompletion(text: "for", type: .keyword, detail: "For loop", insertText: "for ", documentation: "Loop statement", score: 1.0),
            CodeCompletion(text: "while", type: .keyword, detail: "While loop", insertText: "while ", documentation: "Loop while true", score: 1.0),
            CodeCompletion(text: "return", type: .keyword, detail: "Return statement", insertText: "return ", documentation: "Return from function", score: 1.0),
            CodeCompletion(text: "async", type: .keyword, detail: "Async function", insertText: "async ", documentation: "Asynchronous function", score: 1.0),
            CodeCompletion(text: "await", type: .keyword, detail: "Await expression", insertText: "await ", documentation: "Wait for promise", score: 1.0),
            CodeCompletion(text: "console.log", type: .function, detail: "Console log", insertText: "console.log(", documentation: "Log to console", score: 0.8),
        ]
        
        languageCompletions[.javascript] = jsCompletions
        languageCompletions[.typescript] = jsCompletions + [
            CodeCompletion(text: "interface", type: .keyword, detail: "Interface declaration", insertText: "interface ", documentation: "Define an interface", score: 1.0),
            CodeCompletion(text: "type", type: .keyword, detail: "Type alias", insertText: "type ", documentation: "Define a type alias", score: 1.0),
            CodeCompletion(text: "enum", type: .keyword, detail: "Enum declaration", insertText: "enum ", documentation: "Define an enum", score: 1.0),
        ]
    }
    
    private func loadSnippets() {
        // Swift snippets
        snippets[.swift] = [
            CodeSnippet(
                name: "Function",
                prefix: "func",
                body: "func ${1:name}(${2:parameters}) -> ${3:ReturnType} {\n    ${4:// body}\n}",
                description: "Function declaration",
                language: .swift
            ),
            CodeSnippet(
                name: "Guard Let",
                prefix: "guard",
                body: "guard let ${1:name} = ${2:optional} else {\n    ${3:return}\n}",
                description: "Guard let statement",
                language: .swift
            ),
            CodeSnippet(
                name: "If Let",
                prefix: "iflet",
                body: "if let ${1:name} = ${2:optional} {\n    ${3:// use name}\n}",
                description: "Optional binding",
                language: .swift
            ),
            CodeSnippet(
                name: "For In",
                prefix: "forin",
                body: "for ${1:item} in ${2:collection} {\n    ${3:// body}\n}",
                description: "For-in loop",
                language: .swift
            ),
            CodeSnippet(
                name: "Switch",
                prefix: "switch",
                body: "switch ${1:value} {\ncase ${2:pattern}:\n    ${3:// code}\ndefault:\n    ${4:// default}\n}",
                description: "Switch statement",
                language: .swift
            ),
            CodeSnippet(
                name: "Class",
                prefix: "class",
                body: "class ${1:ClassName} {\n    ${2:// properties}\n    \n    init(${3:parameters}) {\n        ${4:// initialization}\n    }\n}",
                description: "Class declaration",
                language: .swift
            ),
            CodeSnippet(
                name: "Struct",
                prefix: "struct",
                body: "struct ${1:StructName} {\n    ${2:// properties}\n}",
                description: "Struct declaration",
                language: .swift
            ),
            CodeSnippet(
                name: "Enum",
                prefix: "enum",
                body: "enum ${1:EnumName} {\n    case ${2:case1}\n    case ${3:case2}\n}",
                description: "Enum declaration",
                language: .swift
            ),
        ]
        
        // Python snippets
        snippets[.python] = [
            CodeSnippet(
                name: "Function",
                prefix: "def",
                body: "def ${1:function_name}(${2:parameters}):\n    \"\"\"${3:docstring}\"\"\"\n    ${4:pass}",
                description: "Function definition",
                language: .python
            ),
            CodeSnippet(
                name: "Class",
                prefix: "class",
                body: "class ${1:ClassName}:\n    def __init__(self, ${2:parameters}):\n        ${3:self.attribute = value}",
                description: "Class definition",
                language: .python
            ),
            CodeSnippet(
                name: "If Main",
                prefix: "ifmain",
                body: "if __name__ == \"__main__\":\n    ${1:main()}",
                description: "If main guard",
                language: .python
            ),
            CodeSnippet(
                name: "Try Except",
                prefix: "try",
                body: "try:\n    ${1:# code}\nexcept ${2:Exception} as e:\n    ${3:# handle}",
                description: "Try-except block",
                language: .python
            ),
        ]
        
        // JavaScript/TypeScript snippets
        let jsSnippets = [
            CodeSnippet(
                name: "Function",
                prefix: "function",
                body: "function ${1:name}(${2:params}) {\n    ${3:// body}\n}",
                description: "Function declaration",
                language: .javascript
            ),
            CodeSnippet(
                name: "Arrow Function",
                prefix: "arrow",
                body: "const ${1:name} = (${2:params}) => {\n    ${3:// body}\n}",
                description: "Arrow function",
                language: .javascript
            ),
            CodeSnippet(
                name: "If Else",
                prefix: "ifelse",
                body: "if (${1:condition}) {\n    ${2:// true}\n} else {\n    ${3:// false}\n}",
                description: "If-else statement",
                language: .javascript
            ),
            CodeSnippet(
                name: "For Loop",
                prefix: "for",
                body: "for (let ${1:i} = 0; ${1:i} < ${2:length}; ${1:i}++) {\n    ${3:// body}\n}",
                description: "For loop",
                language: .javascript
            ),
            CodeSnippet(
                name: "Console Log",
                prefix: "log",
                body: "console.log(${1:message});",
                description: "Console log",
                language: .javascript
            ),
        ]
        
        snippets[.javascript] = jsSnippets
        snippets[.typescript] = jsSnippets
    }
    
    private func getCurrentWord(in text: String, at position: Int) -> String {
        guard position > 0, position <= text.count else { return "" }
        
        let beforeIndex = text.index(text.startIndex, offsetBy: position)
        let beforeText = String(text[..<beforeIndex])
        
        // Find the start of the current word
        var wordStart = position
        for (index, char) in beforeText.reversed().enumerated() {
            if !char.isLetter && !char.isNumber && char != "_" {
                wordStart = position - index
                break
            }
        }
        
        if wordStart == position {
            wordStart = 0
        }
        
        let startIndex = text.index(text.startIndex, offsetBy: wordStart)
        let endIndex = beforeIndex
        
        return String(text[startIndex..<endIndex])
    }
    
    private func getContext(in text: String, at position: Int) -> String {
        guard position > 0, position <= text.count else { return "" }
        
        let contextLength = min(100, position)
        let startOffset = max(0, position - contextLength)
        
        let startIndex = text.index(text.startIndex, offsetBy: startOffset)
        let endIndex = text.index(text.startIndex, offsetBy: position)
        
        return String(text[startIndex..<endIndex])
    }
    
    private func scoreCompletions(_ completions: [CodeCompletion], context: String, currentWord: String) -> [CodeCompletion] {
        return completions.map { completion in
            var score = completion.score
            
            // Exact match bonus
            if completion.text == currentWord {
                score += 0.5
            }
            
            // Starts with bonus
            if completion.text.hasPrefix(currentWord) {
                score += 0.3
            }
            
            // Context relevance bonus
            if context.contains("func") && completion.type == .function {
                score += 0.2
            }
            if context.contains("class") && completion.type == .type {
                score += 0.2
            }
            if context.contains("var") || context.contains("let") {
                if completion.type == .type {
                    score += 0.3
                }
            }
            
            // Create new completion with updated score
            return CodeCompletion(
                text: completion.text,
                type: completion.type,
                detail: completion.detail,
                insertText: completion.insertText,
                documentation: completion.documentation,
                score: score
            )
        }.sorted { $0.score > $1.score }
    }
}

// MARK: - Context Analyzer

/// Analyzes code context for better completions
private class ContextAnalyzer {
    
    func analyze(text: String, position: Int) -> CodeContext {
        // Simplified context analysis
        return CodeContext(
            isInFunction: false,
            isInClass: false,
            isInString: false,
            isInComment: false,
            precedingToken: nil,
            currentScope: .global
        )
    }
    
    struct CodeContext {
        let isInFunction: Bool
        let isInClass: Bool
        let isInString: Bool
        let isInComment: Bool
        let precedingToken: String?
        let currentScope: Scope
        
        enum Scope {
            case global
            case function
            case classBody
            case method
        }
    }
}