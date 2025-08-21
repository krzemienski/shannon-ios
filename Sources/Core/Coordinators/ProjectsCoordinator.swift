//
//  ProjectsCoordinator.swift
//  ClaudeCode
//
//  Coordinator for project management navigation and flow
//

import SwiftUI
import Combine

/// Coordinator managing projects navigation and flow
@MainActor
final class ProjectsCoordinator: BaseCoordinator, ObservableObject {
    
    // MARK: - Navigation State
    
    @Published var navigationPath = NavigationPath()
    @Published var selectedProjectId: String?
    @Published var isShowingNewProject = false
    @Published var isShowingProjectSettings = false
    @Published var isShowingSSHConfig = false
    @Published var isShowingEnvironmentVariables = false
    
    // MARK: - Dependencies
    
    weak var appCoordinator: AppCoordinator?
    private let dependencyContainer: DependencyContainer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - View Models
    
    private var projectViewModels: [String: ProjectViewModel] = [:]
    
    // MARK: - Initialization
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        super.init()
        observeProjectStore()
    }
    
    // MARK: - Setup
    
    private func observeProjectStore() {
        // Observe active project changes
        dependencyContainer.projectStore.$activeProjectId
            .removeDuplicates()
            .sink { [weak self] projectId in
                self?.selectedProjectId = projectId
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Coordinator Lifecycle
    
    override func start() {
        // Load initial projects
        Task {
            await dependencyContainer.projectStore.loadProjects()
        }
    }
    
    // MARK: - Navigation
    
    func handleTabSelection() {
        // Called when projects tab is selected
        if selectedProjectId == nil {
            // Select first project or show new project
            if let first = dependencyContainer.projectStore.projects.first {
                openProject(id: first.id)
            } else {
                showNewProject()
            }
        }
    }
    
    func openProject(id: String) {
        selectedProjectId = id
        dependencyContainer.projectStore.setActiveProject(id)
        
        // Navigate to project detail
        navigationPath.append(ProjectRoute.detail(id))
    }
    
    func showNewProject() {
        isShowingNewProject = true
        appCoordinator?.presentSheet(.newProject)
    }
    
    func createProject(name: String, path: String, sshConfig: SSHConfiguration?) {
        isShowingNewProject = false
        
        Task {
            let project = await dependencyContainer.projectStore.createProject(
                name: name,
                path: path,
                sshConfig: sshConfig
            )
            openProject(id: project.id)
        }
    }
    
    func deleteProject(id: String) {
        Task {
            await dependencyContainer.projectStore.deleteProject(id: id)
            
            // If deleted project was selected, select another
            if selectedProjectId == id {
                selectedProjectId = nil
                if let first = dependencyContainer.projectStore.projects.first {
                    openProject(id: first.id)
                }
            }
        }
    }
    
    // MARK: - Project Management
    
    func showProjectSettings(for projectId: String) {
        isShowingProjectSettings = true
        appCoordinator?.presentSheet(.projectSettings(projectId))
    }
    
    func updateProject(_ project: Project) {
        Task {
            await dependencyContainer.projectStore.updateProject(project)
        }
    }
    
    func duplicateProject(id: String) {
        Task {
            let newProject = await dependencyContainer.projectStore.duplicateProject(id: id)
            openProject(id: newProject.id)
        }
    }
    
    // MARK: - SSH Configuration
    
    func showSSHConfig(for projectId: String) {
        isShowingSSHConfig = true
        navigationPath.append(ProjectRoute.sshConfig(projectId))
    }
    
    func updateSSHConfig(for projectId: String, config: SSHConfiguration) {
        Task {
            await dependencyContainer.projectStore.updateSSHConfig(
                projectId: projectId,
                config: config
            )
        }
    }
    
    func testSSHConnection(for projectId: String) async -> Bool {
        guard let project = dependencyContainer.projectStore.getProject(id: projectId),
              let sshConfig = project.sshConfiguration else {
            return false
        }
        
        return await dependencyContainer.sshManager.testConnection(config: sshConfig)
    }
    
    func connectSSH(for projectId: String) async throws {
        guard let project = dependencyContainer.projectStore.getProject(id: projectId),
              let sshConfig = project.sshConfiguration else {
            throw ProjectError.noSSHConfiguration
        }
        
        try await dependencyContainer.sshManager.connect(config: sshConfig)
    }
    
    func disconnectSSH() async {
        await dependencyContainer.sshManager.disconnect()
    }
    
    // MARK: - Environment Variables
    
    func showEnvironmentVariables(for projectId: String) {
        isShowingEnvironmentVariables = true
        navigationPath.append(ProjectRoute.environmentVariables(projectId))
    }
    
    func updateEnvironmentVariables(for projectId: String, variables: [String: String]) {
        Task {
            await dependencyContainer.projectStore.updateEnvironmentVariables(
                projectId: projectId,
                variables: variables
            )
        }
    }
    
    // MARK: - File Management
    
    func openFile(at path: String, in projectId: String) {
        navigationPath.append(ProjectRoute.fileEditor(projectId, path))
    }
    
    func openTerminal(for projectId: String) {
        navigationPath.append(ProjectRoute.terminal(projectId))
    }
    
    // MARK: - View Model Management
    
    func getProjectViewModel(for projectId: String) -> ProjectViewModel {
        if let existing = projectViewModels[projectId] {
            return existing
        }
        
        let viewModel = dependencyContainer.makeProjectViewModel(projectId: projectId)
        projectViewModels[projectId] = viewModel
        return viewModel
    }
    
    func cleanupViewModel(for projectId: String) {
        projectViewModels.removeValue(forKey: projectId)
    }
    
    // MARK: - Error Handling
    
    func handleProjectError(_ error: Error) {
        appCoordinator?.showError(error) { [weak self] in
            // Retry logic based on error type
            if error is NetworkError {
                Task {
                    await self?.dependencyContainer.projectStore.loadProjects()
                }
            }
        }
    }
}

// MARK: - Navigation Routes

enum ProjectRoute: Hashable {
    case detail(String)
    case sshConfig(String)
    case environmentVariables(String)
    case fileEditor(String, String) // projectId, filePath
    case terminal(String)
}

// MARK: - Supporting Types

enum ProjectError: LocalizedError {
    case noSSHConfiguration
    case connectionFailed
    case invalidPath
    
    var errorDescription: String? {
        switch self {
        case .noSSHConfiguration:
            return "No SSH configuration found for this project"
        case .connectionFailed:
            return "Failed to establish SSH connection"
        case .invalidPath:
            return "Invalid project path"
        }
    }
}