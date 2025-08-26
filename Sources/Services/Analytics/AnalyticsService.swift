//
//  AnalyticsService.swift
//  ClaudeCode
//
//  Analytics service for tracking user behavior, events, and experiments
//

import Foundation
import Combine
import SwiftUI

// MARK: - Analytics Event

public struct AnalyticsEvent {
    public let name: String
    public let properties: [String: Any]
    public let timestamp: Date
    public let userId: String
    public let sessionId: String
    
    public init(
        name: String,
        properties: [String: Any] = [:],
        timestamp: Date = Date(),
        userId: String,
        sessionId: String
    ) {
        self.name = name
        self.properties = properties
        self.timestamp = timestamp
        self.userId = userId
        self.sessionId = sessionId
    }
}

// MARK: - User Properties

public struct UserProperties {
    public var userId: String
    public var deviceId: String
    public var platform: String
    public var osVersion: String
    public var appVersion: String
    public var buildNumber: String
    public var deviceModel: String
    public var locale: String
    public var timezone: String
    public var isPowerUser: Bool
    public var isNewUser: Bool
    public var customProperties: [String: Any]
    
    public init() {
        self.userId = UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        self.platform = "iOS"
        self.osVersion = UIDevice.current.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        self.deviceModel = UIDevice.current.model
        self.locale = Locale.current.identifier
        self.timezone = TimeZone.current.identifier
        self.isPowerUser = false
        self.isNewUser = true
        self.customProperties = [:]
    }
}

// MARK: - Analytics Service

@MainActor
public class AnalyticsService: ObservableObject {
    public static let shared = AnalyticsService()
    
    @Published public private(set) var userProperties = UserProperties()
    @Published public private(set) var sessionId = UUID().uuidString
    @Published public private(set) var sessionStartTime = Date()
    @Published public private(set) var eventsQueue: [AnalyticsEvent] = []
    @Published public private(set) var isEnabled = true
    
    private let maxQueueSize = 100
    private let batchSize = 50
    private let flushInterval: TimeInterval = 30
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let eventQueueKey = "com.claudecode.analytics.queue"
    
    private init() {
        loadUserProperties()
        loadQueuedEvents()
        setupFlushTimer()
        setupSessionTracking()
    }
    
    // MARK: - Public Methods
    
    /// Track an event
    public func track(event: String, properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        
        let analyticsEvent = AnalyticsEvent(
            name: event,
            properties: enrichProperties(properties),
            timestamp: Date(),
            userId: userProperties.userId,
            sessionId: sessionId
        )
        
        addToQueue(analyticsEvent)
        
        // Flush if queue is full
        if eventsQueue.count >= maxQueueSize {
            Task {
                await flush()
            }
        }
    }
    
    /// Track screen view
    public func trackScreen(_ screenName: String, properties: [String: Any] = [:]) {
        var enrichedProps = properties
        enrichedProps["screen_name"] = screenName
        track(event: "screen_view", properties: enrichedProps)
    }
    
    /// Track user action
    public func trackAction(_ action: String, target: String, properties: [String: Any] = [:]) {
        var enrichedProps = properties
        enrichedProps["action"] = action
        enrichedProps["target"] = target
        track(event: "user_action", properties: enrichedProps)
    }
    
    /// Track timing
    public func trackTiming(_ category: String, value: TimeInterval, properties: [String: Any] = [:]) {
        var enrichedProps = properties
        enrichedProps["category"] = category
        enrichedProps["value"] = value
        track(event: "timing", properties: enrichedProps)
    }
    
    /// Track error
    public func trackError(_ error: Error, properties: [String: Any] = [:]) {
        var enrichedProps = properties
        enrichedProps["error_message"] = error.localizedDescription
        enrichedProps["error_type"] = String(describing: type(of: error))
        track(event: "error", properties: enrichedProps)
    }
    
    /// Set user property
    public func setUserProperty(_ key: String, value: Any) {
        userProperties.customProperties[key] = value
        saveUserProperties()
    }
    
    /// Set multiple user properties
    public func setUserProperties(_ properties: [String: Any]) {
        for (key, value) in properties {
            userProperties.customProperties[key] = value
        }
        saveUserProperties()
    }
    
    /// Identify user
    public func identify(userId: String, properties: [String: Any] = [:]) {
        userProperties.userId = userId
        userDefaults.set(userId, forKey: "userId")
        
        for (key, value) in properties {
            userProperties.customProperties[key] = value
        }
        
        saveUserProperties()
        track(event: "identify", properties: properties)
    }
    
