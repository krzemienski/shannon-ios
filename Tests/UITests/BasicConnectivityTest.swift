//
//  BasicConnectivityTest.swift
//  ClaudeCodeUITests
//
//  Basic connectivity test to verify backend connection
//

import XCTest

final class BasicConnectivityTest: XCTestCase {
    
    let app = XCUIApplication()
    let backendURL = "http://localhost:8000"
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // Set environment variable for backend URL
        app.launchEnvironment = [
            "BACKEND_URL": backendURL,
            "UI_TEST_MODE": "true"
        ]
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    // MARK: - Backend Connectivity Tests
    
    func testBackendHealthCheck() throws {
        // Test direct backend connectivity (health has no v1 prefix)
        let session = URLSession.shared
        let url = URL(string: "\(backendURL)/health")!
        
        let expectation = XCTestExpectation(description: "Backend health check")
        
        let task = session.dataTask(with: url) { data, response, error in
            XCTAssertNil(error, "Backend connection failed: \(error?.localizedDescription ?? "unknown error")")
            
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 200, "Backend health check failed with status: \(httpResponse.statusCode)")
            }
            
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Backend returns empty object for health check
                        print("✅ Backend health check successful")
                    }
                } catch {
                    XCTFail("Failed to parse health response: \(error)")
                }
            }
            
            expectation.fulfill()
        }
        
        task.resume()
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testBackendModelsEndpoint() throws {
        // Test models endpoint with v1 prefix
        let session = URLSession.shared
        let url = URL(string: "\(backendURL)/v1/models")!
        
        let expectation = XCTestExpectation(description: "Backend models check")
        
        let task = session.dataTask(with: url) { data, response, error in
            XCTAssertNil(error, "Models endpoint failed: \(error?.localizedDescription ?? "unknown error")")
            
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 200, "Models endpoint failed with status: \(httpResponse.statusCode)")
            }
            
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Models endpoint returns empty object or list
                        print("✅ Backend models endpoint successful")
                    }
                } catch {
                    XCTFail("Failed to parse models response: \(error)")
                }
            }
            
            expectation.fulfill()
        }
        
        task.resume()
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - App Launch Tests
    
    func testAppLaunchesSuccessfully() throws {
        // Verify app launches
        XCTAssertTrue(app.exists, "App did not launch")
        
        // Wait for initial view to appear
        let predicate = NSPredicate(format: "exists == true")
        let query = app.descendants(matching: .any)
        
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: query.firstMatch)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        
        XCTAssertEqual(result, .completed, "App UI did not appear within timeout")
        print("✅ App launched successfully")
    }
    
    func testInitialViewElements() throws {
        // Wait for app to stabilize
        sleep(2)
        
        // Check if any views are present
        let viewCount = app.descendants(matching: .any).count
        XCTAssertGreaterThan(viewCount, 0, "No UI elements found")
        
        print("✅ Found \(viewCount) UI elements")
        
        // Try to find common UI elements
        let buttons = app.buttons.allElementsBoundByIndex
        let textFields = app.textFields.allElementsBoundByIndex
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        
        print("📊 UI Element Summary:")
        print("   - Buttons: \(buttons.count)")
        print("   - TextFields: \(textFields.count)")
        print("   - StaticTexts: \(staticTexts.count)")
    }
    
    // MARK: - Mock Test for Basic Flow
    
    func testBasicUserFlow() throws {
        // This test will evolve as the app builds successfully
        print("🔄 Starting basic user flow test...")
        
        // Wait for app to load
        sleep(3)
        
        // Try to interact with any available buttons
        let firstButton = app.buttons.firstMatch
        if firstButton.exists && firstButton.isHittable {
            firstButton.tap()
            print("✅ Tapped first available button")
            sleep(1)
        }
        
        // Try to find and interact with text fields
        let firstTextField = app.textFields.firstMatch
        if firstTextField.exists && firstTextField.isHittable {
            firstTextField.tap()
            firstTextField.typeText("Test input")
            print("✅ Entered text in first available field")
        }
        
        // Take a screenshot for debugging
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Basic Flow Screenshot"
        attachment.lifetime = .keepAlways
        add(attachment)
        
        print("📸 Screenshot captured for debugging")
    }
}

// MARK: - Test Suite Runner

class FunctionalUITestSuite: XCTestCase {
    
    override class var defaultTestSuite: XCTestSuite {
        let suite = XCTestSuite(name: "Functional UI Tests")
        
        // Add connectivity tests
        suite.addTest(BasicConnectivityTest(selector: #selector(BasicConnectivityTest.testBackendHealthCheck)))
        suite.addTest(BasicConnectivityTest(selector: #selector(BasicConnectivityTest.testBackendModelsEndpoint)))
        
        // Add app tests
        suite.addTest(BasicConnectivityTest(selector: #selector(BasicConnectivityTest.testAppLaunchesSuccessfully)))
        suite.addTest(BasicConnectivityTest(selector: #selector(BasicConnectivityTest.testInitialViewElements)))
        suite.addTest(BasicConnectivityTest(selector: #selector(BasicConnectivityTest.testBasicUserFlow)))
        
        return suite
    }
    
    func testRunFullSuite() {
        // This triggers the full test suite
        print("🚀 Running Functional UI Test Suite")
        print("🔗 Backend URL: http://localhost:8000")
        print("📱 Testing on: iPhone 16 Pro Max (iOS 18.6)")
        print("=" * 50)
    }
}