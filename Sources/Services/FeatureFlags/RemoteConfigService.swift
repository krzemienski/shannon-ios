//
//  RemoteConfigService.swift
//  ClaudeCode
//
//  Remote configuration management for feature flags and app settings
//

import Foundation
import Combine

/// Service for fetching and managing remote configuration
@MainActor
public class RemoteConfigService: ObservableObject {
    @Published public private(set) var configuration: RemoteConfiguration?
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastFetchTime: Date?
    @Published public private(set) var error: Error?
    
    private let apiClient: APIClient
    private let cacheManager: CacheManager
    private let cacheKey = "com.claudecode.remoteconfig"
    private let cacheExpiration: TimeInterval = 3600 // 1 hour
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        self.apiClient = DependencyContainer.shared.apiClient
        self.cacheManager = CacheManager()
        loadCachedConfiguration()
    }
    
    // MARK: - Public Methods
    
    /// Fetch feature flags from remote
    public func fetchFeatureFlags() async throws -> [FeatureFlag] {
        // Check cache first
        if let cached = getCachedFlags() {
            return cached
        }
        
        // Fetch from remote
        return try await fetchFromRemote()
    }
    
    /// Fetch complete remote configuration
    public func fetchConfiguration() async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // For now, use mock data - replace with actual API call
            let config = try await fetchMockConfiguration()
            configuration = config
            lastFetchTime = Date()
            
            // Cache configuration
            cacheConfiguration(config)
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Get value for a configuration key
    public func getValue(for key: String) -> Any? {
        return configuration?.values[key]
    }
    
    /// Get string value for a configuration key
    public func getString(for key: String, default defaultValue: String = "") -> String {
        return configuration?.values[key] as? String ?? defaultValue
    }
    
    /// Get boolean value for a configuration key
    public func getBool(for key: String, default defaultValue: Bool = false) -> Bool {
        return configuration?.values[key] as? Bool ?? defaultValue
    }
    
    /// Get integer value for a configuration key
    public func getInt(for key: String, default defaultValue: Int = 0) -> Int {
        return configuration?.values[key] as? Int ?? defaultValue
    }
    
    /// Force refresh configuration
    public func refresh() async {
        try? await fetchConfiguration()
    }
    
    // MARK: - Private Methods
    
    private func loadCachedConfiguration() {
        guard let cached = cacheManager.getObject(
            RemoteConfiguration.self,
            forKey: cacheKey
        ) else { return }
        
        // Check if cache is still valid
        if let fetchTime = cached.fetchTime,
           Date().timeIntervalSince(fetchTime) < cacheExpiration {
            configuration = cached
            lastFetchTime = fetchTime
        }
    }
    
    private func cacheConfiguration(_ config: RemoteConfiguration) {
        var configToCache = config
        configToCache.fetchTime = Date()
        cacheManager.setObject(configToCache, forKey: cacheKey)
    }
    
    private func getCachedFlags() -> [FeatureFlag]? {
        guard let config = configuration,
              let fetchTime = lastFetchTime,
              Date().timeIntervalSince(fetchTime) < cacheExpiration else {
            return nil
        }
        return config.featureFlags
    }
    
    private func fetchFromRemote() async throws -> [FeatureFlag] {
        // In production, this would make an actual API call
        // For now, return mock data
        let config = try await fetchMockConfiguration()
        configuration = config
        lastFetchTime = Date()
        cacheConfiguration(config)
        return config.featureFlags
    }
    
    private func fetchMockConfiguration() async throws -> RemoteConfiguration {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Return mock configuration
        return RemoteConfiguration(
            featureFlags: getMockFeatureFlags(),
            values: getMockConfigValues(),
            experiments: getMockExperiments()
        )
    }
    
    private func getMockFeatureFlags() -> [FeatureFlag] {
        return [
            FeatureFlag(
                id: "advanced_terminal",
                name: "Advanced Terminal Features",
                description: "Enable advanced terminal functionality",
                isEnabled: true,
                rolloutPercentage: 100
            ),
            FeatureFlag(
                id: "ai_suggestions",
                name: "AI Code Suggestions",
                description: "Show AI-powered code suggestions",
                isEnabled: true,
                rolloutPercentage: 80,
                targetAudience: TargetAudience(
                    userSegments: ["power_user"],
                    deviceTypes: [.iPhone, .iPad],
                    osVersions: ["17.0"],
                    regions: [],
                    customCriteria: [:]
                )
            ),
            FeatureFlag(
                id: "new_chat_ui",
                name: "New Chat Interface",
                description: "Redesigned chat interface with enhanced features",
                isEnabled: true,
                rolloutPercentage: 50,
                experimentConfig: ExperimentConfig(
                    experimentId: "chat_ui_redesign",
                    variants: [
                        ExperimentConfig.Variant(
                            id: "control",
                            name: "Current Design",
                            weight: 0.5,
                            configuration: ["layout": AnyCodable("classic")]
                        ),
                        ExperimentConfig.Variant(
                            id: "variant_a",
                            name: "New Design",
                            weight: 0.5,
                            configuration: ["layout": AnyCodable("modern")]
                        )
                    ],
                    metrics: ["engagement", "retention", "satisfaction"],
                    startDate: Date().addingTimeInterval(-86400 * 7), // 7 days ago
                    endDate: Date().addingTimeInterval(86400 * 30), // 30 days from now
                    isActive: true
                )
            ),
            FeatureFlag(
                id: "voice_input",
                name: "Voice Input",
                description: "Enable voice input for chat",
                isEnabled: true,
                rolloutPercentage: 30
            ),
            FeatureFlag(
                id: "collaborative_editing",
                name: "Collaborative Editing",
                description: "Real-time collaborative code editing",
                isEnabled: false,
                rolloutPercentage: 0
            ),
            FeatureFlag(
                id: "smart_tooltips",
                name: "Smart Tooltips",
                description: "Context-aware tooltips and help",
                isEnabled: true,
                rolloutPercentage: 100
            ),
            FeatureFlag(
                id: "performance_monitoring",
                name: "Enhanced Performance Monitoring",
                description: "Advanced performance metrics and monitoring",
                isEnabled: true,
                rolloutPercentage: 100
            ),
            FeatureFlag(
                id: "biometric_auth",
                name: "Biometric Authentication",
                description: "Face ID / Touch ID support",
                isEnabled: true,
                rolloutPercentage: 100
            )
        ]
    }
    
    private func getMockConfigValues() -> [String: Any] {
        return [
            "max_chat_history": 100,
            "sync_interval": 300,
            "enable_analytics": true,
            "api_timeout": 30,
            "max_file_size": 10485760, // 10MB
            "supported_languages": ["swift", "python", "javascript", "typescript"],
            "theme_options": ["dark", "light", "auto"],
            "onboarding_version": "2.0",
            "help_center_url": "https://help.claudecode.com",
            "feedback_email": "feedback@claudecode.com",
            "minimum_os_version": "17.0"
        ]
    }
    
    private func getMockExperiments() -> [String: Any] {
        return [
            "chat_ui_redesign": [
                "status": "active",
                "start_date": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 7)),
                "variants": ["control", "variant_a"]
            ],
            "onboarding_flow": [
                "status": "completed",
                "winner": "variant_b"
            ]
        ]
    }
}

