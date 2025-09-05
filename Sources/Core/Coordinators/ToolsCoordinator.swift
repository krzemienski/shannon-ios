//
//  ToolsCoordinator.swift
//  ClaudeCode
//
//  Coordinator for tools navigation and flow
//

import SwiftUI
import Combine

/// Coordinator managing tools navigation and flow
@MainActor
public final class ToolsCoordinator: BaseCoordinator, ObservableObject {
    
    // MARK: - Navigation State
    
    @Published var navigationPath = NavigationPath()
    @Published var selectedToolId: String?
    @Published var isShowingToolDetail = false
    @Published var isShowingToolExecution = false
    @Published var searchQuery = ""
    @Published var selectedCategory: ToolsCoordinatorCategory = .all
    
    // MARK: - Dependencies
    
    weak var appCoordinator: AppCoordinator?
    private let dependencyContainer: DependencyContainer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - View Models
    
    private var toolsViewModel: ToolsViewModel?
    
    // MARK: - Initialization
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        super.init()
        observeToolStore()
    }
    
    // MARK: - Setup
    
    private func observeToolStore() {
        // Observe tool store updates
        dependencyContainer.toolStore.$availableTools
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Coordinator Lifecycle
    
    override func start() {
        // Tools are already loaded in ToolStore init
    }
    
    // MARK: - Navigation
    
    func handleTabSelection() {
        // Called when tools tab is selected
        if selectedToolId == nil && !dependencyContainer.toolStore.availableTools.isEmpty {
            // Show tool categories or featured tools
            showToolCategories()
        }
    }
    
    func openTool(id: String) {
        selectedToolId = id
        isShowingToolDetail = true
        navigationPath.append(ToolRoute.detail(id))
    }
    
    func showToolCategories() {
        navigationPath.removeLast(navigationPath.count)
        selectedToolId = nil
    }
    
    func selectCategory(_ category: ToolsCoordinatorCategory) {
        selectedCategory = category
        navigationPath.append(ToolRoute.category(category))
    }
    
    // MARK: - Tool Execution
    
    func executeTool(id: String, parameters: [String: Any]) {
        isShowingToolExecution = true
        navigationPath.append(ToolRoute.execution(id, parameters))
        
        Task {
            await performToolExecution(id: id, parameters: parameters)
        }
    }
    
    private func performToolExecution(id: String, parameters: [String: Any]) async {
        let viewModel = getToolsViewModel()
        
        // Set the selected tool and parameters
        if let tool = dependencyContainer.toolStore.availableTools.first(where: { $0.id == id }) {
            viewModel.selectedTool = tool
            viewModel.toolParameters = parameters.compactMapValues { "\($0)" }
            
            // Execute the tool
            await viewModel.executeTool()
            
            if let result = viewModel.executionResult {
                handleToolExecutionSuccess(toolId: id, result: result)
            } else if let error = viewModel.error {
                handleToolExecutionError(error)
            }
        }
    }
    
    func cancelToolExecution(id: String) {
        let viewModel = getToolsViewModel()
        viewModel.cancelExecution()
        isShowingToolExecution = false
    }
    
    // MARK: - Tool Management
    
    func addToFavorites(toolId: String) {
        Task {
            await dependencyContainer.toolStore.addToFavorites(toolId)
        }
    }
    
    func removeFromFavorites(toolId: String) {
        Task {
            await dependencyContainer.toolStore.removeFromFavorites(toolId)
        }
    }
    
    func searchTools(query: String) -> [Tool] {
        dependencyContainer.toolStore.searchTools(query: query)
    }
    
    func getToolsByCategory(_ category: ToolsCoordinatorCategory) -> [Tool] {
        dependencyContainer.toolStore.getToolsByCategory(category)
    }
    
    func getRecentTools() -> [Tool] {
        dependencyContainer.toolStore.recentTools
    }
    
    func getFavoriteTools() -> [Tool] {
        dependencyContainer.toolStore.favoritedTools
    }
    
    // MARK: - Tool Details
    
    func showToolDetails(for toolId: String) {
        isShowingToolDetail = true
        appCoordinator?.presentSheet(.toolDetails(toolId))
    }
    
    func getToolDocumentation(for toolId: String) -> String? {
        dependencyContainer.toolStore.getToolDocumentation(toolId)
    }
    
    func getToolParameters(for toolId: String) -> [ToolParameter]? {
        dependencyContainer.toolStore.getToolParameters(toolId)
    }
    
    // MARK: - Execution History
    
    func getExecutionHistory(for toolId: String? = nil) -> [ToolExecution] {
        if let toolId = toolId {
            return dependencyContainer.toolStore.getExecutionHistory(for: toolId)
        } else {
            return dependencyContainer.toolStore.allExecutionHistory
        }
    }
    
    func clearExecutionHistory(for toolId: String? = nil) {
        Task {
            // Clear execution history
            await dependencyContainer.toolStore.clearExecutionHistory()
        }
    }
    
    // MARK: - View Model Management
    
    func getToolsViewModel() -> ToolsViewModel {
        if let existing = toolsViewModel {
            return existing
        }
        
        let viewModel = dependencyContainer.makeToolsViewModel()
        toolsViewModel = viewModel
        return viewModel
    }
    
    // MARK: - Success/Error Handling
    
    private func handleToolExecutionSuccess(toolId: String, result: ToolResult) {
        isShowingToolExecution = false
        
        // Store execution in history
        Task {
            let execution = ToolExecution(
                id: UUID().uuidString,
                toolId: toolId,
                toolName: dependencyContainer.toolStore.availableTools.first(where: { $0.id == toolId })?.name ?? toolId,
                parameters: [:],
                status: .completed,
                startedAt: Date(),
                completedAt: Date(),
                result: result,
                error: nil
            )
            await dependencyContainer.toolStore.addToHistory(execution)
        }
        
        // Show success feedback
        let alertData = AlertData(
            title: "Tool Executed Successfully",
            message: "The tool '\(toolId)' has completed execution.",
            primaryAction: AlertAction(
                title: "OK",
                style: .default,
                handler: nil
            ),
            secondaryAction: nil
        )
        appCoordinator?.showAlert(alertData)
    }
    
    private func handleToolExecutionError(_ error: Error) {
        isShowingToolExecution = false
        appCoordinator?.showError(error) { [weak self] in
            // Retry execution
            if let toolId = self?.selectedToolId {
                self?.navigationPath.removeLast()
                // User would need to re-enter parameters
            }
        }
    }
}

