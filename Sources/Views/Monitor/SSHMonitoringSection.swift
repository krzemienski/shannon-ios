// MVP: Simplified SSH monitoring section to avoid compilation errors
import SwiftUI

struct SSHMonitoringSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SSH Monitoring")
                .font(.headline)
                .foregroundColor(Theme.primary)
            
            Text("MVP: SSH monitoring coming soon")
                .font(.caption)
                .foregroundColor(Theme.mutedForeground)
            
            Spacer()
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(12)
    }
}