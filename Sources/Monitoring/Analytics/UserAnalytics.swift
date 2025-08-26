//
//  UserAnalytics.swift
//  ClaudeCode
//
//  Comprehensive user analytics with behavior tracking and funnel analysis
//

import Foundation
import UIKit
import StoreKit
import AdSupport
import AppTrackingTransparency
import os.log
import Combine

// MARK: - User Analytics Manager

public final class UserAnalyticsManager {
    
    // MARK: - Singleton
    
    public static let shared = UserAnalyticsManager()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.analytics", category: "UserAnalytics")
    private let queue = DispatchQueue(label: "com.claudecode.analytics.user", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    
    // User tracking
    private var userId: String?
    private var anonymousId: String
    private var userProperties: [String: Any] = [:]
    private var sessionId: String?
    private var sessionStartTime: Date?
    
    // Analytics data
    private let behaviorTracker = UserBehaviorTracker()
    private let funnelAnalyzer = ConversionFunnelAnalyzer()
    private let featureAdoptionTracker = FeatureAdoptionTracker()
    private let cohortAnalyzer = CohortAnalyzer()
    private let retentionTracker = RetentionTracker()
    
    // Event storage
    private var eventQueue: [AnalyticsEvent] = []
    private let maxQueueSize = 500
    
    // Configuration
    private var config = AnalyticsConfiguration.default
    
    // Providers
    private var providers: [AnalyticsProvider] = []
    
    // MARK: - Initialization
    
    private init() {
        self.anonymousId = getOrCreateAnonymousId()
        setupProviders()
        setupNotifications()
        requestTrackingAuthorization()
    }
    
    // MARK: - Configuration
    
    public func configure(with configuration: AnalyticsConfiguration = .default) {
        self.config = configuration
        
        providers.forEach { provider in
            provider.configure(with: configuration)
        }
        
        logger.info("User analytics configured")
    }
    
    // MARK: - User Identification
    
    public func identify(userId: String, properties: [String: Any] = [:]) {
        self.userId = userId
        
        // Merge properties
        userProperties.merge(properties) { _, new in new }
        
        // Update user profile
        updateUserProfile()
        
        // Send to providers
        providers.forEach { provider in
            provider.identify(userId: userId, properties: userProperties)
        }
        
        // Track identification event
        trackEvent(AnalyticsEvent(
            name: "user_identified",
            category: .user,
            properties: ["user_id": userId]
        ))
        
        logger.info("User identified: \(userId)")
    }
    
    public func setUserProperty(key: String, value: Any) {
        queue.async(flags: .barrier) {
            self.userProperties[key] = value
        }
        
        providers.forEach { provider in
            provider.setUserProperty(key: key, value: value)
        }
    }
    
    public func incrementUserProperty(key: String, by amount: Double = 1.0) {
        queue.async(flags: .barrier) {
            if let current = self.userProperties[key] as? Double {
                self.userProperties[key] = current + amount
            } else {
                self.userProperties[key] = amount
            }
        }
        
        providers.forEach { provider in
            provider.incrementUserProperty(key: key, by: amount)
        }
    }
    
    // MARK: - Session Management
    
    public func startSession() {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        
        let sessionProperties: [String: Any] = [
            "session_id": sessionId ?? "",
            "start_time": sessionStartTime?.timeIntervalSince1970 ?? 0,
            "device_model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "screen_size": "\(UIScreen.main.bounds.width)x\(UIScreen.main.bounds.height)"
        ]
        
        trackEvent(AnalyticsEvent(
            name: "session_start",
            category: .session,
            properties: sessionProperties
        ))
        
        // Update retention data
        retentionTracker.recordSession(userId: userId ?? anonymousId)
        
        logger.info("Analytics session started: \(sessionId ?? "")")
    }
    
    public func endSession() {
        guard let sessionId = sessionId,
              let startTime = sessionStartTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        
        trackEvent(AnalyticsEvent(
            name: "session_end",
            category: .session,
            properties: [
                "session_id": sessionId,
                "duration": duration,
                "events_count": behaviorTracker.getSessionEventCount()
            ]
        ))
        
        self.sessionId = nil
        self.sessionStartTime = nil
        
        logger.info("Analytics session ended after \(duration) seconds")
    }
    
    // MARK: - Event Tracking
    
    public func trackEvent(_ event: AnalyticsEvent) {
        // Add metadata
        var enrichedEvent = event
        enrichedEvent.userId = userId
        enrichedEvent.anonymousId = anonymousId
        enrichedEvent.sessionId = sessionId
        enrichedEvent.timestamp = Date()
        
        // Process through components
        behaviorTracker.trackBehavior(enrichedEvent)
        funnelAnalyzer.processEvent(enrichedEvent)
        featureAdoptionTracker.trackFeatureUsage(enrichedEvent)
        cohortAnalyzer.processEvent(enrichedEvent)
        
        // Queue event
        queue.async(flags: .barrier) {
            self.eventQueue.append(enrichedEvent)
            if self.eventQueue.count >= self.config.batchSize {
                self.flushEvents()
            }
        }
        
        // Send to providers
        providers.forEach { provider in
            provider.trackEvent(enrichedEvent)
        }
        
        logger.debug("Event tracked: \(event.name)")
    }
    
    public func trackScreenView(screenName: String, properties: [String: Any] = [:]) {
        var props = properties
        props["screen_name"] = screenName
        
        trackEvent(AnalyticsEvent(
            name: "screen_view",
            category: .navigation,
            properties: props
        ))
        
        behaviorTracker.trackScreenView(screenName)
    }
    
    public func trackUserAction(action: String, target: String? = nil, value: Any? = nil) {
        var properties: [String: Any] = ["action": action]
        if let target = target {
            properties["target"] = target
        }
        if let value = value {
            properties["value"] = value
        }
        
        trackEvent(AnalyticsEvent(
            name: "user_action",
            category: .interaction,
            properties: properties
        ))
    }
    
    // MARK: - Conversion Funnels
    
    public func defineFunnel(_ funnel: ConversionFunnel) {
        funnelAnalyzer.defineFunnel(funnel)
    }
    
    public func trackFunnelStep(funnelName: String, step: String, properties: [String: Any] = [:]) {
        funnelAnalyzer.trackStep(funnelName: funnelName, step: step, properties: properties)
        
        trackEvent(AnalyticsEvent(
            name: "funnel_step",
            category: .conversion,
            properties: [
                "funnel": funnelName,
                "step": step
            ].merging(properties) { _, new in new }
        ))
    }
    
    public func getFunnelConversion(funnelName: String) -> FunnelConversionReport? {
        return funnelAnalyzer.getConversionReport(for: funnelName)
    }
    
    // MARK: - Feature Adoption
    
    public func trackFeatureUsage(featureName: String, properties: [String: Any] = [:]) {
        featureAdoptionTracker.trackUsage(featureName: featureName, userId: userId ?? anonymousId)
        
        trackEvent(AnalyticsEvent(
            name: "feature_used",
            category: .feature,
            properties: [
                "feature": featureName
            ].merging(properties) { _, new in new }
        ))
    }
    
    public func getFeatureAdoptionMetrics() -> FeatureAdoptionMetrics {
        return featureAdoptionTracker.getMetrics()
    }
    
    // MARK: - Cohort Analysis
    
    public func assignUserToCohort(_ cohort: String) {
        cohortAnalyzer.assignUser(userId ?? anonymousId, to: cohort)
        setUserProperty(key: "cohort", value: cohort)
    }
    
    public func getCohortMetrics(cohortName: String) -> CohortMetrics? {
        return cohortAnalyzer.getMetrics(for: cohortName)
    }
    
    // MARK: - Retention Tracking
    
    public func getRetentionMetrics(days: Int = 30) -> RetentionMetrics {
        return retentionTracker.getMetrics(for: days)
    }
    
    // MARK: - Revenue Tracking
    
    public func trackRevenue(amount: Double, currency: String = "USD", properties: [String: Any] = [:]) {
        var props = properties
        props["amount"] = amount
        props["currency"] = currency
        
        trackEvent(AnalyticsEvent(
            name: "revenue",
            category: .revenue,
            properties: props
        ))
    }
    
    public func trackPurchase(productId: String, price: Double, currency: String = "USD", quantity: Int = 1) {
        trackEvent(AnalyticsEvent(
            name: "purchase",
            category: .revenue,
            properties: [
                "product_id": productId,
                "price": price,
                "currency": currency,
                "quantity": quantity,
                "total": price * Double(quantity)
            ]
        ))
    }
    
    // MARK: - A/B Testing
    
    public func getExperimentVariant(experimentName: String) -> String {
        // Simple hash-based assignment
        let hash = (userId ?? anonymousId).hashValue
        let variants = ["control", "variant_a", "variant_b"]
        let index = abs(hash) % variants.count
        let variant = variants[index]
        
        trackEvent(AnalyticsEvent(
            name: "experiment_viewed",
            category: .experiment,
            properties: [
                "experiment": experimentName,
                "variant": variant
            ]
        ))
        
        return variant
    }
    
    // MARK: - Private Methods
    
    private func setupProviders() {
        // Initialize analytics providers
        // These would be actual implementations
        // providers = [
        //     MixpanelProvider(),
        //     AmplitudeProvider(),
        //     FirebaseAnalyticsProvider(),
        //     CustomAnalyticsProvider()
        // ]
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.startSession()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.endSession()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.flush()
            }
            .store(in: &cancellables)
    }
    
