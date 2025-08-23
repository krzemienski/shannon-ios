//
//  SSHTerminal.swift
//  ClaudeCode
//
//  Terminal emulation with PTY support for SSH sessions (Tasks 491-495)
//

import Foundation
import SwiftUI
import Combine
import OSLog

/// SSH terminal emulator with PTY support
@MainActor
public final class SSHTerminal: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var terminalBuffer: TerminalBuffer
    @Published public private(set) var cursorPosition: CursorPosition
    @Published public private(set) var isConnected = false
    @Published public private(set) var terminalSize: TerminalSize
    @Published public private(set) var terminalMode: TerminalMode = .normal
    @Published public private(set) var lastError: TerminalError?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHTerminal")
    private var inputBuffer = Data()
    private var outputBuffer = Data()
    private var escapeSequenceParser = ANSIEscapeParser()
    private var inputSubject = PassthroughSubject<String, Never>()
    private var outputSubject = PassthroughSubject<Data, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // Terminal state
    public private(set) var scrollbackBuffer: [TerminalLine] = []
    private var currentAttributes = CharacterAttributes()
    private var savedCursorPosition: CursorPosition?
    private var alternateScreenBuffer: TerminalBuffer?
    private var isAlternateScreen = false
    
    // Configuration
    private let maxScrollbackLines = 10000
    private let tabWidth = 8
    
    // MARK: - Initialization
    
    public init(columns: Int = 80, rows: Int = 24) {
        self.terminalSize = TerminalSize(columns: columns, rows: rows)
        self.terminalBuffer = TerminalBuffer(size: terminalSize)
        self.cursorPosition = CursorPosition(column: 0, row: 0)
        
        setupTerminal()
    }
    
    // MARK: - Public Methods
    
    /// Connect terminal to SSH session
    public func connect() {
        logger.info("Connecting terminal")
        isConnected = true
        clearScreen()
    }
    
    /// Disconnect terminal
    public func disconnect() {
        logger.info("Disconnecting terminal")
        isConnected = false
    }
    
    /// Process input from user
    public func processInput(_ input: String) {
        guard isConnected else { return }
        
        logger.debug("Processing input: \(input.count) characters")
        
        // Handle special keys
        let processedInput = processSpecialKeys(input)
        
        // Send to output
        inputSubject.send(processedInput)
        
        // Echo if in local echo mode
        if terminalMode == .localEcho {
            processOutput(processedInput.data(using: .utf8) ?? Data())
        }
    }
    
    /// Process output from SSH session
    public func processOutput(_ data: Data) {
        guard isConnected else { return }
        
        outputBuffer.append(data)
        
        // Process complete sequences
        while let sequence = extractNextSequence() {
            processSequence(sequence)
        }
        
        // Update display
        objectWillChange.send()
    }
    
    /// Resize terminal
    public func resize(columns: Int, rows: Int) {
        logger.info("Resizing terminal to \(columns)x\(rows)")
        
        let newSize = TerminalSize(columns: columns, rows: rows)
        
        // Resize buffers
        terminalBuffer.resize(to: newSize)
        alternateScreenBuffer?.resize(to: newSize)
        
        // Adjust cursor if needed
        if cursorPosition.column >= columns {
            cursorPosition.column = columns - 1
        }
        if cursorPosition.row >= rows {
            cursorPosition.row = rows - 1
        }
        
        terminalSize = newSize
        
        // Notify session of resize
        outputSubject.send(generateResizeSequence())
    }
    
    /// Clear screen
    public func clearScreen() {
        terminalBuffer.clear()
        cursorPosition = CursorPosition(column: 0, row: 0)
        objectWillChange.send()
    }
    
    /// Clear scrollback buffer
    public func clearScrollback() {
        scrollbackBuffer.removeAll()
        objectWillChange.send()
    }
    
    /// Get visible lines including scrollback
    public func getVisibleLines(scrollOffset: Int = 0) -> [TerminalLine] {
        var lines: [TerminalLine] = []
        
        // Add scrollback lines if scrolled up
        if scrollOffset > 0 {
            let startIndex = max(0, scrollbackBuffer.count - scrollOffset)
            let endIndex = scrollbackBuffer.count
            lines.append(contentsOf: Array(scrollbackBuffer[startIndex..<endIndex]))
        }
        
        // Add current buffer lines
        lines.append(contentsOf: terminalBuffer.lines)
        
        return lines
    }
    
    /// Send control sequence
    public func sendControlSequence(_ sequence: ControlSequence) {
        let data = sequence.data
        outputSubject.send(data)
    }
    
    // MARK: - Input/Output Streams
    
    /// Get input stream for sending data to SSH session
    public var inputStream: AnyPublisher<String, Never> {
        inputSubject.eraseToAnyPublisher()
    }
    
    /// Get output stream for receiving data from SSH session
    public var outputStream: AnyPublisher<Data, Never> {
        outputSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func setupTerminal() {
        // Initialize with empty lines
        terminalBuffer.initialize()
        
        // Set default terminal attributes
        currentAttributes = CharacterAttributes(
            foregroundColor: .default,
            backgroundColor: .default,
            bold: false,
            italic: false,
            underline: false,
            blink: false,
            reverse: false,
            strikethrough: false
        )
    }
    
    private func extractNextSequence() -> TerminalSequence? {
        guard !outputBuffer.isEmpty else { return nil }
        
        // Look for escape sequences
        if outputBuffer.first == 0x1B { // ESC
            return extractEscapeSequence()
        }
        
        // Look for control characters
        if let first = outputBuffer.first, first < 0x20 {
            return extractControlCharacter()
        }
        
        // Extract printable text
        return extractPrintableText()
    }
    
    private func extractEscapeSequence() -> TerminalSequence? {
        // Parse ANSI escape sequence
        let result = escapeSequenceParser.parse(outputBuffer)
        
        switch result {
        case .complete(let sequence, let consumed):
            outputBuffer.removeFirst(consumed)
            return .escape(sequence)
        case .incomplete:
            return nil // Wait for more data
        case .invalid:
            // Remove invalid escape character
            outputBuffer.removeFirst()
            return .text("�") // Replacement character
        }
    }
    
    private func extractControlCharacter() -> TerminalSequence? {
        guard let char = outputBuffer.first else { return nil }
        outputBuffer.removeFirst()
        
        switch char {
        case 0x07: // BEL
            return .control(.bell)
        case 0x08: // BS
            return .control(.backspace)
        case 0x09: // TAB
            return .control(.tab)
        case 0x0A: // LF
            return .control(.lineFeed)
        case 0x0D: // CR
            return .control(.carriageReturn)
        default:
            return nil
        }
    }
    
    private func extractPrintableText() -> TerminalSequence? {
        var text = ""
        
        while let char = outputBuffer.first, char >= 0x20 && char != 0x1B {
            outputBuffer.removeFirst()
            if let scalar = UnicodeScalar(char) {
                text.append(Character(scalar))
            }
        }
        
        return text.isEmpty ? nil : .text(text)
    }
    
    private func processSequence(_ sequence: TerminalSequence) {
        switch sequence {
        case .text(let text):
            insertText(text)
            
        case .control(let control):
            processControlCharacter(control)
            
        case .escape(let escape):
            processEscapeSequence(escape)
        }
    }
    
    private func insertText(_ text: String) {
        for char in text {
            // Insert character at cursor position
            terminalBuffer.setCharacter(
                at: cursorPosition,
                character: char,
                attributes: currentAttributes
            )
            
            // Move cursor forward
            cursorPosition.column += 1
            
            // Wrap to next line if needed
            if cursorPosition.column >= terminalSize.columns {
                cursorPosition.column = 0
                cursorPosition.row += 1
                
                // Scroll if at bottom
                if cursorPosition.row >= terminalSize.rows {
                    scrollUp()
                    cursorPosition.row = terminalSize.rows - 1
                }
            }
        }
    }
    
    private func processControlCharacter(_ control: ControlCharacter) {
        switch control {
        case .bell:
            // Play bell sound or visual indicator
            logger.debug("Bell")
            
        case .backspace:
            if cursorPosition.column > 0 {
                cursorPosition.column -= 1
            }
            
        case .tab:
            // Move to next tab stop
            let nextTab = ((cursorPosition.column / tabWidth) + 1) * tabWidth
            cursorPosition.column = min(nextTab, terminalSize.columns - 1)
            
        case .lineFeed:
            cursorPosition.row += 1
            if cursorPosition.row >= terminalSize.rows {
                scrollUp()
                cursorPosition.row = terminalSize.rows - 1
            }
            
        case .carriageReturn:
            cursorPosition.column = 0
        }
    }
    
    private func processEscapeSequence(_ sequence: ANSIEscapeSequence) {
        switch sequence {
        case .cursorUp(let n):
            cursorPosition.row = max(0, cursorPosition.row - n)
            
        case .cursorDown(let n):
            cursorPosition.row = min(terminalSize.rows - 1, cursorPosition.row + n)
            
        case .cursorForward(let n):
            cursorPosition.column = min(terminalSize.columns - 1, cursorPosition.column + n)
            
        case .cursorBackward(let n):
            cursorPosition.column = max(0, cursorPosition.column - n)
            
        case .cursorPosition(let row, let col):
            cursorPosition.row = min(terminalSize.rows - 1, max(0, row - 1))
            cursorPosition.column = min(terminalSize.columns - 1, max(0, col - 1))
            
        case .eraseDisplay(let mode):
            processEraseDisplay(mode)
            
        case .eraseLine(let mode):
            processEraseLine(mode)
            
        case .setGraphics(let params):
            processGraphicsParameters(params)
            
        case .saveCursor:
            savedCursorPosition = cursorPosition
            
        case .restoreCursor:
            if let saved = savedCursorPosition {
                cursorPosition = saved
            }
            
        case .alternateScreen(let enable):
            if enable {
                enterAlternateScreen()
            } else {
                exitAlternateScreen()
            }
            
        case .setScrollRegion(let top, let bottom):
            terminalBuffer.setScrollRegion(top: top, bottom: bottom)
            
        default:
            logger.debug("Unhandled escape sequence: \(sequence)")
        }
    }
    
    private func processEraseDisplay(_ mode: EraseMode) {
        switch mode {
        case .toEnd:
            // Erase from cursor to end of display
            terminalBuffer.eraseFromCursor(cursorPosition, toEnd: true)
            
        case .toBeginning:
            // Erase from beginning to cursor
            terminalBuffer.eraseToCursor(cursorPosition, fromBeginning: true)
            
        case .all:
            // Erase entire display
            terminalBuffer.clear()
        }
    }
    
    private func processEraseLine(_ mode: EraseMode) {
        switch mode {
        case .toEnd:
            terminalBuffer.eraseLineFromCursor(cursorPosition, toEnd: true)
            
        case .toBeginning:
            terminalBuffer.eraseLineToCursor(cursorPosition, fromBeginning: true)
            
        case .all:
            terminalBuffer.eraseLine(at: cursorPosition.row)
        }
    }
    
    private func processGraphicsParameters(_ params: [Int]) {
        for param in params {
            switch param {
            case 0: // Reset
                currentAttributes = CharacterAttributes()
            case 1: // Bold
                currentAttributes.bold = true
            case 3: // Italic
                currentAttributes.italic = true
            case 4: // Underline
                currentAttributes.underline = true
            case 5: // Blink
                currentAttributes.blink = true
            case 7: // Reverse
                currentAttributes.reverse = true
            case 9: // Strikethrough
                currentAttributes.strikethrough = true
            case 30...37: // Foreground color
                currentAttributes.foregroundColor = .ansi(param - 30)
            case 40...47: // Background color
                currentAttributes.backgroundColor = .ansi(param - 40)
            case 90...97: // Bright foreground color
                currentAttributes.foregroundColor = .ansiBright(param - 90)
            case 100...107: // Bright background color
                currentAttributes.backgroundColor = .ansiBright(param - 100)
            default:
                break
            }
        }
    }
    
    private func scrollUp() {
        // Move top line to scrollback
        if let firstLine = terminalBuffer.lines.first {
            scrollbackBuffer.append(firstLine)
            
            // Limit scrollback size
            if scrollbackBuffer.count > maxScrollbackLines {
                scrollbackBuffer.removeFirst()
            }
        }
        
        // Scroll buffer up
        terminalBuffer.scrollUp()
    }
    
    private func enterAlternateScreen() {
        if !isAlternateScreen {
            alternateScreenBuffer = terminalBuffer
            terminalBuffer = TerminalBuffer(size: terminalSize)
            terminalBuffer.initialize()
            isAlternateScreen = true
        }
    }
    
    private func exitAlternateScreen() {
        if isAlternateScreen, let mainBuffer = alternateScreenBuffer {
            terminalBuffer = mainBuffer
            alternateScreenBuffer = nil
            isAlternateScreen = false
        }
    }
    
    private func processSpecialKeys(_ input: String) -> String {
        // Convert special keys to escape sequences
        var processed = ""
        
        for char in input {
            switch char {
            case "\u{001B}": // ESC
                processed += "\u{001B}"
            case "\n": // Enter
                processed += "\r"
            case "\u{007F}": // Delete
                processed += "\u{0008}"
            default:
                processed.append(char)
            }
        }
        
        return processed
    }
    
    private func generateResizeSequence() -> Data {
        // Generate TIOCSWINSZ ioctl sequence
        var data = Data()
        
        // Window size structure
        data.append(contentsOf: withUnsafeBytes(of: UInt16(terminalSize.rows)) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(terminalSize.columns)) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(0)) { Array($0) }) // x pixels
        data.append(contentsOf: withUnsafeBytes(of: UInt16(0)) { Array($0) }) // y pixels
        
        return data
    }
}

