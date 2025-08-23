//
//  TerminalView.swift
//  ClaudeCode
//
//  Terminal view for SSH connections
//

import SwiftUI

struct TerminalView: View {
    let projectId: String
    @EnvironmentObject var coordinator: ProjectsCoordinator
    @State private var terminalOutput = "$ "
    @State private var currentCommand = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    Text(terminalOutput)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Theme.foreground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("bottom")
                }
                .background(Color.black.opacity(0.9))
                .onChange(of: terminalOutput) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            // Command input
            HStack {
                Text("$")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Theme.primary)
                
                TextField("Enter command", text: $currentCommand)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Theme.foreground)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isInputFocused)
                    .onSubmit {
                        executeCommand()
                    }
            }
            .padding()
            .background(Theme.card)
        }
        .navigationTitle("Terminal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isInputFocused = true
            connectToProject()
        }
    }
    
    private func executeCommand() {
        guard !currentCommand.isEmpty else { return }
        
        terminalOutput += "\n$ \(currentCommand)\n"
        
        // TODO: Send command to SSH connection
        terminalOutput += "Command execution not yet implemented\n"
        
        currentCommand = ""
    }
    
    private func connectToProject() {
        terminalOutput = "Connecting to project \(projectId)...\n"
        terminalOutput += "SSH connection not yet implemented\n$ "
    }
}