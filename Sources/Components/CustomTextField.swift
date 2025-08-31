//
//  CustomTextField.swift
//  ClaudeCode
//
//  Custom text field with theme styling
//

import SwiftUI

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    @State private var isShowingPassword = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
            // Title label
            if !title.isEmpty {
                Text(title)
                    .font(Theme.Typography.captionFont)
                    .foregroundColor(Theme.mutedForeground)
            }
            
            // Text field container
            HStack(spacing: ThemeSpacing.sm) {
                // Leading icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.muted)
                        .frame(width: 20)
                }
                
                // Text field
                Group {
                    if isSecure && !isShowingPassword {
                        SecureField(placeholder, text: $text)
                            .textContentType(textContentType)
                            .submitLabel(submitLabel)
                            .onSubmit {
                                onSubmit?()
                            }
                            .focused($isFocused)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                            .textContentType(textContentType)
                            .submitLabel(submitLabel)
                            .onSubmit {
                                onSubmit?()
                            }
                            .focused($isFocused)
                    }
                }
                .font(Theme.Typography.bodyFont)
                .foregroundColor(Theme.foreground)
                .tint(Theme.primary)
                
                // Password visibility toggle
                if isSecure {
                    Button {
                        isShowingPassword.toggle()
                    } label: {
                        Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.muted)
                    }
                }
                
                // Clear button
                if !text.isEmpty && !isSecure {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.muted)
                    }
                }
            }
            .padding(.horizontal, ThemeSpacing.md)
            .padding(.vertical, ThemeSpacing.sm)
            .background(Theme.input)
            .cornerRadius(Theme.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                    .stroke(
                        isFocused ? Theme.primary : Theme.inputBorder,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .animation(Theme.Animation.easeInOut, value: isFocused)
        }
    }
}

#Preview {
    ZStack {
        Theme.background
            .ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: ThemeSpacing.lg) {
                CustomTextField(
                    title: "Username",
                    text: .constant(""),
                    placeholder: "Enter username",
                    icon: "person.fill",
                    textContentType: .username
                )
                
                CustomTextField(
                    title: "Email",
                    text: .constant("john@example.com"),
                    placeholder: "Enter email",
                    icon: "envelope.fill",
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )
                
                CustomTextField(
                    title: "Password",
                    text: .constant("password123"),
                    placeholder: "Enter password",
                    isSecure: true,
                    icon: "lock.fill",
                    textContentType: .password
                )
                
                CustomTextField(
                    title: "API Key",
                    text: .constant(""),
                    placeholder: "sk-...",
                    icon: "key.fill"
                )
                
                CustomTextEditor(
                    title: "Message",
                    text: .constant(""),
                    placeholder: "Type your message here..."
                )
            }
            .padding()
        }
    }
}