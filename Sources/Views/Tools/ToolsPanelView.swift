//
//  ToolsPanelView.swift
//  ClaudeCode
//
//  Tools panel with categories and search
//

import SwiftUI

// MARK: - Tools Panel View

struct ToolsPanelView: View {
    let tools: [String]
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var selectedTool: PanelToolInfo?
    @Environment(\.dismiss) private var dismiss
    
    let categories = ["All", "File", "System", "Network", "Search", "Analysis"]
    
    // Mock tool data
    let toolInfos: [PanelToolInfo] = [
        PanelToolInfo(
            name: "Read File",
            category: "File",
            icon: "doc.text",
            description: "Read the contents of a file",
            usage: "read(path: String)",
            examples: ["read('/path/to/file.txt')", "read('README.md')"],
            lastUsed: Date().addingTimeInterval(-300)
        ),
        PanelToolInfo(
            name: "Write File",
            category: "File",
            icon: "square.and.pencil",
            description: "Write content to a file",
            usage: "write(path: String, content: String)",
            examples: ["write('output.txt', 'Hello World')", "write('config.json', jsonContent)"],
            lastUsed: Date().addingTimeInterval(-600)
        ),
        PanelToolInfo(
            name: "Execute Command",
            category: "System",
            icon: "terminal",
            description: "Execute shell commands",
            usage: "execute(command: String)",
            examples: ["execute('ls -la')", "execute('git status')"],
            lastUsed: Date().addingTimeInterval(-1200)
        ),
        PanelToolInfo(
            name: "Search Files",
            category: "Search",
            icon: "magnifyingglass",
            description: "Search for files by pattern",
            usage: "search(pattern: String, path: String?)",
            examples: ["search('*.swift')", "search('TODO', recursive: true)"],
            lastUsed: nil
        ),
        PanelToolInfo(
            name: "Analyze Code",
            category: "Analysis",
            icon: "chart.bar",
            description: "Analyze code structure and metrics",
            usage: "analyze(path: String, options: AnalysisOptions?)",
            examples: ["analyze('src/')", "analyze('main.swift', metrics: true)"],
            lastUsed: Date().addingTimeInterval(-7200)
        ),
        PanelToolInfo(
            name: "HTTP Request",
            category: "Network",
            icon: "network",
            description: "Make HTTP requests",
            usage: "http(method: String, url: String, body: Any?)",
            examples: ["http('GET', 'https://api.example.com')", "http('POST', url, json: data)"],
            lastUsed: Date().addingTimeInterval(-3600)
        )
    ]
    
    var filteredTools: [PanelToolInfo] {
        let categoryFiltered = selectedCategory == "All" 
            ? toolInfos 
            : toolInfos.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered
        }
        
        return categoryFiltered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    SearchField(
                        text: $searchText,
                        placeholder: "Search tools..."
                    )
                    .padding(.horizontal)
                    .padding(.top, ThemeSpacing.sm)
                    
                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ThemeSpacing.sm) {
                            ForEach(categories, id: \.self) { category in
                                PanelCategoryChip(
                                    title: category,
                                    isSelected: selectedCategory == category,
                                    count: countForCategory(category)
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, ThemeSpacing.sm)
                    }
                    
                    // Tools grid
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: ThemeSpacing.md
                        ) {
                            ForEach(filteredTools) { tool in
                                PanelToolCard(tool: tool) {
                                    selectedTool = tool
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Available Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .tint(Theme.primary)
                }
            }
        }
        .sheet(item: $selectedTool) { tool in
            ToolDetailView(tool: tool)
        }
    }
    
    private func countForCategory(_ category: String) -> Int {
        if category == "All" {
            return toolInfos.count
        }
        return toolInfos.filter { $0.category == category }.count
    }
}

// MARK: - Category Chip

struct PanelCategoryChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ThemeSpacing.xs) {
                Text(title)
                    .font(Theme.Typography.captionFont)
                
