// Sources/Core/Telemetry/Exporters/TelemetryExporter.swift
// Task: Telemetry Export System Implementation
// This file handles exporting telemetry data to various destinations

import Foundation
import OSLog
import Logging

/// Base protocol for telemetry exporters
public protocol TelemetryExporter: Sendable {
    /// Export a batch of events
    func export(_ events: [any TelemetryEvent]) async throws
    
    /// Export a single event
    func export(_ event: any TelemetryEvent) async throws
    
    /// Flush any pending exports
    func flush() async throws
    
    /// Shutdown the exporter
    func shutdown() async
}

/// JSON file exporter
public actor JSONFileExporter: TelemetryExporter {
    
    private let logger = Logger(label: "com.claudecode.telemetry.exporter.json")
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private var pendingEvents: [any TelemetryEvent] = []
    private let maxBatchSize = 100
    
    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    
    public func export(_ events: [any TelemetryEvent]) async throws {
        pendingEvents.append(contentsOf: events)
        
        if pendingEvents.count >= maxBatchSize {
            try await flush()
        }
    }
    
    public func export(_ event: any TelemetryEvent) async throws {
        pendingEvents.append(event)
        
        if pendingEvents.count >= maxBatchSize {
            try await flush()
        }
    }
    
    public func flush() async throws {
        guard !pendingEvents.isEmpty else { return }
        
        let eventsToWrite = pendingEvents
        pendingEvents.removeAll()
        
        // Convert events to JSON
        var jsonArray: [[String: Any]] = []
        
        for event in eventsToWrite {
            if let data = try? encoder.encode(event),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                jsonArray.append(json)
            }
        }
        
        // Write to file
        let data = try JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Append to existing file
            let handle = try FileHandle(forWritingTo: fileURL)
            handle.seekToEndOfFile()
            handle.write(",\n".data(using: .utf8)!)
            handle.write(data)
            try handle.close()
        } else {
            // Create new file
            try data.write(to: fileURL)
        }
        
        logger.info("Exported \(eventsToWrite.count) events to JSON file")
    }
    
    public func shutdown() async {
        try? await flush()
    }
}

/// CSV file exporter
public actor CSVFileExporter: TelemetryExporter {
    
    private let logger = Logger(label: "com.claudecode.telemetry.exporter.csv")
    private let fileURL: URL
    private var pendingEvents: [any TelemetryEvent] = []
    private let maxBatchSize = 100
    private var headerWritten = false
    
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    public func export(_ events: [any TelemetryEvent]) async throws {
        pendingEvents.append(contentsOf: events)
        
        if pendingEvents.count >= maxBatchSize {
            try await flush()
        }
    }
    
    public func export(_ event: any TelemetryEvent) async throws {
        pendingEvents.append(event)
        
        if pendingEvents.count >= maxBatchSize {
            try await flush()
        }
    }
    
    public func flush() async throws {
        guard !pendingEvents.isEmpty else { return }
        
        let eventsToWrite = pendingEvents
        pendingEvents.removeAll()
        
        var csvContent = ""
        
        // Write header if needed
        if !headerWritten && !FileManager.default.fileExists(atPath: fileURL.path) {
            csvContent += "timestamp,event_type,session_id,user_id,device_model,os_version,details\n"
            headerWritten = true
        }
        
        // Convert events to CSV rows
        for event in eventsToWrite {
            let row = formatEventAsCSV(event)
            csvContent += row + "\n"
        }
        
        // Write to file
        if let data = csvContent.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                handle.seekToEndOfFile()
                handle.write(data)
                try handle.close()
            } else {
                try data.write(to: fileURL)
            }
        }
        
        logger.info("Exported \(eventsToWrite.count) events to CSV file")
    }
    
    public func shutdown() async {
        try? await flush()
    }
    
    private func formatEventAsCSV(_ event: any TelemetryEvent) -> String {
        let timestamp = ISO8601DateFormatter().string(from: event.timestamp)
        let eventType = event.eventType.rawValue
        let sessionId = event.sessionId.uuidString
        let userId = event.userId ?? "anonymous"
        let deviceModel = event.deviceInfo.model
        let osVersion = event.deviceInfo.osVersion
        
        var details = ""
        
        switch event {
        case let performanceEvent as PerformanceEvent:
            details = "\(performanceEvent.metricName)=\(performanceEvent.value)\(performanceEvent.unit)"
        case let errorEvent as ErrorEvent:
            details = "Error: \(errorEvent.errorMessage)"
        case let userActionEvent as UserActionEvent:
            details = "Action: \(userActionEvent.actionName)"
        case let sshEvent as SSHConnectionEvent:
            details = "SSH: \(sshEvent.host):\(sshEvent.port) - \(sshEvent.status.rawValue)"
        default:
            details = "Event: \(eventType)"
        }
        
        // Escape CSV special characters
        let escapedDetails = details.replacingOccurrences(of: "\"", with: "\"\"")
        
        return "\"\(timestamp)\",\"\(eventType)\",\"\(sessionId)\",\"\(userId)\",\"\(deviceModel)\",\"\(osVersion)\",\"\(escapedDetails)\""
    }
}

