# Claude Code iOS - Component Architecture Document
## Agent E (UI/UX Designer) - Wave 2 Component Strategy

---

## 1. Component Hierarchy

### 1.1 Atomic Design Principles

We'll follow atomic design methodology adapted for SwiftUI:

```
Atoms → Molecules → Organisms → Templates → Screens
```

### 1.2 Component Categories

```swift
// Atoms (Basic building blocks)
- Colors, Typography, Icons, Spacing
- Basic animations and transitions
- Haptic feedback patterns

// Molecules (Simple components)
- Buttons, Badges, Pills, Chips
- Input fields, Toggles, Sliders
- Loading indicators, Progress bars

// Organisms (Complex components)
- Cards, Lists, Navigation bars
- Forms, Modals, Sheets
- Tool timeline, Message bubbles

// Templates (Layout patterns)
- Tab layouts, Split views
- Master-detail patterns
- Chat console layout

// Screens (Complete views)
- HomeView, ProjectsView, SessionsView
- ChatConsoleView, MonitoringView
- SettingsView, HelpView
```

## 2. Core Component Library

### 2.1 Button Components

```swift
// Button Variants
enum ButtonSize {
    case small    // 32pt height
    case medium   // 40pt height
    case large    // 48pt height
}

enum ButtonVariant {
    case primary(size: ButtonSize = .medium)
    case secondary(size: ButtonSize = .medium)
    case ghost(size: ButtonSize = .medium)
    case danger(size: ButtonSize = .medium)
    case floating // FAB style
}

// Usage Examples
struct ButtonExamples: View {
    var body: some View {
        VStack(spacing: 16) {
            // Primary action
            CyberpunkButton("Start Session", variant: .primary()) {
                // Action
            }
            
            // Secondary action
            CyberpunkButton("Configure", variant: .secondary()) {
                // Action
            }
            
            // Danger action
            CyberpunkButton("Delete", variant: .danger()) {
                // Action
            }
            
            // Ghost button for less emphasis
            CyberpunkButton("Cancel", variant: .ghost()) {
                // Action
            }
        }
    }
}
```

### 2.2 Form Components

```swift
// Text Input Components
struct FormComponents {
    // Basic text field
    CyberpunkTextField(
        text: $text,
        placeholder: "Enter API key",
        icon: "key.fill",
        isSecure: true
    )
    
    // Multi-line text editor
    CyberpunkTextEditor(
        text: $prompt,
        placeholder: "Enter your prompt...",
        minHeight: 100,
        maxHeight: 300
    )
    
    // Search field with live results
    CyberpunkSearchField(
        query: $searchQuery,
        placeholder: "Search projects...",
        onSearch: { query in
            // Perform search
        }
    )
    
    // Dropdown/Picker
    CyberpunkPicker(
        selection: $selectedModel,
        options: models,
        label: "Select Model"
    )
    
    // Toggle with description
    CyberpunkToggle(
        isOn: $streamingEnabled,
        label: "Enable Streaming",
        description: "Stream responses in real-time"
    )
    
    // Slider with value display
    CyberpunkSlider(
        value: $temperature,
        range: 0...2,
        step: 0.1,
        label: "Temperature"
    )
}
```

### 2.3 Display Components

```swift
// Card Components
struct CardVariants {
    // Basic card
    CyberpunkCard {
        // Content
    }
    
    // Glowing card for emphasis
    CyberpunkCard(glowColor: .neonCyan, glowIntensity: 0.3) {
        // Content
    }
    
    // Card with grid overlay
    CyberpunkCard(showGrid: true) {
        // Content
    }
    
    // Expandable card
    CyberpunkExpandableCard(
        header: { HeaderView() },
        content: { DetailedContent() }
    )
}

// Badge & Chip Components
struct StatusComponents {
    // Status badge
    CyberpunkBadge(
        text: "Active",
        color: .success,
        animated: true
    )
    
    // Chip with close button
    CyberpunkChip(
        text: "GPT-4",
        onClose: {
            // Remove chip
        }
    )
    
    // Tag group
    CyberpunkTagGroup(
        tags: ["Swift", "iOS", "API"],
        selectedTags: $selectedTags
    )
}
```

