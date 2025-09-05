//
//  TerminalEmulatorView.swift
//  ClaudeCode
//
//  ANSI terminal emulation component (Tasks 606-610)
//

import SwiftUI
import Combine

/// Terminal emulator view with ANSI escape sequence support
public struct TerminalEmulatorView: View {
    @ObservedObject var terminal: SSHTerminal
    @Binding var scrollToBottom: Bool
    let searchText: String
    let onResize: (TerminalSize) -> Void
    
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var fontSize: CGFloat = 13
    @State private var cellSize: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    @State private var selection: EmulatorSelection?
    @State private var hoveredPosition: EmulatorPosition?
    
    @AppStorage("terminal_font_size") private var storedFontSize: Double = 13
    @AppStorage("terminal_cursor_blink") private var cursorBlink: Bool = true
    @AppStorage("terminal_show_scrollbar") private var showScrollbar: Bool = true
    
    private let fontName = "SF Mono"
    
    // MARK: - Body Sub-components (MVP: Breaking up complex expression for compiler)
    
    @ViewBuilder
    private var terminalLines: some View {
        ForEach(Array(terminal.getVisibleLines().enumerated()), id: \.offset) { index, line in
            EmulatorLineView(
                line: line,
                lineNumber: index,
                fontSize: fontSize,
                fontName: fontName,
                cursorPosition: terminal.cursorPosition,
                selection: selection,
                searchText: searchText,
                onHover: { position in
                    hoveredPosition = position
                }
            )
            .id(index)
        }
    }
    
    @ViewBuilder
    private var emptyCursor: some View {
        if terminal.cursorPosition.row >= terminal.terminalBuffer.lines.count {
            EmulatorCursorView(
                position: terminal.cursorPosition,
                fontSize: fontSize,
                blink: cursorBlink
            )
        }
    }
    
