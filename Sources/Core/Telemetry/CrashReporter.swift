// Sources/Core/Telemetry/CrashReporter.swift
// Task: Crash Reporting System Implementation
// This file handles crash detection, reporting, and recovery

import Foundation
import OSLog

/// Crash reporting system for capturing and reporting application crashes
public final class CrashReporter: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.telemetry", category: "CrashReporter")
    private let crashQueue = DispatchQueue(label: "com.claudecode.telemetry.crash", attributes: .concurrent)
    
    /// Shared instance
    public static let shared = CrashReporter()
    
    // Crash handlers
    private var crashHandlers: [(CrashReport) -> Void] = []
    
    // Exception handler
    private var previousExceptionHandler: NSUncaughtExceptionHandler?
    
    // Signal handlers
    private var signalHandlers: [Int32: (@convention(c) (Int32) -> Void)?] = [:]
    
    // Crash file storage
    private let crashReportDirectory: URL
    
    // Session information
    private let sessionId = UUID()
    private let sessionStartTime = Date()
    
    private init() {
        // Setup crash report directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.crashReportDirectory = documentsPath.appendingPathComponent("CrashReports", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: crashReportDirectory, withIntermediateDirectories: true)
        
        // Setup crash handling
        setupCrashHandling()
        
        // Check for previous crashes
        checkForPreviousCrashes()
    }
    
    // MARK: - Public Methods
    
    /// Enable crash reporting
    public func enable() {
        installExceptionHandler()
        installSignalHandlers()
        logger.info("Crash reporting enabled")
    }
    
    /// Disable crash reporting
    public func disable() {
        uninstallExceptionHandler()
        uninstallSignalHandlers()
        logger.info("Crash reporting disabled")
    }
    
    /// Add crash handler
    public func addCrashHandler(_ handler: @escaping (CrashReport) -> Void) {
        crashQueue.async(flags: .barrier) { [weak self] in
            self?.crashHandlers.append(handler)
        }
    }
    
    /// Manually report an error as a crash
    public func reportError(_ error: Error, fatal: Bool = false) {
        let crashReport = CrashReport(
            id: UUID(),
            timestamp: Date(),
            sessionId: sessionId,
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            type: fatal ? .fatalError : .nonFatalError,
            reason: error.localizedDescription,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            threadInfo: captureThreadInfo(),
            systemInfo: captureSystemInfo(),
            appInfo: captureAppInfo(),
            customData: nil
        )
        
        saveCrashReport(crashReport)
        notifyHandlers(crashReport)
        
        logger.error("Reported error: \(error.localizedDescription)")
    }
    
    /// Report a custom crash
    public func reportCustomCrash(reason: String, details: [String: Any]? = nil) {
        let crashReport = CrashReport(
            id: UUID(),
            timestamp: Date(),
            sessionId: sessionId,
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            type: .custom,
            reason: reason,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            threadInfo: captureThreadInfo(),
            systemInfo: captureSystemInfo(),
            appInfo: captureAppInfo(),
            customData: details
        )
        
        saveCrashReport(crashReport)
        notifyHandlers(crashReport)
    }
    
    /// Get pending crash reports
    public func getPendingCrashReports() -> [CrashReport] {
        crashQueue.sync {
            loadPendingCrashReports()
        }
    }
    
    /// Clear crash reports
    public func clearCrashReports() {
        crashQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            do {
                let files = try FileManager.default.contentsOfDirectory(at: self.crashReportDirectory, includingPropertiesForKeys: nil)
                for file in files {
                    try FileManager.default.removeItem(at: file)
                }
                self.logger.info("Cleared all crash reports")
            } catch {
                self.logger.error("Failed to clear crash reports: \(error)")
            }
        }
    }
    
    /// Mark crash report as sent
    public func markCrashReportAsSent(_ reportId: UUID) {
        crashQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let filename = "crash_\(reportId.uuidString).json"
            let fileURL = self.crashReportDirectory.appendingPathComponent(filename)
            
            do {
                try FileManager.default.removeItem(at: fileURL)
                self.logger.info("Marked crash report as sent: \(reportId)")
            } catch {
                self.logger.error("Failed to mark crash report as sent: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupCrashHandling() {
        // Setup notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    private func installExceptionHandler() {
        previousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleException(exception)
        }
    }
    
    private func uninstallExceptionHandler() {
        NSSetUncaughtExceptionHandler(previousExceptionHandler)
    }
    
    private func installSignalHandlers() {
        let signals: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE, SIGTRAP]
        
        for signal in signals {
            let oldHandler = signal(signal, CrashReporter.signalHandler)
            signalHandlers[signal] = oldHandler
        }
    }
    
    private func uninstallSignalHandlers() {
        for (sig, handler) in signalHandlers {
            signal(sig, handler)
        }
        signalHandlers.removeAll()
    }
    
    private static let signalHandler: @convention(c) (Int32) -> Void = { signal in
        CrashReporter.shared.handleSignal(signal)
    }
    
    private func handleException(_ exception: NSException) {
        let crashReport = CrashReport(
            id: UUID(),
            timestamp: Date(),
            sessionId: sessionId,
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            type: .exception,
            reason: exception.reason ?? "Unknown exception",
            stackTrace: exception.callStackSymbols.joined(separator: "\n"),
            threadInfo: captureThreadInfo(),
            systemInfo: captureSystemInfo(),
            appInfo: captureAppInfo(),
            customData: [
                "exception_name": exception.name.rawValue,
                "exception_userInfo": exception.userInfo ?? [:]
            ]
        )
        
        saveCrashReport(crashReport)
        
        // Call previous handler if exists
        previousExceptionHandler?(exception)
    }
    
    private func handleSignal(_ signal: Int32) {
        let signalName = getSignalName(signal)
        
        let crashReport = CrashReport(
            id: UUID(),
            timestamp: Date(),
            sessionId: sessionId,
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            type: .signal,
            reason: "Signal \(signalName) (\(signal))",
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            threadInfo: captureThreadInfo(),
            systemInfo: captureSystemInfo(),
            appInfo: captureAppInfo(),
            customData: ["signal": signal]
        )
        
        saveCrashReport(crashReport)
        
        // Call original handler if exists
        if let originalHandler = signalHandlers[signal] {
            originalHandler?(signal)
        }
    }
    
    private func getSignalName(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGILL: return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE: return "SIGFPE"
        case SIGBUS: return "SIGBUS"
        case SIGPIPE: return "SIGPIPE"
        case SIGTRAP: return "SIGTRAP"
        default: return "UNKNOWN"
        }
    }
    
    @objc private func applicationWillTerminate() {
        // Save session end information
        let sessionEnd = CrashReport(
            id: UUID(),
            timestamp: Date(),
            sessionId: sessionId,
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            type: .sessionEnd,
            reason: "Application terminated normally",
            stackTrace: nil,
            threadInfo: nil,
            systemInfo: captureSystemInfo(),
            appInfo: captureAppInfo(),
            customData: nil
        )
        
        saveCrashReport(sessionEnd)
    }
    
    private func checkForPreviousCrashes() {
        let reports = loadPendingCrashReports()
        
        if !reports.isEmpty {
            logger.info("Found \(reports.count) pending crash reports from previous session")
            
            // Notify handlers about previous crashes
            for report in reports {
                notifyHandlers(report)
            }
        }
    }
    
    private func saveCrashReport(_ report: CrashReport) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(report)
            let filename = "crash_\(report.id.uuidString).json"
            let fileURL = crashReportDirectory.appendingPathComponent(filename)
            
            try data.write(to: fileURL)
            logger.info("Saved crash report: \(report.id)")
        } catch {
            logger.error("Failed to save crash report: \(error)")
        }
    }
    
    private func loadPendingCrashReports() -> [CrashReport] {
        var reports: [CrashReport] = []
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: crashReportDirectory, includingPropertiesForKeys: nil)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            for file in files where file.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: file)
                    let report = try decoder.decode(CrashReport.self, from: data)
                    reports.append(report)
                } catch {
                    logger.error("Failed to load crash report from \(file): \(error)")
                }
            }
        } catch {
            logger.error("Failed to load crash reports: \(error)")
        }
        
        return reports
    }
    
    private func notifyHandlers(_ report: CrashReport) {
        crashQueue.async { [weak self] in
            self?.crashHandlers.forEach { $0(report) }
        }
    }
    
    private func captureThreadInfo() -> ThreadInfo {
        ThreadInfo(
            threadId: Thread.current.description,
            isMainThread: Thread.isMainThread,
            stackTrace: Thread.callStackSymbols,
            queueName: String(cString: __dispatch_queue_get_label(nil))
        )
    }
    
    private func captureSystemInfo() -> SystemInfo {
        let processInfo = ProcessInfo.processInfo
        
        return SystemInfo(
            osVersion: processInfo.operatingSystemVersionString,
            deviceModel: UIDevice.current.model,
            deviceName: UIDevice.current.name,
            systemUptime: processInfo.systemUptime,
            memoryUsage: getMemoryUsage(),
            diskSpace: getDiskSpace(),
            batteryLevel: UIDevice.current.batteryLevel,
            isLowPowerMode: processInfo.isLowPowerModeEnabled
        )
    }
    
    private func captureAppInfo() -> AppInfo {
        let bundle = Bundle.main
        
        return AppInfo(
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            bundleIdentifier: bundle.bundleIdentifier ?? "Unknown",
            executableName: bundle.executableURL?.lastPathComponent ?? "Unknown"
        )
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func getDiskSpace() -> DiskSpace {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let totalSpace = systemAttributes[.systemSize] as? Int64 ?? 0
            let freeSpace = systemAttributes[.systemFreeSize] as? Int64 ?? 0
            
            return DiskSpace(total: totalSpace, free: freeSpace, used: totalSpace - freeSpace)
        } catch {
            return DiskSpace(total: 0, free: 0, used: 0)
        }
    }
}

