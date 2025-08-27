//
//  MessagePaginator.swift
//  ClaudeCode
//
//  Handles pagination of messages for memory-efficient conversation display
//

import Foundation
import SwiftUI

/// Manages pagination of messages for memory-efficient display
@MainActor
final class MessagePaginator: ObservableObject {
    
    // MARK: - Configuration
    struct Configuration {
        var pageSize: Int = 50
        var preloadThreshold: Int = 10
        var maxCachedPages: Int = 3
    }
    
    // MARK: - Published Properties
    @Published var visibleMessages: [Message] = []
    @Published var isLoadingMore = false
    @Published var hasMoreMessages = true
    @Published var currentPage = 0
    
    // MARK: - Private Properties
    private var allMessages: [Message] = []
    private var configuration = Configuration()
    private var loadedPages = Set<Int>()
    private let messageCache = LRUCache<String, [Message]>(maxSize: 5)
    
    // MARK: - Computed Properties
    var totalPages: Int {
        let total = allMessages.count
        return (total + configuration.pageSize - 1) / configuration.pageSize
    }
    
    var loadedMessageCount: Int {
        visibleMessages.count
    }
    
    var totalMessageCount: Int {
        allMessages.count
    }
    
    // MARK: - Initialization
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Initialize paginator with all messages
    func initialize(with messages: [Message]) {
        allMessages = messages
        loadedPages.removeAll()
        currentPage = 0
        
        // Load initial page
        loadInitialPage()
    }
    
    /// Load more messages when scrolling up
    func loadMoreIfNeeded(currentMessage: Message) {
        guard !isLoadingMore else { return }
        
        // Check if we're near the top of loaded messages
        if let index = visibleMessages.firstIndex(where: { $0.id == currentMessage.id }),
           index < configuration.preloadThreshold {
            loadPreviousPage()
        }
    }
    
    /// Load the next page of messages
    func loadNextPage() {
        guard !isLoadingMore,
              hasMoreMessages,
              currentPage < totalPages - 1 else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        Task {
            await loadPage(currentPage)
            isLoadingMore = false
        }
    }
    
    /// Load the previous page of messages (for scrolling up in history)
    func loadPreviousPage() {
        guard !isLoadingMore else { return }
        
        // Find the earliest loaded page
        guard let earliestPage = loadedPages.min(),
              earliestPage > 0 else { return }
        
        isLoadingMore = true
        let pageToLoad = earliestPage - 1
        
        Task {
            await loadPage(pageToLoad, prepend: true)
            isLoadingMore = false
        }
    }
    
    /// Refresh current view
    func refresh() {
        loadedPages.removeAll()
        visibleMessages.removeAll()
        loadInitialPage()
    }
    
    /// Clear all cached data
    func clear() {
        allMessages.removeAll()
        visibleMessages.removeAll()
        loadedPages.removeAll()
        messageCache.clear()
        currentPage = 0
        hasMoreMessages = true
    }
    
    // MARK: - Private Methods
    
    private func loadInitialPage() {
        // Start from the end (most recent messages)
        let lastPage = max(0, totalPages - 1)
        currentPage = lastPage
        
        Task {
            await loadPage(lastPage)
            
            // Preload one more page if available
            if lastPage > 0 {
                await loadPage(lastPage - 1, prepend: true)
            }
        }
    }
    
    private func loadPage(_ page: Int, prepend: Bool = false) async {
        guard page >= 0 && page < totalPages else { return }
        
        // Check cache first
        let cacheKey = "\(page)"
        if let cachedMessages = messageCache[cacheKey] {
            if prepend {
                visibleMessages.insert(contentsOf: cachedMessages, at: 0)
            } else {
                visibleMessages.append(contentsOf: cachedMessages)
            }
            loadedPages.insert(page)
            return
        }
        
        // Calculate page range
        let startIndex = page * configuration.pageSize
        let endIndex = min(startIndex + configuration.pageSize, allMessages.count)
        
        guard startIndex < allMessages.count else {
            hasMoreMessages = false
            return
        }
        
        // Extract page messages
        let pageMessages = Array(allMessages[startIndex..<endIndex])
        
        // Cache the page
        messageCache[cacheKey] = pageMessages
        
        // Add to visible messages
        if prepend {
            visibleMessages.insert(contentsOf: pageMessages, at: 0)
        } else {
            visibleMessages.append(contentsOf: pageMessages)
        }
        
        loadedPages.insert(page)
        
        // Clean up old pages if we have too many loaded
        cleanupOldPages()
        
        // Update hasMoreMessages
        hasMoreMessages = page > 0 || page < totalPages - 1
    }
    
    private func cleanupOldPages() {
        guard loadedPages.count > configuration.maxCachedPages else { return }
        
        // Keep the most recently accessed pages
        let sortedPages = loadedPages.sorted()
        let pagesToKeep = configuration.maxCachedPages
        
        if sortedPages.count > pagesToKeep {
            // Keep pages around current view
            let midPoint = currentPage
            let keepRange = (midPoint - pagesToKeep/2)...(midPoint + pagesToKeep/2)
            
            // Remove messages from pages outside the keep range
            for page in sortedPages {
                if !keepRange.contains(page) {
                    removePageMessages(page)
                    loadedPages.remove(page)
                }
            }
        }
    }
    
    private func removePageMessages(_ page: Int) {
        let startIndex = page * configuration.pageSize
        let endIndex = min(startIndex + configuration.pageSize, allMessages.count)
        
        guard startIndex < allMessages.count else { return }
        
        let pageMessages = Array(allMessages[startIndex..<endIndex])
        let messageIds = Set(pageMessages.map { $0.id })
        
        visibleMessages.removeAll { messageIds.contains($0.id) }
    }
}

// MARK: - SwiftUI Integration

struct PaginatedMessagesView: View {
    @StateObject private var paginator = MessagePaginator()
    let messages: [Message]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if paginator.isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                    
                    ForEach(paginator.visibleMessages) { message in
                        // MessageView requires ChatMessageUI, not Message
                        Text(message.content)
                            .id(message.id)
                            .onAppear {
                                paginator.loadMoreIfNeeded(currentMessage: message)
                            }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            paginator.initialize(with: messages)
        }
    }
}