    @ViewBuilder
    private func terminalContent(for geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            terminalLines
            emptyCursor
        }
        .background(
            GeometryReader { contentGeometry in
                Color.clear
                    .onAppear {
                        calculateCellSize()
                        updateTerminalSize(geometry.frame(in: .local).size)
                    }
                    .onChange(of: geometry.frame(in: .local).size) { newSize in
                        updateTerminalSize(newSize)
                    }
            }
        )
        .padding(8)
    }
    
    @ViewBuilder
    private func scrollContent(for geometry: GeometryProxy) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: showScrollbar) {
            terminalContent(for: geometry)
        }
        .background(terminalBackground)
        .onAppear {
            fontSize = CGFloat(storedFontSize)
        }
        .onChange(of: scrollToBottom) { shouldScroll in
            if shouldScroll {
                scrollToBottom(animated: true)
            }
        }
        .onChange(of: terminal.terminalBuffer) { _ in
            if scrollToBottom {
                scrollToBottom(animated: false)
            }
        }
        .onTapGesture { location in
            handleTap(at: location)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    handleDragSelection(value)
                }
                .onEnded { _ in
                    finalizeSelection()
                }
        )
    }
    
    @ViewBuilder
    private var scrollIndicatorOverlay: some View {
        if !showScrollbar {
            ScrollPositionIndicator(
                visibleLines: terminal.getVisibleLines().count,
                totalLines: terminal.terminalBuffer.lines.count + terminal.scrollbackBuffer.count
            )
            .padding()
        }
    }
    
    @ViewBuilder
    private var sizeIndicatorOverlay: some View {
        if viewSize != .zero {
            TerminalSizeIndicator(size: terminal.terminalSize)
                .padding()
                .transition(.opacity)
        }
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                scrollContent(for: geometry)
                    .onAppear {
                        scrollViewProxy = proxy
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            scrollIndicatorOverlay
        }
        .overlay(alignment: .bottomTrailing) {
            sizeIndicatorOverlay
        }
        .contextMenu {
            terminalContextMenu
        }
    }
    
    // MARK: - Terminal Background
    
    private var terminalBackground: some View {
        ZStack {
            // Base background
            Color.black.opacity(0.95)
            
            // Subtle scan line effect
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.01),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Terminal glow effect
            RadialGradient(
                colors: [
                    Theme.primary.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Context Menu
    
    private var terminalContextMenu: some View {
        Group {
            Button("Copy") {
                copySelection()
            }
            .disabled(selection == nil)
            
            Button("Paste") {
                pasteFromClipboard()
            }
            
            Divider()
            
            Button("Select All") {
                selectAll()
            }
            
            Button("Clear Selection") {
                selection = nil
            }
            .disabled(selection == nil)
            
            Divider()
            
            Button("Clear Terminal") {
                terminal.clearScreen()
            }
            
            Button("Clear Scrollback") {
                terminal.clearScrollback()
            }
            
            Divider()
            
            Menu("Font Size") {
                Button("Increase") {
                    increaseFontSize()
                }
                
                Button("Decrease") {
                    decreaseFontSize()
                }
                
                Button("Reset") {
                    resetFontSize()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateCellSize() {
        let font = Font.system(size: fontSize, design: .monospaced)
        let uiFont = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: uiFont
        ]
        
        let size = "W".size(withAttributes: attributes)
        cellSize = CGSize(
            width: size.width,
            height: size.height * 1.2 // Line height multiplier
        )
    }
    
    private func updateTerminalSize(_ size: CGSize) {
        guard cellSize.width > 0 && cellSize.height > 0 else { return }
        
        let columns = Int((size.width - 16) / cellSize.width) // Account for padding
        let rows = Int((size.height - 16) / cellSize.height)
        
        let newSize = TerminalSize(columns: max(20, columns), rows: max(5, rows))
        
        if newSize != terminal.terminalSize {
            viewSize = size
            onResize(newSize)
            
            // Hide size indicator after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    viewSize = .zero
                }
            }
        }
    }
    
    private func scrollToBottom(animated: Bool) {
        guard let proxy = scrollViewProxy else { return }
        let lastLine = terminal.getVisibleLines().count - 1
        
        withAnimation(animated ? .easeInOut(duration: 0.2) : nil) {
            proxy.scrollTo(lastLine, anchor: .bottom)
        }
    }
    
    private func handleTap(at location: CGPoint) {
        // Convert tap location to terminal position
        let column = Int(location.x / cellSize.width)
        let row = Int(location.y / cellSize.height)
        
        let position = EmulatorPosition(row: row, column: column)
        
        // Update cursor position if in input mode
        if terminal.terminalMode == .normal {
            // TODO: Move cursor to position
        }
    }
    
    private func handleDragSelection(_ value: DragGesture.Value) {
        let startColumn = Int(value.startLocation.x / cellSize.width)
        let startRow = Int(value.startLocation.y / cellSize.height)
        let endColumn = Int(value.location.x / cellSize.width)
        let endRow = Int(value.location.y / cellSize.height)
        
        selection = EmulatorSelection(
            start: EmulatorPosition(row: startRow, column: startColumn),
            end: EmulatorPosition(row: endRow, column: endColumn)
        )
    }
    
    private func finalizeSelection() {
        // Normalize selection (ensure start comes before end)
        if let sel = selection {
            if sel.end.row < sel.start.row ||
               (sel.end.row == sel.start.row && sel.end.column < sel.start.column) {
                selection = EmulatorSelection(start: sel.end, end: sel.start)
            }
        }
    }
    
    private func copySelection() {
        guard let selection = selection else { return }
        
        var text = ""
        let lines = terminal.getVisibleLines()
        
        for row in selection.start.row...selection.end.row {
            guard row < lines.count else { continue }
            
            let line = lines[row]
            let startCol = row == selection.start.row ? selection.start.column : 0
            let endCol = row == selection.end.row ? selection.end.column : line.characters.count - 1
            
            for col in startCol...endCol {
                if col < line.characters.count {
                    text.append(line.characters[col].character)
                }
            }
            
            if row < selection.end.row {
                text.append("\n")
            }
        }
        
        UIPasteboard.general.string = text
    }
    
    private func pasteFromClipboard() {
        if let text = UIPasteboard.general.string {
            terminal.processInput(text)
        }
    }
    
    private func selectAll() {
        let lines = terminal.getVisibleLines()
        guard !lines.isEmpty else { return }
        
        let lastLine = lines[lines.count - 1]
        selection = EmulatorSelection(
            start: EmulatorPosition(row: 0, column: 0),
            end: EmulatorPosition(row: lines.count - 1, column: lastLine.characters.count - 1)
        )
    }
    
    private func increaseFontSize() {
        fontSize = min(fontSize + 1, 24)
        storedFontSize = Double(fontSize)
        calculateCellSize()
    }
    
    private func decreaseFontSize() {
        fontSize = max(fontSize - 1, 9)
        storedFontSize = Double(fontSize)
        calculateCellSize()
    }
    
    private func resetFontSize() {
        fontSize = 13
        storedFontSize = 13
        calculateCellSize()
    }
}

/// Terminal line view
struct EmulatorLineView: View {
    let line: TerminalLine
    let lineNumber: Int
    let fontSize: CGFloat
    let fontName: String
    let cursorPosition: CursorPosition
    let selection: EmulatorSelection?
    let searchText: String
    let onHover: (EmulatorPosition?) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(line.characters.enumerated()), id: \.offset) { column, character in
                EmulatorCharacterView(
                    character: character,
                    position: EmulatorPosition(row: lineNumber, column: column),
                    fontSize: fontSize,
                    fontName: fontName,
                    isSelected: isSelected(row: lineNumber, column: column),
                    isHighlighted: isHighlighted(character: character),
                    hasCursor: cursorPosition.row == lineNumber && cursorPosition.column == column
                )
                .onHover { hovering in
                    onHover(hovering ? EmulatorPosition(row: lineNumber, column: column) : nil)
                }
            }
            
            // Fill remaining space
            Spacer(minLength: 0)
        }
    }
    
    private func isSelected(row: Int, column: Int) -> Bool {
        guard let selection = selection else { return false }
        
        if row < selection.start.row || row > selection.end.row {
            return false
        }
        
        if row == selection.start.row && column < selection.start.column {
            return false
        }
        
        if row == selection.end.row && column > selection.end.column {
            return false
        }
        
        return true
    }
    
    private func isHighlighted(character: TerminalCharacter) -> Bool {
        guard !searchText.isEmpty else { return false }
        return String(character.character).localizedCaseInsensitiveContains(searchText)
    }
}

