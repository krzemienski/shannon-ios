//
//  MonitorExportView.swift
//  ClaudeCode
//
//  Export monitoring data view
//

import SwiftUI

struct MonitorExportView: View {
    @EnvironmentObject var coordinator: MonitorCoordinator
    @State private var exportFormat: ExportViewFormat = .csv
    @State private var dateRange = ExportDateRange.lastWeek
    @State private var includeSSHLogs = true
    @State private var includePerformanceMetrics = true
    
    var body: some View {
        Form {
            Section("Export Format") {
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportViewFormat.allCases, id: \.self) { format in
                        Text(format.rawValue.uppercased()).tag(format)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section("Date Range") {
                Picker("Range", selection: $dateRange) {
                    ForEach(ExportDateRange.allCases, id: \.self) { range in
                        Text(range.title).tag(range)
                    }
                }
            }
            
            Section("Include Data") {
                Toggle("SSH Logs", isOn: $includeSSHLogs)
                Toggle("Performance Metrics", isOn: $includePerformanceMetrics)
            }
            
            Section {
                Button("Export Data") {
                    exportData()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Export Monitor Data")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func exportData() {
        // TODO: Implement export
        print("Exporting data as \(exportFormat.rawValue)")
    }
}

enum ExportViewFormat: String, CaseIterable {
    case csv = "csv"
    case json = "json"
    case xml = "xml"
}

enum ExportDateRange: CaseIterable {
    case today
    case lastWeek
    case lastMonth
    case custom
    
    var title: String {
        switch self {
        case .today: return "Today"
        case .lastWeek: return "Last 7 Days"
        case .lastMonth: return "Last 30 Days"
        case .custom: return "Custom Range"
        }
    }
}