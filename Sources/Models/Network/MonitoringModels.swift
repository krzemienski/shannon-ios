import Foundation

// MARK: - Task 186: ProcessInfo Model
/// Process information
public struct ProcessInfo: Codable, Identifiable, Equatable {
    public let id: String // PID as string
    public let pid: Int
    public let name: String
    public let command: String?
    public let user: String?
    public let cpuUsage: Double
    public let memoryUsage: Int64 // in bytes
    public let virtualMemory: Int64?
    public let threads: Int?
    public let startTime: Date?
    public let state: ProcessState
    public let parentPid: Int?
    public let priority: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case pid
        case name
        case command
        case user
        case cpuUsage = "cpu_usage"
        case memoryUsage = "memory_usage"
        case virtualMemory = "virtual_memory"
        case threads
        case startTime = "start_time"
        case state
        case parentPid = "parent_pid"
        case priority
    }
}

/// Process state
public enum ProcessState: String, Codable {
    case running
    case sleeping
    case stopped
    case zombie
    case idle
    case unknown
}

// MARK: - Task 189: TraceEvent Model
/// Trace event for monitoring and debugging
public struct TraceEvent: Codable, Identifiable, Equatable {
    public let id: String
    public let timestamp: Date
    public let level: TraceLevel
    public let category: String
    public let message: String
    public let source: TraceSource?
    public let context: TraceContext?
    public let duration: TimeInterval?
    public let metadata: [String: String]?
    
    public init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        level: TraceLevel,
        category: String,
        message: String,
        source: TraceSource? = nil,
        context: TraceContext? = nil,
        duration: TimeInterval? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.source = source
        self.context = context
        self.duration = duration
        self.metadata = metadata
    }
}

/// Trace level
public enum TraceLevel: String, Codable, CaseIterable {
    case verbose
    case debug
    case info
    case warning
    case error
    case critical
    
    public var priority: Int {
        switch self {
        case .verbose: return 0
        case .debug: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        case .critical: return 5
        }
    }
}

/// Trace source information
public struct TraceSource: Codable, Equatable {
    public let file: String?
    public let function: String?
    public let line: Int?
    public let module: String?
    public let thread: String?
}

/// Trace context
public struct TraceContext: Codable, Equatable {
    public let requestId: String?
    public let sessionId: String?
    public let userId: String?
    public let correlationId: String?
    public let parentSpanId: String?
    public let spanId: String?
    
    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case sessionId = "session_id"
        case userId = "user_id"
        case correlationId = "correlation_id"
        case parentSpanId = "parent_span_id"
        case spanId = "span_id"
    }
}

// MARK: - Task 190: ExportFormat Enum
/// Export format options
public enum ExportFormat: String, Codable, CaseIterable, Sendable {
    case json
    case csv
    case markdown
    case html
    case pdf
    case plainText = "plain_text"
    case xml
    case yaml
    
    public var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .markdown: return "text/markdown"
        case .html: return "text/html"
        case .pdf: return "application/pdf"
        case .plainText: return "text/plain"
        case .xml: return "application/xml"
        case .yaml: return "application/x-yaml"
        }
    }
    
    public var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .markdown: return "md"
        case .html: return "html"
        case .pdf: return "pdf"
        case .plainText: return "txt"
        case .xml: return "xml"
        case .yaml: return "yaml"
        }
    }
}

// MARK: - Metric Data Point
/// Data point for metrics visualization
public struct MetricDataPoint: Codable, Equatable {
    public let timestamp: Date
    public let value: Double
    public let label: String?
    
    public init(timestamp: Date, value: Double, label: String? = nil) {
        self.timestamp = timestamp
        self.value = value
        self.label = label
    }
}

// MARK: - Task 191: FilterCriteria Model
/// Filter criteria for queries
public struct FilterCriteria: Codable, Equatable {
    public var searchText: String?
    public var dateRange: DateRange?
    public var tags: [String]?
    public var categories: [String]?
    public var status: [String]?
    public var severity: [String]?
    public var customFilters: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case searchText = "search_text"
        case dateRange = "date_range"
        case tags
        case categories
        case status
        case severity
        case customFilters = "custom_filters"
    }
    
    public init(
        searchText: String? = nil,
        dateRange: DateRange? = nil,
        tags: [String]? = nil,
        categories: [String]? = nil,
        status: [String]? = nil,
        severity: [String]? = nil,
        customFilters: [String: String]? = nil
    ) {
        self.searchText = searchText
        self.dateRange = dateRange
        self.tags = tags
        self.categories = categories
        self.status = status
        self.severity = severity
        self.customFilters = customFilters
    }
}

