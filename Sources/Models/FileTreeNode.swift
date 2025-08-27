import Foundation
import SwiftUI

/// Represents a file or folder node in the file tree
public struct FileTreeNode: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64?
    public let modifiedDate: Date?
    public let createdDate: Date?
    public let permissions: String?
    public let mimeType: String?
    public let `extension`: String?
    public var children: [FileTreeNode]?
    public let gitStatus: GitStatus?
    public let isSymlink: Bool
    public let symlinkTarget: String?
    public let isHidden: Bool
    
    /// Computed property for file type detection
    public var fileType: FileType {
        if isDirectory {
            return .directory
        }
        
        guard let ext = self.extension?.lowercased() else {
            return .unknown
        }
        
        return FileType.from(extension: ext)
    }
    
    /// Initialize from backend response
    public init(
        id: String? = nil,
        name: String,
        path: String,
        isDirectory: Bool,
        size: Int64? = nil,
        modifiedDate: Date? = nil,
        createdDate: Date? = nil,
        permissions: String? = nil,
        mimeType: String? = nil,
        extension: String? = nil,
        children: [FileTreeNode]? = nil,
        gitStatus: GitStatus? = nil,
        isSymlink: Bool = false,
        symlinkTarget: String? = nil,
        isHidden: Bool = false
    ) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedDate = modifiedDate
        self.createdDate = createdDate
        self.permissions = permissions
        self.mimeType = mimeType
        self.extension = extension ?? URL(fileURLWithPath: name).pathExtension.isEmpty ? nil : URL(fileURLWithPath: name).pathExtension
        self.children = children
        self.gitStatus = gitStatus
        self.isSymlink = isSymlink
        self.symlinkTarget = symlinkTarget
        self.isHidden = isHidden || name.hasPrefix(".")
    }
    
    /// Hash function for Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(path)
    }
    
    /// Equality for Hashable conformance
    public static func == (lhs: FileTreeNode, rhs: FileTreeNode) -> Bool {
        lhs.id == rhs.id && lhs.path == rhs.path
    }
}

// MARK: - File Type

public enum FileType: String, CaseIterable {
    case directory
    case swift
    case javascript
    case typescript
    case python
    case java
    case csharp
    case cpp
    case c
    case header
    case html
    case css
    case json
    case xml
    case yaml
    case markdown
    case text
    case image
    case video
    case audio
    case pdf
    case archive
    case binary
    case configuration
    case database
    case font
    case unknown
    
    /// Get file type from extension
    static func from(extension ext: String) -> FileType {
        switch ext.lowercased() {
        case "swift": return .swift
        case "js", "mjs", "cjs": return .javascript
        case "ts", "tsx", "jsx": return .typescript
        case "py", "pyw": return .python
        case "java": return .java
        case "cs": return .csharp
        case "cpp", "cc", "cxx", "c++": return .cpp
        case "c": return .c
        case "h", "hpp", "hxx": return .header
        case "html", "htm": return .html
        case "css", "scss", "sass", "less": return .css
        case "json", "jsonc": return .json
        case "xml", "xsl", "xslt": return .xml
        case "yml", "yaml": return .yaml
        case "md", "markdown": return .markdown
        case "txt", "log": return .text
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "ico": return .image
        case "mp4", "mov", "avi", "mkv", "webm": return .video
        case "mp3", "wav", "flac", "aac", "ogg": return .audio
        case "pdf": return .pdf
        case "zip", "tar", "gz", "7z", "rar": return .archive
        case "exe", "dll", "so", "dylib": return .binary
        case "conf", "config", "ini", "toml", "env": return .configuration
        case "db", "sqlite", "sqlite3": return .database
        case "ttf", "otf", "woff", "woff2": return .font
        default: return .unknown
        }
    }
    
    /// System icon name for the file type
    var systemIcon: String {
        switch self {
        case .directory: return "folder.fill"
        case .swift: return "swift"
        case .javascript, .typescript: return "curlybraces"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .java, .csharp, .cpp, .c: return "terminal"
        case .header: return "h.square"
        case .html: return "globe"
        case .css: return "paintbrush"
        case .json, .xml, .yaml: return "doc.text"
        case .markdown: return "text.alignleft"
        case .text: return "doc.plaintext"
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "speaker.wave.2"
        case .pdf: return "doc.richtext"
        case .archive: return "archivebox"
        case .binary: return "gearshape"
        case .configuration: return "gear"
        case .database: return "cylinder"
        case .font: return "textformat"
        case .unknown: return "doc"
        }
    }
    