    private func requestTrackingAuthorization() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                self.logger.info("Tracking authorization status: \(status.rawValue)")
                
                if status == .authorized {
                    self.enableAdvertiserTracking()
                }
            }
        }
    }
    
    private func enableAdvertiserTracking() {
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        setUserProperty(key: "idfa", value: idfa)
    }
    
    private func getOrCreateAnonymousId() -> String {
        if let savedId = UserDefaults.standard.string(forKey: "analytics_anonymous_id") {
            return savedId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "analytics_anonymous_id")
            return newId
        }
    }
    
    private func updateUserProfile() {
        // Collect device and app information
        let deviceInfo: [String: Any] = [
            "device_model": UIDevice.current.model,
            "device_name": UIDevice.current.name,
            "os_version": UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "app_build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            "language": Locale.current.languageCode ?? "unknown",
            "timezone": TimeZone.current.identifier,
            "screen_size": "\(UIScreen.main.bounds.width)x\(UIScreen.main.bounds.height)",
            "screen_scale": UIScreen.main.scale
        ]
        
        deviceInfo.forEach { key, value in
            setUserProperty(key: key, value: value)
        }
    }
    
    private func flushEvents() {
        guard !eventQueue.isEmpty else { return }
        
        let eventsToSend = eventQueue
        eventQueue.removeAll()
        
        providers.forEach { provider in
            provider.flush(events: eventsToSend)
        }
        
        logger.info("Flushed \(eventsToSend.count) analytics events")
    }
    
    // MARK: - Public Methods
    
    public func flush() {
        queue.async(flags: .barrier) {
            self.flushEvents()
        }
        
        providers.forEach { $0.flush(events: []) }
    }
    
    public func reset() {
        userId = nil
        anonymousId = UUID().uuidString
        UserDefaults.standard.set(anonymousId, forKey: "analytics_anonymous_id")
        userProperties.removeAll()
        sessionId = nil
        sessionStartTime = nil
        eventQueue.removeAll()
        
        providers.forEach { $0.reset() }
        
        logger.info("Analytics reset")
    }
}

