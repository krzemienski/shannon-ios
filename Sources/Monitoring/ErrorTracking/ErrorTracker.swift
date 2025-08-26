//
//  ErrorTracker.swift
//  ClaudeCode
//
//  Comprehensive error tracking with grouping, deduplication, and automated triage
//

import Foundation
import os.log
import CryptoKit
import Combine

// MARK: - Error Tracker

public final class ErrorTracker {
    
    // MARK: - Singleton
    
    public static let shared = ErrorTracker()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.monitoring", category: "ErrorTracking")
    private let queue = DispatchQueue(label: "com.claudecode.error.tracker", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    
    // Error storage
    private var errorGroups: [String: ErrorGroup] = [:]
    private var recentErrors: [TrackedError] = []
    private let maxRecentErrors = 1000
    
    // Deduplication
    private let deduplicator = ErrorDeduplicator()
    
    // Classification
    private let classifier = ErrorClassifier()
    
    // Automated triage
    private let triageEngine = AutomatedTriageEngine()
    
    // Providers
    private var providers: [ErrorTrackingProvider] = []
    
    // Configuration
    private var config = ErrorTrackingConfiguration.default
    
    // Session info
    private var sessionId: String?
    private var userId: String?
    
    // MARK: - Initialization
    
    private init() {
        setupProviders()
        setupCrashReporting()
    }
    
    // MARK: - Configuration
    
    public func configure(with configuration: ErrorTrackingConfiguration = .default) {
        self.config = configuration
        
        providers.forEach { provider in
            provider.configure(with: configuration)
        }
        
        logger.info("Error tracking configured")
    }
    
    public func setUser(id: String, properties: [String: Any] = [:]) {
        userId = id
        
        providers.forEach { provider in
            provider.setUser(id: id, properties: properties)
        }
    }
    
    public func setSession(id: String) {
        sessionId = id
    }
    
    // MARK: - Error Tracking
    
    public func trackError(
        _ error: Error,
        severity: ErrorSeverity? = nil,
        context: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let trackedError = createTrackedError(
            error: error,
            severity: severity,
            context: context,
            file: file,
            function: function,
            line: line
        )
        
        processError(trackedError)
    }
    
    public func trackException(
        _ exception: NSException,
        context: [String: Any] = [:]
    ) {
        let error = NSError(
            domain: "NSException",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: exception.reason ?? "Unknown exception",
                "name": exception.name.rawValue,
                "callStackSymbols": exception.callStackSymbols ?? []
            ]
        )
        
        let trackedError = createTrackedError(
            error: error,
            severity: .critical,
            context: context,
            file: "Unknown",
            function: "Unknown",
            line: 0
        )
        
        processError(trackedError)
    }
    
    // MARK: - Error Processing
    
    private func processError(_ error: TrackedError) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Deduplicate
            if self.deduplicator.isDuplicate(error) {
                self.deduplicator.incrementCount(for: error)
                self.logger.debug("Duplicate error suppressed: \(error.message)")
                return
            }
            
            // Store error
            self.storeError(error)
            
            // Group error
            self.groupError(error)
            
            // Classify severity
            let classification = self.classifier.classify(error)
            error.updateClassification(classification)
            
            // Automated triage
            let triageResult = self.triageEngine.triage(error)
            self.handleTriageResult(triageResult, for: error)
            
            // Send to providers
            self.sendToProviders(error)
            
            // Send to monitoring service
            self.sendToMonitoring(error)
            
            // Check for critical errors
            if error.severity == .critical || error.classification?.requiresImmediate​Action == true {
                self.handleCriticalError(error)
            }
            
