import Foundation
import SwiftUI

// MARK: - Task 176: Model Extensions for UI Display

// MARK: - Message Extensions
extension ChatMessage {
    /// Display-friendly timestamp
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: Date())
    }
    
    /// Get the text content from the message
    public var textContent: String {
        return content ?? ""
    }
    
    /// Check if message contains images
    public var hasImages: Bool {
        // For now, messages don't support images directly
        return false
    }
    
    /// Get role display color
    public var roleColor: Color {
        switch role.lowercased() {
        case "system":
            return Color.gray
        case "user":
            return Color(hue: 142/360, saturation: 0.7, brightness: 0.45)
        case "assistant":
            return Color(hue: 280/360, saturation: 0.7, brightness: 0.5)
        case "tool", "function":
            return Color.orange
        default:
            return Color.primary
        }
    }
    
    /// Get role display name
    public var roleDisplayName: String {
        switch role.lowercased() {
        case "system":
            return "System"
        case "user":
            return "User"
        case "assistant":
            return "Assistant"
        case "tool", "function":
            return "Tool"
        default:
            return role.capitalized
        }
    }
}

// MARK: - Session Extensions
extension ChatSession {
    /// Get conversation statistics
    public var stats: ConversationStats {
        // Using placeholder values since ChatSession doesn't have messages array
        ConversationStats(
            messageCount: 0,
            userMessages: 0,
            assistantMessages: 0,
            totalTokens: 0,
            estimatedCost: 0.0
        )
    }
    
    /// Get last message timestamp  
    public var lastMessageTime: Date? {
        return timestamp
    }
    
    /// Check if session is favorite
    public var isFavorite: Bool {
        // This would need to be stored in metadata or a separate property
        return tags.contains("favorite")
    }
}

// MARK: - Project Extensions
extension Project {
    /// Check if project was accessed recently
    public var isRecentlyActive: Bool {
        // A project is active if accessed recently
        guard let lastAccessed = lastAccessedAt else { return false }
        let daysSinceAccess = Date().timeIntervalSince(lastAccessed) / 86400
        return daysSinceAccess < 7
    }
    
    /// Check if project is favorite
    public var isFavorite: Bool {
        // This would need to be stored in metadata
        return false
    }
    
    /// Get project statistics
    public var statistics: ProjectStatistics? {
        // Return basic statistics
        return ProjectStatistics(
            fileCount: 0, // Placeholder - actual file count would be calculated
            totalSize: Int64(1000), // Placeholder
            language: detectPrimaryLanguage(),
            lastModified: lastAccessedAt ?? createdAt
        )
    }
    
    /// Detect primary language from path
    private func detectPrimaryLanguage() -> String {
        if path.contains("swift") || path.contains("ios") {
            return "Swift"
        } else if path.contains("node") || path.contains("js") {
            return "JavaScript"
        } else if path.contains("python") || path.contains("py") {
            return "Python"
        }
        return "Unknown"
    }
}

// MARK: - Tool Extensions
extension Tool {
    /// Tool category color
    public var categoryColor: Color {
        switch category {
        case .fileSystem:
            return Color.blue
        case .shell:
            return Color.green
        case .git:
            return Color.orange
        case .search:
            return Color.purple
        case .network:
            return Color.cyan
        case .other:
            return Color.gray
        }
    }
    
    /// Check if tool requires special permissions
    public var requiresPermission: Bool {
        // Some tools might need file system or network access
        return requiredPermissions?.isEmpty == false
    }
    
    /// Get required permissions
    public var requiredPermissions: [String]? {
        // This would be defined per tool
        switch name {
        case "File Explorer":
            return ["file_system_read", "file_system_write"]
        case "Terminal":
            return ["process_execution"]
        case "Git":
            return ["file_system_write", "network"]
        default:
            return nil
        }
    }
}

// MARK: - Usage Extensions  
extension UsageStats {
    /// Get formatted cost string
    public var formattedCost: String {
        return String(format: "$%.2f", totalCost)
    }
    
    /// Check if within budget
    public func isWithinBudget(_ budget: Double) -> Bool {
        return totalCost <= budget
    }
    
    /// Get average cost per session
    public var averageCostPerSession: Double {
        guard sessionsCount > 0 else { return 0 }
        return totalCost / Double(sessionsCount)
    }
}

// MARK: - Supporting Types

/// Conversation statistics
public struct ConversationStats {
    public let messageCount: Int
    public let userMessages: Int
    public let assistantMessages: Int
    public let totalTokens: Int
    public let estimatedCost: Double
}

/// Project statistics
public struct ProjectStatistics {
    public let fileCount: Int
    public let totalSize: Int64
    public let language: String
    public let lastModified: Date
}

/// Model capability enum
public enum ModelCapability: String {
    case streaming
    case functionCalling = "function_calling"
    case vision
    case codeGeneration = "code_generation"
    case embeddings
}

// ModelPricing is now defined in ProjectModels.swift

/// SSH Session Status (for SSH-related extensions)
public enum SSHSessionStatus: String, CaseIterable {
    case connected = "Connected"
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case error = "Error"
    
    public var color: Color {
        switch self {
        case .connected:
            return .green
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .error:
            return .red
        }
    }
    
    public var icon: String {
        switch self {
        case .connected:
            return "checkmark.circle.fill"
        case .disconnected:
            return "xmark.circle"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - File Tree Extensions
extension FileTreeNode {
    /// Get file icon based on extension
    public var fileIcon: String {
        if isDirectory {
            return "folder.fill"
        }
        
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift":
            return "swift"
        case "js", "jsx", "ts", "tsx":
            return "curlybraces"
        case "html", "htm":
            return "globe"
        case "css", "scss", "sass":
            return "paintbrush.fill"
        case "json", "xml", "yaml", "yml":
            return "doc.text"
        case "md", "markdown":
            return "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "svg":
            return "photo"
        case "mp4", "mov", "avi":
            return "video.fill"
        case "mp3", "wav", "aac":
            return "music.note"
        case "pdf":
            return "doc.fill"
        case "zip", "tar", "gz":
            return "archivebox.fill"
        default:
            return "doc"
        }
    }
    
    /// Get formatted file size
    public var formattedSize: String? {
        guard let size = size else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}