### 2.4 Navigation Components

```swift
// Tab Bar
struct CyberpunkTabBar: View {
    @Binding var selectedTab: Tab
    
    enum Tab: CaseIterable {
        case home
        case projects
        case sessions
        case monitoring
        case settings
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .projects: return "folder.fill"
            case .sessions: return "bubble.left.and.bubble.right.fill"
            case .monitoring: return "chart.line.uptrend.xyaxis"
            case .settings: return "gearshape.fill"
            }
        }
        
        var label: String {
            switch self {
            case .home: return "Home"
            case .projects: return "Projects"
            case .sessions: return "Sessions"
            case .monitoring: return "Monitor"
            case .settings: return "Settings"
            }
        }
    }
    
    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    onTap: { selectedTab = tab }
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Theme.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Theme.border.opacity(0.2)),
            alignment: .top
        )
    }
}

// Navigation Header
struct CyberpunkNavigationHeader: View {
    let title: String
    let subtitle: String?
    let leadingAction: (() -> Void)?
    let trailingActions: [NavigationAction]
    
    var body: some View {
        HStack {
            // Leading button
            if let action = leadingAction {
                IconButton(icon: "arrow.left", action: action)
            }
            
            // Title section
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.themed(.title))
                    .foregroundColor(Theme.foreground)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.themed(.caption))
                        .foregroundColor(Theme.mutedForeground)
                }
            }
            
            Spacer()
            
            // Trailing actions
            HStack(spacing: 12) {
                ForEach(trailingActions) { action in
                    IconButton(icon: action.icon, action: action.handler)
                }
            }
        }
        .padding()
        .background(Theme.surface)
    }
}
```

## 3. Chat Console Components

### 3.1 Message Components

```swift
// Message Bubble
struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message content
                MessageContent(message: message)
                    .padding(12)
                    .background(bubbleBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(bubbleBorder, lineWidth: 1)
                    )
                
                // Timestamp
                Text(message.timestamp.formatted())
                    .font(.themed(.caption))
                    .foregroundColor(Theme.mutedForeground)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: alignment)
            
            if !isCurrentUser { Spacer() }
        }
    }
    
    private var bubbleBackground: Color {
        if isCurrentUser {
            return Theme.primary.opacity(0.2)
        } else {
            return Theme.surface
        }
    }
}

// Message Content Types
enum MessageContentType {
    case text(String)
    case code(language: String, code: String)
    case markdown(String)
    case toolUse(tool: String, input: String)
    case toolResult(tool: String, output: String)
    case image(URL)
    case error(String)
}

// Streaming Indicator
struct StreamingIndicator: View {
    @State private var dots = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Theme.neonCyan)
                    .frame(width: 8, height: 8)
                    .opacity(index <= dots ? 1.0 : 0.3)
                    .scaleEffect(index <= dots ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 0.2), value: dots)
            }
        }
        .onReceive(timer) { _ in
            dots = (dots + 1) % 3
        }
    }
}
```

### 3.2 Input Components

```swift
// Chat Input Bar
struct ChatInputBar: View {
    @Binding var message: String
    @State private var isExpanded = false
    let onSend: () -> Void
    let onAttach: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Attachment preview if needed
            if hasAttachments {
                AttachmentPreview(attachments: attachments)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            // Input area
            HStack(alignment: .bottom, spacing: 12) {
                // Attachment button
                Button(action: onAttach) {
                    Image(systemName: "paperclip")
                        .foregroundColor(Theme.accent)
                }
                
                // Text input
                MessageComposer(
                    text: $message,
                    isExpanded: $isExpanded,
                    placeholder: "Type a message..."
                )
                
                // Send button
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(message.isEmpty ? Theme.mutedForeground : Theme.primary)
                }
                .disabled(message.isEmpty)
            }
            .padding()
            .background(Theme.surface)
        }
    }
}

// Command Palette
struct CommandPalette: View {
    @Binding var isVisible: Bool
    @Binding var selectedCommand: Command?
    
    let commands = [
        Command(name: "clear", description: "Clear chat history"),
        Command(name: "export", description: "Export conversation"),
        Command(name: "models", description: "Change model"),
        Command(name: "tools", description: "Configure MCP tools"),
        // ...
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(filteredCommands) { command in
                CommandRow(command: command) {
                    selectedCommand = command
                    isVisible = false
                }
            }
        }
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.neonCyan.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Theme.neonCyan.opacity(0.2), radius: 20)
    }
}
```