// MARK: - Supporting Types

/// Terminal buffer for storing screen content
public class TerminalBuffer {
    public var lines: [TerminalLine]
    public var size: TerminalSize
    private var scrollTop: Int = 0
    private var scrollBottom: Int?
    
    init(size: TerminalSize) {
        self.size = size
        self.lines = []
    }
    
    func initialize() {
        lines = (0..<size.rows).map { _ in
            TerminalLine(characters: Array(repeating: TerminalCharacter.empty, count: size.columns))
        }
    }
    
    func resize(to newSize: TerminalSize) {
        // Adjust number of lines
        while lines.count < newSize.rows {
            lines.append(TerminalLine(characters: Array(repeating: .empty, count: newSize.columns)))
        }
        while lines.count > newSize.rows {
            lines.removeLast()
        }
        
        // Adjust line widths
        for i in 0..<lines.count {
            while lines[i].characters.count < newSize.columns {
                lines[i].characters.append(.empty)
            }
            while lines[i].characters.count > newSize.columns {
                lines[i].characters.removeLast()
            }
        }
        
        size = newSize
    }
    
    func clear() {
        initialize()
    }
    
    func setCharacter(at position: CursorPosition, character: Character, attributes: CharacterAttributes) {
        guard position.row < lines.count && position.column < size.columns else { return }
        
        lines[position.row].characters[position.column] = TerminalCharacter(
            character: character,
            attributes: attributes
        )
    }
    
