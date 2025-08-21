//
//  ChatSettingsView.swift
//  ClaudeCode
//
//  Chat behavior and model configuration settings
//

import SwiftUI

struct ChatSettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var showingClearHistoryAlert = false
    @State private var showingTemplatesSheet = false
    @State private var selectedTemplate: ChatTemplate?
    
    var body: some View {
        List {
            // Model Configuration
            Section {
                // Model Selection
                VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                    Label {
                        Text("Default Model")
                            .foregroundColor(Theme.foreground)
                    } icon: {
                        Image(systemName: "cpu")
                            .foregroundColor(Theme.primary)
                    }
                    
                    CyberpunkSegmentedControl(
                        selection: $settingsStore.selectedModel,
                        options: availableModels
                    )
                }
                
                // Temperature Slider
                VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                    HStack {
                        Label {
                            Text("Temperature")
                                .foregroundColor(Theme.foreground)
                        } icon: {
                            Image(systemName: "thermometer")
                                .foregroundColor(Theme.accent)
                        }
                        
                        Spacer()
                        
                        Text(String(format: "%.1f", settingsStore.temperature))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.mutedForeground)
                            .monospacedDigit()
                    }
                    
                    CyberpunkSlider(
                        value: $settingsStore.temperature,
                        in: 0...2,
                        step: 0.1
                    )
                    
                    HStack {
                        Text("Focused")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.muted)
                        Spacer()
                        Text("Creative")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.muted)
                    }
                }
                
                // Max Tokens
                VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                    HStack {
                        Label {
                            Text("Max Tokens")
                                .foregroundColor(Theme.foreground)
                        } icon: {
                            Image(systemName: "text.alignleft")
                                .foregroundColor(Theme.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(settingsStore.maxTokens)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.mutedForeground)
                            .monospacedDigit()
                    }
                    
                    CyberpunkSlider(
                        value: .init(
                            get: { Double(settingsStore.maxTokens) },
                            set: { settingsStore.maxTokens = Int($0) }
                        ),
                        in: 256...8192,
                        step: 256
                    )
                    
                    HStack {
                        Text("256")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.muted)
                        Spacer()
                        Text("8192")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.muted)
                    }
                }
            } header: {
                Text("MODEL CONFIGURATION")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
            .listRowBackground(Theme.card)
            
            // Chat Behavior
            Section {
                CyberpunkToggle(
                    "Stream Responses",
                    subtitle: "Show responses as they're generated",
                    isOn: $settingsStore.streamResponses,
                    icon: "waveform"
                )
                
                CyberpunkToggle(
                    "Save Chat History",
                    subtitle: "Automatically save conversations",
                    isOn: $settingsStore.saveHistory,
                    icon: "clock.arrow.circlepath"
                )
                
                CyberpunkToggle(
                    "Show Token Usage",
                    subtitle: "Display token count and costs",
                    isOn: $settingsStore.showTokenUsage,
                    icon: "number.circle"
                )
                
                CyberpunkToggle(
                    "Enable Code Highlighting",
                    subtitle: "Syntax highlighting for code blocks",
                    isOn: $settingsStore.enableCodeHighlighting,
                    icon: "chevron.left.forwardslash.chevron.right"
                )
            } header: {
                Text("BEHAVIOR")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
            .listRowBackground(Theme.card)
            
            // System Prompts
            Section {
                // System Prompt
                VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
                    Label {
                        Text("System Prompt")
                            .foregroundColor(Theme.foreground)
                    } icon: {
                        Image(systemName: "text.bubble")
                            .foregroundColor(Theme.primary)
                    }
                    
                    TextEditor(text: $settingsStore.systemPrompt)
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.foreground)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Theme.input)
                        .cornerRadius(ThemeRadius.sm)
                        .frame(minHeight: 100)
                }
                
                // Prompt Templates
                Button {
                    showingTemplatesSheet = true
                } label: {
                    HStack {
                        Label {
                            Text("Browse Templates")
                                .foregroundColor(Theme.foreground)
                        } icon: {
                            Image(systemName: "doc.text")
                                .foregroundColor(Theme.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Theme.muted)
                    }
                }
            } header: {
                Text("SYSTEM PROMPTS")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            } footer: {
                Text("System prompts help guide the AI's behavior and responses")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.muted)
            }
            .listRowBackground(Theme.card)
            
            // Data Management
            Section {
                // Export History
                Button {
                    exportChatHistory()
                } label: {
                    Label {
                        Text("Export Chat History")
                            .foregroundColor(Theme.foreground)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Theme.primary)
                    }
                }
                
                // Clear History
                Button {
                    showingClearHistoryAlert = true
                } label: {
                    Label {
                        Text("Clear Chat History")
                            .foregroundColor(Theme.destructive)
                    } icon: {
                        Image(systemName: "trash")
                            .foregroundColor(Theme.destructive)
                    }
                }
            } header: {
                Text("DATA MANAGEMENT")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.mutedForeground)
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Chat Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Clear Chat History", isPresented: $showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearChatHistory()
            }
        } message: {
            Text("This will permanently delete all chat conversations. This action cannot be undone.")
        }
        .sheet(isPresented: $showingTemplatesSheet) {
            PromptTemplatesSheet(selectedTemplate: $selectedTemplate) { template in
                settingsStore.systemPrompt = template.prompt
            }
        }
    }
    
    private let availableModels = [
        ("claude-3-5-haiku-20241022", "Haiku"),
        ("claude-3-5-sonnet-20241022", "Sonnet"),
        ("claude-3-opus-20240229", "Opus")
    ]
    
    private func exportChatHistory() {
        // Implementation for exporting chat history
        print("Exporting chat history...")
    }
    
    private func clearChatHistory() {
        // Implementation for clearing chat history
        print("Clearing chat history...")
    }
}

