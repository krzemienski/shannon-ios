// Sources/Core/Telemetry/TelemetryConfiguration.swift
// Task: Telemetry Configuration System Implementation
// This file defines telemetry configuration and settings

import Foundation

/// Telemetry configuration settings
public struct TelemetryConfiguration: Codable, Sendable {
    
    // MARK: - General Settings
    
    /// Whether telemetry is enabled
    public var isEnabled: Bool
    
    /// Whether to collect telemetry in debug mode
    public var collectInDebug: Bool
    
    /// Maximum number of events to store locally
    public var maxLocalEvents: Int
    
    /// Maximum age of events before they are purged (in seconds)
    public var maxEventAge: TimeInterval
    
    /// Batch size for uploading events
    public var uploadBatchSize: Int
    
    /// Upload interval (in seconds)
    public var uploadInterval: TimeInterval
    
    /// Whether to upload only on WiFi
    public var wifiOnlyUpload: Bool
    
    // MARK: - Performance Settings
    
    /// Whether to collect performance metrics
    public var collectPerformanceMetrics: Bool
    
    /// Performance sampling rate (0.0 to 1.0)
    public var performanceSamplingRate: Double
    
    /// Minimum duration for performance events (in milliseconds)
    public var minPerformanceDuration: Double
    
    // MARK: - Error Settings
    
    /// Whether to collect error events
    public var collectErrors: Bool
    
    /// Error severity threshold
    public var errorSeverityThreshold: ErrorEvent.ErrorSeverity
    
    /// Whether to collect stack traces
    public var collectStackTraces: Bool
    
    // MARK: - User Action Settings
    
    /// Whether to collect user actions
    public var collectUserActions: Bool
    
    /// User action sampling rate (0.0 to 1.0)
    public var userActionSamplingRate: Double
    
    /// List of actions to exclude from tracking
    public var excludedActions: Set<String>
    
    // MARK: - SSH Settings
    
    /// Whether to collect SSH connection metrics
    public var collectSSHMetrics: Bool
    
    /// SSH event sampling rate
    public var sshSamplingRate: Double
    
    // MARK: - Privacy Settings
    
    /// Whether to anonymize user identifiers
    public var anonymizeUserIds: Bool
    
    /// Whether to redact sensitive information
    public var redactSensitiveInfo: Bool
    
    /// List of metadata keys to exclude
    public var excludedMetadataKeys: Set<String>
    
    // MARK: - Export Settings
    
    /// Export destinations
    public var exportDestinations: [ExportDestination]
    
    /// Whether to compress exported data
    public var compressExports: Bool
    
    /// Export format
    public var exportFormat: ExportFormat
    
    // MARK: - Initialization
    
    public init(
        isEnabled: Bool = true,
        collectInDebug: Bool = true,
        maxLocalEvents: Int = 10000,
        maxEventAge: TimeInterval = 7 * 24 * 60 * 60, // 7 days
        uploadBatchSize: Int = 100,
        uploadInterval: TimeInterval = 300, // 5 minutes
        wifiOnlyUpload: Bool = false,
        collectPerformanceMetrics: Bool = true,
        performanceSamplingRate: Double = 1.0,
        minPerformanceDuration: Double = 10.0,
        collectErrors: Bool = true,
        errorSeverityThreshold: ErrorEvent.ErrorSeverity = .debug,
        collectStackTraces: Bool = true,
        collectUserActions: Bool = true,
        userActionSamplingRate: Double = 1.0,
        excludedActions: Set<String> = [],
        collectSSHMetrics: Bool = true,
        sshSamplingRate: Double = 1.0,
        anonymizeUserIds: Bool = true,
        redactSensitiveInfo: Bool = true,
        excludedMetadataKeys: Set<String> = ["password", "token", "key", "secret"],
        exportDestinations: [ExportDestination] = [],
        compressExports: Bool = true,
        exportFormat: ExportFormat = .json
    ) {
        self.isEnabled = isEnabled
        self.collectInDebug = collectInDebug
        self.maxLocalEvents = maxLocalEvents
        self.maxEventAge = maxEventAge
        self.uploadBatchSize = uploadBatchSize
        self.uploadInterval = uploadInterval
        self.wifiOnlyUpload = wifiOnlyUpload
        self.collectPerformanceMetrics = collectPerformanceMetrics
        self.performanceSamplingRate = performanceSamplingRate
        self.minPerformanceDuration = minPerformanceDuration
        self.collectErrors = collectErrors
        self.errorSeverityThreshold = errorSeverityThreshold
        self.collectStackTraces = collectStackTraces
        self.collectUserActions = collectUserActions
        self.userActionSamplingRate = userActionSamplingRate
        self.excludedActions = excludedActions
        self.collectSSHMetrics = collectSSHMetrics
        self.sshSamplingRate = sshSamplingRate
        self.anonymizeUserIds = anonymizeUserIds
        self.redactSensitiveInfo = redactSensitiveInfo
        self.excludedMetadataKeys = excludedMetadataKeys
        self.exportDestinations = exportDestinations
        self.compressExports = compressExports
        self.exportFormat = exportFormat
    }
    
