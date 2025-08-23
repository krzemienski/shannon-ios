//
//  SSHFileTransfer.swift
//  ClaudeCode
//
//  SCP/SFTP file transfer with progress callbacks (Tasks 469-473)
//

import Foundation
// Temporarily disabled for UI testing
// import Citadel
// import NIO
import Combine
import OSLog

/// SSH file transfer manager supporting SCP and SFTP
@MainActor
public class SSHFileTransfer: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var activeTransfers: [TransferOperation] = []
    @Published public private(set) var isTransferring = false
    
    // MARK: - Private Properties
    
    private let client: SSHClient
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHFileTransfer")
    private var sftpClient: SFTPClient?
    private let transferQueue = DispatchQueue(label: "com.claudecode.ssh.transfer", qos: .background)
    private let monitor = SSHMonitoringCoordinator.shared
    
    // Configuration
    private let chunkSize: Int = 32768 // 32KB chunks
    private let maxConcurrentTransfers = 3
    
    // Session tracking
    private var sessionId: String?
    private var hostInfo: (host: String, port: Int)?
    
    // MARK: - Initialization
    
    public init(client: SSHClient, sessionId: String? = nil, host: String? = nil, port: Int? = nil) {
        self.client = client
        self.sessionId = sessionId
        if let host = host, let port = port {
            self.hostInfo = (host, port)
        }
    }
    
    // MARK: - SFTP Session Management
    
    /// Open SFTP session
    private func ensureSFTPSession() async throws -> SFTPClient {
        if let sftp = sftpClient {
            return sftp
        }
        
        let sftp = try await client.openSFTP()
        self.sftpClient = sftp
        return sftp
    }
    
    /// Close SFTP session
    public func closeSFTPSession() async {
        sftpClient = nil
    }
    
    // MARK: - File Upload
    
    /// Upload a file to remote server
    public func uploadFile(
        localPath: String,
        remotePath: String,
        overwrite: Bool = true,
        progressHandler: ((TransferProgress) -> Void)? = nil
    ) async throws {
        
        let operation = TransferOperation(
            id: UUID().uuidString,
            type: .upload,
            localPath: localPath,
            remotePath: remotePath,
            status: .pending
        )
        
        activeTransfers.append(operation)
        isTransferring = true
        
        defer {
            activeTransfers.removeAll { $0.id == operation.id }
            isTransferring = !activeTransfers.isEmpty
        }
        
        logger.info("Starting upload: \(localPath) -> \(remotePath)")
        
        // Start monitoring
        let host = hostInfo?.host ?? "unknown"
        let port = hostInfo?.port ?? 22
        let operationId = monitor.startOperation(
            type: .fileTransfer,
            host: host,
            port: port,
            sessionId: sessionId,
            metadata: [
                "operation": "upload",
                "localPath": localPath,
                "remotePath": remotePath
            ]
        )
        
        // Update status
        updateOperationStatus(operation.id, status: .connecting)
        
        // Get file info
        let fileURL = URL(fileURLWithPath: localPath)
        guard FileManager.default.fileExists(atPath: localPath) else {
            monitor.completeOperation(operationId, success: false, sessionId: sessionId, error: "File not found: \(localPath)")
            throw SSHFileTransferError.fileNotFound(localPath)
        }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: localPath)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Create progress tracker
        let progress = TransferProgress(
            totalBytes: fileSize,
            transferredBytes: 0,
            fileName: fileURL.lastPathComponent,
            startTime: Date()
        )
        
        updateOperationStatus(operation.id, status: .transferring)
        
        do {
            // Ensure SFTP session
            let sftp = try await ensureSFTPSession()
            
            // Check if remote file exists
            if !overwrite {
                if try await remoteFileExists(remotePath, sftp: sftp) {
                    monitor.completeOperation(operationId, success: false, sessionId: sessionId, error: "File exists: \(remotePath)")
                    throw SSHFileTransferError.fileExists(remotePath)
                }
            }
            
            // Read file data
            let fileData = try Data(contentsOf: fileURL)
            
            // Upload in chunks for progress tracking
            try await uploadDataInChunks(
                data: fileData,
                to: remotePath,
                sftp: sftp,
                progress: progress,
                progressHandler: progressHandler
            )
            
            // Complete monitoring with success
            monitor.completeOperation(
                operationId,
                success: true,
                sessionId: sessionId,
                bytesTransferred: fileSize
            )
            
            // Track bytes in session monitor
            if let sessionId = sessionId,
               let sessionMonitor = monitor.sessionMonitors[sessionId] {
                sessionMonitor.trackBytesTransferred(fileSize)
            }
            
            updateOperationStatus(operation.id, status: .completed)
            logger.info("Upload completed: \(localPath)")
            
        } catch {
            updateOperationStatus(operation.id, status: .failed(error.localizedDescription))
            
            // Complete monitoring with failure
            monitor.completeOperation(
                operationId,
                success: false,
                sessionId: sessionId,
                error: error.localizedDescription
            )
            
            logger.error("Upload failed: \(error)")
            throw error
        }
    }
    
    /// Upload data in chunks with progress tracking
    private func uploadDataInChunks(
        data: Data,
        to remotePath: String,
        sftp: SFTPClient,
        progress: TransferProgress,
        progressHandler: ((TransferProgress) -> Void)?
    ) async throws {
        
        let totalSize = data.count
        var offset = 0
        
        // Create or truncate remote file
        let file = try await sftp.openFile(
            filePath: remotePath,
            flags: .write
        )
        
        defer {
            Task {
                try? await file.close()
            }
        }
        
        while offset < totalSize {
            let chunkEnd = min(offset + chunkSize, totalSize)
            let chunk = data[offset..<chunkEnd]
            
            // Write chunk
            try await file.write(chunk, at: UInt64(offset))
            
            offset = chunkEnd
            
            // Update progress
            progress.transferredBytes = Int64(offset)
            progress.updateMetrics()
            progressHandler?(progress)
            
            // Allow other operations
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
    }
    
    // MARK: - File Download
    
    /// Download a file from remote server
    public func downloadFile(
        remotePath: String,
        localPath: String,
        overwrite: Bool = true,
        progressHandler: ((TransferProgress) -> Void)? = nil
    ) async throws {
        
        let operation = TransferOperation(
            id: UUID().uuidString,
            type: .download,
            localPath: localPath,
            remotePath: remotePath,
            status: .pending
        )
        
        activeTransfers.append(operation)
        isTransferring = true
        
        defer {
            activeTransfers.removeAll { $0.id == operation.id }
            isTransferring = !activeTransfers.isEmpty
        }
        
        logger.info("Starting download: \(remotePath) -> \(localPath)")
        
        updateOperationStatus(operation.id, status: .connecting)
        
        // Check local file
        let fileURL = URL(fileURLWithPath: localPath)
        if !overwrite && FileManager.default.fileExists(atPath: localPath) {
            throw SSHFileTransferError.fileExists(localPath)
        }
        
        // Create parent directory if needed
        let parentDir = fileURL.deletingLastPathComponent().path
        try FileManager.default.createDirectory(
            atPath: parentDir,
            withIntermediateDirectories: true
        )
        
        updateOperationStatus(operation.id, status: .transferring)
        
        do {
            // Ensure SFTP session
            let sftp = try await ensureSFTPSession()
            
            // Get remote file info
            let attributes = try await sftp.stat(remotePath)
            let fileSize = Int64(attributes.size ?? 0)
            
            // Create progress tracker
            let progress = TransferProgress(
                totalBytes: fileSize,
                transferredBytes: 0,
                fileName: URL(fileURLWithPath: remotePath).lastPathComponent,
                startTime: Date()
            )
            
            // Download in chunks
            let data = try await downloadDataInChunks(
                from: remotePath,
                sftp: sftp,
                fileSize: fileSize,
                progress: progress,
                progressHandler: progressHandler
            )
            
            // Write to local file
            try data.write(to: fileURL)
            
            updateOperationStatus(operation.id, status: .completed)
            logger.info("Download completed: \(remotePath)")
            
        } catch {
            updateOperationStatus(operation.id, status: .failed(error.localizedDescription))
            logger.error("Download failed: \(error)")
            throw error
        }
    }
    
    /// Download data in chunks with progress tracking
    private func downloadDataInChunks(
        from remotePath: String,
        sftp: SFTPClient,
        fileSize: Int64,
        progress: TransferProgress,
        progressHandler: ((TransferProgress) -> Void)?
    ) async throws -> Data {
        
        var data = Data()
        var offset: UInt64 = 0
        
        // Open remote file
        let file = try await sftp.openFile(
            filePath: remotePath,
            flags: .read
        )
        
        defer {
            Task {
                try? await file.close()
            }
        }
        
        while offset < UInt64(fileSize) {
            let chunkSize = min(self.chunkSize, Int(UInt64(fileSize) - offset))
            
            // Read chunk
            let buffer = try await file.read(
                from: offset,
                length: UInt32(chunkSize)
            )
            
            // buffer is Data, so append directly
            data.append(buffer)
            
            offset += UInt64(chunkSize)
            
            // Update progress
            progress.transferredBytes = Int64(offset)
            progress.updateMetrics()
            progressHandler?(progress)
            
            // Allow other operations
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        return data
    }
    
    // MARK: - Directory Operations
    
    /// Upload directory recursively
    public func uploadDirectory(
        localPath: String,
        remotePath: String,
        excludePatterns: [String] = [],
        progressHandler: ((DirectoryTransferProgress) -> Void)? = nil
    ) async throws {
        
        let progress = DirectoryTransferProgress()
        
        // Get all files to upload
        let files = try listLocalFiles(
            at: localPath,
            excludePatterns: excludePatterns
        )
        
        progress.totalFiles = files.count
        progressHandler?(progress)
        
        // Ensure remote directory exists
        let sftp = try await ensureSFTPSession()
        try await createRemoteDirectory(remotePath, sftp: sftp)
        
        // Upload each file
        for (index, file) in files.enumerated() {
            progress.currentFile = index + 1
            progress.currentFileName = file.relativePath
            progressHandler?(progress)
            
            let localFilePath = URL(fileURLWithPath: localPath)
                .appendingPathComponent(file.relativePath)
                .path
            
            let remoteFilePath = "\(remotePath)/\(file.relativePath)"
            
            do {
                try await uploadFile(
                    localPath: localFilePath,
                    remotePath: remoteFilePath,
                    progressHandler: { fileProgress in
                        progress.currentFileProgress = fileProgress
                        progressHandler?(progress)
                    }
                )
                progress.successCount += 1
            } catch {
                progress.errors.append(
                    TransferError(
                        file: file.relativePath,
                        error: error.localizedDescription
                    )
                )
            }
        }
        
        progress.isComplete = true
        progressHandler?(progress)
    }
    
    /// Download directory recursively
    public func downloadDirectory(
        remotePath: String,
        localPath: String,
        excludePatterns: [String] = [],
        progressHandler: ((DirectoryTransferProgress) -> Void)? = nil
    ) async throws {
        
        let progress = DirectoryTransferProgress()
        
        // List remote files
        let sftp = try await ensureSFTPSession()
        let files = try await listRemoteFiles(
            at: remotePath,
            sftp: sftp,
            excludePatterns: excludePatterns
        )
        
        progress.totalFiles = files.count
        progressHandler?(progress)
        
        // Create local directory
        try FileManager.default.createDirectory(
            atPath: localPath,
            withIntermediateDirectories: true
        )
        
        // Download each file
        for (index, file) in files.enumerated() {
            progress.currentFile = index + 1
            progress.currentFileName = file.relativePath
            progressHandler?(progress)
            
            let remoteFilePath = "\(remotePath)/\(file.relativePath)"
            
            let localFilePath = URL(fileURLWithPath: localPath)
                .appendingPathComponent(file.relativePath)
                .path
            
            // Create parent directory
            let parentDir = URL(fileURLWithPath: localFilePath)
                .deletingLastPathComponent()
                .path
            try FileManager.default.createDirectory(
                atPath: parentDir,
                withIntermediateDirectories: true
            )
            
            do {
                try await downloadFile(
                    remotePath: remoteFilePath,
                    localPath: localFilePath,
                    progressHandler: { fileProgress in
                        progress.currentFileProgress = fileProgress
                        progressHandler?(progress)
                    }
                )
                progress.successCount += 1
            } catch {
                progress.errors.append(
                    TransferError(
                        file: file.relativePath,
                        error: error.localizedDescription
                    )
                )
            }
        }
        
        progress.isComplete = true
        progressHandler?(progress)
    }
    
    // MARK: - Helper Methods
    
    /// Check if remote file exists
    private func remoteFileExists(_ path: String, sftp: SFTPClient) async throws -> Bool {
        do {
            _ = try await sftp.stat(path)
            return true
        } catch {
            return false
        }
    }
    
    /// Create remote directory
    private func createRemoteDirectory(_ path: String, sftp: SFTPClient) async throws {
        do {
            try await sftp.createDirectory(atPath: path)
        } catch {
            // Directory might already exist
            logger.warning("Could not create directory \(path): \(error)")
        }
    }
    
    /// List local files recursively
    private func listLocalFiles(
        at path: String,
        excludePatterns: [String]
    ) throws -> [FileInfo] {
        
        var files: [FileInfo] = []
        let baseURL = URL(fileURLWithPath: path)
        
        if let enumerator = FileManager.default.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
        ) {
            for case let fileURL as URL in enumerator {
                let attributes = try fileURL.resourceValues(
                    forKeys: [.isRegularFileKey, .fileSizeKey]
                )
                
                if attributes.isRegularFile == true {
                    let relativePath = fileURL.path
                        .replacingOccurrences(of: baseURL.path + "/", with: "")
                    
                    // Check exclude patterns
                    if !shouldExclude(relativePath, patterns: excludePatterns) {
                        files.append(FileInfo(
                            relativePath: relativePath,
                            size: Int64(attributes.fileSize ?? 0)
                        ))
                    }
                }
            }
        }
        
        return files
    }
    
    /// List remote files recursively
    private func listRemoteFiles(
        at path: String,
        sftp: SFTPClient,
        excludePatterns: [String],
        currentPath: String = ""
    ) async throws -> [FileInfo] {
        
        var files: [FileInfo] = []
        
        let entries = try await sftp.listDirectory(atPath: path)
        
        for entry in entries {
            // Skip . and ..
            // The entry type depends on Citadel's API - let's assume it's a SFTPPathComponent
            let filename: String
            let attributes: SFTPFileAttributes
            
            // Handle different possible return types from Citadel
            if let component = entry as? SFTPPathComponent {
                filename = component.filename
                attributes = component.attributes
            } else {
                // Skip if we can't get filename
                continue
            }
            
            if filename == "." || filename == ".." {
                continue
            }
            
            let fullPath = "\(path)/\(filename)"
            let relativePath = currentPath.isEmpty
                ? filename
                : "\(currentPath)/\(filename)"
            
            if shouldExclude(relativePath, patterns: excludePatterns) {
                continue
            }
            
            // Check if it's a directory using attributes
            let isDirectory = attributes.permissions?.fileType == .directory
            
            if isDirectory {
                // Recursively list subdirectory
                let subFiles = try await listRemoteFiles(
                    at: fullPath,
                    sftp: sftp,
                    excludePatterns: excludePatterns,
                    currentPath: relativePath
                )
                files.append(contentsOf: subFiles)
            } else {
                files.append(FileInfo(
                    relativePath: relativePath,
                    size: Int64(attributes?.size ?? 0)
                ))
            }
        }
        
        return files
    }
    
    /// Check if file should be excluded
    private func shouldExclude(_ path: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if path.contains(pattern) {
                return true
            }
        }
        return false
    }
    
    /// Update operation status
    private func updateOperationStatus(_ id: String, status: TransferStatus) {
        if let index = activeTransfers.firstIndex(where: { $0.id == id }) {
            activeTransfers[index].status = status
            activeTransfers[index].lastUpdate = Date()
        }
    }
}

