//
//  SSHTerminal.swift
//  ClaudeCode
//
//  SSH terminal emulation
//

import Foundation
import SwiftUI

@MainActor
class SSHTerminal: ObservableObject {
    @Published var output: String = ""
    @Published var isConnected: Bool = false
    @Published var currentDirectory: String = "~"
    
    private var size: TerminalSize = TerminalSize(columns: 80, rows: 24)
    
    init() {}
    
    func send(_ command: String) {
        // Process command
        output += "\n$ \(command)\n"
    }
    
    func resize(to size: TerminalSize) {
        self.size = size
    }
    
    func clear() {
        output = ""
    }
    
    func connect() {
        isConnected = true
    }
    
    func disconnect() {
        isConnected = false
    }
}

struct TerminalSize: Equatable {
    let columns: Int
    let rows: Int
}