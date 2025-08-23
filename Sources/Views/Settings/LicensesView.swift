//
//  LicensesView.swift
//  ClaudeCode
//
//  Open source licenses view
//

import SwiftUI

struct LicensesView: View {
    let licenses = [
        License(name: "SwiftUI", type: "MIT", copyright: "© Apple Inc."),
        License(name: "Citadel", type: "MIT", copyright: "© Citadel Contributors"),
        License(name: "swift-collections", type: "Apache 2.0", copyright: "© Apple Inc."),
        License(name: "Combine", type: "MIT", copyright: "© Apple Inc.")
    ]
    
    var body: some View {
        List(licenses) { license in
            VStack(alignment: .leading, spacing: 8) {
                Text(license.name)
                    .font(.headline)
                
                HStack {
                    Text(license.type)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.primary.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(license.copyright)
                        .font(.caption)
                        .foregroundColor(Theme.mutedForeground)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Open Source Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct License: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let copyright: String
}