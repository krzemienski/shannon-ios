//
//  TooltipView.swift
//  ClaudeCode
//
//  Interactive tooltip and help UI components
//

import SwiftUI

// MARK: - Tooltip View

struct TooltipView: View {
    let tooltip: Tooltip
    let onDismiss: () -> Void
    let onAction: (String) -> Void
    
    @State private var animateIn = false
    @State private var showArrow = true
    
    var backgroundColor: Color {
        switch tooltip.type {
        case .info:
            return Theme.primary
        case .warning:
            return .orange
        case .success:
            return .green
        case .tip:
            return Theme.secondary
        case .tutorial:
            return Theme.accent
        case .feature:
            return Theme.primary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Arrow (if needed)
            if showArrow && tooltip.position == .bottom {
                TooltipArrow(color: backgroundColor)
                    .frame(width: 20, height: 10)
                    .offset(x: 20)
            }
            
            // Content
            VStack(alignment: .leading, spacing: Theme.spacing.sm) {
                // Header
                HStack {
                    if let icon = tooltip.icon {
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    
                    Text(tooltip.title)
                        .font(Theme.typography.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring()) {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Message
                Text(tooltip.message)
                    .font(Theme.typography.body)
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                
                // Actions
                if !tooltip.actions.isEmpty {
                    HStack(spacing: Theme.spacing.sm) {
                        ForEach(tooltip.actions, id: \.actionId) { action in
                            TooltipActionButton(
                                action: action,
                                onTap: { onAction(action.actionId) }
                            )
                        }
                    }
                    .padding(.top, Theme.spacing.sm)
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(Theme.radius.medium)
            .shadow(color: backgroundColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Arrow (if needed)
            if showArrow && tooltip.position == .top {
                TooltipArrow(color: backgroundColor)
                    .frame(width: 20, height: 10)
                    .rotationEffect(.degrees(180))
                    .offset(x: 20)
            }
        }
        .scaleEffect(animateIn ? 1.0 : 0.8)
        .opacity(animateIn ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring()) {
                animateIn = true
            }
        }
    }
}

// MARK: - Tooltip Arrow

struct TooltipArrow: View {
    let color: Color
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 10, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 10))
            path.addLine(to: CGPoint(x: 20, y: 10))
            path.closeSubpath()
        }
        .fill(color)
    }
}

// MARK: - Tooltip Action Button

struct TooltipActionButton: View {
    let action: Tooltip.TooltipAction
    let onTap: () -> Void
    
    var backgroundColor: Color {
        switch action.style {
        case .primary:
            return .white
        case .secondary:
            return .white.opacity(0.2)
        case .destructive:
            return .red
        }
    }
    
    var foregroundColor: Color {
        switch action.style {
        case .primary:
            return Theme.primary
        case .secondary:
            return .white
        case .destructive:
            return .white
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            Text(action.title)
                .font(Theme.typography.caption)
                .foregroundColor(foregroundColor)
                .padding(.horizontal, Theme.spacing.md)
                .padding(.vertical, Theme.spacing.xs)
                .background(backgroundColor)
                .cornerRadius(Theme.radius.small)
        }
    }
}

// MARK: - Tooltip Modifier

struct TooltipModifier: ViewModifier {
    let tooltipId: String
    let showCondition: Bool
    @StateObject private var tooltipService = TooltipService.shared
    @State private var showTooltip = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if showTooltip,
                       let tooltip = tooltipService.activeTooltip,
                       tooltip.targetId == tooltipId {
                        TooltipView(
                            tooltip: tooltip,
                            onDismiss: {
                                tooltipService.hideTooltip()
                                showTooltip = false
                            },
                            onAction: { actionId in
                                handleTooltipAction(actionId)
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(1000)
                    }
                },
                alignment: getAlignment(for: tooltipService.activeTooltip?.position ?? .top)
            )
            .onAppear {
                if showCondition {
                    tooltipService.showTooltip(tooltipId)
                    showTooltip = true
                }
            }
            .onChange(of: tooltipService.activeTooltip) { _, newValue in
                showTooltip = newValue?.targetId == tooltipId
            }
    }
    
