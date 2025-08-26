//
//  EnhancedOnboardingView.swift
//  ClaudeCode
//
//  Comprehensive onboarding flow with permissions, preferences, and tutorials
//

import SwiftUI
import Lottie

struct EnhancedOnboardingView: View {
    @StateObject private var onboardingService = OnboardingService.shared
    @StateObject private var featureFlags = FeatureFlagService.shared
    @State private var currentPage = 0
    @State private var showSkipButton = true
    @State private var animateContent = false
    @State private var selectedPreferences = UserPreferences()
    @State private var apiKey = ""
    @State private var baseURL = "http://localhost:8000/v1"
    @Environment(\.dismiss) private var dismiss
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Theme.background,
                    Theme.card
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                OnboardingProgressBar(
                    currentStep: currentPage,
                    totalSteps: onboardingService.steps.count
                )
                .padding(.horizontal)
                .padding(.top, Theme.spacing.lg)
                
                // Content
                TabView(selection: $currentPage) {
                    ForEach(Array(onboardingService.steps.enumerated()), id: \.element.id) { index, step in
                        getViewForStep(step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(), value: currentPage)
                
                // Navigation buttons
                navigationButtons
                    .padding(.horizontal)
                    .padding(.bottom, Theme.spacing.xl)
            }
        }
        .onAppear {
            onboardingService.startOnboarding()
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animateContent = true
            }
        }
    }
    
    @ViewBuilder
    private func getViewForStep(_ step: OnboardingStep) -> some View {
        switch step.type {
        case .welcome:
            WelcomeStepView(animateContent: $animateContent)
        case .permissions:
            PermissionsStepView()
        case .apiSetup:
            APISetupStepView(apiKey: $apiKey, baseURL: $baseURL)
        case .preferences:
            PreferencesStepView(preferences: $selectedPreferences)
        case .tutorial:
            TutorialStepView()
        case .completion:
            CompletionStepView(onComplete: onComplete)
        case .custom(_):
            EmptyView()
        }
    }
    
    private var navigationButtons: some View {
        HStack(spacing: Theme.spacing.md) {
            // Skip button (if applicable)
            if showSkipButton && currentPage < onboardingService.steps.count - 1 {
                Button("Skip") {
                    if !onboardingService.steps[currentPage].isRequired {
                        onboardingService.skipCurrentStep()
                        advanceToNextPage()
                    }
                }
                .font(Theme.typography.body)
                .foregroundColor(Theme.muted)
            }
            
            Spacer()
            
            // Back button
            if currentPage > 0 {
                Button {
                    withAnimation {
                        currentPage -= 1
                    }
                } label: {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.primary)
                }
            }
            
            // Next/Complete button
            Button {
                handleNextAction()
            } label: {
                HStack {
                    Text(currentPage == onboardingService.steps.count - 1 ? "Get Started" : "Next")
                        .font(Theme.typography.headline)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
                .padding(.horizontal, Theme.spacing.lg)
                .padding(.vertical, Theme.spacing.md)
                .background(Theme.primary)
                .foregroundColor(Theme.background)
                .cornerRadius(Theme.radius.medium)
            }
        }
    }
    
    private func handleNextAction() {
        let currentStep = onboardingService.steps[currentPage]
        
        // Collect data based on step type
        var stepData: [String: Any]? = nil
        
        switch currentStep.type {
        case .apiSetup:
            stepData = [
                "apiKey": apiKey,
                "baseURL": baseURL
            ]
        case .preferences:
            stepData = [
                "theme": selectedPreferences.theme,
                "experienceLevel": selectedPreferences.experienceLevel.rawValue,
                "primaryUseCase": selectedPreferences.primaryUseCase,
                "preferredLanguages": selectedPreferences.preferredLanguages,
                "fontSize": selectedPreferences.fontSize
            ]
        default:
            break
        }
        
        // Complete current step
        onboardingService.completeCurrentStep(with: stepData)
        
        // Advance or complete
        if currentPage < onboardingService.steps.count - 1 {
            advanceToNextPage()
        } else {
            onboardingService.completeOnboarding()
            onComplete()
        }
    }
    
    private func advanceToNextPage() {
        withAnimation {
            currentPage += 1
        }
    }
}

