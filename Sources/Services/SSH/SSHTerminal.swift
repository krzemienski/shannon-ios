//
//  SSHTerminal.swift
//  ClaudeCode
//
//  SSH terminal emulation
//

import Foundation
import SwiftUI
import Combine

// MVP: Define types directly here for compilation (duplicated from TerminalStubTypes.swift)
// These should be moved to a shared module in the future

public enum TerminalColor: Equatable {
    case `default`
    case ansi(Int)
    case ansiBright(Int)  // MVP: Add missing cases
    case palette(Int)
    case rgb(UInt8, UInt8, UInt8)
    
    public var swiftUIColor: Color {
        switch self {
        case .default:
            return Color.primary
        case .ansi(let code):
            // MVP: Basic ANSI color mapping
            switch code {
            case 0: return Color.black
            case 1: return Color.red
            case 2: return Color.green
            case 3: return Color.yellow
            case 4: return Color.blue
            case 5: return Color.purple
            case 6: return Color.cyan
            case 7: return Color.white
            default: return Color.primary
            }
        case .ansiBright(_):
            return Color.primary // MVP: Simplified
        case .palette(_):
            return Color.primary // MVP: Simplified
        case .rgb(let r, let g, let b):
            return Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
        }
    }
}

public struct TerminalLine: Identifiable, Equatable {
    public let id = UUID()
    public var content: String // MVP: Make mutable for TerminalEmulator
    public let timestamp: Date
    public var characters: [TerminalCharacter] = []
    public var cells: [TerminalCell] = [] // MVP: Add cells property for compatibility
    public var text: String { // MVP: Add text property with getter/setter
        get { content }
        set { content = newValue }
    }
    
    public init(content: String = "") {
        self.content = content
        self.timestamp = Date()
        self.characters = content.map { TerminalCharacter(character: $0) }
        self.cells = content.map { TerminalCell(character: $0) }
    }
    
    // MVP: Add default initializer
    public init() {
        self.init(content: "")
    }
}

public struct TerminalCharacter: Equatable {
    public let character: Character
    public let attributes: TextAttributes
    
    public struct TextAttributes: Equatable {
        public var foregroundColor: TerminalColor = .default
        public var backgroundColor: TerminalColor = .default
        public var bold: Bool = false
        public var italic: Bool = false
        public var underline: Bool = false
        public var strikethrough: Bool = false
        public var reverse: Bool = false
        
        // MVP: Add aliases for TerminalSessionView compatibility
        public var foreground: TerminalColor { foregroundColor }
        public var background: TerminalColor { backgroundColor }
        
        public init() {} // MVP: Add public initializer
    }
    
    public init(character: Character, attributes: TextAttributes = TextAttributes()) {
        self.character = character
        self.attributes = attributes
    }
}

public struct EmulatorPosition: Equatable {
    public var row: Int
    public var column: Int
    
    public init(row: Int = 0, column: Int = 0) {
        self.row = row
        self.column = column
    }
}

public struct TerminalSize: Equatable {
    public let columns: Int
    public let rows: Int
    
    public init(columns: Int = 80, rows: Int = 24) {
        self.columns = columns
        self.rows = rows
    }
}

// MVP: Add CursorPosition type needed by TerminalEmulatorView
public struct CursorPosition: Equatable {
    public var row: Int
    public var column: Int
    
    public init(row: Int = 0, column: Int = 0) {
        self.row = row
        self.column = column
    }
    
    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }
}

// MVP: Add TerminalCursor type needed by TerminalEmulator
public struct TerminalCursor: Equatable {
    public var position: CursorPosition
    public var visible: Bool
    public var blinking: Bool
    public var style: CursorStyle = .block // MVP: Add style property
    
    public init(position: CursorPosition = CursorPosition(), visible: Bool = true, blinking: Bool = true, style: CursorStyle = .block) {
        self.position = position
        self.visible = visible
        self.blinking = blinking
        self.style = style
    }
}

// MVP: Add CursorStyle enum
public enum CursorStyle: String, CaseIterable, Codable {
    case block
    case underline
    case bar
}

