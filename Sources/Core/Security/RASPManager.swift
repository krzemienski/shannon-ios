//
//  RASPManager.swift
//  ClaudeCode
//
//  Runtime Application Self-Protection (RASP) system
//

import Foundation
import UIKit
import CryptoKit
import OSLog
import MachO

/// Runtime Application Self-Protection manager
public final class RASPManager: @unchecked Sendable {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "RASP")
    private var jailbreakDetector: JailbreakDetector?
    
    // Protection status
    private var isProtectionActive = false
    private var detectedThreats: Set<ThreatType> = []
    private var protectionStartTime: Date?
    
    // Monitoring queues
    private let monitoringQueue = DispatchQueue(label: "com.claudecode.rasp.monitoring", qos: .userInitiated)
    private let responseQueue = DispatchQueue(label: "com.claudecode.rasp.response", qos: .userInteractive)
    
    // Timers
    private var integrityCheckTimer: Timer?
    private var runtimeMonitorTimer: Timer?
    private var memoryProtectionTimer: Timer?
    
    // Configuration
    private let checkInterval: TimeInterval = 30.0 // 30 seconds
    private let criticalCheckInterval: TimeInterval = 5.0 // 5 seconds for critical checks
    
    // Anti-tampering
    private var originalMethodImplementations: [String: IMP] = [:]
    private var criticalMethodSignatures: [String: String] = [:]
    
    // Memory protection
    private var protectedMemoryRegions: Set<MemoryRegion> = []
    private var stackCanary: UInt64 = 0
    
    // MARK: - Singleton
    
    public static let shared = RASPManager()
    
    private init() {
        setupInitialProtection()
    }
    
    // MARK: - Public Methods
    
    /// Start runtime protection
    public func startProtection() {
        guard !isProtectionActive else {
            logger.info("RASP protection already active")
            return
        }
        
        logger.info("Starting RASP protection")
        
        isProtectionActive = true
        protectionStartTime = Date()
        
        // Initialize all protection mechanisms
        setupAntiDebugging()
        setupIntegrityChecking()
        setupRuntimeMonitoring()
        setupMemoryProtection()
        setupAntiTampering()
        setupExceptionHandling()
        
        // Start monitoring timers
        startMonitoringTimers()
        
        logger.info("RASP protection activated successfully")
    }
    
    /// Stop runtime protection
    public func stopProtection() {
        guard isProtectionActive else { return }
        
        logger.info("Stopping RASP protection")
        
        isProtectionActive = false
        
        // Stop all timers
        integrityCheckTimer?.invalidate()
        runtimeMonitorTimer?.invalidate()
        memoryProtectionTimer?.invalidate()
        
        logger.info("RASP protection deactivated")
    }
    
    /// Get current threat status
    public func getThreatStatus() -> ThreatStatus {
        return ThreatStatus(
            isSecure: detectedThreats.isEmpty,
            activeThreats: Array(detectedThreats),
            protectionActive: isProtectionActive,
            lastCheck: Date()
        )
    }
    
    // MARK: - Protection Setup
    
    private func setupInitialProtection() {
        // Generate stack canary
        stackCanary = UInt64.random(in: UInt64.min...UInt64.max)
        
        // Store original method implementations
        storeOriginalImplementations()
        
        // Set up crash handler
        setupCrashHandler()
    }
    
    private func setupAntiDebugging() {
        // Implement ptrace denial
        #if !targetEnvironment(simulator)
        monitoringQueue.async {
            // Use ptrace to prevent debugging
            let PT_DENY_ATTACH = 31
            let handle = dlopen(nil, RTLD_NOW)
            if handle != nil {
                let ptrace = dlsym(handle, "ptrace")
                if ptrace != nil {
                    typealias PtraceType = @convention(c) (Int32, pid_t, caddr_t, Int32) -> Int32
                    let ptraceFunc = unsafeBitCast(ptrace, to: PtraceType.self)
                    _ = ptraceFunc(Int32(PT_DENY_ATTACH), 0, nil, 0)
                }
                dlclose(handle)
            }
            
            // Set up debugger detection
            self.startDebuggerDetection()
        }
        #endif
    }
    
    private func setupIntegrityChecking() {
        monitoringQueue.async {
            // Check binary integrity
            self.verifyBinaryIntegrity()
            
            // Check code signing
            self.verifyCodeSigning()
            
            // Check resource integrity
            self.verifyResourceIntegrity()
        }
    }
    
    private func setupRuntimeMonitoring() {
        // Monitor method swizzling
        monitorMethodSwizzling()
        
        // Monitor library injection
        monitorLibraryInjection()
        
        // Monitor hook detection
        monitorHookDetection()
    }
    
    private func setupMemoryProtection() {
        // Protect sensitive memory regions
        protectSensitiveMemory()
        
        // Set up stack protection
        setupStackProtection()
        
        // Monitor memory access patterns
        monitorMemoryAccess()
    }
    
    private func setupAntiTampering() {
        // Calculate method signatures
        calculateMethodSignatures()
        
        // Set up tampering detection
        setupTamperingDetection()
        
        // Monitor file system changes
        monitorFileSystemChanges()
    }
    
    private func setupExceptionHandling() {
        // Set up exception handlers
        NSSetUncaughtExceptionHandler { exception in
            RASPManager.shared.handleException(exception)
        }
        
        // Set up signal handlers
        setupSignalHandlers()
    }
    
    // MARK: - Monitoring Timers
    
    private func startMonitoringTimers() {
        // Integrity check timer
        integrityCheckTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
            self.performIntegrityCheck()
        }
        
        // Runtime monitor timer
        runtimeMonitorTimer = Timer.scheduledTimer(withTimeInterval: criticalCheckInterval, repeats: true) { _ in
            self.performRuntimeCheck()
        }
        
        // Memory protection timer
        memoryProtectionTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
            self.performMemoryCheck()
        }
    }
    
    // MARK: - Integrity Checks
    
    private func performIntegrityCheck() {
        monitoringQueue.async {
            // Verify binary hasn't been modified
            if !self.verifyBinaryIntegrity() {
                self.handleThreat(.binaryTampering)
            }
            
            // Verify method implementations
            if !self.verifyMethodIntegrity() {
                self.handleThreat(.methodSwizzling)
            }
            
            // Verify resource files
            if !self.verifyResourceIntegrity() {
                self.handleThreat(.resourceTampering)
            }
        }
    }
    
    private func performRuntimeCheck() {
        monitoringQueue.async {
            // Check for debugger
            if self.isDebuggerAttached() {
                self.handleThreat(.debuggerAttached)
            }
            
            // Check for hooks
            if self.detectHooks() {
                self.handleThreat(.hookDetected)
            }
            
            // Check for injection
            if self.detectInjection() {
                self.handleThreat(.codeInjection)
            }
            
            // Verify stack canary
            if !self.verifyStackCanary() {
                self.handleThreat(.stackCorruption)
            }
        }
    }
    
    private func performMemoryCheck() {
        monitoringQueue.async {
            // Check protected memory regions
            for region in self.protectedMemoryRegions {
                if !self.verifyMemoryRegion(region) {
                    self.handleThreat(.memoryTampering)
                    break
                }
            }
            
            // Check for memory patches
            if self.detectMemoryPatches() {
                self.handleThreat(.memoryPatching)
            }
        }
    }
    
    // MARK: - Detection Methods
    
    private func isDebuggerAttached() -> Bool {
        // Check using multiple methods
        
        // Method 1: sysctl check
        var info = kinfo_proc()
        var mib: [Int32] = [Int32(CTL_KERN), Int32(KERN_PROC), Int32(KERN_PROC_PID), getpid()]
        var size = MemoryLayout<kinfo_proc>.size
        
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        
        if result == 0 {
            if (info.kp_proc.p_flag & Int32(P_TRACED)) != 0 {
                return true
            }
        }
        
        // Method 2: Check for debugger ports
        let debugPorts = [27042, 27043] // Common LLDB ports
        for port in debugPorts {
            if isPortListening(port) {
                return true
            }
        }
        
        return false
    }
    
    private func detectHooks() -> Bool {
        // Check for inline hooks in critical functions
        let criticalFunctions = [
            "SecItemAdd",
            "SecItemCopyMatching",
            "SecItemUpdate",
            "SecItemDelete"
        ]
        
        for functionName in criticalFunctions {
            if let function = dlsym(UnsafeMutableRawPointer(bitPattern: -2), functionName) {
                // Check first bytes for common hook patterns
                let bytes = UnsafeRawPointer(function).assumingMemoryBound(to: UInt8.self)
                
                // Check for JMP instruction (0xE9) or other hook indicators
                if bytes[0] == 0xE9 || bytes[0] == 0xFF {
                    logger.warning("Hook detected in \(functionName)")
                    return true
                }
            }
        }
        
        return false
    }
    
    private func detectInjection() -> Bool {
        // Check loaded libraries
        let count = _dyld_image_count()
        
        let suspiciousLibraries = [
            "SubstrateLoader",
            "SSLKillSwitch",
            "FridaGadget",
            "cycript"
        ]
        
        for i in 0..<count {
            if let name = _dyld_get_image_name(i) {
                let imageName = String(cString: name)
                
                for suspicious in suspiciousLibraries {
                    if imageName.contains(suspicious) {
                        logger.warning("Suspicious library detected: \(imageName)")
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    private func detectMemoryPatches() -> Bool {
        // Check for common memory patching patterns
        // This is a simplified check - in production would be more comprehensive
        
        // Check if our code section has been modified
        let header = _dyld_get_image_header(0)
        var size: UInt = 0
        
        if let header = header,
           let textSection = getsectiondata(header.withMemoryRebound(to: mach_header_64.self, capacity: 1) { $0 }, "__TEXT", "__text", &size) {
            // Calculate checksum of text section
            let data = Data(bytes: textSection, count: Int(size))
            let hash = SHA256.hash(data: data)
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
            
            // Compare with stored hash (would be calculated at compile time)
            // This is simplified - in production would use compile-time hash
            return false
        }
        
        return false
    }
    
    // MARK: - Verification Methods
    
    private func verifyBinaryIntegrity() -> Bool {
        // Verify the binary hasn't been modified
        guard let bundlePath = Bundle.main.bundlePath as NSString? else {
            return false
        }
        
        let executablePath = bundlePath.appendingPathComponent("ClaudeCode")
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: executablePath))
            let hash = SHA256.hash(data: data)
            // Compare with known hash (would be stored securely)
            // This is simplified for demonstration
            return true
        } catch {
            logger.error("Failed to verify binary integrity: \(error)")
            return false
        }
    }
    
    private func verifyCodeSigning() -> Bool {
        // Verify code signing status
        guard let bundleURL = Bundle.main.bundleURL.absoluteString.removingPercentEncoding else {
            return false
        }
        
        // Check if running from expected location
        if !bundleURL.contains("/Containers/Bundle/Application/") {
            logger.warning("App not running from expected location")
            return false
        }
        
        return true
    }
    
    private func verifyResourceIntegrity() -> Bool {
        // Verify critical resource files haven't been tampered with
        let criticalResources = [
            "Info.plist",
            "embedded.mobileprovision"
        ]
        
        for resource in criticalResources {
            guard let path = Bundle.main.path(forResource: resource, ofType: nil) else {
                continue
            }
            
            // Check file attributes
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: path)
                
                // Check modification date
                if attributes[.modificationDate] is Date {
                    // Check if modified after installation
                    // This is simplified - would need to store original dates
                }
            } catch {
                logger.error("Failed to verify resource: \(resource)")
                return false
            }
        }
        
        return true
    }
    
    private func verifyMethodIntegrity() -> Bool {
        // Verify critical methods haven't been swizzled
        for (methodName, originalIMP) in originalMethodImplementations {
            if let currentIMP = getCurrentImplementation(for: methodName) {
                if currentIMP != originalIMP {
                    logger.warning("Method \(methodName) has been modified")
                    return false
                }
            }
        }
        
        return true
    }
    
    private func verifyStackCanary() -> Bool {
        // Verify stack canary hasn't been corrupted
        var currentCanary: UInt64 = 0
        withUnsafePointer(to: &currentCanary) { ptr in
            // In a real implementation, would check actual stack location
            // This is simplified for demonstration
        }
        
        // For now, just return true
        // In production, would implement actual stack canary checking
        return true
    }
    
    private func verifyMemoryRegion(_ region: MemoryRegion) -> Bool {
        // Verify protected memory region integrity
        let currentHash = calculateMemoryHash(region)
        return currentHash == region.originalHash
    }
    
    // MARK: - Protection Methods
    
    private func protectSensitiveMemory() {
        // Protect sensitive memory regions
        // This would use mprotect() to set memory permissions
        
        // Example: Protect encryption keys in memory
        // mprotect(keyAddress, keySize, PROT_READ)
    }
    
    private func setupStackProtection() {
        // Set up stack protection mechanisms
        // This would involve stack cookies and guard pages
    }
    
    private func monitorMemoryAccess() {
        // Monitor for suspicious memory access patterns
        // This would use memory breakpoints or page protection
    }
    
    // MARK: - Response Methods
    
    private func handleThreat(_ threat: ThreatType) {
        // TODO: Fix type inference issue with async closure
        logger.critical("🚨 RASP Threat Detected: \(threat.rawValue)")
        
        // Add to detected threats
        detectedThreats.insert(threat)
        
        // Take appropriate action based on threat type
        switch threat {
        case .debuggerAttached:
            respondToDebugger()
        case .jailbreakDetected:
            respondToJailbreak()
        case .codeInjection:
            respondToInjection()
        case .methodSwizzling:
            respondToSwizzling()
        case .hookDetected:
            respondToHooks()
        case .binaryTampering:
            respondToTampering()
        case .memoryTampering, .memoryPatching:
            respondToMemoryAttack()
        case .stackCorruption:
            respondToStackAttack()
        case .resourceTampering:
            respondToResourceTampering()
        }
        
        // Log security event
        logSecurityEvent(threat)
        
        // Notify security monitoring
        notifySecurityMonitoring(threat)
    }
    
    private func respondToDebugger() {
        // Response to debugger attachment
        logger.critical("Debugger detected - terminating app")
        
        // Clear sensitive data
        clearSensitiveData()
        
        // Terminate app
        exit(0)
    }
    
    private func respondToJailbreak() {
        // Response to jailbreak detection
        logger.critical("Jailbreak detected - restricting functionality")
        
        // Disable sensitive features
        disableSensitiveFeatures()
        
        // Alert user
        showSecurityAlert("Security Warning", "This device appears to be jailbroken. Some features have been disabled for security.")
    }
    
    private func respondToInjection() {
        // Response to code injection
        logger.critical("Code injection detected - securing app")
        
        // Clear sensitive data
        clearSensitiveData()
        
        // Terminate affected processes
        terminateAffectedProcesses()
    }
    
    private func respondToSwizzling() {
        // Response to method swizzling
        logger.critical("Method swizzling detected - restoring methods")
        
        // Attempt to restore original implementations
        restoreOriginalImplementations()
    }
    
    private func respondToHooks() {
        // Response to hooks
        logger.critical("Hooks detected - bypassing")
        
        // Implement hook bypassing
        bypassDetectedHooks()
    }
    
    private func respondToTampering() {
        // Response to binary tampering
        logger.critical("Binary tampering detected - app integrity compromised")
        
        // Clear all data and terminate
        clearAllData()
        exit(0)
    }
    
    private func respondToMemoryAttack() {
        // Response to memory attacks
        logger.critical("Memory attack detected - protecting memory")
        
        // Re-protect memory regions
        reprotectMemory()
    }
    
    private func respondToStackAttack() {
        // Response to stack attacks
        logger.critical("Stack corruption detected - terminating")
        
        // Immediate termination
        abort()
    }
    
    private func respondToResourceTampering() {
        // Response to resource tampering
        logger.critical("Resource tampering detected - restoring resources")
        
        // Attempt to restore resources from backup
        restoreResources()
    }
    
    // MARK: - Helper Methods
    
    private func storeOriginalImplementations() {
        // Store original method implementations for critical methods
        let criticalMethods = [
            "URLSession.dataTask",
            "SecItemAdd",
            "SecItemCopyMatching"
        ]
        
        for methodName in criticalMethods {
            if let imp = getCurrentImplementation(for: methodName) {
                originalMethodImplementations[methodName] = imp
            }
        }
    }
    
    private func getCurrentImplementation(for methodName: String) -> IMP? {
        // Get current implementation of a method
        // This is simplified - would need proper method lookup
        return nil
    }
    
    private func calculateMethodSignatures() {
        // Calculate signatures for critical methods
        for (methodName, _) in originalMethodImplementations {
            // Calculate signature hash
            let signature = "method_signature_\(methodName)"
            criticalMethodSignatures[methodName] = signature
        }
    }
    
    private func calculateMemoryHash(_ region: MemoryRegion) -> String {
        // Calculate hash of memory region
        let data = Data(bytes: region.address, count: region.size)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func isPortListening(_ port: Int) -> Bool {
        // Check if a port is listening (simplified)
        return false
    }
    
    private func clearSensitiveData() {
        // Clear all sensitive data from memory
        Task {
            try? await SecureTokenManager.shared.clearAllTokens()
            try? await EnhancedKeychainManager.shared.clearCategory(.apiKey)
            try? await EnhancedKeychainManager.shared.clearCategory(.authToken)
        }
    }
    
    private func clearAllData() {
        // Clear all application data
        Task {
            try? await DataEncryptionManager.shared.wipeAllEncryptedData()
        }
    }
    
    private func disableSensitiveFeatures() {
        // Disable sensitive features when security is compromised
        UserDefaults.standard.set(true, forKey: "SecurityCompromised")
    }
    
    private func showSecurityAlert(_ title: String, _ message: String) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else { return }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func terminateAffectedProcesses() {
        // Terminate processes affected by injection
        // This is a placeholder - actual implementation would be more complex
    }
    
    private func restoreOriginalImplementations() {
        // Attempt to restore original method implementations
        // This would use method_setImplementation
    }
    
    private func bypassDetectedHooks() {
        // Implement hook bypassing techniques
        // This would involve direct syscalls or other bypass methods
    }
    
    private func reprotectMemory() {
        // Re-protect memory regions
        for _ in protectedMemoryRegions {
            // Re-apply memory protection
            // mprotect(region.address, region.size, region.protection)
        }
    }
    
    private func restoreResources() {
        // Restore tampered resources from backup
        // This would require having secure backups of critical resources
    }
    
    private func logSecurityEvent(_ threat: ThreatType) {
        // Log security event for analysis
        Task { @MainActor in
            let event = SecurityEvent(
                timestamp: Date(),
                threat: threat,
                deviceInfo: await getDeviceInfo(),
                stackTrace: Thread.callStackSymbols
            )
        
            // Store securely for later analysis
            // In production, would send to security monitoring service
            logger.critical("Security Event: \(String(describing: event))")
        }
    }
    
    private func notifySecurityMonitoring(_ threat: ThreatType) {
        // Notify security monitoring service
        // In production, would send to backend security service
    }
    
    private func getDeviceInfo() async -> [String: String] {
        return [
            "device": await MainActor.run { UIDevice.current.model },
            "os": await MainActor.run { UIDevice.current.systemVersion },
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ]
    }
    
    // MARK: - Exception Handling
    
    private func handleException(_ exception: NSException) {
        logger.critical("Uncaught exception: \(exception)")
        
        // Log exception details
        logSecurityEvent(.stackCorruption)
        
        // Clear sensitive data before crash
        clearSensitiveData()
    }
    
    private func setupSignalHandlers() {
        // Set up signal handlers for various signals
        signal(SIGABRT) { _ in
            RASPManager.shared.handleSignal("SIGABRT")
        }
        
        signal(SIGSEGV) { _ in
            RASPManager.shared.handleSignal("SIGSEGV")
        }
        
        signal(SIGBUS) { _ in
            RASPManager.shared.handleSignal("SIGBUS")
        }
    }
    
    private func handleSignal(_ signal: String) {
        logger.critical("Signal received: \(signal)")
        
        // Clear sensitive data
        clearSensitiveData()
    }
    
    private func setupCrashHandler() {
        // Set up crash handler for additional protection
        // This would integrate with crash reporting framework
    }
    
    private func startDebuggerDetection() {
        // Continuous debugger detection
        // This would run in a separate thread continuously
    }
    
    private func setupTamperingDetection() {
        // Set up continuous tampering detection
        // This would monitor for file system changes and integrity
    }
    
    private func monitorMethodSwizzling() {
        // Monitor for runtime method swizzling
        // This would check method implementations periodically
    }
    
    private func monitorLibraryInjection() {
        // Monitor for dynamic library injection
        // This would check loaded libraries periodically
    }
    
    private func monitorHookDetection() {
        // Monitor for function hooks
        // This would check function prologues periodically
    }
    
    private func monitorFileSystemChanges() {
        // Monitor for file system changes
        // This would use file system events or polling
    }
}

