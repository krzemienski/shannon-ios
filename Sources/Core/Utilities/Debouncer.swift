//
//  Debouncer.swift
//  ClaudeCode
//
//  Utility for debouncing rapid function calls to improve performance
//

import Foundation
import Combine

/// A utility class for debouncing rapid function calls
/// Helps prevent excessive API calls and improves performance
@MainActor
final class Debouncer {
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    private let delay: TimeInterval
    
    /// Initialize a new debouncer
    /// - Parameters:
    ///   - delay: The delay in seconds before executing the action
    ///   - queue: The queue to execute the action on (default: main)
    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }
    
    /// Debounce a function call
    /// - Parameter action: The action to execute after the delay
    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        
        let newWorkItem = DispatchWorkItem { [weak self] in
            action()
        }
        
        workItem = newWorkItem
        queue.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }
    
    /// Cancel any pending debounced action
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
    
    deinit {
        cancel()
    }
}

/// Publisher-based debouncer for Combine integration
extension Publisher where Failure == Never {
    /// Debounce publisher events
    /// - Parameters:
    ///   - duration: The duration to wait before publishing
    ///   - scheduler: The scheduler to use for timing
    /// - Returns: A publisher that delays events
    func debounce<S: Scheduler>(
        for duration: S.SchedulerTimeType.Stride,
        scheduler: S
    ) -> AnyPublisher<Output, Never> {
        self.debounce(for: duration, scheduler: scheduler)
            .eraseToAnyPublisher()
    }
}

/// Throttle utility for rate limiting
@MainActor
final class Throttler {
    private var workItem: DispatchWorkItem?
    private var lastRun: Date?
    private let queue: DispatchQueue
    private let minimumDelay: TimeInterval
    
    init(minimumDelay: TimeInterval, queue: DispatchQueue = .main) {
        self.minimumDelay = minimumDelay
        self.queue = queue
    }
    
    func throttle(action: @escaping () -> Void) {
        workItem?.cancel()
        
        let now = Date()
        let timeElapsed = lastRun.map { now.timeIntervalSince($0) } ?? minimumDelay
        
        if timeElapsed >= minimumDelay {
            lastRun = now
            action()
        } else {
            let remainingDelay = minimumDelay - timeElapsed
            let newWorkItem = DispatchWorkItem { [weak self] in
                self?.lastRun = Date()
                action()
            }
            
            workItem = newWorkItem
            queue.asyncAfter(deadline: .now() + remainingDelay, execute: newWorkItem)
        }
    }
    
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
    
    deinit {
        cancel()
    }
}