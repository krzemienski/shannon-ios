//
//  AnalyticsComponents.swift
//  ClaudeCode
//
//  Supporting components for user analytics
//

import Foundation
import os.log

// MARK: - User Behavior Tracker

public class UserBehaviorTracker {
    private var sessionEvents: [AnalyticsEvent] = []
    private var screenViews: [ScreenView] = []
    private var userJourney: [JourneyStep] = []
    private var behaviorPatterns: [String: BehaviorPattern] = [:]
    private let queue = DispatchQueue(label: "com.claudecode.behavior.tracker")
    private let logger = Logger(subsystem: "com.claudecode.analytics", category: "Behavior")
    
    struct ScreenView {
        let name: String
        let timestamp: Date
        let duration: TimeInterval?
        let previousScreen: String?
    }
    
    struct JourneyStep {
        let event: String
        let timestamp: Date
        let properties: [String: Any]
    }
    
    struct BehaviorPattern {
        let pattern: String
        var occurrences: Int
        var lastSeen: Date
        var averageTime: TimeInterval
    }
    
    func trackBehavior(_ event: AnalyticsEvent) {
        queue.async {
            self.sessionEvents.append(event)
            self.userJourney.append(JourneyStep(
                event: event.name,
                timestamp: event.timestamp ?? Date(),
                properties: event.properties
            ))
            
            self.detectPatterns(for: event)
            self.analyzeUserFlow()
        }
    }
    
    func trackScreenView(_ screenName: String) {
        queue.async {
            let previousScreen = self.screenViews.last?.name
            
            // Calculate duration for previous screen
            if let lastScreen = self.screenViews.last {
                let duration = Date().timeIntervalSince(lastScreen.timestamp)
                self.screenViews[self.screenViews.count - 1] = ScreenView(
                    name: lastScreen.name,
                    timestamp: lastScreen.timestamp,
                    duration: duration,
                    previousScreen: lastScreen.previousScreen
                )
            }
            
            self.screenViews.append(ScreenView(
                name: screenName,
                timestamp: Date(),
                duration: nil,
                previousScreen: previousScreen
            ))
            
            self.analyzeScreenFlow()
        }
    }
    
    func getSessionEventCount() -> Int {
        return queue.sync { sessionEvents.count }
    }
    
    func getUserJourney() -> [JourneyStep] {
        return queue.sync { userJourney }
    }
    
    func getTopPatterns(limit: Int = 10) -> [(String, Int)] {
        return queue.sync {
            behaviorPatterns
                .sorted { $0.value.occurrences > $1.value.occurrences }
                .prefix(limit)
                .map { ($0.key, $0.value.occurrences) }
        }
    }
    
    private func detectPatterns(for event: AnalyticsEvent) {
        // Simple pattern detection - sequence of last 3 events
        guard userJourney.count >= 3 else { return }
        
        let recentEvents = userJourney.suffix(3)
        let pattern = recentEvents.map { $0.event }.joined(separator: " → ")
        
        if var existing = behaviorPatterns[pattern] {
            existing.occurrences += 1
            existing.lastSeen = Date()
            behaviorPatterns[pattern] = existing
        } else {
            behaviorPatterns[pattern] = BehaviorPattern(
                pattern: pattern,
                occurrences: 1,
                lastSeen: Date(),
                averageTime: 0
            )
        }
    }
    
    private func analyzeUserFlow() {
        // Analyze common user paths
        guard userJourney.count >= 2 else { return }
        
        // Track transitions
        for i in 0..<(userJourney.count - 1) {
            let from = userJourney[i].event
            let to = userJourney[i + 1].event
            let transition = "\(from) → \(to)"
            
            // Update pattern for transitions
            if var pattern = behaviorPatterns[transition] {
                pattern.occurrences += 1
                pattern.lastSeen = Date()
                behaviorPatterns[transition] = pattern
            } else {
                behaviorPatterns[transition] = BehaviorPattern(
                    pattern: transition,
                    occurrences: 1,
                    lastSeen: Date(),
                    averageTime: 0
                )
            }
        }
    }
    