    /// Default configuration for development
    public static var development: TelemetryConfiguration {
        TelemetryConfiguration(
            isEnabled: true,
            collectInDebug: true,
            performanceSamplingRate: 1.0,
            userActionSamplingRate: 1.0,
            sshSamplingRate: 1.0,
            anonymizeUserIds: false,
            redactSensitiveInfo: false
        )
    }
    
    /// Default configuration for production
    public static var production: TelemetryConfiguration {
        TelemetryConfiguration(
            isEnabled: true,
            collectInDebug: false,
            performanceSamplingRate: 0.1,
            userActionSamplingRate: 0.5,
            sshSamplingRate: 0.2,
            anonymizeUserIds: true,
            redactSensitiveInfo: true,
            wifiOnlyUpload: true
        )
    }
    
    /// Minimal configuration (for testing)
    public static var minimal: TelemetryConfiguration {
        TelemetryConfiguration(
            isEnabled: true,
            collectInDebug: false,
            maxLocalEvents: 100,
            collectPerformanceMetrics: false,
            collectErrors: true,
            errorSeverityThreshold: .error,
            collectUserActions: false,
            collectSSHMetrics: false
        )
    }
}

// MARK: - Export Configuration

/// Export destination types
public enum ExportDestination: String, Codable, Sendable {
    case console = "console"
    case file = "file"
    case cloudWatch = "cloudwatch"
    case applicationInsights = "app_insights"
    case customEndpoint = "custom"
    case localStorage = "local_storage"
}

// ExportFormat is now imported from MonitoringModels.swift

// MARK: - Performance Thresholds

/// Performance metric thresholds
public struct PerformanceThresholds: Codable, Sendable {
    /// App launch time threshold (in seconds)
    public var appLaunchTime: Double
    
    /// View load time threshold (in seconds)
    public var viewLoadTime: Double
    
    /// API response time threshold (in seconds)
    public var apiResponseTime: Double
    
    /// SSH connection time threshold (in seconds)
    public var sshConnectionTime: Double
    
    /// Memory usage threshold (in MB)
    public var memoryUsage: Double
    
    /// CPU usage threshold (percentage)
    public var cpuUsage: Double
    
    /// Disk usage threshold (in MB)
    public var diskUsage: Double
    
    /// Battery drain threshold (percentage per hour)
    public var batteryDrain: Double
    
    public init(
        appLaunchTime: Double = 3.0,
        viewLoadTime: Double = 1.0,
        apiResponseTime: Double = 2.0,
        sshConnectionTime: Double = 5.0,
        memoryUsage: Double = 500.0,
        cpuUsage: Double = 80.0,
        diskUsage: Double = 100.0,
        batteryDrain: Double = 10.0
    ) {
        self.appLaunchTime = appLaunchTime
        self.viewLoadTime = viewLoadTime
        self.apiResponseTime = apiResponseTime
        self.sshConnectionTime = sshConnectionTime
        self.memoryUsage = memoryUsage
        self.cpuUsage = cpuUsage
        self.diskUsage = diskUsage
        self.batteryDrain = batteryDrain
    }
}

// MARK: - Telemetry Policy

/// Telemetry collection policy
public struct TelemetryPolicy: Codable, Sendable {
    /// Data retention period (in days)
    public var retentionDays: Int
    
    /// Whether user consent is required
    public var requiresUserConsent: Bool
    
    /// GDPR compliance enabled
    public var gdprCompliant: Bool
    
    /// CCPA compliance enabled
    public var ccpaCompliant: Bool
    
    /// List of countries where telemetry is disabled
    public var disabledCountries: Set<String>
    
