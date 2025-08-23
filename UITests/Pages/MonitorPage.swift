//
//  MonitorPage.swift
//  ClaudeCodeUITests
//
//  Page object for Monitor screens
//

import XCTest

/// Page object for Monitor functionality
class MonitorPage: BasePage {
    
    // MARK: - Elements
    
    var monitorTab: XCUIElement {
        app.tabBars.buttons[AccessibilityIdentifier.tabBarMonitor]
    }
    
    var metricsView: XCUIElement {
        app.scrollViews["monitor.metrics"]
    }
    
    var performanceChart: XCUIElement {
        app.otherElements["monitor.performance.chart"]
    }
    
    var logsView: XCUIElement {
        app.tables["monitor.logs"]
    }
    
    var refreshButton: XCUIElement {
        app.buttons["monitor.refresh"]
    }
    
    var pauseButton: XCUIElement {
        app.buttons["monitor.pause"]
    }
    
    var clearButton: XCUIElement {
        app.buttons["monitor.clear"]
    }
    
    var filterButton: XCUIElement {
        app.buttons["monitor.filter"]
    }
    
    var exportButton: XCUIElement {
        app.buttons["monitor.export"]
    }
    
    // Metrics Elements
    var cpuUsageLabel: XCUIElement {
        app.staticTexts["monitor.cpu.usage"]
    }
    
    var memoryUsageLabel: XCUIElement {
        app.staticTexts["monitor.memory.usage"]
    }
    
    var networkLatencyLabel: XCUIElement {
        app.staticTexts["monitor.network.latency"]
    }
    
    var requestCountLabel: XCUIElement {
        app.staticTexts["monitor.request.count"]
    }
    
    var errorRateLabel: XCUIElement {
        app.staticTexts["monitor.error.rate"]
    }
    
    var uptimeLabel: XCUIElement {
        app.staticTexts["monitor.uptime"]
    }
    
    // Log Level Filters
    var debugToggle: XCUIElement {
        app.switches["monitor.filter.debug"]
    }
    
    var infoToggle: XCUIElement {
        app.switches["monitor.filter.info"]
    }
    
    var warningToggle: XCUIElement {
        app.switches["monitor.filter.warning"]
    }
    
    var errorToggle: XCUIElement {
        app.switches["monitor.filter.error"]
    }
    
    // Time Range Selector
    var timeRangeSelector: XCUIElement {
        app.segmentedControls["monitor.time.range"]
    }
    
    // Alert Threshold Controls
    var cpuThresholdSlider: XCUIElement {
        app.sliders["monitor.threshold.cpu"]
    }
    
    var memoryThresholdSlider: XCUIElement {
        app.sliders["monitor.threshold.memory"]
    }
    
    var errorThresholdSlider: XCUIElement {
        app.sliders["monitor.threshold.error"]
    }
    
    // MARK: - Actions
    
    func navigateToMonitor() {
        monitorTab.tap()
        waitForPage()
    }
    
    func refreshMetrics() {
        refreshButton.tap()
    }
    
    func pauseMonitoring() {
        pauseButton.tap()
    }
    
    func resumeMonitoring() {
        if pauseButton.label == "Resume" {
            pauseButton.tap()
        }
    }
    
    func clearLogs() {
        clearButton.tap()
        
        // Confirm clearing
        let confirmButton = app.alerts.buttons["Clear"]
        if confirmButton.waitForExistence(timeout: 2) {
            confirmButton.tap()
        }
    }
    
    func openFilters() {
        filterButton.tap()
    }
    
    func setLogLevelFilter(debug: Bool, info: Bool, warning: Bool, error: Bool) {
        openFilters()
        
        setToggleState(debugToggle, enabled: debug)
        setToggleState(infoToggle, enabled: info)
        setToggleState(warningToggle, enabled: warning)
        setToggleState(errorToggle, enabled: error)
        
        // Apply filters
        let applyButton = app.buttons["Apply"]
        if applyButton.exists {
            applyButton.tap()
        }
    }
    
    private func setToggleState(_ toggle: XCUIElement, enabled: Bool) {
        let currentState = toggle.value as? String == "1"
        if currentState != enabled {
            toggle.tap()
        }
    }
    
    func selectTimeRange(_ range: TimeRange) {
        timeRangeSelector.buttons[range.rawValue].tap()
    }
    
    enum TimeRange: String {
        case realtime = "Real-time"
        case lastHour = "1h"
        case lastDay = "24h"
        case lastWeek = "7d"
        case lastMonth = "30d"
    }
    
    func exportLogs() {
        exportButton.tap()
        
        // Select export format
        let formatSheet = app.sheets["Export Logs"]
        if formatSheet.waitForExistence(timeout: 2) {
            let jsonButton = formatSheet.buttons["JSON"]
            jsonButton.tap()
        }
    }
    
    func selectLogEntry(at index: Int) {
        let logEntry = logsView.cells.element(boundBy: index)
        logEntry.tap()
    }
    
    func searchLogs(_ query: String) {
        let searchField = app.searchFields["monitor.search"]
        searchField.tap()
        searchField.typeText(query)
    }
    
    // MARK: - Alert Threshold Actions
    
    func setCPUThreshold(_ value: Float) {
        cpuThresholdSlider.adjust(toNormalizedSliderPosition: CGFloat(value))
    }
    
