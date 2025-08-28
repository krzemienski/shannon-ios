//
//  TerminalEmulator.swift
//  ClaudeCode
//
//  Terminal emulation engine
//

import Foundation
import SwiftUI
import Combine

/// Terminal emulator for handling terminal display and input
@MainActor
public class TerminalEmulator: ObservableObject {
    @Published public var buffer: TerminalBuffer
    @Published public var cursor: TerminalCursor
    @Published public var size: TerminalSize
    @Published public var title: String = "Terminal"
    
    // Input/Output streams
    public let inputStream = PassthroughSubject<Data, Never>()
    public let outputStream = PassthroughSubject<Data, Never>()
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(columns: Int = 80, rows: Int = 24) {
        self.buffer = TerminalBuffer()
        self.cursor = TerminalCursor()
        self.size = TerminalSize(columns: columns, rows: rows)
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Process output data
        outputStream
            .sink { [weak self] data in
                self?.processData(data)
            }
            .store(in: &cancellables)
    }
    
    /// Process incoming data from the terminal
    public func processData(_ data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }
        
        for char in string {
            processCharacter(char)
        }
    }
    
    /// Process a single character
    private func processCharacter(_ char: Character) {
        switch char {
        case "\n":
            // New line
            newLine()
        case "\r":
            // Carriage return
            cursor.position.column = 0
        case "\u{1B}":
            // Escape sequence - simplified handling
            // In a full implementation, this would parse ANSI escape codes
            break
        case "\u{7F}", "\u{08}":
            // Backspace
            if cursor.position.column > 0 {
                cursor.position.column -= 1
                updateCharacterAtCursor(" ")
            }
        default:
            // Regular character
            updateCharacterAtCursor(char)
            cursor.position.column += 1
            
            // Wrap if needed
            if cursor.position.column >= size.columns {
                cursor.position.column = 0
                cursor.position.row += 1
            }
        }
    }
    
    /// Update character at cursor position
    private func updateCharacterAtCursor(_ char: Character) {
        ensureLineExists(cursor.position.row)
        
        if cursor.position.row < buffer.lines.count {
            var line = buffer.lines[cursor.position.row]
            
            // Ensure cells array is large enough
            while line.cells.count <= cursor.position.column {
                line.cells.append(TerminalCell())
            }
            
            // Update character
            line.cells[cursor.position.column] = TerminalCell(
                character: char,
                attributes: TerminalAttributes()
            )
            
            // Update text representation
            line.text = String(line.cells.map { $0.character })
            
            buffer.lines[cursor.position.row] = line
        }
    }
    
    /// Ensure line exists at given row
    private func ensureLineExists(_ row: Int) {
        while buffer.lines.count <= row {
            buffer.addLine(TerminalLine())
        }
    }
    
    /// Move to new line
    private func newLine() {
        cursor.position.column = 0
        cursor.position.row += 1
        ensureLineExists(cursor.position.row)
    }
    
    /// Send input to the terminal
    public func sendInput(_ text: String) {
        if let data = text.data(using: .utf8) {
            inputStream.send(data)
            // Echo input locally
            processData(data)
        }
    }
    
    /// Send special key
    public func sendKey(_ key: SpecialKey) {
        let sequence: String
        switch key {
        case .up:
            sequence = "\u{1B}[A"
        case .down:
            sequence = "\u{1B}[B"
        case .left:
            sequence = "\u{1B}[D"
        case .right:
            sequence = "\u{1B}[C"
        case .home:
            sequence = "\u{1B}[H"
        case .end:
            sequence = "\u{1B}[F"
        case .pageUp:
            sequence = "\u{1B}[5~"
        case .pageDown:
            sequence = "\u{1B}[6~"
        case .tab:
            sequence = "\t"
        case .escape:
            sequence = "\u{1B}"
        case .enter:
            sequence = "\n"
        case .backspace:
            sequence = "\u{7F}"
        }
        
        if let data = sequence.data(using: .utf8) {
            inputStream.send(data)
        }
    }
    
    /// Clear the terminal
    public func clear() {
        buffer.clear()
        cursor.position = CursorPosition(row: 0, column: 0)
    }
    
    /// Resize terminal
    public func resize(columns: Int, rows: Int) {
        size = TerminalSize(columns: columns, rows: rows)
    }
    
    /// Get visible content
    public func getVisibleContent() -> [TerminalLine] {
        let startIndex = max(0, buffer.lines.count - size.rows)
        let endIndex = min(buffer.lines.count, startIndex + size.rows)
        
        if startIndex < endIndex {
            return Array(buffer.lines[startIndex..<endIndex])
        }
        return []
    }
    
    /// Get visible lines (compatibility method)
    public func getVisibleLines() -> [TerminalLine] {
        return getVisibleContent()
    }
    
    /// Connect terminal (for compatibility)
    public func connect() {
        // Connection logic would go here
    }
    
    /// Disconnect terminal (for compatibility)
    public func disconnect() {
        // Disconnection logic would go here
    }
}

/// Special keys
public enum SpecialKey {
    case up, down, left, right
    case home, end, pageUp, pageDown
    case tab, escape, enter, backspace
}