    private func analyzeScreenFlow() {
        // Analyze screen navigation patterns
        guard screenViews.count >= 2 else { return }
        
        let lastTwo = screenViews.suffix(2)
        if lastTwo.count == 2 {
            let transition = "\(lastTwo[0].name) → \(lastTwo[1].name)"
            logger.debug("Screen transition: \(transition)")
        }
    }
}

// MARK: - Conversion Funnel Analyzer

public class ConversionFunnelAnalyzer {
    private var funnels: [String: ConversionFunnel] = [:]
    private var funnelProgress: [String: [String: FunnelUserProgress]] = [:] // [funnelName: [userId: progress]]
    private let queue = DispatchQueue(label: "com.claudecode.funnel.analyzer")
    private let logger = Logger(subsystem: "com.claudecode.analytics", category: "Funnel")
    
    struct FunnelUserProgress {
        let userId: String
        var currentStep: String
        var completedSteps: Set<String>
        var stepTimestamps: [String: Date]
        let startTime: Date
        var completed: Bool = false
    }
    
    func defineFunnel(_ funnel: ConversionFunnel) {
        queue.async(flags: .barrier) {
            self.funnels[funnel.name] = funnel
            self.funnelProgress[funnel.name] = [:]
            self.logger.info("Funnel defined: \(funnel.name) with \(funnel.steps.count) steps")
        }
    }
    
    func processEvent(_ event: AnalyticsEvent) {
        queue.async(flags: .barrier) {
            // Check if event matches any funnel steps
            for (funnelName, funnel) in self.funnels {
                if funnel.steps.contains(event.name) {
                    self.updateFunnelProgress(
                        funnelName: funnelName,
                        step: event.name,
                        userId: event.userId ?? event.anonymousId ?? "unknown",
                        timestamp: event.timestamp ?? Date()
                    )
                }
            }
        }
    }
    
    func trackStep(funnelName: String, step: String, properties: [String: Any]) {
        queue.async(flags: .barrier) {
            guard let funnel = self.funnels[funnelName] else {
                self.logger.warning("Unknown funnel: \(funnelName)")
                return
            }
            
            guard funnel.steps.contains(step) else {
                self.logger.warning("Step \(step) not in funnel \(funnelName)")
                return
            }
            
            let userId = properties["user_id"] as? String ?? "anonymous"
            self.updateFunnelProgress(
                funnelName: funnelName,
                step: step,
                userId: userId,
                timestamp: Date()
            )
        }
    }
    
    func getConversionReport(for funnelName: String) -> FunnelConversionReport? {
        return queue.sync {
            guard let funnel = funnels[funnelName],
                  let progress = funnelProgress[funnelName] else {
                return nil
            }
            
            var stepConversions: [FunnelConversionReport.StepConversion] = []
            var previousStepUsers = progress.count
            
            for (index, step) in funnel.steps.enumerated() {
                let usersAtStep = progress.values.filter { $0.completedSteps.contains(step) }.count
                let conversionRate = previousStepUsers > 0 ? Double(usersAtStep) / Double(previousStepUsers) : 0
                let dropoffRate = 1.0 - conversionRate
                
                // Calculate average time to step
                let times = progress.values.compactMap { progress -> TimeInterval? in
                    guard let stepTime = progress.stepTimestamps[step] else { return nil }
                    return stepTime.timeIntervalSince(progress.startTime)
                }
                let averageTime = times.isEmpty ? 0 : times.reduce(0, +) / Double(times.count)
                
                stepConversions.append(FunnelConversionReport.StepConversion(
                    step: step,
                    users: usersAtStep,
                    conversionRate: conversionRate,
                    dropoffRate: dropoffRate,
                    averageTime: averageTime
                ))
                
                previousStepUsers = usersAtStep
            }
            
            let completedUsers = progress.values.filter { $0.completed }.count
            let overallConversionRate = progress.count > 0 ? Double(completedUsers) / Double(progress.count) : 0
            
            // Calculate average time to complete
            let completionTimes = progress.values.compactMap { progress -> TimeInterval? in
                guard progress.completed,
                      let goalTime = progress.stepTimestamps[funnel.goalStep] else { return nil }
                return goalTime.timeIntervalSince(progress.startTime)
            }
            let averageTimeToConvert = completionTimes.isEmpty ? 0 : completionTimes.reduce(0, +) / Double(completionTimes.count)
            
            return FunnelConversionReport(
                funnelName: funnelName,
                totalUsers: progress.count,
                stepConversions: stepConversions,
                overallConversionRate: overallConversionRate,
                averageTimeToConvert: averageTimeToConvert
            )
        }
    }
    
