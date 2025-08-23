//
//  DataManagementView.swift
//  ClaudeCode
//
//  Data management settings view
//

import SwiftUI

struct DataManagementView: View {
    @EnvironmentObject var coordinator: SettingsCoordinator
    @State private var cacheSize = "0 MB"
    @State private var downloadedFiles = "0 MB"
    @State private var isClearing = false
    
    var body: some View {
        Form {
            Section("Storage") {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(cacheSize)
                        .foregroundColor(Theme.mutedForeground)
                }
                
                HStack {
                    Text("Downloaded Files")
                    Spacer()
                    Text(downloadedFiles)
                        .foregroundColor(Theme.mutedForeground)
                }
                
                Button("Clear Cache") {
                    clearCache()
                }
                .foregroundColor(.red)
            }
            
            Section("Backup") {
                Button("Export All Data") {
                    exportData()
                }
                
                Button("Import Data") {
                    importData()
                }
            }
            
            Section("Danger Zone") {
                Button("Delete All Data") {
                    deleteAllData()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateStorageUsage()
        }
    }
    
    private func calculateStorageUsage() {
        // TODO: Calculate actual storage usage
        cacheSize = "12.5 MB"
        downloadedFiles = "45.2 MB"
    }
    
    private func clearCache() {
        isClearing = true
        // TODO: Clear cache
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            cacheSize = "0 MB"
            isClearing = false
        }
    }
    
    private func exportData() {
        // TODO: Export data
    }
    
    private func importData() {
        // TODO: Import data
    }
    
    private func deleteAllData() {
        // TODO: Delete all data with confirmation
    }
}