    /// Minimum age requirement
    public var minimumAge: Int?
    
    public init(
        retentionDays: Int = 30,
        requiresUserConsent: Bool = false,
        gdprCompliant: Bool = true,
        ccpaCompliant: Bool = true,
        disabledCountries: Set<String> = [],
        minimumAge: Int? = nil
    ) {
        self.retentionDays = retentionDays
        self.requiresUserConsent = requiresUserConsent
        self.gdprCompliant = gdprCompliant
        self.ccpaCompliant = ccpaCompliant
        self.disabledCountries = disabledCountries
        self.minimumAge = minimumAge
    }
}

// MARK: - Configuration Manager

/// Manages telemetry configuration
public final class TelemetryConfigurationManager: @unchecked Sendable {
    
    /// Shared instance
    public static let shared = TelemetryConfigurationManager()
    
    /// Current configuration
    private var _configuration: TelemetryConfiguration
    private let configurationQueue = DispatchQueue(label: "com.claudecode.telemetry.config", attributes: .concurrent)
    
    /// Performance thresholds
    private var _thresholds: PerformanceThresholds
    
    /// Telemetry policy
    private var _policy: TelemetryPolicy
    
    /// Configuration change observers
    private var observers: [(TelemetryConfiguration) -> Void] = []
    
    public var configuration: TelemetryConfiguration {
        get {
            configurationQueue.sync { _configuration }
        }
        set {
            configurationQueue.async(flags: .barrier) { [weak self] in
                self?._configuration = newValue
                self?.notifyObservers(newValue)
                self?.persistConfiguration()
            }
        }
    }
    
    public var thresholds: PerformanceThresholds {
        get {
            configurationQueue.sync { _thresholds }
        }
        set {
            configurationQueue.async(flags: .barrier) { [weak self] in
                self?._thresholds = newValue
                self?.persistThresholds()
            }
        }
    }
    
    public var policy: TelemetryPolicy {
        get {
            configurationQueue.sync { _policy }
        }
        set {
            configurationQueue.async(flags: .barrier) { [weak self] in
                self?._policy = newValue
                self?.persistPolicy()
            }
        }
    }
    
    private init() {
        // Load configuration from storage or use defaults
        self._configuration = Self.loadConfiguration() ?? .development
        self._thresholds = Self.loadThresholds() ?? PerformanceThresholds()
        self._policy = Self.loadPolicy() ?? TelemetryPolicy()
    }
    
    /// Add configuration change observer
    public func addObserver(_ observer: @escaping (TelemetryConfiguration) -> Void) {
        configurationQueue.async(flags: .barrier) { [weak self] in
            self?.observers.append(observer)
        }
    }
    
    /// Reset to default configuration
    public func resetToDefaults() {
        #if DEBUG
        configuration = .development
        #else
        configuration = .production
        #endif
        thresholds = PerformanceThresholds()
        policy = TelemetryPolicy()
    }
    
    // MARK: - Private Methods
    
    private func notifyObservers(_ configuration: TelemetryConfiguration) {
        observers.forEach { $0(configuration) }
    }
    
    private func persistConfiguration() {
        // Save to UserDefaults or other storage
        if let data = try? JSONEncoder().encode(_configuration) {
            UserDefaults.standard.set(data, forKey: "TelemetryConfiguration")
        }
    }
    
    private func persistThresholds() {
        if let data = try? JSONEncoder().encode(_thresholds) {
            UserDefaults.standard.set(data, forKey: "TelemetryThresholds")
        }
    }
    
    private func persistPolicy() {
        if let data = try? JSONEncoder().encode(_policy) {
            UserDefaults.standard.set(data, forKey: "TelemetryPolicy")
        }
    }
    
    private static func loadConfiguration() -> TelemetryConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "TelemetryConfiguration") else { return nil }
        return try? JSONDecoder().decode(TelemetryConfiguration.self, from: data)
    }
    
    private static func loadThresholds() -> PerformanceThresholds? {
        guard let data = UserDefaults.standard.data(forKey: "TelemetryThresholds") else { return nil }
        return try? JSONDecoder().decode(PerformanceThresholds.self, from: data)
    }
    
    private static func loadPolicy() -> TelemetryPolicy? {
        guard let data = UserDefaults.standard.data(forKey: "TelemetryPolicy") else { return nil }
        return try? JSONDecoder().decode(TelemetryPolicy.self, from: data)
    }
}