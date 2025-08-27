//
//  SmokeTests.swift
//  ClaudeCodeUITests
//
//  Basic smoke tests to verify app launches and core functionality
//

import XCTest

final class SmokeTests: ClaudeCodeUITestCase {
    
    // MARK: - Tests
    
    func testAppLaunches() {
        // Test: Verify app launches successfully
        XCTAssertTrue(app.exists, "App should exist")
        
        // Take screenshot for evidence
        takeScreenshot(name: "App-Launch")
        
        // Verify main interface elements
        let mainView = app.otherElements["ContentView"]
        waitForElement(mainView, timeout: 5)
        
        XCTAssertTrue(mainView.exists || app.navigationBars.firstMatch.exists || app.tabBars.firstMatch.exists,
                      "Main interface should be visible")
    }
    
    func testBasicNavigation() {
        // Skip if no tab bar (might be onboarding)
        guard app.tabBars.firstMatch.exists else {
            XCTSkip("Tab bar not available - likely in onboarding flow")
            return
        }
        
        let tabBar = app.tabBars.firstMatch
        
        // Test tab navigation if tabs exist
        if tabBar.buttons.count > 0 {
            // Try to tap first available tab
            let firstTab = tabBar.buttons.element(boundBy: 0)
            if firstTab.exists && firstTab.isHittable {
                firstTab.tap()
                takeScreenshot(name: "First-Tab")
            }
            
            // Try to tap last available tab
            let lastIndex = tabBar.buttons.count - 1
            if lastIndex > 0 {
                let lastTab = tabBar.buttons.element(boundBy: lastIndex)
                if lastTab.exists && lastTab.isHittable {
                    lastTab.tap()
                    takeScreenshot(name: "Last-Tab")
                }
            }
        }
    }
    
    func testMemoryAndPerformance() {
        // Basic performance check
        measure {
            // Launch and navigate
            if app.tabBars.firstMatch.exists {
                let tabBar = app.tabBars.firstMatch
                for i in 0..<min(tabBar.buttons.count, 3) {
                    let tab = tabBar.buttons.element(boundBy: i)
                    if tab.exists && tab.isHittable {
                        tab.tap()
                    }
                }
            }
        }
    }
}