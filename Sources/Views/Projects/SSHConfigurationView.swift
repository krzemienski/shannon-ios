//
//  SSHConfigurationView.swift
//  ClaudeCode
//
//  SSH configuration view for projects
//

import SwiftUI

struct SSHConfigurationView: View {
    let projectId: String
    @EnvironmentObject var coordinator: ProjectsCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var hostname = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var useKeyAuth = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Hostname", text: $hostname)
                        .textContentType(.URL)
                    
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                }
                
                Section("Authentication") {
                    Toggle("Use SSH Key", isOn: $useKeyAuth)
                    
                    if useKeyAuth {
                        Button("Select SSH Key") {
                            // TODO: Implement key selection
                        }
                    } else {
                        SecureField("Password", text: .constant(""))
                    }
                }
            }
            .navigationTitle("SSH Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Save configuration
                        dismiss()
                    }
                }
            }
        }
    }
}