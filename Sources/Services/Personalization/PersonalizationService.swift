//
//  PersonalizationService.swift
//  ClaudeCode
//
//  Adaptive personalization system for user experience optimization
//

import Foundation
import SwiftUI
import Combine
import CoreML

// MARK: - User Behavior Model

public struct UserBehavior: Codable {
    public var userId: String
    public var sessionCount: Int = 0
    public var totalUsageTime: TimeInterval = 0
    public var lastActiveDate: Date = Date()
    public var favoriteFeatures: [String: Int] = [:]
    public var usagePatterns: UsagePatterns = UsagePatterns()
    public var preferences: PersonalizationPreferences = PersonalizationPreferences()
    public var interactions: [UserInteraction] = []
    public var achievements: Set<String> = []
}

// MARK: - Usage Patterns

public struct UsagePatterns: Codable {
    public var mostActiveHours: [Int: Double] = [:] // Hour: Activity score
    public var mostActiveDays: [String: Double] = [:] // Day: Activity score
    public var averageSessionDuration: TimeInterval = 0
    public var frequentlyUsedTools: [String: Int] = [:]
    public var commonWorkflows: [WorkflowPattern] = []
    public var searchPatterns: [String] = []
    public var errorPatterns: [String: Int] = [:]
}

// MARK: - Workflow Pattern

public struct WorkflowPattern: Codable, Identifiable {
    public let id = UUID()
    public let actions: [String]
    public let frequency: Int
    public let averageDuration: TimeInterval
    public let successRate: Double
}

// MARK: - User Interaction

public struct UserInteraction: Codable {
    public let timestamp: Date
    public let type: InteractionType
    public let target: String
    public let context: [String: String]
    public let duration: TimeInterval?
    
    public enum InteractionType: String, Codable {
        case tap
        case swipe
        case longPress
        case search
        case navigation
        case featureUse
        case error
        case success
    }
}

// MARK: - Personalization Preferences

public struct PersonalizationPreferences: Codable {
    // UI Preferences
    public var preferredTheme: String = "auto"
    public var fontSize: Int = 14
    public var compactUI: Bool = false
    public var showAnimations: Bool = true
    public var hapticFeedback: Bool = true
    
    // Content Preferences
    public var preferredLanguages: [String] = []
    public var codeHighlightTheme: String = "default"
    public var showLineNumbers: Bool = true
    public var wordWrap: Bool = false
    public var tabSize: Int = 4
    
    // Behavior Preferences
    public var autoSave: Bool = true
    public var autoComplete: Bool = true
    public var smartSuggestions: Bool = true
    public var quickActions: [String] = []
    public var shortcuts: [String: String] = [:]
    
    // Notification Preferences
    public var enableNotifications: Bool = true
    public var notificationTypes: Set<String> = []
    public var quietHoursEnabled: Bool = false
    public var quietHoursStart: String = "22:00"
    public var quietHoursEnd: String = "08:00"
}

// MARK: - Recommendation Model

public struct Recommendation: Identifiable {
    public let id = UUID()
    public let type: RecommendationType
    public let title: String
    public let description: String
    public let confidence: Double
    public let action: String?
    public let metadata: [String: Any]
    
    public enum RecommendationType {
        case feature
        case workflow
        case setting
        case tip
        case shortcut
        case content
    }
}

// MARK: - Personalization Service

@MainActor
public class PersonalizationService: ObservableObject {
    public static let shared = PersonalizationService()
    
    @Published public var userBehavior = UserBehavior(userId: "")
    @Published public var recommendations: [Recommendation] = []
    @Published public var adaptiveUI: AdaptiveUIConfiguration = AdaptiveUIConfiguration()
    @Published public var smartDefaults: [String: Any] = [:]
    @Published public var isLearning = false
    
    private let analyticsService = AnalyticsService.shared
    private let featureFlags = FeatureFlagService.shared
    private let userDefaults = UserDefaults.standard
    private let behaviorKey = "com.claudecode.personalization.behavior"
    private let preferencesKey = "com.claudecode.personalization.preferences"
    private var cancellables = Set<AnyCancellable>()
    private let learningQueue = DispatchQueue(label: "com.claudecode.learning", qos: .background)
    
    private init() {
        loadUserBehavior()
        setupObservers()
        startLearningCycle()
    }
    
    // MARK: - Public Methods
    
