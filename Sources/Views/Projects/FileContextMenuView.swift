import SwiftUI

/// Context menu view for file operations
struct FileContextMenuView: View {
    let node: FileTreeNode
    let viewModel: FileTreeViewModel
    
    @State private var showingRenameDialog = false
    @State private var showingDeleteConfirmation = false
    @State private var newName = ""
    
    var body: some View {
        Group {
            // Open in editor
            if !node.isDirectory {
                Button(action: openInEditor) {
                    Label("Open in Editor", systemImage: "doc.text")
                }
            }
            
            // New file/folder
            if node.isDirectory {
                Menu {
                    Button(action: { createNew(isDirectory: false) }) {
                        Label("New File", systemImage: "doc.badge.plus")
                    }
                    
                    Button(action: { createNew(isDirectory: true) }) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Label("New", systemImage: "plus")
                }
            }
            
            Divider()
            
            // Cut, Copy, Paste
            Button(action: cut) {
                Label("Cut", systemImage: "scissors")
            }
            .keyboardShortcut("x", modifiers: .command)
            
            Button(action: copy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)
            
            if node.isDirectory {
                Button(action: paste) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: .command)
                .disabled(ClipboardManager.shared.isEmpty)
            }
            
            Divider()
            
            // Rename
            Button(action: { showingRenameDialog = true }) {
                Label("Rename", systemImage: "pencil")
            }
            
            // Delete
            Button(action: { showingDeleteConfirmation = true }) {
                Label("Delete", systemImage: "trash")
                    .foregroundColor(.red)
            }
            
            Divider()
            
            // Reveal in Finder (macOS specific)
            #if os(macOS)
            Button(action: revealInFinder) {
                Label("Reveal in Finder", systemImage: "folder")
            }
            #endif
            
            // Copy path
            Button(action: copyPath) {
                Label("Copy Path", systemImage: "doc.on.doc.fill")
            }
            
            // File info
            if !node.isDirectory {
                Divider()
                
                Menu {
                    Text("Size: \(FileIconProvider.formatFileSize(node.size))")
                    if let modified = node.modifiedDate {
                        Text("Modified: \(FileIconProvider.formatDate(modified))")
                    }
                    if let created = node.createdDate {
                        Text("Created: \(FileIconProvider.formatDate(created))")
                    }
                    if let mimeType = node.mimeType {
                        Text("Type: \(mimeType)")
                    }
                } label: {
                    Label("Info", systemImage: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showingRenameDialog) {
            RenameDialog(
                originalName: node.name,
                newName: $newName,
                onRename: performRename
            )
        }
        .alert("Delete \(node.name)?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.delete([node])
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    // MARK: - Actions
    
    private func openInEditor() {
        // Open file in code editor
        NotificationCenter.default.post(
            name: .openFileInEditor,
            object: nil,
            userInfo: ["node": node]
        )
    }
    
    private func createNew(isDirectory: Bool) {
        viewModel.operationTarget = node
        viewModel.showingCreateDialog = true
        
        NotificationCenter.default.post(
            name: .showCreateDialog,
            object: nil,
            userInfo: ["parent": node, "isDirectory": isDirectory]
        )
    }
    
    private func cut() {
        ClipboardManager.shared.cut(nodes: [node])
        viewModel.clearSelection()
    }
    
    private func copy() {
        ClipboardManager.shared.copy(nodes: [node])
    }
    
    private func paste() {
        guard !ClipboardManager.shared.isEmpty else { return }
        
        Task {
            if ClipboardManager.shared.isCut {
                await viewModel.move(ClipboardManager.shared.nodes, to: node)
            } else {
                await viewModel.copy(ClipboardManager.shared.nodes, to: node)
            }
            ClipboardManager.shared.clear()
        }
    }
    
    private func performRename() {
        guard !newName.isEmpty, newName != node.name else { return }
        
        Task {
            await viewModel.rename(node, to: newName)
        }
    }
    
    private func copyPath() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(node.path, forType: .string)
        #else
        UIPasteboard.general.string = node.path
        #endif
    }
    
    #if os(macOS)
    private func revealInFinder() {
        NSWorkspace.shared.selectFile(node.path, inFileViewerRootedAtPath: "")
    }
    #endif
}

// MARK: - Rename Dialog

struct RenameDialog: View {
    let originalName: String
    @Binding var newName: String
    let onRename: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rename")
                .font(.headline)
            
            TextField("New name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    performRename()
                }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Rename") {
                    performRename()
                }
                .keyboardShortcut(.return)
                .disabled(newName.isEmpty || newName == originalName)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            newName = originalName
            isFocused = true
        }
    }
    
    private func performRename() {
        guard !newName.isEmpty, newName != originalName else { return }
        onRename()
        dismiss()
    }
}

// MARK: - Clipboard Manager

@MainActor
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published private(set) var nodes: [FileTreeNode] = []
    @Published private(set) var isCut = false
    
    var isEmpty: Bool { nodes.isEmpty }
    
    private init() {}
    
    func cut(nodes: [FileTreeNode]) {
        self.nodes = nodes
        self.isCut = true
    }
    
    func copy(nodes: [FileTreeNode]) {
        self.nodes = nodes
        self.isCut = false
    }
    
    func clear() {
        nodes = []
        isCut = false
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openFileInEditor = Notification.Name("openFileInEditor")
    static let showCreateDialog = Notification.Name("showCreateDialog")
}