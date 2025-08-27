//
//  FileEditorView.swift
//  ClaudeCode
//
//  File editor view for project files with advanced syntax highlighting
//

import SwiftUI

struct FileEditorView: View {
    let projectId: String
    let filePath: String
    @EnvironmentObject var coordinator: ProjectsCoordinator
    @State private var fileContent = ""
    @State private var isEditing = false
    @State private var language: ProgrammingLanguage = .plainText
    @State private var hasUnsavedChanges = false
    @State private var showSaveAlert = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // File information
    private var fileName: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }
    
    private var fileExtension: String {
        URL(fileURLWithPath: filePath).pathExtension.lowercased()
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading file...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.destructive)
                    
                    Text("Error Loading File")
                        .font(.headline)
                        .foregroundColor(Theme.foreground)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Retry") {
                        loadFile()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
            } else {
                // Advanced code editor
                CodeEditorView(
                    text: $fileContent,
                    language: $language,
                    fileName: fileName
                )
                .onChange(of: fileContent) { _ in
                    hasUnsavedChanges = true
                }
            }
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if hasUnsavedChanges {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.warning)
                }
                
                Button(action: saveFile) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(!hasUnsavedChanges)
                
                Menu {
                    Button(action: reloadFile) {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    
                    Button(action: shareFile) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(action: duplicateFile) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    
                    Button(action: renameFile) {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: deleteFile) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            detectLanguage()
            loadFile()
        }
        .onDisappear {
            if hasUnsavedChanges {
                autoSaveFile()
            }
        }
        .alert("Unsaved Changes", isPresented: $showSaveAlert) {
            Button("Save", role: .none) {
                saveFile()
            }
            Button("Discard", role: .destructive) {
                hasUnsavedChanges = false
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. What would you like to do?")
        }
    }
    
    // MARK: - Methods
    
    private func detectLanguage() {
        language = ProgrammingLanguage.from(fileExtension: fileExtension)
    }
    
    private func loadFile() {
        isLoading = true
        errorMessage = nil
        
        // Simulate async file loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // TODO: Implement actual file loading from backend
            if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                fileContent = content
                hasUnsavedChanges = false
                isLoading = false
            } else {
                // For demo purposes, load sample content based on language
                loadSampleContent()
                isLoading = false
            }
        }
    }
    
    private func loadSampleContent() {
        switch language {
        case .swift:
            fileContent = """
            //
            //  \(fileName)
            //  \(projectId)
            //
            
            import SwiftUI
            
            struct ContentView: View {
                @State private var counter = 0
                
                var body: some View {
                    VStack(spacing: 20) {
                        Text("Hello, ClaudeCode!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Counter: \\(counter)")
                            .font(.title2)
                        
                        Button("Increment") {
                            counter += 1
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            
            #Preview {
                ContentView()
            }
            """
            
        case .python:
            fileContent = """
            #!/usr/bin/env python3
            # -*- coding: utf-8 -*-
            
            \"\"\"
            \(fileName)
            Project: \(projectId)
            \"\"\"
            
            import os
            import sys
            from typing import List, Optional
            
            
            class DataProcessor:
                \"\"\"Process and analyze data.\"\"\"
                
                def __init__(self, data: List[float]):
                    self.data = data
                    self._mean: Optional[float] = None
                
                def calculate_mean(self) -> float:
                    \"\"\"Calculate the mean of the data.\"\"\"
                    if not self.data:
                        return 0.0
                    
                    self._mean = sum(self.data) / len(self.data)
                    return self._mean
                
                def filter_outliers(self, threshold: float = 2.0) -> List[float]:
                    \"\"\"Filter outliers from the data.\"\"\"
                    if self._mean is None:
                        self.calculate_mean()
                    
                    return [x for x in self.data if abs(x - self._mean) < threshold]
            
            
            def main():
                \"\"\"Main entry point.\"\"\"
                data = [1.2, 3.4, 2.1, 8.9, 2.3, 2.8]
                processor = DataProcessor(data)
                
                mean = processor.calculate_mean()
                print(f"Mean: {mean:.2f}")
                
                filtered = processor.filter_outliers()
                print(f"Filtered data: {filtered}")
            
            
            if __name__ == "__main__":
                main()
            """
            
        case .javascript, .typescript:
            fileContent = """
            /**
             * \(fileName)
             * Project: \(projectId)
             */
            
            // Import dependencies
            import React, { useState, useEffect } from 'react';
            import axios from 'axios';
            
            // Constants
            const API_URL = 'https://api.example.com';
            const TIMEOUT = 5000;
            
            /**
             * Fetch data from API with retry logic
             * @param {string} endpoint - API endpoint
             * @param {number} retries - Number of retries
             * @returns {Promise<any>} - API response data
             */
            async function fetchWithRetry(endpoint, retries = 3) {
                for (let i = 0; i < retries; i++) {
                    try {
                        const response = await axios.get(`${API_URL}${endpoint}`, {
                            timeout: TIMEOUT
                        });
                        return response.data;
                    } catch (error) {
                        console.error(`Attempt ${i + 1} failed:`, error);
                        if (i === retries - 1) throw error;
                        await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
                    }
                }
            }
            
            /**
             * Custom hook for data fetching
             */
            export function useApiData(endpoint) {
                const [data, setData] = useState(null);
                const [loading, setLoading] = useState(true);
                const [error, setError] = useState(null);
                
                useEffect(() => {
                    const fetchData = async () => {
                        try {
                            setLoading(true);
                            const result = await fetchWithRetry(endpoint);
                            setData(result);
                        } catch (err) {
                            setError(err.message);
                        } finally {
                            setLoading(false);
                        }
                    };
                    
                    fetchData();
                }, [endpoint]);
                
                return { data, loading, error };
            }
            
            // Export default component
            export default function DataDisplay({ endpoint }) {
                const { data, loading, error } = useApiData(endpoint);
                
                if (loading) return <div>Loading...</div>;
                if (error) return <div>Error: {error}</div>;
                
                return (
                    <div>
                        <h1>Data</h1>
                        <pre>{JSON.stringify(data, null, 2)}</pre>
                    </div>
                );
            }
            """
            
        default:
            fileContent = """
            File: \(fileName)
            Project: \(projectId)
            
            This is a sample file content.
            The advanced code editor supports:
            - Syntax highlighting for 20+ languages
            - Line numbers with current line highlighting
            - Code completion and snippets
            - Find and replace with regex support
            - Multiple themes
            - And much more!
            """
        }
    }
    
    private func saveFile() {
        // TODO: Implement actual file saving to backend
        print("Saving file: \(filePath)")
        hasUnsavedChanges = false
        
        // Show success feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    private func autoSaveFile() {
        // TODO: Implement auto-save
        saveFile()
    }
    
    private func reloadFile() {
        if hasUnsavedChanges {
            showSaveAlert = true
        } else {
            loadFile()
        }
    }
    
    private func shareFile() {
        // TODO: Implement file sharing
        print("Share file: \(filePath)")
    }
    
    private func duplicateFile() {
        // TODO: Implement file duplication
        print("Duplicate file: \(filePath)")
    }
    
    private func renameFile() {
        // TODO: Implement file renaming
        print("Rename file: \(filePath)")
    }
    
    private func deleteFile() {
        // TODO: Implement file deletion
        print("Delete file: \(filePath)")
    }
}