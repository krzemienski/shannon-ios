//
//  EnvironmentVariablesView.swift
//  ClaudeCode
//
//  Environment variables configuration view
//

import SwiftUI

struct EnvironmentVariablesView: View {
    let projectId: String
    @EnvironmentObject var coordinator: ProjectsCoordinator
    @State private var variables: [(String, String)] = []
    @State private var newKey = ""
    @State private var newValue = ""
    
    var body: some View {
        VStack {
            List {
                Section("Environment Variables") {
                    ForEach(variables.indices, id: \.self) { index in
                        HStack {
                            Text(variables[index].0)
                                .font(Theme.caption)
                                .foregroundColor(Theme.primary)
                            
                            Spacer()
                            
                            Text(variables[index].1)
                                .font(Theme.caption)
                                .foregroundColor(Theme.mutedForeground)
                        }
                    }
                    .onDelete { indexSet in
                        variables.remove(atOffsets: indexSet)
                    }
                }
                
                Section("Add Variable") {
                    HStack {
                        TextField("Key", text: $newKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Value", text: $newValue)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Add") {
                            if !newKey.isEmpty && !newValue.isEmpty {
                                variables.append((newKey, newValue))
                                newKey = ""
                                newValue = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .navigationTitle("Environment Variables")
        .navigationBarTitleDisplayMode(.inline)
    }
}