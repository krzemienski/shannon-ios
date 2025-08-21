//
//  OnboardingView.swift
//  ClaudeCode
//
//  Onboarding flow for new users
//

import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    
    var body: some View {
        TabView(selection: $currentPage) {
            WelcomeView()
                .tag(0)
            
            FeaturesView()
                .tag(1)
            
            SetupView(onComplete: onComplete)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Theme.background)
    }
}

private struct WelcomeView: View {
    var body: some View {
        VStack(spacing: Theme.spacing.xl) {
            Spacer()
            
            Image(systemName: "terminal.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.primary)
                .padding()
                .background(
                    Circle()
                        .fill(Theme.primary.opacity(0.1))
                )
            
            VStack(spacing: Theme.spacing.md) {
                Text("Welcome to Claude Code")
                    .font(Theme.typography.largeTitle)
                    .foregroundColor(Theme.foreground)
                
                Text("Your AI-powered development companion")
                    .font(Theme.typography.body)
                    .foregroundColor(Theme.secondaryForeground)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
}

private struct FeaturesView: View {
    var body: some View {
        VStack(spacing: Theme.spacing.xl) {
            Text("Key Features")
                .font(Theme.typography.title)
                .foregroundColor(Theme.foreground)
                .padding(.top, Theme.spacing.xxl)
            
            VStack(spacing: Theme.spacing.lg) {
                FeatureRow(
                    icon: "message.fill",
                    title: "AI Chat",
                    description: "Interactive coding assistance with Claude"
                )
                
                FeatureRow(
                    icon: "folder.fill",
                    title: "Project Management",
                    description: "Organize and manage your development projects"
                )
                
                FeatureRow(
                    icon: "wrench.and.screwdriver.fill",
                    title: "Developer Tools",
                    description: "Access powerful tools and utilities"
                )
                
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "System Monitoring",
                    description: "Track performance and system metrics"
                )
            }
            
            Spacer()
        }
        .padding()
    }
}

private struct SetupView: View {
    let onComplete: () -> Void
    @State private var apiKey = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: Theme.spacing.xl) {
            Text("Let's Get Started")
                .font(Theme.typography.title)
                .foregroundColor(Theme.foreground)
                .padding(.top, Theme.spacing.xxl)
            
            VStack(alignment: .leading, spacing: Theme.spacing.md) {
                Text("API Key")
                    .font(Theme.typography.caption)
                    .foregroundColor(Theme.secondaryForeground)
                
                SecureField("Enter your Claude API key", text: $apiKey)
                    .textFieldStyle(CyberpunkTextFieldStyle())
                
                Text("You can add or change this later in Settings")
                    .font(Theme.typography.small)
                    .foregroundColor(Theme.tertiaryForeground)
            }
            
            Spacer()
            
            CyberpunkButton(
                title: "Complete Setup",
                style: .primary,
                isLoading: isLoading
            ) {
                completeSetup()
            }
            .disabled(apiKey.isEmpty)
            
            Button("Skip for now") {
                onComplete()
            }
            .font(Theme.typography.caption)
            .foregroundColor(Theme.primary)
            .padding(.bottom, Theme.spacing.xl)
        }
        .padding()
    }
    
    private func completeSetup() {
        isLoading = true
        
        Task {
            // Save API key
            if !apiKey.isEmpty {
                await DependencyContainer.shared.settingsStore.updateAPIConfiguration(
                    apiKey: apiKey,
                    baseURL: nil
                )
            }
            
            await MainActor.run {
                isLoading = false
                onComplete()
            }
        }
    }
}

private struct FeatureRow: View {
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