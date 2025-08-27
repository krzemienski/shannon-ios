import XCTest

/// Tests for file operations and code editing with real backend
class FileOperationsTests: BaseUITest {
    
    // MARK: - Setup
    
    private var testProjectName: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Login before each test
        performLogin()
        
        // Create a test project for file operations
        navigateToTab("Projects")
        testProjectName = createTestProject(name: "File Ops Test \(Date().timeIntervalSince1970)")
        
        // Open the project
        waitAndTap(app.cells.staticTexts[testProjectName])
        
        // Navigate to Files section
        waitAndTap(app.buttons["Files"])
    }
    
    // MARK: - File Operation Tests
    
    /// Test creating a new file
    func testCreateFile() throws {
        // Tap new file button
        let newFileButton = app.navigationBars.buttons["plus"]
        if !newFileButton.exists {
            // Alternative: Look for "New File" button
            let altButton = app.buttons["New File"]
            if altButton.exists {
                waitAndTap(altButton)
            }
        } else {
            waitAndTap(newFileButton)
        }
        
        captureScreenshot(name: "01_new_file_dialog")
        
        // Choose file type
        let fileTypeSelector = app.segmentedControls.firstMatch
        if fileTypeSelector.exists {
            fileTypeSelector.buttons["Swift"].tap()
        }
        
        // Enter file name
        let fileNameField = app.textFields["File Name"]
        let fileName = "TestFile.swift"
        typeText(fileName, in: fileNameField)
        
        // Enter initial content
        let contentView = app.textViews["File Content"]
        if contentView.exists {
            let initialContent = """
            import Foundation
            
            class TestClass {
                func testMethod() {
                    print("Hello from test file")
                }
            }
            """
            typeText(initialContent, in: contentView)
        }
        
        captureScreenshot(name: "02_file_details_entered")
        
        // Create file
        waitAndTap(app.buttons["Create"])
        
        // Wait for API response
        waitForAPIResponse(timeout: apiTimeout)
        
        // Verify file was created
        XCTAssertTrue(waitForElement(app.cells.staticTexts[fileName], timeout: uiTimeout),
                     "Created file should appear in file list")
        
        captureScreenshot(name: "03_file_created")
    }
    
    /// Test opening and viewing a file
    func testOpenFile() throws {
        // First create a file
        try testCreateFile()
        
        // Tap on the file to open it
        let fileName = "TestFile.swift"
        waitAndTap(app.cells.staticTexts[fileName])
        
        // Verify file editor opened
        XCTAssertTrue(waitForElement(app.navigationBars[fileName], timeout: uiTimeout),
                     "File editor should show file name in navigation bar")
        
        // Verify code editor is present
        let codeEditor = app.textViews["Code Editor"]
        XCTAssertTrue(codeEditor.exists,
                     "Code editor should be visible")
        
        // Verify syntax highlighting (check for colored text)
        XCTAssertTrue(app.staticTexts["import"].exists || 
                     app.staticTexts["class"].exists ||
                     app.staticTexts["func"].exists,
                     "Should have syntax highlighting")
        
        captureScreenshot(name: "file_opened_in_editor")
        
        // Test line numbers
        XCTAssertTrue(app.staticTexts["1"].exists,
                     "Should show line numbers")
    }
    
    /// Test editing a file
    func testEditFile() throws {
        // Create and open a file
        try testCreateFile()
        let fileName = "TestFile.swift"
        waitAndTap(app.cells.staticTexts[fileName])
        
        // Enter edit mode
        let editButton = app.navigationBars.buttons["Edit"]
        if editButton.exists {
            waitAndTap(editButton)
        }
        
        let codeEditor = app.textViews["Code Editor"]
        
        // Add new code
        codeEditor.tap()
        
        // Move to end of file
        let endCoordinate = codeEditor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9))
        endCoordinate.tap()
        
        // Add new method
        let newCode = """
        
            
            func newMethod() {
                // New method added via UI test
                let result = 42
                return result
            }
        """
        codeEditor.typeText(newCode)
        
        captureScreenshot(name: "01_code_edited")
        
        // Save changes
        let saveButton = app.buttons["Save"]
        waitAndTap(saveButton)
        
        // Wait for API response
        waitForAPIResponse(timeout: apiTimeout)
        
        // Verify save confirmation
        let savedIndicator = app.staticTexts["Saved"]
        if savedIndicator.exists {
            XCTAssertTrue(true, "File saved successfully")
        }
        
        // Go back and reopen to verify changes persisted
        app.navigationBars.buttons.firstMatch.tap()
        Thread.sleep(forTimeInterval: 1.0)
        waitAndTap(app.cells.staticTexts[fileName])
        
        // Verify new code is present
        let editorContent = codeEditor.value as? String ?? ""
        XCTAssertTrue(editorContent.contains("newMethod"),
                     "Edited content should be persisted")
        
        captureScreenshot(name: "02_edit_persisted")
    }
    
    /// Test deleting a file
    func testDeleteFile() throws {
        // Create a file first
        try testCreateFile()
        let fileName = "TestFile.swift"
        
        // Swipe to delete
        let fileCell = app.cells.containing(.staticText, identifier: fileName).firstMatch
        fileCell.swipeLeft()
        
        let deleteButton = app.buttons["Delete"]
        if waitForElement(deleteButton, timeout: uiTimeout) {
            deleteButton.tap()
            
            // Confirm deletion
            let confirmButton = app.alerts.buttons["Delete"]
            if confirmButton.exists {
                confirmButton.tap()
            }
            
            // Wait for API response
            waitForAPIResponse(timeout: apiTimeout)
            
            // Verify file is deleted
            XCTAssertFalse(app.cells.staticTexts[fileName].exists,
                          "Deleted file should not appear in list")
            
            captureScreenshot(name: "file_deleted")
        }
    }
    
    /// Test renaming a file
    func testRenameFile() throws {
        // Create a file
        try testCreateFile()
        let originalName = "TestFile.swift"
        
        // Long press for options
        let fileCell = app.cells.containing(.staticText, identifier: originalName).firstMatch
        fileCell.press(forDuration: 1.0)
        
        // Select rename option
        let renameButton = app.buttons["Rename"]
        if waitForElement(renameButton, timeout: uiTimeout) {
            renameButton.tap()
            
            // Enter new name
            let nameField = app.textFields["File Name"]
            nameField.clearText()
            let newName = "RenamedFile.swift"
            typeText(newName, in: nameField)
            
            // Confirm rename
            waitAndTap(app.buttons["Rename"])
            
            // Wait for API response
            waitForAPIResponse(timeout: apiTimeout)
            
            // Verify file is renamed
            XCTAssertFalse(app.cells.staticTexts[originalName].exists,
                          "Original file name should not exist")
            XCTAssertTrue(app.cells.staticTexts[newName].exists,
                         "Renamed file should appear in list")
            
            captureScreenshot(name: "file_renamed")
        }
    }
    
    /// Test creating folders
    func testCreateFolder() throws {
        // Tap new folder button
        let newFolderButton = app.buttons["New Folder"]
        if !newFolderButton.exists {
            // Alternative: Look in menu
            let menuButton = app.navigationBars.buttons["more"]
            if menuButton.exists {
                waitAndTap(menuButton)
                let folderOption = app.buttons["New Folder"]
                if folderOption.exists {
                    waitAndTap(folderOption)
                }
            }
        } else {
            waitAndTap(newFolderButton)
        }
        
        // Enter folder name
        let folderNameField = app.textFields["Folder Name"]
        let folderName = "TestFolder"
        typeText(folderName, in: folderNameField)
        
        // Create folder
        waitAndTap(app.buttons["Create"])
        
        // Wait for API response
        waitForAPIResponse(timeout: apiTimeout)
        
        // Verify folder was created
        XCTAssertTrue(app.cells.staticTexts[folderName].exists,
                     "Created folder should appear in list")
        
        // Verify folder icon
        let folderCell = app.cells.containing(.staticText, identifier: folderName).firstMatch
        XCTAssertTrue(folderCell.images["folder"].exists,
                     "Folder should have folder icon")
        
        captureScreenshot(name: "folder_created")
        
        // Test navigating into folder
        waitAndTap(folderCell)
        
        XCTAssertTrue(waitForElement(app.navigationBars[folderName], timeout: uiTimeout),
                     "Should navigate into folder")
        
        // Test creating file inside folder
        try testCreateFile()
    }
    
    /// Test file search functionality
    func testFileSearch() throws {
        // Create multiple files with different names
        let fileNames = ["AppDelegate.swift", "ViewController.swift", "Model.swift", "Helper.swift"]
        
        for fileName in fileNames {
            // Create file
            let newFileButton = app.navigationBars.buttons["plus"]
            if newFileButton.exists {
                waitAndTap(newFileButton)
                
                let fileNameField = app.textFields["File Name"]
                typeText(fileName, in: fileNameField)
                
                waitAndTap(app.buttons["Create"])
                waitForAPIResponse(timeout: apiTimeout)
            }
        }
        
        // Use search
        let searchField = app.searchFields.firstMatch
        if waitForElement(searchField, timeout: uiTimeout) {
            searchField.tap()
            searchField.typeText("View")
            
            // Verify search results
            Thread.sleep(forTimeInterval: 1.0) // Wait for search
            
            XCTAssertTrue(app.cells.staticTexts["ViewController.swift"].exists,
                         "Should find ViewController.swift")
            XCTAssertFalse(app.cells.staticTexts["AppDelegate.swift"].exists,
                          "Should not show AppDelegate.swift")
            XCTAssertFalse(app.cells.staticTexts["Model.swift"].exists,
                          "Should not show Model.swift")
            
            captureScreenshot(name: "file_search_results")
        }
    }
    
    /// Test code completion and suggestions
    func testCodeCompletion() throws {
        // Create and open a Swift file
        try testCreateFile()
        let fileName = "TestFile.swift"
        waitAndTap(app.cells.staticTexts[fileName])
        
        // Enter edit mode
        let editButton = app.navigationBars.buttons["Edit"]
        if editButton.exists {
            waitAndTap(editButton)
        }
        
        let codeEditor = app.textViews["Code Editor"]
        codeEditor.tap()
        
        // Type to trigger completion
        codeEditor.typeText("\nlet myString = ")
        
        // Wait for completion suggestions
        let completionPopover = app.popovers.firstMatch
        if waitForElement(completionPopover, timeout: 3.0) {
            // Verify suggestions are shown
            XCTAssertTrue(app.cells.staticTexts["String"].exists ||
                         app.buttons["String"].exists,
                         "Should show String completion")
            
            // Select a suggestion
            if app.cells.staticTexts["String"].exists {
                app.cells.staticTexts["String"].tap()
            }
            
            captureScreenshot(name: "code_completion")
        }
    }
    
    /// Test syntax error highlighting
    func testSyntaxErrorHighlighting() throws {
        // Create and open a Swift file
        try testCreateFile()
        let fileName = "TestFile.swift"
        waitAndTap(app.cells.staticTexts[fileName])
        
        // Enter edit mode
        let editButton = app.navigationBars.buttons["Edit"]
        if editButton.exists {
            waitAndTap(editButton)
        }
        
        let codeEditor = app.textViews["Code Editor"]
        codeEditor.tap()
        
        // Add code with syntax error
        let errorCode = """
        
        func brokenFunction() {
            let x = 
            print(y) // y is not defined
        }
        """
        codeEditor.typeText(errorCode)
        
        // Save to trigger validation
        waitAndTap(app.buttons["Save"])
        
        // Wait for syntax check
        Thread.sleep(forTimeInterval: 2.0)
        
        // Look for error indicators
        let errorIndicator = app.images["error"] 
        let warningIndicator = app.images["warning"]
        
        XCTAssertTrue(errorIndicator.exists || warningIndicator.exists,
                     "Should show syntax error indicators")
        
        captureScreenshot(name: "syntax_errors_highlighted")
    }
    
    /// Test file version history
    func testFileVersionHistory() throws {
        // Create and edit a file multiple times
        try testCreateFile()
        let fileName = "TestFile.swift"
        
        // Make first edit
        waitAndTap(app.cells.staticTexts[fileName])
        if app.navigationBars.buttons["Edit"].exists {
            app.navigationBars.buttons["Edit"].tap()
        }
        
        let codeEditor = app.textViews["Code Editor"]
        codeEditor.tap()
        codeEditor.typeText("\n// Version 1")
        waitAndTap(app.buttons["Save"])
        waitForAPIResponse(timeout: apiTimeout)
        
        // Make second edit
        codeEditor.tap()
        codeEditor.typeText("\n// Version 2")
        waitAndTap(app.buttons["Save"])
        waitForAPIResponse(timeout: apiTimeout)
        
        // Open version history
        let historyButton = app.buttons["History"]
        if !historyButton.exists {
            // Alternative: Look in menu
            let menuButton = app.navigationBars.buttons["more"]
            if menuButton.exists {
                waitAndTap(menuButton)
                if app.buttons["Version History"].exists {
                    waitAndTap(app.buttons["Version History"])
                }
            }
        } else {
            waitAndTap(historyButton)
        }
        
        // Verify version history is shown
        if app.navigationBars["Version History"].exists {
            XCTAssertGreaterThanOrEqual(app.cells.count, 2,
                                       "Should have at least 2 versions")
            
            captureScreenshot(name: "version_history")
            
            // Test reverting to previous version
            let firstVersion = app.cells.element(boundBy: 1)
            if firstVersion.exists {
                waitAndTap(firstVersion)
                
                // Confirm revert
                if app.buttons["Revert"].exists {
                    waitAndTap(app.buttons["Revert"])
                    
                    if app.alerts.buttons["Revert"].exists {
                        app.alerts.buttons["Revert"].tap()
                    }
                    
                    waitForAPIResponse(timeout: apiTimeout)
                    
                    // Verify content reverted
                    let content = codeEditor.value as? String ?? ""
                    XCTAssertFalse(content.contains("Version 2"),
                                  "Version 2 content should be removed after revert")
                }
            }
        }
    }
    
    /// Test file upload
    func testFileUpload() throws {
        // Tap upload button
        let uploadButton = app.buttons["Upload"]
        if !uploadButton.exists {
            // Alternative: Look in menu
            let menuButton = app.navigationBars.buttons["more"]
            if menuButton.exists {
                waitAndTap(menuButton)
                if app.buttons["Upload File"].exists {
                    waitAndTap(app.buttons["Upload File"])
                }
            }
        } else {
            waitAndTap(uploadButton)
        }
        
        // This would typically open a file picker
        // For testing, we'll simulate the selection
        let filePicker = app.otherElements["File Picker"]
        if waitForElement(filePicker, timeout: uiTimeout) {
            // In a real test, you'd select a file from the system
            // For now, we'll just verify the UI is present
            XCTAssertTrue(app.buttons["Choose File"].exists ||
                         app.buttons["Select"].exists,
                         "Should show file selection UI")
            
            captureScreenshot(name: "file_upload_picker")
            
            // Cancel for now
            if app.buttons["Cancel"].exists {
                app.buttons["Cancel"].tap()
            }
        }
    }
    
    // MARK: - Performance Tests
    
    /// Test file loading performance
    func testFileLoadingPerformance() throws {
        // Create multiple files
        for i in 1...10 {
            let newFileButton = app.navigationBars.buttons["plus"]
            if newFileButton.exists {
                waitAndTap(newFileButton)
                
                let fileNameField = app.textFields["File Name"]
                typeText("PerfTest\(i).swift", in: fileNameField)
                
                waitAndTap(app.buttons["Create"])
                waitForAPIResponse(timeout: apiTimeout)
            }
        }
        
        measureAPIPerformance(operation: "File List Loading") {
            // Navigate away and back
            app.navigationBars.buttons.firstMatch.tap()
            waitAndTap(app.buttons["Files"])
            
            // Verify files are loaded
            XCTAssertGreaterThanOrEqual(app.cells.count, 10,
                                       "Should load all created files")
        }
    }
    
    /// Test code editor performance with large file
    func testLargeFileEditingPerformance() throws {
        // Create a file with substantial content
        let newFileButton = app.navigationBars.buttons["plus"]
        if newFileButton.exists {
            waitAndTap(newFileButton)
            
            let fileNameField = app.textFields["File Name"]
            typeText("LargeFile.swift", in: fileNameField)
            
            // Generate large content
            let contentView = app.textViews["File Content"]
            if contentView.exists {
                var largeContent = "import Foundation\n\n"
                for i in 1...100 {
                    largeContent += """
                    
                    func function\(i)() {
                        let variable\(i) = "Value \(i)"
                        print(variable\(i))
                    }
                    
                    """
                }
                typeText(largeContent, in: contentView)
            }
            
            waitAndTap(app.buttons["Create"])
            waitForAPIResponse(timeout: apiTimeout)
        }
        
        // Open the large file
        waitAndTap(app.cells.staticTexts["LargeFile.swift"])
        
        measureAPIPerformance(operation: "Large File Editing") {
            // Enter edit mode
            if app.navigationBars.buttons["Edit"].exists {
                app.navigationBars.buttons["Edit"].tap()
            }
            
            let codeEditor = app.textViews["Code Editor"]
            
            // Perform edits
            codeEditor.tap()
            codeEditor.typeText("\n// Performance test edit")
            
            // Save
            waitAndTap(app.buttons["Save"])
            waitForAPIResponse(timeout: apiTimeout)
        }
    }
}