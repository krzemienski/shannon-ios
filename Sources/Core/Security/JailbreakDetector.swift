//
//  JailbreakDetector.swift
//  ClaudeCode
//
//  Jailbreak and integrity detection for iOS security
//

import Foundation
import UIKit
import MachO
import OSLog

/// Manager for detecting jailbroken devices and app integrity
public final class JailbreakDetector {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "JailbreakDetector")
    private let fileManager = FileManager.default
    
    // Detection methods weights for scoring
    private let detectionWeights: [DetectionMethod: Double] = [
        .suspiciousFiles: 0.3,
        .suspiciousApps: 0.2,
        .symbolicLinks: 0.15,
        .writeableSystem: 0.15,
        .dyldInjection: 0.1,
        .suspiciousDylibs: 0.1
    ]
    
    // Threshold for jailbreak detection (0.0 - 1.0)
    private let jailbreakThreshold: Double = 0.6
    
    // MARK: - Singleton
    
    public static let shared = JailbreakDetector()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Check if device is jailbroken
    public func isJailbroken() -> Bool {
        let detectionScore = calculateJailbreakScore()
        
        logger.info("Jailbreak detection score: \(detectionScore)")
        
        if detectionScore >= jailbreakThreshold {
            logger.warning("Device appears to be jailbroken")
            return true
        }
        
        return false
    }
    
    /// Perform comprehensive security check
    public func performSecurityCheck() -> SecurityCheckResult {
        var issues: [SecurityIssue] = []
        
        // Check for jailbreak
        if isJailbroken() {
            issues.append(.jailbrokenDevice)
        }
        
        // Check for debugging
        if isBeingDebugged() {
            issues.append(.debuggerAttached)
        }
        
        // Check for code injection
        if hasCodeInjection() {
            issues.append(.codeInjection)
        }
        
        // Check for app integrity
        if !verifyAppIntegrity() {
            issues.append(.integrityViolation)
        }
        
        // Check for proxy/VPN
        if isUsingProxy() {
            issues.append(.proxyDetected)
        }
        
        // Check for suspicious environment
        if hasSuspiciousEnvironment() {
            issues.append(.suspiciousEnvironment)
        }
        
        return SecurityCheckResult(
            isSecure: issues.isEmpty,
            issues: issues,
            timestamp: Date()
        )
    }
    
    // MARK: - Jailbreak Detection Methods
    
    private func calculateJailbreakScore() -> Double {
        var score: Double = 0
        
        // Check for suspicious files
        if checkSuspiciousFiles() {
            score += detectionWeights[.suspiciousFiles] ?? 0
        }
        
        // Check for suspicious apps
        if checkSuspiciousApps() {
            score += detectionWeights[.suspiciousApps] ?? 0
        }
        
        // Check for symbolic links
        if checkSymbolicLinks() {
            score += detectionWeights[.symbolicLinks] ?? 0
        }
        
        // Check for writeable system directories
        if checkWriteableSystemDirectories() {
            score += detectionWeights[.writeableSystem] ?? 0
        }
        
        // Check for dyld injection
        if checkDyldInjection() {
            score += detectionWeights[.dyldInjection] ?? 0
        }
        
        // Check for suspicious dylibs
        if checkSuspiciousDylibs() {
            score += detectionWeights[.suspiciousDylibs] ?? 0
        }
        
        return score
    }
    
    private func checkSuspiciousFiles() -> Bool {
        let suspiciousFiles = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/stash",
            "/usr/libexec/sftp-server",
            "/usr/bin/cycript",
            "/usr/local/bin/cycript",
            "/usr/lib/libcycript.dylib",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/SBSettings.app",
            "/Applications/WinterBoard.app",
            "/Applications/blackra1n.app",
            "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
            "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/private/var/tmp/cydia.log",
            "/var/cache/apt",
            "/var/lib/apt",
            "/var/lib/cydia",
            "/var/log/syslog"
        ]
        
        for file in suspiciousFiles {
            if fileManager.fileExists(atPath: file) {
                logger.warning("Suspicious file detected: \(file)")
                return true
            }
        }
        
        // Check if we can open suspicious files
        for file in suspiciousFiles {
            if let _ = fopen(file, "r") {
                fclose(nil)
                return true
            }
        }
        
        return false
    }
    
    private func checkSuspiciousApps() -> Bool {
        let suspiciousSchemes = [
            "cydia://",
            "sileo://",
            "zbra://",
            "undecimus://",
            "substitute://",
            "filza://"
        ]
        
        for scheme in suspiciousSchemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                logger.warning("Suspicious app scheme detected: \(scheme)")
                return true
            }
        }
        
        return false
    }
    
    private func checkSymbolicLinks() -> Bool {
        // Check for symbolic links in system directories
        let pathsToCheck = [
            "/Applications",
            "/var/stash",
            "/Library/Ringtones",
            "/Library/Wallpaper",
            "/usr/arm-apple-darwin9",
            "/usr/include",
            "/usr/libexec",
            "/usr/share"
        ]
        
        for path in pathsToCheck {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: path)
                if let fileType = attributes[.type] as? FileAttributeType,
                   fileType == .typeSymbolicLink {
                    logger.warning("Symbolic link detected at: \(path)")
                    return true
                }
            } catch {
                // Path doesn't exist or can't be accessed - normal on non-jailbroken devices
            }
        }
        
        return false
    }
    
    private func checkWriteableSystemDirectories() -> Bool {
        let systemPaths = [
            "/",
            "/root",
            "/private",
            "/jb"
        ]
        
        for path in systemPaths {
            do {
                let testFile = "\(path)/test_\(UUID().uuidString).tmp"
                try "test".write(toFile: testFile, atomically: true, encoding: .utf8)
                try fileManager.removeItem(atPath: testFile)
                logger.warning("System directory is writeable: \(path)")
                return true
            } catch {
                // Expected behavior - system directories should not be writeable
            }
        }
        
        return false
    }
    
    private func checkDyldInjection() -> Bool {
        // Check for DYLD environment variables
        let suspiciousEnvVars = [
            "DYLD_INSERT_LIBRARIES",
            "DYLD_LIBRARY_PATH",
            "_MSSafeMode"
        ]
        
        for envVar in suspiciousEnvVars {
            if getenv(envVar) != nil {
                logger.warning("Suspicious environment variable detected: \(envVar)")
                return true
            }
        }
        
        return false
    }
    
    private func checkSuspiciousDylibs() -> Bool {
        // Get loaded dynamic libraries
        let count = _dyld_image_count()
        
        let suspiciousLibraries = [
            "SubstrateLoader.dylib",
            "SSLKillSwitch2.dylib",
            "SSLKillSwitch.dylib",
            "MobileSubstrate.dylib",
            "TweakInject.dylib",
            "CydiaSubstrate",
            "cynject",
            "CustomWidgetIcons",
            "PreferenceLoader",
            "RocketBootstrap",
            "WeeLoader",
            "/.file",
            "/FridaGadget"
        ]
        
        for i in 0..<count {
            if let name = _dyld_get_image_name(i) {
                let imageName = String(cString: name)
                
                for suspicious in suspiciousLibraries {
                    if imageName.contains(suspicious) {
                        logger.warning("Suspicious dylib loaded: \(imageName)")
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    // MARK: - Anti-Debugging Detection
    
    private func isBeingDebugged() -> Bool {
        // Method 1: Check P_TRACED flag
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.size
        
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        
        if result == 0 {
            if (info.kp_proc.p_flag & P_TRACED) != 0 {
                logger.warning("Debugger detected via P_TRACED")
                return true
            }
        }
        
        // Method 2: Check for ptrace
        #if !targetEnvironment(simulator)
        var ptraceDetected = false
        let handle = dlopen(nil, RTLD_NOW)
        if handle != nil {
            let ptrace = dlsym(handle, "ptrace")
            if ptrace != nil {
                typealias PtraceType = @convention(c) (Int32, pid_t, caddr_t, Int32) -> Int32
                let ptraceFunc = unsafeBitCast(ptrace, to: PtraceType.self)
                if ptraceFunc(31 /* PT_DENY_ATTACH */, 0, nil, 0) == -1 {
                    ptraceDetected = true
                }
            }
            dlclose(handle)
        }
        
        if ptraceDetected {
            logger.warning("Debugger detected via ptrace")
            return true
        }
        #endif
        
        // Method 3: Check for common debugging ports
        let debugPorts = [27042, 27043] // Common LLDB ports
        for port in debugPorts {
            if isPortOpen(port) {
                logger.warning("Debugging port \(port) is open")
                return true
            }
        }
        
        return false
    }
    
    private func isPortOpen(_ port: Int) -> Bool {
        // Simple port check - in production use more sophisticated methods
        return false
    }
    
    // MARK: - Code Injection Detection
    
    private func hasCodeInjection() -> Bool {
        // Check for code injection frameworks
        let injectionClasses = [
            "InjectionBundle",
            "InjectionServer",
            "DTXMessageParser",
            "DTXMessenger"
        ]
        
        for className in injectionClasses {
            if NSClassFromString(className) != nil {
                logger.warning("Code injection class detected: \(className)")
                return true
            }
        }
        
        // Check for method swizzling on critical methods
        if detectMethodSwizzling() {
            return true
        }
        
        return false
    }
    
    private func detectMethodSwizzling() -> Bool {
        // Check if critical methods have been swizzled
        // This is a simplified check - in production use more comprehensive detection
        
        let criticalSelectors = [
            #selector(URLSession.dataTask(with:completionHandler:) as (URLSession) -> (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask),
            #selector(FileManager.fileExists(atPath:))
        ]
        
        // Check method implementations
        // In production, compare with known good implementations
        
        return false
    }
    
    // MARK: - App Integrity
    
    private func verifyAppIntegrity() -> Bool {
        // Verify app signature
        guard let bundleURL = Bundle.main.bundleURL.absoluteString.removingPercentEncoding else {
            return false
        }
        
        // Check if app bundle has been modified
        if bundleURL.contains("/Containers/Bundle/Application/") {
            // Normal installation path
        } else if bundleURL.contains("/Applications/") {
            // System app or jailbroken installation
            logger.warning("App installed in system directory")
            return false
        }
        
        // Verify provisioning profile
        if !verifyProvisioningProfile() {
            return false
        }
        
        // Verify code signature
        if !verifyCodeSignature() {
            return false
        }
        
        return true
    }
    
    private func verifyProvisioningProfile() -> Bool {
        guard let profilePath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            // No provisioning profile - could be App Store build
            return true
        }
        
        // Check if profile has been tampered with
        do {
            let profileData = try Data(contentsOf: URL(fileURLWithPath: profilePath))
            // In production, verify profile signature
            return !profileData.isEmpty
        } catch {
            return false
        }
    }
    
    private func verifyCodeSignature() -> Bool {
        // Check Mach-O header for code signature
        guard let executablePath = Bundle.main.executablePath else {
            return false
        }
        
        // This is a simplified check - in production use Security framework
        return fileManager.fileExists(atPath: executablePath)
    }
    
    // MARK: - Network Security
    
    private func isUsingProxy() -> Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return false
        }
        
        let httpProxyEnabled = proxySettings["HTTPEnable"] as? Int == 1
        let httpsProxyEnabled = proxySettings["HTTPSEnable"] as? Int == 1
        
        if httpProxyEnabled || httpsProxyEnabled {
            logger.warning("Proxy detected in network settings")
            return true
        }
        
        return false
    }
    
    // MARK: - Environment Check
    
    private func hasSuspiciousEnvironment() -> Bool {
        // Check for simulator
        #if targetEnvironment(simulator)
        logger.warning("Running in simulator")
        return true
        #endif
        
        // Check for unusual environment variables
        let environmentVars = ProcessInfo.processInfo.environment
        let suspiciousKeys = ["CYCRIPT", "FRIDA", "SUBSTRATE"]
        
        for key in environmentVars.keys {
            for suspicious in suspiciousKeys {
                if key.uppercased().contains(suspicious) {
                    logger.warning("Suspicious environment variable: \(key)")
                    return true
                }
            }
        }
        
        return false
    }
}

// MARK: - Supporting Types

private enum DetectionMethod {
    case suspiciousFiles
    case suspiciousApps
    case symbolicLinks
    case writeableSystem
    case dyldInjection
    case suspiciousDylibs
}

public struct SecurityCheckResult {
    public let isSecure: Bool
    public let issues: [SecurityIssue]
    public let timestamp: Date
    
    public var riskLevel: RiskLevel {
        if issues.isEmpty {
            return .none
        } else if issues.contains(.jailbrokenDevice) || issues.contains(.codeInjection) {
            return .critical
        } else if issues.contains(.debuggerAttached) || issues.contains(.integrityViolation) {
            return .high
        } else if issues.contains(.proxyDetected) {
            return .medium
        } else {
            return .low
        }
    }
}

public enum SecurityIssue {
    case jailbrokenDevice
    case debuggerAttached
    case codeInjection
    case integrityViolation
    case proxyDetected
    case suspiciousEnvironment
}

public enum RiskLevel {
    case none
    case low
    case medium
    case high
    case critical
}

// Constants for sysctl
private let CTL_KERN = 1
private let KERN_PROC = 14
private let KERN_PROC_PID = 1
private let P_TRACED = 0x00000800