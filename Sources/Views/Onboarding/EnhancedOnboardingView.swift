// MVP: Simplified enhanced onboarding view to avoid compilation errors
import SwiftUI

public struct EnhancedOnboardingView: View {
    @Binding var showOnboarding: Bool
    
    public init(showOnboarding: Binding<Bool>) {
        self._showOnboarding = showOnboarding
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to ClaudeCode")
                .font(.largeTitle)
                .foregroundColor(Theme.primary)
            
            Text("Enhanced Features")
                .font(.title2)
                .foregroundColor(Theme.mutedForeground)
            
            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "message.fill", text: "AI-Powered Chat")
                FeatureRow(icon: "folder.fill", text: "Project Management")
                FeatureRow(icon: "terminal.fill", text: "SSH Terminal")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Performance Monitoring")
            }
            .padding()
            
            Button("Continue") {
                showOnboarding = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Theme.accent)
                .frame(width: 30)
            Text(text)
                .foregroundColor(Theme.foreground)
        }
    }
}