// MARK: - Supporting Types

public struct AnalyticsEvent {
    let name: String
    let category: EventCategory
    var properties: [String: Any]
    var userId: String?
    var anonymousId: String?
    var sessionId: String?
    var timestamp: Date?
    
    public init(name: String, category: EventCategory, properties: [String: Any] = [:]) {
        self.name = name
        self.category = category
        self.properties = properties
    }
    
    public enum EventCategory {
        case user
        case session
        case navigation
        case interaction
        case feature
        case conversion
        case revenue
        case experiment
        case custom
    }
}

public struct ConversionFunnel {
    let name: String
    let steps: [String]
    let goalStep: String
    let timeout: TimeInterval // Max time between steps
    
    public init(name: String, steps: [String], goalStep: String, timeout: TimeInterval = 3600) {
        self.name = name
        self.steps = steps
        self.goalStep = goalStep
        self.timeout = timeout
    }
}

public struct FunnelConversionReport {
    let funnelName: String
    let totalUsers: Int
    let stepConversions: [StepConversion]
    let overallConversionRate: Double
    let averageTimeToConvert: TimeInterval
    
    public struct StepConversion {
        let step: String
        let users: Int
        let conversionRate: Double
        let dropoffRate: Double
        let averageTime: TimeInterval
    }
}

public struct FeatureAdoptionMetrics {
    let totalFeatures: Int
    let adoptedFeatures: Int
    let adoptionRate: Double
    let featureUsage: [String: FeatureUsage]
    
    public struct FeatureUsage {
        let name: String
        let totalUsers: Int
        let dailyActiveUsers: Int
        let weeklyActiveUsers: Int
        let monthlyActiveUsers: Int
        let averageUsagePerUser: Double
        let firstUsedDate: Date
        let lastUsedDate: Date
    }
}

public struct CohortMetrics {
    let cohortName: String
    let userCount: Int
    let activeUsers: Int
    let retentionRate: Double
    let averageSessionLength: TimeInterval
    let averageEventsPerSession: Int
    let topEvents: [(String, Int)]
}

public struct RetentionMetrics {
    let period: Int // Days
    let cohorts: [DailyCohort]
    let overallRetention: [Int: Double] // Day: Retention rate
    
    public struct DailyCohort {
        let date: Date
        let initialUsers: Int
        let retainedUsers: [Int: Int] // Day: User count
    }
}

public struct AnalyticsConfiguration {
    let isEnabled: Bool
    let environment: String
    let apiKey: String?
    let endpoint: URL?
    let batchSize: Int
    let flushInterval: TimeInterval
    let sessionTimeout: TimeInterval
    let trackingEnabled: Bool
    let debugMode: Bool
    
    public static let `default` = AnalyticsConfiguration(
        isEnabled: true,
        environment: "development",
        apiKey: nil,
        endpoint: nil,
        batchSize: 50,
        flushInterval: 60,
        sessionTimeout: 30 * 60,
        trackingEnabled: true,
        debugMode: true
    )
}

// MARK: - Analytics Provider Protocol

public protocol AnalyticsProvider {
    func configure(with config: AnalyticsConfiguration)
    func identify(userId: String, properties: [String: Any])
    func setUserProperty(key: String, value: Any)
    func incrementUserProperty(key: String, by amount: Double)
    func trackEvent(_ event: AnalyticsEvent)
    func flush(events: [AnalyticsEvent])
    func reset()
}