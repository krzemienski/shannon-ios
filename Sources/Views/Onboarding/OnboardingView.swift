// MVP: Simplified onboarding view to avoid compilation errors
import SwiftUI

public struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    
    public init(showOnboarding: Binding<Bool>) {
        self._showOnboarding = showOnboarding
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to ClaudeCode")
                .font(.largeTitle)
                .foregroundColor(Theme.primary)
            
            Text("MVP Build")
                .font(.title2)
                .foregroundColor(Theme.mutedForeground)
            
            Button("Get Started") {
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