/// Date range for filtering
public struct DateRange: Codable, Equatable {
    public let startDate: Date
    public let endDate: Date
    
    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
    }
    
    public init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - Task 192: SortOptions Model
/// Sort options for queries
public struct SortOptions: Codable, Equatable {
    public let field: String
    public let direction: SortDirection
    public let nullHandling: NullHandling?
    
    enum CodingKeys: String, CodingKey {
        case field
        case direction
        case nullHandling = "null_handling"
    }
    
    public init(
        field: String,
        direction: SortDirection = .ascending,
        nullHandling: NullHandling? = nil
    ) {
        self.field = field
        self.direction = direction
        self.nullHandling = nullHandling
    }
}

/// Sort direction
public enum SortDirection: String, Codable {
    case ascending = "asc"
    case descending = "desc"
}

/// Null value handling in sorting
public enum NullHandling: String, Codable {
    case first = "nulls_first"
    case last = "nulls_last"
}

// MARK: - Task 193: Pagination Model
/// Pagination information
public struct Pagination: Codable, Equatable {
    public let page: Int
    public let pageSize: Int
    public let totalItems: Int?
    public let totalPages: Int?
    public let hasNext: Bool?
    public let hasPrevious: Bool?
    
    enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case totalItems = "total_items"
        case totalPages = "total_pages"
        case hasNext = "has_next"
        case hasPrevious = "has_previous"
    }
    
    public init(
        page: Int = 1,
        pageSize: Int = 20,
        totalItems: Int? = nil,
        totalPages: Int? = nil,
        hasNext: Bool? = nil,
        hasPrevious: Bool? = nil
    ) {
        self.page = page
        self.pageSize = pageSize
        self.totalItems = totalItems
        self.totalPages = totalPages
        self.hasNext = hasNext
        self.hasPrevious = hasPrevious
    }
    
    /// Calculate total pages from total items
    public var calculatedTotalPages: Int? {
        guard let totalItems = totalItems else { return nil }
        return (totalItems + pageSize - 1) / pageSize
    }
}

// MARK: - Task 194: Cache Models
/// Cache entry
public struct CacheEntry: Codable, Equatable {
    public let key: String
    public let value: Data
    public let timestamp: Date
    public let expiresAt: Date?
    public let metadata: CacheMetadata?
    
    enum CodingKeys: String, CodingKey {
        case key
        case value
        case timestamp
        case expiresAt = "expires_at"
        case metadata
    }
    
    public init(
        key: String,
        value: Data,
        timestamp: Date = Date(),
        expiresAt: Date? = nil,
        metadata: CacheMetadata? = nil
    ) {
        self.key = key
        self.value = value
        self.timestamp = timestamp
        self.expiresAt = expiresAt
        self.metadata = metadata
    }
    
    /// Check if cache entry is expired
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

/// Cache metadata
public struct CacheMetadata: Codable, Equatable {
    public let size: Int64
    public let etag: String?
    public let contentType: String?
    public let hitCount: Int
    public let lastAccessed: Date?
    
    enum CodingKeys: String, CodingKey {
        case size
        case etag
        case contentType = "content_type"
        case hitCount = "hit_count"
        case lastAccessed = "last_accessed"
    }
}

// MARK: - Task 195: Preference Models
/// User preferences
public struct UserPreferences: Codable, Equatable {
    public var theme: ThemePreference
    public var language: String
    public var notifications: NotificationPreferences
    public var privacy: PrivacyPreferences
    public var accessibility: AccessibilityPreferences
    public var advanced: AdvancedPreferences
    
