//
//  ErrorTrackingComponents.swift
//  ClaudeCode
//
//  Supporting components for error tracking: deduplication, classification, triage, and system state
//

import Foundation
import UIKit
import CryptoKit
import os.log

// MARK: - Error Deduplicator

public class ErrorDeduplicator {
    private var errorSignatures: [String: ErrorSignature] = [:]
    private let maxSignatures = 1000
    private let deduplicationWindow: TimeInterval = 300 // 5 minutes
    private let queue = DispatchQueue(label: "com.claudecode.error.deduplicator")
    
    struct ErrorSignature {
        let firstSeen: Date
        var lastSeen: Date
        var count: Int
        let hash: String
    }
    
    func isDuplicate(_ error: TrackedError) -> Bool {
        let hash = generateHash(for: error)
        
        return queue.sync {
            if let signature = errorSignatures[hash] {
                let timeSinceFirst = Date().timeIntervalSince(signature.firstSeen)
                return timeSinceFirst < deduplicationWindow
            }
            return false
        }
    }
    
    func incrementCount(for error: TrackedError) {
        let hash = generateHash(for: error)
        
        queue.async(flags: .barrier) {
            if var signature = self.errorSignatures[hash] {
                signature.count += 1
                signature.lastSeen = Date()
                self.errorSignatures[hash] = signature
            } else {
                let signature = ErrorSignature(
                    firstSeen: Date(),
                    lastSeen: Date(),
                    count: 1,
                    hash: hash
                )
                self.errorSignatures[hash] = signature
            }
            
            self.cleanOldSignatures()
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.errorSignatures.removeAll()
        }
    }
    
    private func generateHash(for error: TrackedError) -> String {
        let components = [
            error.type,
            error.message,
            error.file,
            error.function,
            String(error.line)
        ]
        
        let combined = components.joined(separator: "|")
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func cleanOldSignatures() {
        let cutoffDate = Date().addingTimeInterval(-deduplicationWindow)
        errorSignatures = errorSignatures.filter { _, signature in
            signature.lastSeen > cutoffDate
        }
        
        // Limit total signatures
        if errorSignatures.count > maxSignatures {
            let sortedSignatures = errorSignatures.sorted { $0.value.lastSeen > $1.value.lastSeen }
            errorSignatures = Dictionary(uniqueKeysWithValues: sortedSignatures.prefix(maxSignatures))
        }
    }
}

// MARK: - Error Classifier

public class ErrorClassifier {
    private let logger = Logger(subsystem: "com.claudecode.monitoring", category: "ErrorClassifier")
    
    func classify(_ error: TrackedError) -> ErrorClassification {
        let category = determineCategory(for: error)
        let impact = determineImpact(for: error)
        let adjustedSeverity = adjustSeverity(original: error.severity, category: category, impact: impact)
        let requiresImmediate = shouldRequireImmediateAction(error: error, category: category, impact: impact)
        let suggestedAction = determineSuggestedAction(for: error, category: category)
        
        return ErrorClassification(
            category: category,
            impact: impact,
            adjustedSeverity: adjustedSeverity,
            requiresImmediateAction: requiresImmediate,
            suggestedAction: suggestedAction
        )
    }
    
    func determineSeverity(for error: Error) -> ErrorSeverity {
        let nsError = error as NSError
        
        // Check for specific error domains
        switch nsError.domain {
        case NSURLErrorDomain:
            return classifyNetworkError(code: nsError.code)
            
        case "NSCocoaErrorDomain":
            return classifyCocoaError(code: nsError.code)
            
        case "Signal", "NSException":
            return .critical
            
        default:
            // Default classification based on error code
            if nsError.code >= 500 {
                return .error
            } else if nsError.code >= 400 {
                return .warning
            } else {
                return .info
            }
        }
    }
    
    private func determineCategory(for error: TrackedError) -> ErrorCategory {
        let errorType = error.type.lowercased()
        let message = error.message.lowercased()
        
        if errorType.contains("network") || message.contains("network") ||
           errorType.contains("url") || message.contains("connection") {
            return .network
        }
        
        if errorType.contains("database") || errorType.contains("coredata") ||
           message.contains("database") || message.contains("sql") {
            return .database
        }
        
        if errorType.contains("security") || errorType.contains("auth") ||
           message.contains("unauthorized") || message.contains("forbidden") {
            return .security
        }
        
        if errorType.contains("memory") || errorType.contains("performance") ||
           message.contains("timeout") || message.contains("slow") {
            return .performance
        }
        
        if errorType.contains("ui") || errorType.contains("view") ||
           error.file.contains("View") || error.file.contains("Controller") {
            return .ui
        }
        
        if errorType.contains("signal") || errorType.contains("exception") ||
           errorType.contains("crash") {
            return .system
        }
        
        return .unknown
    }
    