    private func updateFunnelProgress(funnelName: String, step: String, userId: String, timestamp: Date) {
        guard let funnel = funnels[funnelName] else { return }
        
        if funnelProgress[funnelName] == nil {
            funnelProgress[funnelName] = [:]
        }
        
        if var userProgress = funnelProgress[funnelName]?[userId] {
            // Check timeout
            if let lastTimestamp = userProgress.stepTimestamps.values.max() {
                if timestamp.timeIntervalSince(lastTimestamp) > funnel.timeout {
                    // Timeout exceeded, start new funnel
                    userProgress = FunnelUserProgress(
                        userId: userId,
                        currentStep: step,
                        completedSteps: [step],
                        stepTimestamps: [step: timestamp],
                        startTime: timestamp,
                        completed: false
                    )
                } else {
                    // Continue funnel
                    userProgress.currentStep = step
                    userProgress.completedSteps.insert(step)
                    userProgress.stepTimestamps[step] = timestamp
                    
                    if step == funnel.goalStep {
                        userProgress.completed = true
                        logger.info("User \(userId) completed funnel \(funnelName)")
                    }
                }
            }
            
            funnelProgress[funnelName]?[userId] = userProgress
        } else {
            // New user in funnel
            let userProgress = FunnelUserProgress(
                userId: userId,
                currentStep: step,
                completedSteps: [step],
                stepTimestamps: [step: timestamp],
                startTime: timestamp,
                completed: step == funnel.goalStep
            )
            
            funnelProgress[funnelName]?[userId] = userProgress
        }
    }
}

// MARK: - Feature Adoption Tracker

public class FeatureAdoptionTracker {
    private var featureUsage: [String: FeatureUsageData] = [:]
    private let queue = DispatchQueue(label: "com.claudecode.feature.adoption")
    private let logger = Logger(subsystem: "com.claudecode.analytics", category: "FeatureAdoption")
    
    struct FeatureUsageData {
        let name: String
        var users: Set<String>
        var dailyUsers: Set<String>
        var weeklyUsers: Set<String>
        var monthlyUsers: Set<String>
        var usageCount: [String: Int] // userId: count
        var firstUsed: Date
        var lastUsed: Date
        var lastDailyReset: Date
        var lastWeeklyReset: Date
        var lastMonthlyReset: Date
    }
    
    func trackFeatureUsage(_ event: AnalyticsEvent) {
        guard event.category == .feature else { return }
        
        if let featureName = event.properties["feature"] as? String {
            trackUsage(featureName: featureName, userId: event.userId ?? event.anonymousId ?? "unknown")
        }
    }
    
    func trackUsage(featureName: String, userId: String) {
        queue.async(flags: .barrier) {
            let now = Date()
            
            if var feature = self.featureUsage[featureName] {
                // Update existing feature
                feature.users.insert(userId)
                feature.lastUsed = now
                
                // Update usage count
                feature.usageCount[userId, default: 0] += 1
                
                // Reset daily/weekly/monthly if needed
                if !Calendar.current.isDate(feature.lastDailyReset, inSameDayAs: now) {
                    feature.dailyUsers.removeAll()
                    feature.lastDailyReset = now
                }
                
                if !self.isInSameWeek(feature.lastWeeklyReset, now) {
                    feature.weeklyUsers.removeAll()
                    feature.lastWeeklyReset = now
                }
                
                if !self.isInSameMonth(feature.lastMonthlyReset, now) {
                    feature.monthlyUsers.removeAll()
                    feature.lastMonthlyReset = now
                }
                
                // Add user to active sets
                feature.dailyUsers.insert(userId)
                feature.weeklyUsers.insert(userId)
                feature.monthlyUsers.insert(userId)
                
                self.featureUsage[featureName] = feature
            } else {
                // New feature
                let feature = FeatureUsageData(
                    name: featureName,
                    users: [userId],
                    dailyUsers: [userId],
                    weeklyUsers: [userId],
                    monthlyUsers: [userId],
                    usageCount: [userId: 1],
                    firstUsed: now,
                    lastUsed: now,
                    lastDailyReset: now,
                    lastWeeklyReset: now,
                    lastMonthlyReset: now
                )
                
                self.featureUsage[featureName] = feature
            }
            
            self.logger.debug("Feature usage tracked: \(featureName) by user \(userId)")
        }
    }
    
