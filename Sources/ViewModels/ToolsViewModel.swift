//
//  ToolsViewModel.swift
//  ClaudeCode
//
//  ViewModel for tools management with MVVM pattern
//

import SwiftUI
import Combine

/// ViewModel for managing tools interface
@MainActor
public final class ToolsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var availableTools: [Tool] = []
    @Published public var recentTools: [Tool] = []
    @Published public var favoriteTools: [Tool] = []
    @Published public var toolExecutions: [ToolExecution] = []
    @Published public var selectedTool: Tool?
    @Published public var selectedCategory: ToolCategory?
    @Published public var searchText = ""
    @Published public var isExecuting = false
    @Published public var showToolDetail = false
    @Published public var showExecutionHistory = false
    @Published public var error: Error?
    @Published public var showError = false
    
    // MARK: - Tool Parameters
    
    @Published public var toolParameters: [String: String] = [:]
    @Published public var parameterValidation: [String: Bool] = [:]
    
    // MARK: - Execution Results
    
    @Published public var currentExecution: ToolExecution?
    @Published public var executionResult: ToolResult?
    @Published public var showResult = false
    
    // MARK: - Private Properties
    
    private let toolStore: ToolStore
    private let apiClient: APIClient
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    public var categorizedTools: [ToolCategory: [Tool]] {
        Dictionary(grouping: filteredTools, by: { $0.category })
    }
    
    public var filteredTools: [Tool] {
        var tools = availableTools
        
        // Filter by category
        if let category = selectedCategory {
            tools = tools.filter { $0.category == category }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            tools = tools.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return tools
    }
    
    public var activeExecutions: [ToolExecution] {
        toolExecutions.filter { $0.status == .running }
    }
    
    public var hasActiveExecutions: Bool {
        !activeExecutions.isEmpty
    }
    
    public var canExecuteTool: Bool {
        guard let tool = selectedTool else { return false }
        
        // Check all required parameters are filled
        for parameter in tool.parameters where parameter.required {
            if toolParameters[parameter.name]?.isEmpty ?? true {
                return false
            }
        }
        
        return !isExecuting
    }
    
    // MARK: - Initialization
    
    public init(toolStore: ToolStore,
         apiClient: APIClient,
         appState: AppState) {
        self.toolStore = toolStore
        self.apiClient = apiClient
        self.appState = appState
        
        setupBindings()
        loadTools()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind to tool store
        toolStore.$availableTools
            .sink { [weak self] tools in
                self?.availableTools = tools
            }
            .store(in: &cancellables)
        
        toolStore.$recentTools
            .sink { [weak self] tools in
                self?.recentTools = tools
            }
            .store(in: &cancellables)
        
        toolStore.$favoriteTools
            .sink { [weak self] favoriteIds in
                self?.updateFavoriteTools(favoriteIds)
            }
            .store(in: &cancellables)
        
        toolStore.$toolExecutions
            .sink { [weak self] executions in
                self?.toolExecutions = executions
                self?.updateCurrentExecution(executions)
            }
            .store(in: &cancellables)
    }
    
    public func loadTools() {
        availableTools = toolStore.availableTools
        recentTools = toolStore.recentTools
        updateFavoriteTools(toolStore.favoriteTools)
    }
    
    // MARK: - Public Methods - Tool Selection
    
    /// Select a tool
    public func selectTool(_ tool: Tool) {
        selectedTool = tool
        toolParameters.removeAll()
        parameterValidation.removeAll()
        
        // Initialize parameters with defaults
        for parameter in tool.parameters {
            if let defaultValue = parameter.defaultValue as? String {
                toolParameters[parameter.name] = defaultValue
            } else {
                toolParameters[parameter.name] = ""
            }
            
            // Initialize validation
            parameterValidation[parameter.name] = !parameter.required
        }
        
        showToolDetail = true
    }
    
    /// Clear tool selection
    public func clearSelection() {
        selectedTool = nil
        toolParameters.removeAll()
        parameterValidation.removeAll()
        showToolDetail = false
    }
    
    /// Select category filter
    public func selectCategory(_ category: ToolCategory?) {
        selectedCategory = category
    }
    
    // MARK: - Public Methods - Tool Execution
    
    /// Execute selected tool
    public func executeTool() async {
        guard let tool = selectedTool, canExecuteTool else { return }
        
        isExecuting = true
        error = nil
        executionResult = nil
        
        // Convert parameters to proper types
        var parameters: [String: Any] = [:]
        for param in tool.parameters {
            if let value = toolParameters[param.name], !value.isEmpty {
                parameters[param.name] = convertParameter(value, type: param.type)
            }
        }
        
        do {
            let result = try await toolStore.executeTool(tool, parameters: parameters)
            executionResult = result
            showResult = true
            
            // Provide haptic feedback
            let impactFeedback = UINotificationFeedbackGenerator()
            impactFeedback.notificationOccurred(.success)
        } catch {
            handleError(error)
        }
        
        isExecuting = false
    }
    
    /// Cancel execution
    func cancelExecution() {
        if let execution = currentExecution {
            toolStore.cancelExecution(execution.id)
        }
        isExecuting = false
    }
    
    /// Retry failed execution
    public func retryExecution(_ execution: ToolExecution) async {
        guard let tool = availableTools.first(where: { $0.id == execution.toolId }) else {
            return
        }
        
        selectedTool = tool
        
        // Restore parameters
        for (key, value) in execution.parameters {
            toolParameters[key] = String(describing: value)
        }
        
        await executeTool()
    }
    
    // MARK: - Public Methods - Favorites
    
    /// Toggle favorite status
    public func toggleFavorite(_ tool: Tool) {
        toolStore.toggleFavorite(tool)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    /// Check if tool is favorite
    public func isFavorite(_ tool: Tool) -> Bool {
        toolStore.favoriteTools.contains(tool.id)
    }
    
    // MARK: - Public Methods - History
    
    /// Clear execution history
    public func clearHistory() {
        toolStore.clearExecutionHistory()
    }
    
    /// Export execution history
    public func exportHistory() async -> Data? {
        let export = ExecutionHistoryExport(
            timestamp: Date(),
            executionCount: toolExecutions.count,
            executions: toolExecutions.map { ExecutionRecord(from: $0) }
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(export)
    }
    
    // MARK: - Public Methods - Parameters
    
    /// Update tool parameter
    public func updateParameter(_ name: String, value: String) {
        toolParameters[name] = value
        validateParameter(name, value: value)
    }
    
    /// Validate parameter
    public func validateParameter(_ name: String, value: String) {
        guard let tool = selectedTool,
              let parameter = tool.parameters.first(where: { $0.name == name }) else {
            return
        }
        
        if parameter.required {
            parameterValidation[name] = !value.isEmpty
        } else {
            parameterValidation[name] = true
        }
        
        // Type-specific validation
        switch parameter.type {
        case .number:
            parameterValidation[name] = Double(value) != nil
        case .boolean:
            parameterValidation[name] = ["true", "false", "yes", "no", "1", "0"].contains(value.lowercased())
        default:
            break
        }
    }
    
    /// Clear all parameters
    public func clearParameters() {
        for key in toolParameters.keys {
            toolParameters[key] = ""
        }
    }
    
    // MARK: - Private Methods
    
    private func updateFavoriteTools(_ favoriteIds: Set<String>) {
        favoriteTools = availableTools.filter { favoriteIds.contains($0.id) }
    }
    
    private func updateCurrentExecution(_ executions: [ToolExecution]) {
        // Update current execution if it exists
        if let current = currentExecution {
            currentExecution = executions.first { $0.id == current.id }
        }
        
        // Set current execution to the latest running one
        if currentExecution == nil || currentExecution?.status != .running {
            currentExecution = executions.first { $0.status == .running }
        }
    }
    
    private func convertParameter(_ value: String, type: ParameterType) -> Any {
        switch type {
        case .number:
            return Double(value) ?? 0
        case .boolean:
            return ["true", "yes", "1"].contains(value.lowercased())
        case .array:
            return value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        case .object:
            // Try to parse as JSON
            if let data = value.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) {
                return json
            }
            return [:]
        case .string:
            return value
        }
    }
    
    private func handleError(_ error: Error) {
        self.error = error
        showError = true
        
        // Haptic feedback
        let impactFeedback = UINotificationFeedbackGenerator()
        impactFeedback.notificationOccurred(.error)
    }
}

// MARK: - Supporting Types

public struct ExecutionHistoryExport: Codable {
    let timestamp: Date
    let executionCount: Int
    let executions: [ExecutionRecord]
}

public struct ExecutionRecord: Codable {
    let toolId: String
    let toolName: String
    let startedAt: Date
    let completedAt: Date?
    let status: String
    let success: Bool
    
    public init(from execution: ToolExecution) {
        self.toolId = execution.toolId
        self.toolName = execution.toolName
        self.startedAt = execution.startedAt
        self.completedAt = execution.completedAt
        self.status = String(describing: execution.status)
        self.success = execution.result?.success ?? false
    }
}