## 4. Tool Timeline Components

### 4.1 Timeline Visualization

```swift
// Tool Timeline View
struct ToolTimeline: View {
    let events: [ToolEvent]
    @State private var selectedEvent: ToolEvent?
    @State private var zoomLevel: Double = 1.0
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            TimelineCanvas(
                events: events,
                selectedEvent: $selectedEvent,
                zoomLevel: zoomLevel
            )
            .frame(
                width: canvasWidth * zoomLevel,
                height: canvasHeight
            )
        }
        .overlay(
            TimelineControls(zoomLevel: $zoomLevel),
            alignment: .topTrailing
        )
        .sheet(item: $selectedEvent) { event in
            ToolEventDetail(event: event)
        }
    }
}

// Tool Event Node
struct ToolEventNode: View {
    let event: ToolEvent
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Theme.foreground, lineWidth: 2)
                        .opacity(isSelected ? 1 : 0)
                )
            
            // Tool icon
            Image(systemName: event.tool.icon)
                .font(.system(size: 24))
                .foregroundColor(Theme.foreground)
            
            // Tool name
            Text(event.tool.name)
                .font(.themed(.caption))
                .foregroundColor(Theme.mutedForeground)
            
            // Duration
            Text(formatDuration(event.duration))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Theme.accent)
        }
        .padding(8)
        .background(Theme.card)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Theme.neonCyan : Theme.border.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: statusColor.opacity(0.3), radius: 8)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
    
    private var statusColor: Color {
        switch event.status {
        case .success: return Theme.success
        case .error: return Theme.error
        case .running: return Theme.neonCyan
        case .pending: return Theme.mutedForeground
        }
    }
}
```

## 5. Loading & Error States

### 5.1 Loading Components

```swift
// Loading States
struct LoadingView: View {
    let message: String?
    
    var body: some View {
        VStack(spacing: 20) {
            CyberpunkSpinner()
            
            if let message = message {
                Text(message)
                    .font(.themed(.body))
                    .foregroundColor(Theme.mutedForeground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.opacity(0.9))
    }
}

// Custom Spinner
struct CyberpunkSpinner: View {
    @State private var rotation = 0.0
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [Theme.neonCyan, Theme.accent, Theme.neonCyan],
                        center: .center
                    ),
                    lineWidth: 4
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(rotation))
            
            // Inner ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [Theme.accent, Theme.neonCyan, Theme.accent],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-rotation * 1.5))
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
```

### 5.2 Error States

```swift
// Error View
struct ErrorView: View {
    let error: Error
    let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.error)
            
            // Error message
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.themed(.title))
                    .foregroundColor(Theme.foreground)
                
                Text(error.localizedDescription)
                    .font(.themed(.body))
                    .foregroundColor(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
            }
            
            // Actions
            if let onRetry = onRetry {
                CyberpunkButton("Try Again", variant: .primary()) {
                    onRetry()
                }
            }
        }
        .padding(32)
        .frame(maxWidth: 400)
    }
}

// Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let action: (() -> Void)?
    let actionLabel: String?
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(Theme.mutedForeground.opacity(0.5))
            
            // Text
            VStack(spacing: 8) {
                Text(title)
                    .font(.themed(.title))
                    .foregroundColor(Theme.foreground)
                
                Text(message)
                    .font(.themed(.body))
                    .foregroundColor(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
            }
            
            // Action
            if let action = action, let label = actionLabel {
                CyberpunkButton(label, variant: .primary()) {
                    action()
                }
            }
        }
        .padding(32)
        .frame(maxWidth: 400)
    }
}
```

## 6. Accessibility Components

### 6.1 Accessibility Wrappers