    func scrollUp() {
        let bottom = scrollBottom ?? (size.rows - 1)
        
        if scrollTop < lines.count && bottom < lines.count {
            lines.remove(at: scrollTop)
            lines.insert(
                TerminalLine(characters: Array(repeating: .empty, count: size.columns)),
                at: bottom
            )
        }
    }
    
    func setScrollRegion(top: Int, bottom: Int) {
        scrollTop = max(0, min(top, size.rows - 1))
        scrollBottom = max(scrollTop, min(bottom, size.rows - 1))
    }
    
    func eraseFromCursor(_ position: CursorPosition, toEnd: Bool) {
        guard position.row < lines.count else { return }
        
        if toEnd {
            // Erase from cursor to end of line
            for col in position.column..<size.columns {
                lines[position.row].characters[col] = .empty
            }
            // Erase all lines below
            for row in (position.row + 1)..<lines.count {
                lines[row].characters = Array(repeating: .empty, count: size.columns)
            }
        }
    }
    
    func eraseToCursor(_ position: CursorPosition, fromBeginning: Bool) {
        guard position.row < lines.count else { return }
        
        if fromBeginning {
            // Erase all lines above
            for row in 0..<position.row {
                lines[row].characters = Array(repeating: .empty, count: size.columns)
            }
            // Erase from beginning to cursor on current line
            for col in 0...position.column {
                lines[position.row].characters[col] = .empty
            }
        }
    }
    
