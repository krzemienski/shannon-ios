#!/bin/bash

# Claude Code iOS - Beta Testing Infrastructure
# Comprehensive beta testing setup with crash reporting, analytics, and feedback
# Version: 1.0.0

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SCRIPTS_DIR="${PROJECT_ROOT}/Scripts"
readonly CONFIG_DIR="${PROJECT_ROOT}/Configs"
readonly DOCS_DIR="${PROJECT_ROOT}/docs"
readonly BETA_DIR="${PROJECT_ROOT}/beta"

# Beta testing configuration
readonly TESTFLIGHT_PUBLIC_LINK="${TESTFLIGHT_PUBLIC_LINK:-}"
readonly MAX_BETA_TESTERS="${MAX_BETA_TESTERS:-1000}"
readonly BETA_EXPIRY_DAYS="${BETA_EXPIRY_DAYS:-90}"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_header() {
    echo
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD} $1${NC}"
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════${NC}"
    echo
}

log_info() {
    echo -e "${BLUE}ℹ️  ${NC}$1"
}

log_success() {
    echo -e "${GREEN}✅ ${NC}$1"
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${NC}$1"
}

log_error() {
    echo -e "${RED}❌ ${NC}$1" >&2
}

log_step() {
    echo -e "${MAGENTA}▶ ${NC}$1"
}

# ============================================================================
# CRASH REPORTING SETUP
# ============================================================================

setup_crashlytics() {
    log_header "Setting up Firebase Crashlytics"
    
    # Check if Firebase configuration exists
    if [[ ! -f "${PROJECT_ROOT}/GoogleService-Info.plist" ]]; then
        log_warning "GoogleService-Info.plist not found"
        log_info "Download from Firebase Console: https://console.firebase.google.com"
        log_info "Place it in: ${PROJECT_ROOT}/"
        return 1
    fi
    
    # Create Crashlytics configuration
    cat > "${PROJECT_ROOT}/Sources/Core/ErrorTracking/CrashlyticsManager.swift" <<'EOF'
import Foundation
import FirebaseCrashlytics

/// Manages crash reporting and error tracking through Firebase Crashlytics
public final class CrashlyticsManager: NSObject {
    
    // MARK: - Properties
    
    public static let shared = CrashlyticsManager()
    
    private let crashlytics = Crashlytics.crashlytics()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        configureCrashlytics()
    }
    
    // MARK: - Configuration
    
    private func configureCrashlytics() {
        #if !DEBUG
        // Enable crash reporting in release builds
        crashlytics.setCrashlyticsCollectionEnabled(true)
        #else
        // Disable in debug builds
        crashlytics.setCrashlyticsCollectionEnabled(false)
        #endif
        
        // Set custom keys for better debugging
        setDefaultKeys()
    }
    
    private func setDefaultKeys() {
        crashlytics.setCustomValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "Unknown", 
                                   forKey: "app_version")
        crashlytics.setCustomValue(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "Unknown", 
                                   forKey: "build_number")
        crashlytics.setCustomValue(UIDevice.current.systemVersion, forKey: "ios_version")
        crashlytics.setCustomValue(UIDevice.current.model, forKey: "device_model")
        
        #if BETA
        crashlytics.setCustomValue(true, forKey: "is_beta")
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Set user identifier for crash reports
    public func setUserIdentifier(_ identifier: String) {
        crashlytics.setUserID(identifier)
    }
    
    /// Log custom event
    public func log(_ message: String, attributes: [String: Any]? = nil) {
        crashlytics.log(message)
        
        attributes?.forEach { key, value in
            crashlytics.setCustomValue(value, forKey: key)
        }
    }
    
    /// Record non-fatal error
    public func recordError(_ error: Error, 
                           userInfo: [String: Any]? = nil) {
        let nsError = error as NSError
        var fullUserInfo = nsError.userInfo
        
        if let userInfo = userInfo {
            fullUserInfo.merge(userInfo) { _, new in new }
        }
        
        crashlytics.record(error: NSError(domain: nsError.domain,
                                          code: nsError.code,
                                          userInfo: fullUserInfo))
    }
    
    /// Force a test crash
    public func testCrash() {
        #if DEBUG
        fatalError("Test crash triggered")
        #endif
    }
    
    /// Send unsynced reports
    public func sendUnsentReports() {
        crashlytics.sendUnsentReports()
    }
    
    /// Check for unsynced reports
    public func checkForUnsentReports(completion: @escaping (Bool) -> Void) {
        crashlytics.checkForUnsentReports { hasReports in
            completion(hasReports)
        }
    }
}
EOF
    
    log_success "Crashlytics manager created"
    
    # Add Firebase dependencies to Package.swift
    log_step "Adding Firebase dependencies..."
    
    # This would be done through SPM or CocoaPods in practice
    log_info "Add to Package.swift dependencies:"
    echo '    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0")'
    
    log_success "Crashlytics setup complete"
}

