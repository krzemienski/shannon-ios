import SwiftUI

/// Main file browser view with tree structure
public struct FileTreeView: View {
    @StateObject private var viewModel: FileTreeViewModel
    @State private var searchText = ""
    @State private var showingCreateDialog = false
    @State private var createIsDirectory = false
    @State private var createParent: FileTreeNode?
    @State private var newItemName = ""
    
    public init(projectId: String, apiClient: APIClient) {
        _viewModel = StateObject(wrappedValue: FileTreeViewModel(
            projectId: projectId,
            apiClient: apiClient
        ))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            FileTreeToolbar(
                viewModel: viewModel,
                searchText: $searchText,
                onCreateFile: { showCreateDialog(isDirectory: false) },
                onCreateFolder: { showCreateDialog(isDirectory: true) }
            )
            
            Divider()
            
            // Breadcrumbs
            if !viewModel.breadcrumbs.isEmpty {
                BreadcrumbView(items: viewModel.breadcrumbs) { item in
                    Task {
                        await viewModel.navigateToBreadcrumb(item)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
            }
            
            // File tree or search results
            if !searchText.isEmpty && !viewModel.searchResults.isEmpty {
                // Search results
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.searchResults) { node in
                            FileNodeRow(
                                node: node,
                                viewModel: viewModel,
                                level: 0,
                                isSearchResult: true
                            )
                        }
                    }
                }
            } else if let rootNode = viewModel.rootNode {
                // File tree
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let children = rootNode.children {
                            ForEach(children) { child in
                                FileNodeView(
                                    node: child,
                                    viewModel: viewModel,
                                    level: 0
                                )
                            }
                        } else {
                            FileTreeEmptyStateView()
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else if viewModel.isLoading {
                // Loading state
                ProgressView("Loading files...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Empty state
                FileTreeEmptyStateView()
            }
        }
        .task {
            await viewModel.loadRootDirectory()
        }
        .onChange(of: searchText) { newValue in
            Task {
                if newValue.isEmpty {
                    viewModel.clearSearch()
                } else {
                    await viewModel.search(query: newValue)
                }
            }
        }
        .sheet(isPresented: $showingCreateDialog) {
            CreateItemDialog(
                isDirectory: createIsDirectory,
                parentPath: createParent?.path ?? viewModel.currentPath,
                itemName: $newItemName,
                onCreate: performCreate
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCreateDialog)) { notification in
            if let parent = notification.userInfo?["parent"] as? FileTreeNode,
               let isDirectory = notification.userInfo?["isDirectory"] as? Bool {
                createParent = parent
                createIsDirectory = isDirectory
                showingCreateDialog = true
            }
        }
    }
    
    private func showCreateDialog(isDirectory: Bool) {
        createIsDirectory = isDirectory
        createParent = nil
        newItemName = ""
        showingCreateDialog = true
    }
    
    private func performCreate() {
        guard !newItemName.isEmpty else { return }
        
        Task {
            await viewModel.createItem(
                in: createParent,
                name: newItemName,
                isDirectory: createIsDirectory
            )
            showingCreateDialog = false
            newItemName = ""
        }
    }
}

// MARK: - File Node View

struct FileNodeView: View {
    let node: FileTreeNode
    @ObservedObject var viewModel: FileTreeViewModel
    let level: Int
    
    @State private var isHovered = false
    @State private var isDragTarget = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FileNodeRow(
                node: node,
                viewModel: viewModel,
                level: level,
                isSearchResult: false
            )
            .background(rowBackground)
            .onHover { hovering in
                isHovered = hovering
            }
            .onDrop(of: [.fileURL], isTargeted: $isDragTarget) { providers in
                handleDrop(providers: providers)
            }
            .contextMenu {
                FileContextMenuView(node: node, viewModel: viewModel)
            }
            