// MARK: - Navigation Routes

enum ToolRoute: Hashable {
    case category(ToolsCoordinatorCategory)
    case detail(String)
    case execution(String, [String: Any])
    
    static func == (lhs: ToolRoute, rhs: ToolRoute) -> Bool {
        switch (lhs, rhs) {
        case (.category(let a), .category(let b)):
            return a == b
        case (.detail(let a), .detail(let b)):
            return a == b
        case (.execution(let a, _), .execution(let b, _)):
            return a == b  // Only compare tool IDs for equality
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .category(let category):
            hasher.combine("category")
            hasher.combine(category)
        case .detail(let id):
            hasher.combine("detail")
            hasher.combine(id)
        case .execution(let id, _):
            hasher.combine("execution")
            hasher.combine(id)
        }
    }
}

// MARK: - Supporting Types

enum ToolsCoordinatorCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case file = "File"
    case system = "System"
    case network = "Network"
    case development = "Development"
    case utility = "Utility"
    case ai = "AI"
    case favorite = "Favorites"
    case recent = "Recent"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .file: return "doc.fill"
        case .system: return "cpu"
        case .network: return "network"
        case .development: return "hammer.fill"
        case .utility: return "wrench.fill"
        case .ai: return "brain"
        case .favorite: return "star.fill"
        case .recent: return "clock.fill"
        }
    }
}