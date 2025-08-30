//
//  ErrorTracker.swift
//  ClaudeCode
//
//  Central error tracking and reporting system (Tasks 901-925)
//

import Foundation
import SwiftUI
import os.log

/// Error severity levels
public enum ErrorSeverity: String, Codable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

/// Tracked error information
public struct TrackedError: Identifiable, Codable {
    public let id = UUID()
    public let timestamp: Date
    public let severity: ErrorSeverity
    public let category: String
    public let message: String
    public let file: String
    public let function: String
    public let line: Int
    public let userInfo: [String: String]?
    public let stackTrace: [String]?
    
    public init(
        severity: ErrorSeverity,
        category: String,
        message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        userInfo: [String: String]? = nil,
        stackTrace: [String]? = nil
    ) {
        self.timestamp = Date()
        self.severity = severity
        self.category = category
        self.message = message
        self.file = URL(fileURLWithPath: file).lastPathComponent
        self.function = function
        self.line = line
        self.userInfo = userInfo
        self.stackTrace = stackTrace
    }
}

/// Central error tracking service
@MainActor
public class ErrorTracker: ObservableObject {
    // MARK: - Singleton
    
    public static let shared = ErrorTracker()
    
    // MARK: - Published Properties
    
    @Published public private(set) var recentErrors: [TrackedError] = []
    @Published public private(set) var errorCount: Int = 0
    @Published public private(set) var warningCount: Int = 0
    @Published public private(set) var criticalCount: Int = 0
    @Published public private(set) var isTracking = true
    
    // MARK: - Private Properties
    
    private let errorLog = OSLog(subsystem: "com.claudecode.ios", category: "ErrorTracking")
    private let maxRecentErrors = 100
    private let errorQueue = DispatchQueue(label: "com.claudecode.errortracker", qos: .utility)
    private var errorHandlers: [(TrackedError) -> Void] = []
    