    func eraseLineFromCursor(_ position: CursorPosition, toEnd: Bool) {
        guard position.row < lines.count else { return }
        
        if toEnd {
            for col in position.column..<size.columns {
                lines[position.row].characters[col] = .empty
            }
        }
    }
    
    func eraseLineToCursor(_ position: CursorPosition, fromBeginning: Bool) {
        guard position.row < lines.count else { return }
        
        if fromBeginning {
            for col in 0...position.column {
                lines[position.row].characters[col] = .empty
            }
        }
    }
    
    func eraseLine(at row: Int) {
        guard row < lines.count else { return }
        lines[row].characters = Array(repeating: .empty, count: size.columns)
    }
}

/// Terminal line
public struct TerminalLine {
    public var characters: [TerminalCharacter]
    
    public var text: String {
        characters.map { String($0.character) }.joined()
    }
}

/// Terminal character with attributes
public struct TerminalCharacter {
    public let character: Character
    public let attributes: CharacterAttributes
    
    public static let empty = TerminalCharacter(character: " ", attributes: CharacterAttributes())
}

/// Character attributes
public struct CharacterAttributes: Equatable {
    public var foregroundColor: TerminalColor = .default
    public var backgroundColor: TerminalColor = .default
    public var bold: Bool = false
    public var italic: Bool = false
    public var underline: Bool = false
    public var blink: Bool = false
    public var reverse: Bool = false
    public var strikethrough: Bool = false
}

