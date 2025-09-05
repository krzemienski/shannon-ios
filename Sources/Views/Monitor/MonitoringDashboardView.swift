// MVP: Simplified monitoring dashboard to avoid compilation errors
import SwiftUI

public struct MonitoringDashboardView: View {
    public init() {}
    
    public var body: some View {
        VStack {
            Text("Monitoring Dashboard")
                .font(.largeTitle)
                .foregroundColor(Theme.primary)
            
            Text("MVP: Coming Soon")
                .foregroundColor(Theme.muted)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}