//
//  TerminalTypes.swift
//  ClaudeCode
//
//  Terminal emulation types and models
//

import Foundation
import SwiftUI

/// Represents a single line in the terminal
public struct TerminalLine: Identifiable, Equatable {
    public let id = UUID()
    public var text: String
    public var cells: [TerminalCell]
    public var wrapped: Bool
    
    public init(text: String = "", cells: [TerminalCell] = [], wrapped: Bool = false) {
        self.text = text
        self.cells = cells
        self.wrapped = wrapped
    }
    
    public static func == (lhs: TerminalLine, rhs: TerminalLine) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text && lhs.wrapped == rhs.wrapped
    }
}

/// Represents a single character cell in the terminal
public struct TerminalCell: Equatable {
    public var character: Character
    public var attributes: TerminalAttributes
    
    public init(character: Character = " ", attributes: TerminalAttributes = TerminalAttributes()) {
        self.character = character
        self.attributes = attributes
    }
}

/// Character attributes for terminal display
public struct TerminalAttributes: Equatable {
    public var foreground: TerminalColor = .default
    public var background: TerminalColor = .default
    public var bold: Bool = false
    public var italic: Bool = false
    public var underline: Bool = false
    public var strikethrough: Bool = false
    public var reverse: Bool = false
    public var dim: Bool = false
    public var blink: Bool = false
    
    public init() {}
}

/// Terminal color representation
public enum TerminalColor: Equatable {
    case `default`
    case ansi(Int)
    case ansiBright(Int)
    case palette(Int)
    case rgb(UInt8, UInt8, UInt8)
}

/// Represents a single character in the terminal (simplified)
public struct TerminalCharacter: Equatable {
    public var char: Character
    public var style: TerminalStyle
    
    public init(char: Character = " ", style: TerminalStyle = TerminalStyle()) {
        self.char = char
        self.style = style
    }
}

/// Terminal character style
public struct TerminalStyle: Equatable {
    public var foregroundColor: Color = Theme.foreground
    public var backgroundColor: Color = .clear
    public var isBold: Bool = false
    public var isItalic: Bool = false
    public var isUnderline: Bool = false
    
    public init() {}
}

/// Cursor position in the terminal
public struct CursorPosition: Equatable {
    public var row: Int
    public var column: Int
    
    public init(row: Int = 0, column: Int = 0) {
        self.row = row
        self.column = column
    }
}

/// Terminal cursor representation
public struct TerminalCursor: Equatable {
    public var position: CursorPosition
    public var visible: Bool
    public var blinking: Bool
    public var style: CursorStyle
    
    public enum CursorStyle: String, CaseIterable {
        case block
        case underline
        case bar
    }
    
    public init(
        position: CursorPosition = CursorPosition(),
        visible: Bool = true,
        blinking: Bool = true,
        style: CursorStyle = .block
    ) {
        self.position = position
        self.visible = visible
        self.blinking = blinking
        self.style = style
    }
}

/// Terminal size
public struct TerminalSize: Equatable {
    public let columns: Int
    public let rows: Int
    
    public init(columns: Int = 80, rows: Int = 24) {
        self.columns = columns
        self.rows = rows
    }
}

/// Terminal buffer for storing lines
public class TerminalBuffer: ObservableObject {
    @Published public var lines: [TerminalLine] = []
    @Published public var scrollbackLines: [TerminalLine] = []
    public var maxScrollback: Int = 10000
    
    public init() {
        // Initialize with empty line
        lines.append(TerminalLine())
    }
    
    public func addLine(_ line: TerminalLine) {
        lines.append(line)
        
        // Manage scrollback
        if lines.count > 100 { // Keep 100 visible lines
            let overflow = lines.prefix(lines.count - 100)
            scrollbackLines.append(contentsOf: overflow)
            lines.removeFirst(lines.count - 100)
            
            // Trim scrollback if needed
            if scrollbackLines.count > maxScrollback {
                scrollbackLines.removeFirst(scrollbackLines.count - maxScrollback)
            }
        }
    }
    
    public func clear() {
        lines = [TerminalLine()]
        scrollbackLines = []
    }
    
    public func getAllLines() -> [TerminalLine] {
        return scrollbackLines + lines
    }
}