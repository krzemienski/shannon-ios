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
final class ProjectsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showError = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Private Properties
    
    private let apiClient: APIClient
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "ProjectsViewModel")
    
    // MARK: - Initialization
    
    init(apiClient: APIClient, appState: AppState) {
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
    func loadProjects() {
        Task {
            await fetchProjects()
        }
    }
    
    /// Refresh projects
    func refreshProjects() async {
        await fetchProjects()
    }
    
    /// Create a new project
    func createProject(_ project: Project) async throws {
        isLoading = true
        error = nil
        
        do {
            // Create project request
            let request = CreateProjectRequest(
                name: project.name,
                description: project.description,
                path: "/Users/\(NSUserName())/Projects/\(project.name.replacingOccurrences(of: " ", with: "_"))",
                gitRemote: nil
            )
            
            // Call API
            let projectInfo = try await apiClient.createProject(request)
            
            // Convert to local Project model
            let newProject = Project(
                id: projectInfo.id,
                name: projectInfo.name,
                description: projectInfo.description ?? project.description,
                icon: project.icon,
                isActive: projectInfo.isActive,
                sessionCount: 0,
                toolCount: 0,
                lastUpdated: projectInfo.createdAt ?? Date(),
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
    func deleteProject(_ project: Project) async throws {
        isLoading = true
        error = nil
        
        do {
            let success = try await apiClient.deleteProject(projectId: project.id)
            
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
    func updateProject(_ project: Project) async throws {
        isLoading = true
        error = nil
        
        do {
            // Update project request
            let request = UpdateProjectRequest(
                name: project.name,
                description: project.description,
                isActive: project.isActive
            )
            
            // Call API
            let projectInfo = try await apiClient.updateProject(
                projectId: project.id,
                updates: request
            )
            
            // Update local project
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = Project(
                    id: projectInfo.id,
                    name: projectInfo.name,
                    description: projectInfo.description ?? project.description,
                    icon: project.icon,
                    isActive: projectInfo.isActive,
                    sessionCount: project.sessionCount,
                    toolCount: project.toolCount,
                    lastUpdated: projectInfo.updatedAt ?? Date(),
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
                    description: projectInfo.description ?? "",
                    icon: iconForProject(projectInfo.name),
                    isActive: projectInfo.isActive,
                    sessionCount: projectInfo.sessionCount ?? 0,
                    toolCount: 0, // TODO: Get tool count from API
                    lastUpdated: projectInfo.updatedAt ?? projectInfo.createdAt ?? Date(),
                    sshConfig: nil // TODO: Get SSH config from API
                )
            }
            
            logger.info("Loaded \(projects.count) projects from backend")
        } catch let apiError as APIConfig.APIError {
            handleAPIError(apiError)
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
        error = APIConfig.APIError.backendNotRunning
        showError = true
        
        // Provide helpful message
        logger.error("Backend not running! Start with: cd claude-code-api && make start")
    }
}

// MARK: - API Request/Response Models
// CreateProjectRequest is now defined in NetworkModels.swift

struct UpdateProjectRequest: Codable {
    let name: String?
    let description: String?
    let isActive: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case isActive = "is_active"
    }
}