// MARK: - Supporting Types

/// Transfer operation
public struct TransferOperation: Identifiable {
    public let id: String
    public let type: TransferType
    public let localPath: String
    public let remotePath: String
    public var status: TransferStatus
    public var lastUpdate: Date = Date()
}

/// Transfer type
public enum TransferType {
    case upload
    case download
}

/// Transfer status
public enum TransferStatus {
    case pending
    case connecting
    case transferring
    case completed
    case failed(String)
    case cancelled
}

/// Transfer progress
public class TransferProgress {
    public let totalBytes: Int64
    public var transferredBytes: Int64
    public let fileName: String
    public let startTime: Date
    public var endTime: Date?
    public var currentSpeed: Double = 0 // bytes per second
    public var averageSpeed: Double = 0
    public var estimatedTimeRemaining: TimeInterval?
    
    public init(
        totalBytes: Int64,
        transferredBytes: Int64,
        fileName: String,
        startTime: Date
    ) {
        self.totalBytes = totalBytes
        self.transferredBytes = transferredBytes
        self.fileName = fileName
        self.startTime = startTime
    }
    
    public var progress: Double {
        totalBytes > 0 ? Double(transferredBytes) / Double(totalBytes) : 0
    }
    
    public var progressPercentage: Int {
        Int(progress * 100)
    }
    