                Text("\(count)")
                    .font(Theme.Typography.caption2Font)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        isSelected ? Theme.background : Theme.primary.opacity(0.1)
                    )
                    .cornerRadius(Theme.Radius.xs)
            }
            .foregroundColor(isSelected ? Theme.background : Theme.foreground)
            .padding(.horizontal, ThemeSpacing.md)
            .padding(.vertical, ThemeSpacing.xs)
            .background(isSelected ? Theme.primary : Theme.card)
            .cornerRadius(Theme.Radius.round)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.round)
                    .stroke(isSelected ? Color.clear : Theme.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Tool Card

struct PanelToolCard: View {
    let tool: PanelToolInfo
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                // Header
                HStack {
                    Image(systemName: tool.icon)
                        .font(.system(size: 24))
                        .foregroundColor(Theme.primary)
                        .frame(width: 40, height: 40)
                        .background(Theme.primary.opacity(0.1))
                        .cornerRadius(Theme.Radius.sm)
                    
                    Spacer()
                    
                    if tool.lastUsed != nil {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.mutedForeground)
                    }
                }
                
                // Title
                Text(tool.name)
                    .font(Theme.Typography.headlineFont)
                    .foregroundColor(Theme.foreground)
                    .lineLimit(1)
                
                // Description
                Text(tool.description)
                    .font(Theme.Typography.captionFont)
                    .foregroundColor(Theme.mutedForeground)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Footer
                HStack {
                    Text(tool.category)
                        .font(Theme.Typography.caption2Font)
                        .foregroundColor(Theme.primary)
                        .padding(.horizontal, ThemeSpacing.xs)
                        .padding(.vertical, 2)
                        .background(Theme.primary.opacity(0.1))
                        .cornerRadius(Theme.Radius.xs)
                    
                    Spacer()
                    
                    if let lastUsed = tool.lastUsed {
                        Text(formattedTime(lastUsed))
                            .font(Theme.Typography.caption2Font)
                            .foregroundColor(Theme.mutedForeground)
                    }
                }
            }
            .padding(ThemeSpacing.md)
            .frame(height: 160)
            .background(Theme.card)
            .cornerRadius(Theme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Tool Detail View

struct ToolDetailView: View {
    let tool: PanelToolInfo
    @Environment(\.dismiss) private var dismiss
    @State private var copiedExample: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: ThemeSpacing.lg) {
                        // Icon and title
                        HStack(spacing: ThemeSpacing.md) {
                            Image(systemName: tool.icon)
                                .font(.system(size: 32))
                                .foregroundColor(Theme.primary)
                                .frame(width: 60, height: 60)
                                .background(Theme.primary.opacity(0.1))
                                .cornerRadius(Theme.Radius.md)
                            
                            VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                                Text(tool.name)
                                    .font(Theme.Typography.title2Font)
                                    .foregroundColor(Theme.foreground)
                                
                                HStack(spacing: ThemeSpacing.sm) {
                                    Text(tool.category)
                                        .font(Theme.Typography.captionFont)
                                        .foregroundColor(Theme.primary)
                                        .padding(.horizontal, ThemeSpacing.sm)
                                        .padding(.vertical, 2)
                                        .background(Theme.primary.opacity(0.1))
                                        .cornerRadius(Theme.Radius.xs)
                                    
                                    if let lastUsed = tool.lastUsed {
                                        Text("Used \(formattedTime(lastUsed))")
                                            .font(Theme.Typography.captionFont)
                                            .foregroundColor(Theme.mutedForeground)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                            Text("Description")
                                .font(Theme.Typography.headlineFont)
                                .foregroundColor(Theme.foreground)
                            
                            Text(tool.description)
                                .font(Theme.Typography.bodyFont)
                                .foregroundColor(Theme.mutedForeground)
                        }
                        
                        // Usage
                        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                            Text("Usage")
                                .font(Theme.Typography.headlineFont)
                                .foregroundColor(Theme.foreground)
                            
                            CodeBlock(text: tool.usage)
                        }
                        
                        // Examples
                        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                            Text("Examples")
                                .font(Theme.Typography.headlineFont)
                                .foregroundColor(Theme.foreground)
                            
                            ForEach(tool.examples, id: \.self) { example in
                                HStack {
                                    CodeBlock(text: example)
                                        .onTapGesture {
                                            copyToClipboard(example)
                                        }
                                    
                                    if copiedExample == example {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(Theme.success)
                                            .transition(.scale)
                                    }
                                }
                            }
                        }
                        
                        // Statistics
                        if tool.lastUsed != nil {
                            VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                                Text("Statistics")
                                    .font(Theme.Typography.headlineFont)
                                    .foregroundColor(Theme.foreground)
                                
                                HStack(spacing: ThemeSpacing.md) {
                                    ToolStatCard(
                                        title: "Total Uses",
                                        value: "42",
                                        icon: "number"
                                    )
                                    
                                    ToolStatCard(
                                        title: "Avg Time",
                                        value: "127ms",
                                        icon: "timer"
                                    )
                                    
                                    ToolStatCard(
                                        title: "Success Rate",
                                        value: "98%",
                                        icon: "checkmark.circle"
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tool Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .tint(Theme.primary)
                }
            }
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        withAnimation {
            copiedExample = text
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedExample = nil
            }
        }
        
        Theme.Haptics.notification(.success)
    }
}

// MARK: - Code Block

struct CodeBlock: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(Theme.Typography.codeFont)
            .foregroundColor(Theme.foreground)
            .padding(ThemeSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.codeBackground)
            .cornerRadius(Theme.Radius.sm)
    }
}

// MARK: - Stat Card

struct ToolStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: ThemeSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.primary)
            
            Text(value)
                .font(Theme.Typography.headlineFont)
                .foregroundColor(Theme.foreground)
            
            Text(title)
                .font(Theme.Typography.caption2Font)
                .foregroundColor(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(ThemeSpacing.sm)
        .background(Theme.card)
        .cornerRadius(Theme.Radius.sm)
    }
}

// Note: PanelToolInfo is now defined in Models/ViewModels.swift

// MARK: - Preview

struct ToolsPanelView_Previews: PreviewProvider {
    static var previews: some View {
        ToolsPanelView(tools: ["Read", "Write", "Execute", "Search"])
            .preferredColorScheme(.dark)
    }
}