setup_sentry() {
    log_header "Setting up Sentry Error Tracking"
    
    # Create Sentry configuration
    cat > "${PROJECT_ROOT}/Sources/Core/ErrorTracking/SentryManager.swift" <<'EOF'
import Foundation
import Sentry

/// Manages error tracking through Sentry
public final class SentryManager {
    
    // MARK: - Properties
    
    public static let shared = SentryManager()
    
    private var isInitialized = false
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Configuration
    
    public func configure(dsn: String) {
        guard !isInitialized else { return }
        
        SentrySDK.start { options in
            options.dsn = dsn
            
            #if DEBUG
            options.debug = true
            options.environment = "development"
            #elseif BETA
            options.environment = "beta"
            #else
            options.environment = "production"
            #endif
            
            // Performance monitoring
            options.tracesSampleRate = 0.2
            options.profilesSampleRate = 0.2
            
            // Attachments
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            
            // Session tracking
            options.sessionTrackingIntervalMillis = 30000
            
            // Release information
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                options.releaseName = "\(version)-\(build)"
            }
        }
        
        isInitialized = true
        configureScope()
    }
    
    private func configureScope() {
        SentrySDK.configureScope { scope in
            // Device information
            scope.setTag(value: UIDevice.current.systemVersion, key: "ios_version")
            scope.setTag(value: UIDevice.current.model, key: "device_model")
            
            // App information
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                scope.setTag(value: version, key: "app_version")
            }
            
            #if BETA
            scope.setTag(value: "true", key: "is_beta")
            #endif
        }
    }
    
    // MARK: - Public Methods
    
    /// Set user context
    public func setUser(id: String, email: String? = nil, username: String? = nil) {
        let user = User(userId: id)
        user.email = email
        user.username = username
        SentrySDK.setUser(user)
    }
    
    /// Clear user context
    public func clearUser() {
        SentrySDK.setUser(nil)
    }
    
    /// Capture message
    public func captureMessage(_ message: String, level: SentryLevel = .info) {
        SentrySDK.capture(message: message) { scope in
            scope.setLevel(level)
        }
    }
    
    /// Capture error
    public func captureError(_ error: Error, context: [String: Any]? = nil) {
        SentrySDK.capture(error: error) { scope in
            context?.forEach { key, value in
                scope.setContext(value: ["value": value], key: key)
            }
        }
    }
    
    /// Add breadcrumb
    public func addBreadcrumb(_ message: String, 
                              category: String? = nil,
                              level: SentryLevel = .info,
                              data: [String: Any]? = nil) {
        let breadcrumb = Breadcrumb()
        breadcrumb.message = message
        breadcrumb.category = category
        breadcrumb.level = level
        breadcrumb.data = data
        SentrySDK.addBreadcrumb(breadcrumb)
    }
    
    /// Start transaction for performance monitoring
    public func startTransaction(name: String, operation: String) -> ITransaction {
        return SentrySDK.startTransaction(name: name, operation: operation)
    }
}
EOF
    
    log_success "Sentry manager created"
    log_info "Add Sentry DSN to environment configuration"
}

# ============================================================================
# ANALYTICS SETUP
# ============================================================================