```swift
// Accessible Card
struct AccessibleCard<Content: View>: View {
    let label: String
    let hint: String?
    let content: Content
    
    init(
        label: String,
        hint: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.hint = hint
        self.content = content()
    }
    
    var body: some View {
        CyberpunkCard {
            content
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .if(hint != nil) { view in
            view.accessibilityHint(hint!)
        }
    }
}

// Accessible List Row
struct AccessibleListRow<Content: View>: View {
    let position: Int
    let total: Int
    let content: Content
    
    var body: some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityValue("\(position) of \(total)")
            .accessibilityAddTraits(.isButton)
    }
}
```

### 6.2 Dynamic Type Support

```swift
// Dynamic Type Aware Component
struct DynamicTypeText: View {
    let text: String
    let style: Typography.TextStyle
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        Text(text)
            .font(.themed(style))
            .minimumScaleFactor(minimumScale)
            .lineLimit(lineLimit)
    }
    
    private var minimumScale: CGFloat {
        switch sizeCategory {
        case .extraSmall, .small, .medium, .large:
            return 1.0
        case .extraLarge, .extraExtraLarge:
            return 0.9
        case .extraExtraExtraLarge:
            return 0.8
        default:
            return 0.7
        }
    }
    
    private var lineLimit: Int? {
        sizeCategory.isAccessibilityCategory ? nil : 3
    }
}
```

## 7. Testing Components

### 7.1 Preview Providers

```swift
// Component Preview Provider
struct ComponentPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light/Dark mode
            ComponentShowcase()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // Different device sizes
            ComponentShowcase()
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("iPhone SE")
            
            ComponentShowcase()
                .previewDevice("iPhone 15 Pro Max")
                .previewDisplayName("iPhone 15 Pro Max")
            
            // Dynamic Type sizes
            ComponentShowcase()
                .environment(\.sizeCategory, .extraSmall)
                .previewDisplayName("XS Text")
            
            ComponentShowcase()
                .environment(\.sizeCategory, .extraExtraExtraLarge)
                .previewDisplayName("XXXL Text")
            
            // Accessibility
            ComponentShowcase()
                .environment(\.accessibilityReduceMotion, true)
                .previewDisplayName("Reduce Motion")
        }
    }
}

// Component Showcase
struct ComponentShowcase: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                ButtonShowcase()
                FormShowcase()
                CardShowcase()
                ChatShowcase()
                LoadingShowcase()
            }
            .padding()
        }
        .background(Theme.background)
    }
}
```

## 8. Performance Optimization

### 8.1 Lazy Loading

```swift
// Lazy loaded list
struct OptimizedList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    content(item)
                        .onAppear {
                            // Prefetch next items
                            prefetchIfNeeded(item)
                        }
                }
            }
        }
    }
}
```

### 8.2 View Recycling

```swift
// Reusable cell pattern
struct ReusableCell: View {
    @State private var content: AnyView?
    let identifier: String
    
    func configure<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }
    
    var body: some View {
        content ?? AnyView(EmptyView())
    }
}
```

## 9. Component Documentation

Each component will include:
- **Purpose**: Clear description of component's role
- **Usage**: Code examples and best practices
- **Props**: All configurable properties
- **States**: Different visual states
- **Accessibility**: VoiceOver behavior and keyboard support
- **Performance**: Rendering cost and optimization tips
- **Testing**: Unit and snapshot test coverage

## 10. Implementation Timeline

### Wave 2 - Phase 1: Core Components (Tasks 501-520)
- Week 1: Buttons, basic inputs, cards
- Week 2: Navigation, tab bar, headers

### Wave 2 - Phase 2: Form Components (Tasks 521-540)
- Week 3: Text fields, pickers, toggles
- Week 4: Validation, error states, accessibility

### Wave 2 - Phase 3: Advanced Components (Tasks 541-550)
- Week 5: Modals, sheets, complex interactions

### Wave 2 - Phase 4: Chat Components (Tasks 651-680)
- Week 6: Message bubbles, streaming indicators
- Week 7: Input bar, command palette

### Wave 2 - Phase 5: Specialized Components (Tasks 681-700)
- Week 8: Tool timeline, monitoring displays
- Week 9: Polish, animations, testing

---

*Component Architecture prepared by Agent E (Swift UI Designer)*
*Ready for systematic implementation following atomic design principles*