    func setMemoryThreshold(_ value: Float) {
        memoryThresholdSlider.adjust(toNormalizedSliderPosition: CGFloat(value))
    }
    
    func setErrorThreshold(_ value: Float) {
        errorThresholdSlider.adjust(toNormalizedSliderPosition: CGFloat(value))
    }
    
    func enableAlerts() {
        let alertsToggle = app.switches["monitor.alerts.enabled"]
        if alertsToggle.value as? String != "1" {
            alertsToggle.tap()
        }
    }
    
    func disableAlerts() {
        let alertsToggle = app.switches["monitor.alerts.enabled"]
        if alertsToggle.value as? String == "1" {
            alertsToggle.tap()
        }
    }
    
    // MARK: - Performance Chart Actions
    
    func selectChartMetric(_ metric: ChartMetric) {
        let metricButton = app.buttons["chart.metric.\(metric.rawValue)"]
        metricButton.tap()
    }
    
    enum ChartMetric: String {
        case cpu = "cpu"
        case memory = "memory"
        case network = "network"
        case requests = "requests"
        case errors = "errors"
    }
    
    func zoomInChart() {
        performanceChart.pinch(withScale: 2.0, velocity: 1.0)
    }
    
    func zoomOutChart() {
        performanceChart.pinch(withScale: 0.5, velocity: -1.0)
    }
    
    func panChart(direction: SwipeDirection) {
        switch direction {
        case .left:
            performanceChart.swipeLeft()
        case .right:
            performanceChart.swipeRight()
        case .up:
            performanceChart.swipeUp()
        case .down:
            performanceChart.swipeDown()
        }
    }
    
    enum SwipeDirection {
        case left, right, up, down
    }
    
    // MARK: - Verification
    
    override func waitForPage(timeout: TimeInterval = 10) {
        _ = metricsView.waitForExistence(timeout: timeout)
    }
    
    func verifyCPUUsage() -> String? {
        return cpuUsageLabel.label
    }
    
    func verifyMemoryUsage() -> String? {
        return memoryUsageLabel.label
    }
    
    func verifyNetworkLatency() -> String? {
        return networkLatencyLabel.label
    }
    
    func verifyRequestCount() -> Int? {
        let countString = requestCountLabel.label
        return Int(countString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
    }
    
    func verifyErrorRate() -> String? {
        return errorRateLabel.label
    }
    
    func verifyUptime() -> String? {
        return uptimeLabel.label
    }
    
    func verifyLogEntryExists(containing text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let logEntry = logsView.cells.matching(predicate).firstMatch
        return logEntry.exists
    }
    
    func verifyMonitoringPaused() -> Bool {
        return pauseButton.label == "Resume"
    }
    
    func verifyAlertTriggered(for metric: String) -> Bool {
        let alert = app.staticTexts["alert.\(metric)"]
        return alert.exists
    }
    
    func getLogCount() -> Int {
        return logsView.cells.count
    }
    
    // MARK: - Advanced Monitoring Actions
    
    func createCustomAlert(name: String, condition: String, threshold: String) {
        let addAlertButton = app.buttons["monitor.add.alert"]
        addAlertButton.tap()
        
        let nameField = app.textFields["alert.name"]
        if nameField.waitForExistence(timeout: 2) {
            nameField.tap()
            nameField.typeText(name)
            
            let conditionField = app.textFields["alert.condition"]
            conditionField.tap()
            conditionField.typeText(condition)
            
            let thresholdField = app.textFields["alert.threshold"]
            thresholdField.tap()
            thresholdField.typeText(threshold)
            
            let saveButton = app.buttons["Save Alert"]
            saveButton.tap()
        }
    }
    
    func deleteAlert(named name: String) {
        let alertsList = app.tables["monitor.alerts.list"]
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        let alert = alertsList.cells.matching(predicate).firstMatch
        
        if alert.exists {
            alert.swipeLeft()
            
            let deleteButton = app.buttons["Delete"]
            if deleteButton.waitForExistence(timeout: 2) {
                deleteButton.tap()
            }
        }
    }
    
    func snoozeAlert(named name: String, duration: String) {
        let alertsList = app.tables["monitor.alerts.list"]
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        let alert = alertsList.cells.matching(predicate).firstMatch
        
        if alert.exists {
            alert.tap()
            
            let snoozeButton = app.buttons["Snooze"]
            if snoozeButton.waitForExistence(timeout: 2) {
                snoozeButton.tap()
                
                let durationPicker = app.pickers["snooze.duration"]
                // Select duration
                let durationOption = durationPicker.pickerWheels.firstMatch
                durationOption.adjust(toPickerWheelValue: duration)
                
                let confirmButton = app.buttons["Confirm"]
                confirmButton.tap()
            }
        }
    }
    
    func viewDetailedMetrics(for metric: ChartMetric) {
        selectChartMetric(metric)
        
        let detailButton = app.buttons["chart.detail"]
        if detailButton.exists {
            detailButton.tap()
        }
    }
    
    func compareMetrics(_ metric1: ChartMetric, _ metric2: ChartMetric) {
        let compareButton = app.buttons["monitor.compare"]
        compareButton.tap()
        
        let metric1Button = app.buttons["compare.\(metric1.rawValue)"]
        metric1Button.tap()
        
        let metric2Button = app.buttons["compare.\(metric2.rawValue)"]
        metric2Button.tap()
        
        let applyButton = app.buttons["Apply Comparison"]
        applyButton.tap()
    }
}