    func getMetrics() -> FeatureAdoptionMetrics {
        return queue.sync {
            let totalFeatures = featureUsage.count
            let adoptedFeatures = featureUsage.filter { $0.value.users.count > 0 }.count
            let adoptionRate = totalFeatures > 0 ? Double(adoptedFeatures) / Double(totalFeatures) : 0
            
            var featureUsageMetrics: [String: FeatureAdoptionMetrics.FeatureUsage] = [:]
            
            for (name, data) in featureUsage {
                let averageUsage = data.usageCount.values.reduce(0, +) / max(data.users.count, 1)
                
                featureUsageMetrics[name] = FeatureAdoptionMetrics.FeatureUsage(
                    name: name,
                    totalUsers: data.users.count,
                    dailyActiveUsers: data.dailyUsers.count,
                    weeklyActiveUsers: data.weeklyUsers.count,
                    monthlyActiveUsers: data.monthlyUsers.count,
                    averageUsagePerUser: Double(averageUsage),
                    firstUsedDate: data.firstUsed,
                    lastUsedDate: data.lastUsed
                )
            }
            
            return FeatureAdoptionMetrics(
                totalFeatures: totalFeatures,
                adoptedFeatures: adoptedFeatures,
                adoptionRate: adoptionRate,
                featureUsage: featureUsageMetrics
            )
        }
    }
    
    private func isInSameWeek(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        let week1 = calendar.component(.weekOfYear, from: date1)
        let week2 = calendar.component(.weekOfYear, from: date2)
        let year1 = calendar.component(.year, from: date1)
        let year2 = calendar.component(.year, from: date2)
        return week1 == week2 && year1 == year2
    }
    
    private func isInSameMonth(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        let month1 = calendar.component(.month, from: date1)
        let month2 = calendar.component(.month, from: date2)
        let year1 = calendar.component(.year, from: date1)
        let year2 = calendar.component(.year, from: date2)
        return month1 == month2 && year1 == year2
    }
}

// MARK: - Cohort Analyzer

public class CohortAnalyzer {
    private var cohorts: [String: Cohort] = [:]
    private let queue = DispatchQueue(label: "com.claudecode.cohort.analyzer")
    private let logger = Logger(subsystem: "com.claudecode.analytics", category: "Cohort")
    
    struct Cohort {
        let name: String
        var users: Set<String>
        var activeUsers: Set<String>
        var events: [String: Int] // eventName: count
        var totalSessions: Int
        var totalSessionDuration: TimeInterval
        var createdAt: Date
        var lastActivity: Date
    }
    
    func assignUser(_ userId: String, to cohortName: String) {
        queue.async(flags: .barrier) {
            if var cohort = self.cohorts[cohortName] {
                cohort.users.insert(userId)
                cohort.lastActivity = Date()
                self.cohorts[cohortName] = cohort
            } else {
                let cohort = Cohort(
                    name: cohortName,
                    users: [userId],
                    activeUsers: [],
                    events: [:],
                    totalSessions: 0,
                    totalSessionDuration: 0,
                    createdAt: Date(),
                    lastActivity: Date()
                )
                self.cohorts[cohortName] = cohort
            }
            
            self.logger.info("User \(userId) assigned to cohort \(cohortName)")
        }
    }
    
    func processEvent(_ event: AnalyticsEvent) {
        guard let userId = event.userId ?? event.anonymousId else { return }
        
        queue.async(flags: .barrier) {
            // Find user's cohort
            for (cohortName, var cohort) in self.cohorts {
                if cohort.users.contains(userId) {
                    // Update cohort metrics
                    cohort.events[event.name, default: 0] += 1
                    cohort.activeUsers.insert(userId)
                    cohort.lastActivity = Date()
                    
                    if event.name == "session_start" {
                        cohort.totalSessions += 1
                    } else if event.name == "session_end",
                              let duration = event.properties["duration"] as? TimeInterval {
                        cohort.totalSessionDuration += duration
                    }
                    
                    self.cohorts[cohortName] = cohort
                }
            }
        }
    }
    
