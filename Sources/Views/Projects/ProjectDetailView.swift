import SwiftUI

/// Detailed view for a single project with file browser integration
public struct ProjectDetailView: View {
    let projectId: String
    let projectName: String
    
    @State private var selectedTab = ProjectTab.files
    @State private var selectedFile: FileTreeNode?
    @State private var showingCodeEditor = false
    @State private var showingTerminal = false
    @State private var splitViewMode: SplitViewMode = .single
    
    @EnvironmentObject private var apiClient: APIClient
    @Environment(\.dismiss) private var dismiss
    
    enum ProjectTab: String, CaseIterable {
        case files = "Files"
        case terminal = "Terminal"
        case settings = "Settings"
        case git = "Git"
        
        var icon: String {
            switch self {
            case .files: return "folder"
            case .terminal: return "terminal"
            case .settings: return "gearshape"
            case .git: return "arrow.triangle.branch"
            }
        }
    }
    
    enum SplitViewMode {
        case single
        case vertical
        case horizontal
    }
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar with file browser
            VStack(spacing: 0) {
                // Project header
                ProjectHeader(
                    projectName: projectName,
                    onClose: { dismiss() }
                )
                
                Divider()
                
                // File browser
                FileTreeView(
                    projectId: projectId,
                    apiClient: apiClient
                )
            }
            .frame(minWidth: 250, idealWidth: 300)
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } detail: {
            // Main content area
            VStack(spacing: 0) {
                // Tab bar
                TabBarView(selectedTab: $selectedTab)
                
                Divider()
                
                // Content based on selected tab
                switch selectedTab {
                case .files:
                    FileContentView(
                        selectedFile: $selectedFile,
                        splitViewMode: $splitViewMode,
                        showingCodeEditor: $showingCodeEditor
                    )
                    
                case .terminal:
                    TerminalContainerView(projectId: projectId)
                    
                case .settings:
                    ProjectSettingsView(projectId: projectId)
                    
                case .git:
                    GitView(projectId: projectId)
                }
            }
        }
        .navigationTitle(projectName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarContent()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFileInEditor)) { notification in
            if let node = notification.userInfo?["node"] as? FileTreeNode {
                selectedFile = node
                showingCodeEditor = true
            }
        }
    }
}

// MARK: - Project Header

struct ProjectHeader: View {
    let projectName: String
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.accentColor)
            
            Text(projectName)
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }
}

// MARK: - Tab Bar

struct TabBarView: View {
    @Binding var selectedTab: ProjectDetailView.ProjectTab
    
    var body: some View {
        HStack(spacing: 20) {
            ForEach(ProjectDetailView.ProjectTab.allCases, id: \.self) { tab in
                TabButton(
                    title: tab.rawValue,
                    icon: tab.icon,
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - File Content View

struct FileContentView: View {
    @Binding var selectedFile: FileTreeNode?
    @Binding var splitViewMode: ProjectDetailView.SplitViewMode
    @Binding var showingCodeEditor: Bool
    
    var body: some View {
        if let file = selectedFile {
            switch splitViewMode {
            case .single:
                CodeEditorContainer(file: file)
                
            case .vertical:
                HSplitView {
                    CodeEditorContainer(file: file)
                    
                    if showingCodeEditor {
                        CodeEditorContainer(file: file)
                    } else {
                        FilePreviewContainer(file: file)
                    }
                }
                
            case .horizontal:
                VSplitView {
                    CodeEditorContainer(file: file)
                    
                    if showingCodeEditor {
                        CodeEditorContainer(file: file)
                    } else {
                        FilePreviewContainer(file: file)
                    }
                }
            }
        } else {
            EmptyFileView()
        }
    }
}

// MARK: - Code Editor Container

struct CodeEditorContainer: View {
    let file: FileTreeNode
    @StateObject private var editorViewModel = CodeEditorViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Editor header
            HStack {
                FileIconProvider.icon(for: file).iconView
                    .fileIconStyle(size: 14)
                
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                
                if editorViewModel.isModified {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }
                
                Spacer()
                
                Button(action: { editorViewModel.save() }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14))
                }
                .disabled(!editorViewModel.isModified)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.05))
            
            Divider()
            
            // Code editor
            CodeEditorView(viewModel: editorViewModel)
                .task {
                    await editorViewModel.loadFile(file)
                }
        }
    }
}