    /// Track user interaction
    public func trackInteraction(
        type: UserInteraction.InteractionType,
        target: String,
        context: [String: String] = [:],
        duration: TimeInterval? = nil
    ) {
        let interaction = UserInteraction(
            timestamp: Date(),
            type: type,
            target: target,
            context: context,
            duration: duration
        )
        
        userBehavior.interactions.append(interaction)
        
        // Update patterns
        updateUsagePatterns(from: interaction)
        
        // Limit interaction history
        if userBehavior.interactions.count > 1000 {
            userBehavior.interactions.removeFirst(100)
        }
        
        saveUserBehavior()
        
        // Generate recommendations if needed
        if shouldGenerateRecommendations() {
            Task {
                await generateRecommendations()
            }
        }
    }
    
    /// Track feature usage
    public func trackFeatureUsage(_ feature: String) {
        userBehavior.favoriteFeatures[feature, default: 0] += 1
        userBehavior.usagePatterns.frequentlyUsedTools[feature, default: 0] += 1
        
        trackInteraction(type: .featureUse, target: feature)
        
        // Update adaptive UI
        updateAdaptiveUI()
    }
    
    /// Track workflow
    public func trackWorkflow(_ actions: [String], success: Bool, duration: TimeInterval) {
        // Find or create workflow pattern
        if let index = userBehavior.usagePatterns.commonWorkflows.firstIndex(where: { $0.actions == actions }) {
            var pattern = userBehavior.usagePatterns.commonWorkflows[index]
            let newFrequency = pattern.frequency + 1
            let newSuccessRate = (pattern.successRate * Double(pattern.frequency) + (success ? 1.0 : 0.0)) / Double(newFrequency)
            let newAverageDuration = (pattern.averageDuration * Double(pattern.frequency) + duration) / Double(newFrequency)
            
            userBehavior.usagePatterns.commonWorkflows[index] = WorkflowPattern(
                actions: actions,
                frequency: newFrequency,
                averageDuration: newAverageDuration,
                successRate: newSuccessRate
            )
        } else {
            userBehavior.usagePatterns.commonWorkflows.append(
                WorkflowPattern(
                    actions: actions,
                    frequency: 1,
                    averageDuration: duration,
                    successRate: success ? 1.0 : 0.0
                )
            )
        }
        
        saveUserBehavior()
    }
    
    /// Update user preference
    public func updatePreference<T>(_ keyPath: WritableKeyPath<PersonalizationPreferences, T>, value: T) {
        userBehavior.preferences[keyPath: keyPath] = value
        saveUserBehavior()
        applyPreferences()
    }
    
    /// Get smart default for a setting
    public func getSmartDefault<T>(for key: String, fallback: T) -> T {
        if let value = smartDefaults[key] as? T {
            return value
        }
        return fallback
    }
    
    /// Get personalized recommendations
    public func getRecommendations(type: Recommendation.RecommendationType? = nil) -> [Recommendation] {
        if let type = type {
            return recommendations.filter { $0.type == type }
        }
        return recommendations
    }
    
    /// Apply recommendation
    public func applyRecommendation(_ recommendation: Recommendation) {
        switch recommendation.type {
        case .setting:
            applySetting(recommendation)
        case .shortcut:
            applyShortcut(recommendation)
        case .workflow:
            applyWorkflow(recommendation)
        default:
            break
        }
        
        // Track application
        analyticsService.track(event: "recommendation_applied", properties: [
            "type": String(describing: recommendation.type),
            "title": recommendation.title,
            "confidence": recommendation.confidence
        ])
    }
    
    /// Reset personalization
    public func reset() {
        userBehavior = UserBehavior(userId: getUserId())
        recommendations.removeAll()
        smartDefaults.removeAll()
        adaptiveUI = AdaptiveUIConfiguration()
        saveUserBehavior()
    }
    
    // MARK: - Private Methods
    
    private func loadUserBehavior() {
        if let data = userDefaults.data(forKey: behaviorKey),
           let behavior = try? JSONDecoder().decode(UserBehavior.self, from: data) {
            userBehavior = behavior
        } else {
            userBehavior = UserBehavior(userId: getUserId())
        }
        
        applyPreferences()
    }
    
    private func saveUserBehavior() {
        if let data = try? JSONEncoder().encode(userBehavior) {
            userDefaults.set(data, forKey: behaviorKey)
        }
    }
    
    private func getUserId() -> String {
        if let userId = userDefaults.string(forKey: "userId") {
            return userId
        }
        let newId = UUID().uuidString
        userDefaults.set(newId, forKey: "userId")
        return newId
    }
    
    private func updateUsagePatterns(from interaction: UserInteraction) {
        // Update time patterns
        let hour = Calendar.current.component(.hour, from: interaction.timestamp)
        userBehavior.usagePatterns.mostActiveHours[hour, default: 0] += 1
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let day = dayFormatter.string(from: interaction.timestamp)
        userBehavior.usagePatterns.mostActiveDays[day, default: 0] += 1
        
        // Update error patterns
        if interaction.type == .error {
            userBehavior.usagePatterns.errorPatterns[interaction.target, default: 0] += 1
        }
        
        // Update search patterns
        if interaction.type == .search {
            userBehavior.usagePatterns.searchPatterns.append(interaction.target)
            if userBehavior.usagePatterns.searchPatterns.count > 100 {
                userBehavior.usagePatterns.searchPatterns.removeFirst()
            }
        }
    }
    