/// Network endpoint exporter
public actor NetworkExporter: TelemetryExporter {
    
    private let logger = Logger(label: "com.claudecode.telemetry.exporter.network")
    private let endpoint: URL
    private let session: URLSession
    private var pendingEvents: [any TelemetryEvent] = []
    private let maxBatchSize = 50
    private let encoder = JSONEncoder()
    
    public init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
        encoder.dateEncodingStrategy = .iso8601
    }
    
    public func export(_ events: [any TelemetryEvent]) async throws {
        pendingEvents.append(contentsOf: events)
        
        if pendingEvents.count >= maxBatchSize {
            try await flush()
        }
    }
    
    public func export(_ event: any TelemetryEvent) async throws {
        pendingEvents.append(event)
        
        if pendingEvents.count >= maxBatchSize {
            try await flush()
        }
    }
    
    public func flush() async throws {
        guard !pendingEvents.isEmpty else { return }
        
        let eventsToSend = pendingEvents
        pendingEvents.removeAll()
        
        // Prepare request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode events
        let payload = TelemetryPayload(events: eventsToSend)
        let data = try encoder.encode(payload)
        request.httpBody = data
        
        // Send request
        do {
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    logger.info("Successfully exported \(eventsToSend.count) events to endpoint")
                } else {
                    logger.error("Failed to export events, status code: \(httpResponse.statusCode)")
                    // Re-add events to pending for retry
                    pendingEvents.append(contentsOf: eventsToSend)
                }
            }
        } catch {
            logger.error("Network export failed: \(error)")
            // Re-add events to pending for retry
            pendingEvents.append(contentsOf: eventsToSend)
            throw error
        }
    }
    
    public func shutdown() async {
        try? await flush()
    }
}

