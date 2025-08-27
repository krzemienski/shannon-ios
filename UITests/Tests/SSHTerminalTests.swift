import XCTest

/// Tests for SSH terminal sessions with real backend
class SSHTerminalTests: BaseUITest {
    
    // MARK: - Setup
    
    private var testProjectName: String!
    private let testSSHHost = ProcessInfo.processInfo.environment["TEST_SSH_HOST"] ?? "localhost"
    private let testSSHPort = ProcessInfo.processInfo.environment["TEST_SSH_PORT"] ?? "2222"
    private let testSSHUser = ProcessInfo.processInfo.environment["TEST_SSH_USER"] ?? "testuser"
    private let testSSHPassword = ProcessInfo.processInfo.environment["TEST_SSH_PASSWORD"] ?? "testpass123"
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Login before each test
        performLogin()
        
        // Create a test project with SSH configuration
        navigateToTab("Projects")
        testProjectName = createTestProject(name: "SSH Test \(Date().timeIntervalSince1970)")
        
        // Configure SSH for the project
        configureSSHForProject()
    }
    
    // MARK: - Helper Methods
    
    private func configureSSHForProject() {
        // Open project
        waitAndTap(app.cells.staticTexts[testProjectName])
        
        // Navigate to SSH Config
        waitAndTap(app.buttons["SSH Config"])
        
        // Configure SSH settings
        typeText(testSSHHost, in: app.textFields["Host"])
        typeText(testSSHPort, in: app.textFields["Port"])
        typeText(testSSHUser, in: app.textFields["Username"])
        
        // Use password authentication
        let authTypeSegment = app.segmentedControls.firstMatch
        if authTypeSegment.exists {
            authTypeSegment.buttons["Password"].tap()
            typeText(testSSHPassword, in: app.secureTextFields["Password"])
        }
        
        // Save configuration
        waitAndTap(app.buttons["Save"])
        waitForAPIResponse(timeout: apiTimeout)
        
        // Go back to project
        app.navigationBars.buttons.firstMatch.tap()
    }
    
    // MARK: - SSH Connection Tests
    
    /// Test establishing SSH connection
    func testEstablishSSHConnection() throws {
        // Navigate to Terminal
        waitAndTap(app.buttons["Terminal"])
        
        captureScreenshot(name: "01_terminal_view")
        
        // Start new SSH session
        let connectButton = app.buttons["Connect"]
        if !connectButton.exists {
            // Alternative: Look for new session button
            let newSessionButton = app.buttons["New Session"]
            if newSessionButton.exists {
                waitAndTap(newSessionButton)
            }
        } else {
            waitAndTap(connectButton)
        }
        
        // Wait for connection
        let connectionIndicator = app.activityIndicators["Connecting"]
        if connectionIndicator.exists {
            let predicate = NSPredicate(format: "exists == false")
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: connectionIndicator)
            wait(for: [expectation], timeout: apiTimeout)
        }
        
        // Verify connection established
        let terminalOutput = app.textViews["Terminal Output"]
        XCTAssertTrue(waitForElement(terminalOutput, timeout: apiTimeout),
                     "Terminal output should be visible after connection")
        
        // Look for connection success indicators
        let outputText = terminalOutput.value as? String ?? ""
        XCTAssertTrue(outputText.contains("Welcome") || 
                     outputText.contains("Last login") ||
                     outputText.contains("$") ||
                     outputText.contains("#"),
                     "Should show connection success indicators")
        
        captureScreenshot(name: "02_ssh_connected")
        
        // Verify session status
        XCTAssertTrue(app.staticTexts["Connected"].exists ||
                     app.images["connected_indicator"].exists,
                     "Should show connected status")
    }
    
    /// Test executing SSH commands
    func testExecuteSSHCommands() throws {
        try testEstablishSSHConnection()
        
        let terminalInput = app.textFields["Terminal Input"]
        let terminalOutput = app.textViews["Terminal Output"]
        
        // Test simple command
        typeText("echo 'Hello from SSH test'", in: terminalInput)
        app.buttons["Return"].tap() // or app.keyboards.buttons["return"].tap()
        
        // Wait for command execution
        Thread.sleep(forTimeInterval: 2.0)
        
        // Verify command output
        let outputText = terminalOutput.value as? String ?? ""
        XCTAssertTrue(outputText.contains("Hello from SSH test"),
                     "Should show command output")
        
        captureScreenshot(name: "01_command_executed")
        
        // Test ls command
        terminalInput.clearText()
        typeText("ls -la", in: terminalInput)
        app.buttons["Return"].tap()
        
        Thread.sleep(forTimeInterval: 2.0)
        
        // Verify ls output
        let lsOutput = terminalOutput.value as? String ?? ""
        XCTAssertTrue(lsOutput.contains("total") || lsOutput.contains("drwx"),
                     "Should show directory listing")
        
        // Test pwd command
        terminalInput.clearText()
        typeText("pwd", in: terminalInput)
        app.buttons["Return"].tap()
        
        Thread.sleep(forTimeInterval: 2.0)
        
        // Verify pwd output
        let pwdOutput = terminalOutput.value as? String ?? ""
        XCTAssertTrue(pwdOutput.contains("/home") || pwdOutput.contains("/Users"),
                     "Should show current directory")
        
        captureScreenshot(name: "02_multiple_commands")
    }
    
    /// Test file operations via SSH
    func testSSHFileOperations() throws {
        try testEstablishSSHConnection()
        
        let terminalInput = app.textFields["Terminal Input"]
        let terminalOutput = app.textViews["Terminal Output"]
        
        // Create a test file
        let fileName = "test_file_\(Date().timeIntervalSince1970).txt"
        typeText("echo 'Test content' > \(fileName)", in: terminalInput)
        app.buttons["Return"].tap()
        
        Thread.sleep(forTimeInterval: 2.0)
        
        // Verify file was created
        terminalInput.clearText()
        typeText("ls -la \(fileName)", in: terminalInput)
        app.buttons["Return"].tap()
        
        Thread.sleep(forTimeInterval: 2.0)
        
        let lsOutput = terminalOutput.value as? String ?? ""
        XCTAssertTrue(lsOutput.contains(fileName),
                     "Created file should be visible")
        
        // Read file content
        terminalInput.clearText()
        typeText("cat \(fileName)", in: terminalInput)
        app.buttons["Return"].tap()
        
        Thread.sleep(forTimeInterval: 2.0)
        
        let catOutput = terminalOutput.value as? String ?? ""
        XCTAssertTrue(catOutput.contains("Test content"),
                     "Should show file content")
        
        // Delete file
        terminalInput.clearText()
        typeText("rm \(fileName)", in: terminalInput)
        app.buttons["Return"].tap()
        
        Thread.sleep(forTimeInterval: 2.0)
        
        // Verify file deleted
        terminalInput.clearText()
        typeText("ls -la \(fileName)", in: terminalInput)
        app.buttons["Return"].tap()
        
        Thread.sleep(forTimeInterval: 2.0)
        
        let finalOutput = terminalOutput.value as? String ?? ""
        XCTAssertTrue(finalOutput.contains("No such file") || 
                     finalOutput.contains("cannot access"),
                     "File should be deleted")
        
        captureScreenshot(name: "ssh_file_operations")
    }
    
    /// Test SSH session tabs
    func testMultipleSSHSessions() throws {
        // Establish first session
        try testEstablishSSHConnection()
        
        // Create new tab/session
        let newTabButton = app.buttons["New Tab"]
        if !newTabButton.exists {
            // Alternative: Plus button
            let plusButton = app.buttons["plus"]
            if plusButton.exists {
                waitAndTap(plusButton)
            }
        } else {
            waitAndTap(newTabButton)
        }
        
        // Connect second session
        let connectButton = app.buttons["Connect"]
        if connectButton.exists {
            waitAndTap(connectButton)
        }
        
        // Wait for second connection
        Thread.sleep(forTimeInterval: 3.0)
        
        // Verify we have two sessions
        let tabBar = app.tabBars["Terminal Tabs"]
        if tabBar.exists {
            XCTAssertGreaterThanOrEqual(tabBar.buttons.count, 2,
                                       "Should have at least 2 session tabs")
        }
        
        captureScreenshot(name: "multiple_ssh_sessions")
        
        // Switch between tabs
        if tabBar.buttons.element(boundBy: 0).exists {
            tabBar.buttons.element(boundBy: 0).tap()
            
            // Verify we're on first session
            let terminalOutput = app.textViews["Terminal Output"]
            XCTAssertTrue(terminalOutput.exists,
                         "Should show first session output")
        }
        
        if tabBar.buttons.element(boundBy: 1).exists {
            tabBar.buttons.element(boundBy: 1).tap()
            
            // Verify we're on second session
            let terminalOutput = app.textViews["Terminal Output"]
            XCTAssertTrue(terminalOutput.exists,
                         "Should show second session output")
        }
    }
    
    /// Test SSH disconnection and reconnection
    func testSSHDisconnectReconnect() throws {
        try testEstablishSSHConnection()
        
        // Disconnect
        let disconnectButton = app.buttons["Disconnect"]
        if disconnectButton.exists {
            waitAndTap(disconnectButton)
            
            // Confirm disconnection
            if app.alerts.buttons["Disconnect"].exists {
                app.alerts.buttons["Disconnect"].tap()
            }
            
            // Verify disconnected state
            XCTAssertTrue(app.staticTexts["Disconnected"].exists ||
                         app.buttons["Connect"].exists,
                         "Should show disconnected state")
            
            captureScreenshot(name: "01_disconnected")
        }
        
        // Reconnect
        let connectButton = app.buttons["Connect"]
        if connectButton.exists {
            waitAndTap(connectButton)
            
            // Wait for reconnection
            waitForAPIResponse(timeout: apiTimeout)
            
            // Verify reconnected
            let terminalOutput = app.textViews["Terminal Output"]
            XCTAssertTrue(waitForElement(terminalOutput, timeout: apiTimeout),
                         "Should reconnect successfully")
            
            captureScreenshot(name: "02_reconnected")
        }
    }
    
    /// Test terminal output scrolling and history
    func testTerminalScrollingAndHistory() throws {
        try testEstablishSSHConnection()
        
        let terminalInput = app.textFields["Terminal Input"]
        let terminalOutput = app.textViews["Terminal Output"]
        
        // Execute multiple commands to fill terminal
        let commands = [
            "ls -la",
            "pwd",
            "date",
            "whoami",
            "uname -a",
            "echo 'Line 1'",
            "echo 'Line 2'",
            "echo 'Line 3'",
            "echo 'Line 4'",
            "echo 'Line 5'",
            "for i in {1..20}; do echo \"Line $i\"; done"
        ]
        
        for command in commands {
            terminalInput.clearText()
            typeText(command, in: terminalInput)
            app.buttons["Return"].tap()
            Thread.sleep(forTimeInterval: 1.0)
        }
        
        // Test scrolling
        terminalOutput.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        terminalOutput.swipeDown()
        
        // Verify output is preserved and scrollable
        let outputText = terminalOutput.value as? String ?? ""
        XCTAssertTrue(outputText.count > 100,
                     "Should have substantial output history")
        
        captureScreenshot(name: "terminal_with_history")
        
        // Test command history navigation
        // Press up arrow to get previous command
        if app.buttons["Up Arrow"].exists {
            app.buttons["Up Arrow"].tap()
            
            // Verify previous command appears in input
            let inputText = terminalInput.value as? String ?? ""
            XCTAssertTrue(commands.contains(inputText),
                         "Should show previous command from history")
        }
    }
    
    /// Test terminal copy/paste functionality
    func testTerminalCopyPaste() throws {
        try testEstablishSSHConnection()
        
        let terminalInput = app.textFields["Terminal Input"]
        let terminalOutput = app.textViews["Terminal Output"]
        
        // Execute a command
        typeText("echo 'Copy this text'", in: terminalInput)
        app.buttons["Return"].tap()
        
        Thread.sleep(forTimeInterval: 2.0)
        
        // Select and copy text from output
        terminalOutput.press(forDuration: 1.0)
        
        // Look for copy option
        if app.menuItems["Copy"].exists {
            app.menuItems["Copy"].tap()
        } else if app.buttons["Copy"].exists {
            app.buttons["Copy"].tap()
        }
        
        // Paste into input
        terminalInput.tap()
        terminalInput.press(forDuration: 1.0)
        
        if app.menuItems["Paste"].exists {
            app.menuItems["Paste"].tap()
            
            // Verify pasted content
            let inputText = terminalInput.value as? String ?? ""
            XCTAssertTrue(inputText.contains("Copy this text"),
                         "Should paste copied text")
            
            captureScreenshot(name: "terminal_copy_paste")
        }
    }
    
    /// Test terminal color and formatting
    func testTerminalColorFormatting() throws {
        try testEstablishSSHConnection()
        
        let terminalInput = app.textFields["Terminal Input"]
        
        // Execute command with colored output
        typeText("ls -la --color=always", in: terminalInput)
        app.buttons["Return"].tap()
        
        Thread.sleep(forTimeInterval: 2.0)
        
        // Verify colored elements exist (directories, executables, etc.)
        // This depends on the terminal implementation
        captureScreenshot(name: "terminal_with_colors")
        
        // Test ANSI escape sequences
        terminalInput.clearText()
        typeText("echo -e '\\033[31mRed\\033[0m \\033[32mGreen\\033[0m \\033[34mBlue\\033[0m'", in: terminalInput)
        app.buttons["Return"].tap()
        
        Thread.sleep(forTimeInterval: 2.0)
        
        captureScreenshot(name: "ansi_colors")
    }
    
    /// Test SSH key authentication
    func testSSHKeyAuthentication() throws {
        // Navigate to project SSH settings
        waitAndTap(app.cells.staticTexts[testProjectName])
        waitAndTap(app.buttons["SSH Config"])
        
        // Switch to key authentication
        let authTypeSegment = app.segmentedControls.firstMatch
        if authTypeSegment.exists {
            authTypeSegment.buttons["SSH Key"].tap()
            
            // Generate or select SSH key
            let generateKeyButton = app.buttons["Generate Key"]
            if generateKeyButton.exists {
                waitAndTap(generateKeyButton)
                
                // Wait for key generation
                waitForAPIResponse(timeout: apiTimeout)
                
                // Verify key was generated
                XCTAssertTrue(app.staticTexts["Key Generated"].exists ||
                             app.staticTexts["ssh-rsa"].exists,
                             "Should show generated key")
                
                captureScreenshot(name: "ssh_key_generated")
            }
            
            // Save configuration
            waitAndTap(app.buttons["Save"])
            waitForAPIResponse(timeout: apiTimeout)
            
            // Test connection with key
            app.navigationBars.buttons.firstMatch.tap()
            waitAndTap(app.buttons["Terminal"])
            
            let connectButton = app.buttons["Connect"]
            if connectButton.exists {
                waitAndTap(connectButton)
                
                // Note: Actual key authentication would require proper SSH server setup
                // This test verifies the UI flow
                Thread.sleep(forTimeInterval: 3.0)
                
                captureScreenshot(name: "ssh_key_connection_attempt")
            }
        }
    }
    
    /// Test port forwarding setup
    func testPortForwarding() throws {
        try testEstablishSSHConnection()
        
        // Open port forwarding settings
        let menuButton = app.navigationBars.buttons["more"]
        if menuButton.exists {
            waitAndTap(menuButton)
            
            let portForwardButton = app.buttons["Port Forwarding"]
            if portForwardButton.exists {
                waitAndTap(portForwardButton)
                
                // Add port forward
                let addButton = app.buttons["Add Port Forward"]
                if addButton.exists {
                    waitAndTap(addButton)
                    
                    // Configure port forward
                    typeText("8080", in: app.textFields["Local Port"])
                    typeText("localhost", in: app.textFields["Remote Host"])
                    typeText("80", in: app.textFields["Remote Port"])
                    
                    // Save
                    waitAndTap(app.buttons["Save"])
                    
                    // Verify port forward is active
                    XCTAssertTrue(app.staticTexts["8080 → localhost:80"].exists,
                                 "Should show active port forward")
                    
                    captureScreenshot(name: "port_forwarding_configured")
                }
            }
        }
    }
    
    // MARK: - Performance Tests
    
    /// Test SSH connection performance
    func testSSHConnectionPerformance() throws {
        measureAPIPerformance(operation: "SSH Connection") {
            // Navigate to Terminal
            waitAndTap(app.buttons["Terminal"])
            
            // Connect
            let connectButton = app.buttons["Connect"]
            if connectButton.exists {
                waitAndTap(connectButton)
                
                // Measure time to establish connection
                let terminalOutput = app.textViews["Terminal Output"]
                XCTAssertTrue(waitForElement(terminalOutput, timeout: apiTimeout),
                             "Should establish connection within timeout")
            }
        }
    }
    
    /// Test command execution performance
    func testCommandExecutionPerformance() throws {
        try testEstablishSSHConnection()
        
        let terminalInput = app.textFields["Terminal Input"]
        
        measureAPIPerformance(operation: "SSH Command Execution") {
            // Execute a simple command
            typeText("echo 'Performance test'", in: terminalInput)
            app.buttons["Return"].tap()
            
            // Measure time for output to appear
            Thread.sleep(forTimeInterval: 0.5) // Allow time for response
            
            let terminalOutput = app.textViews["Terminal Output"]
            let outputText = terminalOutput.value as? String ?? ""
            XCTAssertTrue(outputText.contains("Performance test"),
                         "Command should execute and show output quickly")
        }
    }
    
    /// Test terminal responsiveness with heavy output
    func testTerminalHeavyOutputPerformance() throws {
        try testEstablishSSHConnection()
        
        let terminalInput = app.textFields["Terminal Input"]
        
        measureAPIPerformance(operation: "Heavy Terminal Output") {
            // Generate heavy output
            typeText("for i in {1..100}; do echo \"Line $i: $(date)\"; done", in: terminalInput)
            app.buttons["Return"].tap()
            
            // Wait for command to complete
            Thread.sleep(forTimeInterval: 5.0)
            
            // Verify terminal remains responsive
            let terminalOutput = app.textViews["Terminal Output"]
            
            // Test scrolling performance
            terminalOutput.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
            terminalOutput.swipeDown()
            
            // Verify we can still interact
            terminalInput.tap()
            XCTAssertTrue(terminalInput.isEnabled,
                         "Terminal should remain responsive after heavy output")
        }
    }
}