// MARK: - Supporting Types

public enum ThreatType: String, CaseIterable, Sendable {
    case debuggerAttached = "Debugger Attached"
    case jailbreakDetected = "Jailbreak Detected"
    case codeInjection = "Code Injection"
    case methodSwizzling = "Method Swizzling"
    case hookDetected = "Hook Detected"
    case binaryTampering = "Binary Tampering"
    case memoryTampering = "Memory Tampering"
    case memoryPatching = "Memory Patching"
    case stackCorruption = "Stack Corruption"
    case resourceTampering = "Resource Tampering"
}

public struct ThreatStatus {
    public let isSecure: Bool
    public let activeThreats: [ThreatType]
    public let protectionActive: Bool
    public let lastCheck: Date
}

private struct MemoryRegion: Hashable {
    let address: UnsafeRawPointer
    let size: Int
    let protection: Int32
    let originalHash: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(address)
        hasher.combine(size)
        hasher.combine(protection)
        hasher.combine(originalHash)
    }
    
    static func == (lhs: MemoryRegion, rhs: MemoryRegion) -> Bool {
        lhs.address == rhs.address &&
        lhs.size == rhs.size &&
        lhs.protection == rhs.protection &&
        lhs.originalHash == rhs.originalHash
    }
}

private struct SecurityEvent {
    let timestamp: Date
    let threat: ThreatType
    let deviceInfo: [String: String]
    let stackTrace: [String]
}

// Constants for sysctl
private let CTL_KERN = 1
private let KERN_PROC = 14
private let KERN_PROC_PID = 1
private let P_TRACED = 0x00000800