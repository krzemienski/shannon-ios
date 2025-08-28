//
//  ToolsView.swift
//  ClaudeCode
//
//  MCP tools configuration and management
//

import SwiftUI

struct ToolsView: View {
    @State private var tools: [MCPTool] = MCPTool.mockData
    @State private var searchText = ""
    @State private var selectedCategory: MCPToolCategory = .all
    @State private var showingAddTool = false
    
    var filteredTools: [MCPTool] {
        let categoryFiltered = selectedCategory == .all ? tools : tools.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered
        }
        return categoryFiltered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ThemeSpacing.sm) {
                        ForEach(ToolCategory.allCases, id: \.self) { category in
                            ToolCategoryChip(
                                category: category,
                                isSelected: selectedCategory == category,
                                count: tools.filter { category == .all || $0.category == category }.count
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, ThemeSpacing.sm)
                }
                .background(Theme.card)
                
                Divider()
                    .background(Theme.border)
                
                // Tools list
                if filteredTools.isEmpty {
                    EmptyStateView(
                        icon: "wrench.and.screwdriver",
                        title: "No Tools Found",
                        message: searchText.isEmpty ? "Add MCP tools to enhance Claude's capabilities" : "No tools match your search",
                        action: searchText.isEmpty ? ("Add Tool", { showingAddTool = true }) : nil
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: ThemeSpacing.sm) {
                            ForEach(filteredTools) { tool in
                                ToolCard(tool: tool)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search tools")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddTool = true
                } label: {
                    Image(systemName: "plus")
                }
                .tint(Theme.primary)
            }
        }
        .sheet(isPresented: $showingAddTool) {
            AddToolView { newTool in
                tools.append(newTool)
            }
        }
    }
}

// MARK: - Category Chip

struct ToolCategoryChip: View {
    let category: MCPToolCategory
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ThemeSpacing.xs) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                Text(category.rawValue)
                    .font(Theme.Typography.footnote)
                Text("(\(count))")
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(isSelected ? Theme.foreground : Theme.mutedForeground)
            .padding(.horizontal, ThemeSpacing.md)
            .padding(.vertical, ThemeSpacing.xs)
            .background(isSelected ? Theme.primary : Theme.card)
            .cornerRadius(Theme.CornerRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.full)
                    .stroke(isSelected ? Color.clear : Theme.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let tool: MCPTool
    @State private var isEnabled = true
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            HStack(spacing: ThemeSpacing.md) {
                // Tool icon
                Image(systemName: tool.category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isEnabled ? Theme.primary : Theme.muted)
                    .frame(width: 40, height: 40)
                    .background(isEnabled ? Theme.primary.opacity(0.1) : Theme.muted.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.sm)
                
                // Tool info
                VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                    Text(tool.name)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.foreground)
                    
                    Text(tool.description)
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.mutedForeground)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    // Stats
                    HStack(spacing: ThemeSpacing.md) {
                        Label("\(tool.usageCount) uses", systemImage: "chart.bar")
                        if tool.lastUsed != nil {
                            Label(tool.formattedLastUsed, systemImage: "clock")
                        }
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.muted)
                }
                
                Spacer()
                
                // Toggle
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(Theme.primary)
            }
            .padding(ThemeSpacing.md)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                    Divider()
                        .background(Theme.border)
                    
                    // Parameters
                    if !tool.parameters.isEmpty {
                        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                            Text("Parameters")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.mutedForeground)
                            
                            ForEach(tool.parameters, id: \.name) { param in
                                HStack {
                                    Text(param.name)
                                        .font(Theme.Typography.footnote)
                                        .foregroundColor(Theme.foreground)
                                    Spacer()
                                    Text(param.type)
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.muted)
                                        .padding(.horizontal, ThemeSpacing.xs)
                                        .padding(.vertical, 2)
                                        .background(Theme.muted.opacity(0.2))
                                        .cornerRadius(Theme.CornerRadius.sm)
                                }
                            }
                        }
                    }
                    
                    // Configuration
                    if tool.requiresConfig {
                        Button {
                            // Configure tool
                        } label: {
                            HStack {
                                Image(systemName: "gear")
                                Text("Configure")
                            }
                            .font(Theme.Typography.footnote)
                        }
                        .secondaryButton()
                    }
                }
                .padding([.horizontal, .bottom], ThemeSpacing.md)
            }
        }
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.border, lineWidth: 1)
        )
        .onTapGesture {
            withAnimation(Theme.Animation.spring) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - Tool Category

enum MCPToolCategory: String, CaseIterable {
    case all = "All"
    case fileSystem = "File System"
    case codeAnalysis = "Code Analysis"
    case git = "Git"
    case database = "Database"
    case api = "API"
    case terminal = "Terminal"
    case custom = "Custom"
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .fileSystem: return "folder"
        case .codeAnalysis: return "magnifyingglass"
        case .git: return "arrow.triangle.branch"
        case .database: return "cylinder"
        case .api: return "network"
        case .terminal: return "terminal"
        case .custom: return "wrench"
        }
    }
}

// MARK: - MCP Tool Model
// Using MCPTool from MCPModels.swift instead