/// Terminal color
public enum TerminalColor: Equatable {
    case `default`
    case ansi(Int) // 0-7
    case ansiBright(Int) // 0-7
    case color256(Int) // 0-255
    case rgb(r: Int, g: Int, b: Int)
    
    public var swiftUIColor: Color {
        switch self {
        case .default:
            return .primary
        case .ansi(let index):
            return ansiColors[index]
        case .ansiBright(let index):
            return ansiBrightColors[index]
        case .color256(let index):
            return color256Palette[index]
        case .rgb(let r, let g, let b):
            return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        }
    }
    
    private var ansiColors: [Color] {
        [.black, .red, .green, .yellow, .blue, .purple, .cyan, .gray]
    }
    
    private var ansiBrightColors: [Color] {
        [.gray, .red, .green, .yellow, .blue, .purple, .cyan, .white]
    }
    
    private var color256Palette: [Color] {
        // Simplified - would have full 256 color palette
        Array(repeating: .gray, count: 256)
    }
}

/// Cursor position
public struct CursorPosition: Equatable {
    public var column: Int
    public var row: Int
}

/// Terminal size
public struct TerminalSize: Equatable {
    public let columns: Int
    public let rows: Int
}

/// Terminal mode
public enum TerminalMode {
    case normal
    case localEcho
    case raw
    case application
}

/// Terminal sequence types
enum TerminalSequence {
    case text(String)
    case control(ControlCharacter)
    case escape(ANSIEscapeSequence)
}

/// Control characters
enum ControlCharacter {
    case bell
    case backspace
    case tab
    case lineFeed
    case carriageReturn
}

/// Control sequences
public enum ControlSequence {
    case up
    case down
    case left
    case right
    case home
    case end
    case pageUp
    case pageDown
    case function(Int)
    
    var data: Data {
        switch self {
        case .up:
            return Data([0x1B, 0x5B, 0x41]) // ESC[A
        case .down:
            return Data([0x1B, 0x5B, 0x42]) // ESC[B
        case .right:
            return Data([0x1B, 0x5B, 0x43]) // ESC[C
        case .left:
            return Data([0x1B, 0x5B, 0x44]) // ESC[D
        case .home:
            return Data([0x1B, 0x5B, 0x48]) // ESC[H
        case .end:
            return Data([0x1B, 0x5B, 0x46]) // ESC[F
        case .pageUp:
            return Data([0x1B, 0x5B, 0x35, 0x7E]) // ESC[5~
        case .pageDown:
            return Data([0x1B, 0x5B, 0x36, 0x7E]) // ESC[6~
        case .function(let n):
            // F1-F12
            let seq = [0x1B, 0x5B, 0x31, UInt8(0x30 + n), 0x7E]
            return Data(seq)
        }
    }
}

