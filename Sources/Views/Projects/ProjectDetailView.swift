// MVP: Simplified project detail view to avoid compilation errors
import SwiftUI

public struct ProjectDetailView: View {
    let project: Project
    
    public init(project: Project) {
        self.project = project
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.name)
                        .font(.largeTitle)
                        .foregroundColor(Theme.primary)
                    
                    if let description = project.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(Theme.mutedForeground)
                    }
                    
                    HStack {
                        Label("Created: \(project.createdAt.formatted())", systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(Theme.mutedForeground)
                    }
                }
                .padding()
                .background(Theme.card)
                .cornerRadius(12)
                
                // Stats
                HStack(spacing: 16) {
                    ProjectStatCard(title: "Files", value: "0")
                    ProjectStatCard(title: "Size", value: "0 KB")
                }
                
                Text("MVP: Full project details coming soon")
                    .font(.caption)
                    .foregroundColor(Theme.mutedForeground)
                    .padding()
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.background)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

private struct ProjectStatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.mutedForeground)
            Text(value)
                .font(.title2)
                .foregroundColor(Theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.card)
        .cornerRadius(8)
    }
}