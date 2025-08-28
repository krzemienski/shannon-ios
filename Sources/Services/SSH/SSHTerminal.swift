//
//  SSHTerminal.swift
//  ClaudeCode
//
//  SSH terminal emulation
//

import Foundation
import SwiftUI
import Combine

@MainActor
public class SSHTerminal: ObservableObject {
    @Published public var output: String = ""
    @Published public var isConnected: Bool = false
    @Published public var currentDirectory: String = "~"
    public var inputStream = PassthroughSubject<String, Never>()
    
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
}

struct TerminalSize: Equatable {
    let columns: Int
    let rows: Int
}