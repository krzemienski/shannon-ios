//
//  WebSocketEventHandler.swift
//  ClaudeCode
//
//  Event parsing and routing for WebSocket messages
//

import Foundation
import Combine
import OSLog

/// Handles parsing and routing of WebSocket events
public class WebSocketEventHandler {
    // MARK: - Event Types
    
    public enum EventType: String, Codable {
        case projectUpdate = "project.update"
        case projectCreate = "project.create"
        case projectDelete = "project.delete"
        
        case chatUpdate = "chat.update"
        case chatMessage = "chat.message"
        case chatStreamStart = "chat.stream.start"
        case chatStreamData = "chat.stream.data"
        case chatStreamEnd = "chat.stream.end"
        
        case fileChange = "file.change"
        case fileCreate = "file.create"
        case fileUpdate = "file.update"
        case fileDelete = "file.delete"
        
        case terminalOutput = "terminal.output"
        case terminalCommand = "terminal.command"
        case terminalClear = "terminal.clear"
        
        case collaborationJoin = "collaboration.join"
        case collaborationLeave = "collaboration.leave"
        case collaborationCursor = "collaboration.cursor"
        case collaborationSelection = "collaboration.selection"
        
        case systemNotification = "system.notification"
        case systemError = "system.error"
        case systemWarning = "system.warning"
        
        case heartbeat = "heartbeat"
        case acknowledge = "ack"
    }
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "WebSocketEventHandler")
    
    // Event publishers
    private let projectUpdateSubject = PassthroughSubject<ProjectUpdateEvent, Never>()
    private let chatUpdateSubject = PassthroughSubject<ChatUpdateEvent, Never>()
    private let fileChangeSubject = PassthroughSubject<FileChangeEvent, Never>()
    private let terminalOutputSubject = PassthroughSubject<TerminalOutputEvent, Never>()
    private let collaborationSubject = PassthroughSubject<CollaborationEvent, Never>()
    private let systemNotificationSubject = PassthroughSubject<SystemNotificationEvent, Never>()
    
    // Public publishers
    public var projectUpdatePublisher: AnyPublisher<ProjectUpdateEvent, Never> {
        projectUpdateSubject.eraseToAnyPublisher()
    }
    
    public var chatUpdatePublisher: AnyPublisher<ChatUpdateEvent, Never> {
        chatUpdateSubject.eraseToAnyPublisher()
    }
    
    public var fileChangePublisher: AnyPublisher<FileChangeEvent, Never> {
        fileChangeSubject.eraseToAnyPublisher()
    }
    
    public var terminalOutputPublisher: AnyPublisher<TerminalOutputEvent, Never> {
        terminalOutputSubject.eraseToAnyPublisher()
    }
    
    public var collaborationPublisher: AnyPublisher<CollaborationEvent, Never> {
        collaborationSubject.eraseToAnyPublisher()
    }
    
    public var systemNotificationPublisher: AnyPublisher<SystemNotificationEvent, Never> {
        systemNotificationSubject.eraseToAnyPublisher()
    }
    
    // JSON decoder
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Handle incoming WebSocket message
    public func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            logger.error("Failed to convert message to data")
            return
        }
        
        do {
            // Try to decode base event structure
            let baseEvent = try decoder.decode(BaseWebSocketEvent.self, from: data)
            
            // Route to appropriate handler based on event type
            switch baseEvent.type {
            case .projectCreate, .projectUpdate, .projectDelete:
                handleProjectEvent(data: data, type: baseEvent.type)
                
            case .chatUpdate, .chatMessage, .chatStreamStart, .chatStreamData, .chatStreamEnd:
                handleChatEvent(data: data, type: baseEvent.type)
                
            case .fileCreate, .fileUpdate, .fileDelete, .fileChange:
                handleFileEvent(data: data, type: baseEvent.type)
                
            case .terminalOutput, .terminalCommand, .terminalClear:
                handleTerminalEvent(data: data, type: baseEvent.type)
                
            case .collaborationJoin, .collaborationLeave, .collaborationCursor, .collaborationSelection:
                handleCollaborationEvent(data: data, type: baseEvent.type)
                
            case .systemNotification, .systemError, .systemWarning:
                handleSystemEvent(data: data, type: baseEvent.type)
                
            case .heartbeat:
                logger.debug("Received heartbeat")
                
            case .acknowledge:
                logger.debug("Received acknowledgment")
            }
            
        } catch {
            logger.error("Failed to decode WebSocket event: \(error)")
            logger.debug("Raw message: \(text)")
        }
    }
    
    // MARK: - Private Event Handlers
    
    private func handleProjectEvent(data: Data, type: EventType) {
        do {
            let event = try decoder.decode(ProjectUpdateEvent.self, from: data)
            projectUpdateSubject.send(event)
            logger.debug("Handled project event: \(type.rawValue)")
        } catch {
            logger.error("Failed to decode project event: \(error)")
        }
    }
    
    private func handleChatEvent(data: Data, type: EventType) {
        do {
            let event = try decoder.decode(ChatUpdateEvent.self, from: data)
            chatUpdateSubject.send(event)
            logger.debug("Handled chat event: \(type.rawValue)")
        } catch {
            logger.error("Failed to decode chat event: \(error)")
        }
    }
    
    private func handleFileEvent(data: Data, type: EventType) {
        do {
            let event = try decoder.decode(FileChangeEvent.self, from: data)
            fileChangeSubject.send(event)
            logger.debug("Handled file event: \(type.rawValue)")
        } catch {
            logger.error("Failed to decode file event: \(error)")
        }
    }
    
    private func handleTerminalEvent(data: Data, type: EventType) {
        do {
            let event = try decoder.decode(TerminalOutputEvent.self, from: data)
            terminalOutputSubject.send(event)
            logger.debug("Handled terminal event: \(type.rawValue)")
        } catch {
            logger.error("Failed to decode terminal event: \(error)")
        }
    }
    
    private func handleCollaborationEvent(data: Data, type: EventType) {
        do {
            let event = try decoder.decode(CollaborationEvent.self, from: data)
            collaborationSubject.send(event)
            logger.debug("Handled collaboration event: \(type.rawValue)")
        } catch {
            logger.error("Failed to decode collaboration event: \(error)")
        }
    }
    
    private func handleSystemEvent(data: Data, type: EventType) {
        do {
            let event = try decoder.decode(SystemNotificationEvent.self, from: data)
            systemNotificationSubject.send(event)
            logger.debug("Handled system event: \(type.rawValue)")
        } catch {
            logger.error("Failed to decode system event: \(error)")
        }
    }
}