    private func shouldGenerateRecommendations() -> Bool {
        // Generate recommendations based on various triggers
        let interactionCount = userBehavior.interactions.count
        return interactionCount % 50 == 0 || // Every 50 interactions
               recommendations.isEmpty || // No recommendations yet
               Date().timeIntervalSince(userBehavior.lastActiveDate) > 86400 // Daily
    }
    
    private func generateRecommendations() async {
        isLearning = true
        defer { isLearning = false }
        
        var newRecommendations: [Recommendation] = []
        
        // Feature recommendations based on usage
        newRecommendations.append(contentsOf: generateFeatureRecommendations())
        
        // Workflow recommendations
        newRecommendations.append(contentsOf: generateWorkflowRecommendations())
        
        // Setting recommendations
        newRecommendations.append(contentsOf: generateSettingRecommendations())
        
        // Tip recommendations
        newRecommendations.append(contentsOf: generateTipRecommendations())
        
        // Sort by confidence
        newRecommendations.sort { $0.confidence > $1.confidence }
        
        // Update recommendations
        recommendations = Array(newRecommendations.prefix(10))
        
        // Update smart defaults
        updateSmartDefaults()
    }
    
    private func generateFeatureRecommendations() -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Find underused features
        let allFeatures = ["chat", "projects", "terminal", "monitoring", "tools"]
        let usedFeatures = Set(userBehavior.favoriteFeatures.keys)
        let underusedFeatures = allFeatures.filter { !usedFeatures.contains($0) }
        
        for feature in underusedFeatures {
            recommendations.append(
                Recommendation(
                    type: .feature,
                    title: "Try \(feature.capitalized)",
                    description: "You haven't explored this feature yet",
                    confidence: 0.8,
                    action: "open_\(feature)",
                    metadata: ["feature": feature]
                )
            )
        }
        
