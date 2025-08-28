//
//  FeatureFlagService.swift
//  ClaudeCode
//
//  Feature flag system for controlled feature rollout and A/B testing
//

import Foundation
import Combine
import SwiftUI

// MARK: - Feature Flag Model

/// Represents a feature flag with its configuration
public struct FeatureFlag: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public var isEnabled: Bool
    public var rolloutPercentage: Int
    public var targetAudience: TargetAudience?
    public var experimentConfig: ExperimentConfig?
    public var metadata: [String: AnyCodable]
    public var createdAt: Date
    public var lastModified: Date
    
    public init(
        id: String,
        name: String,
        description: String,
        isEnabled: Bool = false,
        rolloutPercentage: Int = 0,
        targetAudience: TargetAudience? = nil,
        experimentConfig: ExperimentConfig? = nil,
        metadata: [String: AnyCodable] = [:],
        createdAt: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isEnabled = isEnabled
        self.rolloutPercentage = rolloutPercentage
        self.targetAudience = targetAudience
        self.experimentConfig = experimentConfig
        self.metadata = metadata
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

// MARK: - Target Audience

/// Defines the target audience for a feature flag
public struct TargetAudience: Codable {
    public var userSegments: [String]
    public var deviceTypes: [DeviceType]
    public var osVersions: [String]
    public var regions: [String]
    public var customCriteria: [String: AnyCodable]
    
    public enum DeviceType: String, Codable {
        case iPhone
        case iPad
        case mac
        case appleWatch
        case appleTV
        case visionPro
    }
}

// MARK: - Experiment Configuration

/// Configuration for A/B testing experiments
public struct ExperimentConfig: Codable {
    public let experimentId: String
    public let variants: [Variant]
    public let metrics: [String]
    public let startDate: Date
    public let endDate: Date?
    public var isActive: Bool
    
    public struct Variant: Codable {
        public let id: String
        public let name: String
        public let weight: Double
        public let configuration: [String: AnyCodable]
    }
}

// MARK: - Feature Flag Service

/// Main service for managing feature flags
@MainActor
public class FeatureFlagService: ObservableObject {
    public static let shared = FeatureFlagService()
    
    @Published public private(set) var flags: [String: FeatureFlag] = [:]
    @Published public private(set) var activeExperiments: [String: ExperimentConfig] = [:]
    @Published public private(set) var userVariants: [String: String] = [:] // experimentId: variantId
    @Published public private(set) var isInitialized = false
    
    private let remoteConfigService: RemoteConfigService
    private let analyticsService: AnalyticsService
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // Cache keys
    private let flagsCacheKey = "com.claudecode.featureflags.cache"
    private let experimentsCacheKey = "com.claudecode.experiments.cache"
    private let userVariantsCacheKey = "com.claudecode.userVariants.cache"
    
    private init() {
        self.remoteConfigService = RemoteConfigService()
        self.analyticsService = AnalyticsService.shared
        loadCachedFlags()
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Initialize feature flag service
    public func initialize() async {
        await fetchRemoteFlags()
        assignUserToExperiments()
        isInitialized = true
    }
    
    /// Check if a feature is enabled for the current user
    public func isEnabled(_ flagId: String) -> Bool {
        guard let flag = flags[flagId] else { return false }
        
        // Check if flag is globally enabled
        guard flag.isEnabled else { return false }
        
        // Check rollout percentage
        if flag.rolloutPercentage < 100 {
            let userHash = getUserHash(for: flagId)
            let threshold = Double(flag.rolloutPercentage) / 100.0
            if userHash > threshold { return false }
        }
        
        // Check target audience
        if let audience = flag.targetAudience {
            if !matchesAudience(audience) { return false }
        }
        
        // Check experiment status
        if let experiment = flag.experimentConfig, experiment.isActive {
            return userVariants[experiment.experimentId] != nil
        }
        
        return true
    }
    
    /// Get variant for an experiment
    public func getVariant(for experimentId: String) -> String? {
        return userVariants[experimentId]
    }
    
    /// Get configuration for a variant
    public func getVariantConfig(for experimentId: String) -> [String: AnyCodable]? {
        guard let variantId = userVariants[experimentId],
              let experiment = activeExperiments[experimentId],
              let variant = experiment.variants.first(where: { $0.id == variantId })
        else { return nil }
        
        return variant.configuration
    }
    
    /// Force refresh flags from remote
    public func refreshFlags() async {
        await fetchRemoteFlags()
        assignUserToExperiments()
    }
    
    /// Override a flag for testing
    public func overrideFlag(_ flagId: String, enabled: Bool) {
        guard var flag = flags[flagId] else { return }
        flag.isEnabled = enabled
        flags[flagId] = flag
        
        // Track override event
        analyticsService.track(event: "feature_flag_override", properties: [
            "flag_id": flagId,
            "enabled": enabled
        ])
    }
    
    /// Track feature usage
    public func trackFeatureUsage(_ flagId: String) {
        guard let flag = flags[flagId] else { return }
        
        analyticsService.track(event: "feature_used", properties: [
            "flag_id": flagId,
            "flag_name": flag.name,
            "experiment_id": flag.experimentConfig?.experimentId ?? "",
            "variant_id": userVariants[flag.experimentConfig?.experimentId ?? ""] ?? ""
        ])
    }
    
    /// Track experiment metric
    public func trackExperimentMetric(_ experimentId: String, metric: String, value: Any? = nil) {
        guard let experiment = activeExperiments[experimentId],
              let variantId = userVariants[experimentId] else { return }
        
        var properties: [String: Any] = [
            "experiment_id": experimentId,
            "variant_id": variantId,
            "metric": metric
        ]
        
        if let value = value {
            properties["value"] = value
        }
        
        analyticsService.track(event: "experiment_metric", properties: properties)
    }
    
    // MARK: - Private Methods
    
    private func loadCachedFlags() {
        // Load cached flags from UserDefaults
        if let data = userDefaults.data(forKey: flagsCacheKey),
           let cached = try? JSONDecoder().decode([String: FeatureFlag].self, from: data) {
            self.flags = cached
        }
        
        // Load cached experiments
        if let data = userDefaults.data(forKey: experimentsCacheKey),
           let cached = try? JSONDecoder().decode([String: ExperimentConfig].self, from: data) {
            self.activeExperiments = cached
        }
        
        // Load user variants
        if let cached = userDefaults.dictionary(forKey: userVariantsCacheKey) as? [String: String] {
            self.userVariants = cached
        }
    }
    
    private func fetchRemoteFlags() async {
        do {
            let remoteFlags = try await remoteConfigService.fetchFeatureFlags()
            
            // Update flags
            for flag in remoteFlags {
                flags[flag.id] = flag
                
                // Update experiments
                if let experiment = flag.experimentConfig, experiment.isActive {
                    activeExperiments[experiment.experimentId] = experiment
                }
            }
            
            // Cache flags
            if let data = try? JSONEncoder().encode(flags) {
                userDefaults.set(data, forKey: flagsCacheKey)
            }
            
            if let data = try? JSONEncoder().encode(activeExperiments) {
                userDefaults.set(data, forKey: experimentsCacheKey)
            }
            
        } catch {
            print("Failed to fetch remote flags: \(error)")
            // Continue with cached flags
        }
    }
    
    private func assignUserToExperiments() {
        let userId = getUserId()
        
        for (experimentId, experiment) in activeExperiments {
            // Skip if user already assigned
            if userVariants[experimentId] != nil { continue }
            
            // Skip if experiment is not active
            guard experiment.isActive else { continue }
            
            // Check date range
            let now = Date()
            if now < experiment.startDate { continue }
            if let endDate = experiment.endDate, now > endDate { continue }
            
            // Assign to variant based on weights
            let variantId = selectVariant(from: experiment.variants, userId: userId)
            userVariants[experimentId] = variantId
            
            // Track assignment
            analyticsService.track(event: "experiment_assigned", properties: [
                "experiment_id": experimentId,
                "variant_id": variantId
            ])
        }
        
        // Cache user variants
        userDefaults.set(userVariants, forKey: userVariantsCacheKey)
    }
    
    private func selectVariant(from variants: [ExperimentConfig.Variant], userId: String) -> String {
        let hash = getUserHash(for: userId)
        var cumulative = 0.0
        
        for variant in variants {
            cumulative += variant.weight
            if hash <= cumulative {
                return variant.id
            }
        }
        
        // Fallback to last variant
        return variants.last?.id ?? ""
    }
    
    private func getUserHash(for input: String) -> Double {
        let userId = getUserId()
        let combined = "\(userId)-\(input)"
        let hash = combined.hash
        return Double(abs(hash)) / Double(Int.max)
    }
    
    private func getUserId() -> String {
        if let userId = userDefaults.string(forKey: "userId") {
            return userId
        }
        
        let newUserId = UUID().uuidString
        userDefaults.set(newUserId, forKey: "userId")
        return newUserId
    }
    
    private func matchesAudience(_ audience: TargetAudience) -> Bool {
        // Check device type
        if !audience.deviceTypes.isEmpty {
            let currentDevice = getCurrentDeviceType()
            if !audience.deviceTypes.contains(currentDevice) {
                return false
            }
        }
        
        // Check OS version
        if !audience.osVersions.isEmpty {
            let currentVersion = UIDevice.current.systemVersion
            if !audience.osVersions.contains(where: { isVersionCompatible($0, current: currentVersion) }) {
                return false
            }
        }
        
        // Check region
        if !audience.regions.isEmpty {
            let currentRegion = Locale.current.region?.identifier ?? ""
            if !audience.regions.contains(currentRegion) {
                return false
            }
        }
        
        // Check user segments
        if !audience.userSegments.isEmpty {
            let userSegments = getUserSegments()
            if !audience.userSegments.contains(where: { userSegments.contains($0) }) {
                return false
            }
        }
        
        return true
    }
    
    private func getCurrentDeviceType() -> TargetAudience.DeviceType {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        }
        return .iPhone
    }
    
    private func isVersionCompatible(_ requirement: String, current: String) -> Bool {
        // Simple version comparison
        return current.compare(requirement, options: .numeric) != .orderedAscending
    }
    
    private func getUserSegments() -> Set<String> {
        // This would be determined by user properties, behavior, etc.
        var segments: Set<String> = []
        
        // Example segments
        if userDefaults.bool(forKey: "isPowerUser") {
            segments.insert("power_user")
        }
        
        if userDefaults.bool(forKey: "isNewUser") {
            segments.insert("new_user")
        }
        
        return segments
    }
    
    private func setupObservers() {
        // Refresh flags periodically
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.refreshFlags()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - SwiftUI Environment

private struct FeatureFlagEnvironmentKey: EnvironmentKey {
    static var defaultValue: FeatureFlagService {
        FeatureFlagService.shared
    }
}

public extension EnvironmentValues {
    var featureFlags: FeatureFlagService {
        get { self[FeatureFlagEnvironmentKey.self] }
        set { self[FeatureFlagEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Modifier

public struct FeatureFlagModifier: ViewModifier {
    let flagId: String
    let fallback: AnyView?
    @Environment(\.featureFlags) var featureFlags
    
    public func body(content: Content) -> some View {
        if featureFlags.isEnabled(flagId) {
            content
        } else {
            fallback ?? AnyView(EmptyView())
        }
    }
}

public extension View {
    /// Show view only if feature flag is enabled
    func featureFlag(_ flagId: String, fallback: AnyView? = nil) -> some View {
        modifier(FeatureFlagModifier(flagId: flagId, fallback: fallback))
    }
}