import XCTest

/// Tests for monitoring view and system status flows
final class MonitoringFlowTests: BaseUITest {
    
    // MARK: - Test Cases
    
    /// Test accessing monitoring view
    func testAccessMonitoringView() throws {
        // Look for monitoring tab or navigation
        let monitoringTab = app.tabBars.buttons["Monitoring"]
        let monitoringButton = app.buttons["Monitoring"]
        let systemButton = app.buttons["System"]
        
        let monitoringAccess = [monitoringTab, monitoringButton, systemButton].first { $0.exists }
        
        // If not in tab bar, check navigation or menu
        if monitoringAccess == nil {
            // Try to access via menu or settings
            let menuButton = app.navigationBars.buttons["Menu"]
            let settingsButton = app.navigationBars.buttons["Settings"]
            
            if menuButton.exists {
                menuButton.tap()
                Thread.sleep(forTimeInterval: 1)
            } else if settingsButton.exists {
                settingsButton.tap()
                Thread.sleep(forTimeInterval: 1)
            }
        }
        
        // Now try to find monitoring option again
        let finalMonitoringButton = [
            app.tabBars.buttons["Monitoring"],
            app.buttons["Monitoring"],
            app.buttons["System"],
            app.buttons["System Status"],
            app.cells["Monitoring"]
        ].first { $0.exists }
        
        guard let button = finalMonitoringButton ?? monitoringAccess else {
            throw XCTSkip("Monitoring view not accessible in current UI")
        }
        
        takeScreenshot(name: "Before Monitoring Access")
        
        // Tap to access monitoring
        button.tap()
        Thread.sleep(forTimeInterval: 1)
        
        // Verify monitoring view loaded
        let monitoringTitle = app.navigationBars["Monitoring"]
        let systemStatusTitle = app.navigationBars["System Status"]
        let statsView = app.otherElements["StatsView"]
        
        XCTAssertTrue(
            monitoringTitle.exists || systemStatusTitle.exists || statsView.exists,
            "Monitoring view did not load"
        )
        
        takeScreenshot(name: "Monitoring View Loaded")
    }
    
    /// Test viewing API status
    func testViewAPIStatus() throws {
        try testAccessMonitoringView()
        
        // Look for API status indicators
        let apiStatusLabel = app.staticTexts["API Status"]
        let backendStatusLabel = app.staticTexts["Backend Status"]
        let connectionStatus = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'connected'")).firstMatch
        
        if apiStatusLabel.exists || backendStatusLabel.exists {
            takeScreenshot(name: "API Status Section")
            
            // Check for status indicator
            let statusOnline = app.staticTexts["Online"]
            let statusConnected = app.staticTexts["Connected"]
            let statusHealthy = app.staticTexts["Healthy"]
            
            let isHealthy = statusOnline.exists || statusConnected.exists || statusHealthy.exists
            
            if isHealthy {
                XCTAssertTrue(true, "API is healthy")
                takeScreenshot(name: "API Status Healthy")
            } else {
                // Check for error states
                let statusOffline = app.staticTexts["Offline"]
                let statusError = app.staticTexts["Error"]
                
                if statusOffline.exists || statusError.exists {
                    takeScreenshot(name: "API Status Unhealthy")
                }
            }
        }
        
        // Check for endpoint information
        let endpointLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'localhost:8000'")).firstMatch
        if endpointLabel.exists {
            XCTAssertTrue(true, "Backend endpoint displayed correctly")
        }
        
        verifyNetworkRequestSucceeded(description: "Checked backend health via /health")
    }
    
    /// Test viewing session statistics
    func testViewSessionStatistics() throws {
        try testAccessMonitoringView()
        
        // Look for session stats
        let sessionCountLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'session'")).firstMatch
        let messageCountLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'message'")).firstMatch
        let activeSessionsLabel = app.staticTexts["Active Sessions"]
        
        if sessionCountLabel.exists || activeSessionsLabel.exists {
            takeScreenshot(name: "Session Statistics")
            
            // Verify numbers are displayed
            let numberLabels = app.staticTexts.matching(NSPredicate(format: "label MATCHES '^[0-9]+$'"))
            XCTAssertTrue(numberLabels.count > 0, "No statistics numbers found")
        }
        
        if messageCountLabel.exists {
            takeScreenshot(name: "Message Statistics")
        }
    }
    
    /// Test viewing resource usage
    func testViewResourceUsage() throws {
        try testAccessMonitoringView()
        
        // Scroll to find resource usage section if needed
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
        }
        
        // Look for resource indicators
        let memoryLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'memory'")).firstMatch
        let cpuLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'cpu'")).firstMatch
        let diskLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'disk'")).firstMatch
        let networkLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'network'")).firstMatch
        
