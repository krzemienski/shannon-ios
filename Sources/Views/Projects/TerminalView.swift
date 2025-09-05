// MVP: Simplified terminal view to avoid compilation errors
import SwiftUI

struct TerminalView: View {
    let projectId: String?
    @EnvironmentObject var coordinator: ProjectsCoordinator
    @State private var showConnectionSheet = false
    
    init(projectId: String? = nil) {
        self.projectId = projectId
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Terminal placeholder
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("$ ssh user@server")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Theme.primary)
                    
                    Text("MVP: Terminal functionality coming soon")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Theme.mutedForeground)
                    
                    Text("$ _")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Theme.primary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.opacity(0.9))
            .cornerRadius(12)
            
            // Connect button
            Button {
                showConnectionSheet = true
            } label: {
                Label("New Connection", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .navigationTitle("Terminal")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showConnectionSheet) {
            Text("SSH Connection Setup")
                .font(.largeTitle)
                .padding()
        }
    }
}