    /// Icon color for the file type
    var iconColor: Color {
        switch self {
        case .directory: return .blue
        case .swift: return .orange
        case .javascript: return .yellow
        case .typescript: return .blue
        case .python: return Color(red: 0.2, green: 0.5, blue: 0.7)
        case .java: return .red
        case .csharp: return .purple
        case .cpp, .c, .header: return Color(red: 0.0, green: 0.4, blue: 0.8)
        case .html: return .orange
        case .css: return .blue
        case .json, .xml, .yaml: return .green
        case .markdown: return .gray
        case .text: return .secondary
        case .image: return .purple
        case .video: return .red
        case .audio: return .pink
        case .pdf: return .red
        case .archive: return .brown
        case .binary: return .gray
        case .configuration: return .indigo
        case .database: return .teal
        case .font: return .black
        case .unknown: return .secondary
        }
    }
}

// MARK: - Git Status

public enum GitStatus: String, Codable, CaseIterable {
    case untracked = "??"
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case unmerged = "U"
    case ignored = "!!"
    
    var statusColor: Color {
        switch self {
        case .untracked: return .gray
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .blue
        case .copied: return .purple
        case .unmerged: return .yellow
        case .ignored: return .secondary
        }
    }
    
    var statusIcon: String {
        switch self {
        case .untracked: return "questionmark.circle"
        case .modified: return "pencil.circle"
        case .added: return "plus.circle"
        case .deleted: return "minus.circle"
        case .renamed: return "arrow.right.circle"
        case .copied: return "doc.on.doc.fill"
        case .unmerged: return "exclamationmark.triangle"
        case .ignored: return "eye.slash"
        }
    }
}

// MARK: - File Operation

public enum FileOperation {
    case create(name: String, isDirectory: Bool)
    case rename(oldPath: String, newName: String)
    case delete(path: String)
    case move(sourcePath: String, destinationPath: String)
    case copy(sourcePath: String, destinationPath: String)
    case chmod(path: String, permissions: String)
}

// MARK: - Backend Response Models

/// Response model for file listing from backend
public struct FileListResponse: Codable {
    public let files: [FileInfo]
    public let path: String
    public let total: Int
}

/// File information from backend
public struct FileInfo: Codable {
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64?
    public let modifiedAt: String?
    public let createdAt: String?
    public let permissions: String?
    public let mimeType: String?
    public let gitStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case name, path
        case isDirectory = "is_directory"
        case size
        case modifiedAt = "modified_at"
        case createdAt = "created_at"
        case permissions
        case mimeType = "mime_type"
        case gitStatus = "git_status"
    }
    
    /// Convert to FileTreeNode
    func toNode() -> FileTreeNode {
        let dateFormatter = ISO8601DateFormatter()
        
        return FileTreeNode(
            name: name,
            path: path,
            isDirectory: isDirectory,
            size: size,
            modifiedDate: modifiedAt.flatMap { dateFormatter.date(from: $0) },
            createdDate: createdAt.flatMap { dateFormatter.date(from: $0) },
            permissions: permissions,
            mimeType: mimeType,
            gitStatus: gitStatus.flatMap { GitStatus(rawValue: $0) }
        )
    }
}

/// Request model for file operations
public struct FileOperationRequest: Codable {
    public let operation: String
    public let path: String
    public let targetPath: String?
    public let name: String?
    public let isDirectory: Bool?
    public let permissions: String?
    
    public init(operation: FileOperation) {
        switch operation {
        case .create(let name, let isDirectory):
            self.operation = "create"
            self.path = ""
            self.targetPath = nil
            self.name = name
            self.isDirectory = isDirectory
            self.permissions = nil
            
        case .rename(let oldPath, let newName):
            self.operation = "rename"
            self.path = oldPath
            self.targetPath = nil
            self.name = newName
            self.isDirectory = nil
            self.permissions = nil
            
        case .delete(let path):
            self.operation = "delete"
            self.path = path
            self.targetPath = nil
            self.name = nil
            self.isDirectory = nil
            self.permissions = nil
            
        case .move(let source, let destination):
            self.operation = "move"
            self.path = source
            self.targetPath = destination
            self.name = nil
            self.isDirectory = nil
            self.permissions = nil
            
        case .copy(let source, let destination):
            self.operation = "copy"
            self.path = source
            self.targetPath = destination
            self.name = nil
            self.isDirectory = nil
            self.permissions = nil
            
        case .chmod(let path, let permissions):
            self.operation = "chmod"
            self.path = path
            self.targetPath = nil
            self.name = nil
            self.isDirectory = nil
            self.permissions = permissions
        }
    }
}

/// Response for file operations
public struct FileOperationResponse: Codable {
    public let success: Bool
    public let message: String?
    public let updatedFile: FileInfo?
}