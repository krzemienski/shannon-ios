// Sources/Core/Telemetry/Models/TelemetryEvent.swift
// Task: Telemetry Event Models Implementation
// This file defines the core telemetry event structures

import Foundation
#if os(iOS)
import UIKit
#endif

/// Base protocol for all telemetry events
public protocol TelemetryEvent: Codable, Sendable {
    /// Unique identifier for the event
    var id: UUID { get }
    
    /// Timestamp when the event was created
    var timestamp: Date { get }
    
    /// Event type identifier
    var eventType: TelemetryEventType { get }
    
    /// Session identifier for grouping events
    var sessionId: UUID { get }
    
    /// User identifier (anonymized)
    var userId: String? { get }
    
    /// Device information
    var deviceInfo: DeviceInfo { get }
    
    /// Additional metadata
    var metadata: [String: AnyCodable]? { get }
}

/// Types of telemetry events
public enum TelemetryEventType: String, Codable, CaseIterable, Sendable {
    case performance = "performance"
    case error = "error"
    case userAction = "user_action"
    case systemEvent = "system_event"
    case networkRequest = "network_request"
    case sshConnection = "ssh_connection"
    case appLifecycle = "app_lifecycle"
    case custom = "custom"
}

/// Device information for context
public struct DeviceInfo: Codable, Sendable {
    public let model: String
    public let osVersion: String
    public let appVersion: String
    public let buildNumber: String
    public let screenResolution: String
    public let isSimulator: Bool
    public let locale: String
    public let timezone: String
    public let availableMemory: Int64?
    public let availableStorage: Int64?
    public let batteryLevel: Float?
    public let isLowPowerMode: Bool
    public let networkType: String?
    
    public init(
        model: String = "",
        osVersion: String = "",
        appVersion: String = "",
        buildNumber: String = "",
        screenResolution: String = "",
        isSimulator: Bool = false,
        locale: String = "",
        timezone: String = "",
        availableMemory: Int64? = nil,
        availableStorage: Int64? = nil,
        batteryLevel: Float? = nil,
        isLowPowerMode: Bool = false,
        networkType: String? = nil
    ) {
        self.model = model
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.screenResolution = screenResolution
        self.isSimulator = isSimulator
        self.locale = locale
        self.timezone = timezone
        self.availableMemory = availableMemory
        self.availableStorage = availableStorage
        self.batteryLevel = batteryLevel
        self.isLowPowerMode = isLowPowerMode
        self.networkType = networkType
    }
    
    /// Creates a default device info placeholder
    public static func placeholder() -> DeviceInfo {
        return DeviceInfo()
    }
    
    /// Creates device info from current device
    @MainActor
    public static func current() -> DeviceInfo {
        #if os(iOS)
        let device = UIDevice.current
        let screen = UIScreen.main
        let locale = Locale.current
        let timezone = TimeZone.current
        let processInfo = Foundation.ProcessInfo.processInfo
        
        // Get app version and build
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        // Get screen resolution
        let screenResolution = "\(Int(screen.bounds.width))x\(Int(screen.bounds.height))@\(Int(screen.scale))x"
        
        // Check if simulator
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        
        // Get memory info
        let availableMemory = processInfo.physicalMemory
        
        // Get battery info
        device.isBatteryMonitoringEnabled = true
        let batteryLevel = device.batteryLevel
        let isLowPowerMode = processInfo.isLowPowerModeEnabled
        
        return DeviceInfo(
            model: device.model,
            osVersion: device.systemVersion,
            appVersion: appVersion,
            buildNumber: buildNumber,
            screenResolution: screenResolution,
            isSimulator: isSimulator,
            locale: locale.identifier,
            timezone: timezone.identifier,
            availableMemory: Int64(availableMemory),
            availableStorage: nil, // TODO: Implement storage calculation
            batteryLevel: batteryLevel,
            isLowPowerMode: isLowPowerMode,
            networkType: nil // TODO: Implement network type detection
        )
        #else
        return DeviceInfo()
        #endif
    }
}

/// Performance telemetry event
public struct PerformanceEvent: TelemetryEvent {
    public let id: UUID
    public let timestamp: Date
    public let eventType: TelemetryEventType = .performance
    public let sessionId: UUID
    public let userId: String?
    public let deviceInfo: DeviceInfo
    public let metadata: [String: AnyCodable]?
    
    // Performance specific fields
    public let metricName: String
    public let value: Double
    public let unit: String
    public let tags: [String: String]?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionId: UUID,
        userId: String? = nil,
        deviceInfo: DeviceInfo? = nil,
        metadata: [String: AnyCodable]? = nil,
        metricName: String,
        value: Double,
        unit: String,
        tags: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.deviceInfo = deviceInfo ?? DeviceInfo()
        self.metadata = metadata
        self.metricName = metricName
        self.value = value
        self.unit = unit
        self.tags = tags
    }
}

/// Error telemetry event
public struct ErrorEvent: TelemetryEvent {
    public let id: UUID
    public let timestamp: Date
    public let eventType: TelemetryEventType = .error
    public let sessionId: UUID
    public let userId: String?
    public let deviceInfo: DeviceInfo
    public let metadata: [String: AnyCodable]?
    
    // Error specific fields
    public let errorType: String
    public let errorMessage: String
    public let stackTrace: String?
    public let severity: ErrorSeverity
    public let context: [String: String]?
    
