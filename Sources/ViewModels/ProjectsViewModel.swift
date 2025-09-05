//
//  ProjectsViewModel.swift
//  ClaudeCode
//
//  ViewModel for managing projects with real backend API integration
//

import SwiftUI
import Combine
import OSLog

/// ViewModel for managing projects
@MainActor
public final class ProjectsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var projects: [Project] = []
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var showError = false
    @Published public var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Private Properties
    
    private let apiClient: APIClient
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "ProjectsViewModel")
    
    // MARK: - Initialization
    
    public init(apiClient: APIClient, appState: AppState) {
        self.apiClient = apiClient
        self.appState = appState
        
        setupBindings()
        checkConnection()
        loadProjects()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe app state changes
        appState.$isConnected
            .sink { [weak self] isConnected in
                self?.connectionStatus = isConnected ? .connected : .disconnected
            }
            .store(in: &cancellables)
    }
    
    private func checkConnection() {
        Task {
            connectionStatus = .connecting
            let isHealthy = await apiClient.checkHealth()
            connectionStatus = isHealthy ? .connected : .disconnected
            
            if !isHealthy {
                logger.error("Backend not available at \(APIConfig.baseURL.absoluteString)")
                showBackendError()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Load projects from backend
    public func loadProjects() {
        Task {
            await fetchProjects()
        }
    }
    
    /// Refresh projects
    public func refreshProjects() async {
        await fetchProjects()
    }
    
    /// Create a new project
    public func createProject(_ project: Project) async throws {
        isLoading = true
        error = nil
        
        do {
            // Create project request
            let request = CreateProjectRequest(
                name: project.name,
                path: "/Users/\(NSUserName())/Projects/\(project.name.replacingOccurrences(of: " ", with: "_"))",
                language: "swift",
                framework: "SwiftUI",
                metadata: nil
            )
            
            // Call API
            let projectInfo = try await apiClient.createProject(request)
            
            // Convert to local Project model
            let newProject = Project(
                id: projectInfo.id,
                name: projectInfo.name,
                path: projectInfo.path,
                type: .general,
                description: project.description,
                isActive: projectInfo.isActive,
                sshConfig: project.sshConfig
            )
            
            // Add to projects list
            projects.insert(newProject, at: 0)
            
            logger.info("Created project: \(projectInfo.name)")
        } catch {
            logger.error("Failed to create project: \(error)")
            self.error = error
            showError = true
            throw error
        }
        
        isLoading = false
    }
    
    /// Delete a project
    public func deleteProject(_ project: Project) async throws {
        isLoading = true
        error = nil
        
        do {
            let success = try await apiClient.deleteProject(id: project.id)
            
            if success {
                projects.removeAll { $0.id == project.id }
                logger.info("Deleted project: \(project.name)")
            }
        } catch {
            logger.error("Failed to delete project: \(error)")
            self.error = error
            showError = true
            throw error
        }
        
        isLoading = false
    }
    
    /// Update a project
    public func updateProject(_ project: Project) async throws {
        isLoading = true
        error = nil
        
        do {
            // Call API with CreateProjectRequest
            let projectInfo = try await apiClient.updateProject(
                id: project.id,
                request: CreateProjectRequest(
                    name: project.name,
                    path: "/Users/\(NSUserName())/Projects/\(project.name.replacingOccurrences(of: " ", with: "_"))",
                    language: "swift",
                    framework: "SwiftUI",
                    metadata: nil
                )
            )
            
            // Update local project
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = Project(
                    id: projectInfo.id,
                    name: projectInfo.name,
                    path: projectInfo.path,
                    type: .general,
                    description: project.description,
                    isActive: projectInfo.isActive,
                    sshConfig: project.sshConfig
                )
            }
            
            logger.info("Updated project: \(project.name)")
        } catch {
            logger.error("Failed to update project: \(error)")
            self.error = error
            showError = true
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func fetchProjects() async {
        isLoading = true
        error = nil
        
        do {
            let projectList = try await apiClient.listProjects()
            
            // Convert API projects to local Project model
            self.projects = projectList.map { projectInfo in
                Project(
                    id: projectInfo.id,
                    name: projectInfo.name,
                    path: projectInfo.path,
                    type: .general,
                    description: projectInfo.description ?? "",
                    isActive: projectInfo.isActive,
                    sshConfig: nil, // TODO: Get SSH config from API
                    environmentVariables: nil,
                    createdAt: projectInfo.createdAt ?? Date(),
                    lastAccessedAt: projectInfo.updatedAt
                )
            }
            
            logger.info("Loaded \(self.projects.count) projects from backend")
        } catch let configError as APIConfig.ConfigError {
            handleConfigError(configError)
        } catch {
            logger.error("Failed to load projects: \(error)")
            self.error = error
            showError = true
            
            // Fall back to empty list
            self.projects = []
        }
        
        isLoading = false
    }
    
    private func iconForProject(_ name: String) -> String {
        // Determine icon based on project name
        let lowercased = name.lowercased()
        
        if lowercased.contains("ios") || lowercased.contains("iphone") || lowercased.contains("ipad") {
            return "iphone"
        } else if lowercased.contains("web") || lowercased.contains("dashboard") {
            return "globe"
        } else if lowercased.contains("api") || lowercased.contains("backend") || lowercased.contains("server") {
            return "server.rack"
        } else if lowercased.contains("ml") || lowercased.contains("ai") || lowercased.contains("machine") {
            return "brain"
        } else {
            return "folder.fill"
        }
    }
    
    private func handleConfigError(_ configError: APIConfig.ConfigError) {
        switch configError {
        case .backendNotRunning:
            logger.error("Backend server is not running")
            showBackendError()
        case .unauthorized:
            error = configError
            showError = true
        case .networkError(let netError):
            logger.error("Network error: \(netError)")
            error = configError
            showError = true
        default:
            error = configError
            showError = true
        }
    }
    
    private func handleAPIError(_ apiError: APIError) {
        switch apiError {
        case .backendNotRunning:
            logger.error("Backend server is not running")
            showBackendError()
        case .unauthorized:
            error = apiError
            showError = true
        case .networkError(let netError):
            logger.error("Network error: \(netError)")
            error = apiError
            showError = true
        default:
            error = apiError
            showError = true
        }
    }
    
    private func showBackendError() {
        error = APIConfig.ConfigError.backendNotRunning
        showError = true
        
        // Provide helpful message
        logger.error("Backend not running! Start with: cd claude-code-api && make start")
    }
}

// MARK: - API Request/Response Models
// CreateProjectRequest is now defined in NetworkModels.swift

public struct UpdateProjectRequest: Codable {
    let name: String?
    let description: String?
    let isActive: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case isActive = "is_active"
    }
}