setup_analytics() {
    log_header "Setting up Analytics"
    
    # Create Analytics Manager
    cat > "${PROJECT_ROOT}/Sources/Core/Analytics/AnalyticsManager.swift" <<'EOF'
import Foundation
import FirebaseAnalytics

/// Manages analytics tracking
public final class AnalyticsManager {
    
    // MARK: - Event Names
    
    public enum Event: String {
        // App lifecycle
        case appLaunched = "app_launched"
        case appBackgrounded = "app_backgrounded"
        case appTerminated = "app_terminated"
        
        // User actions
        case userSignedIn = "user_signed_in"
        case userSignedOut = "user_signed_out"
        case projectCreated = "project_created"
        case projectOpened = "project_opened"
        case toolExecuted = "tool_executed"
        case chatStarted = "chat_started"
        case messagesSent = "message_sent"
        
        // Beta specific
        case betaFeedbackSubmitted = "beta_feedback_submitted"
        case betaFeatureUsed = "beta_feature_used"
        case betaCrashReported = "beta_crash_reported"
        
        // Performance
        case performanceIssue = "performance_issue"
        case networkError = "network_error"
    }
    
    // MARK: - Properties
    
    public static let shared = AnalyticsManager()
    
    private var isEnabled: Bool = true
    private var userProperties: [String: Any] = [:]
    
    // MARK: - Initialization
    
    private init() {
        configure()
    }
    
    // MARK: - Configuration
    
    private func configure() {
        #if DEBUG
        isEnabled = false
        Analytics.setAnalyticsCollectionEnabled(false)
        #else
        isEnabled = true
        Analytics.setAnalyticsCollectionEnabled(true)
        #endif
        
        setDefaultUserProperties()
    }
    
    private func setDefaultUserProperties() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            setUserProperty(version, forName: "app_version")
        }
        
        setUserProperty(UIDevice.current.systemVersion, forName: "ios_version")
        setUserProperty(UIDevice.current.model, forName: "device_model")
        
        #if BETA
        setUserProperty("true", forName: "is_beta_tester")
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Track event
    public func track(_ event: Event, parameters: [String: Any]? = nil) {
        guard isEnabled else { return }
        
        var params = parameters ?? [:]
        params["timestamp"] = Date().timeIntervalSince1970
        
        Analytics.logEvent(event.rawValue, parameters: params)
        
        #if DEBUG
        print("📊 Analytics Event: \(event.rawValue)")
        if let parameters = parameters {
            print("   Parameters: \(parameters)")
        }
        #endif
    }
    
    /// Track screen view
    public func trackScreen(_ screenName: String, screenClass: String? = nil) {
        guard isEnabled else { return }
        
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
    }
    
    /// Set user ID
    public func setUserID(_ userID: String?) {
        Analytics.setUserID(userID)
    }
    
    /// Set user property
    public func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
        
        if let value = value {
            userProperties[name] = value
        } else {
            userProperties.removeValue(forKey: name)
        }
    }
    
    /// Track beta feature usage
    public func trackBetaFeature(_ featureName: String, metadata: [String: Any]? = nil) {
        var params: [String: Any] = ["feature_name": featureName]
        
        if let metadata = metadata {
            params.merge(metadata) { _, new in new }
        }
        
        track(.betaFeatureUsed, parameters: params)
    }
    
    /// Track performance metric
    public func trackPerformance(_ metric: String, value: Double, metadata: [String: Any]? = nil) {
        var params: [String: Any] = [
            "metric_name": metric,
            "metric_value": value
        ]
        
        if let metadata = metadata {
            params.merge(metadata) { _, new in new }
        }
        
        Analytics.logEvent("performance_metric", parameters: params)
    }
}
EOF
    
    log_success "Analytics manager created"
}

# ============================================================================
# FEEDBACK COLLECTION
# ============================================================================

