//
//  ClaudeCodeApp.swift
//  ClaudeCode
//
//  Main app with integrated monitoring system
//

import SwiftUI

@main
struct ClaudeCodeApp: App {
    @StateObject private var monitoringService = MonitoringService.shared
    @StateObject private var dashboardManager = DashboardManager.shared
    @State private var selectedTab = 0
    
    init() {
        setupMonitoring()
    }
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                // Main App View
                MainAppView()
                    .tabItem {
                        Label("App", systemImage: "apps.iphone")
                    }
                    .tag(0)
                
                // Real-Time Monitoring
                RealTimeMonitoringView()
                    .tabItem {
                        Label("Live", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(1)
                
                // Executive Dashboard
                NavigationView {
                    ExecutiveDashboardView()
                }
                .tabItem {
                    Label("Executive", systemImage: "briefcase.fill")
                }
                .tag(2)
                
                // Developer Dashboard
                NavigationView {
                    DeveloperDashboardView()
                }
                .tabItem {
                    Label("Developer", systemImage: "hammer.fill")
                }
                .tag(3)
                
                // Settings & Debug
                MonitoringSettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(4)
            }
            .onAppear {
                startMonitoringSession()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                monitoringService.pauseSession()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                monitoringService.resumeSession()
            }
        }
    }
    
    private func setupMonitoring() {
        // Configure monitoring providers (in production, use real API keys)
        let configuration = MonitoringConfiguration(
            enableCrashReporting: true,
            enablePerformanceMonitoring: true,
            enableAnalytics: true,
            enableNetworkMonitoring: true,
            samplingRate: 1.0 // 100% sampling for development
        )
        
        monitoringService.configure(with: configuration)
        
        // Set up error tracking
        ErrorTracker.shared.setup(environment: .development)
        
        // Set up performance monitoring
        PerformanceMonitor.shared.startMonitoring()
        
        // Set up network monitoring
        NetworkPerformanceMonitor.shared.startMonitoring()
        
        // Set up user analytics
        UserAnalyticsManager.shared.configure(
            appId: "com.claudecode.ios",
            environment: .development
        )
    }
    
    private func startMonitoringSession() {
        // Start a new monitoring session
        monitoringService.startSession()
        
        // Track app launch
        monitoringService.trackEvent(MonitoringEvent(
            name: "app_launch",
            category: .system,
            properties: [
                "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
                "device": UIDevice.current.model,
                "os": UIDevice.current.systemVersion
            ],
            severity: .info
        ))
        
        // Start a performance transaction for app startup
        let transaction = PerformanceMonitor.shared.startTransaction(
            name: "app_startup",
            operation: "launch"
        )
        
        // Simulate app initialization work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            transaction.finish()
        }
    }
}

// MARK: - Main App View

