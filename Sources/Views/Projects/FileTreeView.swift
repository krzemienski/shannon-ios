// MVP: Simplified file tree view to avoid compilation errors
import SwiftUI

public struct FileTreeView: View {
    let project: Project
    
    public init(project: Project) {
        self.project = project
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("File Tree")
                .font(.headline)
                .foregroundColor(Theme.primary)
            
            Text("Project: \(project.name)")
                .font(.subheadline)
                .foregroundColor(Theme.mutedForeground)
            
            Text("MVP: File tree navigation coming soon")
                .font(.caption)
                .foregroundColor(Theme.mutedForeground)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}