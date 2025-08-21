//
//  ContentView.swift
//  ClaudeCode
//
//  Main content view - temporary placeholder
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "brain.head.profile")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Claude Code iOS")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("AI Development Assistant")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}