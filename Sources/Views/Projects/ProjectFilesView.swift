// MVP: Simplified project files view to avoid compilation errors
import SwiftUI

public struct ProjectFilesView: View {
    let project: Project
    
    public init(project: Project) {
        self.project = project
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Files")
                .font(.headline)
                .foregroundColor(Theme.primary)
            
            Text("Project: \(project.name)")
                .font(.subheadline)
                .foregroundColor(Theme.mutedForeground)
            
            Text("Total Files: 0")
                .font(.caption)
                .foregroundColor(Theme.mutedForeground)
            
            Text("MVP: File browser coming soon")
                .font(.caption)
                .foregroundColor(Theme.mutedForeground)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Files")
        .navigationBarTitleDisplayMode(.inline)
    }
}