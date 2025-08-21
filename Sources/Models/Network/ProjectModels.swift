import Foundation

// MARK: - Task 166: Project Model
/// Project information
public struct ProjectInfo: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var description: String?
    public var path: String
    public var gitRepository: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var lastAccessedAt: Date?
    public var metadata: ProjectMetadata?
    public var settings: ProjectSettings?
    public var tags: [String]
    public var isActive: Bool
    public var isFavorite: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case path
        case gitRepository = "git_repository"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastAccessedAt = "last_accessed_at"
        case metadata
        case settings
        case tags
        case isActive = "is_active"
        case isFavorite = "is_favorite"
    }
    
    public init(
        id: String,
        name: String,
        description: String? = nil,
        path: String,
        gitRepository: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastAccessedAt: Date? = nil,
        metadata: ProjectMetadata? = nil,
        settings: ProjectSettings? = nil,
        tags: [String] = [],
        isActive: Bool = true,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.path = path
        self.gitRepository = gitRepository
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastAccessedAt = lastAccessedAt
        self.metadata = metadata
        self.settings = settings
        self.tags = tags
        self.isActive = isActive
        self.isFavorite = isFavorite
    }
}

/// Project metadata
public struct ProjectMetadata: Codable, Equatable {
    public var language: String?
    public var framework: String?
    public var dependencies: [String]?
    public var environment: [String: String]?
    public var statistics: ProjectStatistics?
    
    public init(
        language: String? = nil,
        framework: String? = nil,
        dependencies: [String]? = nil,
        environment: [String: String]? = nil,
        statistics: ProjectStatistics? = nil
    ) {
        self.language = language
        self.framework = framework
        self.dependencies = dependencies
        self.environment = environment
        self.statistics = statistics
    }
}

/// Project statistics
public struct ProjectStatistics: Codable, Equatable {
    public let fileCount: Int?
    public let lineCount: Int?
    public let size: Int64? // in bytes
    public let lastCommit: String?
    public let branch: String?
    
    enum CodingKeys: String, CodingKey {
        case fileCount = "file_count"
        case lineCount = "line_count"
        case size
        case lastCommit = "last_commit"
        case branch
    }
}

/// Project settings
public struct ProjectSettings: Codable, Equatable {
    public var defaultModel: String?
    public var temperature: Double?
    public var maxTokens: Int?
    public var systemPrompt: String?
    public var excludePaths: [String]?
    public var includePaths: [String]?
    public var autoSave: Bool
    public var syncWithGit: Bool
    
    enum CodingKeys: String, CodingKey {
        case defaultModel = "default_model"
        case temperature
        case maxTokens = "max_tokens"
        case systemPrompt = "system_prompt"
        case excludePaths = "exclude_paths"
        case includePaths = "include_paths"
        case autoSave = "auto_save"
        case syncWithGit = "sync_with_git"
    }
    
    public init(
        defaultModel: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        systemPrompt: String? = nil,
        excludePaths: [String]? = nil,
        includePaths: [String]? = nil,
        autoSave: Bool = true,
        syncWithGit: Bool = false
    ) {
        self.defaultModel = defaultModel
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.excludePaths = excludePaths
        self.includePaths = includePaths
        self.autoSave = autoSave
        self.syncWithGit = syncWithGit
    }
}

/// Create project request
public struct CreateProjectRequest: Codable {
    public let name: String
    public let description: String?
    public let path: String
    public let gitRepository: String?
    public let settings: ProjectSettings?
    public let tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case path
        case gitRepository = "git_repository"
        case settings
        case tags
    }
    
    public init(
        name: String,
        description: String? = nil,
        path: String,
        gitRepository: String? = nil,
        settings: ProjectSettings? = nil,
        tags: [String]? = nil
    ) {
        self.name = name
        self.description = description
        self.path = path
        self.gitRepository = gitRepository
        self.settings = settings
        self.tags = tags
    }
}

/// Projects response
public struct ProjectsResponse: Codable {
    public let projects: [ProjectInfo]
    public let totalCount: Int?
    public let page: Int?
    public let pageSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case projects
        case totalCount = "total_count"
        case page
        case pageSize = "page_size"
    }
}

/// Delete response
public struct DeleteResponse: Codable {
    public let success: Bool
    public let message: String?
}