    public init(
        theme: ThemePreference = .auto,
        language: String = "en",
        notifications: NotificationPreferences = NotificationPreferences(),
        privacy: PrivacyPreferences = PrivacyPreferences(),
        accessibility: AccessibilityPreferences = AccessibilityPreferences(),
        advanced: AdvancedPreferences = AdvancedPreferences()
    ) {
        self.theme = theme
        self.language = language
        self.notifications = notifications
        self.privacy = privacy
        self.accessibility = accessibility
        self.advanced = advanced
    }
}

/// Theme preference
public enum ThemePreference: String, Codable {
    case light
    case dark
    case auto
}

/// Notification preferences
public struct NotificationPreferences: Codable, Equatable {
    public var enabled: Bool
    public var sound: Bool
    public var badge: Bool
    public var alerts: Bool
    public var categories: [String: Bool]
    
    public init(
        enabled: Bool = true,
        sound: Bool = true,
        badge: Bool = true,
        alerts: Bool = true,
        categories: [String: Bool] = [:]
    ) {
        self.enabled = enabled
        self.sound = sound
        self.badge = badge
        self.alerts = alerts
        self.categories = categories
    }
}

/// Privacy preferences
public struct PrivacyPreferences: Codable, Equatable {
    public var analytics: Bool
    public var crashReporting: Bool
    public var personalization: Bool
    public var dataSharingr: Bool
    
    enum CodingKeys: String, CodingKey {
        case analytics
        case crashReporting = "crash_reporting"
        case personalization
        case dataSharingr = "data_sharing"
    }
    
    public init(
        analytics: Bool = false,
        crashReporting: Bool = true,
        personalization: Bool = false,
        dataSharingr: Bool = false
    ) {
        self.analytics = analytics
        self.crashReporting = crashReporting
        self.personalization = personalization
        self.dataSharingr = dataSharingr
    }
}

/// Accessibility preferences
public struct AccessibilityPreferences: Codable, Equatable {
    public var voiceOver: Bool
    public var largeText: Bool
    public var reduceMotion: Bool
    public var increaseContrast: Bool
    
    enum CodingKeys: String, CodingKey {
        case voiceOver = "voice_over"
        case largeText = "large_text"
        case reduceMotion = "reduce_motion"
        case increaseContrast = "increase_contrast"
    }
    
    public init(
        voiceOver: Bool = false,
        largeText: Bool = false,
        reduceMotion: Bool = false,
        increaseContrast: Bool = false
    ) {
        self.voiceOver = voiceOver
        self.largeText = largeText
        self.reduceMotion = reduceMotion
        self.increaseContrast = increaseContrast
    }
}

/// Advanced preferences
public struct AdvancedPreferences: Codable, Equatable {
    public var developerMode: Bool
    public var debugLogging: Bool
    public var experimentalFeatures: Bool
    public var cacheSize: Int64 // in bytes
    public var networkTimeout: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case developerMode = "developer_mode"
        case debugLogging = "debug_logging"
        case experimentalFeatures = "experimental_features"
        case cacheSize = "cache_size"
        case networkTimeout = "network_timeout"
    }
    
    public init(
        developerMode: Bool = false,
        debugLogging: Bool = false,
        experimentalFeatures: Bool = false,
        cacheSize: Int64 = 100 * 1024 * 1024, // 100MB
        networkTimeout: TimeInterval = 30
    ) {
        self.developerMode = developerMode
        self.debugLogging = debugLogging
        self.experimentalFeatures = experimentalFeatures
        self.cacheSize = cacheSize
        self.networkTimeout = networkTimeout
    }
}

// MARK: - Task 196: Notification Models

// Notification Priority enum
public enum NotificationPriority: String, Codable, Equatable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
}

/// Notification model
public struct AppNotification: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let body: String
    public let timestamp: Date
    public let category: NotificationCategory
    public let priority: NotificationPriority
    public let isRead: Bool
    public let actionUrl: String?
    public let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case timestamp
        case category
        case priority
        case isRead = "is_read"
        case actionUrl = "action_url"
        case metadata
    }
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        timestamp: Date = Date(),
        category: NotificationCategory,
        priority: NotificationPriority = .normal,
        isRead: Bool = false,
        actionUrl: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.timestamp = timestamp
        self.category = category
        self.priority = priority
        self.isRead = isRead
        self.actionUrl = actionUrl
        self.metadata = metadata
    }
}

/// Notification category
public enum NotificationCategory: String, Codable {
    case system
    case message
    case alert
    case update
    case error
    case success
    case info
    case reminder
}

/// Notification priority
public enum MonitoringNotificationPriority: String, Codable {
    case low
    case normal
    case high
    case urgent
}