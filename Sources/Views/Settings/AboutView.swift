//
//  AboutView.swift
//  ClaudeCode
//
//  About screen showing app information and credits
//

import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Icon and Title
                VStack(spacing: 16) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.primary, Theme.primary.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Claude Code")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Description
                VStack(spacing: 12) {
                    Text("AI-Powered Development Assistant")
                        .font(.headline)
                    
                    Text("Claude Code brings the power of Claude AI to iOS, enabling intelligent code assistance, project management, and development tools on the go.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                // Features
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Intelligent Code Completion", systemImage: "brain")
                        Label("Project Management", systemImage: "folder.fill")
                        Label("SSH & Terminal Support", systemImage: "terminal")
                        Label("Real-time Monitoring", systemImage: "chart.line.uptrend.xyaxis")
                        Label("Tool Integration", systemImage: "wrench.and.screwdriver")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                
                // Links
                VStack(spacing: 16) {
                    Button(action: { openURL(URL(string: "https://claude.ai")!) }) {
                        Label("Visit Claude AI", systemImage: "globe")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                    
                    HStack(spacing: 20) {
                        Button(action: { openURL(URL(string: "https://github.com/anthropic-ai")!) }) {
                            Image(systemName: "link")
                            Text("GitHub")
                        }
                        
                        Button(action: { openURL(URL(string: "https://docs.anthropic.com")!) }) {
                            Image(systemName: "book")
                            Text("Documentation")
                        }
                    }
                    .font(.callout)
                }
                
                // Credits
                GroupBox {
                    VStack(spacing: 12) {
                        Text("Built with ❤️ by the Claude Code Team")
                            .font(.caption)
                        
                        Text("Powered by Anthropic's Claude AI")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                
                // Legal
                VStack(spacing: 8) {
                    Button("Privacy Policy") {
                        openURL(URL(string: "https://anthropic.com/privacy")!)
                    }
                    
                    Button("Terms of Service") {
                        openURL(URL(string: "https://anthropic.com/terms")!)
                    }
                    
                    Text("© 2024 Anthropic. All rights reserved.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
}