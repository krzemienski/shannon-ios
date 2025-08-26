//
//  TooltipService.swift
//  ClaudeCode
//
//  Interactive tooltip and contextual help system
//

import Foundation
import SwiftUI
import Combine

// MARK: - Tooltip Model

public struct Tooltip: Identifiable, Codable {
    public let id: String
    public let targetId: String
    public let title: String
    public let message: String
    public let icon: String?
    public let type: TooltipType
    public let position: TooltipPosition
    public let showOnce: Bool
    public let priority: Int
    public let triggerEvent: TriggerEvent
    public let actions: [TooltipAction]
    public var hasBeenShown: Bool = false
    
    public enum TooltipType: String, Codable {
        case info
        case warning
        case success
        case tip
        case tutorial
        case feature
    }
    
    public enum TooltipPosition: String, Codable {
        case top
        case bottom
        case leading
        case trailing
        case center
    }
    
    public enum TriggerEvent: String, Codable {
        case onAppear
        case onTap
        case onLongPress
        case onHover
        case manual
        case afterDelay
    }
    
    public struct TooltipAction: Codable {
        public let title: String
        public let actionId: String
        public let style: ActionStyle
        
        public enum ActionStyle: String, Codable {
            case primary
            case secondary
            case destructive
        }
    }
}

// MARK: - Help Article

public struct HelpArticle: Identifiable, Codable {
    public let id: String
    public let title: String
    public let category: String
    public let content: String
    public let tags: [String]
    public let relatedArticles: [String]
    public let videoURL: String?
    public let lastUpdated: Date
    public let viewCount: Int
    public let helpfulCount: Int
    public let notHelpfulCount: Int
}

// MARK: - FAQ Item

public struct FAQItem: Identifiable, Codable {
    public let id: String
    public let question: String
    public let answer: String
    public let category: String
    public let popularity: Int
    public let relatedQuestions: [String]
}

// MARK: - Tooltip Service

@MainActor
public class TooltipService: ObservableObject {
    public static let shared = TooltipService()
    
    @Published public var activeTooltip: Tooltip?
    @Published public var tooltipQueue: [Tooltip] = []
    @Published public var shownTooltips: Set<String> = []
    @Published public var isShowingHelp = false
    @Published public var currentHelpArticle: HelpArticle?
    @Published public var searchResults: [HelpArticle] = []
    
    private var tooltips: [String: Tooltip] = [:]
    private var helpArticles: [HelpArticle] = []
    private var faqItems: [FAQItem] = []
    private let userDefaults = UserDefaults.standard
    private let shownTooltipsKey = "com.claudecode.tooltips.shown"
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadShownTooltips()
        loadTooltips()
        loadHelpContent()
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Register a tooltip
    public func registerTooltip(_ tooltip: Tooltip) {
        tooltips[tooltip.id] = tooltip
    }
    
    /// Show a tooltip by ID
    public func showTooltip(_ tooltipId: String) {
        guard let tooltip = tooltips[tooltipId] else { return }
        
        // Check if already shown and should only show once
        if tooltip.showOnce && shownTooltips.contains(tooltipId) {
            return
        }
        
        // Add to queue or show immediately
        if activeTooltip == nil {
            activeTooltip = tooltip
        } else {
            tooltipQueue.append(tooltip)
            tooltipQueue.sort { $0.priority > $1.priority }
        }
        
        // Mark as shown
        markTooltipAsShown(tooltipId)
    }
    
    /// Hide current tooltip
    public func hideTooltip() {
        activeTooltip = nil
        
        // Show next in queue if available
        if !tooltipQueue.isEmpty {
            activeTooltip = tooltipQueue.removeFirst()
        }
    }
    
    /// Show contextual help for a feature
    public func showContextualHelp(for featureId: String) {
        guard let article = findHelpArticle(for: featureId) else { return }
        
        currentHelpArticle = article
        isShowingHelp = true
        
        // Track help view
        AnalyticsService.shared.track(event: "help_viewed", properties: [
            "article_id": article.id,
            "category": article.category
        ])
    }
    
