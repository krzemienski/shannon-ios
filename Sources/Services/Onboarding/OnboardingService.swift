//
//  OnboardingService.swift
//  ClaudeCode
//
//  Comprehensive onboarding service with user preferences and progress tracking
//

import Foundation
import SwiftUI
import Combine
import UserNotifications
import AVFoundation
import Photos

// MARK: - Onboarding Step

public struct OnboardingStep: Identifiable {
    public let id = UUID()
    public let type: StepType
    public let title: String
    public let description: String
    public let icon: String
    public let isRequired: Bool
    public var isCompleted: Bool = false
    public var metadata: [String: Any] = [:]
    
    public enum StepType {
        case welcome
        case permissions
        case apiSetup
        case preferences
        case tutorial
        case completion
        case custom(String)
    }
}

// MARK: - User Preferences

public struct OnboardingUserPreferences: Codable {
    public var theme: String = "auto"
    public var primaryUseCase: String = ""
    public var experienceLevel: ExperienceLevel = .beginner
    public var preferredLanguages: [String] = []
    public var enableNotifications: Bool = true
    public var enableAnalytics: Bool = true
    public var enableCrashReporting: Bool = true
    public var autoSave: Bool = true
    public var showTips: Bool = true
    public var keyboardHaptics: Bool = true
    public var codeHighlighting: Bool = true
    public var fontSize: Int = 14
    public var tabSize: Int = 4
    
    public enum ExperienceLevel: String, Codable, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case expert = "Expert"
    }
}

// MARK: - Onboarding Progress

public struct OnboardingProgress: Codable {
    public var completedSteps: Set<String> = []
    public var currentStep: Int = 0
    public var totalSteps: Int = 0
    public var startedAt: Date = Date()
    public var completedAt: Date?
    public var skippedSteps: Set<String> = []
    public var preferences: OnboardingUserPreferences = OnboardingUserPreferences()
    public var analyticsEvents: [[String: AnyCodable]] = []
}

// MARK: - Onboarding Service

@MainActor
public class OnboardingService: ObservableObject {
    public static let shared = OnboardingService()
    
    @Published public var progress = OnboardingProgress()
    @Published public var currentStep: OnboardingStep?
    @Published public var steps: [OnboardingStep] = []
    @Published public var isOnboardingActive = false
    @Published public var showTutorial = false
    @Published public var permissionStatuses: [PermissionType: Bool] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let progressKey = "com.claudecode.onboarding.progress"
    private let preferencesKey = "com.claudecode.user.preferences"
    private var cancellables = Set<AnyCancellable>()
    
    public enum PermissionType {
        case notifications
        case camera
        case microphone
        case photos
        case biometrics
    }
    
    private init() {
        loadProgress()
        setupSteps()
    }
    
    // MARK: - Public Methods
    
    /// Start onboarding flow
    public func startOnboarding() {
        isOnboardingActive = true
        progress.startedAt = Date()
        progress.currentStep = 0
        
        if !steps.isEmpty {
            currentStep = steps[0]
        }
        
        // Track onboarding start
        AnalyticsService.shared.track(event: "onboarding_started", properties: [
            "total_steps": steps.count
        ])
    }
    
    /// Complete current step and move to next
    public func completeCurrentStep(with data: [String: Any]? = nil) {
        guard let current = currentStep else { return }
        
        // Mark step as completed
        progress.completedSteps.insert(current.title)
        
        // Store any data from the step
        if let data = data {
            switch current.type {
            case .preferences:
                updatePreferences(from: data)
            case .apiSetup:
                saveAPIConfiguration(from: data)
            default:
                break
            }
        }
        
        // Track step completion
        AnalyticsService.shared.track(event: "onboarding_step_completed", properties: [
            "step": current.title,
            "step_type": String(describing: current.type),
            "step_number": progress.currentStep
        ])
        
        // Move to next step
        moveToNextStep()
    }
    
