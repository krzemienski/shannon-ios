import Foundation
import SwiftUI

// MARK: - App Settings

/// Main application settings
public struct AppSettings: Codable {
    // API Settings
    public var apiConfiguration: APIConfiguration?
    public var defaultModel: AIModel
    public var streamResponses: Bool
    
    // Appearance Settings
    public var appearanceSettings: AppearanceSettings
    
    // Chat Settings
    public var chatSettings: ChatSettings
    
    // SSH Settings
    public var sshSettings: SSHSettings
    
    // Advanced Settings
    public var advancedSettings: AdvancedSettings
    
    // Notification Settings
    public var notificationSettings: AppNotificationSettings
    
    public init(
        apiConfiguration: APIConfiguration? = nil,
        defaultModel: AIModel = .claude3Sonnet,
        streamResponses: Bool = true,
        appearanceSettings: AppearanceSettings = AppearanceSettings(),
        chatSettings: ChatSettings = ChatSettings(),
        sshSettings: SSHSettings = SSHSettings(),
        advancedSettings: AdvancedSettings = AdvancedSettings(),
        notificationSettings: AppNotificationSettings = AppNotificationSettings()
    ) {
        self.apiConfiguration = apiConfiguration
        self.defaultModel = defaultModel
        self.streamResponses = streamResponses
        self.appearanceSettings = appearanceSettings
        self.chatSettings = chatSettings
        self.sshSettings = sshSettings
        self.advancedSettings = advancedSettings
        self.notificationSettings = notificationSettings
    }
}

// MARK: - AI Model

public enum AIModel: String, Codable, CaseIterable {
    case claude3Opus = "claude-3-opus-20240229"
    case claude3Sonnet = "claude-3-5-sonnet-20241022"
    case claude3Haiku = "claude-3-haiku-20240307"
    case claude2_1 = "claude-2.1"
    case claude2 = "claude-2.0"
    case claudeInstant = "claude-instant-1.2"
    
    public var displayName: String {
        switch self {
        case .claude3Opus:
            return "Claude 3 Opus"
        case .claude3Sonnet:
            return "Claude 3.5 Sonnet"
        case .claude3Haiku:
            return "Claude 3 Haiku"
        case .claude2_1:
            return "Claude 2.1"
        case .claude2:
            return "Claude 2.0"
        case .claudeInstant:
            return "Claude Instant"
        }
    }
    
    public var maxTokens: Int {
        switch self {
        case .claude3Opus, .claude3Sonnet, .claude3Haiku:
            return 4096
        case .claude2_1, .claude2:
            return 4096
        case .claudeInstant:
            return 4096
        }
    }
    
    public var contextWindow: Int {
        switch self {
        case .claude3Opus, .claude3Sonnet, .claude3Haiku:
            return 200000
        case .claude2_1:
            return 200000
        case .claude2:
            return 100000
        case .claudeInstant:
            return 100000
        }
    }
    
    public var supportsVision: Bool {
        switch self {
        case .claude3Opus, .claude3Sonnet, .claude3Haiku:
            return true
        default:
            return false
        }
    }
    
    public var supportsFunctionCalling: Bool {
        switch self {
        case .claude3Opus, .claude3Sonnet, .claude3Haiku:
            return true
        default:
            return false
        }
    }
}

// MARK: - Appearance Settings

public struct AppearanceSettings: Codable {
    public var theme: ThemeMode
    public var accentColorHue: Double
    public var fontSize: FontSize
    public var codeFont: CodeFont
    public var showLineNumbers: Bool
    public var syntaxHighlighting: Bool
    public var useHaptics: Bool
    
    public enum ThemeMode: String, Codable, CaseIterable {
        case system
        case light
        case dark
        
        public var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }
    
    public enum FontSize: String, Codable, CaseIterable {
        case small
        case medium
        case large
        case extraLarge
        
        public var displayName: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            case .extraLarge: return "Extra Large"
            }
        }
        
        public var scaleFactor: CGFloat {
            switch self {
            case .small: return 0.85
            case .medium: return 1.0
            case .large: return 1.15
            case .extraLarge: return 1.3
            }
        }
    }
    
    public enum CodeFont: String, Codable, CaseIterable {
        case sfMono = "SF Mono"
        case menlo = "Menlo"
        case monaco = "Monaco"
        case courier = "Courier"
        
        public var displayName: String {
            rawValue
        }
    }
    
    public init(
        theme: ThemeMode = .system,
        accentColorHue: Double = 9, // Anthropic orange
        fontSize: FontSize = .medium,
        codeFont: CodeFont = .sfMono,
        showLineNumbers: Bool = true,
        syntaxHighlighting: Bool = true,
        useHaptics: Bool = true
    ) {
        self.theme = theme
        self.accentColorHue = accentColorHue
        self.fontSize = fontSize
        self.codeFont = codeFont
        self.showLineNumbers = showLineNumbers
        self.syntaxHighlighting = syntaxHighlighting
        self.useHaptics = useHaptics
    }
}

// MARK: - Chat Settings

public struct ChatSettings: Codable {
    public var defaultTemperature: Double
    public var defaultMaxTokens: Int
    public var defaultTopP: Double
    public var defaultTopK: Int
    public var autoSaveConversations: Bool
    public var showTimestamps: Bool
    public var showTokenCount: Bool
    public var enableMarkdown: Bool
    public var enableCodeHighlighting: Bool
    public var messageGrouping: MessageGrouping
    
    public enum MessageGrouping: String, Codable, CaseIterable {
        case none
        case byTime
        case byRole
        