            self.logger.info("Error tracked: \(error.errorId) - \(error.message)")
        }
    }
    
    private func storeError(_ error: TrackedError) {
        recentErrors.append(error)
        
        if recentErrors.count > maxRecentErrors {
            recentErrors.removeFirst()
        }
    }
    
    private func groupError(_ error: TrackedError) {
        let groupKey = generateGroupKey(for: error)
        
        if let existingGroup = errorGroups[groupKey] {
            existingGroup.addError(error)
        } else {
            let newGroup = ErrorGroup(key: groupKey, initialError: error)
            errorGroups[groupKey] = newGroup
        }
    }
    
    private func generateGroupKey(for error: TrackedError) -> String {
        let components = [
            error.type,
            error.file,
            error.function,
            String(error.line)
        ]
        
        let combined = components.joined(separator: ":")
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func handleTriageResult(_ result: TriageResult, for error: TrackedError) {
        switch result.action {
        case .ignore:
            logger.debug("Error ignored by triage: \(error.errorId)")
            
        case .log:
            logger.info("Error logged: \(error.message)")
            
        case .alert:
            sendAlert(for: error, priority: result.priority)
            
        case .escalate:
            escalateError(error, to: result.assignee)
            
        case .autoResolve:
            attemptAutoResolution(for: error)
        }
    }
    
    private func sendToProviders(_ error: TrackedError) {
        providers.forEach { provider in
            provider.trackError(error)
        }
    }
    
    private func sendToMonitoring(_ error: TrackedError) {
        let context = ErrorContext(
            file: error.file,
            function: error.function,
            line: error.line,
            additionalInfo: error.context
        )
        
        let monitoringError = MonitoringError(
            error: error.originalError,
            context: context,
            stackTrace: error.stackTrace,
            timestamp: error.timestamp,
            isFatal: error.severity == .critical
        )
        
        MonitoringService.shared.trackError(monitoringError)
    }
    
    // MARK: - Critical Error Handling
    
    private func handleCriticalError(_ error: TrackedError) {
        logger.critical("Critical error detected: \(error.message)")
        
        // Send immediate alert
        sendImmediateAlert(for: error)
        
        // Capture additional context
        captureSystemState(for: error)
        
        // Execute emergency protocols
        executeEmergencyProtocols(for: error)
    }
    
    private func sendAlert(for error: TrackedError, priority: TriagePriority) {
        let alert = ErrorAlert(
            errorId: error.errorId,
            message: error.message,
            severity: error.severity,
            priority: priority,
            timestamp: Date()
        )
        
        // Send through notification channels
        NotificationCenter.default.post(
            name: .errorAlert,
            object: alert
        )
        
        logger.warning("Alert sent for error: \(error.errorId) with priority: \(priority)")
    }
    
    private func sendImmediateAlert(for error: TrackedError) {
        sendAlert(for: error, priority: .p1)
        
        // Additional immediate notification logic
        // Could integrate with push notifications, SMS, etc.
    }
    
    private func escalateError(_ error: TrackedError, to assignee: String?) {
        logger.info("Error escalated: \(error.errorId) to \(assignee ?? "on-call")")
        
        // Escalation logic - could integrate with ticketing systems
    }
    
    private func attemptAutoResolution(for error: TrackedError) {
        logger.info("Attempting auto-resolution for error: \(error.errorId)")
        
        // Auto-resolution strategies based on error type
        switch error.type {
        case "NetworkError":
            retryNetworkOperation(for: error)
            
        case "CacheError":
            clearCache()
            
        case "MemoryWarning":
            freeMemory()
            
        default:
            logger.warning("No auto-resolution available for error type: \(error.type)")
        }
    }
    
    private func captureSystemState(for error: TrackedError) {
        let systemState = SystemStateCapture()
        systemState.capture { [weak self] state in
            error.systemState = state
            self?.logger.info("System state captured for error: \(error.errorId)")
        }
    }
    
    private func executeEmergencyProtocols(for error: TrackedError) {
        // Emergency protocols based on error type
        if error.type.contains("Security") {
            // Security breach protocol
            lockdownSensitiveFeatures()
        }
        
        if error.type.contains("DataCorruption") {
            // Data integrity protocol
            initiateDataValidation()
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTrackedError(
        error: Error,
        severity: ErrorSeverity?,
        context: [String: Any],
        file: String,
        function: String,
        line: Int
    ) -> TrackedError {
        let nsError = error as NSError
        
        return TrackedError(
            errorId: UUID().uuidString,
            timestamp: Date(),
            type: String(describing: type(of: error)),
            message: error.localizedDescription,
            severity: severity ?? classifier.determineSeverity(for: error),
            file: URL(fileURLWithPath: file).lastPathComponent,
            function: function,
            line: line,
            context: context.merging([
                "session_id": sessionId ?? "unknown",
                "user_id": userId ?? "anonymous",
                "domain": nsError.domain,
                "code": nsError.code
            ]) { _, new in new },
            stackTrace: Thread.callStackSymbols,
            originalError: error
        )
    }
    
    private func setupProviders() {
        // Initialize error tracking providers
        // These would be actual implementations of various services
        // providers = [
        //     SentryErrorProvider(),
        //     BugsnagErrorProvider(),
        //     FirebaseCrashlyticsProvider(),
        //     CustomErrorProvider()
        // ]
    }
    
    private func setupCrashReporting() {
        // Set up crash reporting handlers
        NSSetUncaughtExceptionHandler { exception in
            ErrorTracker.shared.trackException(exception)
        }
        
        // Signal handlers for crashes
        setupSignalHandlers()
    }
    
    private func setupSignalHandlers() {
        signal(SIGABRT) { _ in
            ErrorTracker.shared.handleSignal("SIGABRT")
        }
        
        signal(SIGILL) { _ in
            ErrorTracker.shared.handleSignal("SIGILL")
        }
        
        signal(SIGSEGV) { _ in
            ErrorTracker.shared.handleSignal("SIGSEGV")
        }
        
        signal(SIGBUS) { _ in
            ErrorTracker.shared.handleSignal("SIGBUS")
        }
        
        signal(SIGTRAP) { _ in
            ErrorTracker.shared.handleSignal("SIGTRAP")
        }
    }
    
    private func handleSignal(_ signal: String) {
        let error = NSError(
            domain: "Signal",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Application crashed with signal: \(signal)"
            ]
        )
        
        trackError(error, severity: .critical, context: ["signal": signal])
        
        // Force flush before crash
        flush()
    }
    
    // MARK: - Auto-Resolution Methods
    
    private func retryNetworkOperation(for error: TrackedError) {
        // Implement network retry logic
    }
    
    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
    }
    
    private func freeMemory() {
        NotificationCenter.default.post(name: .clearMemoryCaches, object: nil)
    }
    
    private func lockdownSensitiveFeatures() {
        // Security lockdown logic
    }
    
    private func initiateDataValidation() {
        // Data validation logic
    }
    
    // MARK: - Public Methods
    
    public func getErrorGroups(limit: Int = 50) -> [ErrorGroup] {
        return queue.sync {
            Array(errorGroups.values)
                .sorted { $0.lastOccurrence > $1.lastOccurrence }
                .prefix(limit)
                .map { $0 }
        }
    }
    
    public func getRecentErrors(limit: Int = 100) -> [TrackedError] {
        return queue.sync {
            Array(recentErrors.suffix(limit))
        }
    }
    
    public func clearErrors() {
        queue.async(flags: .barrier) {
            self.errorGroups.removeAll()
            self.recentErrors.removeAll()
            self.deduplicator.clear()
        }
    }
    
    public func flush() {
        providers.forEach { $0.flush() }
        logger.info("Error tracking data flushed")
    }
}

