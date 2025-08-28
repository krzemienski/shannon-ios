//
//  UsageModels.swift
//  ClaudeCode
//
//  Usage statistics and tracking models
//

import Foundation

/// Usage statistics
public struct UsageStats: Codable {
    public let totalTokens: Int
    public let totalCost: Double
    public let sessionsCount: Int
    public let averageTokensPerSession: Double
    public let periodStart: Date?
    public let periodEnd: Date?
    
    public init(
        totalTokens: Int = 0,
        totalCost: Double = 0.0,
        sessionsCount: Int = 0,
        averageTokensPerSession: Double = 0.0,
        periodStart: Date? = nil,
        periodEnd: Date? = nil
    ) {
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.sessionsCount = sessionsCount
        self.averageTokensPerSession = averageTokensPerSession
        self.periodStart = periodStart
        self.periodEnd = periodEnd
    }
    
    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
        case totalCost = "total_cost"
        case sessionsCount = "sessions_count"
        case averageTokensPerSession = "average_tokens_per_session"
        case periodStart = "period_start"
        case periodEnd = "period_end"
    }
}

/// Usage tracking request
public struct UsageTrackingRequest: Codable {
    public let sessionId: String
    public let usage: APIUsage
    
    public init(sessionId: String, usage: APIUsage) {
        self.sessionId = sessionId
        self.usage = usage
    }
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case usage
    }
}