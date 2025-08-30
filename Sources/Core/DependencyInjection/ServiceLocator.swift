//
//  ServiceLocator.swift
//  ClaudeCode
//
//  Service Locator pattern implementation
//

import Foundation

/// Service lifetime scope
public enum ServiceLifetime {
    case singleton
    case transient
}

/// Service factory closure
public typealias ServiceFactory = () -> Any

/// Service registration entry
private struct ServiceEntry {
    let lifetime: ServiceLifetime
    let factory: ServiceFactory
    var instance: Any?
}

/// Thread-safe service locator
public final class ServiceLocator: @unchecked Sendable {
    
    // MARK: - Properties
    
    private var services: [ObjectIdentifier: ServiceEntry] = [:]
    private let lock = NSLock()
    
    // MARK: - Singleton
    
    public static let shared = ServiceLocator()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Registration
    
    /// Register a service with a specific lifetime
    public func register<Service>(
        _ serviceType: Service.Type,
        lifetime: ServiceLifetime = .singleton,
        factory: @escaping () -> Service
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ObjectIdentifier(serviceType)
        services[key] = ServiceEntry(
            lifetime: lifetime,
            factory: factory,
            instance: nil
        )
    }
    
    /// Register multiple modules
    public func register(modules: [Any]) {
        // This is a compatibility method for existing code
        // Modules should implement their own registration
    }
    
    // MARK: - Resolution
    
    /// Resolve a service
    public func resolve<Service>(_ serviceType: Service.Type) -> Service {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ObjectIdentifier(serviceType)
        
        guard var entry = services[key] else {
            fatalError("Service \(serviceType) not registered")
        }
        
        switch entry.lifetime {
        case .singleton:
            if let instance = entry.instance as? Service {
                return instance
            }
            let newInstance = entry.factory()
            entry.instance = newInstance
            services[key] = entry
            return newInstance as! Service
            
        case .transient:
            return entry.factory() as! Service
        }
    }
    
    /// Safely resolve a service
    public func safeResolve<Service>(_ serviceType: Service.Type) -> Service? {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ObjectIdentifier(serviceType)
        
        guard var entry = services[key] else {
            return nil
        }
        
        switch entry.lifetime {
        case .singleton:
            if let instance = entry.instance as? Service {
                return instance
            }
            guard let newInstance = entry.factory() as? Service else {
                return nil
            }
            entry.instance = newInstance
            services[key] = entry
            return newInstance
            
        case .transient:
            return entry.factory() as? Service
        }
    }
    
    // MARK: - Management
    
    /// Reset all registrations
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        services.removeAll()
    }
    
    /// Clear singleton instances
    public func clearSingletons() {
        lock.lock()
        defer { lock.unlock() }
        
        for key in services.keys {
            services[key]?.instance = nil
        }
    }
}

// MARK: - Convenience Extensions

extension ServiceLocator {
    
    /// Check if a service is registered
    public func isRegistered<Service>(_ serviceType: Service.Type) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let key = ObjectIdentifier(serviceType)
        return services[key] != nil
    }
    
    /// Get all registered service types
    public var registeredTypes: [String] {
        lock.lock()
        defer { lock.unlock() }
        
        return services.keys.map { String(describing: $0) }
    }
}