// MARK: - Supporting Types

/// Crash report structure
public struct CrashReport: Codable {
    public let id: UUID
    public let timestamp: Date
    public let sessionId: UUID
    public let sessionDuration: TimeInterval
    public let type: CrashType
    public let reason: String
    public let stackTrace: String?
    public let threadInfo: ThreadInfo?
    public let systemInfo: SystemInfo
    public let appInfo: AppInfo
    public let customData: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, sessionId, sessionDuration, type, reason, stackTrace
        case threadInfo, systemInfo, appInfo, customData
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        sessionDuration = try container.decode(TimeInterval.self, forKey: .sessionDuration)
        type = try container.decode(CrashType.self, forKey: .type)
        reason = try container.decode(String.self, forKey: .reason)
        stackTrace = try container.decodeIfPresent(String.self, forKey: .stackTrace)
        threadInfo = try container.decodeIfPresent(ThreadInfo.self, forKey: .threadInfo)
        systemInfo = try container.decode(SystemInfo.self, forKey: .systemInfo)
        appInfo = try container.decode(AppInfo.self, forKey: .appInfo)
        customData = nil // Handle custom data separately if needed
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(sessionDuration, forKey: .sessionDuration)
        try container.encode(type, forKey: .type)
        try container.encode(reason, forKey: .reason)
        try container.encodeIfPresent(stackTrace, forKey: .stackTrace)
        try container.encodeIfPresent(threadInfo, forKey: .threadInfo)
        try container.encode(systemInfo, forKey: .systemInfo)
        try container.encode(appInfo, forKey: .appInfo)
        // Handle custom data encoding if needed
    }
    
    init(id: UUID, timestamp: Date, sessionId: UUID, sessionDuration: TimeInterval,
         type: CrashType, reason: String, stackTrace: String?, threadInfo: ThreadInfo?,
         systemInfo: SystemInfo, appInfo: AppInfo, customData: [String: Any]?) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.sessionDuration = sessionDuration
        self.type = type
        self.reason = reason
        self.stackTrace = stackTrace
        self.threadInfo = threadInfo
        self.systemInfo = systemInfo
        self.appInfo = appInfo
        self.customData = customData
    }
}

/// Crash types
public enum CrashType: String, Codable {
    case exception = "exception"
    case signal = "signal"
    case fatalError = "fatal_error"
    case nonFatalError = "non_fatal_error"
    case sessionEnd = "session_end"
    case custom = "custom"
}

/// Thread information
public struct ThreadInfo: Codable {
    public let threadId: String
    public let isMainThread: Bool
    public let stackTrace: [String]
    public let queueName: String
}

/// System information
public struct SystemInfo: Codable {
    public let osVersion: String
    public let deviceModel: String
    public let deviceName: String
    public let systemUptime: TimeInterval
    public let memoryUsage: Int64
    public let diskSpace: DiskSpace
    public let batteryLevel: Float
    public let isLowPowerMode: Bool
}

/// Disk space information
public struct DiskSpace: Codable {
    public let total: Int64
    public let free: Int64
    public let used: Int64
}

/// App information
public struct AppInfo: Codable {
    public let appVersion: String
    public let buildNumber: String
    public let bundleIdentifier: String
    public let executableName: String
}