/// ANSI escape sequences
enum ANSIEscapeSequence {
    case cursorUp(Int)
    case cursorDown(Int)
    case cursorForward(Int)
    case cursorBackward(Int)
    case cursorPosition(row: Int, column: Int)
    case eraseDisplay(EraseMode)
    case eraseLine(EraseMode)
    case setGraphics([Int])
    case saveCursor
    case restoreCursor
    case alternateScreen(Bool)
    case setScrollRegion(top: Int, bottom: Int)
    case unknown(String)
}

/// Erase modes
enum EraseMode {
    case toEnd
    case toBeginning
    case all
}

/// ANSI escape sequence parser
class ANSIEscapeParser {
    enum ParseResult {
        case complete(ANSIEscapeSequence, consumed: Int)
        case incomplete
        case invalid
    }
    
    func parse(_ data: Data) -> ParseResult {
        guard data.count >= 2, data[0] == 0x1B else {
            return .invalid
        }
        
        // CSI sequences (ESC[)
        if data[1] == 0x5B {
            return parseCSI(data)
        }
        
        // Other escape sequences
        return .incomplete
    }
    
    private func parseCSI(_ data: Data) -> ParseResult {
        // Parse CSI sequence (ESC[ ... letter)
        var index = 2
        var params: [Int] = []
        var currentParam = ""
        
        while index < data.count {
            let byte = data[index]
            
            if byte >= 0x30 && byte <= 0x39 { // Digit
                currentParam.append(Character(UnicodeScalar(byte)))
            } else if byte == 0x3B { // Semicolon
                if let param = Int(currentParam) {
                    params.append(param)
                }
                currentParam = ""
            } else if byte >= 0x40 && byte <= 0x7E { // Final byte
                if !currentParam.isEmpty, let param = Int(currentParam) {
                    params.append(param)
                }
                
                let sequence = parseCSISequence(byte, params: params)
                return .complete(sequence, consumed: index + 1)
            } else {
                return .invalid
            }
            
            index += 1
        }
        
        return .incomplete
    }
    
    private func parseCSISequence(_ finalByte: UInt8, params: [Int]) -> ANSIEscapeSequence {
        let n = params.first ?? 1
        
        switch Character(UnicodeScalar(finalByte)) {
        case "A": return .cursorUp(n)
        case "B": return .cursorDown(n)
        case "C": return .cursorForward(n)
        case "D": return .cursorBackward(n)
        case "H", "f":
            let row = params.first ?? 1
            let col = params.count > 1 ? params[1] : 1
            return .cursorPosition(row: row, column: col)
        case "J":
            let mode = params.first ?? 0
            return .eraseDisplay(eraseMode(from: mode))
        case "K":
            let mode = params.first ?? 0
            return .eraseLine(eraseMode(from: mode))
        case "m":
            return .setGraphics(params.isEmpty ? [0] : params)
        case "s":
            return .saveCursor
        case "u":
            return .restoreCursor
        case "r":
            let top = params.first ?? 1
            let bottom = params.count > 1 ? params[1] : 24
            return .setScrollRegion(top: top, bottom: bottom)
        default:
            return .unknown(String(finalByte))
        }
    }
    
    private func eraseMode(from param: Int) -> EraseMode {
        switch param {
        case 0: return .toEnd
        case 1: return .toBeginning
        case 2: return .all
        default: return .toEnd
        }
    }
}

/// Terminal errors
public enum TerminalError: LocalizedError {
    case notConnected
    case invalidInput
    case resizeFailed
    case bufferOverflow
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Terminal not connected"
        case .invalidInput:
            return "Invalid terminal input"
        case .resizeFailed:
            return "Failed to resize terminal"
        case .bufferOverflow:
            return "Terminal buffer overflow"
        }
    }
}