    /// Start new session
    public func startNewSession() {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        track(event: "session_start")
    }
    
    /// End session
    public func endSession() {
        let duration = Date().timeIntervalSince(sessionStartTime)
        track(event: "session_end", properties: ["duration": duration])
    }
    
    /// Flush events queue
    public func flush() async {
        guard !eventsQueue.isEmpty else { return }
        
        let eventsToSend = Array(eventsQueue.prefix(batchSize))
        
        do {
            try await sendEvents(eventsToSend)
            
            // Remove sent events from queue
            eventsQueue.removeFirst(min(batchSize, eventsQueue.count))
            saveQueuedEvents()
            
        } catch {
            print("Failed to send analytics events: \(error)")
        }
    }
    
    /// Enable/disable analytics
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        userDefaults.set(enabled, forKey: "analyticsEnabled")
        
        if enabled {
            track(event: "analytics_enabled")
        }
    }
    
    /// Reset analytics
    public func reset() {
        eventsQueue.removeAll()
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        userProperties = UserProperties()
        saveUserProperties()
        saveQueuedEvents()
    }
    
    // MARK: - Private Methods
    
    private func enrichProperties(_ properties: [String: Any]) -> [String: Any] {
        var enriched = properties
        
        // Add session info
        enriched["session_id"] = sessionId
        enriched["session_duration"] = Date().timeIntervalSince(sessionStartTime)
        
        // Add device info
        enriched["platform"] = userProperties.platform
        enriched["os_version"] = userProperties.osVersion
        enriched["app_version"] = userProperties.appVersion
        enriched["device_model"] = userProperties.deviceModel
        
        // Add user segments
        enriched["is_power_user"] = userProperties.isPowerUser
        enriched["is_new_user"] = userProperties.isNewUser
        
        // Add timestamp
        enriched["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        return enriched
    }
    
    private func addToQueue(_ event: AnalyticsEvent) {
        eventsQueue.append(event)
        
        // Maintain max queue size
        if eventsQueue.count > maxQueueSize {
            eventsQueue.removeFirst()
        }
        
        saveQueuedEvents()
    }
    
    private func sendEvents(_ events: [AnalyticsEvent]) async throws {
        // In production, this would send events to your analytics backend
        // For now, just log them
        print("📊 Sending \(events.count) analytics events")
        
        for event in events {
            print("  - \(event.name): \(event.properties)")
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    private func loadUserProperties() {
        if let userId = userDefaults.string(forKey: "userId") {
            userProperties.userId = userId
        } else {
            userDefaults.set(userProperties.userId, forKey: "userId")
        }
        
        userProperties.isPowerUser = userDefaults.bool(forKey: "isPowerUser")
        userProperties.isNewUser = userDefaults.bool(forKey: "isNewUser")
        
        if let customProps = userDefaults.dictionary(forKey: "userCustomProperties") {
            userProperties.customProperties = customProps
        }
    }
    
    private func saveUserProperties() {
        userDefaults.set(userProperties.isPowerUser, forKey: "isPowerUser")
        userDefaults.set(userProperties.isNewUser, forKey: "isNewUser")
        userDefaults.set(userProperties.customProperties, forKey: "userCustomProperties")
    }
    
    private func loadQueuedEvents() {
        // For simplicity, we're not persisting the full event queue
        // In production, you'd want to persist and restore events
    }
    
    private func saveQueuedEvents() {
        // For simplicity, we're not persisting the full event queue
        // In production, you'd want to persist events to handle app termination
    }
    
    private func setupFlushTimer() {
        Timer.publish(every: flushInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.flush()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSessionTracking() {
        // Track app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.track(event: "app_active")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.track(event: "app_inactive")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.track(event: "app_background")
                Task {
                    await self?.flush()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.track(event: "app_foreground")
                self?.startNewSession()
            }
            .store(in: &cancellables)
    }
}

// MARK: - View Modifier for Screen Tracking

public struct ScreenTrackingModifier: ViewModifier {
    let screenName: String
    @Environment(\.scenePhase) private var scenePhase
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                AnalyticsService.shared.trackScreen(screenName)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    AnalyticsService.shared.trackScreen(screenName)
                }
            }
    }
}

public extension View {
    /// Track screen views automatically
    func trackScreen(_ screenName: String) -> some View {
        modifier(ScreenTrackingModifier(screenName: screenName))
    }
}