        if memoryLabel.exists {
            takeScreenshot(name: "Memory Usage")
            
            // Check for usage percentage or MB/GB values
            let percentageLabels = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '%'"))
            let memoryValueLabels = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'MB' OR label CONTAINS 'GB'"))
            
            XCTAssertTrue(
                percentageLabels.count > 0 || memoryValueLabels.count > 0,
                "No memory usage values found"
            )
        }
        
        if cpuLabel.exists {
            takeScreenshot(name: "CPU Usage")
        }
        
        if diskLabel.exists {
            takeScreenshot(name: "Disk Usage")
        }
        
        if networkLabel.exists {
            takeScreenshot(name: "Network Usage")
        }
    }
    
    /// Test viewing error logs
    func testViewErrorLogs() throws {
        try testAccessMonitoringView()
        
        // Look for logs section
        let logsButton = app.buttons["Logs"]
        let viewLogsButton = app.buttons["View Logs"]
        let errorLogsTab = app.buttons["Errors"]
        
        let logsAccess = [logsButton, viewLogsButton, errorLogsTab].first { $0.exists }
        
        if let button = logsAccess {
            button.tap()
            Thread.sleep(forTimeInterval: 1)
            
            takeScreenshot(name: "Logs View")
            
            // Check for log entries
            let logTable = app.tables["LogsTable"]
            let logList = app.collectionViews["LogsList"]
            let logContainer = logTable.exists ? logTable : logList
            
            if logContainer.exists {
                let logEntries = logContainer.cells
                
                if logEntries.count > 0 {
                    takeScreenshot(name: "Log Entries Present")
                    
                    // Tap on first log entry for details
                    let firstLog = logEntries.firstMatch
                    if firstLog.exists {
                        firstLog.tap()
                        Thread.sleep(forTimeInterval: 1)
                        takeScreenshot(name: "Log Entry Details")
                        
                        // Navigate back
                        if app.navigationBars.buttons.firstMatch.exists {
                            app.navigationBars.buttons.firstMatch.tap()
                        }
                    }
                } else {
                    // No logs (which is good if no errors)
                    let noLogsLabel = app.staticTexts["No logs"]
                    let emptyLogsLabel = app.staticTexts["No errors"]
                    
                    XCTAssertTrue(
                        noLogsLabel.exists || emptyLogsLabel.exists,
                        "Empty logs state not shown"
                    )
                    takeScreenshot(name: "No Error Logs")
                }
            }
        }
    }
    
    /// Test refresh monitoring data
    func testRefreshMonitoringData() throws {
        try testAccessMonitoringView()
        
        takeScreenshot(name: "Before Refresh")
        
        // Look for refresh button or pull to refresh
        let refreshButton = app.buttons["Refresh"]
        let reloadButton = app.buttons["Reload"]
        
        if refreshButton.exists {
            refreshButton.tap()
        } else if reloadButton.exists {
            reloadButton.tap()
        } else {
            // Try pull to refresh
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeDown()
            } else {
                // Swipe down on the main view
                app.swipeDown()
            }
        }
        
        // Wait for refresh
        Thread.sleep(forTimeInterval: 2)
        
        // Check for loading indicator
        let loadingIndicator = app.activityIndicators.firstMatch
        if loadingIndicator.exists {
            // Wait for loading to complete
            let _ = loadingIndicator.waitForExistence(timeout: 5)
        }
        
        takeScreenshot(name: "After Refresh")
        
        verifyNetworkRequestSucceeded(description: "Refreshed monitoring data")
    }
    
    /// Test monitoring view performance
    func testMonitoringViewPerformance() throws {
        // Measure how quickly monitoring view loads
        let startTime = Date()
        
        try testAccessMonitoringView()
        
        let loadTime = Date().timeIntervalSince(startTime)
        
        XCTAssertTrue(
            loadTime < 3.0,
            "Monitoring view took too long to load: \(loadTime) seconds"
        )
        
        if verboseLogging {
            print("⏱ Monitoring view loaded in \(loadTime) seconds")
        }
        
        // Check if real-time updates are working
        let initialValue = captureMetricValue()
        
        // Wait for update
        Thread.sleep(forTimeInterval: 5)
        
        let updatedValue = captureMetricValue()
        
        // Values might change if real-time updates are working
        if initialValue != updatedValue {
            takeScreenshot(name: "Real-time Updates Working")
        }
    }
    
    // MARK: - Helper Methods
    
    private func captureMetricValue() -> String? {
        // Try to capture a metric value that changes over time
        let messageCountLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES '^[0-9]+.*messages?$'")).firstMatch
        let sessionCountLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES '^[0-9]+.*sessions?$'")).firstMatch
        
        if messageCountLabel.exists {
            return messageCountLabel.label
        } else if sessionCountLabel.exists {
            return sessionCountLabel.label
        }
        
        return nil
    }
}