    func getMetrics(for cohortName: String) -> CohortMetrics? {
        return queue.sync {
            guard let cohort = cohorts[cohortName] else { return nil }
            
            let retentionRate = cohort.users.count > 0 ? Double(cohort.activeUsers.count) / Double(cohort.users.count) : 0
            let averageSessionLength = cohort.totalSessions > 0 ? cohort.totalSessionDuration / Double(cohort.totalSessions) : 0
            let averageEventsPerSession = cohort.totalSessions > 0 ? cohort.events.values.reduce(0, +) / cohort.totalSessions : 0
            
            let topEvents = cohort.events
                .sorted { $0.value > $1.value }
                .prefix(10)
                .map { ($0.key, $0.value) }
            
            return CohortMetrics(
                cohortName: cohortName,
                userCount: cohort.users.count,
                activeUsers: cohort.activeUsers.count,
                retentionRate: retentionRate,
                averageSessionLength: averageSessionLength,
                averageEventsPerSession: averageEventsPerSession,
                topEvents: topEvents
            )
        }
    }
}

// MARK: - Retention Tracker

public class RetentionTracker {
    private var dailyCohorts: [String: DailyRetentionCohort] = [] // date string: cohort
    private let queue = DispatchQueue(label: "com.claudecode.retention.tracker")
    private let logger = Logger(subsystem: "com.claudecode.analytics", category: "Retention")
    
    struct DailyRetentionCohort {
        let date: Date
        var initialUsers: Set<String>
        var retainedUsers: [Int: Set<String>] // day: users
    }
    
    func recordSession(userId: String) {
        queue.async(flags: .barrier) {
            let today = self.dateKey(for: Date())
            
            // Add user to today's cohort
            if var cohort = self.dailyCohorts[today] {
                cohort.initialUsers.insert(userId)
                self.dailyCohorts[today] = cohort
            } else {
                let cohort = DailyRetentionCohort(
                    date: Date(),
                    initialUsers: [userId],
                    retainedUsers: [:]
                )
                self.dailyCohorts[today] = cohort
            }
            
            // Update retention for previous cohorts
            for (dateKey, var cohort) in self.dailyCohorts {
                guard dateKey != today else { continue }
                
                let daysSince = self.daysBetween(cohort.date, Date())
                if daysSince > 0 && daysSince <= 30 {
                    if cohort.retainedUsers[daysSince] == nil {
                        cohort.retainedUsers[daysSince] = []
                    }
                    cohort.retainedUsers[daysSince]?.insert(userId)
                    self.dailyCohorts[dateKey] = cohort
                }
            }
        }
    }
    
    func getMetrics(for days: Int) -> RetentionMetrics {
        return queue.sync {
            var cohorts: [RetentionMetrics.DailyCohort] = []
            var overallRetention: [Int: Double] = [:]
            
            for (_, cohort) in dailyCohorts {
                var retained: [Int: Int] = [:]
                for (day, users) in cohort.retainedUsers {
                    retained[day] = users.count
                }
                
                cohorts.append(RetentionMetrics.DailyCohort(
                    date: cohort.date,
                    initialUsers: cohort.initialUsers.count,
                    retainedUsers: retained
                ))
            }
            
            // Calculate overall retention rates
            for day in 1...days {
                var totalInitial = 0
                var totalRetained = 0
                
                for cohort in dailyCohorts.values {
                    totalInitial += cohort.initialUsers.count
                    totalRetained += cohort.retainedUsers[day]?.count ?? 0
                }
                
                if totalInitial > 0 {
                    overallRetention[day] = Double(totalRetained) / Double(totalInitial)
                }
            }
            
            return RetentionMetrics(
                period: days,
                cohorts: cohorts.sorted { $0.date < $1.date },
                overallRetention: overallRetention
            )
        }
    }
    
    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func daysBetween(_ date1: Date, _ date2: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date1, to: date2)
        return components.day ?? 0
    }
}