//
//  StateManager.swift
//  ClaudeCode
//
//  Centralized state management with reactive patterns
//

import SwiftUI
import Combine

/// Protocol for state change events
protocol StateEvent {
    var timestamp: Date { get }
    var source: String { get }
}

/// Protocol for state stores
protocol StateStore: ObservableObject {
    associatedtype State
    
    var state: State { get }
    func dispatch(_ action: StateAction)
    func subscribe<S: Subscriber>(subscriber: S) where S.Input == State, S.Failure == Never
}

/// Base class for state actions
protocol StateAction {
    var type: String { get }
}

/// Generic state manager with undo/redo support
@MainActor
class StateManager<State: Equatable>: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var currentState: State
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var isProcessing = false
    
    // MARK: - Private Properties
    
    private var undoStack: [State] = []
    private var redoStack: [State] = []
    private let maxHistorySize: Int
    private var middlewares: [StateMiddleware<State>] = []
    private var subscribers = Set<AnyCancellable>()
    private let stateSubject: CurrentValueSubject<State, Never>
    
    // MARK: - Initialization
    
    init(initialState: State, maxHistorySize: Int = 50) {
        self.currentState = initialState
        self.maxHistorySize = maxHistorySize
        self.stateSubject = CurrentValueSubject(initialState)
    }
    
    // MARK: - State Management
    
    func setState(_ newState: State, recordHistory: Bool = true) {
        guard newState != currentState else { return }
        
        if recordHistory {
            // Add current state to undo stack
            undoStack.append(currentState)
            if undoStack.count > maxHistorySize {
                undoStack.removeFirst()
            }
            
            // Clear redo stack when new action is performed
            redoStack.removeAll()
        }
        
        // Apply middlewares
        var processedState = newState
        for middleware in middlewares {
            processedState = middleware.process(state: processedState, previousState: currentState)
        }
        
        // Update state
        currentState = processedState
        stateSubject.send(processedState)
        
        // Update undo/redo availability
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    func undo() {
        guard canUndo, let previousState = undoStack.popLast() else { return }
        
        // Save current state to redo stack
        redoStack.append(currentState)
        
        // Restore previous state
        setState(previousState, recordHistory: false)
    }
    
    func redo() {
        guard canRedo, let nextState = redoStack.popLast() else { return }
        
        // Save current state to undo stack
        undoStack.append(currentState)
        
        // Restore next state
        setState(nextState, recordHistory: false)
    }
    
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        canUndo = false
        canRedo = false
    }
    
    // MARK: - Middleware
    
    func addMiddleware(_ middleware: StateMiddleware<State>) {
        middlewares.append(middleware)
    }
    
    func removeAllMiddlewares() {
        middlewares.removeAll()
    }
    
    // MARK: - Subscription
    
    func subscribe(_ handler: @escaping (State) -> Void) -> AnyCancellable {
        stateSubject
            .receive(on: DispatchQueue.main)
            .sink { state in
                handler(state)
            }
    }
    
    func publisher() -> AnyPublisher<State, Never> {
        stateSubject.eraseToAnyPublisher()
    }
}

/// Middleware protocol for state processing
protocol StateMiddleware<State> {
    associatedtype State
    func process(state: State, previousState: State) -> State
}

/// Logging middleware
struct LoggingMiddleware<State>: StateMiddleware {
    let logger: (State, State) -> Void
    
    func process(state: State, previousState: State) -> State {
        logger(state, previousState)
        return state
    }
}

/// Validation middleware
struct ValidationMiddleware<State>: StateMiddleware {
    let validator: (State) -> State
    
    func process(state: State, previousState: State) -> State {
        validator(state)
    }
}

/// Persistence middleware
struct PersistenceMiddleware<State: Codable>: StateMiddleware {
    let key: String
    let userDefaults: UserDefaults
    
    init(key: String, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.userDefaults = userDefaults
    }
    
    func process(state: State, previousState: State) -> State {
        // Save state to UserDefaults
        if let encoded = try? JSONEncoder().encode(state) {
            userDefaults.set(encoded, forKey: key)
        }
        return state
    }
    
    func loadState() -> State? {
        guard let data = userDefaults.data(forKey: key),
              let state = try? JSONDecoder().decode(State.self, from: data) else {
            return nil
        }
        return state
    }
}

/// Performance monitoring middleware
struct PerformanceMiddleware<State>: StateMiddleware {
    let threshold: TimeInterval
    let onSlowUpdate: (TimeInterval) -> Void
    
    func process(state: State, previousState: State) -> State {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            if elapsed > threshold {
                onSlowUpdate(elapsed)
            }
        }
        return state
    }
}