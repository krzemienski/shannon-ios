//
//  ProjectsView.swift
//  ClaudeCode
//
//  Project management view
//

import SwiftUI
import OSLog

struct ProjectsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ProjectsViewModel
    @State private var searchText = ""
    @State private var showingNewProject = false
    @State private var selectedProject: Project?
    
    init() {
        let container = DependencyContainer.shared
        _viewModel = StateObject(wrappedValue: ProjectsViewModel(
            apiClient: container.apiClient,
            appState: container.appState
        ))
    }
    
    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return viewModel.projects
        }
        return viewModel.projects.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            if viewModel.projects.isEmpty && !viewModel.isLoading {
                VStack(spacing: ThemeSpacing.lg) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.muted)
                    
                    Text("No Projects")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.foreground)
                    
                    Text("Create a project to organize your development work")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.mutedForeground)
                        .multilineTextAlignment(.center)
                    
                    Button("New Project") {
                        showingNewProject = true
                    }
                    .primaryButton()
                }
                .padding(ThemeSpacing.xl)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: ThemeSpacing.md
                    ) {
                        ForEach(filteredProjects) { project in
                            ProjectCard(project: project) {
                                selectedProject = project
                            }
                        }
                    }
                    .padding()
                }
                .searchable(text: $searchText, prompt: "Search projects")
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewProject = true
                } label: {
                    Image(systemName: "plus")
                }
                .tint(Theme.primary)
            }
        }
        .sheet(isPresented: $showingNewProject) {
            NewProjectView { newProject in
                Task {
                    try? await viewModel.createProject(newProject)
                }
            }
        }
        .refreshable {
            await viewModel.refreshProjects()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred")
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailView(project: project)
        }
    }
}

// MARK: - Project Card

struct ProjectCard: View {
    let project: Project
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                // Icon and status
                HStack {
                    Image(systemName: project.icon)
                        .font(.system(size: 24))
                        .foregroundColor(Theme.primary)
                    
                    Spacer()
                    
                    Circle()
                        .fill(project.isActive ? Theme.success : Theme.muted)
                        .frame(width: 8, height: 8)
                }
                
                // Project name
                Text(project.name)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.foreground)
                    .lineLimit(1)
                
                // Description
                Text(project.description)
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
                    .lineLimit(2)
                
                Spacer()
                
                // Stats
                HStack(spacing: ThemeSpacing.md) {
                    Label("\(project.sessionCount)", systemImage: "message")
                    Label("\(project.toolCount)", systemImage: "wrench")
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.muted)
                
                // Last updated
                Text(project.formattedLastUpdated)
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.muted)
            }
            .padding(ThemeSpacing.md)
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .background(Theme.card)
            .cornerRadius(Theme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Project Model

struct Project: Identifiable {
    let id: String  // Changed to match backend API
    let name: String
    let description: String
    let icon: String
    let isActive: Bool
    let sessionCount: Int
    let toolCount: Int
    let lastUpdated: Date
    let sshConfig: SSHConfig?
    
    // Constructor with default id for new projects
    init(id: String = UUID().uuidString,
         name: String,
         description: String,
         icon: String,
         isActive: Bool,
         sessionCount: Int,
         toolCount: Int,
         lastUpdated: Date,
         sshConfig: SSHConfig?) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.isActive = isActive
        self.sessionCount = sessionCount
        self.toolCount = toolCount
        self.lastUpdated = lastUpdated
        self.sshConfig = sshConfig
    }
    
    var formattedLastUpdated: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
    
    struct SSHConfig {
        let host: String
        let port: Int
        let username: String
        let authMethod: AuthMethod
        
        enum AuthMethod {
            case password
            case publicKey
        }
    }
    
    static let mockData: [Project] = [
        Project(
            name: "ClaudeCode iOS",
            description: "Native iOS client for Claude Code API",
            icon: "iphone",
            isActive: true,
            sessionCount: 12,
            toolCount: 8,
            lastUpdated: Date().addingTimeInterval(-3600),
            sshConfig: nil
        ),
        Project(
            name: "Web Dashboard",
            description: "React-based admin dashboard with TypeScript",
            icon: "globe",
            isActive: false,
            sessionCount: 24,
            toolCount: 15,
            lastUpdated: Date().addingTimeInterval(-86400),
            sshConfig: SSHConfig(
                host: "192.168.1.100",
                port: 22,
                username: "developer",
                authMethod: .publicKey
            )
        ),
        Project(
            name: "API Backend",
            description: "Node.js REST API with Express and MongoDB",
            icon: "server.rack",
            isActive: true,
            sessionCount: 8,
            toolCount: 12,
            lastUpdated: Date().addingTimeInterval(-7200),
            sshConfig: nil
        ),
        Project(
            name: "ML Pipeline",
            description: "Python data processing and ML training pipeline",
            icon: "brain",
            isActive: false,
            sessionCount: 5,
            toolCount: 6,
            lastUpdated: Date().addingTimeInterval(-172800),
            sshConfig: SSHConfig(
                host: "ml.example.com",
                port: 2222,
                username: "mlops",
                authMethod: .password
            )
        )
    ]
}

