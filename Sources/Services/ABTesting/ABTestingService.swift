//
//  ABTestingService.swift
//  ClaudeCode
//
//  A/B testing and experimentation framework
//

import Foundation
import SwiftUI
import Combine

// MARK: - Experiment Model

public struct Experiment: Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let hypothesis: String
    public let startDate: Date
    public let endDate: Date?
    public let status: ExperimentStatus
    public let variants: [Variant]
    public let metrics: [Metric]
    public let targetAudience: TargetCriteria?
    public let minimumSampleSize: Int
    public let confidenceLevel: Double
    
    public enum ExperimentStatus: String, Codable {
        case draft
        case scheduled
        case running
        case paused
        case completed
        case cancelled
    }
}

// MARK: - Variant Model

public struct Variant: Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let weight: Double // Distribution weight (0-1)
    public let configuration: [String: AnyCodable]
    public var participants: Int = 0
    public var conversions: Int = 0
    public var metrics: [String: Double] = [:]
}

// MARK: - Metric Model

public struct Metric: Identifiable, Codable {
    public let id: String
    public let name: String
    public let type: MetricType
    public let targetValue: Double?
    public let unit: String?
    public let isPrimary: Bool
    
    public enum MetricType: String, Codable {
        case conversion
        case engagement
        case retention
        case revenue
        case custom
    }
}

// MARK: - Target Criteria

public struct TargetCriteria: Codable {
    public let segments: [String]
    public let properties: [String: AnyCodable]
    public let percentage: Double // What percentage of eligible users to include
}

// MARK: - Experiment Result

public struct ExperimentResult: Codable {
    public let experimentId: String
    public let variantId: String
    public let metric: String
    public let value: Double
    public let sampleSize: Int
    public let confidence: Double
    public let uplift: Double? // Percentage change from control
    public let pValue: Double?
    public let isStatisticallySignificant: Bool
    public let timestamp: Date
}

// MARK: - AB Testing Service

@MainActor
public class ABTestingService: ObservableObject {
    public static let shared = ABTestingService()
    
    @Published public var experiments: [Experiment] = []
    @Published public var activeExperiments: [String: Experiment] = [:]
    @Published public var userAssignments: [String: String] = [:] // experimentId: variantId
    @Published public var experimentResults: [String: [ExperimentResult]] = [:]
    @Published public var isProcessingResults = false
    
    private let featureFlags = FeatureFlagService.shared
    private let analytics = AnalyticsService.shared
    private let personalization = PersonalizationService.shared
    private let userDefaults = UserDefaults.standard
    
    private let experimentsKey = "com.claudecode.abtesting.experiments"
    private let assignmentsKey = "com.claudecode.abtesting.assignments"
    private let resultsKey = "com.claudecode.abtesting.results"
    
    private var cancellables = Set<AnyCancellable>()
    private let statisticsQueue = DispatchQueue(label: "com.claudecode.statistics", qos: .background)
    
