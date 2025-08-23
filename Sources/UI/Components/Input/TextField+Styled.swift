//
//  TextField+Styled.swift
//  ClaudeCode
//
//  Custom styled text field component
//

import SwiftUI

/// Styled text field with validation and custom appearance
public struct StyledTextField: View {
    // MARK: - Properties
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let errorMessage: String?
    let helperText: String?
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let onCommit: (() -> Void)?
    
    @State private var isFocused = false
    @State private var showPassword = false
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Initialization
    public init(
        _ title: String = "",
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        errorMessage: String? = nil,
        helperText: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.errorMessage = errorMessage
        self.helperText = helperText
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.onCommit = onCommit
    }
    
    // MARK: - Body
    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title
            if !title.isEmpty {
                Text(title)
                    .font(Typography.Label.medium)
                    .foregroundColor(SemanticColors.Foregrounds.secondary(colorScheme))
            }
            
            // Input Field
            HStack(spacing: Spacing.md) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                        .frame(width: 20)
                }
                
                Group {
                    if isSecure && !showPassword {
                        SecureField(placeholder, text: $text)
                            .textContentType(textContentType)
                    } else {
                        TextField(placeholder, text: $text, onCommit: {
                            onCommit?()
                        })
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                    }
                }
                .font(Typography.Body.medium)
                .foregroundColor(SemanticColors.Foregrounds.primary(colorScheme))
                .accentColor(SemanticColors.Accents.primary)
                .onTapGesture {
                    withAnimation(Animations.Spring.quick) {
                        isFocused = true
                    }
                }
                
                if isSecure {
                    Button(action: {
                        showPassword.toggle()
                    }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(SemanticColors.Foregrounds.secondary(colorScheme))
                    }
                    .buttonStyle(.plain)
                }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: Icons.Navigation.close)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(SemanticColors.Foregrounds.secondary(colorScheme))
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(SemanticColors.Backgrounds.tertiary(colorScheme))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
            .background(fieldBackground)
            .overlay(fieldBorder)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            
            // Helper/Error Text
            if let errorMessage = errorMessage {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: Icons.Status.error)
                        .font(.system(size: 12))
                    Text(errorMessage)
                        .font(Typography.Body.xs)
                }
                .foregroundColor(SemanticColors.States.error)
            } else if let helperText = helperText {
                Text(helperText)
                    .font(Typography.Body.xs)
                    .foregroundColor(SemanticColors.Foregrounds.tertiary(colorScheme))
            }
        }
    }
    
    // MARK: - Computed Properties
    private var iconColor: Color {
        if errorMessage != nil {
            return SemanticColors.States.error
        } else if isFocused {
            return SemanticColors.Accents.primary
        } else {
            return SemanticColors.Foregrounds.secondary(colorScheme)
        }
    }
    
    private var fieldBackground: some View {
        SemanticColors.Backgrounds.tertiary(colorScheme)
            .opacity(isFocused ? 1.0 : 0.8)
    }
    
    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.md)
            .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
    }
    
    private var borderColor: Color {
        if errorMessage != nil {
            return SemanticColors.States.error
        } else if isFocused {
            return SemanticColors.Accents.primary
        } else {
            return SemanticColors.Borders.default(colorScheme)
        }
    }
}

// MARK: - Text Area Component
public struct StyledTextEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let errorMessage: String?
    
    @State private var isFocused = false
    @State private var textHeight: CGFloat = 100
    @Environment(\.colorScheme) var colorScheme
    
    public init(
        _ title: String = "",
        placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat = 100,
        maxHeight: CGFloat = 300,
        errorMessage: String? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.errorMessage = errorMessage
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !title.isEmpty {
                Text(title)
                    .font(Typography.Label.medium)
                    .foregroundColor(SemanticColors.Foregrounds.secondary(colorScheme))
            }
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Typography.Body.medium)
                        .foregroundColor(SemanticColors.Foregrounds.tertiary(colorScheme))
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.sm)
                }
                
                TextEditor(text: $text)
                    .font(Typography.Body.medium)
                    .foregroundColor(SemanticColors.Foregrounds.primary(colorScheme))
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.xs)
                    .frame(minHeight: minHeight, maxHeight: maxHeight)
                    .onTapGesture {
                        withAnimation(Animations.Spring.quick) {
                            isFocused = true
                        }
                    }
            }
            .padding(Spacing.sm)
            .background(SemanticColors.Backgrounds.tertiary(colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(
                        errorMessage != nil ? SemanticColors.States.error :
                        isFocused ? SemanticColors.Accents.primary :
                        SemanticColors.Borders.default(colorScheme),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            
            if let errorMessage = errorMessage {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: Icons.Status.error)
                        .font(.system(size: 12))
                    Text(errorMessage)
                        .font(Typography.Body.xs)
                }
                .foregroundColor(SemanticColors.States.error)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: Spacing.xl) {
        StyledTextField(
            "Email",
            placeholder: "Enter your email",
            text: .constant(""),
            icon: Icons.Communication.email,
            helperText: "We'll never share your email"
        )
        
        StyledTextField(
            "Password",
            placeholder: "Enter password",
            text: .constant("password123"),
            icon: Icons.System.security,
            isSecure: true
        )
        
        StyledTextField(
            placeholder: "Search...",
            text: .constant(""),
            icon: Icons.Navigation.search
        )
        
        StyledTextField(
            "Username",
            placeholder: "Choose a username",
            text: .constant("invalid"),
            icon: Icons.System.profile,
            errorMessage: "Username is already taken"
        )
        
        StyledTextEditor(
            "Description",
            placeholder: "Enter a description...",
            text: .constant("")
        )
    }
    .padding()
    .background(Color(hsl: 240, 10, 5))
    .preferredColorScheme(.dark)
}