    public enum ErrorSeverity: String, Codable, Sendable {
        case verbose = "verbose"
        case debug = "debug"
        case info = "info"
        case warning = "warning"
        case error = "error"
        case fatal = "fatal"
    }
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionId: UUID,
        userId: String? = nil,
        deviceInfo: DeviceInfo? = nil,
        metadata: [String: AnyCodable]? = nil,
        errorType: String,
        errorMessage: String,
        stackTrace: String? = nil,
        severity: ErrorSeverity,
        context: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.deviceInfo = deviceInfo ?? DeviceInfo()
        self.metadata = metadata
        self.errorType = errorType
        self.errorMessage = errorMessage
        self.stackTrace = stackTrace
        self.severity = severity
        self.context = context
    }
}

/// User action telemetry event
public struct UserActionEvent: TelemetryEvent {
    public let id: UUID
    public let timestamp: Date
    public let eventType: TelemetryEventType = .userAction
    public let sessionId: UUID
    public let userId: String?
    public let deviceInfo: DeviceInfo
    public let metadata: [String: AnyCodable]?
    
    // User action specific fields
    public let actionName: String
    public let category: String
    public let label: String?
    public let value: Double?
    public let screenName: String?
    public let properties: [String: AnyCodable]?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionId: UUID,
        userId: String? = nil,
        deviceInfo: DeviceInfo? = nil,
        metadata: [String: AnyCodable]? = nil,
        actionName: String,
        category: String,
        label: String? = nil,
        value: Double? = nil,
        screenName: String? = nil,
        properties: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.deviceInfo = deviceInfo ?? DeviceInfo()
        self.metadata = metadata
        self.actionName = actionName
        self.category = category
        self.label = label
        self.value = value
        self.screenName = screenName
        self.properties = properties
    }
}

/// SSH connection telemetry event
public struct SSHConnectionEvent: TelemetryEvent {
    public let id: UUID
    public let timestamp: Date
    public let eventType: TelemetryEventType = .sshConnection
    public let sessionId: UUID
    public let userId: String?
    public let deviceInfo: DeviceInfo
    public let metadata: [String: AnyCodable]?
    
    // SSH specific fields
    public let connectionId: UUID
    public let host: String
    public let port: Int
    public let status: ConnectionStatus
    public let duration: TimeInterval?
    public let bytesTransferred: Int64?
    public let errorReason: String?
    
    public enum ConnectionStatus: String, Codable, Sendable {
        case connecting = "connecting"
        case connected = "connected"
        case disconnected = "disconnected"
        case failed = "failed"
        case reconnecting = "reconnecting"
    }
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionId: UUID,
        userId: String? = nil,
        deviceInfo: DeviceInfo? = nil,
        metadata: [String: AnyCodable]? = nil,
        connectionId: UUID,
        host: String,
        port: Int,
        status: ConnectionStatus,
        duration: TimeInterval? = nil,
        bytesTransferred: Int64? = nil,
        errorReason: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.deviceInfo = deviceInfo ?? DeviceInfo()
        self.metadata = metadata
        self.connectionId = connectionId
        self.host = host
        self.port = port
        self.status = status
        self.duration = duration
        self.bytesTransferred = bytesTransferred
        self.errorReason = errorReason
    }
}

/// App lifecycle telemetry event
public struct AppLifecycleEvent: TelemetryEvent {
    public let id: UUID
    public let timestamp: Date
    public let eventType: TelemetryEventType = .appLifecycle
    public let sessionId: UUID
    public let userId: String?
    public let deviceInfo: DeviceInfo
    public let metadata: [String: AnyCodable]?
    
    // Lifecycle specific fields
    public let lifecycleEvent: LifecycleEventType
    public let previousState: String?
    public let currentState: String
    public let sessionDuration: TimeInterval?
    
    public enum LifecycleEventType: String, Codable, Sendable {
        case launch = "launch"
        case foreground = "foreground"
        case background = "background"
        case terminate = "terminate"
        case memoryWarning = "memory_warning"
        case crash = "crash"
    }
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionId: UUID,
        userId: String? = nil,
        deviceInfo: DeviceInfo? = nil,
        metadata: [String: AnyCodable]? = nil,
        lifecycleEvent: LifecycleEventType,
        previousState: String? = nil,
        currentState: String,
        sessionDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.deviceInfo = deviceInfo ?? DeviceInfo()
        self.metadata = metadata
        self.lifecycleEvent = lifecycleEvent
        self.previousState = previousState
        self.currentState = currentState
        self.sessionDuration = sessionDuration
    }
}

/// Generic custom telemetry event
public struct CustomEvent: TelemetryEvent {
    public let id: UUID
    public let timestamp: Date
    public let eventType: TelemetryEventType = .custom
    public let sessionId: UUID
    public let userId: String?
    public let deviceInfo: DeviceInfo
    public let metadata: [String: AnyCodable]?
    
    // Custom event fields
    public let name: String
    public let category: String?
    public let data: [String: AnyCodable]
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionId: UUID,
        userId: String? = nil,
        deviceInfo: DeviceInfo? = nil,
        metadata: [String: AnyCodable]? = nil,
        name: String,
        category: String? = nil,
        data: [String: AnyCodable]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.deviceInfo = deviceInfo ?? DeviceInfo()
        self.metadata = metadata
        self.name = name
        self.category = category
        self.data = data
    }
}

/// Helper type for encoding/decoding any Codable value
/* Commented out - using the definition from ChatModels.swift
public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encode(String(describing: value))
        }
    }
}
*/