    /// Search help articles
    public func searchHelp(_ query: String) -> [HelpArticle] {
        guard !query.isEmpty else { return helpArticles }
        
        let lowercasedQuery = query.lowercased()
        return helpArticles.filter { article in
            article.title.lowercased().contains(lowercasedQuery) ||
            article.content.lowercased().contains(lowercasedQuery) ||
            article.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    /// Get FAQ items for a category
    public func getFAQs(for category: String? = nil) -> [FAQItem] {
        if let category = category {
            return faqItems.filter { $0.category == category }
        }
        return faqItems.sorted { $0.popularity > $1.popularity }
    }
    
    /// Mark article as helpful
    public func markArticleHelpful(_ articleId: String, helpful: Bool) {
        guard let index = helpArticles.firstIndex(where: { $0.id == articleId }) else { return }
        
        if helpful {
            helpArticles[index] = HelpArticle(
                id: helpArticles[index].id,
                title: helpArticles[index].title,
                category: helpArticles[index].category,
                content: helpArticles[index].content,
                tags: helpArticles[index].tags,
                relatedArticles: helpArticles[index].relatedArticles,
                videoURL: helpArticles[index].videoURL,
                lastUpdated: helpArticles[index].lastUpdated,
                viewCount: helpArticles[index].viewCount + 1,
                helpfulCount: helpArticles[index].helpfulCount + 1,
                notHelpfulCount: helpArticles[index].notHelpfulCount
            )
        } else {
            helpArticles[index] = HelpArticle(
                id: helpArticles[index].id,
                title: helpArticles[index].title,
                category: helpArticles[index].category,
                content: helpArticles[index].content,
                tags: helpArticles[index].tags,
                relatedArticles: helpArticles[index].relatedArticles,
                videoURL: helpArticles[index].videoURL,
                lastUpdated: helpArticles[index].lastUpdated,
                viewCount: helpArticles[index].viewCount + 1,
                helpfulCount: helpArticles[index].helpfulCount,
                notHelpfulCount: helpArticles[index].notHelpfulCount + 1
            )
        }
        
        // Track feedback
        AnalyticsService.shared.track(event: "help_feedback", properties: [
            "article_id": articleId,
            "helpful": helpful
        ])
    }
    
    /// Reset shown tooltips (for testing or user request)
    public func resetTooltips() {
        shownTooltips.removeAll()
        saveShownTooltips()
    }
    
    // MARK: - Private Methods
    
    private func loadShownTooltips() {
        if let shown = userDefaults.object(forKey: shownTooltipsKey) as? [String] {
            shownTooltips = Set(shown)
        }
    }
    
    private func saveShownTooltips() {
        userDefaults.set(Array(shownTooltips), forKey: shownTooltipsKey)
    }
    
    private func markTooltipAsShown(_ tooltipId: String) {
        shownTooltips.insert(tooltipId)
        saveShownTooltips()
    }
    
    private func loadTooltips() {
        // Load predefined tooltips
        tooltips = [
            "chat_input": Tooltip(
                id: "chat_input",
                targetId: "chat_input_field",
                title: "Chat with Claude",
                message: "Type your question here and press Enter to send",
                icon: "message.fill",
                type: .tip,
                position: .top,
                showOnce: true,
                priority: 5,
                triggerEvent: .onAppear,
                actions: []
            ),
            "project_create": Tooltip(
                id: "project_create",
                targetId: "create_project_button",
                title: "Create Your First Project",
                message: "Tap here to create a new project and start coding",
                icon: "folder.fill.badge.plus",
                type: .feature,
                position: .bottom,
                showOnce: true,
                priority: 8,
                triggerEvent: .onAppear,
                actions: [
                    Tooltip.TooltipAction(
                        title: "Create Project",
                        actionId: "create_project",
                        style: .primary
                    )
                ]
            ),
            "terminal_access": Tooltip(
                id: "terminal_access",
                targetId: "terminal_tab",
                title: "Terminal Access",
                message: "Run commands directly from the app",
                icon: "terminal.fill",
                type: .info,
                position: .top,
                showOnce: false,
                priority: 3,
                triggerEvent: .onTap,
                actions: []
            )
        ]
    }
    
    private func loadHelpContent() {
        // Load help articles
        helpArticles = [
            HelpArticle(
                id: "getting_started",
                title: "Getting Started with Claude Code",
                category: "Basics",
                content: """
                # Getting Started with Claude Code
                
                Welcome to Claude Code! This guide will help you get started quickly.
                
                ## First Steps
                1. Set up your API key in Settings
                2. Create your first project
                3. Start chatting with Claude
                
                ## Key Features
                - AI-powered code assistance
                - Project management
                - Terminal access
                - Performance monitoring
                """,
                tags: ["getting started", "basics", "tutorial"],
                relatedArticles: ["api_setup", "create_project"],
                videoURL: nil,
                lastUpdated: Date(),
                viewCount: 0,
                helpfulCount: 0,
                notHelpfulCount: 0
            ),
            HelpArticle(
                id: "api_setup",
                title: "Setting Up Your API Key",
                category: "Configuration",
                content: """
                # Setting Up Your API Key
                
                To use Claude Code, you need an API key from Anthropic.
                
                ## Steps:
                1. Visit console.anthropic.com
                2. Create an account or sign in
                3. Generate an API key
                4. Copy the key
                5. Go to Settings > API Configuration
                6. Paste your key
                """,
                tags: ["api", "configuration", "setup"],
                relatedArticles: ["getting_started", "troubleshooting_api"],
                videoURL: nil,
                lastUpdated: Date(),
                viewCount: 0,
                helpfulCount: 0,
                notHelpfulCount: 0
            ),
            HelpArticle(
                id: "create_project",
                title: "Creating Your First Project",
                category: "Projects",
                content: """
                # Creating Your First Project
                
                Projects help you organize your code and collaborate with Claude.
                
                ## To create a project:
                1. Go to the Projects tab
                2. Tap the + button
                3. Enter project details
                4. Choose a template (optional)
                5. Start coding!
                """,
                tags: ["projects", "create", "organize"],
                relatedArticles: ["getting_started", "project_settings"],
                videoURL: nil,
                lastUpdated: Date(),
                viewCount: 0,
                helpfulCount: 0,
                notHelpfulCount: 0
            )
        ]
        
        // Load FAQ items
        faqItems = [
            FAQItem(
                id: "faq_1",
                question: "How do I get an API key?",
                answer: "Visit console.anthropic.com to create an account and generate an API key.",
                category: "Getting Started",
                popularity: 10,
                relatedQuestions: ["faq_2"]
            ),
            FAQItem(
                id: "faq_2",
                question: "Is my data secure?",
                answer: "Yes! All data is encrypted and stored locally on your device. API calls are made directly to Anthropic's servers.",
                category: "Security",
                popularity: 8,
                relatedQuestions: ["faq_1"]
            ),
            FAQItem(
                id: "faq_3",
                question: "Can I use Claude Code offline?",
                answer: "You can view and edit local projects offline, but AI features require an internet connection.",
                category: "Features",
                popularity: 6,
                relatedQuestions: []
            ),
            FAQItem(
                id: "faq_4",
                question: "What programming languages are supported?",
                answer: "Claude Code supports all major programming languages including Swift, Python, JavaScript, TypeScript, Go, Rust, and many more.",
                category: "Features",
                popularity: 9,
                relatedQuestions: ["faq_3"]
            )
        ]
    }
    
    private func findHelpArticle(for featureId: String) -> HelpArticle? {
        return helpArticles.first { article in
            article.id == featureId || article.tags.contains(featureId)
        }
    }
    
    private func setupObservers() {
        // Auto-hide tooltips after delay
        $activeTooltip
            .compactMap { $0 }
            .delay(for: .seconds(5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.hideTooltip()
            }
            .store(in: &cancellables)
    }
}