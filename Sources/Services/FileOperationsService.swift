import Foundation
import Combine

/// Service for handling file operations with the backend API
@MainActor
public final class FileOperationsService: ObservableObject {
    // MARK: - Properties
    
    @Published public var isLoading = false
    @Published public var error: Error?
    
    private let apiClient: APIClient
    private let projectId: String
    private var cancellables = Set<AnyCancellable>()
    
    // Cache for file listings
    private var fileCache: [String: [FileTreeNode]] = [:]
    private let cacheExpiration: TimeInterval = 30 // 30 seconds
    private var cacheTimestamps: [String: Date] = [:]
    
    // MARK: - Initialization
    
    public init(apiClient: APIClient, projectId: String) {
        self.apiClient = apiClient
        self.projectId = projectId
    }
    
    // MARK: - File Listing
    
    /// List files in a directory
    public func listFiles(at path: String) async throws -> [FileTreeNode] {
        // Check cache first
        if let cached = getCachedFiles(for: path) {
            return cached
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Implement file listing when custom endpoints are available
        // For now, return empty list
        return []
        
//        let endpoint = "/projects/\(projectId)/files"
//        let params = ["path": path]
//        
//        do {
//            let response: FileListResponse = try await apiClient.request(
//                endpoint: endpoint,
//                method: .GET,
//                queryParams: params
//            )
//            
//            let nodes = response.files.map { $0.toNode() }
//            
//            // Update cache
//            cacheFiles(nodes, for: path)
//            
//            return nodes
//        } catch {
//            self.error = error
//            throw error
//        }
    }
    
    /// Get file tree recursively
    public func getFileTree(at path: String, maxDepth: Int = 3) async throws -> FileTreeNode? {
        guard maxDepth > 0 else { return nil }
        
        let files = try await listFiles(at: path)
        
        // Find the root directory node
        guard let rootNode = files.first(where: { $0.path == path && $0.isDirectory }) else {
            // Create a synthetic root node
            var rootNode = FileTreeNode(
                name: URL(fileURLWithPath: path).lastPathComponent,
                path: path,
                isDirectory: true
            )
            
            // Get children
            var children = files
            
            // Recursively load subdirectories
            for (index, child) in children.enumerated() where child.isDirectory {
                if let subtree = try await getFileTree(at: child.path, maxDepth: maxDepth - 1) {
                    children[index] = subtree
                }
            }
            
            rootNode.children = children
            return rootNode
        }
        
        var updatedRoot = rootNode
        
        // Recursively load subdirectories
        if let children = rootNode.children {
            var updatedChildren = children
            
            for (index, child) in children.enumerated() where child.isDirectory {
                if let subtree = try await getFileTree(at: child.path, maxDepth: maxDepth - 1) {
                    updatedChildren[index] = subtree
                }
            }
            
            updatedRoot.children = updatedChildren
        }
        
        return updatedRoot
    }
    
    // MARK: - File Operations
    
    /// Create a new file or directory
    public func createFile(
        in parentPath: String,
        name: String,
        isDirectory: Bool
    ) async throws -> FileTreeNode {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Implement when file management endpoints are added to APIConfig.Endpoint
        // This would require adding:
        // case projectFiles(String) -> "/projects/{id}/files"
        // to the APIConfig.Endpoint enum
        
        // For now, return a mock node
        let node = FileTreeNode(
            name: name,
            path: parentPath.hasSuffix("/") ? "\(parentPath)\(name)" : "\(parentPath)/\(name)",
            isDirectory: isDirectory
        )
        
        // Invalidate cache for parent directory
        invalidateCache(for: parentPath)
        
        return node
    }
    
    /// Rename a file or directory
    public func renameFile(at path: String, newName: String) async throws -> FileTreeNode {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Implement when file management endpoints are added to APIConfig.Endpoint
        // For now, return a mock node
        let parentPath = URL(fileURLWithPath: path).deletingLastPathComponent().path
        let newPath = parentPath.hasSuffix("/") ? "\(parentPath)\(newName)" : "\(parentPath)/\(newName)"
        
        let node = FileTreeNode(
            name: newName,
            path: newPath,
            isDirectory: false
        )
        
        // Invalidate cache for parent directory
        invalidateCache(for: parentPath)
        
        return node
    }
    
    /// Delete a file or directory
    public func deleteFile(at path: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Implement when file management endpoints are added to APIConfig.Endpoint
        // For now, just clear cache
        
        // Invalidate cache for parent directory
        let parentPath = URL(fileURLWithPath: path).deletingLastPathComponent().path
        invalidateCache(for: parentPath)
    }
    
    /// Move a file or directory
    public func moveFile(from sourcePath: String, to destinationPath: String) async throws -> FileTreeNode {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Implement when file management endpoints are added to APIConfig.Endpoint
        // For now, return a mock node
        let fileName = URL(fileURLWithPath: destinationPath).lastPathComponent
        
        let node = FileTreeNode(
            name: fileName,
            path: destinationPath,
            isDirectory: false
        )
        
        // Invalidate cache for both source and destination directories
        let sourceParent = URL(fileURLWithPath: sourcePath).deletingLastPathComponent().path
        let destParent = URL(fileURLWithPath: destinationPath).deletingLastPathComponent().path
        invalidateCache(for: sourceParent)
        invalidateCache(for: destParent)
        
        return node
    }
    
    /// Copy a file or directory
    public func copyFile(from sourcePath: String, to destinationPath: String) async throws -> FileTreeNode {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Implement when file management endpoints are added to APIConfig.Endpoint
        // For now, return a mock node
        let fileName = URL(fileURLWithPath: destinationPath).lastPathComponent
        
        let node = FileTreeNode(
            name: fileName,
            path: destinationPath,
            isDirectory: false
        )
        
        // Invalidate cache for destination directory
        let destParent = URL(fileURLWithPath: destinationPath).deletingLastPathComponent().path
        invalidateCache(for: destParent)
        
        return node
    }
    
    /// Get file content
    public func getFileContent(at path: String) async throws -> String {
        // TODO: Implement when file management endpoints are added to APIConfig.Endpoint
        // For now, return empty content
        return "// File content would be loaded here"
    }
    
    /// Save file content
    public func saveFileContent(at path: String, content: String) async throws {
        // TODO: Implement when file management endpoints are added to APIConfig.Endpoint
        // For now, just clear cache
        
        // Invalidate cache for parent directory
        let parentPath = URL(fileURLWithPath: path).deletingLastPathComponent().path
        invalidateCache(for: parentPath)
    }
    
    // MARK: - Cache Management
    
    private func getCachedFiles(for path: String) -> [FileTreeNode]? {
        guard let timestamp = cacheTimestamps[path],
              Date().timeIntervalSince(timestamp) < cacheExpiration,
              let cached = fileCache[path] else {
            return nil
        }
        return cached
    }
    
    private func cacheFiles(_ files: [FileTreeNode], for path: String) {
        fileCache[path] = files
        cacheTimestamps[path] = Date()
    }
    
    private func invalidateCache(for path: String) {
        fileCache.removeValue(forKey: path)
        cacheTimestamps.removeValue(forKey: path)
    }
    
    /// Clear all cached data
    public func clearCache() {
        fileCache.removeAll()
        cacheTimestamps.removeAll()
    }
}

// MARK: - Error Types

public enum FileOperationError: LocalizedError {
    case operationFailed(String)
    case invalidPath
    case permissionDenied
    case fileNotFound
    case fileAlreadyExists
    
    public var errorDescription: String? {
        switch self {
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .invalidPath:
            return "Invalid file path"
        case .permissionDenied:
            return "Permission denied"
        case .fileNotFound:
            return "File not found"
        case .fileAlreadyExists:
            return "File already exists"
        }
    }
}

// MARK: - Additional Models

struct FileContentResponse: Codable {
    let content: String
    let encoding: String?
    let mimeType: String?
}

struct FileContentRequest: Codable {
    let path: String
    let content: String
    let encoding: String?
    
    init(path: String, content: String, encoding: String? = "utf-8") {
        self.path = path
        self.content = content
        self.encoding = encoding
    }
}