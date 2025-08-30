//
//  ToolStore.swift
//  ClaudeCode
//
//  Manages available tools and their configurations
//

import SwiftUI
import Combine

/// Store for managing available tools and their execution
@MainActor
public final class ToolStore: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var availableTools: [Tool] = []
    @Published public var recentTools: [Tool] = []
    @Published public var favoriteTools: Set<String> = []
    @Published public var toolExecutions: [ToolExecution] = []
    @Published public var isLoading = false
    @Published public var error: ToolError?
    
    // MARK: - Computed Properties
    
    public var categorizedTools: [ToolStoreCategory: [Tool]] {
        Dictionary(grouping: availableTools, by: { $0.category })
    }
    
    public var favoritedTools: [Tool] {
        availableTools.filter { favoriteTools.contains($0.id) }
    }
    
    public var activeExecutions: [ToolExecution] {
        toolExecutions.filter { $0.status == .running }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init() {
        loadTools()
        loadFavorites()
        loadRecentTools()
    }
    
    // MARK: - Public Methods
    
    /// Execute a tool with given parameters
    public func executeTool(_ tool: Tool, parameters: [String: Any]) async throws -> ToolResult {
        let execution = ToolExecution(
            id: UUID().uuidString,
            toolId: tool.id,
            toolName: tool.name,
            parameters: parameters,
            status: .pending,
            startedAt: Date()
        )
        
        toolExecutions.insert(execution, at: 0)
        
        // Update execution status
        updateExecutionStatus(execution.id, status: .running)
        
        do {
            // Execute tool (implementation depends on tool type)
            let result = try await performToolExecution(tool, parameters: parameters)
            
            // Update execution with result
            updateExecutionStatus(execution.id, status: .completed, result: result)
            
            // Add to recent tools
            addToRecentTools(tool)
            
            return result
        } catch {
            updateExecutionStatus(execution.id, status: .failed, error: error)
            throw error
        }
    }
    
    /// Cancel a running tool execution
    func cancelExecution(_ executionId: String) {
        updateExecutionStatus(executionId, status: .cancelled)
    }
    
    /// Toggle favorite status for a tool
    public func toggleFavorite(_ tool: Tool) {
        if favoriteTools.contains(tool.id) {
            favoriteTools.remove(tool.id)
        } else {
            favoriteTools.insert(tool.id)
        }
        saveFavorites()
    }
    
    /// Clear execution history
    public func clearExecutionHistory() {
        toolExecutions.removeAll()
    }
    
    /// Clear recent tools
    public func clearRecentTools() {
        recentTools.removeAll()
        userDefaults.removeObject(forKey: "recentToolIds")
    }
    
    /// Get tools by category (compatibility method for ToolsCoordinator)
    public func getToolsByCategory(_ category: Any) -> [Tool] {
        // For now, return all tools - proper category mapping would be needed
        return availableTools
    }
    
    /// Search tools by query
    public func searchTools(query: String) -> [Tool] {
        guard !query.isEmpty else { return availableTools }
        
        let lowercasedQuery = query.lowercased()
        return availableTools.filter { tool in
            tool.name.lowercased().contains(lowercasedQuery) ||
            tool.description.lowercased().contains(lowercasedQuery)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadTools() {
        // Load built-in tools
        availableTools = [
            Tool(
                id: "read_file",
                name: "Read File",
                description: "Read contents of a file",
                category: .fileSystem,
                icon: "doc.text",
                parameters: [
                    ToolParameter(name: "path", type: .string, required: true, description: "File path")
                ]
            ),
            Tool(
                id: "write_file",
                name: "Write File",
                description: "Write content to a file",
                category: .fileSystem,
                icon: "square.and.pencil",
                parameters: [
                    ToolParameter(name: "path", type: .string, required: true, description: "File path"),
                    ToolParameter(name: "content", type: .string, required: true, description: "File content")
                ]
            ),
            Tool(
                id: "list_directory",
                name: "List Directory",
                description: "List contents of a directory",
                category: .fileSystem,
                icon: "folder",
                parameters: [
                    ToolParameter(name: "path", type: .string, required: true, description: "Directory path")
                ]
            ),
            Tool(
                id: "run_command",
                name: "Run Command",
                description: "Execute a shell command",
                category: .shell,
                icon: "terminal",
                parameters: [
                    ToolParameter(name: "command", type: .string, required: true, description: "Command to execute"),
                    ToolParameter(name: "workingDirectory", type: .string, required: false, description: "Working directory")
                ]
            ),
            Tool(
                id: "search_files",
                name: "Search Files",
                description: "Search for files by pattern",
                category: .search,
                icon: "magnifyingglass",
                parameters: [
                    ToolParameter(name: "pattern", type: .string, required: true, description: "Search pattern"),
                    ToolParameter(name: "path", type: .string, required: false, description: "Search path")
                ]
            ),
            Tool(
                id: "git_status",
                name: "Git Status",
                description: "Get git repository status",
                category: .git,
                icon: "arrow.triangle.branch",
                parameters: [
                    ToolParameter(name: "path", type: .string, required: false, description: "Repository path")
                ]
            )
        ]
    }
    
    private func loadFavorites() {
        if let savedFavorites = userDefaults.stringArray(forKey: "favoriteToolIds") {
            favoriteTools = Set(savedFavorites)
        }
    }
    
    private func saveFavorites() {
        userDefaults.set(Array(favoriteTools), forKey: "favoriteToolIds")
    }
    
    private func loadRecentTools() {
        if let recentIds = userDefaults.stringArray(forKey: "recentToolIds") {
            recentTools = recentIds.compactMap { id in
                availableTools.first { $0.id == id }
            }
        }
    }
    
    private func addToRecentTools(_ tool: Tool) {
        // Remove if already in recent
        recentTools.removeAll { $0.id == tool.id }
        
        // Add to front
        recentTools.insert(tool, at: 0)
        
        // Keep only last 10
        if recentTools.count > 10 {
            recentTools.removeLast()
        }
        
        // Save to UserDefaults
        let recentIds = recentTools.map { $0.id }
        userDefaults.set(recentIds, forKey: "recentToolIds")
    }
    
    private func updateExecutionStatus(_ executionId: String, 
                                     status: ExecutionStatus,
                                     result: ToolResult? = nil,
                                     error: Error? = nil) {
        if let index = toolExecutions.firstIndex(where: { $0.id == executionId }) {
            toolExecutions[index].status = status
            toolExecutions[index].result = result
            toolExecutions[index].error = error?.localizedDescription
            
            if status == .completed || status == .failed || status == .cancelled {
                toolExecutions[index].completedAt = Date()
            }
        }
    }
    
    private func performToolExecution(_ tool: Tool, parameters: [String: Any]) async throws -> ToolResult {
        // This would be implemented based on the actual tool execution logic
        // For now, return a mock result
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate work
        
        return ToolResult(
            toolId: tool.id,
            success: true,
            output: "Tool executed successfully",
            data: nil
        )
    }
    
    // MARK: - Missing Methods
    
    public func clearAll() {
        availableTools.removeAll()
        recentTools.removeAll()
        favoriteTools.removeAll()
        toolExecutions.removeAll()
    }
    
    public func clearCache() {
        // Clear any cached tool data
        recentTools.removeAll()
        toolExecutions.removeAll()
    }
}

// MARK: - Models

public struct Tool: Identifiable, Equatable {
    public let id: String
    let name: String
    let description: String
    let category: ToolStoreCategory
    let icon: String
    let parameters: [ToolParameter]
}

public struct ToolParameter: Equatable {
    let name: String
    let type: ParameterType
    let required: Bool
    let description: String
    let defaultValue: Any?
    
    public init(name: String, type: ParameterType, required: Bool, description: String, defaultValue: Any? = nil) {
        self.name = name
        self.type = type
        self.required = required
        self.description = description
        self.defaultValue = defaultValue
    }
    
    public static func == (lhs: ToolParameter, rhs: ToolParameter) -> Bool {
        lhs.name == rhs.name && lhs.type == rhs.type && lhs.required == rhs.required
    }
}

public enum ParameterType: String, Equatable {
    case string
    case number
    case boolean
    case array
    case object
}

public enum ToolStoreCategory: String, CaseIterable {
    case fileSystem = "File System"
    case shell = "Shell"
    case git = "Git"
    case search = "Search"
    case network = "Network"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .fileSystem: return "folder"
        case .shell: return "terminal"
        case .git: return "arrow.triangle.branch"
        case .search: return "magnifyingglass"
        case .network: return "network"
        case .other: return "wrench"
        }
    }
}

public struct ToolExecution: Identifiable {
    public let id: String
    public let toolId: String
    public let toolName: String
    public let parameters: [String: Any]
    public var status: ExecutionStatus
    public let startedAt: Date
    public var completedAt: Date?
    public var result: ToolResult?
    public var error: String?
}

public enum ExecutionStatus {
    case pending
    case running
    case completed
    case failed
    case cancelled
    
    public var color: Color {
        switch self {
        case .pending: return .gray
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

public struct ToolResult {
    public let toolId: String
    public let success: Bool
    public let output: String?
    public let data: Any?
}

public enum ToolError: LocalizedError {
    case toolNotFound
    case invalidParameters
    case executionFailed(String)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .toolNotFound:
            return "Tool not found"
        case .invalidParameters:
            return "Invalid parameters provided"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .timeout:
            return "Tool execution timed out"
        }
    }
}