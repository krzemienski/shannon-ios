//
//  DIContainer.swift
//  ClaudeCode
//
//  Enhanced dependency injection container with scoping and lifecycle management
//

import SwiftUI
import Combine

/// Protocol for injectable dependencies
protocol Injectable {
    associatedtype Dependencies
    init(dependencies: Dependencies)
}

/// Dependency injection container with advanced features
@MainActor
final class DIContainer {
    
    // MARK: - Types
    
    typealias Factory<T> = () -> T
    typealias AsyncFactory<T> = () async -> T
    
    // MARK: - Singleton
    
    static let shared = DIContainer()
    
    // MARK: - Properties
    
    private var factories: [String: Any] = [:]
    private var singletons: [String: Any] = [:]
    private var weakSingletons: NSMapTable<NSString, AnyObject> = .strongToWeakObjects()
    private var scopedInstances: [String: [String: Any]] = [:]
    private var currentScope: String?
    private let queue = DispatchQueue(label: "com.claudecode.di", attributes: .concurrent)
    
    // MARK: - Registration
    
    /// Register a factory for creating instances
    func register<T>(
        _ type: T.Type,
        name: String? = nil,
        factory: @escaping Factory<T>
    ) {
        let key = makeKey(for: type, name: name)
        queue.async(flags: .barrier) {
            self.factories[key] = factory
        }
    }
    
    /// Register an async factory
    func registerAsync<T>(
        _ type: T.Type,
        name: String? = nil,
        factory: @escaping AsyncFactory<T>
    ) {
        let key = makeKey(for: type, name: name)
        queue.async(flags: .barrier) {
            self.factories[key] = factory
        }
    }
    
    /// Register a singleton instance
    func registerSingleton<T>(
        _ type: T.Type,
        name: String? = nil,
        factory: @escaping Factory<T>
    ) {
        let key = makeKey(for: type, name: name)
        let instance = factory()
        queue.async(flags: .barrier) {
            self.singletons[key] = instance
        }
    }
    
    /// Register a weak singleton
    func registerWeakSingleton<T: AnyObject>(
        _ type: T.Type,
        name: String? = nil,
        factory: @escaping Factory<T>
    ) {
        let key = makeKey(for: type, name: name)
        let instance = factory()
        queue.async(flags: .barrier) {
            self.weakSingletons.setObject(instance, forKey: key as NSString)
        }
    }
    
    /// Register a scoped factory
    func registerScoped<T>(
        _ type: T.Type,
        name: String? = nil,
        factory: @escaping Factory<T>
    ) {
        let key = makeKey(for: type, name: name)
        queue.async(flags: .barrier) {
            self.factories[key] = factory
        }
    }
    
    // MARK: - Resolution
    
    /// Resolve a dependency
    func resolve<T>(
        _ type: T.Type,
        name: String? = nil
    ) -> T {
        let key = makeKey(for: type, name: name)
        
        return queue.sync {
            // Check singletons
            if let singleton = singletons[key] as? T {
                return singleton
            }
            
            // Check weak singletons
            if let weakSingleton = weakSingletons.object(forKey: key as NSString) as? T {
                return weakSingleton
            }
            
            // Check scoped instances
            if let scope = currentScope,
               let scopedInstance = scopedInstances[scope]?[key] as? T {
                return scopedInstance
            }
            
            // Create new instance from factory
            guard let factory = factories[key] else {
                fatalError("No registration found for \(type) with name: \(name ?? "default")")
            }
            
            if let syncFactory = factory as? Factory<T> {
                let instance = syncFactory()
                
                // Store in scope if active
                if let scope = currentScope {
                    queue.async(flags: .barrier) {
                        if self.scopedInstances[scope] == nil {
                            self.scopedInstances[scope] = [:]
                        }
                        self.scopedInstances[scope]?[key] = instance
                    }
                }
                
                return instance
            }
            
            fatalError("Factory type mismatch for \(type)")
        }
    }
    