/// Console exporter for debugging
public actor ConsoleExporter: TelemetryExporter {
    
    private let logger = Logger(label: "com.claudecode.telemetry.exporter.console")
    private let detailed: Bool
    
    public init(detailed: Bool = false) {
        self.detailed = detailed
    }
    
    public func export(_ events: [any TelemetryEvent]) async throws {
        for event in events {
            try await export(event)
        }
    }
    
    public func export(_ event: any TelemetryEvent) async throws {
        if detailed {
            logDetailedEvent(event)
        } else {
            logSimpleEvent(event)
        }
    }
    
    public func flush() async throws {
        // Nothing to flush for console
    }
    
    public func shutdown() async {
        // Nothing to shutdown
    }
    
    private func logSimpleEvent(_ event: any TelemetryEvent) {
        logger.info("[\(event.eventType.rawValue)] \(event.timestamp)")
    }
    
    private func logDetailedEvent(_ event: any TelemetryEvent) {
        var message = """
        ========================================
        Event Type: \(event.eventType.rawValue)
        Timestamp: \(event.timestamp)
        Session ID: \(event.sessionId)
        User ID: \(event.userId ?? "anonymous")
        Device: \(event.deviceInfo.model) - iOS \(event.deviceInfo.osVersion)
        """
        
        switch event {
        case let performanceEvent as PerformanceEvent:
            message += """
            
            Metric: \(performanceEvent.metricName)
            Value: \(performanceEvent.value) \(performanceEvent.unit)
            """
            if let tags = performanceEvent.tags {
                message += "\nTags: \(tags)"
            }
            
        case let errorEvent as ErrorEvent:
            message += """
            
            Error Type: \(errorEvent.errorType)
            Message: \(errorEvent.errorMessage)
            Severity: \(errorEvent.severity.rawValue)
            """
            if let stackTrace = errorEvent.stackTrace {
                message += "\nStack Trace:\n\(stackTrace)"
            }
            
        case let userActionEvent as UserActionEvent:
            message += """
            
            Action: \(userActionEvent.actionName)
            Category: \(userActionEvent.category)
            """
            if let label = userActionEvent.label {
                message += "\nLabel: \(label)"
            }
            if let value = userActionEvent.value {
                message += "\nValue: \(value)"
            }
            
        case let sshEvent as SSHConnectionEvent:
            message += """
            
            Connection ID: \(sshEvent.connectionId)
            Host: \(sshEvent.host):\(sshEvent.port)
            Status: \(sshEvent.status.rawValue)
            """
            if let duration = sshEvent.duration {
                message += "\nDuration: \(duration)s"
            }
            if let errorReason = sshEvent.errorReason {
                message += "\nError: \(errorReason)"
            }
            
        case let lifecycleEvent as AppLifecycleEvent:
            message += """
            
            Lifecycle Event: \(lifecycleEvent.lifecycleEvent.rawValue)
            Current State: \(lifecycleEvent.currentState)
            """
            if let sessionDuration = lifecycleEvent.sessionDuration {
                message += "\nSession Duration: \(sessionDuration)s"
            }
            
        case let customEvent as CustomEvent:
            message += """
            
            Custom Event: \(customEvent.name)
            """
            if let category = customEvent.category {
                message += "\nCategory: \(category)"
            }
            message += "\nData: \(customEvent.data)"
            
        default:
            break
        }
        
        message += "\n========================================"
        
        logger.info("\(message)")
    }
}

/// Composite exporter that sends to multiple destinations
public actor CompositeExporter: TelemetryExporter {
    
    private let exporters: [TelemetryExporter]
    private let logger = Logger(label: "com.claudecode.telemetry.exporter.composite")
    
    public init(exporters: [TelemetryExporter]) {
        self.exporters = exporters
    }
    
    public func export(_ events: [any TelemetryEvent]) async throws {
        await withTaskGroup(of: Void.self) { group in
            for exporter in exporters {
                group.addTask {
                    do {
                        try await exporter.export(events)
                    } catch {
                        self.logger.error("Exporter failed: \(error)")
                    }
                }
            }
        }
    }
    
    public func export(_ event: any TelemetryEvent) async throws {
        await withTaskGroup(of: Void.self) { group in
            for exporter in exporters {
                group.addTask {
                    do {
                        try await exporter.export(event)
                    } catch {
                        self.logger.error("Exporter failed: \(error)")
                    }
                }
            }
        }
    }
    
    public func flush() async throws {
        await withTaskGroup(of: Void.self) { group in
            for exporter in exporters {
                group.addTask {
                    do {
                        try await exporter.flush()
                    } catch {
                        self.logger.error("Flush failed: \(error)")
                    }
                }
            }
        }
    }
    
    public func shutdown() async {
        await withTaskGroup(of: Void.self) { group in
            for exporter in exporters {
                group.addTask {
                    await exporter.shutdown()
                }
            }
        }
    }
}

// MARK: - Supporting Types

/// Telemetry payload for network export
struct TelemetryPayload: Codable {
    let events: [AnyTelemetryEvent]
    
    init(events: [any TelemetryEvent]) {
        self.events = events.map { AnyTelemetryEvent($0) }
    }
}

/// Type-erased telemetry event for encoding
struct AnyTelemetryEvent: Codable {
    let event: any TelemetryEvent
    
    init(_ event: any TelemetryEvent) {
        self.event = event
    }
    
    func encode(to encoder: Encoder) throws {
        try event.encode(to: encoder)
    }
    
    init(from decoder: Decoder) throws {
        // This would need to determine the event type and decode appropriately
        fatalError("Decoding not implemented")
    }
}