// MARK: - New Project View

struct NewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var selectedIcon = "folder.fill"
    @State private var enableSSH = false
    @State private var sshHost = ""
    @State private var sshPort = "22"
    @State private var sshUsername = ""
    @State private var sshAuthMethod = 0 // 0: password, 1: key
    
    let onSave: (Project) -> Void
    
    let icons = [
        "folder.fill", "iphone", "globe", "server.rack",
        "brain", "star.fill", "flag.fill", "tag.fill",
        "bookmark.fill", "heart.fill", "bolt.fill", "cloud.fill"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: ThemeSpacing.lg) {
                        // Basic Info
                        VStack(spacing: ThemeSpacing.md) {
                            CustomTextField(
                                title: "Project Name",
                                text: $name,
                                placeholder: "My Awesome Project",
                                icon: "folder"
                            )
                            
                            VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                                Text("Description")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.mutedForeground)
                                
                                TextEditor(text: $description)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.foreground)
                                    .scrollContentBackground(.hidden)
                                    .background(Theme.input)
                                    .cornerRadius(Theme.Radius.sm)
                                    .frame(minHeight: 80, maxHeight: 120)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                                    .overlay(alignment: .topLeading) {
                                        if description.isEmpty {
                                            Text("Brief description of your project...")
                                                .font(Theme.Typography.body)
                                                .foregroundColor(Theme.muted)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    }
                            }
                            
                            // Icon selector
                            VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                                Text("Icon")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.mutedForeground)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: ThemeSpacing.sm) {
                                    ForEach(icons, id: \.self) { icon in
                                        Button {
                                            selectedIcon = icon
                                        } label: {
                                            Image(systemName: icon)
                                                .font(.system(size: 24))
                                                .foregroundColor(selectedIcon == icon ? Theme.foreground : Theme.muted)
                                                .frame(width: 48, height: 48)
                                                .background(selectedIcon == icon ? Theme.primary : Theme.card)
                                                .cornerRadius(Theme.Radius.sm)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                                        .stroke(selectedIcon == icon ? Theme.primary : Theme.border, lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }
                        }
                        
                        Divider()
                            .background(Theme.border)
                        
                        // SSH Configuration
                        VStack(spacing: ThemeSpacing.md) {
                            Toggle(isOn: $enableSSH) {
                                Label("Enable SSH Monitoring", systemImage: "terminal")
                                    .font(Theme.Typography.headline)
                                    .foregroundColor(Theme.foreground)
                            }
                            .tint(Theme.primary)
                            
                            if enableSSH {
                                CustomTextField(
                                    title: "Host",
                                    text: $sshHost,
                                    placeholder: "192.168.1.100 or example.com",
                                    icon: "network"
                                )
                                
                                CustomTextField(
                                    title: "Port",
                                    text: $sshPort,
                                    placeholder: "22",
                                    icon: "number",
                                    keyboardType: .numberPad
                                )
                                
                                CustomTextField(
                                    title: "Username",
                                    text: $sshUsername,
                                    placeholder: "developer",
                                    icon: "person"
                                )
                                
                                // Auth method picker
                                VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                                    Text("Authentication")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.mutedForeground)
                                    
                                    Picker("Authentication", selection: $sshAuthMethod) {
                                        Text("Password").tag(0)
                                        Text("SSH Key").tag(1)
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(Theme.foreground)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let sshConfig = enableSSH ? Project.SSHConfig(
                            host: sshHost,
                            port: Int(sshPort) ?? 22,
                            username: sshUsername,
                            authMethod: sshAuthMethod == 0 ? .password : .publicKey
                        ) : nil
                        
                        let newProject = Project(
                            name: name.isEmpty ? "Untitled Project" : name,
                            description: description,
                            icon: selectedIcon,
                            isActive: true,
                            sessionCount: 0,
                            toolCount: 0,
                            lastUpdated: Date(),
                            sshConfig: sshConfig
                        )
                        onSave(newProject)
                        dismiss()
                    }
                    .tint(Theme.primary)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Project Detail View

struct ProjectDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: ThemeSpacing.lg) {
                        // Project header
                        HStack(spacing: ThemeSpacing.md) {
                            Image(systemName: project.icon)
                                .font(.system(size: 48))
                                .foregroundColor(Theme.primary)
                                .frame(width: 80, height: 80)
                                .background(Theme.primary.opacity(0.1))
                                .cornerRadius(Theme.Radius.md)
                            
                            VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                                Text(project.name)
                                    .font(Theme.Typography.title2)
                                    .foregroundColor(Theme.foreground)
                                
                                Text(project.description)
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.mutedForeground)
                                
                                HStack {
                                    Circle()
                                        .fill(project.isActive ? Theme.success : Theme.muted)
                                        .frame(width: 8, height: 8)
                                    Text(project.isActive ? "Active" : "Inactive")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(project.isActive ? Theme.success : Theme.muted)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Theme.card)
                        .cornerRadius(Theme.Radius.md)
                        
                        // Statistics
                        HStack(spacing: ThemeSpacing.md) {
                            StatCard(
                                title: "Sessions",
                                value: "\(project.sessionCount)",
                                icon: "message.fill",
                                color: Theme.primary
                            )
                            
                            StatCard(
                                title: "Tools",
                                value: "\(project.toolCount)",
                                icon: "wrench.fill",
                                color: Theme.accent
                            )
                        }
                        
                        // SSH Configuration
                        if let sshConfig = project.sshConfig {
                            VStack(alignment: .leading, spacing: ThemeSpacing.md) {
                                Text("SSH Configuration")
                                    .font(Theme.Typography.headline)
                                    .foregroundColor(Theme.foreground)
                                
                                VStack(spacing: ThemeSpacing.sm) {
                                    InfoRow(label: "Host", value: sshConfig.host)
                                    InfoRow(label: "Port", value: "\(sshConfig.port)")
                                    InfoRow(label: "Username", value: sshConfig.username)
                                    InfoRow(
                                        label: "Auth Method",
                                        value: sshConfig.authMethod == .password ? "Password" : "SSH Key"
                                    )
                                }
                                .padding()
                                .background(Theme.card)
                                .cornerRadius(Theme.Radius.md)
                            }
                        }
                        
                        // Actions
                        VStack(spacing: ThemeSpacing.sm) {
                            Button {
                                // Open in chat
                            } label: {
                                HStack {
                                    Image(systemName: "message.fill")
                                    Text("Open in Chat")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .primaryButton()
                            
                            if project.sshConfig != nil {
                                Button {
                                    // Connect SSH
                                } label: {
                                    HStack {
                                        Image(systemName: "terminal")
                                        Text("Connect SSH")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .secondaryButton()
                            }
                            
                            Button {
                                // Delete project
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Project")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .font(Theme.Typography.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, ThemeSpacing.xl)
                            .padding(.vertical, ThemeSpacing.md)
                            .background(Theme.destructive)
                            .cornerRadius(Theme.Radius.md)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Project Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .tint(Theme.primary)
                }
            }
        }
    }
}

// MARK: - Helper Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.foreground)
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            Spacer()
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(Theme.Radius.md)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.mutedForeground)
            Spacer()
            Text(value)
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.foreground)
        }
    }
}

#Preview {
    NavigationStack {
        ProjectsView()
            .environmentObject(AppState())
    }
    .preferredColorScheme(.dark)
}