// MARK: - Event Models

/// Base WebSocket event structure
struct BaseWebSocketEvent: Codable {
    let type: WebSocketEventHandler.EventType
    let timestamp: Date
    let id: String?
}

/// Project update event
public struct ProjectUpdateEvent: Codable {
    public enum Action: String, Codable {
        case created
        case updated
        case deleted
    }
    
    public let type: WebSocketEventHandler.EventType
    public let timestamp: Date
    public let projectId: String
    public let action: Action
    public let data: ProjectData?
    
    public struct ProjectData: Codable {
        public let name: String?
        public let description: String?
        public let language: String?
        public let path: String?
        public let status: String?
    }
}

/// Chat update event
public struct ChatUpdateEvent: Codable {
    public enum Action: String, Codable {
        case messageAdded
        case messageUpdated
        case streamStarted
        case streamEnded
    }
    
    public let type: WebSocketEventHandler.EventType
    public let timestamp: Date
    public let chatId: String
    public let action: Action
    public let messageId: String?
    public let data: MessageData?
    
    public struct MessageData: Codable {
        public let content: String?
        public let role: String?
        public let isStreaming: Bool?
    }
}

/// File change event
public struct FileChangeEvent: Codable {
    public enum Action: String, Codable {
        case created
        case updated
        case deleted
        case renamed
    }
    
    public let type: WebSocketEventHandler.EventType
    public let timestamp: Date
    public let path: String
    public let action: Action
    public let oldPath: String?
    public let content: String?
}

/// Terminal output event
public struct TerminalOutputEvent: Codable {
    public enum OutputType: String, Codable {
        case stdout
        case stderr
        case command
    }
    
    public let type: WebSocketEventHandler.EventType
    public let timestamp: Date
    public let sessionId: String
    public let outputType: OutputType
    public let content: String
}

/// Collaboration event
public struct CollaborationEvent: Codable {
    public enum CollaborationType: String, Codable {
        case userJoined
        case userLeft
        case cursorUpdate
        case selectionUpdate
    }
    
    public let type: WebSocketEventHandler.EventType
    public let timestamp: Date
    public let userId: String
    public let username: String
    public let collaborationType: CollaborationType
    public let data: CollaborationData?
    
    public struct CollaborationData: Codable {
        public let cursor: CursorPosition?
        public let selection: SelectionRange?
        
        public struct CursorPosition: Codable {
            public let line: Int
            public let column: Int
            public let file: String?
        }
        
        public struct SelectionRange: Codable {
            public let start: CursorPosition
            public let end: CursorPosition
        }
    }
}

/// System notification event
public struct SystemNotificationEvent: Codable {
    public enum Severity: String, Codable {
        case info
        case warning
        case error
        case success
    }
    
    public let type: WebSocketEventHandler.EventType
    public let timestamp: Date
    public let severity: Severity
    public let title: String
    public let message: String
    public let action: String?
}