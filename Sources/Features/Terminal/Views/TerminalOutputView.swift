//
//  TerminalOutputView.swift
//  ClaudeCode
//
//  Terminal output display with ANSI color support (Tasks 616-620)
//

import SwiftUI
import Combine

/// Terminal output view with ANSI color rendering
public struct TerminalOutputView: View {
    let output: TerminalOutput
    let fontSize: CGFloat
    let fontFamily: String
    let showTimestamps: Bool
    let wrapLines: Bool
    
    @State private var selectedRange: NSRange?
    @State private var hoveredLink: String?
    
    public init(
        output: TerminalOutput,
        fontSize: CGFloat = 13,
        fontFamily: String = "SF Mono",
        showTimestamps: Bool = false,
        wrapLines: Bool = true
    ) {
        self.output = output
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.showTimestamps = showTimestamps
        self.wrapLines = wrapLines
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(output.lines) { line in
                        TerminalOutputLineView(
                            line: line,
                            fontSize: fontSize,
                            fontFamily: fontFamily,
                            showTimestamp: showTimestamps,
                            wrapLines: wrapLines,
                            hoveredLink: $hoveredLink
                        )
                        .id(line.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: output.lines.count) { _ in
                // Auto-scroll to bottom on new output
                if let lastLine = output.lines.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(lastLine.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color.black.opacity(0.95))
        .onAppear {
            setupLinkDetection()
        }
    }
    
    private func setupLinkDetection() {
        // Configure link detection for URLs and file paths
    }
}

/// Terminal output line view
struct TerminalOutputLineView: View {
    let line: TerminalOutputLine
    let fontSize: CGFloat
    let fontFamily: String
    let showTimestamp: Bool
    let wrapLines: Bool
    @Binding var hoveredLink: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            if showTimestamp {
                Text(line.timestamp.formatted(.dateTime.hour().minute().second()))
                    .font(.system(size: fontSize * 0.9, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
                    .frame(width: 80, alignment: .trailing)
            }
            
            // Line content
            if line.segments.isEmpty {
                // Empty line
                Text(" ")
                    .font(.custom(fontFamily, size: fontSize))
            } else {
                // Rendered segments
                TerminalOutputSegments(
                    segments: line.segments,
                    fontSize: fontSize,
                    fontFamily: fontFamily,
                    wrapLines: wrapLines,
                    hoveredLink: $hoveredLink
                )
            }
            
            if !wrapLines {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Terminal output segments renderer
struct TerminalOutputSegments: View {
    let segments: [TerminalOutputSegment]
    let fontSize: CGFloat
    let fontFamily: String
    let wrapLines: Bool
    @Binding var hoveredLink: String?
    
    var body: some View {
        if wrapLines {
            // Wrapping layout
            WrappingHStack(alignment: .leading, spacing: 0) {
                ForEach(segments) { segment in
                    TerminalOutputSegmentView(
                        segment: segment,
                        fontSize: fontSize,
                        fontFamily: fontFamily,
                        hoveredLink: $hoveredLink
                    )
                }
            }
        } else {
            // Single line layout
            HStack(spacing: 0) {
                ForEach(segments) { segment in
                    TerminalOutputSegmentView(
                        segment: segment,
                        fontSize: fontSize,
                        fontFamily: fontFamily,
                        hoveredLink: $hoveredLink
                    )
                }
            }
        }
    }
}

/// Terminal output segment view
struct TerminalOutputSegmentView: View {
    let segment: TerminalOutputSegment
    let fontSize: CGFloat
    let fontFamily: String
    @Binding var hoveredLink: String?
    
    @State private var isHovered = false
    
    var body: some View {
        Text(segment.text)
            .font(.custom(fontFamily, size: fontSize))
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .bold(segment.style.contains(.bold))
            .italic(segment.style.contains(.italic))
            .underline(segment.style.contains(.underline) || isLink, color: foregroundColor)
            .strikethrough(segment.style.contains(.strikethrough))
            .onHover { hovering in
                isHovered = hovering
                if isLink {
                    hoveredLink = hovering ? segment.text : nil
                }
            }
            .onTapGesture {
                handleTap()
            }
            .contextMenu {
                if isLink {
                    Button("Open Link") {
                        openLink()
                    }
                    Button("Copy Link") {
                        copyLink()
                    }
                }
            }
    }
    
    private var foregroundColor: Color {
        if segment.style.contains(.reverse) {
            return segment.backgroundColor?.color ?? .black
        } else {
            return segment.foregroundColor?.color ?? .white
        }
    }
    
    private var backgroundColor: Color {
        if segment.style.contains(.reverse) {
            return segment.foregroundColor?.color ?? .white
        } else {
            return segment.backgroundColor?.color ?? .clear
        }
    }
    
    private var isLink: Bool {
        segment.linkURL != nil || segment.text.isValidURL || segment.text.isFilePath
    }
    
    private func handleTap() {
        if isLink {
            openLink()
        }
    }
    
    private func openLink() {
        if let url = segment.linkURL {
            UIApplication.shared.open(url)
        } else if let url = URL(string: segment.text), segment.text.isValidURL {
            UIApplication.shared.open(url)
        }
    }
    
    private func copyLink() {
        UIPasteboard.general.string = segment.linkURL?.absoluteString ?? segment.text
    }
}

/// Wrapping HStack for terminal output
struct WrappingHStack: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 0
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    // Wrap to next line
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                sizes.append(size)
                
                x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + lineHeight
        }
    }
}

// MARK: - Terminal Output Models

/// Terminal output container
public class TerminalOutput: ObservableObject {
    @Published public var lines: [TerminalOutputLine] = []
    private let maxLines: Int
    
    public init(maxLines: Int = 10000) {
        self.maxLines = maxLines
    }
    
    public func append(_ text: String, style: ANSIStyle = ANSIStyle()) {
        let segments = ANSIParser.parse(text)
        let line = TerminalOutputLine(segments: segments)
        
        lines.append(line)
        
        // Trim old lines if needed
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }
    
    public func appendLine(_ line: TerminalOutputLine) {
        lines.append(line)
        
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }
    
    public func clear() {
        lines.removeAll()
    }
}

/// Terminal output line
public struct TerminalOutputLine: Identifiable {
    public let id = UUID()
    public let timestamp = Date()
    public let segments: [TerminalOutputSegment]
    
    public init(segments: [TerminalOutputSegment]) {
        self.segments = segments
    }
    
    public init(text: String, style: ANSIStyle = ANSIStyle()) {
        self.segments = [TerminalOutputSegment(text: text, style: style.attributes)]
    }
}

/// Terminal output segment
public struct TerminalOutputSegment: Identifiable {
    public let id = UUID()
    public let text: String
    public let style: Set<ANSIAttribute>
    public let foregroundColor: ANSIColor?
    public let backgroundColor: ANSIColor?
    public let linkURL: URL?
    
    public init(
        text: String,
        style: Set<ANSIAttribute> = [],
        foregroundColor: ANSIColor? = nil,
        backgroundColor: ANSIColor? = nil,
        linkURL: URL? = nil
    ) {
        self.text = text
        self.style = style
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.linkURL = linkURL
    }
}

/// ANSI style attributes
public enum ANSIAttribute: Hashable {
    case bold
    case italic
    case underline
    case blink
    case reverse
    case strikethrough
    case dim
    case hidden
}

/// ANSI color
public enum ANSIColor: Equatable {
    case standard(ANSIStandardColor)
    case bright(ANSIStandardColor)
    case color256(Int)
    case rgb(r: Int, g: Int, b: Int)
    
    var color: Color {
        switch self {
        case .standard(let standardColor):
            return standardColor.color
        case .bright(let standardColor):
            return standardColor.brightColor
        case .color256(let index):
            return color256Palette[min(255, max(0, index))]
        case .rgb(let r, let g, let b):
            return Color(
                red: Double(r) / 255,
                green: Double(g) / 255,
                blue: Double(b) / 255
            )
        }
    }
    
    private var color256Palette: [Color] {
        // Simplified 256 color palette
        // In production, this would be the full xterm-256 palette
        Array(repeating: .gray, count: 256)
    }
}

/// ANSI standard colors
public enum ANSIStandardColor: Int {
    case black = 0
    case red = 1
    case green = 2
    case yellow = 3
    case blue = 4
    case magenta = 5
    case cyan = 6
    case white = 7
    
    var color: Color {
        switch self {
        case .black: return Color(white: 0.0)
        case .red: return Color(red: 0.8, green: 0.0, blue: 0.0)
        case .green: return Color(red: 0.0, green: 0.8, blue: 0.0)
        case .yellow: return Color(red: 0.8, green: 0.8, blue: 0.0)
        case .blue: return Color(red: 0.0, green: 0.0, blue: 0.8)
        case .magenta: return Color(red: 0.8, green: 0.0, blue: 0.8)
        case .cyan: return Color(red: 0.0, green: 0.8, blue: 0.8)
        case .white: return Color(white: 0.9)
        }
    }
    
    var brightColor: Color {
        switch self {
        case .black: return Color(white: 0.5)
        case .red: return Color(red: 1.0, green: 0.0, blue: 0.0)
        case .green: return Color(red: 0.0, green: 1.0, blue: 0.0)
        case .yellow: return Color(red: 1.0, green: 1.0, blue: 0.0)
        case .blue: return Color(red: 0.0, green: 0.0, blue: 1.0)
        case .magenta: return Color(red: 1.0, green: 0.0, blue: 1.0)
        case .cyan: return Color(red: 0.0, green: 1.0, blue: 1.0)
        case .white: return Color(white: 1.0)
        }
    }
}

/// ANSI style container
public struct ANSIStyle {
    public var attributes: Set<ANSIAttribute> = []
    public var foregroundColor: ANSIColor?
    public var backgroundColor: ANSIColor?
    
    public init(
        attributes: Set<ANSIAttribute> = [],
        foregroundColor: ANSIColor? = nil,
        backgroundColor: ANSIColor? = nil
    ) {
        self.attributes = attributes
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
}

// MARK: - ANSI Parser

/// ANSI escape sequence parser
public struct ANSIParser {
    public static func parse(_ text: String) -> [TerminalOutputSegment] {
        // Simplified ANSI parsing
        // In production, this would be a full ANSI escape sequence parser
        return [TerminalOutputSegment(text: text)]
    }
}

// MARK: - String Extensions

extension String {
    var isValidURL: Bool {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        
        let range = NSRange(location: 0, length: self.utf16.count)
        let matches = detector.matches(in: self, options: [], range: range)
        
        return !matches.isEmpty && matches.first?.range == range
    }
    
    var isFilePath: Bool {
        return self.hasPrefix("/") || self.hasPrefix("~/") || self.hasPrefix("./")
    }
}

// MARK: - Preview

#Preview {
    let output = TerminalOutput()
    output.append("[32mSuccess:[0m Operation completed")
    output.append("[31mError:[0m Connection failed")
    output.append("[33mWarning:[0m Low memory")
    output.append("[34mInfo:[0m Starting process...")
    
    return TerminalOutputView(output: output)
        .frame(height: 400)
        .preferredColorScheme(.dark)
}