        public var displayName: String {
            switch self {
            case .none: return "None"
            case .byTime: return "By Time"
            case .byRole: return "By Role"
            }
        }
    }
    
    public init(
        defaultTemperature: Double = 0.7,
        defaultMaxTokens: Int = 4096,
        defaultTopP: Double = 1.0,
        defaultTopK: Int = 0,
        autoSaveConversations: Bool = true,
        showTimestamps: Bool = true,
        showTokenCount: Bool = false,
        enableMarkdown: Bool = true,
        enableCodeHighlighting: Bool = true,
        messageGrouping: MessageGrouping = .none
    ) {
        self.defaultTemperature = defaultTemperature
        self.defaultMaxTokens = defaultMaxTokens
        self.defaultTopP = defaultTopP
        self.defaultTopK = defaultTopK
        self.autoSaveConversations = autoSaveConversations
        self.showTimestamps = showTimestamps
        self.showTokenCount = showTokenCount
        self.enableMarkdown = enableMarkdown
        self.enableCodeHighlighting = enableCodeHighlighting
        self.messageGrouping = messageGrouping
    }
}

// MARK: - SSH Settings

public struct SSHSettings: Codable {
    public var connections: [SSHConnection]
    public var defaultTimeout: TimeInterval
    public var keepAliveInterval: TimeInterval
    public var autoReconnect: Bool
    public var savePasswords: Bool
    
    public init(
        connections: [SSHConnection] = [],
        defaultTimeout: TimeInterval = 30,
        keepAliveInterval: TimeInterval = 60,
        autoReconnect: Bool = true,
        savePasswords: Bool = false
    ) {
        self.connections = connections
        self.defaultTimeout = defaultTimeout
        self.keepAliveInterval = keepAliveInterval
        self.autoReconnect = autoReconnect
        self.savePasswords = savePasswords
    }
}

public struct SSHConnection: Identifiable, Codable {
    public let id: String
    public var name: String
    public var host: String
    public var port: Int
    public var username: String
    public var authMethod: SSHAuthMethod
    public var privateKeyPath: String?
    public var useKeychain: Bool
    public var lastUsed: Date?
    
    public enum SSHAuthMethod: String, Codable, CaseIterable {
        case password
        case publicKey
        
        public var displayName: String {
            switch self {
            case .password: return "Password"
            case .publicKey: return "Public Key"
            }
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authMethod: SSHAuthMethod = .password,
        privateKeyPath: String? = nil,
        useKeychain: Bool = true,
        lastUsed: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.privateKeyPath = privateKeyPath
        self.useKeychain = useKeychain
        self.lastUsed = lastUsed
    }
}

// MARK: - Advanced Settings

public struct AdvancedSettings: Codable {
    public var enableDebugMode: Bool
    public var enableAnalytics: Bool
    public var cacheSize: Int // in MB
    public var exportFormat: ExportFormat
    public var backupFrequency: BackupFrequency
    public var logLevel: LogLevel
    
    public enum ExportFormat: String, Codable, CaseIterable {
        case json
        case markdown
        case plainText
        case pdf
        
        public var displayName: String {
            switch self {
            case .json: return "JSON"
            case .markdown: return "Markdown"
            case .plainText: return "Plain Text"
            case .pdf: return "PDF"
            }
        }
    }
    
    public enum BackupFrequency: String, Codable, CaseIterable {
        case never
        case daily
        case weekly
        case monthly
        
        public var displayName: String {
            switch self {
            case .never: return "Never"
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            }
        }
    }
    
    public enum LogLevel: String, Codable, CaseIterable {
        case none
        case error
        case warning
        case info
        case debug
        case verbose
        
        public var displayName: String {
            switch self {
            case .none: return "None"
            case .error: return "Error"
            case .warning: return "Warning"
            case .info: return "Info"
            case .debug: return "Debug"
            case .verbose: return "Verbose"
            }
        }
    }
    
    public init(
        enableDebugMode: Bool = false,
        enableAnalytics: Bool = true,
        cacheSize: Int = 100,
        exportFormat: ExportFormat = .markdown,
        backupFrequency: BackupFrequency = .weekly,
        logLevel: LogLevel = .error
    ) {
        self.enableDebugMode = enableDebugMode
        self.enableAnalytics = enableAnalytics
        self.cacheSize = cacheSize
        self.exportFormat = exportFormat
        self.backupFrequency = backupFrequency
        self.logLevel = logLevel
    }
}

// MARK: - Notification Settings

public struct AppNotificationSettings: Codable {
    public var enableNotifications: Bool
    public var messageNotifications: Bool
    public var errorNotifications: Bool
    public var updateNotifications: Bool
    public var soundEnabled: Bool
    public var vibrationEnabled: Bool
    
    public init(
        enableNotifications: Bool = true,
        messageNotifications: Bool = true,
        errorNotifications: Bool = true,
        updateNotifications: Bool = true,
        soundEnabled: Bool = true,
        vibrationEnabled: Bool = true
    ) {
        self.enableNotifications = enableNotifications
        self.messageNotifications = messageNotifications
        self.errorNotifications = errorNotifications
        self.updateNotifications = updateNotifications
        self.soundEnabled = soundEnabled
        self.vibrationEnabled = vibrationEnabled
    }
}

// MARK: - Connection Test Result

/// Result of a connection test for API or SSH connections
public struct ConnectionTestResult {
    public let success: Bool
    public let message: String
    public let details: String?
    
    public init(success: Bool, message: String, details: String? = nil) {
        self.success = success
        self.message = message
        self.details = details
    }
}