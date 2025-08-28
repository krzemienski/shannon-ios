//
//  RelativeDateFormatter.swift
//  ClaudeCode
//
//  Utility for formatting dates in relative terms
//

import Foundation

/// A custom formatter for displaying dates in relative terms (e.g., "5 minutes ago", "Yesterday")
public class RelativeDateFormatter {
    // MARK: - Shared Instance
    
    public static let shared = RelativeDateFormatter()
    
    // MARK: - Properties
    
    private let formatter: RelativeDateTimeFormatter
    
    // MARK: - Initialization
    
    public init() {
        self.formatter = RelativeDateTimeFormatter()
        self.formatter.unitsStyle = .abbreviated
        self.formatter.dateTimeStyle = .numeric
    }
    
    // MARK: - Public Methods
    
    /// Format a date into a relative string
    /// - Parameter date: The date to format
    /// - Returns: A string representing the relative time (e.g., "5 min ago")
    public func string(for date: Date) -> String? {
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Format a date into a relative string with a custom reference date
    /// - Parameters:
    ///   - date: The date to format
    ///   - referenceDate: The date to compare against
    /// - Returns: A string representing the relative time
    public func string(for date: Date, relativeTo referenceDate: Date) -> String? {
        return formatter.localizedString(for: date, relativeTo: referenceDate)
    }
    
    /// Format a time interval into a relative string
    /// - Parameter timeInterval: The time interval in seconds
    /// - Returns: A string representing the relative time
    public func string(from timeInterval: TimeInterval) -> String? {
        let date = Date(timeIntervalSinceNow: -timeInterval)
        return string(for: date)
    }
}

// MARK: - Convenience Extensions

public extension Date {
    /// Get a relative time string for this date
    var relativeTimeString: String {
        RelativeDateFormatter.shared.string(for: self) ?? ""
    }
    
    /// Get a short relative time string (e.g., "5m", "2h", "3d")
    var shortRelativeTimeString: String {
        let interval = Date().timeIntervalSince(self)
        
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else if interval < 604800 {
            return "\(Int(interval / 86400))d"
        } else if interval < 2592000 {
            return "\(Int(interval / 604800))w"
        } else if interval < 31536000 {
            return "\(Int(interval / 2592000))mo"
        } else {
            return "\(Int(interval / 31536000))y"
        }
    }
}

// MARK: - RelativeDateTimeFormatter Extension

extension RelativeDateTimeFormatter {
    /// Thread-safe shared instance for use in SwiftUI views
    @MainActor
    nonisolated(unsafe) public static let shared: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .numeric
        return formatter
    }()
}