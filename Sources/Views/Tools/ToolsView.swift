//
//  ToolsView.swift
//  ClaudeCode
//
//  MCP tools configuration and management
//

import SwiftUI

struct ToolsView: View {
    @StateObject private var toolStore = DependencyContainer.shared.toolStore
    @State private var searchText = ""
    @State private var selectedCategory: MCPToolCategory = .all
    @State private var showingAddTool = false
    
    private var tools: [MCPTool] {
        // MVP: Return empty array for now
        []
        // toolStore.availableTools
    }
    
    var filteredTools: [MCPTool] {
        // MVP: Since tools array is empty, just return it
        return []
        /*
        let categoryFiltered = selectedCategory == .all ? tools : tools.filter { 
            // Would need to map between MCPToolCategory and ToolCategory
            false
        }
        
        if searchText.isEmpty {
            return categoryFiltered
        }
        return categoryFiltered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
        */
    }
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ThemeSpacing.sm) {
                        ForEach(MCPToolCategory.allCases, id: \.self) { category in
                            ToolCategoryChip(
                                category: category,
                                isSelected: selectedCategory == category,
                                count: 0 // MVP: Always 0 since tools is empty
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
                // MVP: Tool adding not implemented
                // Would need to add to toolStore
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
                    .font(Theme.Typography.footnoteFont)
                Text("(\(count))")
                    .font(Theme.Typography.captionFont)
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
                // MVP: Use a default icon since category mapping is complex
                Image(systemName: "wrench")
                    .font(.system(size: 24))
                    .foregroundColor(isEnabled ? Theme.primary : Theme.muted)
                    .frame(width: 40, height: 40)
                    .background(isEnabled ? Theme.primary.opacity(0.1) : Theme.muted.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.sm)
                
                // Tool info
                VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                    Text(tool.name)
                        .font(Theme.Typography.headlineFont)
                        .foregroundColor(Theme.foreground)
                    
                    Text(tool.description)
                        .font(Theme.Typography.footnoteFont)
                        .foregroundColor(Theme.mutedForeground)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    // Stats - MVP: Show version instead
                    HStack(spacing: ThemeSpacing.md) {
                        if let version = tool.version {
                            Label("v\(version)", systemImage: "info.circle")
                                .font(Theme.Typography.captionFont)
                                .foregroundColor(Theme.muted)
                        }
                    }
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
                    
                    // MVP: Show metadata instead of parameters
                    if let metadata = tool.metadata {
                        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                            Text("Server")
                                .font(Theme.Typography.captionFont)
                                .foregroundColor(Theme.mutedForeground)
                            
                            Text(tool.serverId)
                                .font(Theme.Typography.footnoteFont)
                                .foregroundColor(Theme.foreground)
                        }
                    }
                    
                    // Configuration button - always show for MVP
                    Button {
                        // Configure tool
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Configure")
                        }
                        .font(Theme.Typography.footnoteFont)
                    }
                    .secondaryButton()
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
// Removed mock data - now using real data from ToolStore

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
                                .font(Theme.Typography.captionFont)
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
                            .font(Theme.Typography.captionFont)
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
                        // MVP: Create simplified MCP tool
                        // Map MCPToolCategory to ToolCategory
                        var toolCategory: ToolCategory = .custom
                        switch selectedCategory {
                        case .fileSystem:
                            toolCategory = .filesystem
                        case .codeAnalysis:
                            toolCategory = .analysis
                        case .git:
                            toolCategory = .utility
                        case .database:
                            toolCategory = .database
                        case .api:
                            toolCategory = .network
                        case .terminal:
                            toolCategory = .utility
                        default:
                            toolCategory = .custom
                        }
                        
                        let newTool = MCPTool(
                            id: UUID().uuidString,
                            serverId: serverURL,
                            name: toolName,
                            description: toolDescription,
                            version: "1.0.0",
                            category: toolCategory,
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