    private func determineImpact(for error: TrackedError) -> ErrorImpact {
        // Analyze error context and patterns to determine impact
        let affectsAllUsers = checkIfAffectsAllUsers(error)
        let breaksCore = checkIfBreaksCoreFunction(error)
        let dataLoss = checkForDataLoss(error)
        let securityRisk = checkForSecurityRisk(error)
        
        if securityRisk || dataLoss {
            return .critical
        }
        
        if breaksCore || affectsAllUsers {
            return .high
        }
        
        if error.severity >= .error {
            return .medium
        }
        
        if error.severity == .warning {
            return .low
        }
        
        return .minimal
    }
    
    private func adjustSeverity(original: ErrorSeverity, category: ErrorCategory, impact: ErrorImpact) -> ErrorSeverity? {
        // Security errors should always be at least error level
        if category == .security && original < .error {
            return .error
        }
        
        // Critical impact should be critical severity
        if impact == .critical && original < .critical {
            return .critical
        }
        
        // High impact should be at least error
        if impact == .high && original < .error {
            return .error
        }
        
        return nil // No adjustment needed
    }
    
    private func shouldRequireImmediateAction(error: TrackedError, category: ErrorCategory, impact: ErrorImpact) -> Bool {
        // Critical errors always require immediate action
        if error.severity == .critical || impact == .critical {
            return true
        }
        
        // Security errors with high impact
        if category == .security && impact >= .high {
            return true
        }
        
        // System crashes
        if category == .system && error.severity >= .error {
            return true
        }
        
        // Data loss scenarios
        if category == .database && impact >= .high {
            return true
        }
        
        return false
    }
    
    private func determineSuggestedAction(for error: TrackedError, category: ErrorCategory) -> String? {
        switch category {
        case .network:
            return "Check network connectivity and retry operation"
            
        case .database:
            return "Verify data integrity and check database connection"
            
        case .security:
            return "Review security logs and check authentication status"
            
        case .performance:
            return "Analyze performance metrics and optimize resource usage"
            
        case .ui:
            return "Check UI thread and view hierarchy"
            
        case .system:
            return "Review system resources and check for crashes"
            
        default:
            return nil
        }
    }
    
    private func classifyNetworkError(code: Int) -> ErrorSeverity {
        switch code {
        case NSURLErrorCancelled:
            return .debug
            
        case NSURLErrorTimedOut, NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
            return .warning
            
        case NSURLErrorDNSLookupFailed, NSURLErrorHTTPTooManyRedirects,
             NSURLErrorResourceUnavailable:
            return .error
            
        case NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasUnknownRoot:
            return .critical
            
        default:
            return .warning
        }
    }
    
    private func classifyCocoaError(code: Int) -> ErrorSeverity {
        switch code {
        case 4...255: // File errors
            return .warning
            
        case 256...511: // Validation errors
            return .error
            
        case 1024...1279: // Core Data errors
            return .error
            
        default:
            return .warning
        }
    }
    
    private func checkIfAffectsAllUsers(_ error: TrackedError) -> Bool {
        // Check if error affects all users
        let criticalPaths = ["login", "authentication", "payment", "startup"]
        return criticalPaths.contains { error.function.lowercased().contains($0) }
    }
    
    private func checkIfBreaksCoreFunction(_ error: TrackedError) -> Bool {
        // Check if error breaks core functionality
        let coreFunctions = ["send", "receive", "process", "save", "load"]
        return coreFunctions.contains { error.function.lowercased().contains($0) }
    }
    
    private func checkForDataLoss(_ error: TrackedError) -> Bool {
        // Check for potential data loss
        let dataLossIndicators = ["corrupt", "lost", "failed to save", "write error"]
        return dataLossIndicators.contains { error.message.lowercased().contains($0) }
    }
    
