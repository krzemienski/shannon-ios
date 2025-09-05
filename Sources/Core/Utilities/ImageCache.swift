//
//  ImageCache.swift
//  ClaudeCode
//
//  Image caching system for improved performance and memory management
//

#if os(iOS)
import UIKit
import SwiftUI
import Combine

/// Image cache manager for efficient image loading and memory management
@MainActor
final class ImageCache: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ImageCache()
    
    // MARK: - Properties
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCache = DiskCache()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private var cancellables = Set<AnyCancellable>()
    
    // Performance metrics
    @Published var cacheHitRate: Double = 0
    @Published var memoryCacheSize: Int = 0
    @Published var diskCacheSize: Int = 0
    
    private var cacheHits = 0
    private var cacheMisses = 0
    
    // MARK: - Configuration
    struct Configuration {
        var maxMemoryCacheSizeBytes: Int = 50 * 1024 * 1024 // 50MB
        var maxDiskCacheSizeBytes: Int = 200 * 1024 * 1024 // 200MB
        var thumbnailSize = CGSize(width: 150, height: 150)
        var compressionQuality: CGFloat = 0.8
    }
    
    private var configuration = Configuration()
    
    // MARK: - Initialization
    private init() {
        setupCache()
        observeMemoryWarnings()
    }
    
    private func setupCache() {
        // Configure memory cache
        memoryCache.totalCostLimit = configuration.maxMemoryCacheSizeBytes
        memoryCache.countLimit = 100
        
        // Configure thumbnail cache
        thumbnailCache.totalCostLimit = 10 * 1024 * 1024 // 10MB for thumbnails
        thumbnailCache.countLimit = 200
    }
    
    private func observeMemoryWarnings() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Load image from cache or download
    func loadImage(from url: URL) async throws -> UIImage {
        let key = url.absoluteString as NSString
        
        // Check memory cache
        if let cachedImage = memoryCache.object(forKey: key) {
            cacheHits += 1
            updateCacheMetrics()
            return cachedImage
        }
        
        // Check disk cache
        if let diskImage = await diskCache.loadImage(for: url) {
            cacheHits += 1
            // Store in memory cache for quick access
            memoryCache.setObject(diskImage, forKey: key, cost: diskImage.estimatedSizeInBytes)
            updateCacheMetrics()
            return diskImage
        }
        
        // Cache miss - download image
        cacheMisses += 1
        let image = try await downloadImage(from: url)
        
        // Cache the image
        await cacheImage(image, for: url)
        updateCacheMetrics()
        
        return image
    }
    
    /// Load thumbnail version of image
    func loadThumbnail(from url: URL) async throws -> UIImage {
        let key = "thumb_\(url.absoluteString)" as NSString
        
        // Check thumbnail cache
        if let thumbnail = thumbnailCache.object(forKey: key) {
            return thumbnail
        }
        
        // Load full image and generate thumbnail
        let fullImage = try await loadImage(from: url)
        let thumbnail = generateThumbnail(from: fullImage)
        
        // Cache thumbnail
        thumbnailCache.setObject(thumbnail, forKey: key, cost: thumbnail.estimatedSizeInBytes)
        
        return thumbnail
    }
    
    /// Preload images for better scrolling performance
    func preloadImages(urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls.prefix(10) { // Limit concurrent preloads
                group.addTask { [weak self] in
                    _ = try? await self?.loadImage(from: url)
                }
            }
        }
    }
    
    /// Clear all caches
    func clearCache() async {
        memoryCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        await diskCache.clear()
        
        cacheHits = 0
        cacheMisses = 0
        updateCacheMetrics()
    }
    
    /// Clear memory cache only
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        updateCacheMetrics()
    }
    
    // MARK: - Private Methods
    
    private func downloadImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let image = UIImage(data: data) else {
            throw ImageCacheError.invalidImageData
        }
        
        return image
    }
    
    private func cacheImage(_ image: UIImage, for url: URL) async {
        let key = url.absoluteString as NSString
        
        // Store in memory cache
        let cost = image.estimatedSizeInBytes
        memoryCache.setObject(image, forKey: key, cost: cost)
        
        // Store in disk cache asynchronously
        await diskCache.saveImage(image, for: url)
    }
    
    private func generateThumbnail(from image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: configuration.thumbnailSize)
        
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: configuration.thumbnailSize))
        }
    }
    
    private func handleMemoryWarning() {
        // Clear memory cache but keep disk cache
        clearMemoryCache()
    }
    
    private func updateCacheMetrics() {
        let total = cacheHits + cacheMisses
        cacheHitRate = total > 0 ? Double(cacheHits) / Double(total) : 0
        
        // Calculate cache sizes
        memoryCacheSize = calculateMemoryCacheSize()
        Task {
            diskCacheSize = await diskCache.calculateSize()
        }
    }
    
    private func calculateMemoryCacheSize() -> Int {
        // This is an approximation
        return memoryCache.totalCostLimit > 0 ? Int(Double(memoryCache.totalCostLimit) * 0.7) : 0
    }
}

// MARK: - Disk Cache

private actor DiskCache {
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    
    init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache")
        
        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func saveImage(_ image: UIImage, for url: URL) async {
        let fileName = url.absoluteString.data(using: .utf8)?.base64EncodedString() ?? ""
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        try? data.write(to: fileURL)
    }
    
    func loadImage(for url: URL) async -> UIImage? {
        let fileName = url.absoluteString.data(using: .utf8)?.base64EncodedString() ?? ""
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    func clear() async {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func calculateSize() async -> Int {
        let files = (try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        
        return files.reduce(0) { total, file in
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + size
        }
    }
}

// MARK: - Extensions

extension UIImage {
    var estimatedSizeInBytes: Int {
        let pixelCount = Int(size.width * size.height * scale * scale)
        return pixelCount * 4 // 4 bytes per pixel (RGBA)
    }
}

// MARK: - Error Types

enum ImageCacheError: LocalizedError {
    case invalidImageData
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data received"
        case .downloadFailed:
            return "Failed to download image"
        }
    }
}
#endif // os(iOS)
