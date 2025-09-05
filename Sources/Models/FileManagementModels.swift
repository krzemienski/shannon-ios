//
//  FileManagementModels.swift
//  ClaudeCode
//
//  File management models and types
//

import Foundation
import SwiftUI
import Combine

// MARK: - File Upload Manager

/// Manages file upload operations
@MainActor
public class FileUploadManager: ObservableObject {
    // MARK: - Properties
    @Published public var activeTransfers: [FileTransfer] = []
    @Published public var uploadSpeed: Double = 0
    @Published public var totalBytesUploaded: Int64 = 0
    @Published public var isUploading = false
    
    private let apiClient: APIClient
    private var uploadTasks: [String: URLSessionUploadTask] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Upload Methods
    
    /// Upload a file transfer
    public func upload(transfer: FileTransfer, fileURL: URL) async throws {
        guard let data = try? Data(contentsOf: fileURL) else {
            throw FileTransferError.fileNotFound
        }
        
        try await uploadData(transfer: transfer, data: data, mimeType: "application/octet-stream")
    }
    
    /// Upload raw data
    public func uploadData(transfer: FileTransfer, data: Data, mimeType: String) async throws {
        transfer.status = .inProgress
        activeTransfers.append(transfer)
        isUploading = true
        
        do {
            // Simulate upload progress (in real implementation, use URLSession delegate)
            transfer.startTime = Date()
            
            // Create upload request
            let endpoint = "/projects/\(transfer.projectId)/files/upload"
            // Directly create URLRequest instead of using buildRequest
            guard let url = URL(string: "https://api.example.com\(endpoint)") else {
                throw FileTransferError.uploadFailed(NSError(domain: "Invalid URL", code: 0, userInfo: nil))
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            
            // Execute upload
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw FileTransferError.uploadFailed(NSError(domain: "Upload", code: 0, userInfo: nil))
            }
            
            // Update transfer status
            transfer.status = .completed
            transfer.progress = 1.0
            transfer.endTime = Date()
            transfer.bytesTransferred = Int64(data.count)
            totalBytesUploaded += transfer.bytesTransferred
            
            // Remove from active transfers
            activeTransfers.removeAll { $0.id == transfer.id }
            
        } catch {
            transfer.status = .failed
            transfer.error = error
            activeTransfers.removeAll { $0.id == transfer.id }
            throw FileTransferError.uploadFailed(error)
        }
        
        isUploading = !activeTransfers.isEmpty
    }
    
    /// Pause a transfer
    public func pauseTransfer(_ transferId: String) {
        if let task = uploadTasks[transferId] {
            task.suspend()
            activeTransfers.first { $0.id == transferId }?.status = .paused
        }
    }
    
    /// Resume a transfer
    public func resumeTransfer(_ transferId: String) {
        if let task = uploadTasks[transferId] {
            task.resume()
            activeTransfers.first { $0.id == transferId }?.status = .inProgress
        }
    }
    
    /// Cancel a transfer
    public func cancelTransfer(_ transferId: String) {
        if let task = uploadTasks[transferId] {
            task.cancel()
            uploadTasks.removeValue(forKey: transferId)
        }
        activeTransfers.removeAll { $0.id == transferId }
        isUploading = !activeTransfers.isEmpty
    }
}

// MARK: - File Download Manager

/// Manages file download operations
@MainActor
public class FileDownloadManager: ObservableObject {
    // MARK: - Properties
    @Published public var activeTransfers: [FileTransfer] = []
    @Published public var downloadSpeed: Double = 0
    @Published public var totalBytesDownloaded: Int64 = 0
    @Published public var isDownloading = false
    
    private let apiClient: APIClient
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Download Methods
    
    /// Download a file
    public func download(transfer: FileTransfer) async throws {
        transfer.status = .inProgress
        activeTransfers.append(transfer)
        isDownloading = true
        
        do {
            transfer.startTime = Date()
            
            // Create download request
            let endpoint = "/projects/\(transfer.projectId)/files/download"
            let params = ["path": transfer.remotePath ?? "", "file": transfer.fileName]
            // Directly create URLRequest instead of using buildRequest
            var urlComponents = URLComponents(string: "https://api.example.com\(endpoint)")
            urlComponents?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let url = urlComponents?.url else {
                throw FileTransferError.downloadFailed(NSError(domain: "Invalid URL", code: 0, userInfo: nil))
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            // Execute download
            let (localURL, response) = try await URLSession.shared.download(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw FileTransferError.downloadFailed(NSError(domain: "Download", code: 0, userInfo: nil))
            }
            
            // Move file to documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsPath.appendingPathComponent(transfer.fileName)
            
            try? FileManager.default.removeItem(at: destinationURL) // Remove if exists
            try FileManager.default.moveItem(at: localURL, to: destinationURL)
            
            // Update transfer
            transfer.localURL = destinationURL
            transfer.status = .completed
            transfer.progress = 1.0
            transfer.endTime = Date()
            
            // Get file size
            if let attributes = try? FileManager.default.attributesOfItem(atPath: destinationURL.path) {
                transfer.bytesTransferred = attributes[.size] as? Int64 ?? 0
                totalBytesDownloaded += transfer.bytesTransferred
            }
            
            // Remove from active transfers
            activeTransfers.removeAll { $0.id == transfer.id }
            
        } catch {
            transfer.status = .failed
            transfer.error = error
            activeTransfers.removeAll { $0.id == transfer.id }
            throw FileTransferError.downloadFailed(error)
        }
        
        isDownloading = !activeTransfers.isEmpty
    }
    
    /// Pause a transfer
    public func pauseTransfer(_ transferId: String) {
        if let task = downloadTasks[transferId] {
            task.suspend()
            activeTransfers.first { $0.id == transferId }?.status = .paused
        }
    }
    
    /// Resume a transfer
    public func resumeTransfer(_ transferId: String) {
        if let task = downloadTasks[transferId] {
            task.resume()
            activeTransfers.first { $0.id == transferId }?.status = .inProgress
        }
    }
    
    /// Cancel a transfer
    public func cancelTransfer(_ transferId: String) {
        if let task = downloadTasks[transferId] {
            task.cancel()
            downloadTasks.removeValue(forKey: transferId)
        }
        activeTransfers.removeAll { $0.id == transferId }
        isDownloading = !activeTransfers.isEmpty
    }
}

// MARK: - File Search Engine

/// Searches files within projects
@MainActor
public class FileSearchEngine: ObservableObject {
    // MARK: - Properties
    @Published public var searchResults: [FileTreeNode] = []
    @Published public var isSearching = false
    @Published public var searchQuery = ""
    @Published public var searchText: String = ""  // Alias for searchQuery
    @Published public var searchScope: SearchScope = .currentDirectory
    @Published public var searchFilter: SearchFilter = .all
    
