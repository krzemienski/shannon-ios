//
//  ModuleRegistration.swift
//  ClaudeCode
//
//  Protocol for module registration
//

import Foundation

/// Protocol for dependency injection module registration
public protocol ModuleRegistration {
    /// Register module dependencies
    @MainActor
    func register()
}

/// Extension to provide default implementation
extension ModuleRegistration {
    /// Default empty registration
    @MainActor
    public func register() {}
}