    /// Skip current step (if not required)
    public func skipCurrentStep() {
        guard let current = currentStep, !current.isRequired else { return }
        
        progress.skippedSteps.insert(current.title)
        
        // Track skip
        AnalyticsService.shared.track(event: "onboarding_step_skipped", properties: [
            "step": current.title
        ])
        
        moveToNextStep()
    }
    
    /// Move to specific step
    public func moveToStep(_ index: Int) {
        guard index >= 0 && index < steps.count else { return }
        
        progress.currentStep = index
        currentStep = steps[index]
    }
    
    /// Complete onboarding
    public func completeOnboarding() {
        progress.completedAt = Date()
        isOnboardingActive = false
        
        // Save completion
        userDefaults.set(true, forKey: "hasCompletedOnboarding")
        saveProgress()
        
        // Update app state
        Task {
            await DependencyContainer.shared.appState.completeOnboarding()
        }
        
        // Track completion
        let duration = progress.completedAt!.timeIntervalSince(progress.startedAt)
        AnalyticsService.shared.track(event: "onboarding_completed", properties: [
            "duration": duration,
            "completed_steps": progress.completedSteps.count,
            "skipped_steps": progress.skippedSteps.count,
            "experience_level": progress.preferences.experienceLevel.rawValue
        ])
        
        // Set user properties for analytics
        AnalyticsService.shared.setUserProperties([
            "experience_level": progress.preferences.experienceLevel.rawValue,
            "primary_use_case": progress.preferences.primaryUseCase,
            "onboarding_completed": true
        ])
    }
    
    /// Request permission
    public func requestPermission(_ type: PermissionType) async -> Bool {
        switch type {
        case .notifications:
            return await requestNotificationPermission()
        case .camera:
            return await requestCameraPermission()
        case .microphone:
            return await requestMicrophonePermission()
        case .photos:
            return await requestPhotosPermission()
        case .biometrics:
            return await requestBiometricPermission()
        }
    }
    
    /// Check permission status
    public func checkPermissionStatus(_ type: PermissionType) async -> Bool {
        switch type {
        case .notifications:
            return await checkNotificationStatus()
        case .camera:
            return checkMediaStatus(.video)
        case .microphone:
            return checkMediaStatus(.audio)
        case .photos:
            return checkPhotosStatus()
        case .biometrics:
            return await checkBiometricStatus()
        }
    }
    
    /// Update user preferences
    public func updatePreferences(_ preferences: OnboardingUserPreferences) {
        progress.preferences = preferences
        saveProgress()
        
        // Apply preferences
        applyPreferences(preferences)
    }
    
    /// Get onboarding progress percentage
    public func getProgressPercentage() -> Double {
        guard !steps.isEmpty else { return 0 }
        return Double(progress.completedSteps.count) / Double(steps.count)
    }
    
    // MARK: - Private Methods
    
    private func setupSteps() {
        steps = [
            OnboardingStep(
                type: .welcome,
                title: "Welcome to Claude Code",
                description: "Your AI-powered development companion",
                icon: "sparkles",
                isRequired: true
            ),
            OnboardingStep(
                type: .permissions,
                title: "Enable Features",
                description: "Grant permissions to unlock full functionality",
                icon: "lock.shield",
                isRequired: false
            ),
            OnboardingStep(
                type: .apiSetup,
                title: "API Configuration",
                description: "Connect to Claude API for AI assistance",
                icon: "network",
                isRequired: true
            ),
            OnboardingStep(
                type: .preferences,
                title: "Personalize Your Experience",
                description: "Customize settings to match your workflow",
                icon: "slider.horizontal.3",
                isRequired: false
            ),
            OnboardingStep(
                type: .tutorial,
                title: "Quick Tutorial",
                description: "Learn the basics in 2 minutes",
                icon: "graduationcap",
                isRequired: false
            ),
            OnboardingStep(
                type: .completion,
                title: "You're All Set!",
                description: "Start building with Claude Code",
                icon: "checkmark.circle.fill",
                isRequired: true
            )
        ]
        
        progress.totalSteps = steps.count
    }
    
