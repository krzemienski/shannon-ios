// MVP: Simplified performance section to avoid compilation errors
import SwiftUI

public struct PerformanceSection: View {
    @ObservedObject var tracker: PerformanceTracker
    
    public init(tracker: PerformanceTracker) {
        self.tracker = tracker
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
                .foregroundColor(Theme.primary)
            
            HStack {
                Text("Overall Score:")
                    .foregroundColor(Theme.muted)
                Text("\(Int(tracker.overallScore))%")
                    .foregroundColor(Theme.accent)
                    .font(.system(size: 24, weight: .bold))
            }
            
            Text("MVP: Detailed metrics coming soon")
                .font(.caption)
                .foregroundColor(Theme.muted)
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(12)
    }
}