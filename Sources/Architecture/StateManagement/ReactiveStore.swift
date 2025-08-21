//
//  ReactiveStore.swift
//  ClaudeCode
//
//  Reactive store implementation with Combine
//

import SwiftUI
import Combine

/// Base reactive store with automatic state management
@MainActor
class ReactiveStore<State: Equatable, Action>: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var state: State
    
    // MARK: - Private Properties
    
    private let reducer: (State, Action) -> State
    private let stateManager: StateManager<State>
    private var middlewares: [(State, Action) -> Void] = []
    private var effects: [(State, Action) -> AnyPublisher<Action, Never>?] = []
    private var cancellables = Set<AnyCancellable>()
    private let actionSubject = PassthroughSubject<Action, Never>()
    
    // MARK: - Initialization
    
    init(
        initialState: State,
        reducer: @escaping (State, Action) -> State,
        enableHistory: Bool = true
    ) {
        self.state = initialState
        self.reducer = reducer
        self.stateManager = StateManager(
            initialState: initialState,
            maxHistorySize: enableHistory ? 50 : 0
        )
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind state manager to published state
        stateManager.$currentState
            .assign(to: &$state)
        
        // Process actions
        actionSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in
                self?.processAction(action)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Action Dispatch
    
    func dispatch(_ action: Action) {
        actionSubject.send(action)
    }
    
    private func processAction(_ action: Action) {
        // Run pre-middlewares
        middlewares.forEach { middleware in
            middleware(state, action)
        }
        
        // Apply reducer
        let newState = reducer(state, action)
        
        // Update state
        stateManager.setState(newState)
        
        // Run effects
        effects.forEach { effect in
            if let publisher = effect(newState, action) {
                publisher
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] effectAction in
                        self?.dispatch(effectAction)
                    }
                    .store(in: &cancellables)
            }
        }
    }
    
    // MARK: - Middleware
    
    func addMiddleware(_ middleware: @escaping (State, Action) -> Void) {
        middlewares.append(middleware)
    }
    
    // MARK: - Effects
    
    func addEffect(_ effect: @escaping (State, Action) -> AnyPublisher<Action, Never>?) {
        effects.append(effect)
    }
    
    // MARK: - History
    
    func undo() {
        stateManager.undo()
    }
    
    func redo() {
        stateManager.redo()
    }
    
    func clearHistory() {
        stateManager.clearHistory()
    }
    
    var canUndo: Bool {
        stateManager.canUndo
    }
    
    var canRedo: Bool {
        stateManager.canRedo
    }
    
    // MARK: - Subscriptions
    
    func subscribe(to keyPath: KeyPath<State, some Equatable>) -> AnyPublisher<State, Never> {
        $state
            .removeDuplicates { old, new in
                old[keyPath: keyPath] == new[keyPath: keyPath]
            }
            .eraseToAnyPublisher()
    }
    
    func select<T: Equatable>(_ selector: @escaping (State) -> T) -> AnyPublisher<T, Never> {
        $state
            .map(selector)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

/// Async effect support
extension ReactiveStore {
    func addAsyncEffect(_ effect: @escaping (State, Action) async -> Action?) {
        addEffect { state, action in
            Future<Action, Never> { promise in
                Task {
                    if let resultAction = await effect(state, action) {
                        promise(.success(resultAction))
                    }
                }
            }
            .eraseToAnyPublisher()
        }
    }
}

/// Combine operators for state selection
extension Publisher where Output: Equatable, Failure == Never {
    func distinct() -> AnyPublisher<Output, Never> {
        self.removeDuplicates().eraseToAnyPublisher()
    }
}

/// Property wrapper for derived state
@propertyWrapper
struct Derived<State, Value: Equatable> {
    private let store: ReactiveStore<State, Any>
    private let selector: (State) -> Value
    private var cancellable: AnyCancellable?
    @Published private var value: Value
    
    init(
        from store: ReactiveStore<State, Any>,
        select selector: @escaping (State) -> Value
    ) {
        self.store = store
        self.selector = selector
        self.value = selector(store.state)
        
        // Subscribe to changes
        self.cancellable = store.select(selector)
            .assign(to: \.value, on: self)
    }
    
    var wrappedValue: Value {
        get { value }
    }
    
    var projectedValue: Published<Value>.Publisher {
        $value
    }
}