    private func moveToNextStep() {
        let nextIndex = progress.currentStep + 1
        
        if nextIndex < steps.count {
            progress.currentStep = nextIndex
            currentStep = steps[nextIndex]
        } else {
            completeOnboarding()
        }
        
        saveProgress()
    }
    
    private func updatePreferences(from data: [String: Any]) {
        if let theme = data["theme"] as? String {
            progress.preferences.theme = theme
        }
        if let useCase = data["primaryUseCase"] as? String {
            progress.preferences.primaryUseCase = useCase
        }
        if let level = data["experienceLevel"] as? String,
           let experienceLevel = OnboardingUserPreferences.ExperienceLevel(rawValue: level) {
            progress.preferences.experienceLevel = experienceLevel
        }
        if let languages = data["preferredLanguages"] as? [String] {
            progress.preferences.preferredLanguages = languages
        }
        if let fontSize = data["fontSize"] as? Int {
            progress.preferences.fontSize = fontSize
        }
        
        saveProgress()
    }
    
    private func saveAPIConfiguration(from data: [String: Any]) {
        if let apiKey = data["apiKey"] as? String {
            Task {
                try? await KeychainManager.shared.saveAPIKey(apiKey)
            }
        }
        if let baseURL = data["baseURL"] as? String {
            userDefaults.set(baseURL, forKey: "apiBaseURL")
        }
    }
    
    private func applyPreferences(_ preferences: OnboardingUserPreferences) {
        // Apply theme
        if let theme = ColorScheme(rawValue: preferences.theme) {
            ThemeManager.shared.setColorScheme(theme)
        }
        
        // Apply other preferences
        userDefaults.set(preferences.enableAnalytics, forKey: "enableAnalytics")
        userDefaults.set(preferences.enableCrashReporting, forKey: "enableCrashReporting")
        userDefaults.set(preferences.autoSave, forKey: "autoSave")
        userDefaults.set(preferences.showTips, forKey: "showTips")
    }
    
    private func loadProgress() {
        if let data = userDefaults.data(forKey: progressKey),
           let saved = try? JSONDecoder().decode(OnboardingProgress.self, from: data) {
            progress = saved
        }
        
        if let data = userDefaults.data(forKey: preferencesKey),
           let prefs = try? JSONDecoder().decode(OnboardingUserPreferences.self, from: data) {
            progress.preferences = prefs
        }
    }
    
    private func saveProgress() {
        if let data = try? JSONEncoder().encode(progress) {
            userDefaults.set(data, forKey: progressKey)
        }
        
        if let data = try? JSONEncoder().encode(progress.preferences) {
            userDefaults.set(data, forKey: preferencesKey)
        }
    }
    
    // MARK: - Permission Handlers
    
    private func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            permissionStatuses[.notifications] = granted
            return granted
        } catch {
            return false
        }
    }
    
    private func checkNotificationStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let isEnabled = settings.authorizationStatus == .authorized
        permissionStatuses[.notifications] = isEnabled
        return isEnabled
    }
    
    private func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                self.permissionStatuses[.camera] = granted
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                self.permissionStatuses[.microphone] = granted
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func checkMediaStatus(_ mediaType: AVMediaType) -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: mediaType)
        return status == .authorized
    }
    
    private func requestPhotosPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                let granted = status == .authorized
                self.permissionStatuses[.photos] = granted
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func checkPhotosStatus() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus()
        let isEnabled = status == .authorized
        permissionStatuses[.photos] = isEnabled
        return isEnabled
    }
    
    private func requestBiometricPermission() async -> Bool {
        // Biometric permission is handled by BiometricAuthManager
        return await BiometricAuthManager.shared.requestBiometricAuthentication()
    }
    
    private func checkBiometricStatus() async -> Bool {
        return BiometricAuthManager.shared.isBiometricAuthenticationAvailable()
    }
}