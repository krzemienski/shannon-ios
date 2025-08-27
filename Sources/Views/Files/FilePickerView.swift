//
//  FilePickerView.swift
//  ClaudeCode
//
//  SwiftUI file picker interface with multi-selection and document scanning
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import VisionKit

/// File picker view with support for multiple file types and sources
struct FilePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FilePickerViewModel
    
    let projectId: String
    let onSelection: ([URL]) async throws -> Void
    
    @State private var showingDocumentPicker = false
    @State private var showingPhotoPicker = false
    @State private var showingScanner = false
    @State private var showingCamera = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedFiles: [URL] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    init(projectId: String, onSelection: @escaping ([URL]) async throws -> Void) {
        self.projectId = projectId
        self.onSelection = onSelection
        self._viewModel = StateObject(wrappedValue: FilePickerViewModel())
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.largeSpacing) {
                    // File source options
                    fileSourceSection
                    
                    // Recent files
                    if !viewModel.recentFiles.isEmpty {
                        recentFilesSection
                    }
                    
                    // Selected files preview
                    if !selectedFiles.isEmpty {
                        selectedFilesSection
                    }
                    
                    // Upload button
                    if !selectedFiles.isEmpty {
                        uploadButton
                    }
                }
                .padding()
            }
            .navigationTitle("Add Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView(
                    allowedTypes: viewModel.allowedDocumentTypes,
                    allowsMultipleSelection: true
                ) { urls in
                    handleFileSelection(urls)
                }
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .any(of: [.images, .videos])
                ) {
                    Text("Select Photos")
                }
                .onChange(of: selectedItems) { _ in
                    Task {
                        await processPhotoSelection()
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                if VNDocumentCameraViewController.isSupported {
                    DocumentScannerView { scannedImages in
                        handleScannedDocuments(scannedImages)
                    }
                } else {
                    Text("Document scanning not available on this device")
                        .padding()
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPickerView { image in
                    handleCapturedImage(image)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay {
                if isProcessing {
                    LoadingView(message: "Processing files...")
                }
            }
        }
    }
    
    // MARK: - File Source Section
    
    private var fileSourceSection: some View {
        VStack(alignment: .leading, spacing: Theme.mediumSpacing) {
            Text("Choose Files From")
                .font(Theme.titleFont)
                .foregroundColor(Theme.foreground)
            
            VStack(spacing: Theme.smallSpacing) {
                fileSourceButton(
                    title: "Files & Documents",
                    icon: "doc.fill",
                    color: .blue
                ) {
                    showingDocumentPicker = true
                }
                
                fileSourceButton(
                    title: "Photo Library",
                    icon: "photo.fill",
                    color: .green
                ) {
                    showingPhotoPicker = true
                }
                
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    fileSourceButton(
                        title: "Take Photo",
                        icon: "camera.fill",
                        color: .orange
                    ) {
                        showingCamera = true
                    }
                }
                
                if VNDocumentCameraViewController.isSupported {
                    fileSourceButton(
                        title: "Scan Document",
                        icon: "doc.text.viewfinder",
                        color: .purple
                    ) {
                        showingScanner = true
                    }
                }
                
                fileSourceButton(
                    title: "iCloud Drive",
                    icon: "icloud.fill",
                    color: .blue
                ) {
                    viewModel.pickFromiCloud { urls in
                        handleFileSelection(urls)
                    }
                }
            }
        }
    }
    
    private func fileSourceButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .frame(width: 40)
                
                Text(title)
                    .font(Theme.bodyFont)
                    .foregroundColor(Theme.foreground)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.mutedForeground)
            }
            .padding()
            .background(Theme.card)
            .cornerRadius(Theme.smallRadius)
        }
    }
    
    // MARK: - Recent Files Section
    
    private var recentFilesSection: some View {
        VStack(alignment: .leading, spacing: Theme.mediumSpacing) {
            Text("Recent Files")
                .font(Theme.titleFont)
                .foregroundColor(Theme.foreground)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.smallSpacing) {
                    ForEach(viewModel.recentFiles, id: \.self) { file in
                        recentFileCard(file)
                    }
                }
            }
        }
    }
    
    private func recentFileCard(_ file: URL) -> some View {
        Button {
            if !selectedFiles.contains(file) {
                selectedFiles.append(file)
            }
        } label: {
            VStack {
                Image(systemName: viewModel.fileIcon(for: file))
                    .font(.system(size: 32))
                    .foregroundColor(Theme.accent)
                
                Text(file.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(Theme.foreground)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 100, height: 100)
            .background(Theme.card)
            .cornerRadius(Theme.smallRadius)
            .overlay(
                selectedFiles.contains(file) ?
                RoundedRectangle(cornerRadius: Theme.smallRadius)
                    .stroke(Theme.accent, lineWidth: 2) : nil
            )
        }
    }
    
    // MARK: - Selected Files Section
    
    private var selectedFilesSection: some View {
        VStack(alignment: .leading, spacing: Theme.mediumSpacing) {
            HStack {
                Text("Selected Files (\(selectedFiles.count))")
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.foreground)
                
                Spacer()
                
                Button("Clear All") {
                    selectedFiles.removeAll()
                }
                .font(.caption)
                .foregroundColor(Theme.destructive)
            }
            
            VStack(spacing: Theme.smallSpacing) {
                ForEach(selectedFiles, id: \.self) { file in
                    selectedFileRow(file)
                }
            }
        }
    }
    
    private func selectedFileRow(_ file: URL) -> some View {
        HStack {
            Image(systemName: viewModel.fileIcon(for: file))
                .font(.system(size: 20))
                .foregroundColor(Theme.accent)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.lastPathComponent)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.foreground)
                    .lineLimit(1)
                
                if let fileSize = viewModel.fileSize(for: file) {
                    Text(fileSize)
                        .font(.caption)
                        .foregroundColor(Theme.mutedForeground)
                }
            }
            
            Spacer()
            
            Button {
                selectedFiles.removeAll { $0 == file }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Theme.mutedForeground)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Theme.card)
        .cornerRadius(Theme.smallRadius)
    }
    
    // MARK: - Upload Button
    
    private var uploadButton: some View {
        Button {
            Task {
                await uploadSelectedFiles()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                Text("Upload \(selectedFiles.count) File\(selectedFiles.count == 1 ? "" : "s")")
            }
            .font(Theme.bodyFont.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.accent)
            .cornerRadius(Theme.mediumRadius)
        }
    }
    
    // MARK: - File Handling
    
    private func handleFileSelection(_ urls: [URL]) {
        for url in urls {
            if !selectedFiles.contains(url) {
                selectedFiles.append(url)
            }
        }
    }
    
    private func processPhotoSelection() async {
        isProcessing = true
        
        for item in selectedItems {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    
                    try data.write(to: tempURL)
                    selectedFiles.append(tempURL)
                }
            } catch {
                print("Failed to process photo: \(error)")
            }
        }
        
        selectedItems.removeAll()
        isProcessing = false
    }
    
    private func handleScannedDocuments(_ images: [UIImage]) {
        isProcessing = true
        
        for (index, image) in images.enumerated() {
            if let data = image.jpegData(compressionQuality: 0.8) {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("scan_\(index)")
                    .appendingPathExtension("pdf")
                
                // Convert to PDF
                if let pdfData = createPDF(from: [image]) {
                    try? pdfData.write(to: tempURL)
                    selectedFiles.append(tempURL)
                }
            }
        }
        
        isProcessing = false
    }
    
    private func handleCapturedImage(_ image: UIImage) {
        isProcessing = true
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("photo_\(Date().timeIntervalSince1970)")
                .appendingPathExtension("jpg")
            
            try? data.write(to: tempURL)
            selectedFiles.append(tempURL)
        }
        
        isProcessing = false
    }
    
    private func uploadSelectedFiles() async {
        isProcessing = true
        errorMessage = nil
        
        do {
            try await onSelection(selectedFiles)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    private func createPDF(from images: [UIImage]) -> Data? {
        let pdfData = NSMutableData()
        
        UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)
        
        for image in images {
            let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
            
            let aspectRatio = image.size.width / image.size.height
            var drawRect = pageRect.insetBy(dx: 50, dy: 50)
            
            if aspectRatio > drawRect.width / drawRect.height {
                drawRect.size.height = drawRect.width / aspectRatio
            } else {
                drawRect.size.width = drawRect.height * aspectRatio
            }
            
            drawRect.origin.x = (pageRect.width - drawRect.width) / 2
            drawRect.origin.y = (pageRect.height - drawRect.height) / 2
            
            image.draw(in: drawRect)
        }
        
        UIGraphicsEndPDFContext()
        
        return pdfData as Data
    }
}

