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
public final class ProjectViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var projects: [Project] = []
    @Published public var currentProject: Project?
    @Published public var searchText = ""
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var showError = false
    @Published public var showCreateProject = false
    @Published public var showEditProject = false
    @Published public var selectedProject: Project?
    
    // MARK: - Project Creation
    
    @Published public var newProjectName = ""
    @Published public var newProjectPath = ""
    @Published public var newProjectType: ProjectType = .general
    @Published public var newProjectDescription = ""
    
    // MARK: - SSH Configuration
    
    @Published public var showSSHConfig = false
    @Published public var sshHost = ""
    @Published public var sshPort = 22
    @Published public var sshUsername = ""
    @Published public var sshAuthMethod: AppSSHAuthMethod = .publicKey
    @Published public var sshPrivateKey = ""
    @Published public var sshPassphrase = ""
    
    // MARK: - Environment Variables
    
    @Published public var showEnvVarEditor = false
    @Published public var envVarKey = ""
    @Published public var envVarValue = ""
    @Published public var environmentVariables: [String: String] = [:]
    
    // MARK: - Private Properties
    
    private let projectStore: ProjectStore
    private let sshManager: SSHManager
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private let projectId: String?
    
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
    
    public var hasProjects: Bool {
        !projects.isEmpty
    }
    
    public var canCreateProject: Bool {
        !newProjectName.isEmpty && !newProjectPath.isEmpty
    }
    
    public var canSaveSSHConfig: Bool {
        !sshHost.isEmpty && !sshUsername.isEmpty && sshPort > 0
    }
    
    // MARK: - Initialization
    
    public init(projectId: String? = nil,
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
    public func createProject() {
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
    public func editProject(_ project: Project) {
        selectedProject = project
        newProjectName = project.name
        newProjectPath = project.path
        newProjectType = project.type
        newProjectDescription = project.description ?? ""
        showEditProject = true
    }
    
    /// Save project edits
    public func saveProjectEdits() {
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
    public func deleteProject(_ project: Project) {
        projectStore.deleteProject(project)
    }
    
    /// Set active project
    public func setActiveProject(_ project: Project) {
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
    public func duplicateProject(_ project: Project) {
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
    public func openSSHConfig(for project: Project) {
        selectedProject = project
        
        if let config = project.sshConfig {
            sshHost = config.host
            sshPort = Int(config.port)
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
    public func saveSSHConfig() {
        guard let project = selectedProject, canSaveSSHConfig else { return }
        
        let config = AppSSHConfig(
            id: UUID().uuidString,
            name: "\(project.name) SSH",
            host: sshHost,
            port: UInt16(sshPort),
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
    public func testSSHConnection() async {
        guard canSaveSSHConfig else { return }
        
        isLoading = true
        
        let config = AppSSHConfig(
            id: UUID().uuidString,
            name: "Test SSH",
            host: sshHost,
            port: UInt16(sshPort),
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
    public func connectSSH(with config: AppSSHConfig) async {
        isLoading = true
        
        do {
            try await sshManager.connect(config: config)
            showSuccess(message: "Connected to SSH")
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    /// Disconnect SSH
    public func disconnectSSH() async {
        await sshManager.disconnect()
    }
    
    // MARK: - Public Methods - Environment Variables
    
    /// Open environment variables editor
    public func openEnvVarEditor(for project: Project) {
        selectedProject = project
        environmentVariables = project.environmentVariables ?? [:]
        showEnvVarEditor = true
    }
    
    /// Add environment variable
    public func addEnvironmentVariable() {
        guard !envVarKey.isEmpty, !envVarValue.isEmpty else { return }
        
        environmentVariables[envVarKey] = envVarValue
        
        // Clear form
        envVarKey = ""
        envVarValue = ""
    }
    
    /// Remove environment variable
    public func removeEnvironmentVariable(_ key: String) {
        environmentVariables.removeValue(forKey: key)
    }
    
    /// Save environment variables
    public func saveEnvironmentVariables() {
        guard let project = selectedProject else { return }
        
        projectStore.updateProject(project) { proj in
            proj.environmentVariables = environmentVariables.isEmpty ? nil : environmentVariables
        }
        
        showEnvVarEditor = false
    }
    
    // MARK: - Public Methods - Search
    
    /// Search projects
    public func searchProjects(_ text: String) {
        searchText = text
    }
    
    /// Clear search
    public func clearSearch() {
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