/*
struct MCPTool: Identifiable {
    let id = UUID().uuidString
    let name: String
    let description: String
    let category: MCPToolCategory
    let usageCount: Int
    let lastUsed: Date?
    let requiresConfig: Bool
    let parameters: [Parameter]
    
    struct Parameter {
        let name: String
        let type: String
        let required: Bool
    }
    
    var formattedLastUsed: String {
        guard let lastUsed = lastUsed else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUsed, relativeTo: Date())
    }
*/
    
extension MCPTool {
    static let mockData: [MCPTool] = [
        MCPTool(
            id: "read-file",
            serverId: "filesystem",
            name: "Read File",
            description: "Read contents of a file from the file system",
            version: "1.0.0",
            category: .filesystem,
            inputSchema: JSONSchema(
                type: "object",
                properties: nil,
                required: nil,
                additionalProperties: nil,
                description: nil
            ),
            outputSchema: nil,
            examples: nil,
            permissions: nil,
            rateLimit: nil,
            metadata: nil,
            isDeprecated: false,
            replacedBy: nil
        ),
        MCPTool(
            id: "write-file",
            serverId: "filesystem",
            name: "Write File",
            description: "Write or create a file with specified content",
            version: "1.0.0",
            category: .filesystem,
            inputSchema: JSONSchema(
                type: "object",
                properties: [:],
                required: ["path", "content"],
                additionalProperties: nil,
                description: nil
            ),
            outputSchema: nil,
            examples: nil,
            permissions: nil,
            rateLimit: nil,
            metadata: nil,
            isDeprecated: false,
            replacedBy: nil
        ),
        MCPTool(
            id: "git-status",
            serverId: "git",
            name: "Git Status",
            description: "Check the status of a git repository",
            version: "1.0.0",
            category: .utility,
            inputSchema: JSONSchema(
                type: "object",
                properties: nil,
                required: nil,
                additionalProperties: nil,
                description: nil
            ),
            outputSchema: nil,
            examples: nil,
            permissions: nil,
            rateLimit: nil,
            metadata: nil,
            isDeprecated: false,
            replacedBy: nil
        ),
        MCPTool(
            id: "execute-command",
            serverId: "terminal",
            name: "Execute Command",
            description: "Execute a shell command in the terminal",
            version: "1.0.0",
            category: .utility,
            inputSchema: JSONSchema(
                type: "object",
                properties: [:],
                required: ["command"],
                additionalProperties: nil,
                description: nil
            ),
            outputSchema: nil,
            examples: nil,
            permissions: nil,
            rateLimit: nil,
            metadata: nil,
            isDeprecated: false,
            replacedBy: nil
        ),
        MCPTool(
            id: "query-database",
            serverId: "database",
            name: "Query Database",
            description: "Execute SQL queries on connected databases",
            version: "1.0.0",
            category: .database,
            inputSchema: JSONSchema(
                type: "object",
                properties: [:],
                required: ["query", "database"],
                additionalProperties: nil,
                description: nil
            ),
            outputSchema: nil,
            examples: nil,
            permissions: nil,
            rateLimit: nil,
            metadata: nil,
            isDeprecated: false,
            replacedBy: nil
        ),
        MCPTool(
            id: "api-request",
            serverId: "api",
            name: "API Request",
            description: "Make HTTP requests to external APIs",
            version: "1.0.0",
            category: .network,
            inputSchema: JSONSchema(
                type: "object",
                properties: [:],
                required: ["url"],
                additionalProperties: nil,
                description: nil
            ),
            outputSchema: nil,
            examples: nil,
            permissions: nil,
            rateLimit: nil,
            metadata: nil,
            isDeprecated: false,
            replacedBy: nil
        )
    ]
}

// MARK: - Add Tool View

struct AddToolView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var toolName = ""
    @State private var toolDescription = ""
    @State private var selectedCategory: MCPToolCategory = .custom
    @State private var serverURL = ""
    
    let onSave: (MCPTool) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: ThemeSpacing.lg) {
                        CustomTextField(
                            title: "Tool Name",
                            text: $toolName,
                            placeholder: "My Custom Tool",
                            icon: "wrench"
                        )
                        
                        CustomTextEditor(
                            title: "Description",
                            text: $toolDescription,
                            placeholder: "What does this tool do?",
                            minHeight: 80,
                            maxHeight: 120
                        )
                        
                        // Category picker
                        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                            Text("Category")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.mutedForeground)
                            
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(MCPToolCategory.allCases.filter { $0 != .all }, id: \.self) { category in
                                    Label(category.rawValue, systemImage: category.icon)
                                        .tag(category)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.primary)
                        }
                        
                        CustomTextField(
                            title: "MCP Server URL",
                            text: $serverURL,
                            placeholder: "http://localhost:3000/mcp",
                            icon: "network",
                            keyboardType: .URL
                        )
                        
                        Text("Note: The tool will be configured after connecting to the MCP server.")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Tool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(Theme.foreground)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let newTool = MCPTool(
                            name: toolName,
                            description: toolDescription,
                            category: selectedCategory,
                            usageCount: 0,
                            lastUsed: nil,
                            requiresConfig: true,
                            parameters: []
                        )
                        onSave(newTool)
                        dismiss()
                    }
                    .tint(Theme.primary)
                    .disabled(toolName.isEmpty || serverURL.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ToolsView()
    }
    .preferredColorScheme(.dark)
}