//
//  CyberpunkTextField.swift
//  ClaudeCode
//
//  Custom text field with cyberpunk styling
//

import SwiftUI

/// Text field validation state
enum TextFieldState {
    case normal
    case success
    case error
    case warning
    
    var borderColor: Color {
        switch self {
        case .normal:
            return Color.hsl(240, 10, 30)
        case .success:
            return Color.hsl(142, 70, 45)
        case .error:
            return Color.hsl(0, 80, 60)
        case .warning:
            return Color.hsl(45, 80, 60)
        }
    }
    
    var iconColor: Color {
        switch self {
        case .normal:
            return Color.hsl(240, 10, 65)
        case .success:
            return Color.hsl(142, 70, 45)
        case .error:
            return Color.hsl(0, 80, 60)
        case .warning:
            return Color.hsl(45, 80, 60)
        }
    }
}

/// Custom cyberpunk-styled text field
struct CyberpunkTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let isSecure: Bool
    let state: TextFieldState
    let helperText: String?
    let onEditingChanged: ((Bool) -> Void)?
    let onCommit: (() -> Void)?
    
    @State private var isEditing = false
    @State private var showPassword = false
    @FocusState private var isFocused: Bool
    
    init(
        _ title: String = "",
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false,
        state: TextFieldState = .normal,
        helperText: String? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.state = state
        self.helperText = helperText
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title Label
            if !title.isEmpty {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.hsl(240, 10, 65))
            }
            
            // Input Field Container
            HStack(spacing: 12) {
                // Leading Icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(state.iconColor)
                        .frame(width: 20)
                }
                
                // Text Field
                Group {
                    if isSecure && !showPassword {
                        SecureField(placeholder, text: $text)
                            .textFieldStyle(.plain)
                            .focused($isFocused)
                    } else {
                        TextField(placeholder, text: $text, onEditingChanged: { editing in
                            withAnimation(.spring(response: 0.3)) {
                                isEditing = editing
                            }
                            onEditingChanged?(editing)
                        }, onCommit: {
                            onCommit?()
                        })
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                    }
                }
                .font(.body)
                .foregroundColor(Color.hsl(0, 0, 95))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                
                // Password Toggle
                if isSecure {
                    Button(action: {
                        showPassword.toggle()
                    }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.hsl(240, 10, 65))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Clear Button
                if !text.isEmpty && !isSecure {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.hsl(240, 10, 45))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.hsl(240, 10, 12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isFocused ? Color.hsl(142, 70, 45) : state.borderColor,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .shadow(
                color: isFocused ? Color.hsl(142, 70, 45).opacity(0.3) : Color.clear,
                radius: 8,
                x: 0,
                y: 0
            )
            
            // Helper Text
            if let helperText = helperText {
                HStack(spacing: 4) {
                    if state == .error {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                    } else if state == .warning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                    } else if state == .success {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                    }
                    
                    Text(helperText)
                        .font(.caption)
                }
                .foregroundColor(state.iconColor)
            }
        }
        .animation(.spring(response: 0.3), value: isFocused)
        .animation(.spring(response: 0.3), value: state)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 24) {
        CyberpunkTextField(
            "Email",
            placeholder: "Enter your email",
            text: .constant("user@example.com"),
            icon: "envelope.fill"
        )
        
        CyberpunkTextField(
            "Password",
            placeholder: "Enter password",
            text: .constant("password123"),
            icon: "lock.fill",
            isSecure: true
        )
        
        CyberpunkTextField(
            placeholder: "Search...",
            text: .constant(""),
            icon: "magnifyingglass"
        )
        
        CyberpunkTextField(
            "Username",
            placeholder: "Choose a username",
            text: .constant("cyberpunk2077"),
            icon: "person.fill",
            state: .success,
            helperText: "Username is available"
        )
        
        CyberpunkTextField(
            "API Key",
            placeholder: "Enter your API key",
            text: .constant("invalid-key"),
            icon: "key.fill",
            state: .error,
            helperText: "Invalid API key format"
        )
    }
    .padding()
    .background(Color.hsl(240, 10, 5))
}