// MARK: - Progress Bar

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps - 1)
    }
    
    var body: some View {
        VStack(spacing: Theme.spacing.sm) {
            // Step indicators
            HStack(spacing: Theme.spacing.xs) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Theme.primary : Theme.muted.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentStep ? 1.5 : 1.0)
                        .animation(.spring(), value: currentStep)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.muted.opacity(0.2))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.primary, Theme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.spring(), value: progress)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    @Binding var animateContent: Bool
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: Theme.spacing.xl) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .scaleEffect(animateIcon ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                        value: animateIcon
                    )
                
                Image(systemName: "terminal.fill")
                    .font(.system(size: 70))
                    .foregroundColor(Theme.primary)
                    .rotationEffect(.degrees(animateContent ? 0 : -10))
                    .scaleEffect(animateContent ? 1.0 : 0.8)
            }
            .onAppear { animateIcon = true }
            
            VStack(spacing: Theme.spacing.md) {
                Text("Welcome to Claude Code")
                    .font(Theme.typography.largeTitle)
                    .foregroundColor(Theme.foreground)
                    .opacity(animateContent ? 1.0 : 0)
                
                Text("Your AI-powered development companion")
                    .font(Theme.typography.title3)
                    .foregroundColor(Theme.secondaryForeground)
                    .multilineTextAlignment(.center)
                    .opacity(animateContent ? 1.0 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: animateContent)
                
                VStack(alignment: .leading, spacing: Theme.spacing.md) {
                    FeatureHighlight(
                        icon: "brain",
                        title: "AI-Powered Assistance",
                        description: "Get intelligent code suggestions and solutions"
                    )
                    
                    FeatureHighlight(
                        icon: "folder.fill.badge.plus",
                        title: "Project Management",
                        description: "Organize and manage all your projects"
                    )
                    
                    FeatureHighlight(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Performance Monitoring",
                        description: "Track and optimize your app's performance"
                    )
                }
                .padding(.top, Theme.spacing.lg)
                .opacity(animateContent ? 1.0 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: animateContent)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Permissions Step

struct PermissionsStepView: View {
    @StateObject private var onboardingService = OnboardingService.shared
    @State private var permissionStatuses: [OnboardingService.PermissionType: Bool] = [:]
    @State private var isRequestingPermission = false
    
    let permissions: [(OnboardingService.PermissionType, String, String, String)] = [
        (.notifications, "bell.fill", "Notifications", "Stay updated with important alerts"),
        (.biometrics, "faceid", "Biometric Auth", "Secure your app with Face ID"),
        (.camera, "camera.fill", "Camera", "Scan QR codes and capture images"),
        (.microphone, "mic.fill", "Microphone", "Enable voice commands"),
        (.photos, "photo.fill", "Photos", "Access and share images")
    ]
    
    var body: some View {
        VStack(spacing: Theme.spacing.xl) {
            VStack(spacing: Theme.spacing.md) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.primary)
                
                Text("Enable Features")
                    .font(Theme.typography.title)
                    .foregroundColor(Theme.foreground)
                
                Text("Grant permissions to unlock full functionality")
                    .font(Theme.typography.body)
                    .foregroundColor(Theme.secondaryForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Theme.spacing.xxl)
            
            ScrollView {
                VStack(spacing: Theme.spacing.md) {
                    ForEach(permissions, id: \.0) { permission, icon, title, description in
                        PermissionRow(
                            icon: icon,
                            title: title,
                            description: description,
                            isGranted: permissionStatuses[permission] ?? false,
                            isLoading: isRequestingPermission,
                            onRequest: {
                                Task {
                                    isRequestingPermission = true
                                    let granted = await onboardingService.requestPermission(permission)
                                    permissionStatuses[permission] = granted
                                    isRequestingPermission = false
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.vertical)
        .task {
            // Check initial permission statuses
            for (permission, _, _, _) in permissions {
                let status = await onboardingService.checkPermissionStatus(permission)
                permissionStatuses[permission] = status
            }
        }
    }
}

// MARK: - API Setup Step

struct APISetupStepView: View {
    @Binding var apiKey: String
    @Binding var baseURL: String
    @State private var isValidatingAPI = false
    @State private var validationResult: Bool?
    @State private var showAdvancedSettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing.xl) {
                VStack(spacing: Theme.spacing.md) {
                    Image(systemName: "network")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.primary)
                    
                    Text("API Configuration")
                        .font(Theme.typography.title)
                        .foregroundColor(Theme.foreground)
                    
                    Text("Connect to Claude API for AI assistance")
                        .font(Theme.typography.body)
                        .foregroundColor(Theme.secondaryForeground)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Theme.spacing.xxl)
                
                VStack(alignment: .leading, spacing: Theme.spacing.lg) {
                    // API Key input
                    VStack(alignment: .leading, spacing: Theme.spacing.sm) {
                        Label("API Key", systemImage: "key.fill")
                            .font(Theme.typography.caption)
                            .foregroundColor(Theme.secondaryForeground)
                        
                        SecureField("sk-ant-...", text: $apiKey)
                            .textFieldStyle(CyberpunkTextFieldStyle())
                        
                        if let isValid = validationResult {
                            HStack {
                                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isValid ? .green : .red)
                                Text(isValid ? "API key validated" : "Invalid API key")
                                    .font(Theme.typography.small)
                                    .foregroundColor(isValid ? .green : .red)
                            }
                        }
                    }
                    
                    // Advanced settings
                    DisclosureGroup(isExpanded: $showAdvancedSettings) {
                        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
                            Label("Base URL", systemImage: "link")
                                .font(Theme.typography.caption)
                                .foregroundColor(Theme.secondaryForeground)
                            
                            TextField("API Base URL", text: $baseURL)
                                .textFieldStyle(CyberpunkTextFieldStyle())
                            
                            Text("Only change if using a custom API endpoint")
                                .font(Theme.typography.small)
                                .foregroundColor(Theme.tertiaryForeground)
                        }
                        .padding(.top, Theme.spacing.md)
                    } label: {
                        Label("Advanced Settings", systemImage: "gearshape.fill")
                            .font(Theme.typography.body)
                            .foregroundColor(Theme.primary)
                    }
                    
                    // Validate button
                    CyberpunkButton(
                        title: "Validate API Key",
                        style: .secondary,
                        isLoading: isValidatingAPI
                    ) {
                        validateAPIKey()
                    }
                    .disabled(apiKey.isEmpty)
                    
                    // Help text
                    VStack(alignment: .leading, spacing: Theme.spacing.sm) {
                        Text("Where to get an API key:")
                            .font(Theme.typography.headline)
                            .foregroundColor(Theme.foreground)
                        
                        Link(destination: URL(string: "https://console.anthropic.com/")!) {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text("Visit Anthropic Console")
                            }
                            .font(Theme.typography.body)
                            .foregroundColor(Theme.primary)
                        }
                        
                        Text("You can also add or change this later in Settings")
                            .font(Theme.typography.small)
                            .foregroundColor(Theme.tertiaryForeground)
                    }
                    .padding()
                    .background(Theme.card)
                    .cornerRadius(Theme.radius.medium)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
    
    private func validateAPIKey() {
        isValidatingAPI = true
        
        Task {
            // Simulate API validation
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            await MainActor.run {
                validationResult = !apiKey.isEmpty && apiKey.hasPrefix("sk-")
                isValidatingAPI = false
            }
        }
    }
}

// MARK: - Preferences Step

struct PreferencesStepView: View {
    @Binding var preferences: UserPreferences
    @State private var selectedLanguages: Set<String> = []
    
    let experienceLevels = UserPreferences.ExperienceLevel.allCases
    let useCases = [
        "Mobile Development",
        "Web Development",
        "Data Science",
        "Machine Learning",
        "DevOps",
        "System Administration",
        "Other"
    ]
    let programmingLanguages = [
        "Swift", "Python", "JavaScript", "TypeScript",
        "Go", "Rust", "Java", "C++", "Ruby", "PHP"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing.xl) {
                VStack(spacing: Theme.spacing.md) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.primary)
                    
                    Text("Personalize Your Experience")
                        .font(Theme.typography.title)
                        .foregroundColor(Theme.foreground)
                    
                    Text("Help us tailor Claude Code to your needs")
                        .font(Theme.typography.body)
                        .foregroundColor(Theme.secondaryForeground)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Theme.spacing.xxl)
                
                VStack(alignment: .leading, spacing: Theme.spacing.xl) {
                    // Experience level
                    VStack(alignment: .leading, spacing: Theme.spacing.md) {
                        Text("Experience Level")
                            .font(Theme.typography.headline)
                            .foregroundColor(Theme.foreground)
                        
                        ForEach(experienceLevels, id: \.self) { level in
                            ExperienceLevelCard(
                                level: level,
                                isSelected: preferences.experienceLevel == level,
                                onTap: {
                                    preferences.experienceLevel = level
                                }
                            )
                        }
                    }
                    
                    // Primary use case
                    VStack(alignment: .leading, spacing: Theme.spacing.md) {
                        Text("Primary Use Case")
                            .font(Theme.typography.headline)
                            .foregroundColor(Theme.foreground)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.spacing.sm) {
                                ForEach(useCases, id: \.self) { useCase in
                                    UseCaseChip(
                                        title: useCase,
                                        isSelected: preferences.primaryUseCase == useCase,
                                        onTap: {
                                            preferences.primaryUseCase = useCase
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    // Preferred languages
                    VStack(alignment: .leading, spacing: Theme.spacing.md) {
                        Text("Preferred Languages")
                            .font(Theme.typography.headline)
                            .foregroundColor(Theme.foreground)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: Theme.spacing.md) {
                            ForEach(programmingLanguages, id: \.self) { language in
                                LanguageToggle(
                                    language: language,
                                    isSelected: selectedLanguages.contains(language),
                                    onToggle: {
                                        if selectedLanguages.contains(language) {
                                            selectedLanguages.remove(language)
                                        } else {
                                            selectedLanguages.insert(language)
                                        }
                                        preferences.preferredLanguages = Array(selectedLanguages)
                                    }
                                )
                            }
                        }
                    }
                    
                    // Additional preferences
                    VStack(alignment: .leading, spacing: Theme.spacing.md) {
                        Text("Additional Settings")
                            .font(Theme.typography.headline)
                            .foregroundColor(Theme.foreground)
                        
                        Toggle("Enable Analytics", isOn: $preferences.enableAnalytics)
                        Toggle("Show Tips & Hints", isOn: $preferences.showTips)
                        Toggle("Auto-Save Projects", isOn: $preferences.autoSave)
                        Toggle("Keyboard Haptics", isOn: $preferences.keyboardHaptics)
                    }
                    .toggleStyle(CyberpunkToggleStyle())
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
}

// MARK: - Tutorial Step

struct TutorialStepView: View {
    @State private var currentTutorial = 0
    
    let tutorials = [
        ("message.fill", "Chat with Claude", "Ask questions and get AI-powered coding assistance"),
        ("folder.fill", "Manage Projects", "Organize your code projects and access them quickly"),
        ("terminal.fill", "Terminal Access", "Run commands and scripts directly from the app"),
        ("chart.line.uptrend.xyaxis", "Monitor Performance", "Track your app's performance metrics in real-time")
    ]
    
    var body: some View {
        VStack(spacing: Theme.spacing.xl) {
            VStack(spacing: Theme.spacing.md) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.primary)
                
                Text("Quick Tutorial")
                    .font(Theme.typography.title)
                    .foregroundColor(Theme.foreground)
                
                Text("Learn the basics in 2 minutes")
                    .font(Theme.typography.body)
                    .foregroundColor(Theme.secondaryForeground)
            }
            .padding(.top, Theme.spacing.xxl)
            
            TabView(selection: $currentTutorial) {
                ForEach(Array(tutorials.enumerated()), id: \.offset) { index, tutorial in
                    TutorialCard(
                        icon: tutorial.0,
                        title: tutorial.1,
                        description: tutorial.2
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .frame(height: 300)
            
            // Interactive demo button
            CyberpunkButton(
                title: "Try Interactive Demo",
                style: .secondary
            ) {
                // Launch interactive demo
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Completion Step

struct CompletionStepView: View {
    let onComplete: () -> Void
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: Theme.spacing.xl) {
            Spacer()
            
            // Success animation
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .scaleEffect(animate ? 1.2 : 1.0)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Theme.primary)
                    .scaleEffect(animate ? 1.0 : 0.5)
                    .rotationEffect(.degrees(animate ? 0 : -45))
            }
            .onAppear {
                withAnimation(.spring()) {
                    animate = true
                }
            }
            
            VStack(spacing: Theme.spacing.md) {
                Text("You're All Set!")
                    .font(Theme.typography.largeTitle)
                    .foregroundColor(Theme.foreground)
                
                Text("Start building amazing things with Claude Code")
                    .font(Theme.typography.body)
                    .foregroundColor(Theme.secondaryForeground)
                    .multilineTextAlignment(.center)
            }
            
            // Quick actions
            VStack(spacing: Theme.spacing.md) {
                QuickActionCard(
                    icon: "plus.circle.fill",
                    title: "Create Your First Project",
                    color: Theme.primary
                )
                
                QuickActionCard(
                    icon: "message.fill",
                    title: "Start a Chat with Claude",
                    color: Theme.secondary
                )
                
                QuickActionCard(
                    icon: "book.fill",
                    title: "Browse Documentation",
                    color: Theme.accent
                )
            }
            .padding(.top, Theme.spacing.xl)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Supporting Views

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: Theme.spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.primary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: Theme.spacing.xs) {
                Text(title)
                    .font(Theme.typography.headline)
                    .foregroundColor(Theme.foreground)
                
                Text(description)
                    .font(Theme.typography.small)
                    .foregroundColor(Theme.secondaryForeground)
            }
            
            Spacer()
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let isLoading: Bool
    let onRequest: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isGranted ? .green : Theme.primary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: Theme.spacing.xs) {
                Text(title)
                    .font(Theme.typography.headline)
                    .foregroundColor(Theme.foreground)
                
                Text(description)
                    .font(Theme.typography.small)
                    .foregroundColor(Theme.secondaryForeground)
            }
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Enable") {
                    onRequest()
                }
                .font(Theme.typography.caption)
                .padding(.horizontal, Theme.spacing.sm)
                .padding(.vertical, Theme.spacing.xs)
                .background(Theme.primary)
                .foregroundColor(Theme.background)
                .cornerRadius(Theme.radius.small)
                .disabled(isLoading)
            }
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(Theme.radius.medium)
    }
}

struct ExperienceLevelCard: View {
    let level: UserPreferences.ExperienceLevel
    let isSelected: Bool
    let onTap: () -> Void
    
    var description: String {
        switch level {
        case .beginner:
            return "New to development"
        case .intermediate:
            return "Some coding experience"
        case .advanced:
            return "Professional developer"
        case .expert:
            return "Senior developer"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.spacing.xs) {
                    Text(level.rawValue)
                        .font(Theme.typography.headline)
                        .foregroundColor(Theme.foreground)
                    
                    Text(description)
                        .font(Theme.typography.small)
                        .foregroundColor(Theme.secondaryForeground)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.primary)
                }
            }
            .padding()
            .background(isSelected ? Theme.primary.opacity(0.1) : Theme.card)
            .cornerRadius(Theme.radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius.medium)
                    .stroke(isSelected ? Theme.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UseCaseChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(Theme.typography.body)
                .padding(.horizontal, Theme.spacing.md)
                .padding(.vertical, Theme.spacing.sm)
                .background(isSelected ? Theme.primary : Theme.card)
                .foregroundColor(isSelected ? Theme.background : Theme.foreground)
                .cornerRadius(Theme.radius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius.small)
                        .stroke(Theme.primary, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LanguageToggle: View {
    let language: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text(language)
                    .font(Theme.typography.body)
                    .foregroundColor(Theme.foreground)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? Theme.primary : Theme.muted)
            }
            .padding()
            .background(Theme.card)
            .cornerRadius(Theme.radius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TutorialCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: Theme.spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(Theme.primary)
            
            VStack(spacing: Theme.spacing.sm) {
                Text(title)
                    .font(Theme.typography.title2)
                    .foregroundColor(Theme.foreground)
                
                Text(description)
                    .font(Theme.typography.body)
                    .foregroundColor(Theme.secondaryForeground)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(Theme.radius.large)
        .padding(.horizontal)
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(Theme.typography.body)
                .foregroundColor(Theme.foreground)
            
            Spacer()
            
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(Theme.muted)
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(Theme.radius.medium)
    }
}