// MARK: - Chat Template

struct ChatTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let prompt: String
    let category: String
}

// MARK: - Prompt Templates Sheet

struct PromptTemplatesSheet: View {
    @Binding var selectedTemplate: ChatTemplate?
    let onSelect: (ChatTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let templates = [
        ChatTemplate(
            name: "Helpful Assistant",
            description: "A friendly and helpful AI assistant",
            prompt: "You are a helpful, harmless, and honest AI assistant.",
            category: "General"
        ),
        ChatTemplate(
            name: "Code Expert",
            description: "Specialized in programming and software development",
            prompt: "You are an expert programmer who helps with code, debugging, and software architecture.",
            category: "Development"
        ),
        ChatTemplate(
            name: "Creative Writer",
            description: "Focused on creative writing and storytelling",
            prompt: "You are a creative writer who helps with storytelling, narratives, and creative content.",
            category: "Creative"
        ),
        ChatTemplate(
            name: "Technical Analyst",
            description: "Specialized in technical analysis and documentation",
            prompt: "You are a technical analyst who provides detailed analysis and documentation.",
            category: "Technical"
        )
    ]
    
    var body: some View {
        NavigationStack {
            List(templates) { template in
                Button {
                    selectedTemplate = template
                    onSelect(template)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
                        HStack {
                            Text(template.name)
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.foreground)
                            
                            Spacer()
                            
                            Text(template.category)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Theme.primary.opacity(0.2))
                                .cornerRadius(ThemeRadius.xs)
                        }
                        
                        Text(template.description)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.mutedForeground)
                        
                        Text(template.prompt)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.muted)
                            .lineLimit(2)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Prompt Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings Store Extensions

extension SettingsStore {
    @Published var showTokenUsage: Bool = true
    @Published var enableCodeHighlighting: Bool = true
    @Published var systemPrompt: String = "You are a helpful, harmless, and honest AI assistant."
}

#Preview {
    NavigationStack {
        ChatSettingsView()
            .environmentObject(SettingsStore())
    }
    .preferredColorScheme(.dark)
}