struct MainAppView: View {
    @State private var apiResponse: String = "Not tested"
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Claude Code iOS")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Production Monitoring Enabled")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 20)
                    
                    // Quick Actions
                    VStack(spacing: 16) {
                        ActionCard(
                            title: "Test Backend",
                            icon: "network",
                            color: .blue,
                            action: testBackendConnection
                        )
                        
                        ActionCard(
                            title: "Test Chat API",
                            icon: "message.fill",
                            color: .green,
                            action: testChatEndpoint
                        )
                        
                        ActionCard(
                            title: "Simulate Error",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            action: simulateError
                        )
                        
                        ActionCard(
                            title: "Track Custom Event",
                            icon: "chart.bar.fill",
                            color: .purple,
                            action: trackCustomEvent
                        )
                    }
                    
                    // Status Display
                    if !apiResponse.isEmpty && apiResponse != "Not tested" {
                        StatusCard(message: apiResponse, isLoading: isLoading)
                    }
                }
                .padding()
            }
            .navigationTitle("Claude Code")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error Tracked", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Actions
    
    private func testBackendConnection() {
        let transaction = PerformanceMonitor.shared.startTransaction(
            name: "backend_health_check",
            operation: "api_call"
        )
        
        isLoading = true
        apiResponse = "Testing backend..."
        
        // Track the API call
        UserAnalyticsManager.shared.trackEvent(AnalyticsEvent(
            name: "backend_test_initiated",
            category: "testing",
            properties: ["endpoint": "health"],
            timestamp: Date()
        ))
        
        guard let url = URL(string: "http://localhost:8000/v1/health") else {
            apiResponse = "Invalid URL"
            isLoading = false
            transaction.setStatus(.internalError)
            transaction.finish()
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    apiResponse = "Error: \(error.localizedDescription)"
                    transaction.setStatus(.unknownError)
                    
                    // Track the error
                    ErrorTracker.shared.trackError(
                        error,
                        severity: .warning,
                        context: ["endpoint": "health"]
                    )
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        apiResponse = "✅ Backend is running!"
                        transaction.setStatus(.ok)
                        
                        // Track success
                        UserAnalyticsManager.shared.trackEvent(AnalyticsEvent(
                            name: "backend_test_success",
                            category: "testing",
                            properties: ["status_code": "\(httpResponse.statusCode)"],
                            timestamp: Date()
                        ))
                    } else {
                        apiResponse = "❌ HTTP \(httpResponse.statusCode)"
                        transaction.setStatus(.fromHTTPCode(httpResponse.statusCode))
                    }
                }
                
                transaction.finish()
            }
        }.resume()
    }
    
    private func testChatEndpoint() {
        let transaction = PerformanceMonitor.shared.startTransaction(
            name: "chat_api_test",
            operation: "api_call"
        )
        
        isLoading = true
        apiResponse = "Testing chat API..."
        
        guard let url = URL(string: "http://localhost:8000/v1/chat/completions") else {
            apiResponse = "Invalid URL"
            isLoading = false
            transaction.setStatus(.internalError)
            transaction.finish()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer test-key", forHTTPHeaderField: "Authorization")
        
        let body = [
            "model": "claude-3-5-sonnet-20241022",
            "messages": [
                ["role": "user", "content": "Say hello"]
            ],
            "stream": false
        ] as [String : Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            apiResponse = "JSON error: \(error)"
            isLoading = false
            transaction.setStatus(.internalError)
            transaction.finish()
            
            ErrorTracker.shared.trackError(
                error,
                severity: .error,
                context: ["stage": "request_preparation"]
            )
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    apiResponse = "Error: \(error.localizedDescription)"
                    transaction.setStatus(.unknownError)
                    
                    ErrorTracker.shared.trackError(
                        error,
                        severity: .error,
                        context: ["endpoint": "chat"]
                    )
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        apiResponse = "✅ Chat API working!"
                        transaction.setStatus(.ok)
                        
                        UserAnalyticsManager.shared.trackEvent(AnalyticsEvent(
                            name: "chat_api_success",
                            category: "testing",
                            properties: ["model": "claude-3-5-sonnet"],
                            timestamp: Date()
                        ))
                    } else {
                        apiResponse = "❌ Chat API: HTTP \(httpResponse.statusCode)"
                        transaction.setStatus(.fromHTTPCode(httpResponse.statusCode))
                    }
                }
                
                transaction.finish()
            }
        }.resume()
    }
    
    private func simulateError() {
        let error = NSError(
            domain: "com.claudecode.test",
            code: 500,
            userInfo: [
                NSLocalizedDescriptionKey: "This is a simulated error for testing",
                NSLocalizedFailureReasonErrorKey: "User triggered test error",
                "test_id": UUID().uuidString
            ]
        )
        
        ErrorTracker.shared.trackError(
            error,
            severity: .warning,
            context: [
                "source": "manual_test",
                "user_action": "simulate_error_button"
            ]
        )
        
        errorMessage = "Error has been tracked and sent to monitoring systems"
        showError = true
        apiResponse = "⚠️ Error simulated and tracked"
    }
    
    private func trackCustomEvent() {
        // Track a custom analytics event
        UserAnalyticsManager.shared.trackEvent(AnalyticsEvent(
            name: "custom_event_test",
            category: "user_action",
            properties: [
                "button": "track_custom_event",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "session_id": UUID().uuidString
            ],
            timestamp: Date()
        ))
        
        // Also track in monitoring service
        MonitoringService.shared.trackEvent(MonitoringEvent(
            name: "custom_event",
            category: .user,
            properties: ["type": "manual_test"],
            severity: .info
        ))
        
        apiResponse = "📊 Custom event tracked successfully"
    }
}

// MARK: - UI Components

struct ActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .cornerRadius(10)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

