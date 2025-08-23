//
//  ServiceContainer.swift
//  ClaudeCode
//
//  Protocol for service container modules
//

import Foundation

/// Protocol for service container modules that can register dependencies
protocol ServiceContainer {
    /// Register services in the container
    func register()
}