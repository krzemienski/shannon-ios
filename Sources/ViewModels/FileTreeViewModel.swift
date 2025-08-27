import Foundation
import SwiftUI
import Combine

/// View model for managing file tree state and operations
@MainActor
public final class FileTreeViewModel: ObservableObject {
    
    // MARK: - Properties
    
    @Published public var rootNode: FileTreeNode?
    @Published public var expandedNodes: Set<String> = []
    @Published public var selectedNodes: Set<String> = []
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var searchResults: [FileTreeNode] = []
    @Published public var currentPath: String = "/"
    @Published public var breadcrumbs: [BreadcrumbItem] = []
    
    // Services
    private let fileService: FileOperationsService
    private let searchEngine: FileSearchEngine
    private let projectId: String
    
    // Drag and drop
    @Published public var draggedNodes: Set<FileTreeNode> = []
    @Published public var dropTarget: FileTreeNode?
    
    // Context menu
    @Published public var contextMenuNode: FileTreeNode?
    @Published public var showingContextMenu = false
    
    // File operations
    @Published public var showingCreateDialog = false
    @Published public var showingRenameDialog = false
    @Published public var showingDeleteConfirmation = false
    @Published public var operationTarget: FileTreeNode?
    
    // Performance
    private var loadedPaths: Set<String> = []
    private let maxAutoExpandDepth = 2
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(projectId: String, apiClient: APIClient) {
        self.projectId = projectId
        self.fileService = FileOperationsService(apiClient: apiClient, projectId: projectId)
        self.searchEngine = FileSearchEngine()
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind search results
        searchEngine.$searchResults
            .receive(on: DispatchQueue.main)
            .assign(to: &$searchResults)
        
        // Update breadcrumbs when path changes
        $currentPath
            .removeDuplicates()
            .sink { [weak self] path in
                self?.updateBreadcrumbs(for: path)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - File Loading
    
    /// Load the root directory
    public func loadRootDirectory() async {
        await loadDirectory(at: currentPath)
    }
    
    /// Load files for a directory
    public func loadDirectory(at path: String) async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Get file tree with initial depth
            if let tree = try await fileService.getFileTree(at: path, maxDepth: maxAutoExpandDepth) {
                self.rootNode = tree
                
                // Auto-expand first level
                if let children = tree.children {
                    for child in children where child.isDirectory {
                        expandedNodes.insert(child.id)
                    }
                }
                
                loadedPaths.insert(path)
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    /// Load children for a specific node
    public func loadChildren(for node: FileTreeNode) async {
        guard node.isDirectory, !loadedPaths.contains(node.path) else { return }
        
        do {
            let children = try await fileService.listFiles(at: node.path)
            
            // Update the node with children
            if var updatedRoot = rootNode {
                updateNodeChildren(&updatedRoot, targetPath: node.path, children: children)
                rootNode = updatedRoot
            }
            
            loadedPaths.insert(node.path)
        } catch {
            self.error = error
        }
    }
    
    /// Recursively update node children
    private func updateNodeChildren(_ node: inout FileTreeNode, targetPath: String, children: [FileTreeNode]) {
        if node.path == targetPath {
            node.children = children
            return
        }
        
        if var nodeChildren = node.children {
            for i in nodeChildren.indices {
                updateNodeChildren(&nodeChildren[i], targetPath: targetPath, children: children)
            }
            node.children = nodeChildren
        }
    }
    
    /// Refresh current directory
    public func refresh() async {
        loadedPaths.removeAll()
        await loadDirectory(at: currentPath)
    }
    
    // MARK: - Node Expansion
    
    /// Toggle node expansion
    public func toggleExpansion(for node: FileTreeNode) {
        guard node.isDirectory else { return }
        
        if expandedNodes.contains(node.id) {
            expandedNodes.remove(node.id)
        } else {
            expandedNodes.insert(node.id)
            
            // Load children if not already loaded
            if !loadedPaths.contains(node.path) {
                Task {
                    await loadChildren(for: node)
                }
            }
        }
    }
    
    /// Expand all nodes
    public func expandAll() {
        expandAllRecursive(rootNode)
    }
    
    private func expandAllRecursive(_ node: FileTreeNode?) {
        guard let node = node else { return }
        
        if node.isDirectory {
            expandedNodes.insert(node.id)
        }
        
        if let children = node.children {
            for child in children {
                expandAllRecursive(child)
            }
        }
    }
    
    /// Collapse all nodes
    public func collapseAll() {
        expandedNodes.removeAll()
    }
    
    // MARK: - Selection
    
    /// Toggle node selection
    public func toggleSelection(for node: FileTreeNode) {
        if selectedNodes.contains(node.id) {
            selectedNodes.remove(node.id)
        } else {
            selectedNodes.insert(node.id)
        }
    }
    
    /// Select single node
    public func select(_ node: FileTreeNode) {
        selectedNodes = [node.id]
    }
    
    /// Clear selection
    public func clearSelection() {
        selectedNodes.removeAll()
    }
    
    /// Get selected file nodes
    public func getSelectedNodes() -> [FileTreeNode] {
        guard let root = rootNode else { return [] }
        return findNodes(in: root, matching: selectedNodes)
    }
    
    private func findNodes(in node: FileTreeNode, matching ids: Set<String>) -> [FileTreeNode] {
        var results: [FileTreeNode] = []
        
        if ids.contains(node.id) {
            results.append(node)
        }
        
        if let children = node.children {
            for child in children {
                results.append(contentsOf: findNodes(in: child, matching: ids))
            }
        }
        
        return results
    }
    
    // MARK: - File Operations
    
    /// Create new file or directory
    public func createItem(in parent: FileTreeNode?, name: String, isDirectory: Bool) async {
        let parentPath = parent?.path ?? currentPath
        
        do {
            let newNode = try await fileService.createFile(
                in: parentPath,
                name: name,
                isDirectory: isDirectory
            )
            
            // Refresh parent directory
            await loadDirectory(at: parentPath)
            
            // Select the new node
            select(newNode)
        } catch {
            self.error = error
        }
    }
    
    /// Rename file or directory
    public func rename(_ node: FileTreeNode, to newName: String) async {
        do {
            let renamedNode = try await fileService.renameFile(at: node.path, newName: newName)
            
            // Refresh parent directory
            let parentPath = URL(fileURLWithPath: node.path).deletingLastPathComponent().path
            await loadDirectory(at: parentPath)
            
            // Select the renamed node
            select(renamedNode)
        } catch {
            self.error = error
        }
    }
    
    /// Delete files or directories
    public func delete(_ nodes: [FileTreeNode]) async {
        for node in nodes {
            do {
                try await fileService.deleteFile(at: node.path)
            } catch {
                self.error = error
                break
            }
        }
        
        // Refresh current directory
        await refresh()
        clearSelection()
    }
    
    /// Move files or directories
    public func move(_ nodes: [FileTreeNode], to destination: FileTreeNode) async {
        guard destination.isDirectory else { return }
        
        for node in nodes {
            let destinationPath = destination.path + "/" + node.name
            
            do {
                _ = try await fileService.moveFile(from: node.path, to: destinationPath)
            } catch {
                self.error = error
                break
            }
        }
        
        // Refresh both source and destination
        await refresh()
        clearSelection()
    }
    
    /// Copy files or directories
    public func copy(_ nodes: [FileTreeNode], to destination: FileTreeNode) async {
        guard destination.isDirectory else { return }
        
        for node in nodes {
            let destinationPath = destination.path + "/" + node.name
            
            do {
                _ = try await fileService.copyFile(from: node.path, to: destinationPath)
            } catch {
                self.error = error
                break
            }
        }
        
        // Refresh destination
        await loadDirectory(at: destination.path)
    }
    
    // MARK: - Navigation
    
    /// Navigate to a specific path
    public func navigateTo(path: String) async {
        currentPath = path
        await loadDirectory(at: path)
    }
    
    /// Navigate using breadcrumb
    public func navigateToBreadcrumb(_ item: BreadcrumbItem) async {
        await navigateTo(path: item.path)
    }
    
    /// Update breadcrumbs for current path
    private func updateBreadcrumbs(for path: String) {
        let components = path.split(separator: "/").map(String.init)
        var breadcrumbs: [BreadcrumbItem] = []
        var currentPath = ""
        
        // Add root
        breadcrumbs.append(BreadcrumbItem(name: "Project", path: "/"))
        
        // Add path components
        for component in components {
            currentPath += "/" + component
            breadcrumbs.append(BreadcrumbItem(name: component, path: currentPath))
        }
        
        self.breadcrumbs = breadcrumbs
    }
    
    // MARK: - Search
    
    /// Search files
    public func search(query: String) async {
        guard let root = rootNode else { return }
        
        searchEngine.searchText = query
        let results = await searchEngine.searchInTree(root)
        searchResults = results
    }
    
    /// Clear search
    public func clearSearch() {
        searchEngine.clearSearch()
        searchResults = []
    }
    
    // MARK: - Context Menu
    
    /// Show context menu for node
    public func showContextMenu(for node: FileTreeNode) {
        contextMenuNode = node
        showingContextMenu = true
    }
    
    /// Hide context menu
    public func hideContextMenu() {
        contextMenuNode = nil
        showingContextMenu = false
    }
    
    // MARK: - Drag and Drop
    
    /// Start dragging nodes
    public func startDragging(_ nodes: Set<FileTreeNode>) {
        draggedNodes = nodes
    }
    
    /// Set drop target
    public func setDropTarget(_ node: FileTreeNode?) {
        dropTarget = node
    }
    
    /// Perform drop operation
    public func performDrop(on target: FileTreeNode) async {
        guard target.isDirectory, !draggedNodes.isEmpty else { return }
        
        let nodesToMove = Array(draggedNodes)
        await move(nodesToMove, to: target)
        
        // Clear drag state
        draggedNodes.removeAll()
        dropTarget = nil
    }
}

// MARK: - Supporting Types

public struct BreadcrumbItem: Identifiable {
    public let id = UUID()
    public let name: String
    public let path: String
}