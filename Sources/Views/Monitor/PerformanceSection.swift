// MVP: Simplified performance section to avoid compilation errors
import SwiftUI

struct PerformanceSection: View {
    @ObservedObject var tracker: PerformanceTracker
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
                .foregroundColor(Theme.primary)
            
            HStack {
                Text("Overall Score:")
                    .foregroundColor(Theme.mutedForeground)
                Text("\(Int(tracker.overallScore))%")
                    .foregroundColor(Theme.accent)
                    .font(.system(size: 24, weight: .bold))
            }
            
            Text("MVP: Detailed metrics coming soon")
                .font(.caption)
                .foregroundColor(Theme.mutedForeground)
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(12)
    }
}