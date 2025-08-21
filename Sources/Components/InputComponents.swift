//
//  InputComponents.swift
//  ClaudeCode
//
//  Enhanced input components with validation and styling
//

import SwiftUI

// MARK: - Enhanced Text Field

struct EnhancedTextField: View {
    let title: String?
    @Binding var text: String
    let placeholder: String
    let icon: String?
    let trailingIcon: String?
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    let validation: ((String) -> ValidationResult)?
    let onCommit: (() -> Void)?
    
    @State private var isFocused = false
    @State private var validationResult: ValidationResult = .valid
    
    init(
        title: String? = nil,
        text: Binding<String>,
        placeholder: String = "",
        icon: String? = nil,
        trailingIcon: String? = nil,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false,
        validation: ((String) -> ValidationResult)? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.trailingIcon = trailingIcon
        self.keyboardType = keyboardType
        self.isSecure = isSecure
        self.validation = validation
        self.onCommit = onCommit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
            // Title
            if let title = title {
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            // Input field
            HStack(spacing: ThemeSpacing.sm) {
                // Leading icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                        .frame(width: 20)
                }
                
                // Text field
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                    }
                }
                .font(Theme.Typography.body)
                .foregroundColor(Theme.foreground)
                .tint(Theme.primary)
                .onSubmit {
                    onCommit?()
                }
                .onChange(of: text) { newValue in
                    if let validation = validation {
                        validationResult = validation(newValue)
                    }
                }
                
                // Trailing icon or validation indicator
                if let trailingIcon = trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.mutedForeground)
                } else if validation != nil {
                    validationIndicator
                }
            }
            .padding(.horizontal, ThemeSpacing.md)
            .padding(.vertical, ThemeSpacing.sm)
            .background(Theme.input)
            .cornerRadius(Theme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .onTapGesture {
                isFocused = true
            }
            
            // Validation message
            if case .invalid(let message) = validationResult {
                Text(message)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.destructive)
            }
        }
    }
    
    @ViewBuilder
    private var validationIndicator: some View {
        switch validationResult {
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Theme.success)
        case .invalid:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Theme.destructive)
        case .none:
            EmptyView()
        }
    }
    
    private var borderColor: Color {
        if isFocused {
            return Theme.primary
        }
        switch validationResult {
        case .invalid:
            return Theme.destructive
        default:
            return Theme.border
        }
    }
    
    private var iconColor: Color {
        if isFocused {
            return Theme.primary
        }
        return Theme.mutedForeground
    }
}

// MARK: - Search Field

struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    let onSearch: (() -> Void)?
    
    @State private var isFocused = false
    
    init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSearch: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSearch = onSearch
    }
    
    var body: some View {
        HStack(spacing: ThemeSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(isFocused ? Theme.primary : Theme.mutedForeground)
            
            TextField(placeholder, text: $text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.foreground)
                .tint(Theme.primary)
                .onSubmit {
                    onSearch?()
                }
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.mutedForeground)
                }
            }
        }
        .padding(.horizontal, ThemeSpacing.md)
        .padding(.vertical, ThemeSpacing.sm)
        .background(Theme.input)
        .cornerRadius(Theme.Radius.round)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.round)
                .stroke(isFocused ? Theme.primary : Theme.border, lineWidth: 1)
        )
        .onTapGesture {
            isFocused = true
        }
    }
}

// MARK: - Custom Text Editor

struct CustomTextEditor: View {
    let title: String?
    @Binding var text: String
    let placeholder: String
    let minHeight: CGFloat
    let maxHeight: CGFloat?
    let font: Font
    
    @State private var isFocused = false
    @State private var textHeight: CGFloat = 0
    
    init(
        title: String? = nil,
        text: Binding<String>,
        placeholder: String = "",
        minHeight: CGFloat = 100,
        maxHeight: CGFloat? = nil,
        font: Font = Theme.Typography.body
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.font = font
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
            // Title
            if let title = title {
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            // Text editor
            ZStack(alignment: .topLeading) {
                // Placeholder
                if text.isEmpty {
                    Text(placeholder)
                        .font(font)
                        .foregroundColor(Theme.mutedForeground)
                        .padding(.horizontal, ThemeSpacing.md)
                        .padding(.vertical, ThemeSpacing.sm)
                }
                
                // Text editor
                TextEditor(text: $text)
                    .font(font)
                    .foregroundColor(Theme.foreground)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, ThemeSpacing.sm)
                    .padding(.vertical, ThemeSpacing.xs)
                    .frame(minHeight: minHeight, maxHeight: maxHeight)
            }
            .background(Theme.input)
            .cornerRadius(Theme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(isFocused ? Theme.primary : Theme.border, lineWidth: 1)
            )
            .onTapGesture {
                isFocused = true
            }
        }
    }
}