// MARK: - Supporting Types

public class TrackedError {
    let errorId: String
    let timestamp: Date
    let type: String
    let message: String
    var severity: ErrorSeverity
    let file: String
    let function: String
    let line: Int
    let context: [String: Any]
    let stackTrace: [String]
    let originalError: Error
    
    var classification: ErrorClassification?
    var systemState: SystemState?
    
    init(errorId: String, timestamp: Date, type: String, message: String,
         severity: ErrorSeverity, file: String, function: String, line: Int,
         context: [String: Any], stackTrace: [String], originalError: Error) {
        self.errorId = errorId
        self.timestamp = timestamp
        self.type = type
        self.message = message
        self.severity = severity
        self.file = file
        self.function = function
        self.line = line
        self.context = context
        self.stackTrace = stackTrace
        self.originalError = originalError
    }
    
    func updateClassification(_ classification: ErrorClassification) {
        self.classification = classification
        if let adjustedSeverity = classification.adjustedSeverity {
            self.severity = adjustedSeverity
        }
    }
}

public enum ErrorSeverity: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    public static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public class ErrorGroup {
    let key: String
    let firstOccurrence: Date
    var lastOccurrence: Date
    var count: Int = 0
    var errors: [TrackedError] = []
    let maxStoredErrors = 10
    
    init(key: String, initialError: TrackedError) {
        self.key = key
        self.firstOccurrence = initialError.timestamp
        self.lastOccurrence = initialError.timestamp
        addError(initialError)
    }
    
    func addError(_ error: TrackedError) {
        count += 1
        lastOccurrence = error.timestamp
        
        errors.append(error)
        if errors.count > maxStoredErrors {
            errors.removeFirst()
        }
    }
}

public struct ErrorClassification {
    let category: ErrorCategory
    let impact: ErrorImpact
    let adjustedSeverity: ErrorSeverity?
    let requiresImmediate​Action: Bool
    let suggestedAction: String?
}

public enum ErrorCategory {
    case network
    case database
    case security
    case performance
    case ui
    case business
    case system
    case unknown
}

public enum ErrorImpact {
    case minimal
    case low
    case medium
    case high
    case critical
}

public struct TriageResult {
    let action: TriageAction
    let priority: TriagePriority
    let assignee: String?
    let reason: String
}

public enum TriageAction {
    case ignore
    case log
    case alert
    case escalate
    case autoResolve
}

public enum TriagePriority {
    case p1 // Immediate
    case p2 // High
    case p3 // Medium
    case p4 // Low
}

public struct ErrorAlert {
    let errorId: String
    let message: String
    let severity: ErrorSeverity
    let priority: TriagePriority
    let timestamp: Date
}

public struct SystemState {
    let memoryUsage: UInt64
    let cpuUsage: Double
    let diskSpace: UInt64
    let batteryLevel: Float
    let networkStatus: String
    let activeViewControllers: [String]
    let timestamp: Date
}

public struct ErrorTrackingConfiguration {
    let isEnabled: Bool
    let environment: String
    let sampleRate: Double
    let maxErrorsPerSession: Int
    let enableAutomaticTriage: Bool
    let enableCrashReporting: Bool
    
    public static let `default` = ErrorTrackingConfiguration(
        isEnabled: true,
        environment: "development",
        sampleRate: 1.0,
        maxErrorsPerSession: 1000,
        enableAutomaticTriage: true,
        enableCrashReporting: true
    )
}

// MARK: - Error Tracking Provider Protocol

public protocol ErrorTrackingProvider {
    func configure(with config: ErrorTrackingConfiguration)
    func trackError(_ error: TrackedError)
    func setUser(id: String, properties: [String: Any])
    func flush()
}

// MARK: - Notification Names

extension Notification.Name {
    static let errorAlert = Notification.Name("com.claudecode.errorAlert")
}