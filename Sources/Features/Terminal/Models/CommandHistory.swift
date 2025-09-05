//
//  CommandHistory.swift
//  ClaudeCode
//
//  Terminal command history management
//

import Foundation

/// Manages command history for terminal sessions
public class CommandHistory: ObservableObject {
    @Published public var commands: [String] = []
    public var maxHistory: Int = 1000
    private var currentIndex: Int = -1
    
    public init() {}
    
    /// Add command to history
    public func add(_ command: String) {
        // Don't add empty commands or duplicates of the last command
        guard !command.isEmpty,
              command != commands.last else { return }
        
        commands.append(command)
        
        // Trim history if needed
        if commands.count > maxHistory {
            commands.removeFirst(commands.count - maxHistory)
        }
        
        // Reset index to end
        currentIndex = commands.count
    }
    
    /// Get previous command in history
    public func previous() -> String? {
        guard !commands.isEmpty else { return nil }
        
        if currentIndex > 0 {
            currentIndex -= 1
        } else {
            currentIndex = 0
        }
        
        return commands[safe: currentIndex]
    }
    
    /// Get next command in history
    public func next() -> String? {
        guard !commands.isEmpty else { return nil }
        
        if currentIndex < commands.count - 1 {
            currentIndex += 1
            return commands[safe: currentIndex]
        } else {
            currentIndex = commands.count
            return "" // Return to empty prompt
        }
    }
    
    /// Clear history
    public func clear() {
        commands.removeAll()
        currentIndex = -1
    }
    
    /// Search history for commands containing text
    public func search(_ text: String) -> [String] {
        guard !text.isEmpty else { return commands }
        
        return commands.filter { $0.localizedCaseInsensitiveContains(text) }
    }
    
    // MVP: Add properties/methods needed by TerminalInputView
    public var isEmpty: Bool { commands.isEmpty }
    public var count: Int { commands.count }
    
    public subscript(index: Int) -> String? {
        get { commands[safe: index] }
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}