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
final class ProjectStore: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var projects: [Project] = []
    @Published var currentProject: Project?
    @Published var isLoading = false
    @Published var error: ProjectError?
    @Published var searchText = ""
    
    // MARK: - Computed Properties
    
    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projects
        }
        return projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.path.localizedCaseInsensitiveContains(searchText) ||
            $0.description?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    var activeProjects: [Project] {
        projects.filter { $0.isActive }
    }
    
    var recentProjects: [Project] {
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
    
    init() {
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
    func createProject(name: String, path: String, type: ProjectType = .general) -> Project {
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
    func updateProject(_ project: Project, updates: (inout Project) -> Void) {
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
    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        
        if currentProject?.id == project.id {
            currentProject = projects.first
        }
        
        pendingChanges = true
    }
    
    /// Set active project
    func setActiveProject(_ project: Project) {
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
    func addSSHConfig(to project: Project, config: AppSSHConfig) {
        updateProject(project) { proj in
            proj.sshConfig = config
        }
    }
    
    /// Remove SSH configuration from project
    func removeSSHConfig(from project: Project) {
        updateProject(project) { proj in
            proj.sshConfig = nil
        }
    }
    
    /// Add environment variable to project
    func addEnvironmentVariable(to project: Project, key: String, value: String) {
        updateProject(project) { proj in
            if proj.environmentVariables == nil {
                proj.environmentVariables = [:]
            }
            proj.environmentVariables?[key] = value
        }
    }
    
    /// Remove environment variable from project
    func removeEnvironmentVariable(from project: Project, key: String) {
        updateProject(project) { proj in
            proj.environmentVariables?.removeValue(forKey: key)
        }
    }
    
    // MARK: - Persistence
    
    /// Load projects from disk
    func loadProjects() async {
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
    func saveProjects() async {
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
    func savePendingChanges() async {
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
    func clearAll() {
        projects.removeAll()
        currentProject = nil
        pendingChanges = true
    }
    
    deinit {
        autoSaveTimer?.invalidate()
    }
}

// MARK: - Models

struct Project: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var path: String
    var type: ProjectType
    var description: String?
    var isActive: Bool
    var sshConfig: AppSSHConfig?
    var environmentVariables: [String: String]?
    let createdAt: Date
    var lastAccessedAt: Date?
    
    init(id: String = UUID().uuidString,
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

enum ProjectType: String, Codable, CaseIterable {
    case general = "general"
    case ios = "ios"
    case web = "web"
    case backend = "backend"
    case ml = "ml"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .ios: return "iOS"
        case .web: return "Web"
        case .backend: return "Backend"
        case .ml: return "Machine Learning"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "folder"
        case .ios: return "iphone"
        case .web: return "globe"
        case .backend: return "server.rack"
        case .ml: return "brain"
        }
    }
}

enum ProjectError: LocalizedError {
    case projectNotFound
    case invalidPath
    case sshConnectionFailed(String)
    case saveFailed(Error)
    case loadFailed(Error)
    
    var errorDescription: String? {
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
        }
    }
}