    private init() {
        loadExperiments()
        loadAssignments()
        loadResults()
        setupObservers()
        startExperimentMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Create a new experiment
    public func createExperiment(_ experiment: Experiment) {
        experiments.append(experiment)
        
        if experiment.status == .running {
            activeExperiments[experiment.id] = experiment
        }
        
        saveExperiments()
        
        // Track experiment creation
        analytics.track(event: "experiment_created", properties: [
            "experiment_id": experiment.id,
            "name": experiment.name,
            "variants_count": experiment.variants.count
        ])
    }
    
    /// Start an experiment
    public func startExperiment(_ experimentId: String) {
        guard let index = experiments.firstIndex(where: { $0.id == experimentId }) else { return }
        
        var experiment = experiments[index]
        experiment = Experiment(
            id: experiment.id,
            name: experiment.name,
            description: experiment.description,
            hypothesis: experiment.hypothesis,
            startDate: Date(),
            endDate: experiment.endDate,
            status: .running,
            variants: experiment.variants,
            metrics: experiment.metrics,
            targetAudience: experiment.targetAudience,
            minimumSampleSize: experiment.minimumSampleSize,
            confidenceLevel: experiment.confidenceLevel
        )
        
        experiments[index] = experiment
        activeExperiments[experimentId] = experiment
        
        saveExperiments()
        
        // Start assigning users
        assignUsersToExperiment(experiment)
        
        analytics.track(event: "experiment_started", properties: [
            "experiment_id": experimentId
        ])
    }
    
    /// Stop an experiment
    public func stopExperiment(_ experimentId: String, status: Experiment.ExperimentStatus = .completed) {
        guard let index = experiments.firstIndex(where: { $0.id == experimentId }) else { return }
        
        var experiment = experiments[index]
        experiment = Experiment(
            id: experiment.id,
            name: experiment.name,
            description: experiment.description,
            hypothesis: experiment.hypothesis,
            startDate: experiment.startDate,
            endDate: Date(),
            status: status,
            variants: experiment.variants,
            metrics: experiment.metrics,
            targetAudience: experiment.targetAudience,
            minimumSampleSize: experiment.minimumSampleSize,
            confidenceLevel: experiment.confidenceLevel
        )
        
        experiments[index] = experiment
        activeExperiments.removeValue(forKey: experimentId)
        
        saveExperiments()
        
        // Calculate final results
        Task {
            await calculateResults(for: experimentId)
        }
        
        analytics.track(event: "experiment_stopped", properties: [
            "experiment_id": experimentId,
            "status": status.rawValue
        ])
    }
    
    /// Get user's variant for an experiment
    public func getVariant(for experimentId: String) -> String? {
        // Check if user is already assigned
        if let variantId = userAssignments[experimentId] {
            return variantId
        }
        
        // Check if experiment is active
        guard let experiment = activeExperiments[experimentId] else { return nil }
        
        // Check if user meets criteria
        if let criteria = experiment.targetAudience {
            if !userMeetsCriteria(criteria) { return nil }
        }
        
        // Assign user to variant
        let variantId = assignUserToVariant(experiment)
        userAssignments[experimentId] = variantId
        saveAssignments()
        
        // Track assignment
        analytics.track(event: "experiment_assignment", properties: [
            "experiment_id": experimentId,
            "variant_id": variantId
        ])
        
        return variantId
    }
    
    /// Track experiment event
    public func trackEvent(
        experimentId: String,
        event: String,
        value: Double? = nil,
        properties: [String: Any] = [:]
    ) {
        guard let variantId = userAssignments[experimentId] else { return }
        
        var eventProperties = properties
        eventProperties["experiment_id"] = experimentId
        eventProperties["variant_id"] = variantId
        eventProperties["event"] = event
        
        if let value = value {
            eventProperties["value"] = value
        }
        
        // Track with analytics
        analytics.track(event: "experiment_event", properties: eventProperties)
        
        // Update variant metrics
        updateVariantMetrics(experimentId: experimentId, variantId: variantId, event: event, value: value)
    }
    
    /// Track conversion
    public func trackConversion(
        experimentId: String,
        metricId: String,
        value: Double = 1.0
    ) {
        guard let variantId = userAssignments[experimentId],
              let experiment = activeExperiments[experimentId],
              let variantIndex = experiment.variants.firstIndex(where: { $0.id == variantId })
        else { return }
        
        var variant = experiment.variants[variantIndex]
        variant.conversions += 1
        variant.metrics[metricId, default: 0] += value
        
        // Update experiment
        var updatedExperiment = experiment
        updatedExperiment.variants[variantIndex] = variant
        activeExperiments[experimentId] = updatedExperiment
        
        if let index = experiments.firstIndex(where: { $0.id == experimentId }) {
            experiments[index] = updatedExperiment
        }
        
        saveExperiments()
        
        // Track conversion
        analytics.track(event: "experiment_conversion", properties: [
            "experiment_id": experimentId,
            "variant_id": variantId,
            "metric_id": metricId,
            "value": value
        ])
        
        // Check if we have enough data for analysis
        if shouldAnalyzeResults(experiment) {
            Task {
                await calculateResults(for: experimentId)
            }
        }
    }
    
    /// Get experiment results
    public func getResults(for experimentId: String) -> [ExperimentResult] {
        return experimentResults[experimentId] ?? []
    }
    
    /// Get winning variant
    public func getWinningVariant(for experimentId: String) -> Variant? {
        guard let experiment = experiments.first(where: { $0.id == experimentId }),
              let results = experimentResults[experimentId],
              !results.isEmpty else { return nil }
        
        // Find variant with best performance on primary metric
        let primaryMetric = experiment.metrics.first { $0.isPrimary }
        guard let primaryMetricId = primaryMetric?.id else { return nil }
        
        let metricResults = results.filter { $0.metric == primaryMetricId }
        guard let bestResult = metricResults.max(by: { $0.value < $1.value }),
              bestResult.isStatisticallySignificant else { return nil }
        
        return experiment.variants.first { $0.id == bestResult.variantId }
    }
    
    /// Calculate statistical significance
    public func calculateStatisticalSignificance(
        controlValue: Double,
        controlSize: Int,
        variantValue: Double,
        variantSize: Int,
        confidenceLevel: Double = 0.95
    ) -> (pValue: Double, isSignificant: Bool, uplift: Double) {
        // Simplified statistical test (in production, use proper statistical libraries)
        let pooledProportion = (controlValue + variantValue) / Double(controlSize + variantSize)
        let standardError = sqrt(pooledProportion * (1 - pooledProportion) * (1.0/Double(controlSize) + 1.0/Double(variantSize)))
        
        guard standardError > 0 else { return (1.0, false, 0.0) }
        
        let zScore = (variantValue/Double(variantSize) - controlValue/Double(controlSize)) / standardError
        let pValue = 2 * (1 - normalCDF(abs(zScore)))
        
        let isSignificant = pValue < (1 - confidenceLevel)
        let uplift = ((variantValue/Double(variantSize)) - (controlValue/Double(controlSize))) / (controlValue/Double(controlSize)) * 100
        
        return (pValue, isSignificant, uplift)
    }
    
    // MARK: - Private Methods
    
    private func loadExperiments() {
        if let data = userDefaults.data(forKey: experimentsKey),
           let saved = try? JSONDecoder().decode([Experiment].self, from: data) {
            experiments = saved
            
            // Load active experiments
            activeExperiments = Dictionary(
                uniqueKeysWithValues: experiments
                    .filter { $0.status == .running }
                    .map { ($0.id, $0) }
            )
        }
    }
    
    private func saveExperiments() {
        if let data = try? JSONEncoder().encode(experiments) {
            userDefaults.set(data, forKey: experimentsKey)
        }
    }
    
    private func loadAssignments() {
        if let saved = userDefaults.dictionary(forKey: assignmentsKey) as? [String: String] {
            userAssignments = saved
        }
    }
    
    private func saveAssignments() {
        userDefaults.set(userAssignments, forKey: assignmentsKey)
    }
    
    private func loadResults() {
        if let data = userDefaults.data(forKey: resultsKey),
           let saved = try? JSONDecoder().decode([String: [ExperimentResult]].self, from: data) {
            experimentResults = saved
        }
    }
    
    private func saveResults() {
        if let data = try? JSONEncoder().encode(experimentResults) {
            userDefaults.set(data, forKey: resultsKey)
        }
    }
    
    private func assignUsersToExperiment(_ experiment: Experiment) {
        // This would typically involve server-side assignment
        // For now, we'll handle it locally
    }
    
    private func userMeetsCriteria(_ criteria: TargetCriteria) -> Bool {
        // Check if user is in target segments
        let userSegments = getUserSegments()
        let matchesSegments = criteria.segments.isEmpty ||
                             !Set(criteria.segments).isDisjoint(with: userSegments)
        
        if !matchesSegments { return false }
        
        // Check random sampling
        let randomValue = Double.random(in: 0...1)
        return randomValue <= criteria.percentage
    }
    
    private func getUserSegments() -> Set<String> {
        var segments: Set<String> = []
        
        // Determine user segments based on behavior
        let behavior = personalization.userBehavior
        
        if behavior.sessionCount > 20 {
            segments.insert("power_user")
        } else if behavior.sessionCount < 5 {
            segments.insert("new_user")
        }
        
        // Add more segmentation logic
        
        return segments
    }
    
    private func assignUserToVariant(_ experiment: Experiment) -> String {
        let random = Double.random(in: 0...1)
        var cumulative = 0.0
        
        for variant in experiment.variants {
            cumulative += variant.weight
            if random <= cumulative {
                return variant.id
            }
        }
        
        // Fallback to last variant
        return experiment.variants.last?.id ?? ""
    }
    
    private func updateVariantMetrics(
        experimentId: String,
        variantId: String,
        event: String,
        value: Double?
    ) {
        guard var experiment = activeExperiments[experimentId],
              let variantIndex = experiment.variants.firstIndex(where: { $0.id == variantId })
        else { return }
        
        var variant = experiment.variants[variantIndex]
        variant.participants = max(variant.participants, 1) // Ensure at least 1 participant
        
        if let value = value {
            variant.metrics[event, default: 0] += value
        } else {
            variant.metrics[event, default: 0] += 1
        }
        
        experiment.variants[variantIndex] = variant
        activeExperiments[experimentId] = experiment
        
        if let index = experiments.firstIndex(where: { $0.id == experimentId }) {
            experiments[index] = experiment
        }
        
        saveExperiments()
    }
    
    private func shouldAnalyzeResults(_ experiment: Experiment) -> Bool {
        let totalParticipants = experiment.variants.reduce(0) { $0 + $1.participants }
        return totalParticipants >= experiment.minimumSampleSize
    }
    
    private func calculateResults(for experimentId: String) async {
        guard let experiment = experiments.first(where: { $0.id == experimentId }),
              let control = experiment.variants.first else { return }
        
        isProcessingResults = true
        defer { isProcessingResults = false }
        
        var results: [ExperimentResult] = []
        
        for metric in experiment.metrics {
            for variant in experiment.variants {
                guard variant.id != control.id else { continue }
                
                let controlValue = control.metrics[metric.id] ?? 0
                let variantValue = variant.metrics[metric.id] ?? 0
                
                let significance = calculateStatisticalSignificance(
                    controlValue: controlValue,
                    controlSize: control.participants,
                    variantValue: variantValue,
                    variantSize: variant.participants,
                    confidenceLevel: experiment.confidenceLevel
                )
                
                let result = ExperimentResult(
                    experimentId: experimentId,
                    variantId: variant.id,
                    metric: metric.id,
                    value: variantValue / max(Double(variant.participants), 1),
                    sampleSize: variant.participants,
                    confidence: experiment.confidenceLevel,
                    uplift: significance.uplift,
                    pValue: significance.pValue,
                    isStatisticallySignificant: significance.isSignificant,
                    timestamp: Date()
                )
                
                results.append(result)
            }
        }
        
        experimentResults[experimentId] = results
        saveResults()
        
        // Check if experiment should be stopped
        if let winningVariant = getWinningVariant(for: experimentId) {
            // Notify about winning variant
            NotificationCenter.default.post(
                name: .experimentCompleted,
                object: nil,
                userInfo: [
                    "experimentId": experimentId,
                    "winningVariantId": winningVariant.id
                ]
            )
        }
    }
    
    private func normalCDF(_ x: Double) -> Double {
        // Simplified normal CDF calculation
        return 0.5 * (1 + erf(x / sqrt(2)))
    }
    
    private func erf(_ x: Double) -> Double {
        // Approximation of error function
        let a1 =  0.254829592
        let a2 = -0.284496736
        let a3 =  1.421413741
        let a4 = -1.453152027
        let a5 =  1.061405429
        let p  =  0.3275911
        
        let sign = x < 0 ? -1.0 : 1.0
        let absX = abs(x)
        
        let t = 1.0 / (1.0 + p * absX)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-absX * absX)
        
        return sign * y
    }
    
    private func setupObservers() {
        // Monitor experiment status changes
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkExperimentStatus()
            }
            .store(in: &cancellables)
    }
    
    private func startExperimentMonitoring() {
        // Start monitoring active experiments
        Task {
            for experiment in activeExperiments.values {
                if shouldAnalyzeResults(experiment) {
                    await calculateResults(for: experiment.id)
                }
            }
        }
    }
    
    private func checkExperimentStatus() {
        let now = Date()
        
        for experiment in experiments {
            // Start scheduled experiments
            if experiment.status == .scheduled && experiment.startDate <= now {
                startExperiment(experiment.id)
            }
            
            // Stop expired experiments
            if let endDate = experiment.endDate,
               experiment.status == .running && endDate <= now {
                stopExperiment(experiment.id)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let experimentCompleted = Notification.Name("experimentCompleted")
    static let experimentStarted = Notification.Name("experimentStarted")
}