// MVP: Add TerminalCell for TerminalSessionView
public struct TerminalCell: Equatable {
    public var character: Character
    public var attributes: TerminalAttributes
    
    public init(character: Character = " ", attributes: TerminalAttributes = TerminalAttributes()) {
        self.character = character
        self.attributes = attributes
    }
}

// MVP: Add TerminalAttributes as alias to TextAttributes
public typealias TerminalAttributes = TerminalCharacter.TextAttributes

// MVP: Add TerminalSettings for TerminalSettingsView
public struct SSHTerminalSettings: Codable, Equatable {
    public var fontFamily: String
    public var fontSize: CGFloat
    public var colorScheme: String
    public var cursorStyle: String
    public var bellSound: Bool
    public var scrollbackLines: Int
    
    public init(
        fontFamily: String = "SF Mono",
        fontSize: CGFloat = 13,
        colorScheme: String = "cyberpunk",
        cursorStyle: String = "block",
        bellSound: Bool = false,
        scrollbackLines: Int = 10000
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.colorScheme = colorScheme
        self.cursorStyle = cursorStyle
        self.bellSound = bellSound
        self.scrollbackLines = scrollbackLines
    }
}

@MainActor
public class SSHTerminal: ObservableObject {
    @Published public var output: String = ""
    @Published public var isConnected: Bool = false
    @Published public var currentDirectory: String = "~"
    @Published public var cursorPosition: CursorPosition = CursorPosition(row: 0, column: 0) // MVP: Changed to CursorPosition
    public var inputStream = PassthroughSubject<String, Never>()
    
    // MVP: Additional properties for TerminalEmulatorView compatibility
    @Published public var terminalBuffer = TerminalBuffer()
    @Published public var scrollbackBuffer: [TerminalLine] = []
    @Published public var terminalSize: TerminalSize = TerminalSize(columns: 80, rows: 24)
    @Published public var terminalMode: TerminalMode = .normal
    
    private var size: TerminalSize = TerminalSize(columns: 80, rows: 24)
    private var lines: [TerminalLine] = []
    
    public init() {}
    
    public func send(_ command: String) {
        // Process command
        output += "\n$ \(command)\n"
    }
    
    public func resize(to size: TerminalSize) {
        self.size = size
    }
    
    public func resize(columns: Int, rows: Int) {
        self.size = TerminalSize(columns: columns, rows: rows)
    }
    
    public func clear() {
        output = ""
        lines.removeAll()
    }
    
    public func clearScreen() {
        clear()
    }
    
    public func connect() {
        isConnected = true
    }
    
    public func disconnect() {
        isConnected = false
    }
    
    public func processInput(_ input: String) {
        inputStream.send(input)
        output += input
    }
    
    public func processOutput(_ data: Data) {
        if let string = String(data: data, encoding: .utf8) {
            output += string
        }
    }
    
    public func getVisibleLines() -> [TerminalLine] {
        return lines
    }
    
    // MVP: Add clearScrollback method for TerminalEmulatorView
    public func clearScrollback() {
        scrollbackBuffer.removeAll()
    }
}

// MVP: Add missing types for compilation
public enum TerminalMode {
    case normal
    case insert
    case visual
}

public class TerminalBuffer: ObservableObject, Equatable {
    @Published public var lines: [TerminalLine] = []
    @Published public var count: Int = 0
    
    public init() {
        // Initialize with one empty line
        lines.append(TerminalLine(content: ""))
        count = 1
    }
    
    public func addLine(_ line: TerminalLine) {
        lines.append(line)
        count = lines.count
    }
    
    public func clear() {
        lines = [TerminalLine(content: "")]
        count = 1
    }
    
    // MVP: Equatable conformance for onChange modifier
    public static func == (lhs: TerminalBuffer, rhs: TerminalBuffer) -> Bool {
        return lhs.lines == rhs.lines && lhs.count == rhs.count
    }
}

// TerminalSize moved to TerminalTypes.swift to avoid duplication