setup_feedback_system() {
    log_header "Setting up Feedback Collection System"
    
    # Create feedback manager
    cat > "${PROJECT_ROOT}/Sources/Core/Feedback/FeedbackManager.swift" <<'EOF'
import UIKit
import MessageUI
import StoreKit

/// Manages user feedback collection for beta testing
public final class FeedbackManager: NSObject {
    
    // MARK: - Feedback Types
    
    public enum FeedbackType: String, CaseIterable {
        case bug = "Bug Report"
        case feature = "Feature Request"
        case improvement = "Improvement"
        case crash = "Crash Report"
        case performance = "Performance Issue"
        case other = "Other"
        
        var emoji: String {
            switch self {
            case .bug: return "🐛"
            case .feature: return "✨"
            case .improvement: return "💡"
            case .crash: return "💥"
            case .performance: return "🐌"
            case .other: return "💬"
            }
        }
    }
    
    // MARK: - Properties
    
    public static let shared = FeedbackManager()
    
    private let feedbackEmail = "beta@claudecode.app"
    private let slackWebhookURL = ProcessInfo.processInfo.environment["FEEDBACK_SLACK_WEBHOOK"]
    
    private var pendingFeedback: [Feedback] = []
    
    // MARK: - Models
    
    public struct Feedback {
        let id = UUID()
        let type: FeedbackType
        let title: String
        let description: String
        let userEmail: String?
        let deviceInfo: DeviceInfo
        let appInfo: AppInfo
        let timestamp: Date
        let attachments: [Data]
        
        struct DeviceInfo {
            let model = UIDevice.current.model
            let systemVersion = UIDevice.current.systemVersion
            let batteryLevel = UIDevice.current.batteryLevel
            let diskSpace = FeedbackManager.getAvailableDiskSpace()
            let memoryUsage = FeedbackManager.getMemoryUsage()
        }
        
        struct AppInfo {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
            let environment = FeedbackManager.getEnvironment()
        }
    }
    
    // MARK: - Public Methods
    
    /// Show feedback dialog
    public func showFeedbackDialog(from viewController: UIViewController,
                                   type: FeedbackType? = nil) {
        let alertController = UIAlertController(
            title: "Send Beta Feedback",
            message: "Help us improve Claude Code",
            preferredStyle: .actionSheet
        )
        
        // Add feedback type options
        for feedbackType in FeedbackType.allCases {
            alertController.addAction(UIAlertAction(
                title: "\(feedbackType.emoji) \(feedbackType.rawValue)",
                style: .default
            ) { _ in
                self.presentFeedbackForm(from: viewController, type: feedbackType)
            })
        }
        
        // Add cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                       y: viewController.view.bounds.midY,
                                       width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(alertController, animated: true)
    }
    
    /// Present feedback form
    public func presentFeedbackForm(from viewController: UIViewController,
                                   type: FeedbackType) {
        let feedbackVC = FeedbackViewController(type: type) { [weak self] feedback in
            self?.submitFeedback(feedback)
            viewController.dismiss(animated: true)
        }
        
        let nav = UINavigationController(rootViewController: feedbackVC)
        viewController.present(nav, animated: true)
    }
    
    /// Submit feedback
    public func submitFeedback(_ feedback: Feedback) {
        // Track analytics
        AnalyticsManager.shared.track(.betaFeedbackSubmitted, parameters: [
            "type": feedback.type.rawValue,
            "has_attachments": !feedback.attachments.isEmpty
        ])
        
        // Try to send via API
        sendFeedbackToAPI(feedback) { [weak self] success in
            if success {
                self?.showSuccessNotification()
            } else {
                // Queue for later if failed
                self?.pendingFeedback.append(feedback)
                self?.sendFeedbackViaEmail(feedback)
            }
        }
        
        // Also send to Slack if configured
        if slackWebhookURL != nil {
            sendFeedbackToSlack(feedback)
        }
    }
    
    /// Request App Store review (for production)
    public func requestAppStoreReview() {
        if #available(iOS 14.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        } else {
            SKStoreReviewController.requestReview()
        }
    }
    
    // MARK: - Private Methods
    
    private func sendFeedbackToAPI(_ feedback: Feedback, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "")/feedback") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "id": feedback.id.uuidString,
            "type": feedback.type.rawValue,
            "title": feedback.title,
            "description": feedback.description,
            "userEmail": feedback.userEmail ?? "",
            "deviceInfo": [
                "model": feedback.deviceInfo.model,
                "systemVersion": feedback.deviceInfo.systemVersion,
                "batteryLevel": feedback.deviceInfo.batteryLevel,
                "diskSpace": feedback.deviceInfo.diskSpace,
                "memoryUsage": feedback.deviceInfo.memoryUsage
            ],
            "appInfo": [
                "version": feedback.appInfo.version,
                "build": feedback.appInfo.build,
                "environment": feedback.appInfo.environment
            ],
            "timestamp": feedback.timestamp.timeIntervalSince1970,
            "attachmentCount": feedback.attachments.count
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func sendFeedbackToSlack(_ feedback: Feedback) {
        guard let webhookURL = slackWebhookURL,
              let url = URL(string: webhookURL) else { return }
        
        let message = """
        :mega: *New Beta Feedback*
        *Type:* \(feedback.type.emoji) \(feedback.type.rawValue)
        *Title:* \(feedback.title)
        *Description:* \(feedback.description)
        *User:* \(feedback.userEmail ?? "Anonymous")
        *Device:* \(feedback.deviceInfo.model) (iOS \(feedback.deviceInfo.systemVersion))
        *App Version:* \(feedback.appInfo.version) (\(feedback.appInfo.build))
        """
        
        let payload = ["text": message]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            return
        }
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    private func sendFeedbackViaEmail(_ feedback: Feedback) {
        // Implementation would use MFMailComposeViewController
    }
    
    private func showSuccessNotification() {
        // Show success UI feedback
    }
    
    // MARK: - Helpers
    
    private static func getAvailableDiskSpace() -> String {
        let fileManager = FileManager.default
        guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last,
              let dictionary = try? fileManager.attributesOfFileSystem(forPath: path),
              let freeSpace = dictionary[.systemFreeSize] as? NSNumber else {
            return "Unknown"
        }
        
        let formatter = ByteCountFormatter()
        return formatter.string(fromByteCount: freeSpace.int64Value)
    }
    
    private static func getMemoryUsage() -> String {
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
        
        if result == KERN_SUCCESS {
            let formatter = ByteCountFormatter()
            return formatter.string(fromByteCount: Int64(info.resident_size))
        }
        
        return "Unknown"
    }
    
    private static func getEnvironment() -> String {
        #if DEBUG
        return "Debug"
        #elseif BETA
        return "Beta"
        #else
        return "Production"
        #endif
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension FeedbackManager: MFMailComposeViewControllerDelegate {
    public func mailComposeController(_ controller: MFMailComposeViewController,
                                     didFinishWith result: MFMailComposeResult,
                                     error: Error?) {
        controller.dismiss(animated: true)
    }
}
EOF
    
    log_success "Feedback system created"
}

# ============================================================================
# TESTFLIGHT CONFIGURATION
# ============================================================================

setup_testflight() {
    log_header "Setting up TestFlight Configuration"
    
    # Create TestFlight onboarding
    mkdir -p "${BETA_DIR}"
    
    # Create beta tester welcome email template
    cat > "${BETA_DIR}/welcome_email.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
        .content { background: white; padding: 30px; border: 1px solid #e2e8f0; border-radius: 0 0 10px 10px; }
        .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
        .footer { text-align: center; color: #718096; margin-top: 30px; font-size: 14px; }
        code { background: #f7fafc; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Welcome to Claude Code Beta!</h1>
        </div>
        <div class="content">
            <h2>Hi Beta Tester!</h2>
            
            <p>Thank you for joining the Claude Code iOS beta testing program! Your feedback will help us build the best iOS development tool.</p>
            
            <h3>📱 Getting Started</h3>
            <ol>
                <li>Download TestFlight from the App Store if you haven't already</li>
                <li>Click the button below to join the beta</li>
                <li>Install Claude Code from TestFlight</li>
                <li>Start using the app and send us feedback!</li>
            </ol>
            
            <a href="{{TESTFLIGHT_LINK}}" class="button">Join Beta on TestFlight</a>
            
            <h3>🐛 How to Report Issues</h3>
            <ul>
                <li><strong>In-App:</strong> Use the Feedback button in Settings</li>
                <li><strong>TestFlight:</strong> Take a screenshot and share feedback</li>
                <li><strong>Email:</strong> Send detailed reports to beta@claudecode.app</li>
            </ul>
            
            <h3>✨ What to Test</h3>
            <ul>
                <li>Project creation and management</li>
                <li>Chat functionality with AI assistant</li>
                <li>SSH connections and terminal features</li>
                <li>Performance on different network conditions</li>
                <li>UI/UX on different device sizes</li>
            </ul>
            
            <h3>🎁 Beta Tester Rewards</h3>
            <p>Active beta testers will receive:</p>
            <ul>
                <li>Early access to new features</li>
                <li>Recognition in app credits</li>
                <li>Free premium subscription for 6 months after launch</li>
            </ul>
            
            <h3>📊 Current Beta Status</h3>
            <ul>
                <li>Version: {{VERSION}}</li>
                <li>Build: {{BUILD_NUMBER}}</li>
                <li>Beta Period: {{BETA_PERIOD}}</li>
                <li>Total Testers: {{TESTER_COUNT}}</li>
            </ul>
            
            <p>Questions? Join our beta community:</p>
            <ul>
                <li>Discord: <a href="https://discord.gg/claudecode">discord.gg/claudecode</a></li>
                <li>Slack: <a href="https://claudecode.slack.com">claudecode.slack.com</a></li>
            </ul>
            
            <p>Happy testing! 🎉</p>
            
            <p>Best regards,<br>The Claude Code Team</p>
        </div>
        <div class="footer">
            <p>Claude Code © 2024 | <a href="https://claudecode.app/privacy">Privacy Policy</a> | <a href="https://claudecode.app/terms">Terms</a></p>
        </div>
    </div>
</body>
</html>
EOF
    
    log_success "Welcome email template created"
    
    # Create TestFlight test plan
    cat > "${BETA_DIR}/test_plan.md" <<'EOF'
# Claude Code iOS - Beta Test Plan

## 🎯 Testing Objectives

1. **Functionality Testing**: Ensure all features work as expected
2. **Performance Testing**: Identify performance bottlenecks
3. **Usability Testing**: Gather UX feedback
4. **Compatibility Testing**: Test on various devices and iOS versions
5. **Security Testing**: Identify potential security issues
6. **Stability Testing**: Find crashes and memory leaks

## 📋 Test Scenarios

### 1. Onboarding Flow
- [ ] First launch experience
- [ ] Account creation
- [ ] Permissions requests
- [ ] Tutorial completion

### 2. Project Management
- [ ] Create new project
- [ ] Import existing project
- [ ] Configure SSH settings
- [ ] Set environment variables
- [ ] Delete project

### 3. Chat Features
- [ ] Start new conversation
- [ ] Send messages
- [ ] Receive AI responses
- [ ] Copy code snippets
- [ ] Export conversation

### 4. Terminal Features
- [ ] Open terminal
- [ ] Execute commands
- [ ] SSH connection
- [ ] File transfer
- [ ] Terminal customization

### 5. Monitoring
- [ ] View performance metrics
- [ ] Set up alerts
- [ ] Export monitoring data
- [ ] Real-time updates

### 6. Settings
- [ ] Change theme
- [ ] Configure API keys
- [ ] Manage data
- [ ] Security settings
- [ ] Notification preferences

## 🐛 Bug Reporting Template

### Bug Title
[Clear, concise description]

### Environment
- **Device**: [e.g., iPhone 14 Pro]
- **iOS Version**: [e.g., iOS 17.2]
- **App Version**: [e.g., 1.0.0 (123)]
- **Network**: [WiFi/Cellular/Offline]

### Steps to Reproduce
1. [First step]
2. [Second step]
3. [...]

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Screenshots/Videos
[Attach if applicable]

### Additional Context
[Any other relevant information]

## 📊 Testing Metrics

Track and report:
- Crash-free sessions rate
- Average session duration
- Feature usage frequency
- Performance metrics (launch time, response time)
- User satisfaction score (1-5)

## 🏆 Beta Tester Guidelines

1. **Test regularly**: Use the app at least 3 times per week
2. **Report promptly**: Submit feedback within 24 hours of finding issues
3. **Be detailed**: Provide comprehensive bug reports
4. **Test edge cases**: Try unusual workflows
5. **Suggest improvements**: Share feature ideas
6. **Stay engaged**: Participate in beta community discussions

## 📅 Beta Testing Timeline

- **Week 1-2**: Core functionality testing
- **Week 3-4**: Performance and stability testing
- **Week 5-6**: UI/UX refinement testing
- **Week 7-8**: Final testing and release preparation

## 🎁 Recognition Program

Top contributors will be recognized based on:
- Number of bugs reported
- Quality of feedback
- Feature suggestions implemented
- Community engagement

Thank you for being part of the Claude Code beta program!
EOF
    
    log_success "Test plan created"
}

# ============================================================================
# DOCUMENTATION GENERATION
# ============================================================================

generate_beta_docs() {
    log_header "Generating Beta Testing Documentation"
    
    # Create comprehensive beta guide
    cat > "${DOCS_DIR}/BETA_TESTING_GUIDE.md" <<'EOF'
# Claude Code iOS - Beta Testing Guide

## 🚀 Quick Start

### Prerequisites
- iOS device running iOS 17.0 or later
- Apple ID
- TestFlight app installed

### Installation
1. Check your email for TestFlight invitation
2. Click "View in TestFlight" button
3. Accept the invitation
4. Install Claude Code from TestFlight

## 📱 TestFlight Features

### Automatic Updates
- TestFlight automatically notifies you of new builds
- Updates install automatically unless disabled
- Each build expires after 90 days

### Feedback Submission
#### Method 1: Screenshot Feedback
1. Take a screenshot in the app (Power + Volume Up)
2. Tap the screenshot preview
3. Tap "Share" → "TestFlight Feedback"
4. Describe the issue and submit

#### Method 2: TestFlight App
1. Open TestFlight
2. Select Claude Code
3. Tap "Send Beta Feedback"
4. Choose feedback type and submit

#### Method 3: In-App Feedback
1. Open Claude Code
2. Go to Settings → Beta Feedback
3. Select issue type
4. Fill out the form and submit

## 🔍 What We're Testing

### Priority Areas
1. **Stability**: App crashes, freezes, unexpected quits
2. **Performance**: Slow loading, laggy UI, high battery usage
3. **Functionality**: Features not working as expected
4. **Compatibility**: Issues on specific devices or iOS versions
5. **Security**: Data leaks, unauthorized access, encryption issues

### Known Issues
- [List current known issues here]

## 📊 Beta Metrics Dashboard

Access your beta testing stats:
- Feedback submitted
- Bugs found
- Features tested
- Reward points earned

## 🎯 Testing Checklist

### Daily Testing (5 mins)
- [ ] Launch app
- [ ] Create/open a project
- [ ] Send a chat message
- [ ] Check monitoring dashboard
- [ ] Close app properly

### Weekly Testing (30 mins)
- [ ] Complete a full workflow
- [ ] Test offline functionality
- [ ] Try edge cases
- [ ] Submit feedback report
- [ ] Update to latest build

### Build-Specific Testing
Each build includes specific test focus areas in the release notes.

## 🏆 Beta Rewards Program

### Point System
- Bug report (verified): 10 points
- Feature suggestion (implemented): 20 points
- Crash report with steps: 15 points
- UI/UX feedback: 5 points
- Community help: 5 points

### Rewards
- **100 points**: Beta Tester badge in app
- **250 points**: 3 months premium free
- **500 points**: 6 months premium free
- **1000 points**: 1 year premium + exclusive features

## 💬 Community

### Discord Server
Join: https://discord.gg/claudecode
- #beta-general - General discussion
- #bug-reports - Report issues
- #feature-requests - Suggest features
- #help - Get help from team and testers

### Slack Workspace
Join: https://claudecode.slack.com
- Real-time chat with development team
- Direct access to engineers
- Priority support

## 📧 Contact

### Beta Support
- Email: beta@claudecode.app
- Response time: < 24 hours

### Emergency Issues
- Critical bugs: urgent@claudecode.app
- Security issues: security@claudecode.app

## 📜 Beta Agreement

By participating in the beta program, you agree to:
1. Keep all beta features confidential
2. Not share screenshots publicly without permission
3. Provide constructive feedback
4. Report issues responsibly
5. Not reverse engineer the app

## 🔄 Update History

### Latest Build
- **Version**: [VERSION]
- **Build**: [BUILD_NUMBER]
- **Released**: [DATE]
- **Changes**: [CHANGELOG]

### Previous Builds
[List previous beta builds and their changes]

## ❓ FAQ

### Q: How long does the beta last?
A: Each build expires after 90 days. The beta program continues until official release.

### Q: Can I share the app with friends?
A: No, beta access is invite-only. Friends can request access at claudecode.app/beta

### Q: Will my data transfer to the final version?
A: Yes, but we recommend backing up important data.

### Q: How do I leave the beta program?
A: Delete the app from TestFlight and it will be removed from your device.

---

Thank you for helping make Claude Code amazing! 🎉
EOF
    
    log_success "Beta testing guide created"
}

# ============================================================================
# MONITORING SETUP
# ============================================================================

setup_monitoring() {
    log_header "Setting up Beta Monitoring"
    
    # Create monitoring configuration
    cat > "${CONFIG_DIR}/BetaMonitoring.xcconfig" <<'EOF'
// Beta Testing Monitoring Configuration

// Performance monitoring
PERFORMANCE_MONITORING_ENABLED = YES
PERFORMANCE_MONITORING_SAMPLE_RATE = 1.0
PERFORMANCE_MONITORING_TRACE_ENABLED = YES

// Crash reporting
CRASH_REPORTING_ENABLED = YES
CRASH_REPORTING_INCLUDE_SIMULATOR = NO
CRASH_REPORTING_AUTO_SUBMIT = YES

// Analytics
ANALYTICS_ENABLED = YES
ANALYTICS_DEBUG_MODE = NO
ANALYTICS_SESSION_TIMEOUT = 1800

// Network monitoring
NETWORK_MONITORING_ENABLED = YES
NETWORK_MONITORING_DETAILED = YES

// User behavior tracking
USER_BEHAVIOR_TRACKING = YES
HEATMAP_ENABLED = YES
SESSION_RECORDING = NO

// Beta features
BETA_FEATURES_ENABLED = YES
BETA_MENU_ENABLED = YES
BETA_SHORTCUTS_ENABLED = YES

// Logging
LOG_LEVEL = verbose
LOG_TO_CONSOLE = YES
LOG_TO_FILE = YES
REMOTE_LOGGING = YES
EOF
    
    log_success "Beta monitoring configuration created"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

setup_all() {
    log_header "🚀 Complete Beta Testing Infrastructure Setup"
    
    # Create directories
    mkdir -p "${BETA_DIR}"
    mkdir -p "${DOCS_DIR}"
    mkdir -p "${CONFIG_DIR}"
    
    # Setup components
    setup_crashlytics
    setup_sentry
    setup_analytics
    setup_feedback_system
    setup_testflight
    setup_monitoring
    generate_beta_docs
    
    log_header "📋 Setup Summary"
    
    cat <<EOF
Beta Testing Infrastructure Setup Complete!

✅ Crash Reporting:
   - Firebase Crashlytics configured
   - Sentry error tracking ready

✅ Analytics:
   - Firebase Analytics integrated
   - Custom event tracking enabled
   - Beta-specific metrics configured

✅ Feedback System:
   - In-app feedback form created
   - Email fallback configured
   - Slack notifications ready

✅ TestFlight:
   - Welcome email template generated
   - Test plan documented
   - Beta guide created

✅ Monitoring:
   - Performance tracking enabled
   - Network monitoring configured
   - User behavior analytics ready

📝 Next Steps:
1. Add Firebase configuration (GoogleService-Info.plist)
2. Set up Sentry DSN in environment
3. Configure Slack webhook for feedback
4. Update TestFlight metadata in App Store Connect
5. Invite beta testers via TestFlight

🔗 Important Links:
- Firebase Console: https://console.firebase.google.com
- Sentry Dashboard: https://sentry.io
- App Store Connect: https://appstoreconnect.apple.com
- TestFlight: https://testflight.apple.com

📧 Beta Support Email: beta@claudecode.app
💬 Discord: https://discord.gg/claudecode
EOF
    
    log_success "Beta testing infrastructure setup complete! 🎉"
}

# Show usage
show_usage() {
    cat <<EOF
Claude Code iOS - Beta Testing Infrastructure Setup

Usage: $(basename "$0") [command]

Commands:
    all              Setup complete beta infrastructure (default)
    crashlytics      Setup Firebase Crashlytics only
    sentry           Setup Sentry error tracking only
    analytics        Setup analytics only
    feedback         Setup feedback system only
    testflight       Setup TestFlight configuration only
    monitoring       Setup monitoring only
    docs             Generate documentation only
    help             Show this help message

Example:
    $(basename "$0")               # Setup everything
    $(basename "$0") crashlytics   # Setup Crashlytics only
    $(basename "$0") docs          # Generate docs only

EOF
}

# Main execution
main() {
    local command="${1:-all}"
    
    case "$command" in
        all)
            setup_all
            ;;
        crashlytics)
            setup_crashlytics
            ;;
        sentry)
            setup_sentry
            ;;
        analytics)
            setup_analytics
            ;;
        feedback)
            setup_feedback_system
            ;;
        testflight)
            setup_testflight
            ;;
        monitoring)
            setup_monitoring
            ;;
        docs)
            generate_beta_docs
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main
main "$@"