    /// Resolve an async dependency
    func resolveAsync<T>(
        _ type: T.Type,
        name: String? = nil
    ) async -> T {
        let key = makeKey(for: type, name: name)
        
        // Check existing instances
        if let existing = queue.sync(execute: { 
            singletons[key] as? T ?? 
            weakSingletons.object(forKey: key as NSString) as? T ??
            (currentScope.flatMap { scopedInstances[$0]?[key] as? T })
        }) {
            return existing
        }
        
        // Create from async factory
        guard let factory = queue.sync(execute: { factories[key] }) else {
            fatalError("No registration found for \(type) with name: \(name ?? "default")")
        }
        
        if let asyncFactory = factory as? AsyncFactory<T> {
            let instance = await asyncFactory()
            
            // Store in scope if active
            if let scope = currentScope {
                queue.async(flags: .barrier) {
                    if self.scopedInstances[scope] == nil {
                        self.scopedInstances[scope] = [:]
                    }
                    self.scopedInstances[scope]?[key] = instance
                }
            }
            
            return instance
        }
        
        // Fall back to sync factory
        if let syncFactory = factory as? Factory<T> {
            return syncFactory()
        }
        
        fatalError("Factory type mismatch for \(type)")
    }
    
    /// Resolve with automatic injection
    func resolveWithInjection<T: Injectable>(
        _ type: T.Type,
        name: String? = nil
    ) -> T {
        let dependencies = resolve(T.Dependencies.self, name: name)
        return T(dependencies: dependencies)
    }
    
    // MARK: - Scope Management
    
    /// Begin a new scope
    func beginScope(_ identifier: String) {
        queue.async(flags: .barrier) {
            self.currentScope = identifier
            if self.scopedInstances[identifier] == nil {
                self.scopedInstances[identifier] = [:]
            }
        }
    }
    
    /// End a scope
    func endScope(_ identifier: String) {
        queue.async(flags: .barrier) {
            self.scopedInstances.removeValue(forKey: identifier)
            if self.currentScope == identifier {
                self.currentScope = nil
            }
        }
    }
    
    // MARK: - Utilities
    
    private func makeKey(for type: Any.Type, name: String?) -> String {
        let typeName = String(describing: type)
        if let name = name {
            return "\(typeName)_\(name)"
        }
        return typeName
    }
    
    /// Clear all registrations and instances
    func reset() {
        queue.async(flags: .barrier) {
            self.factories.removeAll()
            self.singletons.removeAll()
            self.weakSingletons.removeAllObjects()
            self.scopedInstances.removeAll()
            self.currentScope = nil
        }
    }
    
    /// Clear only instances, keep registrations
    func clearInstances() {
        queue.async(flags: .barrier) {
            self.singletons.removeAll()
            self.weakSingletons.removeAllObjects()
            self.scopedInstances.removeAll()
        }
    }
}

// MARK: - Property Wrappers

@propertyWrapper
struct Inject<T> {
    private let name: String?
    private let container: DIContainer
    
    init(name: String? = nil, container: DIContainer = .shared) {
        self.name = name
        self.container = container
    }
    
    var wrappedValue: T {
        container.resolve(T.self, name: name)
    }
}

@propertyWrapper
struct InjectAsync<T> {
    private let name: String?
    private let container: DIContainer
    
    init(name: String? = nil, container: DIContainer = .shared) {
        self.name = name
        self.container = container
    }
    
    var wrappedValue: T {
        get async {
            await container.resolveAsync(T.self, name: name)
        }
    }
}

// MARK: - SwiftUI Environment

private struct DIContainerKey: EnvironmentKey {
    static let defaultValue = DIContainer.shared
}

extension EnvironmentValues {
    var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}

extension View {
    func diContainer(_ container: DIContainer) -> some View {
        environment(\.diContainer, container)
    }
}