    private func checkForSecurityRisk(_ error: TrackedError) -> Bool {
        // Check for security risks
        let securityIndicators = ["unauthorized", "injection", "breach", "exploit", "vulnerability"]
        return securityIndicators.contains { error.message.lowercased().contains($0) }
    }
}

// MARK: - Automated Triage Engine

public class AutomatedTriageEngine {
    private let rules: [TriageRule] = [
        TriageRule(
            condition: { $0.severity == .critical },
            action: .escalate,
            priority: .p1,
            assignee: "on-call",
            reason: "Critical severity error requires immediate attention"
        ),
        TriageRule(
            condition: { $0.classification?.category == .security },
            action: .escalate,
            priority: .p1,
            assignee: "security-team",
            reason: "Security-related error requires security team review"
        ),
        TriageRule(
            condition: { $0.classification?.impact == .critical },
            action: .alert,
            priority: .p1,
            assignee: nil,
            reason: "Critical impact detected"
        ),
        TriageRule(
            condition: { $0.type.contains("NetworkError") && $0.severity <= .warning },
            action: .autoResolve,
            priority: .p4,
            assignee: nil,
            reason: "Transient network error can be auto-resolved"
        ),
        TriageRule(
            condition: { $0.severity == .debug },
            action: .ignore,
            priority: .p4,
            assignee: nil,
            reason: "Debug level error can be ignored in production"
        ),
        TriageRule(
            condition: { $0.classification?.category == .performance && $0.severity == .warning },
            action: .log,
            priority: .p3,
            assignee: nil,
            reason: "Performance warning logged for analysis"
        )
    ]
    
    func triage(_ error: TrackedError) -> TriageResult {
        // Find the first matching rule
        for rule in rules {
            if rule.condition(error) {
                return TriageResult(
                    action: rule.action,
                    priority: rule.priority,
                    assignee: rule.assignee,
                    reason: rule.reason
                )
            }
        }
        
        // Default triage result
        return TriageResult(
            action: .log,
            priority: .p3,
            assignee: nil,
            reason: "Default triage action"
        )
    }
    
    struct TriageRule {
        let condition: (TrackedError) -> Bool
        let action: TriageAction
        let priority: TriagePriority
        let assignee: String?
        let reason: String
    }
}

// MARK: - System State Capture

public class SystemStateCapture {
    
    func capture(completion: @escaping (SystemState) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let state = SystemState(
                memoryUsage: self.getMemoryUsage(),
                cpuUsage: self.getCPUUsage(),
                diskSpace: self.getAvailableDiskSpace(),
                batteryLevel: self.getBatteryLevel(),
                networkStatus: self.getNetworkStatus(),
                activeViewControllers: self.getActiveViewControllers(),
                timestamp: Date()
            )
            
            DispatchQueue.main.async {
                completion(state)
            }
        }
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                        PROCESSOR_CPU_LOAD_INFO,
                                        &numCpus,
                                        &cpuInfo,
                                        &numCpuInfo)
        
        guard result == KERN_SUCCESS else { return 0 }
        
        defer {
            let size = vm_size_t(numCpuInfo * UInt32(MemoryLayout<integer_t>.stride))
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }
        
        var totalUser: Double = 0
        var totalSystem: Double = 0
        var totalIdle: Double = 0
        
        for i in 0..<Int(numCpus) {
            let cpu = cpuInfo[Int(CPU_STATE_MAX) * i]
            totalUser += Double(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_USER)])
            totalSystem += Double(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_SYSTEM)])
            totalIdle += Double(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_IDLE)])
        }
        
        let total = totalUser + totalSystem + totalIdle
        return total > 0 ? ((totalUser + totalSystem) / total) * 100.0 : 0
    }
    
    private func getAvailableDiskSpace() -> UInt64 {
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentDirectory)
            if let freeSpace = attributes[.systemFreeSize] as? NSNumber {
                return freeSpace.uint64Value
            }
        } catch {
            return 0
        }
        
        return 0
    }
    
    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
    
    private func getNetworkStatus() -> String {
        // This would integrate with NetworkPerformanceMonitor
        return "unknown"
    }
    
    private func getActiveViewControllers() -> [String] {
        var controllers: [String] = []
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                if let rootVC = window.rootViewController {
                    controllers.append(contentsOf: getViewControllerHierarchy(rootVC))
                }
            }
        }
        
        return controllers
    }
    
    private func getViewControllerHierarchy(_ viewController: UIViewController) -> [String] {
        var hierarchy: [String] = [String(describing: type(of: viewController))]
        
        if let nav = viewController as? UINavigationController {
            for vc in nav.viewControllers {
                hierarchy.append(contentsOf: getViewControllerHierarchy(vc))
            }
        } else if let tab = viewController as? UITabBarController {
            if let selected = tab.selectedViewController {
                hierarchy.append(contentsOf: getViewControllerHierarchy(selected))
            }
        } else if let presented = viewController.presentedViewController {
            hierarchy.append(contentsOf: getViewControllerHierarchy(presented))
        }
        
        return hierarchy
    }
}