// MARK: - View Model

@MainActor
class FilePickerViewModel: ObservableObject {
    @Published var recentFiles: [URL] = []
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "FilePicker")
    
    var allowedDocumentTypes: [UTType] {
        [.pdf, .text, .plainText, .sourceCode, .image, .movie, .audio, .archive, .data]
    }
    
    init() {
        loadRecentFiles()
    }
    
    func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "pdf":
            return "doc.fill"
        case "doc", "docx":
            return "doc.richtext"
        case "xls", "xlsx":
            return "tablecells"
        case "ppt", "pptx":
            return "play.rectangle"
        case "txt", "md":
            return "doc.text"
        case "jpg", "jpeg", "png", "gif", "heic":
            return "photo"
        case "mp4", "mov", "avi":
            return "video"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "zip", "tar", "gz", "rar":
            return "archivebox"
        case "swift", "py", "js", "ts", "go", "rs":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc"
        }
    }
    
    func fileSize(for url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    func pickFromiCloud(completion: @escaping ([URL]) -> Void) {
        // Implementation for iCloud Drive picker
        // This would use document picker with iCloud as source
    }
    
    private func loadRecentFiles() {
        // Load recent files from UserDefaults or cache
        if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            if let files = try? FileManager.default.contentsOfDirectory(
                at: documentsDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) {
                recentFiles = Array(files.prefix(10))
            }
        }
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        
        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

// MARK: - Document Scanner

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void
        
        init(onScan: @escaping ([UIImage]) -> Void) {
            self.onScan = onScan
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            onScan(images)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        
        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}