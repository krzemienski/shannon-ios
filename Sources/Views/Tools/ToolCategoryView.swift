//
//  ToolCategoryView.swift
//  ClaudeCode
//
//  Tool category view placeholder
//

import SwiftUI

struct ToolCategoryView: View {
    let category: String
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Tool Category")
                    .font(.largeTitle)
                    .padding()
                
                Text("Category: \(category)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Tools for '\(category)' category coming soon...")
                    .foregroundColor(.secondary)
                    .italic()
                
                Spacer()
            }
            .navigationTitle(category)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ToolCategoryView(category: "Development")
        .environmentObject(AppCoordinator())
}