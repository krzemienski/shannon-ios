// MVP: Simplified environment variables view to avoid compilation errors
import SwiftUI

public struct EnvironmentVariablesView: View {
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Environment Variables")
                .font(.headline)
                .foregroundColor(Theme.primary)
            
            Text("MVP: Environment variables management coming soon")
                .font(.caption)
                .foregroundColor(Theme.mutedForeground)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}