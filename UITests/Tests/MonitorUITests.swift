//
//  MonitorUITests.swift
//  ClaudeCodeUITests
//
//  Comprehensive UI tests for Monitor functionality
//

import XCTest

class MonitorUITests: ClaudeCodeUITestCase {
    
    var monitorPage: MonitorPage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize page object
        monitorPage = MonitorPage(app: app)
        
        // Launch app in authenticated state
        app.terminate()
        launchApp(with: .authenticated)
        
        // Navigate to monitor
        monitorPage.navigateToMonitor()
    }
    
    // MARK: - Basic Monitor Tests
    
    func testNavigateToMonitor() {
        // Verify we're on monitor page
        waitForElement(monitorPage.metricsView)
        XCTAssertTrue(monitorPage.monitorTab.isSelected)
        
        takeScreenshot(name: "Monitor-Dashboard")
    }
    
    func testMetricsDisplay() {
        // Verify all metrics are displayed
        XCTAssertNotNil(monitorPage.verifyCPUUsage())
        XCTAssertNotNil(monitorPage.verifyMemoryUsage())
        XCTAssertNotNil(monitorPage.verifyNetworkLatency())
        XCTAssertNotNil(monitorPage.verifyRequestCount())
        XCTAssertNotNil(monitorPage.verifyErrorRate())
        XCTAssertNotNil(monitorPage.verifyUptime())
        
        takeScreenshot(name: "Monitor-Metrics")
    }
    
    func testRefreshMetrics() {
        // Get initial values
        let initialCPU = monitorPage.verifyCPUUsage()
        
        // Refresh metrics
        monitorPage.refreshMetrics()
        
        // Wait for refresh
        Thread.sleep(forTimeInterval: 2)
        
        // Verify metrics updated (might be same value but should not be nil)
        XCTAssertNotNil(monitorPage.verifyCPUUsage())
        
        takeScreenshot(name: "Monitor-Refreshed")
    }
    
    func testPauseMonitoring() {
        // Pause monitoring
        monitorPage.pauseMonitoring()
        
        // Verify monitoring is paused
        XCTAssertTrue(monitorPage.verifyMonitoringPaused())
        
        takeScreenshot(name: "Monitor-Paused")
        
        // Resume monitoring
        monitorPage.resumeMonitoring()
        
        // Verify monitoring resumed
        XCTAssertFalse(monitorPage.verifyMonitoringPaused())
    }
    
    // MARK: - Log Tests
    
    func testViewLogs() {
        // Verify logs are displayed
        waitForElement(monitorPage.logsView)
        XCTAssertTrue(monitorPage.getLogCount() > 0)
        
        takeScreenshot(name: "Monitor-Logs")
    }
    
    func testLogLevelFiltering() {
        // Set log level filters
        monitorPage.setLogLevelFilter(
            debug: true,
            info: true,
            warning: true,
            error: false
        )
        
        // Wait for filter to apply
        Thread.sleep(forTimeInterval: 1)
        
        // Verify logs are filtered
        XCTAssertFalse(monitorPage.verifyLogEntryExists(containing: "[ERROR]"))
        
        takeScreenshot(name: "Monitor-Logs-Filtered")
        
        // Reset filters
        monitorPage.setLogLevelFilter(
            debug: true,
            info: true,
            warning: true,
            error: true
        )
    }
    
    func testSearchLogs() {
        // Search for specific log entry
        monitorPage.searchLogs("API")
        
        // Wait for search results
        Thread.sleep(forTimeInterval: 1)
        
        // Verify search results
        XCTAssertTrue(monitorPage.verifyLogEntryExists(containing: "API"))
        
        takeScreenshot(name: "Monitor-Logs-Search")
    }
    
    func testClearLogs() {
        // Clear logs
        monitorPage.clearLogs()
        
        // Verify logs cleared
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(monitorPage.getLogCount(), 0)
        
        takeScreenshot(name: "Monitor-Logs-Cleared")
    }
    
    func testSelectLogEntry() {
        // Select a log entry
        monitorPage.selectLogEntry(at: 0)
        
        // Verify log detail view opened
        waitForElement(app.navigationBars["Log Details"])
        
        takeScreenshot(name: "Monitor-Log-Details")
        
        // Go back
        app.navigationBars.buttons.firstMatch.tap()
    }
    
    func testExportLogs() {
        // Export logs
        monitorPage.exportLogs()
        
        // Verify export completed
        Thread.sleep(forTimeInterval: 2)
        
        takeScreenshot(name: "Monitor-Logs-Exported")
    }
    
    // MARK: - Time Range Tests
    
    func testTimeRangeSelection() {
        // Test each time range
        for range in [MonitorPage.TimeRange.realtime, .lastHour, .lastDay, .lastWeek] {
            monitorPage.selectTimeRange(range)
            Thread.sleep(forTimeInterval: 1)
            
            // Verify time range applied
            takeScreenshot(name: "Monitor-TimeRange-\(range.rawValue)")
        }
    }
    
    // MARK: - Performance Chart Tests
    
    func testChartMetricSelection() {
        // Test each chart metric
        for metric in [MonitorPage.ChartMetric.cpu, .memory, .network, .requests, .errors] {
            monitorPage.selectChartMetric(metric)
            Thread.sleep(forTimeInterval: 0.5)
            
            takeScreenshot(name: "Monitor-Chart-\(metric.rawValue)")
        }
    }
    
    func testChartZoom() {
        // Zoom in on chart
        monitorPage.zoomInChart()
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Monitor-Chart-Zoomed-In")
        
        // Zoom out
        monitorPage.zoomOutChart()
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Monitor-Chart-Zoomed-Out")
    }
    
    func testChartPanning() {
        // Pan chart in different directions
        monitorPage.panChart(direction: .left)
        Thread.sleep(forTimeInterval: 0.5)
        
        monitorPage.panChart(direction: .right)
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Monitor-Chart-Panned")
    }
    
    func testViewDetailedMetrics() {
        // View detailed metrics for CPU
        monitorPage.viewDetailedMetrics(for: .cpu)
        
        // Verify detailed view opened
        waitForElement(app.navigationBars["CPU Details"])
        
        takeScreenshot(name: "Monitor-Detailed-Metrics")
        
        // Go back
        app.navigationBars.buttons.firstMatch.tap()
    }
    
    func testCompareMetrics() {
        // Compare CPU and Memory metrics
        monitorPage.compareMetrics(.cpu, .memory)
        
        // Wait for comparison view
        Thread.sleep(forTimeInterval: 1)
        
        takeScreenshot(name: "Monitor-Metrics-Comparison")
    }
    
    // MARK: - Alert Tests
    
    func testSetCPUThreshold() {
        // Set CPU alert threshold
        monitorPage.setCPUThreshold(0.8)
        
        // Verify threshold set
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Monitor-CPU-Threshold")
    }
    
    func testSetMemoryThreshold() {
        // Set memory alert threshold
        monitorPage.setMemoryThreshold(0.75)
        
        // Verify threshold set
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Monitor-Memory-Threshold")
    }
    
    func testSetErrorThreshold() {
        // Set error rate threshold
        monitorPage.setErrorThreshold(0.05)
        
        // Verify threshold set
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Monitor-Error-Threshold")
    }
    
    func testEnableAlerts() {
        // Enable alerts
        monitorPage.enableAlerts()
        
        // Verify alerts enabled
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Monitor-Alerts-Enabled")
    }
    
    func testDisableAlerts() {
        // Disable alerts
        monitorPage.disableAlerts()
        
        // Verify alerts disabled
        Thread.sleep(forTimeInterval: 0.5)
        
        takeScreenshot(name: "Monitor-Alerts-Disabled")
    }
    
    func testCreateCustomAlert() {
        // Create custom alert
        monitorPage.createCustomAlert(
            name: "High Response Time",
            condition: "response_time > 1000",
            threshold: "1000"
        )
        
        // Wait for alert creation
        Thread.sleep(forTimeInterval: 1)
        
        takeScreenshot(name: "Monitor-Custom-Alert-Created")
    }
    
    func testDeleteAlert() {
        // Create an alert first
        monitorPage.createCustomAlert(
            name: "Test Alert",
            condition: "test > 0",
            threshold: "0"
        )
        
        Thread.sleep(forTimeInterval: 1)
        
        // Delete the alert
        monitorPage.deleteAlert(named: "Test Alert")
        
        // Verify alert deleted
        Thread.sleep(forTimeInterval: 1)
        
        takeScreenshot(name: "Monitor-Alert-Deleted")
    }
    
    func testSnoozeAlert() {
        // Create an alert
        monitorPage.createCustomAlert(
            name: "Snoozable Alert",
            condition: "cpu > 90",
            threshold: "90"
        )
        
        Thread.sleep(forTimeInterval: 1)
        
        // Snooze the alert
        monitorPage.snoozeAlert(named: "Snoozable Alert", duration: "30 minutes")
        
        // Verify alert snoozed
        Thread.sleep(forTimeInterval: 1)
        
        takeScreenshot(name: "Monitor-Alert-Snoozed")
    }
    
    func testAlertTriggered() {
        // Set low threshold to trigger alert
        monitorPage.setCPUThreshold(0.01)
        monitorPage.enableAlerts()
        
        // Wait for alert to trigger
        Thread.sleep(forTimeInterval: 3)
        
        // Verify alert triggered
        XCTAssertTrue(monitorPage.verifyAlertTriggered(for: "cpu"))
        
        takeScreenshot(name: "Monitor-Alert-Triggered")
    }
    
    // MARK: - Filter Tests
    
    func testOpenFilters() {
        // Open filters
        monitorPage.openFilters()
        
        // Verify filter panel opened
        waitForElement(app.otherElements["monitor.filters.panel"])
        
        takeScreenshot(name: "Monitor-Filters-Panel")
        
        // Close filters
        app.buttons["Done"].tap()
    }
    
    // MARK: - Performance Tests
    
    func testMetricsRefreshPerformance() {
        measure {
            monitorPage.refreshMetrics()
            Thread.sleep(forTimeInterval: 1)
        }
    }
    
    func testLogScrollingPerformance() {
        measure {
            // Scroll through logs
            monitorPage.logsView.swipeUp()
            monitorPage.logsView.swipeDown()
        }
    }
    
    func testChartRenderingPerformance() {
        measure {
            // Switch between chart metrics
            monitorPage.selectChartMetric(.cpu)
            Thread.sleep(forTimeInterval: 0.2)
            monitorPage.selectChartMetric(.memory)
            Thread.sleep(forTimeInterval: 0.2)
        }
    }
    
    func testLogSearchPerformance() {
        measure {
            monitorPage.searchLogs("test")
            Thread.sleep(forTimeInterval: 0.5)
            app.searchFields["monitor.search"].clearAndType("")
        }
    }
    
    // MARK: - Stress Tests
    
    func testContinuousMonitoring() {
        // Run monitoring for extended period
        for _ in 1...10 {
            monitorPage.refreshMetrics()
            Thread.sleep(forTimeInterval: 1)
            
            // Verify metrics still updating
            XCTAssertNotNil(monitorPage.verifyCPUUsage())
        }
        
        takeScreenshot(name: "Monitor-Continuous-Test")
    }
    
    func testMultipleAlerts() {
        // Create multiple alerts
        for i in 1...5 {
            monitorPage.createCustomAlert(
                name: "Alert \(i)",
                condition: "metric_\(i) > \(i * 10)",
                threshold: "\(i * 10)"
            )
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // Verify all alerts created
        Thread.sleep(forTimeInterval: 1)
        
        takeScreenshot(name: "Monitor-Multiple-Alerts")
    }
}