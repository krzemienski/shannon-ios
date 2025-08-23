// Sources/Core/Telemetry/Storage/TelemetryStorage.swift
// Task: Telemetry Storage System Implementation
// This file handles local storage of telemetry events

import Foundation
import OSLog

/// Protocol for telemetry storage implementations
public protocol TelemetryStorageProtocol: Sendable {
    /// Store a telemetry event
    func store<T: TelemetryEvent>(_ event: T) async throws
    
    /// Store multiple events
    func storeBatch<T: TelemetryEvent>(_ events: [T]) async throws
    
    /// Retrieve events for upload
    func retrieveEvents(limit: Int) async throws -> [any TelemetryEvent]
    
    /// Delete events after successful upload
    func deleteEvents(ids: [UUID]) async throws
    
    /// Get total event count
    func getEventCount() async throws -> Int
    
    /// Clear all stored events
    func clearAll() async throws
    
    /// Prune old events based on age
    func pruneOldEvents(olderThan: Date) async throws
}

/// File-based telemetry storage implementation
public actor TelemetryFileStorage: TelemetryStorageProtocol {
    
    private let logger = Logger(subsystem: "com.claudecode.telemetry", category: "Storage")
    private let storageDirectory: URL
    private let maxFileSize: Int64 = 10 * 1024 * 1024 // 10 MB per file
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var currentFileIndex: Int = 0
    private let fileManager = FileManager.default
    
    public init() throws {
        // Create storage directory in app's documents
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageDirectory = documentsPath.appendingPathComponent("Telemetry", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
        
        // Initialize encoder settings
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Find current file index
        currentFileIndex = try findLatestFileIndex()
    }
    
    // MARK: - TelemetryStorageProtocol
    
    public func store<T: TelemetryEvent>(_ event: T) async throws {
        let data = try encoder.encode(event)
        try await writeEventData(data)
        
        logger.debug("Stored telemetry event: \(event.eventType.rawValue)")
    }
    
    public func storeBatch<T: TelemetryEvent>(_ events: [T]) async throws {
        for event in events {
            try await store(event)
        }
        
        logger.debug("Stored batch of \(events.count) telemetry events")
    }
    
    public func retrieveEvents(limit: Int) async throws -> [any TelemetryEvent] {
        var events: [any TelemetryEvent] = []
        let files = try getEventFiles()
        
        for file in files {
            if events.count >= limit { break }
            
            let fileEvents = try await readEventsFromFile(file)
            events.append(contentsOf: fileEvents.prefix(limit - events.count))
        }
        
        logger.debug("Retrieved \(events.count) telemetry events")
        return events
    }
    
    public func deleteEvents(ids: [UUID]) async throws {
        let idSet = Set(ids)
        let files = try getEventFiles()
        
        for file in files {
            var fileEvents = try await readEventsFromFile(file)
            let originalCount = fileEvents.count
            
            fileEvents.removeAll { idSet.contains($0.id) }
            
            if fileEvents.count < originalCount {
                if fileEvents.isEmpty {
                    // Delete empty file
                    try fileManager.removeItem(at: file)
                } else {
                    // Rewrite file with remaining events
                    try await writeEventsToFile(fileEvents, at: file)
                }
            }
        }
        
        logger.debug("Deleted \(ids.count) telemetry events")
    }
    
    public func getEventCount() async throws -> Int {
        let files = try getEventFiles()
        var count = 0
        
        for file in files {
            let fileEvents = try await readEventsFromFile(file)
            count += fileEvents.count
        }
        
        return count
    }
    
    public func clearAll() async throws {
        let files = try getEventFiles()
        
        for file in files {
            try fileManager.removeItem(at: file)
        }
        
        currentFileIndex = 0
        logger.info("Cleared all telemetry events")
    }
    
    public func pruneOldEvents(olderThan date: Date) async throws {
        let files = try getEventFiles()
        var totalPruned = 0
        
        for file in files {
            var fileEvents = try await readEventsFromFile(file)
            let originalCount = fileEvents.count
            
            fileEvents.removeAll { $0.timestamp < date }
            
            if fileEvents.count < originalCount {
                totalPruned += originalCount - fileEvents.count
                
                if fileEvents.isEmpty {
                    try fileManager.removeItem(at: file)
                } else {
                    try await writeEventsToFile(fileEvents, at: file)
                }
            }
        }
        
        logger.info("Pruned \(totalPruned) old telemetry events")
    }
    
    // MARK: - Private Methods
    
    private func findLatestFileIndex() throws -> Int {
        let files = try getEventFiles()
        
        guard !files.isEmpty else { return 0 }
        
        let indices = files.compactMap { file -> Int? in
            let filename = file.deletingPathExtension().lastPathComponent
            guard filename.hasPrefix("events_") else { return nil }
            return Int(filename.replacingOccurrences(of: "events_", with: ""))
        }
        
        return indices.max() ?? 0
    }
    
    private func getEventFiles() throws -> [URL] {
        let files = try fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: .skipsHiddenFiles
        )
        
        return files
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("events_") }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 < date2
            }
    }
    
    private func getCurrentFile() throws -> URL {
        let currentFile = storageDirectory.appendingPathComponent("events_\(currentFileIndex).json")
        
        // Check if current file exists and its size
        if fileManager.fileExists(atPath: currentFile.path) {
            let attributes = try fileManager.attributesOfItem(atPath: currentFile.path)
            if let fileSize = attributes[.size] as? Int64, fileSize >= maxFileSize {
                // Current file is full, create new one
                currentFileIndex += 1
                return storageDirectory.appendingPathComponent("events_\(currentFileIndex).json")
            }
        }
        
        return currentFile
    }
    
    private func writeEventData(_ data: Data) async throws {
        let file = try getCurrentFile()
        
        // Read existing events if file exists
        var events: [[String: Any]] = []
        if fileManager.fileExists(atPath: file.path),
           let existingData = try? Data(contentsOf: file),
           let existingEvents = try? JSONSerialization.jsonObject(with: existingData) as? [[String: Any]] {
            events = existingEvents
        }
        
        // Add new event
        if let newEvent = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            events.append(newEvent)
        }
        
        // Write back to file
        let updatedData = try JSONSerialization.data(withJSONObject: events, options: .prettyPrinted)
        try updatedData.write(to: file, options: .atomic)
    }
    
    private func readEventsFromFile(_ file: URL) async throws -> [any TelemetryEvent] {
        guard fileManager.fileExists(atPath: file.path) else { return [] }
        
        let data = try Data(contentsOf: file)
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        var events: [any TelemetryEvent] = []
        
        for json in jsonArray {
            guard let eventType = json["eventType"] as? String,
                  let type = TelemetryEventType(rawValue: eventType) else {
                continue
            }
            
            let eventData = try JSONSerialization.data(withJSONObject: json)
            
            switch type {
            case .performance:
                if let event = try? decoder.decode(PerformanceEvent.self, from: eventData) {
                    events.append(event)
                }
            case .error:
                if let event = try? decoder.decode(ErrorEvent.self, from: eventData) {
                    events.append(event)
                }
            case .userAction:
                if let event = try? decoder.decode(UserActionEvent.self, from: eventData) {
                    events.append(event)
                }
            case .sshConnection:
                if let event = try? decoder.decode(SSHConnectionEvent.self, from: eventData) {
                    events.append(event)
                }
            case .appLifecycle:
                if let event = try? decoder.decode(AppLifecycleEvent.self, from: eventData) {
                    events.append(event)
                }
            case .custom:
                if let event = try? decoder.decode(CustomEvent.self, from: eventData) {
                    events.append(event)
                }
            default:
                continue
            }
        }
        
        return events
    }
    
    private func writeEventsToFile(_ events: [any TelemetryEvent], at file: URL) async throws {
        var jsonArray: [[String: Any]] = []
        
        for event in events {
            let data = try encoder.encode(event)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                jsonArray.append(json)
            }
        }
        
        let data = try JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted)
        try data.write(to: file, options: .atomic)
    }
}

/// In-memory telemetry storage for testing
public actor InMemoryTelemetryStorage: TelemetryStorageProtocol {
    
    private var events: [any TelemetryEvent] = []
    private let maxEvents: Int
    
    public init(maxEvents: Int = 1000) {
        self.maxEvents = maxEvents
    }
    
    public func store<T: TelemetryEvent>(_ event: T) async throws {
        events.append(event)
        
        // Trim if exceeds max
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }
    
    public func storeBatch<T: TelemetryEvent>(_ events: [T]) async throws {
        for event in events {
            try await store(event)
        }
    }
    
    public func retrieveEvents(limit: Int) async throws -> [any TelemetryEvent] {
        Array(events.prefix(limit))
    }
    
    public func deleteEvents(ids: [UUID]) async throws {
        let idSet = Set(ids)
        events.removeAll { idSet.contains($0.id) }
    }
    
    public func getEventCount() async throws -> Int {
        events.count
    }
    
    public func clearAll() async throws {
        events.removeAll()
    }
    
    public func pruneOldEvents(olderThan date: Date) async throws {
        events.removeAll { $0.timestamp < date }
    }
}