struct StatusCard: View {
    let message: String
    let isLoading: Bool
    
    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
            }
            
            Text(message)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
    }
    
    private var statusIcon: String {
        if message.contains("✅") {
            return "checkmark.circle.fill"
        } else if message.contains("❌") {
            return "xmark.circle.fill"
        } else if message.contains("⚠️") {
            return "exclamationmark.triangle.fill"
        } else if message.contains("📊") {
            return "chart.bar.fill"
        } else {
            return "info.circle.fill"
        }
    }
    
    private var statusColor: Color {
        if message.contains("✅") {
            return .green
        } else if message.contains("❌") {
            return .red
        } else if message.contains("⚠️") {
            return .orange
        } else if message.contains("📊") {
            return .purple
        } else {
            return .blue
        }
    }
}

// MARK: - Monitoring Settings View

struct MonitoringSettingsView: View {
    @AppStorage("monitoring.enabled") private var monitoringEnabled = true
    @AppStorage("monitoring.crashReporting") private var crashReportingEnabled = true
    @AppStorage("monitoring.performance") private var performanceEnabled = true
    @AppStorage("monitoring.analytics") private var analyticsEnabled = true
    @AppStorage("monitoring.network") private var networkEnabled = true
    @AppStorage("monitoring.samplingRate") private var samplingRate = 1.0
    
    var body: some View {
        NavigationView {
            Form {
                Section("Monitoring Configuration") {
                    Toggle("Enable Monitoring", isOn: $monitoringEnabled)
                    
                    if monitoringEnabled {
                        Toggle("Crash Reporting", isOn: $crashReportingEnabled)
                        Toggle("Performance Monitoring", isOn: $performanceEnabled)
                        Toggle("User Analytics", isOn: $analyticsEnabled)
                        Toggle("Network Monitoring", isOn: $networkEnabled)
                    }
                }
                
                Section("Sampling") {
                    VStack(alignment: .leading) {
                        Text("Sampling Rate: \(Int(samplingRate * 100))%")
                            .font(.caption)
                        
                        Slider(value: $samplingRate, in: 0.1...1.0, step: 0.1)
                    }
                }
                
                Section("Debug Actions") {
                    Button("Force Crash (Test)") {
                        // This would trigger a test crash in production
                        // For safety, we'll just track it as an error
                        ErrorTracker.shared.trackError(
                            NSError(domain: "test.crash", code: -1, userInfo: nil),
                            severity: .fatal,
                            context: ["type": "forced_test_crash"]
                        )
                    }
                    .foregroundColor(.red)
                    
                    Button("Clear All Data") {
                        // Clear monitoring data
                        MonitoringService.shared.clearAllData()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Export Metrics") {
                        // Export monitoring metrics
                        MonitoringService.shared.exportMetrics()
                    }
                }
                
                Section("System Info") {
                    HStack {
                        Text("Device")
                        Spacer()
                        Text(UIDevice.current.model)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("OS Version")
                        Spacer()
                        Text(UIDevice.current.systemVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Session ID")
                        Spacer()
                        Text(MonitoringService.shared.currentSessionId?.uuidString ?? "None")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Monitoring Settings")
        }
    }
}

// MARK: - Transaction Status Extension

extension Transaction {
    enum Status {
        case ok
        case cancelled
        case internalError
        case unknownError
        case invalidArgument
        case deadlineExceeded
        case notFound
        case alreadyExists
        case permissionDenied
        case resourceExhausted
        case failedPrecondition
        case aborted
        case outOfRange
        case unimplemented
        case unavailable
        case dataLoss
        
        static func fromHTTPCode(_ code: Int) -> Status {
            switch code {
            case 200...299:
                return .ok
            case 400:
                return .invalidArgument
            case 401, 403:
                return .permissionDenied
            case 404:
                return .notFound
            case 409:
                return .alreadyExists
            case 429:
                return .resourceExhausted
            case 500:
                return .internalError
            case 501:
                return .unimplemented
            case 503:
                return .unavailable
            case 504:
                return .deadlineExceeded
            default:
                return .unknownError
            }
        }
    }
    
    func setStatus(_ status: Status) {
        // In production, this would update the transaction status
        // For now, we'll just track it as metadata
        self.setData(key: "status", value: "\(status)")
    }
}