/// Terminal character view
struct EmulatorCharacterView: View {
    let character: TerminalCharacter
    let position: EmulatorPosition
    let fontSize: CGFloat
    let fontName: String
    let isSelected: Bool
    let isHighlighted: Bool
    let hasCursor: Bool
    
    var body: some View {
        ZStack {
            // Background
            backgroundColor
            
            // Character
            Text(String(character.character))
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(foregroundColor)
                .bold(character.attributes.bold)
                .italic(character.attributes.italic)
                .underline(character.attributes.underline)
                .strikethrough(character.attributes.strikethrough)
            
            // Cursor overlay
            if hasCursor {
                EmulatorCursorView(
                    position: CursorPosition(column: position.column, row: position.row),
                    fontSize: fontSize,
                    blink: true
                )
            }
        }
        .frame(width: characterWidth, height: characterHeight)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Theme.primary.opacity(0.3)
        } else if isHighlighted {
            return Color.yellow.opacity(0.3)
        } else if character.attributes.reverse {
            return character.attributes.foregroundColor.swiftUIColor
        } else {
            return character.attributes.backgroundColor.swiftUIColor
        }
    }
    
    private var foregroundColor: Color {
        if character.attributes.reverse {
            return character.attributes.backgroundColor.swiftUIColor
        } else {
            return character.attributes.foregroundColor.swiftUIColor
        }
    }
    
    private var characterWidth: CGFloat {
        // Calculate based on font metrics
        fontSize * 0.6
    }
    
    private var characterHeight: CGFloat {
        fontSize * 1.2
    }
}

/// Terminal cursor view
struct EmulatorCursorView: View {
    let position: CursorPosition
    let fontSize: CGFloat
    let blink: Bool
    
    @State private var isVisible = true
    
    var body: some View {
        Rectangle()
            .fill(Theme.primary)
            .frame(width: fontSize * 0.6, height: fontSize * 1.2)
            .opacity(isVisible ? 0.8 : 0)
            .onAppear {
                if blink {
                    startBlinking()
                }
            }
    }
    
    private func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.linear(duration: 0.1)) {
                    isVisible.toggle()
                }
            }
        }
    }
}

/// Scroll position indicator
struct ScrollPositionIndicator: View {
    let visibleLines: Int
    let totalLines: Int
    
    private var scrollPercentage: Double {
        guard totalLines > 0 else { return 0 }
        return Double(visibleLines) / Double(totalLines)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(visibleLines)/\(totalLines)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ProgressView(value: scrollPercentage)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 60)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

/// Terminal size indicator
struct TerminalSizeIndicator: View {
    let size: TerminalSize
    
    var body: some View {
        Text("\(size.columns)×\(size.rows)")
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(6)
    }
}

// MARK: - Supporting Types

// MVP: EmulatorPosition is defined in TerminalStubTypes.swift
// Commenting out duplicate definition
/*
/// Terminal position
struct EmulatorPosition: Equatable {
    let row: Int
    let column: Int
}
*/

/// Terminal selection
struct EmulatorSelection: Equatable {
    let start: EmulatorPosition
    let end: EmulatorPosition
}

// MARK: - Preview

#Preview {
    TerminalEmulatorView(
        terminal: SSHTerminal(),
        scrollToBottom: .constant(true),
        searchText: "",
        onResize: { _ in }
    )
    .frame(height: 600)
    .preferredColorScheme(.dark)
}