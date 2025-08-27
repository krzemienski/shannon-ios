//
//  FilePreviewView.swift
//  ClaudeCode
//
//  Preview files before upload or after download with sharing support
//

import SwiftUI
import QuickLook
import PDFKit
import AVKit
import UniformTypeIdentifiers
import OSLog

/// File preview view with support for various file types and sharing
struct FilePreviewView: View {
    let fileURL: URL
    let fileName: String
    let showShareButton: Bool
    
    @Environment(\.dismiss) private var dismiss
    @State private var isSharePresented = false
    @State private var fileContent: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "FilePreview")
    
    init(fileURL: URL, fileName: String? = nil, showShareButton: Bool = true) {
        self.fileURL = fileURL
        self.fileName = fileName ?? fileURL.lastPathComponent
        self.showShareButton = showShareButton
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if isLoading {
                    LoadingView(message: "Loading file...")
                } else if let errorMessage = errorMessage {
                    FilePreviewErrorStateView(message: errorMessage)
                } else {
                    filePreviewContent
                }
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if showShareButton {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        shareButton
                    }
                }
            }
            .sheet(isPresented: $isSharePresented) {
                ShareSheet(items: [fileURL])
            }
        }
        .onAppear {
            loadFilePreview()
        }
    }
    
    // MARK: - Preview Content
    
    @ViewBuilder
    private var filePreviewContent: some View {
        let fileType = UTType(filenameExtension: fileURL.pathExtension)
        
        if let fileType = fileType {
            if fileType.conforms(to: .image) {
                ImagePreviewView(fileURL: fileURL)
            } else if fileType.conforms(to: .pdf) {
                PDFPreviewView(fileURL: fileURL)
            } else if fileType.conforms(to: .movie) || fileType.conforms(to: .video) {
                VideoPreviewView(fileURL: fileURL)
            } else if fileType.conforms(to: .audio) {
                AudioPreviewView(fileURL: fileURL)
            } else if fileType.conforms(to: .text) || fileType.conforms(to: .sourceCode) {
                TextPreviewView(content: fileContent ?? "", fileType: fileType)
            } else {
                QuickLookPreview(fileURL: fileURL)
            }
        } else {
            UnsupportedFileView(fileName: fileName, fileURL: fileURL)
        }
    }
    
    private var shareButton: some View {
        Button {
            isSharePresented = true
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
    }
    
    // MARK: - File Loading
    
    private func loadFilePreview() {
        Task {
            do {
                let fileType = UTType(filenameExtension: fileURL.pathExtension)
                
                if fileType?.conforms(to: .text) == true || fileType?.conforms(to: .sourceCode) == true {
                    fileContent = try String(contentsOf: fileURL, encoding: .utf8)
                }
                
                isLoading = false
            } catch {
                logger.error("Failed to load file: \(error)")
                errorMessage = "Failed to load file: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - Image Preview

struct ImagePreviewView: View {
    let fileURL: URL
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    
    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1), 4)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                withAnimation(.spring()) {
                                    if scale < 1 {
                                        scale = 1
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2
                            }
                        }
                    }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        if let data = try? Data(contentsOf: fileURL),
           let loadedImage = UIImage(data: data) {
            image = loadedImage
        }
    }
}

// MARK: - PDF Preview

struct PDFPreviewView: View {
    let fileURL: URL
    @State private var pdfDocument: PDFDocument?
    
    var body: some View {
        if let pdfDocument = pdfDocument {
            PDFKitView(document: pdfDocument)
        } else {
            ProgressView()
                .onAppear {
                    pdfDocument = PDFDocument(url: fileURL)
                }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

// MARK: - Video Preview

struct VideoPreviewView: View {
    let fileURL: URL
    @State private var player: AVPlayer?
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: fileURL)
            }
            .onDisappear {
                player?.pause()
            }
    }
}

// MARK: - Audio Preview

struct AudioPreviewView: View {
    let fileURL: URL
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    
    var body: some View {
        VStack(spacing: Theme.largeSpacing) {
            Spacer()
            
            // Audio visualization
            Image(systemName: "music.note.list")
                .font(.system(size: 80))
                .foregroundColor(Theme.accent)
            
            Text(fileURL.lastPathComponent)
                .font(Theme.titleFont)
                .foregroundColor(Theme.foreground)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Progress
            VStack(spacing: Theme.smallSpacing) {
                Slider(value: $currentTime, in: 0...max(duration, 1)) { _ in
                    player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 1))
                }
                .accentColor(Theme.accent)
                
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .foregroundColor(Theme.mutedForeground)
                    
                    Spacer()
                    
                    Text(formatTime(duration))
                        .font(.caption)
                        .foregroundColor(Theme.mutedForeground)
                }
            }
            .padding(.horizontal, Theme.largeSpacing)
            
            // Controls
            HStack(spacing: Theme.largeSpacing) {
                Button {
                    player?.seek(to: CMTime(seconds: max(currentTime - 15, 0), preferredTimescale: 1))
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .foregroundColor(Theme.foreground)
                }
                
                Button {
                    if isPlaying {
                        player?.pause()
                    } else {
                        player?.play()
                    }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.accent)
                }
                
                Button {
                    player?.seek(to: CMTime(seconds: min(currentTime + 15, duration), preferredTimescale: 1))
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title)
                        .foregroundColor(Theme.foreground)
                }
            }
            
            Spacer()
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            updateProgress()
        }
    }
    
    private func setupPlayer() {
        player = AVPlayer(url: fileURL)
        
        if let item = player?.currentItem {
            duration = item.duration.seconds
        }
    }
    
    private func updateProgress() {
        if let player = player {
            currentTime = player.currentTime().seconds
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Text Preview

struct TextPreviewView: View {
    let content: String
    let fileType: UTType
    @State private var fontSize: CGFloat = 14
    
    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(size: fontSize, weight: .regular, design: .monospaced))
                .foregroundColor(Theme.foreground)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.card)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        fontSize = max(10, fontSize - 2)
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                    }
                    
                    Button {
                        fontSize = min(24, fontSize + 2)
                    } label: {
                        Image(systemName: "textformat.size.larger")
                    }
                }
            }
        }
    }
}

// MARK: - QuickLook Preview

struct QuickLookPreview: UIViewControllerRepresentable {
    let fileURL: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let fileURL: URL
        
        init(fileURL: URL) {
            self.fileURL = fileURL
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return fileURL as QLPreviewItem
        }
    }
}

// MARK: - Unsupported File View

struct UnsupportedFileView: View {
    let fileName: String
    let fileURL: URL
    
    var body: some View {
        VStack(spacing: Theme.largeSpacing) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 64))
                .foregroundColor(Theme.mutedForeground)
            
            Text("Cannot Preview File")
                .font(Theme.titleFont)
                .foregroundColor(Theme.foreground)
            
            Text(fileName)
                .font(Theme.bodyFont)
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 {
                Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                    .font(.caption)
                    .foregroundColor(Theme.mutedForeground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error State View

struct FilePreviewErrorStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: Theme.mediumSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(Theme.destructive)
            
            Text("Error Loading File")
                .font(Theme.titleFont)
                .foregroundColor(Theme.foreground)
            
            Text(message)
                .font(Theme.bodyFont)
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}