// MARK: - File Preview Container

struct FilePreviewContainer: View {
    let file: FileTreeNode
    
    var body: some View {
        VStack(spacing: 0) {
            // Preview header
            HStack {
                Image(systemName: "eye")
                    .font(.system(size: 14))
                
                Text("Preview")
                    .font(.system(size: 13, weight: .medium))
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.05))
            
            Divider()
            
            // File preview based on type
            FilePreviewView(node: file)
        }
    }
}

// MARK: - Empty File View

struct EmptyFileView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No file selected")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Select a file from the sidebar to view or edit")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Terminal Container

struct TerminalContainerView: View {
    let projectId: String
    
    var body: some View {
        TerminalView(projectId: projectId)
    }
}

// MARK: - Git View

struct GitView: View {
    let projectId: String
    
    @State private var gitStatus = ""
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Git status
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Git Status", systemImage: "arrow.triangle.branch")
                            .font(.headline)
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(LinearProgressViewStyle())
                        } else {
                            Text(gitStatus.isEmpty ? "No changes" : gitStatus)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Git actions
                HStack(spacing: 12) {
                    Button(action: performGitStatus) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    
                    Button(action: performGitCommit) {
                        Label("Commit", systemImage: "checkmark.circle")
                    }
                    
                    Button(action: performGitPush) {
                        Label("Push", systemImage: "arrow.up.circle")
                    }
                    
                    Button(action: performGitPull) {
                        Label("Pull", systemImage: "arrow.down.circle")
                    }
                }
            }
            .padding()
        }
        .task {
            await loadGitStatus()
        }
    }
    
    private func loadGitStatus() async {
        isLoading = true
        // TODO: Implement git status loading from backend
        gitStatus = "On branch main\nYour branch is up to date with 'origin/main'.\n\nnothing to commit, working tree clean"
        isLoading = false
    }
    
    private func performGitStatus() {
        Task {
            await loadGitStatus()
        }
    }
    
    private func performGitCommit() {
        // TODO: Show commit dialog
    }
    
    private func performGitPush() {
        // TODO: Implement git push
    }
    
    private func performGitPull() {
        // TODO: Implement git pull
    }
}

// MARK: - Toolbar Content

struct ToolbarContent: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: {}) {
                Image(systemName: "play.fill")
            }
            .help("Run Project")
            
            Button(action: {}) {
                Image(systemName: "stop.fill")
            }
            .help("Stop")
            
            Divider()
            
            Button(action: {}) {
                Image(systemName: "hammer")
            }
            .help("Build")
            
            Button(action: {}) {
                Image(systemName: "ladybug")
            }
            .help("Debug")
        }
    }
}

// MARK: - Code Editor View Model

@MainActor
final class CodeEditorViewModel: ObservableObject {
    @Published var content = ""
    @Published var isModified = false
    @Published var isLoading = false
    
    private var originalContent = ""
    private var currentFile: FileTreeNode?
    
    func loadFile(_ file: FileTreeNode) async {
        guard !file.isDirectory else { return }
        
        currentFile = file
        isLoading = true
        
        // TODO: Load file content from backend
        // For now, show placeholder
        content = "// File: \(file.name)\n// Path: \(file.path)\n\n// Content will be loaded from backend..."
        originalContent = content
        isModified = false
        
        isLoading = false
    }
    
    func save() {
        guard isModified, let file = currentFile else { return }
        
        Task {
            // TODO: Save file content to backend
            originalContent = content
            isModified = false
        }
    }
}