// MARK: - Toggle Switch

struct CustomToggle: View {
    let title: String
    @Binding var isOn: Bool
    let subtitle: String?
    let icon: String?
    
    var body: some View {
        HStack(spacing: ThemeSpacing.md) {
            // Icon
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Theme.primary)
                    .frame(width: 32, height: 32)
                    .background(Theme.primary.opacity(0.1))
                    .cornerRadius(Theme.Radius.sm)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.foreground)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.mutedForeground)
                }
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.primary)
        }
        .padding(ThemeSpacing.md)
        .background(Theme.card)
        .cornerRadius(Theme.Radius.md)
    }
}

// MARK: - Segmented Control

struct CustomSegmentedControl<T: Hashable>: View {
    let title: String?
    @Binding var selection: T
    let options: [(T, String)]
    
    @Namespace private var animation
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
            // Title
            if let title = title {
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            // Segmented control
            HStack(spacing: 0) {
                ForEach(options, id: \.0) { option in
                    Button {
                        withAnimation(Theme.Animation.spring) {
                            selection = option.0
                        }
                    } label: {
                        Text(option.1)
                            .font(Theme.Typography.callout)
                            .foregroundColor(selection == option.0 ? Theme.background : Theme.foreground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ThemeSpacing.sm)
                            .background(
                                ZStack {
                                    if selection == option.0 {
                                        Theme.primary
                                            .cornerRadius(Theme.Radius.md)
                                            .matchedGeometryEffect(id: "selection", in: animation)
                                    }
                                }
                            )
                    }
                }
            }
            .background(Theme.input)
            .cornerRadius(Theme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Slider

struct CustomSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    let showValue: Bool
    
    init(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double? = nil,
        showValue: Bool = true
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.showValue = showValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.sm) {
            // Header
            HStack {
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.foreground)
                
                Spacer()
                
                if showValue {
                    Text("\(Int(value))")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.primary)
                        .padding(.horizontal, ThemeSpacing.sm)
                        .padding(.vertical, 2)
                        .background(Theme.primary.opacity(0.1))
                        .cornerRadius(Theme.Radius.sm)
                }
            }
            
            // Slider
            Slider(value: $value, in: range, step: step)
                .tint(Theme.primary)
        }
        .padding(ThemeSpacing.md)
        .background(Theme.card)
        .cornerRadius(Theme.Radius.md)
    }
}

// MARK: - Validation Result

enum ValidationResult {
    case valid
    case invalid(String)
    case none
}

// MARK: - Preview

struct InputComponents_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: ThemeSpacing.lg) {
                    // Text fields
                    EnhancedTextField(
                        title: "Email",
                        text: .constant("user@example.com"),
                        placeholder: "Enter your email",
                        icon: "envelope",
                        keyboardType: .emailAddress,
                        validation: { email in
                            email.contains("@") ? .valid : .invalid("Invalid email format")
                        }
                    )
                    
                    EnhancedTextField(
                        title: "Password",
                        text: .constant(""),
                        placeholder: "Enter password",
                        icon: "lock",
                        isSecure: true
                    )
                    
                    // Search field
                    SearchField(
                        text: .constant(""),
                        placeholder: "Search messages..."
                    )
                    
                    // Text editor
                    CustomTextEditor(
                        title: "Description",
                        text: .constant(""),
                        placeholder: "Enter a detailed description...",
                        minHeight: 120
                    )
                    
                    // Toggle
                    CustomToggle(
                        title: "Enable Notifications",
                        isOn: .constant(true),
                        subtitle: "Receive alerts for new messages",
                        icon: "bell"
                    )
                    
                    // Segmented control
                    CustomSegmentedControl(
                        title: "Model",
                        selection: .constant("haiku"),
                        options: [
                            ("haiku", "Haiku"),
                            ("sonnet", "Sonnet"),
                            ("opus", "Opus")
                        ]
                    )
                    
                    // Slider
                    CustomSlider(
                        title: "Temperature",
                        value: .constant(0.7),
                        range: 0...1,
                        step: 0.1
                    )
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
}