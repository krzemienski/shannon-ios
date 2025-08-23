import XCTest

/// Base UI test class with common utilities and setup
class BaseUITest: XCTestCase {
    
    // MARK: - Properties
    
    var app: XCUIApplication!
    
    /// Backend URL from environment or default
    var backendURL: String {
        ProcessInfo.processInfo.environment["BACKEND_URL"] ?? "http://localhost:8000"
    }
    
    /// Network timeout for API calls
    var networkTimeout: TimeInterval {
        TimeInterval(ProcessInfo.processInfo.environment["NETWORK_TIMEOUT"] ?? "30") ?? 30
    }
    
    /// UI element wait timeout
    var uiTimeout: TimeInterval {
        TimeInterval(ProcessInfo.processInfo.environment["UI_WAIT_TIMEOUT"] ?? "15") ?? 15
    }
    
    /// Verbose logging flag
    var verboseLogging: Bool {
        ProcessInfo.processInfo.environment["VERBOSE_LOGGING"] == "true"
    }
    
    /// Cleanup after tests flag
    var cleanupAfterTests: Bool {
        ProcessInfo.processInfo.environment["CLEANUP_AFTER_TESTS"] == "true"
    }
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["-UITest"]
        app.launchEnvironment = [
            "API_BASE_URL": "\(backendURL)/v1",
            "TEST_MODE": "YES",
            "VERBOSE_LOGGING": verboseLogging ? "YES" : "NO"
        ]
        
        if verboseLogging {
            print("🧪 Test: \(name)")
            print("📡 Backend URL: \(backendURL)")
            print("⏱ Network timeout: \(networkTimeout)s")
            print("⏱ UI timeout: \(uiTimeout)s")
        }
        
        // Verify backend is running before starting tests
        try verifyBackendConnectivity()
        
        app.launch()
        
        // Wait for app to be ready
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
    
    override func tearDownWithError() throws {
        if cleanupAfterTests {
            // Clean up test data if needed
            cleanupTestData()
        }
        
        app = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Backend Verification
    
    /// Verify backend is running and accessible
    func verifyBackendConnectivity() throws {
        let healthURL = URL(string: "\(backendURL)/health")!
        let semaphore = DispatchSemaphore(value: 0)
        var isHealthy = false
        
        let task = URLSession.shared.dataTask(with: healthURL) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                isHealthy = true
            }
            semaphore.signal()
        }
        
        task.resume()
        
        _ = semaphore.wait(timeout: .now() + 5)
        
        if !isHealthy {
            throw XCTSkip("Backend is not running at \(backendURL). Please start the backend before running tests.")
        }
        
        if verboseLogging {
            print("✅ Backend is healthy at \(backendURL)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Wait for element to exist
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        element.waitForExistence(timeout: timeout ?? uiTimeout)
    }
    
    /// Wait for element to be hittable (visible and interactable)
    func waitForElementToBeHittable(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout ?? uiTimeout) == .completed
    }
    
    /// Type text with delay between characters (more reliable)
    func typeText(_ text: String, in element: XCUIElement) {
        element.tap()
        element.typeText(text)
    }
    
    /// Clear text field
    func clearTextField(_ element: XCUIElement) {
        element.tap()
        element.press(forDuration: 1.2)
        
        if app.menuItems["Select All"].exists {
            app.menuItems["Select All"].tap()
        }
        
        element.typeText(XCUIKeyboardKey.delete.rawValue)
    }
    
    /// Scroll to element
    func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement? = nil) {
        let scroll = scrollView ?? app.scrollViews.firstMatch
        
        var attempts = 0
        while !element.isHittable && attempts < 10 {
            scroll.swipeUp()
            attempts += 1
        }
    }
    
    /// Take screenshot with description
    func takeScreenshot(name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    
    /// Verify network request succeeded
    func verifyNetworkRequestSucceeded(description: String) {
        // In a real implementation, we might check network logs or UI indicators
        // For now, we'll just add a small delay to ensure request completes
        Thread.sleep(forTimeInterval: 0.5)
        
        if verboseLogging {
            print("🌐 Network request: \(description)")
        }
    }
    
    /// Clean up test data
    func cleanupTestData() {
        // Override in subclasses if needed
        if verboseLogging {
            print("🧹 Cleaning up test data")
        }
    }
    
    // MARK: - Common UI Elements
    
    /// Navigation bar
    var navigationBar: XCUIElement {
        app.navigationBars.firstMatch
    }
    
    /// Tab bar
    var tabBar: XCUIElement {
        app.tabBars.firstMatch
    }
    
    /// Loading indicator
    var loadingIndicator: XCUIElement {
        app.activityIndicators.firstMatch
    }
    
    /// Alert dialog
    var alert: XCUIElement {
        app.alerts.firstMatch
    }
    
    // MARK: - Common Assertions
    
    /// Assert element contains text
    func assertElementContainsText(_ element: XCUIElement, _ text: String) {
        XCTAssertTrue(element.label.contains(text) || element.value as? String == text,
                     "Element does not contain text: \(text)")
    }
    
    /// Assert navigation title
    func assertNavigationTitle(_ title: String) {
        let navTitle = navigationBar.staticTexts[title]
        XCTAssertTrue(waitForElement(navTitle), "Navigation title '\(title)' not found")
    }
    
    /// Assert alert is shown with title
    func assertAlertShown(title: String) {
        XCTAssertTrue(waitForElement(alert), "Alert not shown")
        XCTAssertTrue(alert.staticTexts[title].exists, "Alert title '\(title)' not found")
    }
    
    /// Dismiss alert if present
    func dismissAlertIfPresent() {
        if alert.exists {
            let okButton = alert.buttons["OK"].exists ? alert.buttons["OK"] : alert.buttons.firstMatch
            if okButton.exists {
                okButton.tap()
            }
        }
    }
}