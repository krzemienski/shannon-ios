//
//  ModelSelectorView.swift
//  ClaudeCode
//
//  Model selection dropdown with capabilities display
//

import SwiftUI

/// Model selector view with favorites and capabilities
struct ModelSelectorView: View {
    @Binding var selectedModel: String
    let onSelect: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var favoriteModels: Set<String> = []
    @State private var showCustomModel = false
    @State private var customModelName = ""
    @AppStorage("favoriteModels") private var storedFavorites = ""
    
    // Available models with their capabilities
    private let models: [ModelInfo] = [
        // Claude models
        ModelInfo(
            id: "claude-3-opus-20240229",
            name: "Claude 3 Opus",
            provider: "Anthropic",
            contextWindow: 200000,
            capabilities: [ModelFeature.reasoning, .coding, .analysis, .creative],
            tier: ModelTier.premium
        ),
        ModelInfo(
            id: "claude-3-sonnet-20240229",
            name: "Claude 3 Sonnet",
            provider: "Anthropic",
            contextWindow: 200000,
            capabilities: [ModelFeature.reasoning, .coding, .analysis],
            tier: ModelTier.standard
        ),
        ModelInfo(
            id: "claude-3-haiku-20240307",
            name: "Claude 3 Haiku",
            provider: "Anthropic",
            contextWindow: 200000,
            capabilities: [ModelFeature.coding, .analysis],
            tier: ModelTier.fast
        ),
        ModelInfo(
            id: "claude-2.1",
            name: "Claude 2.1",
            provider: "Anthropic",
            contextWindow: 200000,
            capabilities: [ModelFeature.reasoning, .coding],
            tier: ModelTier.legacy
        ),
        
        // OpenAI models
        ModelInfo(
            id: "gpt-4-turbo-preview",
            name: "GPT-4 Turbo",
            provider: "OpenAI",
            contextWindow: 128000,
            capabilities: [ModelFeature.reasoning, .coding, .vision],
            tier: ModelTier.premium
        ),
        ModelInfo(
            id: "gpt-4",
            name: "GPT-4",
            provider: "OpenAI",
            contextWindow: 8192,
            capabilities: [ModelFeature.reasoning, .coding],
            tier: ModelTier.standard
        ),
        ModelInfo(
            id: "gpt-3.5-turbo",
            name: "GPT-3.5 Turbo",
            provider: "OpenAI",
            contextWindow: 16385,
            capabilities: [ModelFeature.coding],
            tier: ModelTier.fast
        )
    ]
    
    private var filteredModels: [ModelInfo] {
        if searchText.isEmpty {
            return models
        }
        return models.filter { model in
            model.name.localizedCaseInsensitiveContains(searchText) ||
            model.provider.localizedCaseInsensitiveContains(searchText) ||
            model.id.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var groupedModels: [(String, [ModelInfo])] {
        Dictionary(grouping: filteredModels) { $0.provider }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.sorted { $0.tier.priority > $1.tier.priority }) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ThemeSpacing.lg) {
                    // Search bar
                    searchBar
                    
                    // Favorites section
                    if !favoriteModels.isEmpty {
                        favoritesSection
                    }
                    
                    // Models by provider
                    ForEach(groupedModels, id: \.0) { provider, providerModels in
                        providerSection(provider: provider, models: providerModels)
                    }
                    
                    // Custom model option
                    customModelSection
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadFavorites()
        }
    }
    