    private func getAlignment(for position: Tooltip.TooltipPosition) -> Alignment {
        switch position {
        case .top:
            return .top
        case .bottom:
            return .bottom
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center:
            return .center
        }
    }
    
    private func handleTooltipAction(_ actionId: String) {
        // Handle tooltip actions
        switch actionId {
        case "create_project":
            // Navigate to create project
            break
        default:
            break
        }
        
        tooltipService.hideTooltip()
        showTooltip = false
    }
}

// MARK: - View Extension

extension View {
    func tooltip(_ tooltipId: String, show: Bool = true) -> some View {
        modifier(TooltipModifier(tooltipId: tooltipId, showCondition: show))
    }
}

// MARK: - Help Center View

struct HelpCenterView: View {
    @StateObject private var tooltipService = TooltipService.shared
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showingArticle: HelpArticle?
    
    let categories = ["All", "Getting Started", "Features", "Configuration", "Projects", "Security", "Troubleshooting"]
    
    var filteredArticles: [HelpArticle] {
        if searchText.isEmpty {
            return tooltipService.searchHelp("")
        }
        return tooltipService.searchHelp(searchText)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing.lg) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.muted)
                        
                        TextField("Search help articles...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding()
                    .background(Theme.card)
                    .cornerRadius(Theme.radius.medium)
                    .padding(.horizontal)
                    
                    // Categories
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.spacing.sm) {
                            ForEach(categories, id: \.self) { category in
                                CategoryChip(
                                    title: category,
                                    isSelected: selectedCategory == category,
                                    onTap: {
                                        selectedCategory = category
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Popular articles
                    VStack(alignment: .leading, spacing: Theme.spacing.md) {
                        Text("Popular Articles")
                            .font(Theme.typography.headline)
                            .foregroundColor(Theme.foreground)
                            .padding(.horizontal)
                        
                        ForEach(filteredArticles.prefix(5)) { article in
                            HelpArticleRow(article: article) {
                                showingArticle = article
                            }
                        }
                    }
                    
                    // FAQ section
                    VStack(alignment: .leading, spacing: Theme.spacing.md) {
                        Text("Frequently Asked Questions")
                            .font(Theme.typography.headline)
                            .foregroundColor(Theme.foreground)
                            .padding(.horizontal)
                        
                        ForEach(tooltipService.getFAQs().prefix(5)) { faq in
                            FAQRow(faq: faq)
                        }
                    }
                    
                    // Contact support
                    VStack(spacing: Theme.spacing.md) {
                        Text("Still need help?")
                            .font(Theme.typography.headline)
                            .foregroundColor(Theme.foreground)
                        
                        HStack(spacing: Theme.spacing.md) {
                            ContactButton(
                                icon: "envelope.fill",
                                title: "Email Support",
                                action: {
                                    // Open email
                                }
                            )
                            
                            ContactButton(
                                icon: "bubble.left.and.bubble.right.fill",
                                title: "Community Forum",
                                action: {
                                    // Open forum
                                }
                            )
                        }
                    }
                    .padding()
                    .background(Theme.card)
                    .cornerRadius(Theme.radius.large)
                    .padding()
                }
            }
            .navigationTitle("Help Center")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $showingArticle) { article in
                HelpArticleDetailView(article: article)
            }
        }
    }
}

// MARK: - Help Article Row

struct HelpArticleRow: View {
    let article: HelpArticle
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.spacing.xs) {
                    Text(article.title)
                        .font(Theme.typography.headline)
                        .foregroundColor(Theme.foreground)
                    
                    Text(article.category)
                        .font(Theme.typography.caption)
                        .foregroundColor(Theme.muted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.muted)
            }
            .padding()
            .background(Theme.card)
            .cornerRadius(Theme.radius.medium)
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - FAQ Row

