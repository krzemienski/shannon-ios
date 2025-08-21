//
//  ServiceLocator.swift
//  ClaudeCode
//
//  Service locator pattern for dependency resolution
//

import Foundation
import Combine

/// Protocol for services that can be registered
protocol Service: AnyObject {
    static var identifier: String { get }
}

extension Service {
    static var identifier: String {
        String(describing: self)
    }
}

/// Service lifetime scope
enum ServiceLifetime {
    case singleton
    case transient
    case scoped
}

/// Service registration
struct ServiceRegistration {
    let type: Any.Type
    let lifetime: ServiceLifetime
    let factory: () -> Any
    let identifier: String
}

/// Service locator for dependency resolution
@MainActor
final class ServiceLocator {
    
    // MARK: - Singleton
    
    static let shared = ServiceLocator()
    
    // MARK: - Properties
    
    private var registrations: [String: ServiceRegistration] = [:]
    private var singletons: [String: Any] = [:]
    private var scopedInstances: [String: [String: Any]] = [:]
    private var currentScope: String?
    
    // MARK: - Registration
    
    func register<T>(
        _ type: T.Type,
        lifetime: ServiceLifetime = .singleton,
        factory: @escaping () -> T
    ) {
        let identifier = String(describing: type)
        let registration = ServiceRegistration(
            type: type,
            lifetime: lifetime,
            factory: factory,
            identifier: identifier
        )
        registrations[identifier] = registration
    }
    
    func register<T: Service>(
        _ type: T.Type,
        lifetime: ServiceLifetime = .singleton,
        factory: @escaping () -> T
    ) {
        let identifier = type.identifier
        let registration = ServiceRegistration(
            type: type,
            lifetime: lifetime,
            factory: factory,
            identifier: identifier
        )
        registrations[identifier] = registration
    }
    
    func register<T>(
        _ instance: T,
        as type: T.Type
    ) {
        let identifier = String(describing: type)
        singletons[identifier] = instance
    }
    
    // MARK: - Resolution
    
    func resolve<T>(_ type: T.Type) -> T {
        let identifier = String(describing: type)
        
        // Check if we have a singleton instance
        if let singleton = singletons[identifier] as? T {
            return singleton
        }
        
        // Check if we have a registration
        guard let registration = registrations[identifier] else {
            fatalError("No registration found for type \(type)")
        }
        
        switch registration.lifetime {
        case .singleton:
            if let existing = singletons[identifier] as? T {
                return existing
            }
            let instance = registration.factory() as! T
            singletons[identifier] = instance
            return instance
            
        case .transient:
            return registration.factory() as! T
            
        case .scoped:
            guard let scope = currentScope else {
                fatalError("No scope active for scoped service \(type)")
            }
            
            if let existing = scopedInstances[scope]?[identifier] as? T {
                return existing
            }
            
            let instance = registration.factory() as! T
            if scopedInstances[scope] == nil {
                scopedInstances[scope] = [:]
            }
            scopedInstances[scope]?[identifier] = instance
            return instance
        }
    }
    
    func resolve<T: Service>(_ type: T.Type) -> T {
        let identifier = type.identifier
        
        // Check if we have a singleton instance
        if let singleton = singletons[identifier] as? T {
            return singleton
        }
        
        // Check if we have a registration
        guard let registration = registrations[identifier] else {
            fatalError("No registration found for type \(type)")
        }
        
        switch registration.lifetime {
        case .singleton:
            if let existing = singletons[identifier] as? T {
                return existing
            }
            let instance = registration.factory() as! T
            singletons[identifier] = instance
            return instance
            
        case .transient:
            return registration.factory() as! T
            
        case .scoped:
            guard let scope = currentScope else {
                fatalError("No scope active for scoped service \(type)")
            }
            
            if let existing = scopedInstances[scope]?[identifier] as? T {
                return existing
            }
            
            let instance = registration.factory() as! T
            if scopedInstances[scope] == nil {
                scopedInstances[scope] = [:]
            }
            scopedInstances[scope]?[identifier] = instance
            return instance
        }
    }
    
    // MARK: - Scope Management
    
    func beginScope(_ identifier: String) {
        currentScope = identifier
        if scopedInstances[identifier] == nil {
            scopedInstances[identifier] = [:]
        }
    }
    
    func endScope(_ identifier: String) {
        scopedInstances.removeValue(forKey: identifier)
        if currentScope == identifier {
            currentScope = nil
        }
    }
    
    // MARK: - Cleanup
    
    func reset() {
        registrations.removeAll()
        singletons.removeAll()
        scopedInstances.removeAll()
        currentScope = nil
    }
    
    func clearSingletons() {
        singletons.removeAll()
    }
    
    func clearScoped() {
        scopedInstances.removeAll()
        currentScope = nil
    }
}

// MARK: - Property Wrapper

@propertyWrapper
struct Injected<T> {
    private let service: T
    
    init() {
        self.service = ServiceLocator.shared.resolve(T.self)
    }
    
    init(_ type: T.Type) {
        self.service = ServiceLocator.shared.resolve(type)
    }
    
    var wrappedValue: T {
        service
    }
}

@propertyWrapper
struct LazyInjected<T> {
    private var service: T?
    private let type: T.Type
    
    init(_ type: T.Type) {
        self.type = type
    }
    
    var wrappedValue: T {
        mutating get {
            if service == nil {
                service = ServiceLocator.shared.resolve(type)
            }
            return service!
        }
    }
}

// MARK: - Service Container Protocol

protocol ServiceContainer {
    func register()
}

// MARK: - Module Registration

struct ServiceModule: ServiceContainer {
    let registrations: () -> Void
    
    func register() {
        registrations()
    }
}

extension ServiceLocator {
    func register(modules: [ServiceContainer]) {
        modules.forEach { $0.register() }
    }
}