// MARK: - Remote Configuration Model

public struct RemoteConfiguration: Codable {
    public let featureFlags: [FeatureFlag]
    public let values: [String: Any]
    public let experiments: [String: Any]
    public var fetchTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case featureFlags
        case values
        case experiments
        case fetchTime
    }
    
    public init(
        featureFlags: [FeatureFlag],
        values: [String: Any],
        experiments: [String: Any],
        fetchTime: Date? = nil
    ) {
        self.featureFlags = featureFlags
        self.values = values
        self.experiments = experiments
        self.fetchTime = fetchTime
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        featureFlags = try container.decode([FeatureFlag].self, forKey: .featureFlags)
        values = try container.decode([String: AnyCodable].self, forKey: .values)
            .mapValues { $0.value }
        experiments = try container.decode([String: AnyCodable].self, forKey: .experiments)
            .mapValues { $0.value }
        fetchTime = try container.decodeIfPresent(Date.self, forKey: .fetchTime)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(featureFlags, forKey: .featureFlags)
        try container.encode(values.mapValues { AnyCodable($0) }, forKey: .values)
        try container.encode(experiments.mapValues { AnyCodable($0) }, forKey: .experiments)
        try container.encodeIfPresent(fetchTime, forKey: .fetchTime)
    }
}

// MARK: - Cache Manager

private class CacheManager {
    private let userDefaults = UserDefaults.standard
    
    func setObject<T: Codable>(_ object: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(object) else { return }
        userDefaults.set(data, forKey: key)
    }
    
    func getObject<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    func removeObject(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
}