//
//  TerminalSessionView.swift
//  ClaudeCode
//
//  Individual terminal session view with full emulation support
//

import SwiftUI
import Combine

/// View for displaying a single terminal session
public struct TerminalSessionView: View {
    let session: SSHSession
    let searchText: String
    
    @StateObject private var emulator = TerminalEmulator()
    @State private var inputText = ""
    @State private var commandBuffer = ""
    @FocusState private var isInputFocused: Bool
    @State private var scrollToBottom = true
    
    @EnvironmentObject private var sessionManager: SSHSessionManager
    
    // MARK: - Body
    
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Terminal display
                terminalDisplay(size: geometry.size)
                
                // Input bar
                inputBar
            }
        }
        .background(Color.black)
        .onAppear {
            setupSession()
        }
    }
    
    // MARK: - Terminal Display
    
    private func terminalDisplay(size: CGSize) -> some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Terminal content
                    terminalContent
                    
                    // Cursor overlay
                    cursorOverlay
                }
                .frame(
                    minWidth: size.width,
                    minHeight: size.height - 50, // Account for input bar
                    alignment: .topLeading
                )
                .id("terminal_content")
            }
            .background(Color.black)
            .onChange(of: emulator.cursor.position) { _ in
                if scrollToBottom {
                    withAnimation {
                        proxy.scrollTo("terminal_content", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var terminalContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(emulator.getVisibleContent().enumerated()), id: \.offset) { _, line in
                TerminalLineView(line: line, searchText: searchText)
            }
        }
        .padding(8)
    }
    
    private var cursorOverlay: some View {
        TerminalCursorView(cursor: emulator.cursor)
            .offset(
                x: CGFloat(emulator.cursor.position.column) * characterWidth + 8,
                y: CGFloat(emulator.cursor.position.row) * lineHeight + 8
            )
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            // Input field
            TextField("", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Theme.foreground)
                .focused($isInputFocused)
                .onSubmit {
                    sendInput()
                }
            
            // Special keys
            HStack(spacing: 8) {
                // Tab key
                Button(action: {
                    emulator.sendKey(.tab)
                }) {
                    Text("TAB")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.card)
                        .cornerRadius(4)
                }
                
                // Ctrl key
                Button(action: {
                    // Handle Ctrl combinations
                }) {
                    Text("CTRL")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.card)
                        .cornerRadius(4)
                }
                
                // Escape key
                Button(action: {
                    emulator.sendKey(.escape)
                }) {
                    Text("ESC")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.card)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Theme.card)
    }
    
    // MARK: - Helpers
    
    private var characterWidth: CGFloat {
        // Calculate based on font size
        return 8.4 // Approximate for SF Mono at default size
    }
    
    private var lineHeight: CGFloat {
        // Calculate based on font size
        return 20 // Approximate line height
    }
    
    private func setupSession() {
        guard let service = sessionManager.getService(for: session.id) else { return }
        
        // Connect terminal emulator to SSH session
        Task {
            do {
                let shellSession = try await service.createShellSession()
                
                // Pipe output to emulator
                shellSession.outputStream
                    .sink { data in
                        Task { @MainActor in
                            emulator.processData(data)
                        }
                    }
                    .store(in: &shellSession.cancellables)
                
                // Pipe input from emulator to shell
                emulator.inputStream
                    .sink { data in
                        Task {
                            try? await shellSession.write(data)
                        }
                    }
                    .store(in: &shellSession.cancellables)
                
                isInputFocused = true
                
            } catch {
                print("Failed to create shell session: \(error)")
            }
        }
    }
    
    private func sendInput() {
        guard !inputText.isEmpty else { return }
        
        // Send to terminal emulator
        emulator.sendInput(inputText + "\n")
        
        // Clear input
        inputText = ""
    }
}

// MARK: - Terminal Line View

struct TerminalLineView: View {
    let line: TerminalLine
    let searchText: String
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(line.cells.enumerated()), id: \.offset) { _, cell in
                TerminalCellView(cell: cell, isHighlighted: isHighlighted(cell))
            }
            Spacer()
        }
        .frame(height: 20)
    }
    
    private func isHighlighted(_ cell: TerminalCell) -> Bool {
        guard !searchText.isEmpty else { return false }
        return String(cell.character).lowercased().contains(searchText.lowercased())
    }
}

// MARK: - Terminal Cell View

struct TerminalCellView: View {
    let cell: TerminalCell
    let isHighlighted: Bool
    
    var body: some View {
        Text(String(cell.character))
            .font(.system(.body, design: .monospaced))
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .bold(cell.attributes.bold)
            .italic(cell.attributes.italic)
            .underline(cell.attributes.underline)
            .strikethrough(cell.attributes.strikethrough)
    }
    
    private var foregroundColor: Color {
        if isHighlighted {
            return .yellow
        }
        
        if cell.attributes.reverse {
            return backgroundColor
        }
        
        return cell.attributes.foreground.toColor()
    }
    
    private var backgroundColor: Color {
        if cell.attributes.reverse {
            return cell.attributes.foreground.toColor()
        }
        
        return cell.attributes.background.toColor()
    }
}

// MARK: - Terminal Cursor View

struct TerminalCursorView: View {
    let cursor: TerminalCursor
    @State private var isBlinking = false
    
    var body: some View {
        Rectangle()
            .fill(Theme.primary)
            .frame(width: cursorWidth, height: 20)
            .opacity(cursor.visible && (!cursor.blinking || isBlinking) ? 1 : 0)
            .animation(cursor.blinking ? .easeInOut(duration: 0.5).repeatForever() : .none, value: isBlinking)
            .onAppear {
                if cursor.blinking {
                    isBlinking = true
                }
            }
    }
    
    private var cursorWidth: CGFloat {
        switch cursor.style {
        case .block:
            return 8.4
        case .underline:
            return 8.4
        case .bar:
            return 2
        }
    }
}

// MARK: - Color Extension

extension TerminalColor {
    func toColor() -> Color {
        switch self {
        case .default:
            return Theme.foreground
        case .ansi(let index):
            return ansiColor(index)
        case .ansiBright(let index):
            return ansiBrightColor(index)
        case .palette(let index):
            return paletteColor(index)
        case .rgb(let r, let g, let b):
            return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        }
    }
    
    private func ansiColor(_ index: Int) -> Color {
        switch index {
        case 0: return .black
        case 1: return .red
        case 2: return .green
        case 3: return .yellow
        case 4: return .blue
        case 5: return .purple
        case 6: return .cyan
        case 7: return .white
        default: return .white
        }
    }
    
    private func ansiBrightColor(_ index: Int) -> Color {
        switch index {
        case 0: return Color.gray
        case 1: return Color.red.opacity(1.0)
        case 2: return Color.green.opacity(1.0)
        case 3: return Color.yellow.opacity(1.0)
        case 4: return Color.blue.opacity(1.0)
        case 5: return Color.purple.opacity(1.0)
        case 6: return Color.cyan.opacity(1.0)
        case 7: return Color.white
        default: return .white
        }
    }
    
    private func paletteColor(_ index: Int) -> Color {
        // 256 color palette implementation
        // This is a simplified version
        let grayscale = Double(index) / 255.0
        return Color(white: grayscale)
    }
}