    // Search options
    @Published public var caseSensitive = false
    @Published public var useRegex = false
    @Published public var includeHidden = false
    @Published public var searchInContent = false
    
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Search Types
    
    public enum SearchScope {
        case currentDirectory
        case recursive
        case project
    }
    
    public enum SearchFilter: String, CaseIterable {
        case all = "All Files"
        case code = "Code Files"
        case documents = "Documents"
        case images = "Images"
        case archives = "Archives"
        
        var extensions: [String] {
            switch self {
            case .all: return []
            case .code: return ["swift", "js", "ts", "py", "java", "cpp", "c", "h", "m", "go", "rs"]
            case .documents: return ["md", "txt", "pdf", "doc", "docx", "rtf", "tex"]
            case .images: return ["png", "jpg", "jpeg", "gif", "svg", "bmp", "tiff", "webp"]
            case .archives: return ["zip", "tar", "gz", "7z", "rar", "dmg"]
            }
        }
    }
    
    // MARK: - Search Methods
    
    /// Search for files matching the query
    public func search(in nodes: [FileTreeNode], query: String) async {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchQuery = query
        
        searchTask = Task { @MainActor in
            var results: [FileTreeNode] = []
            
            // Search recursively through nodes
            for node in nodes {
                if Task.isCancelled { break }
                
                let matches = searchNode(node, query: query)
                results.append(contentsOf: matches)
            }
            
            if !Task.isCancelled {
                self.searchResults = results
            }
            
            self.isSearching = false
        }
    }
    
    private func searchNode(_ node: FileTreeNode, query: String) -> [FileTreeNode] {
        var results: [FileTreeNode] = []
        
        // Check if filename matches
        let filename = node.name.lowercased()
        let searchTerm = caseSensitive ? query : query.lowercased()
        
        // Apply filter
        if searchFilter != .all {
            let fileExtension = (node.name as NSString).pathExtension.lowercased()
            if !searchFilter.extensions.contains(fileExtension) {
                // Skip if doesn't match filter, but still search children
                if let children = node.children {
                    for child in children {
                        results.append(contentsOf: searchNode(child, query: query))
                    }
                }
                return results
            }
        }
        
        // Check filename match
        if useRegex {
            if let regex = try? NSRegularExpression(pattern: searchTerm, options: caseSensitive ? [] : .caseInsensitive) {
                let range = NSRange(location: 0, length: node.name.utf16.count)
                if regex.firstMatch(in: node.name, options: [], range: range) != nil {
                    results.append(node)
                }
            }
        } else {
            if filename.contains(searchTerm) {
                results.append(node)
            }
        }
        
        // Search children if directory
        if node.isDirectory, let children = node.children {
            for child in children {
                if !includeHidden && child.name.hasPrefix(".") {
                    continue
                }
                results.append(contentsOf: searchNode(child, query: query))
            }
        }
        
        return results
    }
    
    /// Search in a single tree node
    public func searchInTree(_ root: FileTreeNode) async -> [FileTreeNode] {
        // Update searchQuery from searchText if it was set
        if !searchText.isEmpty {
            searchQuery = searchText
        }
        
        guard !searchQuery.isEmpty else {
            return []
        }
        
        // Search recursively starting from the root
        return searchNode(root, query: searchQuery)
    }
    
    /// Clear search results
    public func clearSearch() {
        searchTask?.cancel()
        searchResults = []
        searchQuery = ""
        searchText = ""
        isSearching = false
    }
}

// MARK: - Supporting Types

/// Breadcrumb item for navigation
public struct BreadcrumbItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let path: String
    public let icon: String?
    
    public init(title: String, path: String, icon: String? = nil) {
        self.title = title
        self.path = path
        self.icon = icon
    }
}

/// File operations service for managing file system operations
// FileOperationsService is defined in Services/FileOperationsService.swift