        return recommendations
    }
    
    private func generateWorkflowRecommendations() -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Recommend based on common workflows
        for pattern in userBehavior.usagePatterns.commonWorkflows.prefix(3) {
            if pattern.successRate < 0.7 {
                recommendations.append(
                    Recommendation(
                        type: .workflow,
                        title: "Improve Workflow",
                        description: "This workflow could be optimized",
                        confidence: 0.9 * (1 - pattern.successRate),
                        action: "optimize_workflow",
                        metadata: ["actions": pattern.actions]
                    )
                )
            }
        }
        
        return recommendations
    }
    
    private func generateSettingRecommendations() -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Recommend based on usage patterns
        if userBehavior.usagePatterns.mostActiveHours.contains(where: { $0.key >= 20 || $0.key <= 6 }) {
            if userBehavior.preferences.preferredTheme != "dark" {
                recommendations.append(
                    Recommendation(
                        type: .setting,
                        title: "Enable Dark Mode",
                        description: "You often use the app at night",
                        confidence: 0.85,
                        action: "set_dark_theme",
                        metadata: ["setting": "theme", "value": "dark"]
                    )
                )
            }
        }
        
        // Recommend shortcuts for frequently used features
        let topFeatures = userBehavior.favoriteFeatures.sorted { $0.value > $1.value }.prefix(3)
        for (feature, _) in topFeatures {
            if !userBehavior.preferences.shortcuts.keys.contains(feature) {
                recommendations.append(
                    Recommendation(
                        type: .shortcut,
                        title: "Add Shortcut for \(feature.capitalized)",
                        description: "You use this feature frequently",
                        confidence: 0.75,
                        action: "add_shortcut",
                        metadata: ["feature": feature]
                    )
                )
            }
        }
        
        return recommendations
    }
    
    private func generateTipRecommendations() -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Tips based on experience level
        let sessionCount = userBehavior.sessionCount
        
        if sessionCount < 5 {
            recommendations.append(
                Recommendation(
                    type: .tip,
                    title: "Explore the Help Center",
                    description: "Learn about all features",
                    confidence: 0.9,
                    action: "open_help",
                    metadata: [:]
                )
            )
        }
        
        if sessionCount > 10 && !userBehavior.preferences.autoComplete {
            recommendations.append(
                Recommendation(
                    type: .tip,
                    title: "Enable Auto-Complete",
                    description: "Speed up your coding",
                    confidence: 0.7,
                    action: "enable_autocomplete",
                    metadata: [:]
                )
            )
        }
        
        return recommendations
    }
    
    private func updateSmartDefaults() {
        // Set smart defaults based on behavior
        
        // Default tab based on most used feature
        if let topFeature = userBehavior.favoriteFeatures.max(by: { $0.value < $1.value }) {
            smartDefaults["defaultTab"] = topFeature.key
        }
        
        // Default theme based on usage time
        let nightUsage = userBehavior.usagePatterns.mostActiveHours
            .filter { $0.key >= 20 || $0.key <= 6 }
            .values.reduce(0, +)
        let dayUsage = userBehavior.usagePatterns.mostActiveHours
            .filter { $0.key > 6 && $0.key < 20 }
            .values.reduce(0, +)
        
        if nightUsage > dayUsage {
            smartDefaults["defaultTheme"] = "dark"
        } else if dayUsage > nightUsage * 2 {
            smartDefaults["defaultTheme"] = "light"
        } else {
            smartDefaults["defaultTheme"] = "auto"
        }
        
        // Default code settings based on preferences
        smartDefaults["defaultFontSize"] = userBehavior.preferences.fontSize
        smartDefaults["defaultTabSize"] = userBehavior.preferences.tabSize
    }
    
    private func updateAdaptiveUI() {
        // Update UI configuration based on behavior
        
        // Show most used features prominently
        let topFeatures = userBehavior.favoriteFeatures
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
        
        adaptiveUI.prominentFeatures = topFeatures
        
        // Adjust UI density based on experience
        if userBehavior.sessionCount > 20 {
            adaptiveUI.uiDensity = .compact
        } else if userBehavior.sessionCount > 10 {
            adaptiveUI.uiDensity = .normal
        } else {
            adaptiveUI.uiDensity = .comfortable
        }
        
        // Show shortcuts for power users
        adaptiveUI.showShortcuts = userBehavior.sessionCount > 30
        
        // Adjust animation speed
        if userBehavior.preferences.showAnimations {
            adaptiveUI.animationSpeed = userBehavior.sessionCount > 50 ? 0.5 : 1.0
        } else {
            adaptiveUI.animationSpeed = 0
        }
    }
    
    private func applyPreferences() {
        // Apply user preferences to the app
        
        // Theme
        if let colorScheme = ColorScheme(rawValue: userBehavior.preferences.preferredTheme) {
            ThemeManager.shared.setColorScheme(colorScheme)
        }
        
        // Other preferences
        userDefaults.set(userBehavior.preferences.autoSave, forKey: "autoSave")
        userDefaults.set(userBehavior.preferences.autoComplete, forKey: "autoComplete")
        userDefaults.set(userBehavior.preferences.hapticFeedback, forKey: "hapticFeedback")
    }
    
    private func applySetting(_ recommendation: Recommendation) {
        guard let setting = recommendation.metadata["setting"] as? String,
              let value = recommendation.metadata["value"] else { return }
        
        switch setting {
        case "theme":
            if let theme = value as? String {
                updatePreference(\.preferredTheme, value: theme)
            }
        default:
            break
        }
    }
    
    private func applyShortcut(_ recommendation: Recommendation) {
        guard let feature = recommendation.metadata["feature"] as? String else { return }
        
        // Add shortcut for feature
        userBehavior.preferences.shortcuts[feature] = "cmd+\(feature.prefix(1))"
        saveUserBehavior()
    }
    
    private func applyWorkflow(_ recommendation: Recommendation) {
        // Apply workflow optimization
        // This would involve creating automated workflows or macros
    }
    
    private func setupObservers() {
        // Track app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.userBehavior.sessionCount += 1
                self?.userBehavior.lastActiveDate = Date()
                self?.saveUserBehavior()
            }
            .store(in: &cancellables)
        
        // Track usage time
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.userBehavior.totalUsageTime += 60
                
                // Update average session duration
                if let sessionCount = self?.userBehavior.sessionCount, sessionCount > 0 {
                    self?.userBehavior.usagePatterns.averageSessionDuration =
                        (self?.userBehavior.totalUsageTime ?? 0) / Double(sessionCount)
                }
            }
            .store(in: &cancellables)
    }
    
    private func startLearningCycle() {
        // Periodic learning and adaptation
        Timer.publish(every: 3600, on: .main, in: .common) // Every hour
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.generateRecommendations()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Adaptive UI Configuration

public struct AdaptiveUIConfiguration {
    public var prominentFeatures: [String] = []
    public var uiDensity: UIDensity = .normal
    public var showShortcuts = false
    public var animationSpeed: Double = 1.0
    public var quickActions: [String] = []
    
    public enum UIDensity {
        case compact
        case normal
        case comfortable
    }
}