struct FAQRow: View {
    let faq: FAQItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
            Button {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(faq.question)
                        .font(Theme.typography.headline)
                        .foregroundColor(Theme.foreground)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(Theme.muted)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(faq.answer)
                    .font(Theme.typography.body)
                    .foregroundColor(Theme.secondaryForeground)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Theme.card)
        .cornerRadius(Theme.radius.medium)
        .padding(.horizontal)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(Theme.typography.caption)
                .foregroundColor(isSelected ? Theme.background : Theme.foreground)
                .padding(.horizontal, Theme.spacing.md)
                .padding(.vertical, Theme.spacing.sm)
                .background(isSelected ? Theme.primary : Theme.card)
                .cornerRadius(Theme.radius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Contact Button

struct ContactButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(Theme.primary)
                
                Text(title)
                    .font(Theme.typography.caption)
                    .foregroundColor(Theme.foreground)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.background)
            .cornerRadius(Theme.radius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Help Article Detail View

struct HelpArticleDetailView: View {
    let article: HelpArticle
    @StateObject private var tooltipService = TooltipService.shared
    @State private var isHelpful: Bool?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing.lg) {
                    // Article content
                    VStack(alignment: .leading, spacing: Theme.spacing.md) {
                        Text(article.title)
                            .font(Theme.typography.largeTitle)
                            .foregroundColor(Theme.foreground)
                        
                        HStack {
                            Label(article.category, systemImage: "folder.fill")
                                .font(Theme.typography.caption)
                                .foregroundColor(Theme.muted)
                            
                            Spacer()
                            
                            Text("Updated: \(article.lastUpdated.formatted(date: .abbreviated, time: .omitted))")
                                .font(Theme.typography.small)
                                .foregroundColor(Theme.tertiaryForeground)
                        }
                        
                        Divider()
                        
                        Text(article.content)
                            .font(Theme.typography.body)
                            .foregroundColor(Theme.foreground)
                        
                        // Video link (if available)
                        if let videoURL = article.videoURL {
                            Link(destination: URL(string: videoURL)!) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Watch Video Tutorial")
                                }
                                .font(Theme.typography.body)
                                .foregroundColor(Theme.primary)
                            }
                            .padding()
                            .background(Theme.primary.opacity(0.1))
                            .cornerRadius(Theme.radius.medium)
                        }
                        
                        // Tags
                        if !article.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.spacing.sm) {
                                    ForEach(article.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(Theme.typography.small)
                                            .foregroundColor(Theme.primary)
                                            .padding(.horizontal, Theme.spacing.sm)
                                            .padding(.vertical, Theme.spacing.xs)
                                            .background(Theme.primary.opacity(0.1))
                                            .cornerRadius(Theme.radius.small)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    
                    // Feedback section
                    VStack(alignment: .leading, spacing: Theme.spacing.md) {
                        Text("Was this article helpful?")
                            .font(Theme.typography.headline)
                            .foregroundColor(Theme.foreground)
                        
                        HStack(spacing: Theme.spacing.md) {
                            FeedbackButton(
                                icon: "hand.thumbsup.fill",
                                title: "Yes",
                                isSelected: isHelpful == true,
                                color: .green,
                                onTap: {
                                    isHelpful = true
                                    tooltipService.markArticleHelpful(article.id, helpful: true)
                                }
                            )
                            
                            FeedbackButton(
                                icon: "hand.thumbsdown.fill",
                                title: "No",
                                isSelected: isHelpful == false,
                                color: .red,
                                onTap: {
                                    isHelpful = false
                                    tooltipService.markArticleHelpful(article.id, helpful: false)
                                }
                            )
                        }
                        
                        if isHelpful != nil {
                            Text("Thank you for your feedback!")
                                .font(Theme.typography.body)
                                .foregroundColor(Theme.secondaryForeground)
                        }
                    }
                    .padding()
                    .background(Theme.card)
                    .cornerRadius(Theme.radius.large)
                    .padding()
                    
                    // Related articles
                    if !article.relatedArticles.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.spacing.md) {
                            Text("Related Articles")
                                .font(Theme.typography.headline)
                                .foregroundColor(Theme.foreground)
                                .padding(.horizontal)
                            
                            // Would show related articles here
                        }
                    }
                }
            }
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

// MARK: - Feedback Button

struct FeedbackButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? color : Theme.muted)
                Text(title)
                    .foregroundColor(isSelected ? color : Theme.foreground)
            }
            .font(Theme.typography.body)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? color.opacity(0.1) : Theme.background)
            .cornerRadius(Theme.radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius.medium)
                    .stroke(isSelected ? color : Theme.muted.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}