//
//  ChatInputView.swift
//  ClaudeCode
//
//  Multiline text input with send button and attachments
//

import SwiftUI
import PhotosUI

/// Chat input view with multiline text, attachments, and voice input
struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let isStreaming: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onAttach: () -> Void
    let onVoiceInput: () -> Void
    
    @State private var textHeight: CGFloat = 40
    @State private var showAttachmentMenu = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isRecording = false
    @FocusState private var isFocused: Bool
    
    private let maxTextHeight: CGFloat = 200
    private let minTextHeight: CGFloat = 40
    private let characterLimit = 10000
    
    private var charactersRemaining: Int {
        characterLimit - text.count
    }
    
    private var shouldShowCharacterCount: Bool {
        text.count > characterLimit * 0.8
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Character count warning
            if shouldShowCharacterCount {
                characterCountView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider()
                .background(Theme.border)
            
            HStack(alignment: .bottom, spacing: ThemeSpacing.sm) {
                // Attachment button
                attachmentButton
                
                // Text input
                textInputView
                
                // Voice input button
                voiceInputButton
                
                // Send button
                sendButton
            }
            .padding(.horizontal, ThemeSpacing.md)
            .padding(.vertical, ThemeSpacing.sm)
            .background(Theme.card)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: shouldShowCharacterCount)
    }
    
    // MARK: - Subviews
    
    private var characterCountView: some View {
        HStack {
            Spacer()
            Text("\(charactersRemaining) characters remaining")
                .font(Theme.Typography.caption2)
                .foregroundColor(charactersRemaining < 500 ? .orange : Theme.mutedForeground)
                .padding(.horizontal, ThemeSpacing.md)
                .padding(.vertical, ThemeSpacing.xs)
        }
        .background(Theme.card)
    }
    
    private var attachmentButton: some View {
        Menu {
            Button(action: handlePhotoSelection) {
                Label("Photo Library", systemImage: "photo")
            }
            
            Button(action: handleFileSelection) {
                Label("Files", systemImage: "doc")
            }
            
            Button(action: handleCodeSnippet) {
                Label("Code Snippet", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            
            Button(action: handleScreenshot) {
                Label("Screenshot", systemImage: "camera.viewfinder")
            }
        } label: {
            Image(systemName: showAttachmentMenu ? "plus.circle.fill" : "plus.circle")
                .font(.system(size: 24))
                .foregroundColor(Theme.primary)
                .animation(.spring(response: 0.3), value: showAttachmentMenu)
        }
        .disabled(isLoading || isStreaming)
        .opacity((isLoading || isStreaming) ? 0.5 : 1)
    }
    
    private var textInputView: some View {
        VStack(alignment: .leading, spacing: ThemeSpacing.xs) {
            // Placeholder text when empty
            if text.isEmpty && !isFocused {
                Text("Message Claude...")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.mutedForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
            
            // Text editor with dynamic height
            TextEditor(text: $text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.foreground)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($isFocused)
                .frame(minHeight: minTextHeight, maxHeight: maxTextHeight)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(isFocused ? Theme.primary : Theme.border, lineWidth: 1)
                )
                .onSubmit {
                    if canSend && !text.contains("\n") {
                        onSend()
                    }
                }
                .onChange(of: text) { newValue in
                    // Limit character count
                    if newValue.count > characterLimit {
                        text = String(newValue.prefix(characterLimit))
                    }
                }
        }
        .overlay(alignment: .bottomTrailing) {
            if isLoading || isStreaming {
                ProgressView()
                    .controlSize(.small)
                    .padding(ThemeSpacing.sm)
            }
        }
    }
    
    private var voiceInputButton: some View {
        Button(action: handleVoiceInput) {
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 22))
                .foregroundColor(isRecording ? .red : Theme.primary)
                .symbolEffect(.bounce, value: isRecording)
        }
        .disabled(isLoading || isStreaming)
        .opacity((isLoading || isStreaming) ? 0.5 : 1)
    }
    
    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(canSend ? Theme.primary : Theme.muted)
                .rotationEffect(.degrees(isLoading ? 360 : 0))
                .animation(
                    isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                    value: isLoading
                )
        }
        .disabled(!canSend)
        .keyboardShortcut(.return, modifiers: .command)
    }
    
    // MARK: - Actions
    
    private func handlePhotoSelection() {
        // TODO: Implement photo selection
        print("Photo selection")
    }
    
    private func handleFileSelection() {
        // TODO: Implement file selection
        print("File selection")
    }
    
    private func handleCodeSnippet() {
        // TODO: Implement code snippet insertion
        print("Code snippet")
    }
    
    private func handleScreenshot() {
        // TODO: Implement screenshot capture
        print("Screenshot")
    }
    
    private func handleVoiceInput() {
        isRecording.toggle()
        if isRecording {
            startRecording()
        } else {
            stopRecording()
        }
        onVoiceInput()
    }
    
    private func startRecording() {
        // TODO: Implement voice recording
        print("Start recording")
    }
    
    private func stopRecording() {
        // TODO: Implement voice recording stop
        print("Stop recording")
    }
}

// MARK: - Attachment View

struct AttachmentView: View {
    let type: AttachmentType
    let name: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: ThemeSpacing.xs) {
            Image(systemName: type.icon)
                .font(.system(size: 12))
                .foregroundColor(type.color)
            
            Text(name)
                .font(Theme.Typography.caption)
                .lineLimit(1)
                .foregroundColor(Theme.foreground)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.mutedForeground)
            }
        }
        .padding(.horizontal, ThemeSpacing.sm)
        .padding(.vertical, ThemeSpacing.xs)
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

enum AttachmentType {
    case image
    case file
    case code
    
    var icon: String {
        switch self {
        case .image: return "photo"
        case .file: return "doc"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    var color: Color {
        switch self {
        case .image: return .blue
        case .file: return .orange
        case .code: return .purple
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        
        ChatInputView(
            text: .constant(""),
            isLoading: false,
            isStreaming: false,
            canSend: false,
            onSend: {},
            onAttach: {},
            onVoiceInput: {}
        )
        
        ChatInputView(
            text: .constant("Hello, how can I help you today?"),
            isLoading: false,
            isStreaming: false,
            canSend: true,
            onSend: {},
            onAttach: {},
            onVoiceInput: {}
        )
        
        ChatInputView(
            text: .constant("Generating response..."),
            isLoading: true,
            isStreaming: false,
            canSend: false,
            onSend: {},
            onAttach: {},
            onVoiceInput: {}
        )
    }
    .background(Theme.background)
    .preferredColorScheme(.dark)
}