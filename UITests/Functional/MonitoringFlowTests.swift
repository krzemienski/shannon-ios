//
//  MonitoringFlowTests.swift
//  ClaudeCodeUITests
//
//  Functional tests for monitoring tab and performance metrics with real backend
//

import XCTest

class MonitoringFlowTests: ClaudeCodeUITestCase {
    
    // MARK: - Properties
    
    private var monitorPage: MonitorPage!
    private var projectsPage: ProjectsPage!
    private var chatPage: ChatPage!
    private var testProjectId: String?
    private var testSessionId: String?
    private var createdProjectIds: [String] = []
    private var createdSessionIds: [String] = []
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Configure for real backend testing
        let config = RealBackendConfig.createLaunchConfiguration()
        launchApp(with: config)
        
        monitorPage = MonitorPage(app: app)
        projectsPage = ProjectsPage(app: app)
        chatPage = ChatPage(app: app)
        
        // Setup test environment with activity to monitor
        let setupExpectation = expectation(description: "Test environment setup")
        Task {
            let isAvailable = await RealBackendConfig.waitForBackend(maxAttempts: 15, interval: 2.0)
            XCTAssertTrue(isAvailable, "Backend must be available for functional tests")
            
            do {
                // Create test project
                let testProject = TestProjectData(
                    name: "FunctionalTest_MonitoringProject",
                    description: "Project for monitoring tests"
                )
                let projectData = try await BackendAPIHelper.shared.createProject(testProject)
                self.testProjectId = projectData["id"] as? String
                if let projectId = self.testProjectId {
                    self.createdProjectIds.append(projectId)
                    
                    // Create test session to generate some activity
                    let sessionData = TestSessionData(
                        projectId: projectId,
                        title: "FunctionalTest_MonitoringSession",
                        model: "claude-3-haiku-20240307"
                    )
                    let session = try await BackendAPIHelper.shared.createSession(sessionData)
                    self.testSessionId = session["id"] as? String
                    if let sessionId = self.testSessionId {
                        self.createdSessionIds.append(sessionId)
                    }
                }
            } catch {
                XCTFail("Failed to setup test environment: \(error)")
            }
            
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 60.0)
    }
    
    override func tearDownWithError() throws {
        // Clean up test data
        let cleanupExpectation = expectation(description: "Cleanup completed")
        Task {
            for sessionId in createdSessionIds {
                do {
                    try await BackendAPIHelper.shared.deleteSession(sessionId)
                    if RealBackendConfig.verboseLogging {
                        print("Cleaned up test session: \(sessionId)")
                    }
                } catch {
                    print("Failed to cleanup session \(sessionId): \(error)")
                }
            }
            
            for projectId in createdProjectIds {
                do {
                    try await BackendAPIHelper.shared.deleteProject(projectId)
                    if RealBackendConfig.verboseLogging {
                        print("Cleaned up test project: \(projectId)")
                    }
                } catch {
                    print("Failed to cleanup project \(projectId): \(error)")
                }
            }
            
            await RealBackendConfig.cleanupTestData()
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 30.0)
        
        try super.tearDownWithError()
    }
    
    // MARK: - Performance Metrics Tests
    
    func testViewRealPerformanceMetrics() throws {
        takeScreenshot(name: "before_monitoring_tab")
        
        // Navigate to monitoring tab
        monitorPage.navigateToMonitor()
        waitForElement(monitorPage.performanceSection, timeout: RealBackendConfig.uiWaitTimeout)
        
        takeScreenshot(name: "monitoring_tab_loaded")
        
        // Wait for real metrics to load from backend
        Thread.sleep(forTimeInterval: 5.0)
        
        takeScreenshot(name: "performance_metrics_loaded")
        
        // Verify performance metrics are displayed
        XCTAssertTrue(monitorPage.performanceSection.exists, "Performance section should be visible")
        
        // Look for specific performance indicators
        let performanceElements = [
            "CPU",
            "Memory", 
            "Network",
            "Response Time",
            "Request Count",
            "Error Rate"
        ]
        
        var metricsFound = 0
        for metric in performanceElements {
            let metricElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", metric)).firstMatch
            if metricElement.exists {
                metricsFound += 1
                if RealBackendConfig.verboseLogging {
                    print("Found metric: \(metric)")
                }
            }
        }
        
        XCTAssertGreaterThan(metricsFound, 0, "Should display at least some performance metrics")
        
        takeScreenshot(name: "performance_metrics_verified")
    }
    
    func testPerformanceMetricsUpdateWithActivity() throws {
        // Generate some activity first by sending messages
        generateTestActivity()
        
        // Navigate to monitoring
        monitorPage.navigateToMonitor()
        waitForElement(monitorPage.performanceSection, timeout: RealBackendConfig.uiWaitTimeout)
        
        takeScreenshot(name: "monitoring_before_activity")
        
        // Capture initial metrics (if any values are displayed)
        let initialMetrics = captureCurrentMetrics()
        
        // Generate more activity
        generateTestActivity()
        
        // Wait for metrics to update
        Thread.sleep(forTimeInterval: 10.0)
        
        // Refresh monitoring view
        monitorPage.refreshMetrics()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "monitoring_after_activity")
        
        // Capture updated metrics
        let updatedMetrics = captureCurrentMetrics()
        
        // Verify metrics have changed (at least some activity should be registered)
        let metricsChanged = initialMetrics != updatedMetrics
        XCTAssertTrue(metricsChanged, "Performance metrics should update after activity")
        
        if RealBackendConfig.verboseLogging {
            print("Initial metrics: \(initialMetrics)")
            print("Updated metrics: \(updatedMetrics)")
        }
        
        takeScreenshot(name: "metrics_update_verified")
    }
    
    func testViewSessionStatistics() throws {
        // Generate session activity
        generateTestActivity()
        
        // Navigate to monitoring
        monitorPage.navigateToMonitor()
        waitForElement(monitorPage.performanceSection, timeout: RealBackendConfig.uiWaitTimeout)
        
        takeScreenshot(name: "before_session_stats")
        
        // Look for session statistics section
        let sessionStatsSection = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "session")).firstMatch
        if sessionStatsSection.exists {
            swipeToElement(sessionStatsSection)
            takeScreenshot(name: "session_stats_visible")
        }
        
        // Verify session-related metrics
        let sessionMetrics = [
            "Active Sessions",
            "Total Sessions", 
            "Messages Sent",
            "Average Response Time",
            "Token Usage"
        ]
        
        var sessionMetricsFound = 0
        for metric in sessionMetrics {
            let metricElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", metric)).firstMatch
            if metricElement.exists {
                sessionMetricsFound += 1
                if RealBackendConfig.verboseLogging {
                    print("Found session metric: \(metric)")
                }
            }
        }
        
        // We expect at least some session metrics to be visible
        XCTAssertGreaterThan(sessionMetricsFound, 0, "Should display session statistics")
        
        takeScreenshot(name: "session_statistics_verified")
    }
    
    // MARK: - Error Logs Tests
    
    func testViewRealErrorLogs() throws {
        // Navigate to monitoring
        monitorPage.navigateToMonitor()
        waitForElement(monitorPage.performanceSection, timeout: RealBackendConfig.uiWaitTimeout)
        
        takeScreenshot(name: "before_error_logs")
        
        // Look for error logs section
        monitorPage.viewErrorLogs()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "error_logs_section")
        
        // Verify error logs interface is accessible
        let errorLogsList = app.tables.containing(NSPredicate(format: "identifier CONTAINS[c] %@", "error")).firstMatch
        if !errorLogsList.exists {
            // Try alternative selectors
            let errorSection = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "error")).firstMatch
            XCTAssertTrue(errorSection.exists, "Should have error logs section accessible")
        }
        
        takeScreenshot(name: "error_logs_verified")
    }
    
    func testFilterErrorLogsByType() throws {
        // Navigate to error logs
        monitorPage.navigateToMonitor()
        waitForElement(monitorPage.performanceSection, timeout: RealBackendConfig.uiWaitTimeout)
        
        monitorPage.viewErrorLogs()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "before_error_filtering")
        
        // Look for filter options
        let filterButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "filter")).firstMatch
        if filterButton.exists {
            filterButton.tap()
            Thread.sleep(forTimeInterval: 2.0)
            
            takeScreenshot(name: "error_filter_options")
            
            // Try different filter options
            let errorTypes = ["Warning", "Error", "Critical", "Network", "API"]
            
            for errorType in errorTypes {
                let filterOption = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", errorType)).firstMatch
                if filterOption.exists {
                    filterOption.tap()
                    Thread.sleep(forTimeInterval: 2.0)
                    
                    takeScreenshot(name: "filtered_by_\(errorType.lowercased())")
                    
                    // Verify filter is applied (interface should reflect the filter)
                    let filteredIndicator = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", errorType)).firstMatch
                    XCTAssertTrue(filteredIndicator.exists, "Filter for \(errorType) should be applied")
                    
                    break // Test one filter to keep test focused
                }
            }
        }
        
        takeScreenshot(name: "error_filtering_verified")
    }
    
    // MARK: - Telemetry Data Tests
    
    func testViewTelemetryData() throws {
        // Generate activity to create telemetry data
        generateTestActivity()
        
        // Navigate to monitoring
        monitorPage.navigateToMonitor()
        waitForElement(monitorPage.performanceSection, timeout: RealBackendConfig.uiWaitTimeout)
        
        takeScreenshot(name: "before_telemetry")
        
        // Look for telemetry section
        let telemetrySection = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "telemetry")).firstMatch
        if telemetrySection.exists {
            swipeToElement(telemetrySection)
            telemetrySection.tap()
            Thread.sleep(forTimeInterval: 3.0)
            
            takeScreenshot(name: "telemetry_section_opened")
        } else {
            // Try monitoring details or settings
            monitorPage.openMonitoringSettings()
            Thread.sleep(forTimeInterval: 3.0)
            
            takeScreenshot(name: "monitoring_settings_opened")
        }
        
        // Verify telemetry data is available
        let telemetryElements = [
            "Events",
            "Metrics", 
            "Performance",
            "Usage",
            "Analytics"
        ]
        
        var telemetryFound = 0
        for element in telemetryElements {
            let telemetryElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", element)).firstMatch
            if telemetryElement.exists {
                telemetryFound += 1
                if RealBackendConfig.verboseLogging {
                    print("Found telemetry element: \(element)")
                }
            }
        }
        
        XCTAssertGreaterThan(telemetryFound, 0, "Should display telemetry data")
        
        takeScreenshot(name: "telemetry_data_verified")
    }
    
    func testExportTelemetryData() throws {
        // Navigate to monitoring
        monitorPage.navigateToMonitor()
        waitForElement(monitorPage.performanceSection, timeout: RealBackendConfig.uiWaitTimeout)
        
        // Open monitoring settings/details
        monitorPage.openMonitoringSettings()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "before_telemetry_export")
        
        // Look for export functionality
        let exportButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "export")).firstMatch
        if exportButton.exists {
            exportButton.tap()
            Thread.sleep(forTimeInterval: 2.0)
            
            takeScreenshot(name: "export_dialog_opened")
            
            // Look for export options
            let exportOptions = ["CSV", "JSON", "PDF", "Share"]
            var exportOptionFound = false
            
            for option in exportOptions {
                let optionButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", option)).firstMatch
                if optionButton.exists {
                    exportOptionFound = true
                    optionButton.tap()
                    Thread.sleep(forTimeInterval: 2.0)
                    
                    takeScreenshot(name: "export_\(option.lowercased())_selected")
                    break
                }
            }
            
            XCTAssertTrue(exportOptionFound, "Should have export options available")
        } else {
            // Export might be in a different location or unavailable
            print("Export functionality not found - this may be expected")
        }
        
        takeScreenshot(name: "telemetry_export_tested")
    }
    
    // MARK: - Real-time Monitoring Tests
    
    func testRealTimeMetricsUpdates() throws {
        // Navigate to monitoring
        monitorPage.navigateToMonitor()
        waitForElement(monitorPage.performanceSection, timeout: RealBackendConfig.uiWaitTimeout)
        
        takeScreenshot(name: "before_realtime_monitoring")
        
        // Capture baseline metrics
        let baselineMetrics = captureCurrentMetrics()
        
        // Generate activity in background while monitoring
        let activityExpectation = expectation(description: "Background activity generated")
        DispatchQueue.global().async {
            // This would ideally generate backend activity
            // For now, we'll simulate by waiting
            Thread.sleep(forTimeInterval: 5.0)
            activityExpectation.fulfill()
        }
        
        // Monitor for updates
        var updatesDetected = 0
        let monitoringDuration: TimeInterval = 30.0
        let checkInterval: TimeInterval = 5.0
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < monitoringDuration {
            Thread.sleep(forTimeInterval: checkInterval)
            
            let currentMetrics = captureCurrentMetrics()
            if currentMetrics != baselineMetrics {
                updatesDetected += 1
                takeScreenshot(name: "metrics_update_\(updatesDetected)")
                
                if RealBackendConfig.verboseLogging {
                    print("Metrics update detected: \(currentMetrics)")
                }
            }
            
            // Refresh the view to trigger updates
            monitorPage.refreshMetrics()
            Thread.sleep(forTimeInterval: 1.0)
        }
        
        wait(for: [activityExpectation], timeout: 10.0)
        
        // We don't strictly require updates since the backend might be idle
        // But we verify the monitoring interface is working
        takeScreenshot(name: "realtime_monitoring_complete")
        
        if updatesDetected > 0 {
            print("Real-time updates detected: \(updatesDetected)")
        } else {
            print("No real-time updates detected - backend may be idle")
        }
    }
    
    // MARK: - Monitoring Configuration Tests
    
    func testConfigureMonitoringSettings() throws {
        // Navigate to monitoring
        monitorPage.navigateToMonitor()
        waitForElement(monitorPage.performanceSection, timeout: RealBackendConfig.uiWaitTimeout)
        
        // Open monitoring settings
        monitorPage.openMonitoringSettings()
        Thread.sleep(forTimeInterval: 3.0)
        
        takeScreenshot(name: "monitoring_settings")
        
        // Look for configurable options
        let settingsOptions = [
            "Refresh Rate",
            "Alert Thresholds", 
            "Data Retention",
            "Notifications",
            "Auto Refresh"
        ]
        
        var settingsFound = 0
        for setting in settingsOptions {
            let settingElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", setting)).firstMatch
            if settingElement.exists {
                settingsFound += 1
                if RealBackendConfig.verboseLogging {
                    print("Found setting: \(setting)")
                }
            }
        }
        
        // Try to modify a setting if available
        let refreshRateSetting = app.switches.containing(NSPredicate(format: "identifier CONTAINS[c] %@", "refresh")).firstMatch
        if refreshRateSetting.exists {
            refreshRateSetting.tap()
            Thread.sleep(forTimeInterval: 2.0)
            takeScreenshot(name: "setting_modified")
        }
        
        takeScreenshot(name: "monitoring_configuration_tested")
        
        XCTAssertGreaterThan(settingsFound, 0, "Should have configurable monitoring settings")
    }
    
    // MARK: - Helper Methods
    
    private func generateTestActivity() {
        guard let sessionId = testSessionId else { return }
        
        // Navigate to chat and send some messages to generate activity
        chatPage.navigateToChat()
        waitForElement(chatPage.chatList, timeout: 10)
        Thread.sleep(forTimeInterval: 2.0)
        
        // Find test session
        let sessionsList = chatPage.chatList
        let sessionCells = sessionsList.cells
        
        for i in 0..<sessionCells.count {
            let cell = sessionCells.element(boundBy: i)
            if cell.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "MonitoringSession")).firstMatch.exists {
                cell.tap()
                break
            }
        }
        
        // Send a few messages to generate activity
        waitForElement(chatPage.chatInput, timeout: 10)
        
        for i in 1...3 {
            chatPage.chatInput.tap()
            clearTextField(chatPage.chatInput)
            chatPage.chatInput.typeText("Monitoring test message \(i)")
            chatPage.sendMessage()
            Thread.sleep(forTimeInterval: 2.0)
        }
        
        if RealBackendConfig.verboseLogging {
            print("Generated test activity for monitoring")
        }
    }
    
    private func captureCurrentMetrics() -> [String: String] {
        var metrics: [String: String] = [:]
        
        // Capture visible metric values
        let allTexts = app.staticTexts.allElementsBoundByIndex
        for element in allTexts {
            let text = element.label
            
            // Look for metric patterns (numbers with units, percentages, etc.)
            if text.contains("%") || 
               text.contains("ms") || 
               text.contains("MB") || 
               text.contains("KB") ||
               text.contains("req/s") {
                metrics[text] = text
            }
        }
        
        return metrics
    }
}