    // Persistent storage
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, 
                                                              in: .userDomainMask).first!
    private var errorLogFile: URL {
        documentsDirectory.appendingPathComponent("error_log.json")
    }
    
    // MARK: - Initialization
    
    private init() {
        loadPersistedErrors()
        setupCrashReporting()
    }
    
    // MARK: - Public Methods
    
    /// Track an error
    public func track(
        _ error: Error,
        severity: ErrorSeverity = .error,
        category: String = "General",
        userInfo: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isTracking else { return }
        
        let trackedError = TrackedError(
            severity: severity,
            category: category,
            message: error.localizedDescription,
            file: file,
            function: function,
            line: line,
            userInfo: userInfo,
            stackTrace: Thread.callStackSymbols
        )
        
        recordError(trackedError)
    }
    
    /// Track a message
    public func track(
        message: String,
        severity: ErrorSeverity = .info,
        category: String = "General",
        userInfo: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isTracking else { return }
        
        let trackedError = TrackedError(
            severity: severity,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line,
            userInfo: userInfo
        )
        
        recordError(trackedError)
    }
    
    /// Register error handler
    public func registerHandler(_ handler: @escaping (TrackedError) -> Void) {
        errorHandlers.append(handler)
    }
    
    /// Clear all tracked errors
    public func clearErrors() {
        recentErrors.removeAll()
        errorCount = 0
        warningCount = 0
        criticalCount = 0
        
        // Clear persisted errors
        try? FileManager.default.removeItem(at: errorLogFile)
    }
    
    /// Export error log
    public func exportErrorLog() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        return try? encoder.encode(recentErrors)
    }
    
    /// Get errors by severity
    public func errors(withSeverity severity: ErrorSeverity) -> [TrackedError] {
        recentErrors.filter { $0.severity == severity }
    }
    
    /// Get errors by category
    public func errors(inCategory category: String) -> [TrackedError] {
        recentErrors.filter { $0.category == category }
    }
    
    // MARK: - Private Methods
    
    private func recordError(_ error: TrackedError) {
        // Update counts
        switch error.severity {
        case .error:
            errorCount += 1
        case .warning:
            warningCount += 1
        case .critical:
            criticalCount += 1
            handleCriticalError(error)
        default:
            break
        }
        
        // Add to recent errors
        recentErrors.append(error)
        if recentErrors.count > maxRecentErrors {
            recentErrors.removeFirst()
        }
        
        // Log to system
        logError(error)
        
        // Notify handlers
        errorHandlers.forEach { $0(error) }
        
        // Persist error
        errorQueue.async { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.persistError(error)
            }
        }
    }
    
    private func logError(_ error: TrackedError) {
        let logType: OSLogType
        switch error.severity {
        case .debug:
            logType = .debug
        case .info:
            logType = .info
        case .warning:
            logType = .default
        case .error:
            logType = .error
        case .critical:
            logType = .fault
        }
        
        os_log(logType, log: errorLog, 
               "[%{public}@] %{public}@ in %{public}@:%{public}d - %{public}@",
               error.severity.rawValue.uppercased(),
               error.category,
               error.file,
               error.line,
               error.message)
    }
    
    private func handleCriticalError(_ error: TrackedError) {
        // Special handling for critical errors
        os_log(.fault, log: errorLog, "CRITICAL ERROR: %{public}@", error.message)
        
        // Could trigger crash reporting, alerts, etc.
        NotificationCenter.default.post(
            name: .criticalErrorOccurred,
            object: nil,
            userInfo: ["error": error]
        )
    }
    
    @MainActor
    private func persistError(_ error: TrackedError) {
        var errors = loadPersistedErrorsSync()
        errors.append(error)
        
        // Keep only recent errors
        if errors.count > 1000 {
            errors = Array(errors.suffix(1000))
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(errors) {
            try? data.write(to: errorLogFile)
        }
    }
    
    private func loadPersistedErrors() {
        Task {
            let errors = loadPersistedErrorsSync()
            await MainActor.run {
                self.recentErrors = Array(errors.suffix(maxRecentErrors))
                self.updateCounts()
            }
        }
    }
    
    private func loadPersistedErrorsSync() -> [TrackedError] {
        guard FileManager.default.fileExists(atPath: errorLogFile.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: errorLogFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([TrackedError].self, from: data)
        } catch {
            os_log(.error, log: errorLog, "Failed to load persisted errors: %{public}@", 
                   error.localizedDescription)
            return []
        }
    }
    
    private func updateCounts() {
        errorCount = recentErrors.filter { $0.severity == .error }.count
        warningCount = recentErrors.filter { $0.severity == .warning }.count
        criticalCount = recentErrors.filter { $0.severity == .critical }.count
    }
    
    private func setupCrashReporting() {
        // Set up exception handler
        NSSetUncaughtExceptionHandler { exception in
            Task { @MainActor in
                ErrorTracker.shared.track(
                    message: exception.description,
                    severity: .critical,
                    category: "Crash",
                    userInfo: [
                        "name": exception.name.rawValue,
                        "reason": exception.reason ?? "Unknown"
                    ]
                )
            }
        }
        
        // Set up signal handlers for crashes
        setupSignalHandlers()
    }
    
    private func setupSignalHandlers() {
        let signals = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE]
        
        for signalNumber in signals {
            Foundation.signal(signalNumber) { sig in
                Task { @MainActor in
                    ErrorTracker.shared.track(
                        message: "Signal \(sig) received",
                        severity: .critical,
                        category: "Crash",
                        userInfo: ["signal": String(sig)]
                    )
                }
            }
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let criticalErrorOccurred = Notification.Name("criticalErrorOccurred")
}

// MARK: - Error Console View

public struct ErrorConsoleView: View {
    @ObservedObject private var tracker = ErrorTracker.shared
    @State private var selectedSeverity: ErrorSeverity?
    @State private var searchText = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats bar
                HStack {
                    StatBadge(label: "Errors", count: tracker.errorCount, color: .red)
                    StatBadge(label: "Warnings", count: tracker.warningCount, color: .orange)
                    StatBadge(label: "Critical", count: tracker.criticalCount, color: .purple)
                }
                .padding()
                
                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        FilterPill(title: "All", 
                                  isSelected: selectedSeverity == nil) {
                            selectedSeverity = nil
                        }
                        
                        ForEach([ErrorSeverity.critical, .error, .warning, .info], id: \.self) { severity in
                            FilterPill(title: severity.rawValue.capitalized,
                                      isSelected: selectedSeverity == severity) {
                                selectedSeverity = severity
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Error list
                List {
                    ForEach(filteredErrors) { error in
                        ErrorRow(error: error)
                    }
                }
                .searchable(text: $searchText, prompt: "Search errors...")
            }
            .navigationTitle("Error Console")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear") {
                        tracker.clearErrors()
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button("Export") {
                        exportErrors()
                    }
                }
            }
        }
    }
    
    private var filteredErrors: [TrackedError] {
        var errors = tracker.recentErrors
        
        if let severity = selectedSeverity {
            errors = errors.filter { $0.severity == severity }
        }
        
        if !searchText.isEmpty {
            errors = errors.filter { 
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return errors.reversed() // Most recent first
    }
    
    private func exportErrors() {
        guard let data = tracker.exportErrorLog() else { return }
        
        // Share error log
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("error_log.json")
        try? data.write(to: url)
        
        // Present share sheet
        // Implementation depends on platform
    }
}

private struct StatBadge: View {
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
    }
}

private struct ErrorRow: View {
    let error: TrackedError
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)
                
                Text(error.category)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(error.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(error.message)
                .font(.system(.body, design: .monospaced))
                .lineLimit(isExpanded ? nil : 2)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(error.file):\(error.line)")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    
                    Text(error.function)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    
                    if let userInfo = error.userInfo {
                        ForEach(Array(userInfo.keys), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .font(.caption.bold())
                                Text(userInfo[key] ?? "")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                isExpanded.toggle()
            }
        }
    }
    
    private var severityColor: Color {
        switch error.severity {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
}