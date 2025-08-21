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
        switch content {
        case .text(let text):
            return text
        case .array(let parts):
            return parts.compactMap { part in
                if case .text = part.type {
                    return part.text
                }
                return nil
            }.joined(separator: "\n")
        case .none:
            return ""
        }
    }
    
    /// Check if message contains images
    public var hasImages: Bool {
        guard case .array(let parts) = content else { return false }
        return parts.contains { $0.type == .imageUrl }
    }
    
    /// Get role display color
    public var roleColor: Color {
        switch role {
        case .system:
            return Color.gray
        case .user:
            return Color(hue: 142/360, saturation: 0.7, brightness: 0.45)
        case .assistant:
            return Color(hue: 280/360, saturation: 0.7, brightness: 0.5)
        case .tool, .function:
            return Color.orange
        }
    }
    
    /// Get role icon
    public var roleIcon: String {
        switch role {
        case .system:
            return "gear"
        case .user:
            return "person.circle.fill"
        case .assistant:
            return "cpu"
        case .tool, .function:
            return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - Session Extensions
extension SessionInfo {
    /// Get a summary of the session
    public var summary: String {
        let messageCount = messages.count
        let duration = updatedAt.timeIntervalSince(createdAt)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        let durationString = formatter.string(from: duration) ?? "0s"
        
        return "\(messageCount) messages • \(durationString)"
    }
    
    /// Get the last message preview
    public var lastMessagePreview: String? {
        messages.last?.textContent
    }
    
    /// Calculate total tokens used
    public var totalTokens: Int {
        stats?.totalTokens ?? 0
    }
    
    /// Get estimated cost
    public var estimatedCost: String {
        let cost = stats?.totalCost ?? 0
        return String(format: "$%.4f", cost)
    }
}

// MARK: - Project Extensions
extension ProjectInfo {
    /// Get project status badge
    public var statusBadge: (text: String, color: Color) {
        if !isActive {
            return ("Inactive", Color.gray)
        } else if isFavorite {
            return ("Favorite", Color.yellow)
        } else {
            return ("Active", Color.green)
        }
    }
    
    /// Get formatted file size
    public var formattedSize: String? {
        guard let size = metadata?.statistics?.size else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    /// Get language icon
    public var languageIcon: String {
        switch metadata?.language?.lowercased() {
        case "swift":
            return "swift"
        case "python":
            return "🐍"
        case "javascript", "typescript":
            return "globe"
        case "java":
            return "cup.and.saucer"
        case "c", "c++", "cpp":
            return "c.circle"
        case "go":
            return "g.circle"
        case "rust":
            return "r.circle"
        default:
            return "doc.text"
        }
    }
}

// MARK: - Tool Extensions
extension ToolInfo {
    /// Get category icon
    public var categoryIcon: String {
        switch category?.lowercased() {
        case "filesystem":
            return "folder"
        case "network":
            return "network"
        case "database":
            return "cylinder"
        case "computation":
            return "function"
        case "analysis":
            return "chart.line.uptrend.xyaxis"
        case "generation":
            return "wand.and.stars"
        case "monitoring":
            return "chart.bar.xaxis"
        default:
            return "wrench"
        }
    }
    
    /// Get permission level
    public var permissionLevel: String {
        guard let permissions = requiredPermissions else { return "None" }
        if permissions.isEmpty { return "None" }
        if permissions.contains("admin") || permissions.contains("root") {
            return "High"
        } else if permissions.count > 3 {
            return "Medium"
        } else {
            return "Low"
        }
    }
}

// MARK: - Model Extensions
extension APIModel {
    /// Get formatted context window
    public var formattedContextWindow: String {
        guard let window = capabilities?.contextWindow else { return "Unknown" }
        if window >= 1_000_000 {
            return "\(window / 1_000_000)M tokens"
        } else if window >= 1_000 {
            return "\(window / 1_000)K tokens"
        } else {
            return "\(window) tokens"
        }
    }
    
    /// Get formatted price per 1K tokens
    public func formattedPrice(for type: PriceType) -> String? {
        guard let pricing = pricing else { return nil }
        
        let price: Double?
        switch type {
        case .prompt:
            price = pricing.promptTokenPrice
        case .completion:
            price = pricing.completionTokenPrice
        }
        
        guard let p = price else { return nil }
        return String(format: "$%.4f", p)
    }
    
    public enum PriceType {
        case prompt
        case completion
    }
    
    /// Check if model supports a specific feature
    public func supports(_ feature: ModelFeature) -> Bool {
        guard let capabilities = capabilities else { return false }
        
        switch feature {
        case .functions:
            return capabilities.supportsFunctions
        case .vision:
            return capabilities.supportsVision
        case .streaming:
            return capabilities.supportsStreaming
        case .systemMessage:
            return capabilities.supportsSystemMessage
        case .toolUse:
            return capabilities.supportsToolUse
        }
    }
    
    public enum ModelFeature {
        case functions
        case vision
        case streaming
        case systemMessage
        case toolUse
    }
}

// MARK: - Usage Extensions
extension Usage {
    /// Get formatted total cost
    public func formattedCost(with pricing: ModelPricing?) -> String {
        guard let pricing = pricing else { return "$0.0000" }
        let cost = calculateCost(pricing: pricing)
        return String(format: "$%.4f", cost)
    }
    
    /// Get usage breakdown
    public var breakdown: String {
        var parts: [String] = []
        parts.append("\(promptTokens) prompt")
        parts.append("\(completionTokens) completion")
        if let cached = cachedTokens, cached > 0 {
            parts.append("\(cached) cached")
        }
        return parts.joined(separator: " • ")
    }
}

// MARK: - Error Extensions
extension APIErrorCode {
    /// Get user-friendly error message
    public var userMessage: String {
        switch self {
        case .invalidRequest:
            return "The request was invalid. Please check your input."
        case .authentication:
            return "Authentication failed. Please check your API key."
        case .permissionDenied:
            return "You don't have permission to perform this action."
        case .notFound:
            return "The requested resource was not found."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .serverError:
            return "A server error occurred. Please try again."
        case .serviceUnavailable:
            return "The service is temporarily unavailable."
        case .timeout:
            return "The request timed out. Please try again."
        case .conflict:
            return "A conflict occurred. The resource may have been modified."
        case .payloadTooLarge:
            return "The request is too large. Please reduce the size."
        case .unprocessableEntity:
            return "The request could not be processed."
        case .quotaExceeded:
            return "Your quota has been exceeded."
        case .invalidApiKey:
            return "The API key is invalid or expired."
        case .modelNotFound:
            return "The specified model was not found."
        case .contextLengthExceeded:
            return "The context length exceeds the model's limit."
        case .contentFilter:
            return "The content was filtered due to policy violations."
        case .invalidToolUse:
            return "Invalid tool usage detected."
        }
    }
    
    /// Get error severity
    public var severity: ErrorSeverity {
        switch self {
        case .authentication, .invalidApiKey, .permissionDenied:
            return .critical
        case .serverError, .serviceUnavailable:
            return .high
        case .rateLimitExceeded, .quotaExceeded, .timeout:
            return .medium
        case .invalidRequest, .notFound, .conflict:
            return .low
        default:
            return .medium
        }
    }
    
    public enum ErrorSeverity {
        case low
        case medium
        case high
        case critical
    }
}

// MARK: - SSH Extensions
extension SSHSessionStatus {
    /// Get status color
    public var statusColor: Color {
        switch self {
        case .connected, .authenticated:
            return .green
        case .connecting:
            return .orange
        case .disconnecting:
            return .yellow
        case .disconnected:
            return .gray
        case .error:
            return .red
        case .idle:
            return .blue
        }
    }
    
    /// Get status icon
    public var statusIcon: String {
        switch self {
        case .connected, .authenticated:
            return "checkmark.circle.fill"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .disconnecting:
            return "xmark.circle"
        case .disconnected:
            return "circle"
        case .error:
            return "exclamationmark.triangle.fill"
        case .idle:
            return "moon.zzz"
        }
    }
}

// MARK: - Process Extensions
extension ProcessState {
    /// Get state display name
    public var displayName: String {
        switch self {
        case .running:
            return "Running"
        case .sleeping:
            return "Sleeping"
        case .stopped:
            return "Stopped"
        case .zombie:
            return "Zombie"
        case .idle:
            return "Idle"
        case .unknown:
            return "Unknown"
        }
    }
    
    /// Get state color
    public var stateColor: Color {
        switch self {
        case .running:
            return .green
        case .sleeping:
            return .blue
        case .stopped:
            return .orange
        case .zombie:
            return .red
        case .idle:
            return .gray
        case .unknown:
            return .gray
        }
    }
}

// MARK: - Trace Extensions
extension TraceLevel {
    /// Get level color
    public var levelColor: Color {
        switch self {
        case .verbose:
            return .gray
        case .debug:
            return .blue
        case .info:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
    
    /// Get level icon
    public var levelIcon: String {
        switch self {
        case .verbose:
            return "text.alignleft"
        case .debug:
            return "ant.circle"
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        case .critical:
            return "flame"
        }
    }
}

// MARK: - Date Extensions
extension Date {
    /// Format as relative time
    public var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Format as short date/time
    public var shortDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}