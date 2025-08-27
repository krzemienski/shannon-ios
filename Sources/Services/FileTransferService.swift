//
//  FileTransferService.swift
//  ClaudeCode
//
//  Core file transfer service for managing uploads and downloads
//

import Foundation
import SwiftUI
import Combine
import OSLog
import UniformTypeIdentifiers

/// Core service managing all file transfer operations
@MainActor
public class FileTransferService: ObservableObject {
    // MARK: - Singleton
    public static let shared = FileTransferService()
    
    // MARK: - Properties
    private let apiClient: APIClient
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "FileTransfer")
    
    // File management
    private let uploadManager: FileUploadManager
    private let downloadManager: FileDownloadManager
    private let fileCache = FileCache()
    
    // Transfer queues
    @Published public var activeUploads: [FileTransfer] = []
    @Published public var activeDownloads: [FileTransfer] = []
    @Published public var completedTransfers: [FileTransfer] = []
    @Published public var failedTransfers: [FileTransfer] = []
    
    // Transfer statistics
    @Published public var totalBytesUploaded: Int64 = 0
    @Published public var totalBytesDownloaded: Int64 = 0
    @Published public var currentUploadSpeed: Double = 0 // bytes per second
    @Published public var currentDownloadSpeed: Double = 0 // bytes per second
    
    // Settings
    @Published public var maxConcurrentUploads = 3
    @Published public var maxConcurrentDownloads = 5
    @Published public var autoCompressImages = true
    @Published public var compressionQuality: CGFloat = 0.8
    @Published public var maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB default
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - File Type Support
    public enum FileCategory {
        case image
        case document
        case code
        case archive
        case video
        case audio
        case other
        
        var allowedTypes: [UTType] {
            switch self {
            case .image:
                return [.png, .jpeg, .gif, .heic, .heif, .bmp, .tiff, .svg, .webP]
            case .document:
                return [.pdf, .text, .plainText, .rtf, .html, 
                       UTType(filenameExtension: "docx") ?? .data,
                       UTType(filenameExtension: "xlsx") ?? .data,
                       UTType(filenameExtension: "pptx") ?? .data,
                       UTType(filenameExtension: "md") ?? .plainText]
            case .code:
                return [.sourceCode, .swiftSource, .pythonScript, .javaScript,
                       UTType(filenameExtension: "ts") ?? .sourceCode,
                       UTType(filenameExtension: "jsx") ?? .sourceCode,
                       UTType(filenameExtension: "tsx") ?? .sourceCode,
                       UTType(filenameExtension: "go") ?? .sourceCode,
                       UTType(filenameExtension: "rs") ?? .sourceCode,
                       UTType(filenameExtension: "cpp") ?? .sourceCode,
                       UTType(filenameExtension: "java") ?? .sourceCode]
            case .archive:
                return [.zip, .archive,
                       UTType(filenameExtension: "tar") ?? .archive,
                       UTType(filenameExtension: "gz") ?? .archive,
                       UTType(filenameExtension: "rar") ?? .archive,
                       UTType(filenameExtension: "7z") ?? .archive]
            case .video:
                return [.movie, .video, .mpeg4Movie, .quickTimeMovie]
            case .audio:
                return [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
            case .other:
                return [.data, .content]
            }
        }
        
        var maxSizeLimit: Int64 {
            switch self {
            case .image: return 50 * 1024 * 1024 // 50MB
            case .document: return 100 * 1024 * 1024 // 100MB
            case .code: return 10 * 1024 * 1024 // 10MB
            case .archive: return 500 * 1024 * 1024 // 500MB
            case .video: return 1024 * 1024 * 1024 // 1GB
            case .audio: return 200 * 1024 * 1024 // 200MB
            case .other: return 100 * 1024 * 1024 // 100MB
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        self.apiClient = APIClient()
        self.uploadManager = FileUploadManager(apiClient: apiClient)
        self.downloadManager = FileDownloadManager(apiClient: apiClient)
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Monitor upload manager
        uploadManager.$activeTransfers
            .sink { [weak self] transfers in
                self?.activeUploads = transfers
            }
            .store(in: &cancellables)
        
        uploadManager.$uploadSpeed
            .sink { [weak self] speed in
                self?.currentUploadSpeed = speed
            }
            .store(in: &cancellables)
        
        // Monitor download manager
        downloadManager.$activeTransfers
            .sink { [weak self] transfers in
                self?.activeDownloads = transfers
            }
            .store(in: &cancellables)
        
        downloadManager.$downloadSpeed
            .sink { [weak self] speed in
                self?.currentDownloadSpeed = speed
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Upload Methods
    
    /// Upload a single file
    public func uploadFile(
        url: URL,
        to projectId: String,
        path: String? = nil,
        compress: Bool? = nil
    ) async throws -> FileTransfer {
        // Validate file
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileTransferError.fileNotFound
        }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        guard fileSize <= maxFileSize else {
            throw FileTransferError.fileTooLarge(size: fileSize, limit: maxFileSize)
        }
        
        // Determine file category
        let fileType = UTType(filenameExtension: url.pathExtension) ?? .data
        let category = categorizeFile(type: fileType)
        
        guard fileSize <= category.maxSizeLimit else {
            throw FileTransferError.fileTooLarge(size: fileSize, limit: category.maxSizeLimit)
        }
        
        // Create transfer
        let transfer = FileTransfer(
            id: UUID().uuidString,
            fileName: url.lastPathComponent,
            fileSize: fileSize,
            direction: .upload,
            projectId: projectId,
            remotePath: path ?? "/",
            localURL: url
        )
        
        // Process file if needed
        let processedURL: URL
        if let shouldCompress = compress, shouldCompress,
           category == .image && autoCompressImages {
            processedURL = try await compressImage(at: url)
        } else {
            processedURL = url
        }
        
        // Start upload
        try await uploadManager.upload(transfer: transfer, fileURL: processedURL)
        
        return transfer
    }
    
    /// Upload multiple files
    public func uploadFiles(
        urls: [URL],
        to projectId: String,
        path: String? = nil
    ) async throws -> [FileTransfer] {
        var transfers: [FileTransfer] = []
        
        for url in urls {
            do {
                let transfer = try await uploadFile(url: url, to: projectId, path: path)
                transfers.append(transfer)
            } catch {
                logger.error("Failed to upload \(url.lastPathComponent): \(error)")
            }
        }
        
        return transfers
    }
    
    /// Upload data directly
    public func uploadData(
        _ data: Data,
        fileName: String,
        to projectId: String,
        mimeType: String = "application/octet-stream"
    ) async throws -> FileTransfer {
        let transfer = FileTransfer(
            id: UUID().uuidString,
            fileName: fileName,
            fileSize: Int64(data.count),
            direction: .upload,
            projectId: projectId
        )
        
        try await uploadManager.uploadData(
            transfer: transfer,
            data: data,
            mimeType: mimeType
        )
        
        return transfer
    }
    
    // MARK: - Download Methods
    
    /// Download a file
    public func downloadFile(
        fileName: String,
        from projectId: String,
        remotePath: String
    ) async throws -> FileTransfer {
        let transfer = FileTransfer(
            id: UUID().uuidString,
            fileName: fileName,
            direction: .download,
            projectId: projectId,
            remotePath: remotePath
        )
        
        // Check cache first
        if let cachedURL = fileCache.getCachedFile(for: transfer.cacheKey) {
            transfer.localURL = cachedURL
            transfer.status = .completed
            transfer.progress = 1.0
            completedTransfers.append(transfer)
            return transfer
        }
        
        // Start download
        try await downloadManager.download(transfer: transfer)
        
        return transfer
    }
    
    /// Download multiple files
    public func downloadFiles(
        fileNames: [String],
        from projectId: String,
        remotePath: String
    ) async throws -> [FileTransfer] {
        var transfers: [FileTransfer] = []
        
        await withTaskGroup(of: FileTransfer?.self) { group in
            for fileName in fileNames {
                group.addTask {
                    do {
                        return try await self.downloadFile(
                            fileName: fileName,
                            from: projectId,
                            remotePath: remotePath
                        )
                    } catch {
                        self.logger.error("Failed to download \(fileName): \(error)")
                        return nil
                    }
                }
            }
            
            for await transfer in group {
                if let transfer = transfer {
                    transfers.append(transfer)
                }
            }
        }
        
        return transfers
    }
    
    // MARK: - Transfer Management
    
    /// Pause a transfer
    public func pauseTransfer(_ transferId: String) {
        if let index = activeUploads.firstIndex(where: { $0.id == transferId }) {
            activeUploads[index].status = .paused
            uploadManager.pauseTransfer(transferId)
        } else if let index = activeDownloads.firstIndex(where: { $0.id == transferId }) {
            activeDownloads[index].status = .paused
            downloadManager.pauseTransfer(transferId)
        }
    }
    
    /// Resume a transfer
    public func resumeTransfer(_ transferId: String) {
        if let transfer = activeUploads.first(where: { $0.id == transferId }) {
            transfer.status = .inProgress
            uploadManager.resumeTransfer(transferId)
        } else if let transfer = activeDownloads.first(where: { $0.id == transferId }) {
            transfer.status = .inProgress
            downloadManager.resumeTransfer(transferId)
        }
    }
    
    /// Cancel a transfer
    public func cancelTransfer(_ transferId: String) {
        if let index = activeUploads.firstIndex(where: { $0.id == transferId }) {
            let transfer = activeUploads[index]
            transfer.status = .cancelled
            uploadManager.cancelTransfer(transferId)
            activeUploads.remove(at: index)
            failedTransfers.append(transfer)
        } else if let index = activeDownloads.firstIndex(where: { $0.id == transferId }) {
            let transfer = activeDownloads[index]
            transfer.status = .cancelled
            downloadManager.cancelTransfer(transferId)
            activeDownloads.remove(at: index)
            failedTransfers.append(transfer)
        }
    }
    
    /// Retry a failed transfer
    public func retryTransfer(_ transferId: String) async throws {
        guard let transfer = failedTransfers.first(where: { $0.id == transferId }) else {
            return
        }
        
        transfer.status = .pending
        transfer.progress = 0
        transfer.error = nil
        
        if transfer.direction == .upload {
            if let localURL = transfer.localURL {
                try await uploadFile(url: localURL, to: transfer.projectId, path: transfer.remotePath)
            }
        } else {
            try await downloadFile(
                fileName: transfer.fileName,
                from: transfer.projectId,
                remotePath: transfer.remotePath ?? "/"
            )
        }
        
        // Remove from failed list
        failedTransfers.removeAll { $0.id == transferId }
    }
    
    // MARK: - Helper Methods
    
    private func categorizeFile(type: UTType) -> FileCategory {
        if type.conforms(to: .image) {
            return .image
        } else if type.conforms(to: .pdf) || type.conforms(to: .text) {
            return .document
        } else if type.conforms(to: .sourceCode) {
            return .code
        } else if type.conforms(to: .archive) || type.conforms(to: .zip) {
            return .archive
        } else if type.conforms(to: .movie) || type.conforms(to: .video) {
            return .video
        } else if type.conforms(to: .audio) {
            return .audio
        } else {
            return .other
        }
    }
    
    private func compressImage(at url: URL) async throws -> URL {
        guard let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            return url
        }
        
        let compressedData = image.jpegData(compressionQuality: compressionQuality) ?? imageData
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        try compressedData.write(to: tempURL)
        
        return tempURL
    }
    
    // MARK: - Statistics
    
    public func getTransferStatistics() -> TransferStatistics {
        return TransferStatistics(
            totalUploaded: totalBytesUploaded,
            totalDownloaded: totalBytesDownloaded,
            activeUploads: activeUploads.count,
            activeDownloads: activeDownloads.count,
            completedCount: completedTransfers.count,
            failedCount: failedTransfers.count,
            averageUploadSpeed: currentUploadSpeed,
            averageDownloadSpeed: currentDownloadSpeed
        )
    }
    
    /// Clear completed transfers
    public func clearCompletedTransfers() {
        completedTransfers.removeAll()
    }
    
    /// Clear failed transfers
    public func clearFailedTransfers() {
        failedTransfers.removeAll()
    }
}

// MARK: - Supporting Types

/// File transfer model
@MainActor
public class FileTransfer: ObservableObject, Identifiable {
    public let id: String
    public let fileName: String
    public let fileSize: Int64
    public let direction: TransferDirection
    public let projectId: String
    public var remotePath: String?
    
    @Published public var status: TransferStatus = .pending
    @Published public var progress: Double = 0
    @Published public var bytesTransferred: Int64 = 0
    @Published public var speed: Double = 0 // bytes per second
    @Published public var remainingTime: TimeInterval = 0
    @Published public var error: Error?
    @Published public var localURL: URL?
    
    public var startTime: Date?
    public var endTime: Date?
    
    public var cacheKey: String {
        "\(projectId)_\(remotePath ?? "")_\(fileName)"
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    public var formattedProgress: String {
        "\(Int(progress * 100))%"
    }
    
    public var formattedSpeed: String {
        guard speed > 0 else { return "0 KB/s" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return "\(formatter.string(fromByteCount: Int64(speed)))/s"
    }
    
    public var formattedRemainingTime: String {
        guard remainingTime > 0 else { return "--:--" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: remainingTime) ?? "--:--"
    }
    
    init(id: String, 
         fileName: String, 
         fileSize: Int64 = 0,
         direction: TransferDirection,
         projectId: String,
         remotePath: String? = nil,
         localURL: URL? = nil) {
        self.id = id
        self.fileName = fileName
        self.fileSize = fileSize
        self.direction = direction
        self.projectId = projectId
        self.remotePath = remotePath
        self.localURL = localURL
    }
}

public enum TransferDirection {
    case upload
    case download
}

public enum TransferStatus {
    case pending
    case inProgress
    case paused
    case completed
    case failed
    case cancelled
}

public struct TransferStatistics {
    public let totalUploaded: Int64
    public let totalDownloaded: Int64
    public let activeUploads: Int
    public let activeDownloads: Int
    public let completedCount: Int
    public let failedCount: Int
    public let averageUploadSpeed: Double
    public let averageDownloadSpeed: Double
}

public enum FileTransferError: LocalizedError {
    case fileNotFound
    case fileTooLarge(size: Int64, limit: Int64)
    case invalidFileType
    case uploadFailed(Error)
    case downloadFailed(Error)
    case networkError(Error)
    case serverError(String)
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .fileTooLarge(let size, let limit):
            let formatter = ByteCountFormatter()
            return "File size (\(formatter.string(fromByteCount: size))) exceeds limit (\(formatter.string(fromByteCount: limit)))"
        case .invalidFileType:
            return "Invalid file type"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .cancelled:
            return "Transfer cancelled"
        }
    }
}

// MARK: - File Cache

class FileCache {
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("FileTransferCache")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func getCachedFile(for key: String) -> URL? {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // Check if cache is still valid
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let modificationDate = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) > maxCacheAge {
            // Cache expired
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        
        return fileURL
    }
    
    func cacheFile(at url: URL, for key: String) throws {
        let cacheURL = cacheDirectory.appendingPathComponent(key.sha256())
        
        // Remove existing cache if it exists
        try? FileManager.default.removeItem(at: cacheURL)
        
        // Copy file to cache
        try FileManager.default.copyItem(at: url, to: cacheURL)
        
        // Clean old cache if needed
        cleanCacheIfNeeded()
    }
    
    private func cleanCacheIfNeeded() {
        // Implementation for cache cleanup based on size and age
    }
}

// SHA256 extension for cache keys
extension String {
    func sha256() -> String {
        // Simple hash for cache key - in production use CryptoKit
        self.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
    }
}