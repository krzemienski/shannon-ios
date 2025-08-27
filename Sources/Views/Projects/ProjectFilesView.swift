//
//  ProjectFilesView.swift
//  ClaudeCode
//
//  Project files view with upload, download, and management capabilities
//

import SwiftUI
import UniformTypeIdentifiers
import OSLog

/// Project files view with comprehensive file management
struct ProjectFilesView: View {
    let projectId: String
    let projectName: String
    
    @StateObject private var fileService = FileTransferService.shared
    @StateObject private var viewModel: ProjectFilesViewModel
    @State private var showingFilePicker = false
    @State private var showingFilePreview = false
    @State private var selectedFile: ProjectFile?
    @State private var showingTransferQueue = false
    @State private var searchText = ""
    @State private var selectedCategory: FileCategory = .all
    @State private var sortOrder: SortOrder = .name
    @State private var showingActionSheet = false
    @State private var selectedFiles: Set<String> = []
    @State private var isSelectionMode = false
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "ProjectFiles")
    
    init(projectId: String, projectName: String) {
        self.projectId = projectId
        self.projectName = projectName
        self._viewModel = StateObject(wrappedValue: ProjectFilesViewModel(projectId: projectId))
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search and filters
                searchAndFilterBar
                
                // Category tabs
                categoryTabs
                
                // Files list or grid
                filesContent
                
                // Transfer status bar
                if fileService.activeUploads.count > 0 || fileService.activeDownloads.count > 0 {
                    transferStatusBar
                }
            }
            
            // Floating action button for uploads
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    uploadButton
                }
            }
            .padding()
        }
        .navigationTitle(projectName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingFilePicker) {
            FilePickerView(projectId: projectId) { urls in
                try await uploadFiles(urls)
            }
        }
        .sheet(isPresented: $showingFilePreview) {
            if let file = selectedFile {
                FilePreviewView(
                    fileURL: file.localURL ?? URL(string: file.remoteURL)!,
                    fileName: file.name
                )
            }
        }
        .sheet(isPresented: $showingTransferQueue) {
            TransferQueueView()
        }
        .actionSheet(isPresented: $showingActionSheet) {
            actionSheet
        }
        .task {
            await viewModel.loadFiles()
        }
    }
    
    // MARK: - Search and Filter Bar
    
    private var searchAndFilterBar: some View {
        HStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.mutedForeground)
                
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(Theme.foreground)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.mutedForeground)
                    }
                }
            }
            .padding(8)
            .background(Theme.card)
            .cornerRadius(Theme.smallRadius)
            
            // Sort button
            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        Label(order.rawValue, systemImage: sortOrder == order ? "checkmark" : "")
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(Theme.accent)
                    .padding(8)
                    .background(Theme.card)
                    .cornerRadius(Theme.smallRadius)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Category Tabs
    
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.smallSpacing) {
                ForEach(FileCategory.allCases, id: \.self) { category in
                    CategoryTab(
                        category: category,
                        isSelected: selectedCategory == category,
                        count: viewModel.fileCount(for: category)
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Files Content
    
    private var filesContent: some View {
        Group {
            if viewModel.isLoading {
                LoadingView(message: "Loading files...")
            } else if filteredFiles.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: "No Files",
                    message: searchText.isEmpty ? 
                        "Upload files to get started" : 
                        "No files match your search"
                )
            } else {
                filesList
            }
        }
    }
    
    private var filesList: some View {
        List {
            ForEach(filteredFiles) { file in
                FileRow(
                    file: file,
                    isSelected: selectedFiles.contains(file.id),
                    isSelectionMode: isSelectionMode,
                    onTap: {
                        if isSelectionMode {
                            toggleSelection(for: file)
                        } else {
                            handleFileTap(file)
                        }
                    },
                    onDownload: {
                        Task {
                            await downloadFile(file)
                        }
                    }
                )
                .listRowBackground(Theme.card)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    fileSwipeActions(for: file)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var filteredFiles: [ProjectFile] {
        viewModel.files
            .filter { file in
                (selectedCategory == .all || file.category == selectedCategory) &&
                (searchText.isEmpty || file.name.localizedCaseInsensitiveContains(searchText))
            }
            .sorted(by: sortOrder.comparator)
    }
    
    // MARK: - Upload Button
    
    private var uploadButton: some View {
        Button {
            showingFilePicker = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Theme.accent)
                .cornerRadius(28)
            .shadow(color: Theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Transfer Status Bar
    
    private var transferStatusBar: some View {
        Button {
            showingTransferQueue = true
        } label: {
            HStack {
                // Upload indicator
                if fileService.activeUploads.count > 0 {
                    Label("\(fileService.activeUploads.count)", systemImage: "arrow.up.circle.fill")
                        .foregroundColor(Theme.success)
                }
                
                // Download indicator
                if fileService.activeDownloads.count > 0 {
                    Label("\(fileService.activeDownloads.count)", systemImage: "arrow.down.circle.fill")
                        .foregroundColor(Theme.info)
                }
                
                Spacer()
                
                // Speed indicators
                if fileService.currentUploadSpeed > 0 {
                    Text(formatSpeed(fileService.currentUploadSpeed))
                        .font(.caption)
                        .foregroundColor(Theme.mutedForeground)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.mutedForeground)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Theme.card)
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                if isSelectionMode {
                    Button("Done") {
                        isSelectionMode = false
                        selectedFiles.removeAll()
                    }
                } else {
                    Menu {
                        Button {
                            isSelectionMode = true
                        } label: {
                            Label("Select Files", systemImage: "checkmark.circle")
                        }
                        
                        Button {
                            showingTransferQueue = true
                        } label: {
                            Label("Transfer Queue", systemImage: "arrow.up.arrow.down.circle")
                        }
                        
                        Button {
                            Task {
                                await viewModel.refreshFiles()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        
        if isSelectionMode && !selectedFiles.isEmpty {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Button {
                        downloadSelectedFiles()
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                    
                    Spacer()
                    
                    Text("\(selectedFiles.count) selected")
                        .font(.caption)
                        .foregroundColor(Theme.mutedForeground)
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        deleteSelectedFiles()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    // MARK: - Swipe Actions
    
    private func fileSwipeActions(for file: ProjectFile) -> some View {
        Group {
            Button {
                Task {
                    await deleteFile(file)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(Theme.destructive)
            
            Button {
                Task {
                    await downloadFile(file)
                }
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .tint(Theme.info)
            
            Button {
                shareFile(file)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(Theme.accent)
        }
    }
    
    // MARK: - Action Sheet
    
    private var actionSheet: ActionSheet {
        ActionSheet(
            title: Text("File Actions"),
            message: selectedFile != nil ? Text(selectedFile!.name) : nil,
            buttons: [
                .default(Text("Preview")) {
                    if let file = selectedFile {
                        showPreview(for: file)
                    }
                },
                .default(Text("Download")) {
                    if let file = selectedFile {
                        Task {
                            await downloadFile(file)
                        }
                    }
                },
                .default(Text("Share")) {
                    if let file = selectedFile {
                        shareFile(file)
                    }
                },
                .destructive(Text("Delete")) {
                    if let file = selectedFile {
                        Task {
                            await deleteFile(file)
                        }
                    }
                },
                .cancel()
            ]
        )
    }
    
    // MARK: - File Actions
    
    private func handleFileTap(_ file: ProjectFile) {
        selectedFile = file
        
        if file.isDownloaded {
            showPreview(for: file)
        } else {
            showingActionSheet = true
        }
    }
    
    private func showPreview(for file: ProjectFile) {
        selectedFile = file
        showingFilePreview = true
    }
    
    private func uploadFiles(_ urls: [URL]) async throws {
        for url in urls {
            _ = try await fileService.uploadFile(
                url: url,
                to: projectId,
                path: viewModel.currentPath
            )
        }
        
        await viewModel.refreshFiles()
    }
    
    private func downloadFile(_ file: ProjectFile) async {
        do {
            _ = try await fileService.downloadFile(
                fileName: file.name,
                from: projectId,
                remotePath: file.path
            )
            await viewModel.markAsDownloaded(file)
        } catch {
            logger.error("Failed to download file: \(error)")
        }
    }
    
    private func downloadSelectedFiles() {
        Task {
            for fileId in selectedFiles {
                if let file = viewModel.files.first(where: { $0.id == fileId }) {
                    await downloadFile(file)
                }
            }
            isSelectionMode = false
            selectedFiles.removeAll()
        }
    }
    
    private func deleteFile(_ file: ProjectFile) async {
        do {
            await viewModel.deleteFile(file)
        } catch {
            logger.error("Failed to delete file: \(error)")
        }
    }
    
    private func deleteSelectedFiles() {
        Task {
            for fileId in selectedFiles {
                if let file = viewModel.files.first(where: { $0.id == fileId }) {
                    await deleteFile(file)
                }
            }
            isSelectionMode = false
            selectedFiles.removeAll()
        }
    }
    
    private func shareFile(_ file: ProjectFile) {
        guard let url = file.localURL ?? URL(string: file.remoteURL) else { return }
        
        let activityController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityController, animated: true)
        }
    }
    
    private func toggleSelection(for file: ProjectFile) {
        if selectedFiles.contains(file.id) {
            selectedFiles.remove(file.id)
        } else {
            selectedFiles.insert(file.id)
        }
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return "\(formatter.string(fromByteCount: Int64(speed)))/s"
    }
}

// MARK: - View Models and Supporting Types

@MainActor
class ProjectFilesViewModel: ObservableObject {
    @Published var files: [ProjectFile] = []
    @Published var isLoading = false
    @Published var currentPath = "/"
    
    private let projectId: String
    private let apiClient = APIClient()
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "ProjectFilesVM")
    
    init(projectId: String) {
        self.projectId = projectId
    }
    
    func loadFiles() async {
        isLoading = true
        
        // TODO: Implement actual API call to load project files
        // For now, using mock data
        await MainActor.run {
            self.files = ProjectFile.mockFiles
            self.isLoading = false
        }
    }
    
    func refreshFiles() async {
        await loadFiles()
    }
    
    func fileCount(for category: FileCategory) -> Int {
        if category == .all {
            return files.count
        }
        return files.filter { $0.category == category }.count
    }
    
    func markAsDownloaded(_ file: ProjectFile) async {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index].isDownloaded = true
        }
    }
    
    func deleteFile(_ file: ProjectFile) async {
        // TODO: Implement actual API call to delete file
        files.removeAll { $0.id == file.id }
    }
}

struct ProjectFile: Identifiable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let modifiedDate: Date
    let category: FileCategory
    let remoteURL: String
    var localURL: URL?
    var isDownloaded: Bool
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: modifiedDate, relativeTo: Date())
    }
    
    // Mock data for testing
    static let mockFiles: [ProjectFile] = [
        ProjectFile(
            id: "1",
            name: "AppDelegate.swift",
            path: "/Sources",
            size: 4096,
            modifiedDate: Date().addingTimeInterval(-3600),
            category: .code,
            remoteURL: "http://localhost:8000/files/1",
            localURL: nil,
            isDownloaded: false
        ),
        ProjectFile(
            id: "2",
            name: "README.md",
            path: "/",
            size: 2048,
            modifiedDate: Date().addingTimeInterval(-7200),
            category: .document,
            remoteURL: "http://localhost:8000/files/2",
            localURL: nil,
            isDownloaded: true
        ),
        ProjectFile(
            id: "3",
            name: "app_icon.png",
            path: "/Assets",
            size: 8192,
            modifiedDate: Date().addingTimeInterval(-86400),
            category: .image,
            remoteURL: "http://localhost:8000/files/3",
            localURL: nil,
            isDownloaded: false
        )
    ]
}

enum FileCategory: String, CaseIterable {
    case all = "All"
    case code = "Code"
    case document = "Documents"
    case image = "Images"
    case video = "Videos"
    case archive = "Archives"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .all: return "folder"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .document: return "doc.text"
        case .image: return "photo"
        case .video: return "video"
        case .archive: return "archivebox"
        case .other: return "doc"
        }
    }
}

enum SortOrder: String, CaseIterable {
    case name = "Name"
    case date = "Date"
    case size = "Size"
    case type = "Type"
    
    var comparator: (ProjectFile, ProjectFile) -> Bool {
        switch self {
        case .name:
            return { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .date:
            return { $0.modifiedDate > $1.modifiedDate }
        case .size:
            return { $0.size > $1.size }
        case .type:
            return { $0.category.rawValue < $1.category.rawValue }
        }
    }
}

// MARK: - Component Views

struct CategoryTab: View {
    let category: FileCategory
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: category.icon)
                Text(category.rawValue)
                if count > 0 {
                    Text("(\(count))")
                        .font(.caption)
                }
            }
            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? Theme.accent : Theme.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.accent.opacity(0.1) : Theme.card)
            .cornerRadius(Theme.smallRadius)
        }
    }
}

struct FileRow: View {
    let file: ProjectFile
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onDownload: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? Theme.accent : Theme.mutedForeground)
                }
                
                Image(systemName: file.category.icon)
                    .font(.title2)
                    .foregroundColor(Theme.accent)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.foreground)
                        .lineLimit(1)
                    
                    HStack {
                        Text(file.formattedSize)
                        Text("•")
                        Text(file.formattedDate)
                    }
                    .font(.caption)
                    .foregroundColor(Theme.mutedForeground)
                }
                
                Spacer()
                
                if file.isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.success)
                } else {
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(Theme.info)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TransferQueueView: View {
    @StateObject private var fileService = FileTransferService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if !fileService.activeUploads.isEmpty {
                    Section("Uploads") {
                        ForEach(fileService.activeUploads) { transfer in
                            TransferRow(transfer: transfer)
                        }
                    }
                }
                
                if !fileService.activeDownloads.isEmpty {
                    Section("Downloads") {
                        ForEach(fileService.activeDownloads) { transfer in
                            TransferRow(transfer: transfer)
                        }
                    }
                }
                
                if !fileService.completedTransfers.isEmpty {
                    Section("Completed") {
                        ForEach(fileService.completedTransfers) { transfer in
                            TransferRow(transfer: transfer)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Transfer Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TransferRow: View {
    @ObservedObject var transfer: FileTransfer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: transfer.direction == .upload ? "arrow.up.circle" : "arrow.down.circle")
                    .foregroundColor(transfer.direction == .upload ? Theme.success : Theme.info)
                
                Text(transfer.fileName)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                Spacer()
                
                statusView
            }
            
            if transfer.status == .inProgress {
                ProgressView(value: transfer.progress)
                    .tint(Theme.accent)
                
                HStack {
                    Text(transfer.formattedProgress)
                    Spacer()
                    Text(transfer.formattedSpeed)
                    Text("•")
                    Text(transfer.formattedRemainingTime)
                }
                .font(.caption)
                .foregroundColor(Theme.mutedForeground)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch transfer.status {
        case .pending:
            Text("Pending")
                .font(.caption)
                .foregroundColor(Theme.mutedForeground)
        case .inProgress:
            EmptyView()
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundColor(Theme.warning)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.success)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(Theme.destructive)
        case .cancelled:
            Image(systemName: "xmark.circle")
                .foregroundColor(Theme.mutedForeground)
        }
    }
}