//
//  ProjectStore.swift
//  ClaudeCode
//
//  Manages project configurations and SSH connections
//

import SwiftUI
import Combine

/// Store for managing projects and their configurations
@MainActor
public final class ProjectStore: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var projects: [Project] = []
    @Published public var currentProject: Project?
    @Published public var activeProjectId: String?
    @Published public var isLoading = false
    @Published public var error: ProjectError?
    @Published public var searchText = ""
    
    // MARK: - Computed Properties
    
    public var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projects
        }
        return projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.path.localizedCaseInsensitiveContains(searchText) ||
            $0.description?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    public var activeProjects: [Project] {
        projects.filter { $0.isActive }
    }
    
    public var recentProjects: [Project] {
        projects.sorted { $0.lastAccessedAt ?? Date.distantPast > $1.lastAccessedAt ?? Date.distantPast }
            .prefix(5)
            .map { $0 }
    }
    
    // MARK: - Private Properties
    
    private let documentsDirectory: URL
    private let projectsFile = "projects.json"
    private var pendingChanges = false
    private var autoSaveTimer: Timer?
    
    // MARK: - Initialization
    
    public init() {
        self.documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        
        Task {
            await loadProjects()
        }
        
        setupAutoSave()
    }
    
    // MARK: - Public Methods
    
    /// Create a new project
    public func createProject(name: String, path: String, type: ProjectType = .general) -> Project {
        let project = Project(
            name: name,
            path: path,
            type: type,
            createdAt: Date()
        )
        
        projects.insert(project, at: 0)
        currentProject = project
        pendingChanges = true
        
        return project
    }
    
    /// Update project configuration
    public func updateProject(_ project: Project, updates: (inout Project) -> Void) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            updates(&projects[index])
            projects[index].lastAccessedAt = Date()
            
            if currentProject?.id == project.id {
                currentProject = projects[index]
            }
            
            pendingChanges = true
        }
    }
    
    /// Delete a project
    public func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        
        if currentProject?.id == project.id {
            currentProject = projects.first
        }
        
        pendingChanges = true
    }
    
    /// Set active project
    public func setActiveProject(_ project: Project) {
        // Deactivate all projects
        for index in projects.indices {
            projects[index].isActive = false
        }
        
        // Activate selected project
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].isActive = true
            projects[index].lastAccessedAt = Date()
            currentProject = projects[index]
        }
        
        pendingChanges = true
    }
    
    /// Add SSH configuration to project
    public func addSSHConfig(to project: Project, config: AppSSHConfig) {
        updateProject(project) { proj in
            proj.sshConfig = config
        }
    }
    
    /// Remove SSH configuration from project
    public func removeSSHConfig(from project: Project) {
        updateProject(project) { proj in
            proj.sshConfig = nil
        }
    }
    
    /// Add environment variable to project
    public func addEnvironmentVariable(to project: Project, key: String, value: String) {
        updateProject(project) { proj in
            if proj.environmentVariables == nil {
                proj.environmentVariables = [:]
            }
            proj.environmentVariables?[key] = value
        }
    }
    
    /// Remove environment variable from project
    public func removeEnvironmentVariable(from project: Project, key: String) {
        updateProject(project) { proj in
            proj.environmentVariables?.removeValue(forKey: key)
        }
    }
    
    /// Duplicate a project
    public func duplicateProject(_ project: Project) -> Project {
        let duplicated = Project(
            name: "\(project.name) (Copy)",
            path: project.path,
            type: project.type,
            description: project.description,
            isActive: false,
            sshConfig: project.sshConfig,
            environmentVariables: project.environmentVariables,
            createdAt: Date()
        )
        
        projects.insert(duplicated, at: 0)
        pendingChanges = true
        
        return duplicated
    }
    
    /// Update SSH configuration
    public func updateSSHConfig(for project: Project, config: AppSSHConfig) {
        updateProject(project) { proj in
            proj.sshConfig = config
        }
    }
    
    /// Get project by ID
    public func getProject(by id: String) -> Project? {
        projects.first { $0.id == id }
    }
    
    /// Update environment variables
    public func updateEnvironmentVariables(for project: Project, variables: [String: String]) {
        updateProject(project) { proj in
            proj.environmentVariables = variables
        }
    }
    
    // MARK: - Persistence
    
    /// Load projects from disk
    public func loadProjects() async {
        let fileURL = documentsDirectory.appendingPathComponent(projectsFile)
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            projects = try decoder.decode([Project].self, from: data)
            
            // Set current project to the active one
            currentProject = projects.first { $0.isActive }
        } catch {
            print("Failed to load projects: \(error)")
            projects = []
        }
    }
    
    /// Save projects to disk
    public func saveProjects() async {
        let fileURL = documentsDirectory.appendingPathComponent(projectsFile)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(projects)
            try data.write(to: fileURL)
            pendingChanges = false
        } catch {
            print("Failed to save projects: \(error)")
        }
    }
    
    /// Save pending changes if any
    public func savePendingChanges() async {
        if pendingChanges {
            await saveProjects()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.savePendingChanges()
            }
        }
    }
    
    /// Clear all projects
    public func clearAll() {
        projects.removeAll()
        currentProject = nil
        pendingChanges = true
    }
    
    deinit {
        // Timer invalidation handled in MainActor context when needed
    }
}

// MARK: - Models

public struct Project: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var path: String
    public var type: ProjectType
    public var description: String?
    public var isActive: Bool
    public var sshConfig: AppSSHConfig?
    public var environmentVariables: [String: String]?
    public let createdAt: Date
    public var lastAccessedAt: Date?
    
    public init(id: String = UUID().uuidString,
         name: String,
         path: String,
         type: ProjectType = .general,
         description: String? = nil,
         isActive: Bool = false,
         sshConfig: AppSSHConfig? = nil,
         environmentVariables: [String: String]? = nil,
         createdAt: Date = Date(),
         lastAccessedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.description = description
        self.isActive = isActive
        self.sshConfig = sshConfig
        self.environmentVariables = environmentVariables
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
    }
}

public enum ProjectType: String, Codable, CaseIterable {
    case general = "general"
    case ios = "ios"
    case web = "web"
    case backend = "backend"
    case ml = "ml"
    
    public var displayName: String {
        switch self {
        case .general: return "General"
        case .ios: return "iOS"
        case .web: return "Web"
        case .backend: return "Backend"
        case .ml: return "Machine Learning"
        }
    }
    
    public var icon: String {
        switch self {
        case .general: return "folder"
        case .ios: return "iphone"
        case .web: return "globe"
        case .backend: return "server.rack"
        case .ml: return "brain"
        }
    }
}

public enum ProjectError: LocalizedError {
    case projectNotFound
    case invalidPath
    case sshConnectionFailed(String)
    case saveFailed(Error)
    case loadFailed(Error)
    case noSSHConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "Project not found"
        case .invalidPath:
            return "Invalid project path"
        case .sshConnectionFailed(let message):
            return "SSH connection failed: \(message)"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load: \(error.localizedDescription)"
        case .noSSHConfiguration:
            return "No SSH configuration found for this project"
        }
    }
}