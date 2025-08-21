//
//  ProjectViewModel.swift
//  ClaudeCode
//
//  ViewModel for project management with MVVM pattern
//

import SwiftUI
import Combine

/// ViewModel for managing projects
@MainActor
final class ProjectViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var projects: [Project] = []
    @Published var currentProject: Project?
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showError = false
    @Published var showCreateProject = false
    @Published var showEditProject = false
    @Published var selectedProject: Project?
    
    // MARK: - Project Creation
    
    @Published var newProjectName = ""
    @Published var newProjectPath = ""
    @Published var newProjectType: ProjectType = .general
    @Published var newProjectDescription = ""
    
    // MARK: - SSH Configuration
    
    @Published var showSSHConfig = false
    @Published var sshHost = ""
    @Published var sshPort = 22
    @Published var sshUsername = ""
    @Published var sshAuthMethod: SSHAuthMethod = .publicKey
    @Published var sshPrivateKey = ""
    @Published var sshPassphrase = ""
    
    // MARK: - Environment Variables
    
    @Published var showEnvVarEditor = false
    @Published var envVarKey = ""
    @Published var envVarValue = ""
    @Published var environmentVariables: [String: String] = [:]
    
    // MARK: - Private Properties
    
    private let projectStore: ProjectStore
    private let sshManager: SSHManager
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private let projectId: String?
    
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
    
    var hasProjects: Bool {
        !projects.isEmpty
    }
    
    var canCreateProject: Bool {
        !newProjectName.isEmpty && !newProjectPath.isEmpty
    }
    
    var canSaveSSHConfig: Bool {
        !sshHost.isEmpty && !sshUsername.isEmpty && sshPort > 0
    }
    
    // MARK: - Initialization
    
    init(projectId: String? = nil,
         projectStore: ProjectStore,
         sshManager: SSHManager,
         appState: AppState) {
        self.projectId = projectId
        self.projectStore = projectStore
        self.sshManager = sshManager
        self.appState = appState
        
        setupBindings()
        loadProjects()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe project store changes
        projectStore.$projects
            .sink { [weak self] projects in
                self?.projects = projects
            }
            .store(in: &cancellables)
        
        projectStore.$currentProject
            .sink { [weak self] project in
                self?.currentProject = project
            }
            .store(in: &cancellables)
    }
    
    private func loadProjects() {
        projects = projectStore.projects
        currentProject = projectStore.currentProject
        
        if let projectId = projectId {
            selectedProject = projects.first { $0.id == projectId }
        }
    }
    
    // MARK: - Public Methods - Project Management
    
    /// Create a new project
    func createProject() {
        guard canCreateProject else { return }
        
        let project = projectStore.createProject(
            name: newProjectName,
            path: newProjectPath,
            type: newProjectType
        )
        
        if !newProjectDescription.isEmpty {
            projectStore.updateProject(project) { proj in
                proj.description = newProjectDescription
            }
        }
        
        // Clear form
        clearNewProjectForm()
        showCreateProject = false
        
        // Set as active project
        setActiveProject(project)
    }
    
    /// Edit existing project
    func editProject(_ project: Project) {
        selectedProject = project
        newProjectName = project.name
        newProjectPath = project.path
        newProjectType = project.type
        newProjectDescription = project.description ?? ""
        showEditProject = true
    }
    
    /// Save project edits
    func saveProjectEdits() {
        guard let project = selectedProject else { return }
        
        projectStore.updateProject(project) { proj in
            proj.name = newProjectName
            proj.path = newProjectPath
            proj.type = newProjectType
            proj.description = newProjectDescription.isEmpty ? nil : newProjectDescription
        }
        
        clearNewProjectForm()
        showEditProject = false
        selectedProject = nil
    }
    
    /// Delete a project
    func deleteProject(_ project: Project) {
        projectStore.deleteProject(project)
    }
    
    /// Set active project
    func setActiveProject(_ project: Project) {
        projectStore.setActiveProject(project)
        
        // Update app state
        appState.selectedProjectId = project.id
        
        // Connect SSH if configured
        if let sshConfig = project.sshConfig {
            Task {
                await connectSSH(with: sshConfig)
            }
        }
    }
    
    /// Duplicate a project
    func duplicateProject(_ project: Project) {
        let duplicated = projectStore.createProject(
            name: "\(project.name) Copy",
            path: project.path,
            type: project.type
        )
        
        // Copy configuration
        projectStore.updateProject(duplicated) { proj in
            proj.description = project.description
            proj.sshConfig = project.sshConfig
            proj.environmentVariables = project.environmentVariables
        }
    }
    
    // MARK: - Public Methods - SSH Configuration
    
    /// Open SSH configuration for project
    func openSSHConfig(for project: Project) {
        selectedProject = project
        
        if let config = project.sshConfig {
            sshHost = config.host
            sshPort = config.port
            sshUsername = config.username
            sshAuthMethod = config.authMethod
            sshPrivateKey = config.privateKeyPath ?? ""
            sshPassphrase = config.passphrase ?? ""
        } else {
            clearSSHForm()
        }
        
        showSSHConfig = true
    }
    
    /// Save SSH configuration
    func saveSSHConfig() {
        guard let project = selectedProject, canSaveSSHConfig else { return }
        
        let config = SSHConfig(
            host: sshHost,
            port: sshPort,
            username: sshUsername,
            authMethod: sshAuthMethod,
            privateKeyPath: sshPrivateKey.isEmpty ? nil : sshPrivateKey,
            passphrase: sshPassphrase.isEmpty ? nil : sshPassphrase
        )
        
        projectStore.addSSHConfig(to: project, config: config)
        clearSSHForm()
        showSSHConfig = false
    }
    
    /// Test SSH connection
    func testSSHConnection() async {
        guard canSaveSSHConfig else { return }
        
        isLoading = true
        
        let config = SSHConfig(
            host: sshHost,
            port: sshPort,
            username: sshUsername,
            authMethod: sshAuthMethod,
            privateKeyPath: sshPrivateKey.isEmpty ? nil : sshPrivateKey,
            passphrase: sshPassphrase.isEmpty ? nil : sshPassphrase
        )
        
        let success = await sshManager.testConnection(config: config)
        
        if success {
            showSuccess(message: "SSH connection successful")
        } else {
            showErrorMessage("SSH connection failed")
        }
        
        isLoading = false
    }
    
    /// Connect SSH for project
    func connectSSH(with config: SSHConfig) async {
        isLoading = true
        
        do {
            await sshManager.connect(config: config)
            showSuccess(message: "Connected to SSH")
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    /// Disconnect SSH
    func disconnectSSH() async {
        await sshManager.disconnect()
    }
    
    // MARK: - Public Methods - Environment Variables
    
    /// Open environment variables editor
    func openEnvVarEditor(for project: Project) {
        selectedProject = project
        environmentVariables = project.environmentVariables ?? [:]
        showEnvVarEditor = true
    }
    
    /// Add environment variable
    func addEnvironmentVariable() {
        guard !envVarKey.isEmpty, !envVarValue.isEmpty else { return }
        
        environmentVariables[envVarKey] = envVarValue
        
        // Clear form
        envVarKey = ""
        envVarValue = ""
    }
    
    /// Remove environment variable
    func removeEnvironmentVariable(_ key: String) {
        environmentVariables.removeValue(forKey: key)
    }
    
    /// Save environment variables
    func saveEnvironmentVariables() {
        guard let project = selectedProject else { return }
        
        projectStore.updateProject(project) { proj in
            proj.environmentVariables = environmentVariables.isEmpty ? nil : environmentVariables
        }
        
        showEnvVarEditor = false
    }
    
    // MARK: - Public Methods - Search
    
    /// Search projects
    func searchProjects(_ text: String) {
        searchText = text
    }
    
    /// Clear search
    func clearSearch() {
        searchText = ""
    }
    
    // MARK: - Private Methods
    
    private func clearNewProjectForm() {
        newProjectName = ""
        newProjectPath = ""
        newProjectType = .general
        newProjectDescription = ""
    }
    
    private func clearSSHForm() {
        sshHost = ""
        sshPort = 22
        sshUsername = ""
        sshAuthMethod = .publicKey
        sshPrivateKey = ""
        sshPassphrase = ""
    }
    
    private func showSuccess(message: String) {
        // Show success feedback
        let impactFeedback = UINotificationFeedbackGenerator()
        impactFeedback.notificationOccurred(.success)
    }
    
    private func showErrorMessage(_ message: String) {
        error = ProjectError.sshConnectionFailed(message)
        showError = true
        
        let impactFeedback = UINotificationFeedbackGenerator()
        impactFeedback.notificationOccurred(.error)
    }
    
    private func handleError(_ error: Error) {
        self.error = error
        showError = true
        
        let impactFeedback = UINotificationFeedbackGenerator()
        impactFeedback.notificationOccurred(.error)
    }
}