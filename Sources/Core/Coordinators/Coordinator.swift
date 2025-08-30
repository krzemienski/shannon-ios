//
//  Coordinator.swift
//  ClaudeCode
//
//  Base coordinator protocol for navigation management
//

import SwiftUI
import Combine

/// Base protocol for all coordinators
protocol Coordinator: AnyObject {
    /// Unique identifier for the coordinator
    var id: UUID { get }
    
    /// Parent coordinator (if any)
    var parent: Coordinator? { get set }
    
    /// Child coordinators
    var children: [Coordinator] { get set }
    
    /// Start the coordinator's flow
    func start()
    
    /// Clean up resources and remove from parent
    func finish()
}

extension Coordinator {
    /// Add a child coordinator
    func addChild(_ coordinator: Coordinator) {
        children.append(coordinator)
        coordinator.parent = self
    }
    
    /// Remove a child coordinator
    func removeChild(_ coordinator: Coordinator) {
        children.removeAll { $0.id == coordinator.id }
        coordinator.parent = nil
    }
    
    /// Remove all child coordinators
    func removeAllChildren() {
        children.forEach { $0.parent = nil }
        children.removeAll()
    }
    
    /// Default finish implementation
    func finish() {
        parent?.removeChild(self)
    }
}

/// Base implementation of Coordinator protocol
public class BaseCoordinator: Coordinator {
    let id = UUID()
    weak var parent: Coordinator?
    var children: [Coordinator] = []
    
    func start() {
        // Override in subclasses
    }
}

/// Navigation coordinator for managing navigation state
protocol NavigationCoordinatorProtocol: Coordinator {
    associatedtype Route: Hashable
    
    /// Current navigation path
    var navigationPath: [Route] { get set }
    
    /// Navigate to a specific route
    func navigate(to route: Route)
    
    /// Pop the current route
    func pop()
    
    /// Pop to root
    func popToRoot()
}

/// Tab coordinator for managing tab navigation
protocol TabCoordinator: Coordinator {
    associatedtype Tab: Hashable
    
    /// Currently selected tab
    var selectedTab: Tab { get set }
    
    /// Switch to a specific tab
    func selectTab(_ tab: Tab)
}

/// Modal coordinator for managing modal presentations
protocol ModalCoordinator: Coordinator {
    /// Present a modal view
    func presentModal<Content: View>(_ content: Content)
    
    /// Dismiss the current modal
    func dismissModal()
}

/// Alert coordinator for managing alerts
protocol AlertCoordinator: Coordinator {
    /// Show an alert
    func showAlert(title: String, message: String?, actions: [AlertAction])
    
    /// Dismiss the current alert
    func dismissAlert()
}

/// Alert action representation
struct AlertAction {
    let title: String
    let style: AlertActionStyle
    let handler: (() -> Void)?
    
    enum AlertActionStyle {
        case `default`
        case cancel
        case destructive
    }
}

/// Sheet coordinator for managing sheet presentations
protocol SheetCoordinator: Coordinator {
    /// Present a sheet
    func presentSheet<Content: View>(_ content: Content)
    
    /// Dismiss the current sheet
    func dismissSheet()
}

/// Full screen cover coordinator
protocol FullScreenCoverCoordinator: Coordinator {
    /// Present a full screen cover
    func presentFullScreenCover<Content: View>(_ content: Content)
    
    /// Dismiss the current full screen cover
    func dismissFullScreenCover()
}