            // Children (if expanded)
            if node.isDirectory && viewModel.expandedNodes.contains(node.id),
               let children = node.children {
                ForEach(children) { child in
                    FileNodeView(
                        node: child,
                        viewModel: viewModel,
                        level: level + 1
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var rowBackground: some View {
        if viewModel.selectedNodes.contains(node.id) {
            Color.accentColor.opacity(0.3)
        } else if isDragTarget && node.isDirectory {
            Color.accentColor.opacity(0.2)
        } else if isHovered {
            Color.primary.opacity(0.05)
        } else {
            Color.clear
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard node.isDirectory else { return false }
        
        Task {
            await viewModel.performDrop(on: node)
        }
        return true
    }
}

// MARK: - File Node Row

struct FileNodeRow: View {
    let node: FileTreeNode
    @ObservedObject var viewModel: FileTreeViewModel
    let level: Int
    let isSearchResult: Bool
    
    private var indentationWidth: CGFloat {
        CGFloat(level) * 20
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Indentation
            if !isSearchResult {
                Color.clear
                    .frame(width: indentationWidth)
            }
            
            // Expansion chevron (for directories)
            if node.isDirectory && !isSearchResult {
                Button(action: toggleExpansion) {
                    Image(systemName: viewModel.expandedNodes.contains(node.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(PlainButtonStyle())
            } else if !isSearchResult {
                Color.clear
                    .frame(width: 16, height: 16)
            }
            
            // File icon
            FileIconProvider.icon(for: node).iconView
                .fileIconStyle(size: 14)
            
            // File name
            Text(node.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
            
            // Git status indicator
            if let gitStatus = node.gitStatus {
                Image(systemName: gitStatus.statusIcon)
                    .font(.system(size: 10))
                    .foregroundColor(gitStatus.statusColor)
            }
            
            Spacer()
            
            // File size (for files)
            if !node.isDirectory, let size = node.size {
                Text(FileIconProvider.formatFileSize(size))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Search result path
            if isSearchResult {
                Text(node.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 200)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .onDrag {
            viewModel.startDragging([node])
            return NSItemProvider(object: node.path as NSString)
        }
    }
    
    private func toggleExpansion() {
        viewModel.toggleExpansion(for: node)
    }
    
    private func handleTap() {
        if node.isDirectory && !isSearchResult {
            toggleExpansion()
        } else {
            viewModel.select(node)
            if !node.isDirectory {
                // Open file in editor
                NotificationCenter.default.post(
                    name: .openFileInEditor,
                    object: nil,
                    userInfo: ["node": node]
                )
            }
        }
    }
}

// MARK: - Toolbar

struct FileTreeToolbar: View {
    @ObservedObject var viewModel: FileTreeViewModel
    @Binding var searchText: String
    let onCreateFile: () -> Void
    let onCreateFolder: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
            
            Spacer()
            
            // Action buttons
            Button(action: onCreateFile) {
                Image(systemName: "doc.badge.plus")
                    .help("New File")
            }
            
            Button(action: onCreateFolder) {
                Image(systemName: "folder.badge.plus")
                    .help("New Folder")
            }
            
            Divider()
                .frame(height: 16)
            
            Button(action: { viewModel.collapseAll() }) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .help("Collapse All")
            }
            
            Button(action: { viewModel.expandAll() }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .help("Expand All")
            }
            
            Button(action: { Task { await viewModel.refresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .help("Refresh")
            }
        }
        .padding(8)
    }
}

// MARK: - Breadcrumb View

struct BreadcrumbView: View {
    let items: [BreadcrumbItem]
    let onTap: (BreadcrumbItem) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button(action: { onTap(item) }) {
                    Text(item.name)
                        .font(.system(size: 12))
                        .foregroundColor(index == items.count - 1 ? .primary : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                if index < items.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Create Item Dialog

struct CreateItemDialog: View {
    let isDirectory: Bool
    let parentPath: String
    @Binding var itemName: String
    let onCreate: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isDirectory ? "New Folder" : "New File")
                .font(.headline)
            
            TextField(isDirectory ? "Folder name" : "File name", text: $itemName)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    performCreate()
                }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Create") {
                    performCreate()
                }
                .keyboardShortcut(.return)
                .disabled(itemName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            isFocused = true
        }
    }
    
    private func performCreate() {
        guard !itemName.isEmpty else { return }
        onCreate()
        dismiss()
    }
}

// MARK: - Empty State

struct FileTreeEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No files found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Create a new file or folder to get started")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - View Extensions

extension View {
    func help(_ text: String) -> some View {
        self.overlay(
            TooltipView(text: text)
                .allowsHitTesting(false)
                .opacity(0) // Tooltip handled by system on macOS
        )
    }
}

struct FileTreeTooltipView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(4)
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(4)
    }
}