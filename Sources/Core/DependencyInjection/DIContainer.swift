//
//  DIContainer.swift
//  ClaudeCode
//
//  Dependency Injection Container using Swinject
//

import Foundation
import Swinject

/// Thread-safe dependency injection container wrapper
public final class DIContainer: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let container: Container
    private let lock = NSLock()
    
    // MARK: - Singleton
    
    public static let shared = DIContainer()
    
    // MARK: - Initialization
    
    private init() {
        self.container = Container()
    }
    
    // MARK: - Registration
    
    /// Register a singleton service
    public func registerSingleton<Service>(
        _ serviceType: Service.Type,
        name: String? = nil,
        factory: @escaping () -> Service
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        container.register(serviceType, name: name) { _ in
            factory()
        }.inObjectScope(.container)
    }
    
    /// Register a singleton service with resolver
    public func registerSingleton<Service>(
        _ serviceType: Service.Type,
        name: String? = nil,
        factory: @escaping (Resolver) -> Service
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        container.register(serviceType, name: name, factory: factory)
            .inObjectScope(.container)
    }
    
    /// Register a transient service
    public func register<Service>(
        _ serviceType: Service.Type,
        name: String? = nil,
        factory: @escaping () -> Service
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        container.register(serviceType, name: name) { _ in
            factory()
        }.inObjectScope(.transient)
    }
    
    /// Register a transient service with resolver
    public func register<Service>(
        _ serviceType: Service.Type,
        name: String? = nil,
        factory: @escaping (Resolver) -> Service
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        container.register(serviceType, name: name, factory: factory)
            .inObjectScope(.transient)
    }
    
    // MARK: - Resolution
    
    /// Resolve a service
    public func resolve<Service>(_ serviceType: Service.Type, name: String? = nil) -> Service {
        lock.lock()
        defer { lock.unlock() }
        
        guard let service = container.resolve(serviceType, name: name) else {
            fatalError("Failed to resolve \(serviceType)")
        }
        return service
    }
    
    /// Safely resolve a service
    public func safeResolve<Service>(_ serviceType: Service.Type, name: String? = nil) -> Service? {
        lock.lock()
        defer { lock.unlock() }
        
        return container.resolve(serviceType, name: name)
    }
    
    // MARK: - Management
    
    /// Reset the container (remove all registrations)
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        container.removeAll()
    }
    
    /// Clear instances but keep registrations
    public func clearInstances() {
        lock.lock()
        defer { lock.unlock() }
        
        container.resetObjectScope(.container)
    }
}

// MARK: - Convenience Extensions

extension DIContainer {
    
    /// Register a singleton with dependencies
    public func registerSingleton<Service, Dep1>(
        _ serviceType: Service.Type,
        dependencies: Dep1.Type,
        factory: @escaping (Dep1) -> Service
    ) {
        registerSingleton(serviceType) { resolver in
            let dep1 = resolver.resolve(Dep1.self)!
            return factory(dep1)
        }
    }
    
    /// Register a singleton with two dependencies
    public func registerSingleton<Service, Dep1, Dep2>(
        _ serviceType: Service.Type,
        dependencies: (Dep1.Type, Dep2.Type),
        factory: @escaping (Dep1, Dep2) -> Service
    ) {
        registerSingleton(serviceType) { resolver in
            let dep1 = resolver.resolve(Dep1.self)!
            let dep2 = resolver.resolve(Dep2.self)!
            return factory(dep1, dep2)
        }
    }
    
    /// Register a singleton with three dependencies
    public func registerSingleton<Service, Dep1, Dep2, Dep3>(
        _ serviceType: Service.Type,
        dependencies: (Dep1.Type, Dep2.Type, Dep3.Type),
        factory: @escaping (Dep1, Dep2, Dep3) -> Service
    ) {
        registerSingleton(serviceType) { resolver in
            let dep1 = resolver.resolve(Dep1.self)!
            let dep2 = resolver.resolve(Dep2.self)!
            let dep3 = resolver.resolve(Dep3.self)!
            return factory(dep1, dep2, dep3)
        }
    }
}