    // MARK: - Subviews
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.mutedForeground)
            
            TextField("Search models...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(Theme.foreground)
        }
        .padding(ThemeSpacing.sm)
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
    
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
            Text("Favorites")
                .font(Theme.Typography.headlineFont)
                .foregroundColor(Theme.foreground)
            
            ForEach(models.filter { favoriteModels.contains($0.id) }) { model in
                modelCard(model, isFavorite: true)
            }
        }
    }
    
    private func providerSection(provider: String, models: [ModelInfo]) -> some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
            HStack {
                Text(provider)
                    .font(Theme.Typography.headlineFont)
                    .foregroundColor(Theme.foreground)
                
                Spacer()
                
                Image(systemName: providerIcon(for: provider))
                    .foregroundColor(Theme.mutedForeground)
            }
            
            ForEach(models) { model in
                modelCard(model, isFavorite: favoriteModels.contains(model.id))
            }
        }
    }
    
    private func modelCard(_ model: ModelInfo, isFavorite: Bool) -> some View {
        Button(action: {
            onSelect(model.id)
            dismiss()
        }) {
            VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                        HStack {
                            Text(model.name)
                                .font(Theme.Typography.bodyFont)
                                .foregroundColor(Theme.foreground)
                            
                            tierBadge(model.tier)
                        }
                        
                        Text(model.id)
                            .font(Theme.Typography.captionFont)
                            .foregroundColor(Theme.mutedForeground)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        toggleFavorite(model.id)
                    }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .yellow : Theme.mutedForeground)
                    }
                    .buttonStyle(.plain)
                    
                    if model.id == selectedModel {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.primary)
                    }
                }
                
                // Context window
                HStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                    Text("\(formatTokenCount(model.contextWindow)) context")
                        .font(Theme.Typography.caption2Font)
                }
                .foregroundColor(Theme.mutedForeground)
                
                // Capabilities
                HStack(spacing: ThemeSpacing.xs) {
                    ForEach(model.capabilities, id: \.self) { capability in
                        capabilityBadge(capability)
                    }
                }
            }
            .padding(ThemeSpacing.md)
            .background(Theme.card)
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(model.id == selectedModel ? Theme.primary : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var customModelSection: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
            Text("Custom Model")
                .font(Theme.Typography.headlineFont)
                .foregroundColor(Theme.foreground)
            
            if showCustomModel {
                VStack(spacing: ThemeSpacing.sm) {
                    TextField("Enter model ID...", text: $customModelName)
                        .textFieldStyle(.plain)
                        .padding(ThemeSpacing.sm)
                        .background(Theme.card)
                        .cornerRadius(Theme.CornerRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                    
                    HStack {
                        Button("Cancel") {
                            showCustomModel = false
                            customModelName = ""
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Use Model") {
                            if !customModelName.isEmpty {
                                onSelect(customModelName)
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(customModelName.isEmpty)
                    }
                }
            } else {
                Button(action: {
                    showCustomModel = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add custom model")
                    }
                    .font(Theme.Typography.bodyFont)
                    .foregroundColor(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(ThemeSpacing.md)
                    .background(Theme.primary.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func tierBadge(_ tier: ModelTier) -> some View {
        Text(tier.rawValue.uppercased())
            .font(Theme.Typography.caption2Font)
            .fontWeight(.semibold)
            .padding(.horizontal, ThemeSpacing.xs)
            .padding(.vertical, 2)
            .background(tier.color.opacity(0.2))
            .foregroundColor(tier.color)
            .cornerRadius(Theme.CornerRadius.xs)
    }
    
    private func capabilityBadge(_ capability: ModelCapability) -> some View {
        HStack(spacing: 2) {
            Image(systemName: capability.icon)
                .font(.system(size: 10))
            Text(capability.rawValue)
                .font(Theme.Typography.caption2Font)
        }
        .padding(.horizontal, ThemeSpacing.xs)
        .padding(.vertical, 2)
        .background(Theme.card)
        .foregroundColor(Theme.mutedForeground)
        .cornerRadius(Theme.CornerRadius.xs)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.xs)
                .stroke(Theme.border, lineWidth: 0.5)
        )
    }
    
    // MARK: - Helpers
    
    private func providerIcon(for provider: String) -> String {
        switch provider {
        case "Anthropic": return "cpu"
        case "OpenAI": return "brain"
        default: return "server.rack"
        }
    }
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return "\(count / 1000)k"
        }
        return "\(count)"
    }
    
    private func toggleFavorite(_ modelId: String) {
        if favoriteModels.contains(modelId) {
            favoriteModels.remove(modelId)
        } else {
            favoriteModels.insert(modelId)
        }
        saveFavorites()
    }
    
    private func loadFavorites() {
        let favorites = storedFavorites.split(separator: ",").map(String.init)
        favoriteModels = Set(favorites)
    }
    
    private func saveFavorites() {
        storedFavorites = Array(favoriteModels).joined(separator: ",")
    }
}

// MARK: - Model Types

struct ModelInfo: Identifiable {
    let id: String
    let name: String
    let provider: String
    let contextWindow: Int
    let capabilities: [ModelFeature]
    let tier: ModelTier
}

enum ModelFeature: String {
    case reasoning = "Reasoning"
    case coding = "Coding"
    case analysis = "Analysis"
    case creative = "Creative"
    case vision = "Vision"
    
    var icon: String {
        switch self {
        case .reasoning: return "brain"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .analysis: return "chart.line.uptrend.xyaxis"
        case .creative: return "paintbrush"
        case .vision: return "eye"
        }
    }
}

enum ModelTier: String {
    case premium = "Premium"
    case standard = "Standard"
    case fast = "Fast"
    case legacy = "Legacy"
    
    var color: Color {
        switch self {
        case .premium: return .purple
        case .standard: return .blue
        case .fast: return .green
        case .legacy: return .gray
        }
    }
    
    var priority: Int {
        switch self {
        case .premium: return 4
        case .standard: return 3
        case .fast: return 2
        case .legacy: return 1
        }
    }
}

// MARK: - Preview

#Preview {
    ModelSelectorView(
        selectedModel: .constant("claude-3-opus-20240229"),
        onSelect: { _ in }
    )
    .preferredColorScheme(.dark)
}