    public func updateMetrics() {
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > 0 {
            averageSpeed = Double(transferredBytes) / elapsed
            
            if averageSpeed > 0 {
                let remaining = totalBytes - transferredBytes
                estimatedTimeRemaining = TimeInterval(Double(remaining) / averageSpeed)
            }
        }
    }
}

/// Directory transfer progress
public class DirectoryTransferProgress {
    public var totalFiles: Int = 0
    public var currentFile: Int = 0
    public var currentFileName: String = ""
    public var currentFileProgress: TransferProgress?
    public var successCount: Int = 0
    public var errors: [TransferError] = []
    public var isComplete: Bool = false
    
    public var progress: Double {
        totalFiles > 0 ? Double(currentFile) / Double(totalFiles) : 0
    }
}

/// Transfer error
public struct TransferError {
    public let file: String
    public let error: String
}

/// File info
struct FileInfo {
    let relativePath: String
    let size: Int64
}

/// SSH file transfer errors
public enum SSHFileTransferError: LocalizedError {
    case fileNotFound(String)
    case fileExists(String)
    case permissionDenied(String)
    case transferFailed(String)
    case sftpNotAvailable
    case invalidPath(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileExists(let path):
            return "File already exists: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .transferFailed(let reason):
            return "Transfer failed: \(reason)"
        case .sftpNotAvailable:
            return "SFTP session is not available"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        }
    }
}