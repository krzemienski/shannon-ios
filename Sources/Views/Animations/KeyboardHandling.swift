//
//  KeyboardHandling.swift
//  ClaudeCode
//
//  Keyboard handling utilities and adaptive layouts
//

import SwiftUI
import Combine

// MARK: - Keyboard Observer

class KeyboardObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isKeyboardVisible = false
    @Published var animationDuration: Double = 0.25
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupKeyboardObservers()
    }
    
    private func setupKeyboardObservers() {
        // Keyboard will show
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                      let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
                    return nil
                }
                return (frame.height, duration)
            }
            .sink { [weak self] height, duration in
                withAnimation(.easeOut(duration: duration)) {
                    self?.keyboardHeight = height
                    self?.isKeyboardVisible = true
                    self?.animationDuration = duration
                }
            }
            .store(in: &cancellables)
        
        // Keyboard will hide
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .compactMap { notification in
                notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            }
            .sink { [weak self] duration in
                withAnimation(.easeOut(duration: duration)) {
                    self?.keyboardHeight = 0
                    self?.isKeyboardVisible = false
                    self?.animationDuration = duration
                }
            }
            .store(in: &cancellables)
        
        // Keyboard frame change
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .compactMap { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                      let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
                    return nil
                }
                return (frame.height, duration)
            }
            .sink { [weak self] height, duration in
                withAnimation(.easeOut(duration: duration)) {
                    self?.keyboardHeight = height
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Keyboard Adaptive Modifier

struct KeyboardAdaptive: ViewModifier {
    @StateObject private var keyboard = KeyboardObserver()
    let additionalPadding: CGFloat
    
    init(additionalPadding: CGFloat = 0) {
        self.additionalPadding = additionalPadding
    }
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboard.keyboardHeight + additionalPadding)
            .animation(.easeOut(duration: keyboard.animationDuration), value: keyboard.keyboardHeight)
    }
}

// MARK: - Keyboard Dismiss Modifier

struct KeyboardDismissible: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
}

// MARK: - Keyboard Toolbar

struct KeyboardToolbar<Content: View>: ViewModifier {
    let content: () -> Content
    @StateObject private var keyboard = KeyboardObserver()
    
    func body(content baseContent: Content) -> some View {
        ZStack(alignment: .bottom) {
            baseContent
            
            if keyboard.isKeyboardVisible {
                VStack(spacing: 0) {
                    Divider()
                        .background(Theme.border)
                    
                    content()
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Theme.card)
                }
                .transition(.move(edge: .bottom))
                .offset(y: -keyboard.keyboardHeight)
                .animation(.easeOut(duration: keyboard.animationDuration), value: keyboard.keyboardHeight)
            }
        }
    }
}

// MARK: - Focus State Manager

class FocusStateManager: ObservableObject {
    enum Field: Hashable {
        case username
        case email
        case password
        case confirmPassword
        case custom(String)
    }
    
    @Published var focusedField: Field?
    
    func focus(on field: Field) {
        focusedField = field
    }
    
    func dismissKeyboard() {
        focusedField = nil
    }
    
    func nextField(from current: Field, in fields: [Field]) {
        guard let currentIndex = fields.firstIndex(of: current) else { return }
        
        if currentIndex < fields.count - 1 {
            focusedField = fields[currentIndex + 1]
        } else {
            dismissKeyboard()
        }
    }
    
    func previousField(from current: Field, in fields: [Field]) {
        guard let currentIndex = fields.firstIndex(of: current) else { return }
        
        if currentIndex > 0 {
            focusedField = fields[currentIndex - 1]
        }
    }
}

// MARK: - Keyboard Aware ScrollView

struct KeyboardAwareScrollView<Content: View>: View {
    let content: () -> Content
    @StateObject private var keyboard = KeyboardObserver()
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content()
                    .padding(.bottom, keyboard.keyboardHeight)
                    .onChange(of: keyboard.isKeyboardVisible) { isVisible in
                        if isVisible {
                            withAnimation {
                                proxy.scrollTo("keyboard_spacer", anchor: .bottom)
                            }
                        }
                    }
                
                Color.clear
                    .frame(height: 1)
                    .id("keyboard_spacer")
            }
        }
    }
}

// MARK: - Input Accessory View

struct InputAccessoryView: View {
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onDone: () -> Void
    let hasPrevious: Bool
    let hasNext: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: 20) {
                Button {
                    onPrevious()
                } label: {
                    Image(systemName: "chevron.up")
                        .foregroundColor(hasPrevious ? Theme.primary : Theme.muted)
                }
                .disabled(!hasPrevious)
                
                Button {
                    onNext()
                } label: {
                    Image(systemName: "chevron.down")
                        .foregroundColor(hasNext ? Theme.primary : Theme.muted)
                }
                .disabled(!hasNext)
            }
            
            Spacer()
            
            Button("Done") {
                onDone()
            }
            .foregroundColor(Theme.primary)
            .fontWeight(.medium)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Theme.card)
    }
}

// MARK: - Smart Text Field

struct SmartTextField: View {
    let title: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let onSubmit: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var showPassword = false
    
    private var isSecureField: Bool {
        textContentType == .password || textContentType == .newPassword
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(isFocused ? Theme.primary : Theme.mutedForeground)
            
            HStack {
                if isSecureField && !showPassword {
                    SecureField("", text: $text)
                        .textContentType(textContentType)
                        .focused($isFocused)
                        .onSubmit(onSubmit)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                        .autocapitalization(keyboardType == .emailAddress ? .none : .sentences)
                        .focused($isFocused)
                        .onSubmit(onSubmit)
                }
                
                if isSecureField {
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(Theme.secondary)
                    }
                }
                
                if isFocused && !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.secondary)
                    }
                }
            }
            .padding()
            .background(Theme.input)
            .cornerRadius(ThemeRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: ThemeRadius.sm)
                    .stroke(isFocused ? Theme.primary : Theme.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - View Extensions

extension View {
    func keyboardAdaptive(additionalPadding: CGFloat = 0) -> some View {
        modifier(KeyboardAdaptive(additionalPadding: additionalPadding))
    }
    
    func keyboardDismissible() -> some View {
        modifier(KeyboardDismissible())
    }
    
    func keyboardToolbar<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(KeyboardToolbar(content: content))
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewContent: View {
        @State private var username = ""
        @State private var email = ""
        @State private var password = ""
        @StateObject private var focusManager = FocusStateManager()
        
        var body: some View {
            KeyboardAwareScrollView {
                VStack(spacing: 20) {
                    SmartTextField(
                        title: "Username",
                        text: $username,
                        keyboardType: .default,
                        textContentType: .username,
                        onSubmit: {
                            // Next field
                        }
                    )
                    
                    SmartTextField(
                        title: "Email",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        onSubmit: {
                            // Next field
                        }
                    )
                    
                    SmartTextField(
                        title: "Password",
                        text: $password,
                        keyboardType: .default,
                        textContentType: .newPassword,
                        onSubmit: {
                            // Submit form
                        }
                    )
                    
                    Button {
                        hideKeyboard()
                    } label: {
                        Text("Sign Up")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryButton()
                }
                .padding()
            }
            .keyboardDismissible()
            .keyboardToolbar {
                InputAccessoryView(
                    onPrevious: {
                        // Previous field
                    },
                    onNext: {
                        // Next field
                    },
                    onDone: {
                        hideKeyboard()
                    },
                    hasPrevious: true,
                    hasNext: true
                )
            }
        }
    }
    
    return NavigationStack {
        PreviewContent()
            .navigationTitle("Keyboard Demo")
            .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
}