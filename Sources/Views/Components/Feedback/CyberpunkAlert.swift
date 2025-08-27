//
//  CyberpunkAlert.swift
//  ClaudeCode
//
//  Alert and toast notification components with cyberpunk styling
//

import SwiftUI

/// Alert types
enum AlertType {
    case success
    case error
    case warning
    case info
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .success:
            return Color.hsl(142, 70, 45).opacity(0.1)
        case .error:
            return Color.hsl(0, 80, 60).opacity(0.1)
        case .warning:
            return Color.hsl(45, 80, 60).opacity(0.1)
        case .info:
            return Color.hsl(201, 70, 50).opacity(0.1)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .success:
            return Color.hsl(142, 70, 45)
        case .error:
            return Color.hsl(0, 80, 60)
        case .warning:
            return Color.hsl(45, 80, 60)
        case .info:
            return Color.hsl(201, 70, 50)
        }
    }
    
    var iconColor: Color {
        borderColor
    }
}

/// Alert banner component
struct CyberpunkAlert: View {
    let title: String
    let message: String?
    let type: AlertType
    let showIcon: Bool
    let dismissible: Bool
    let onDismiss: (() -> Void)?
    let actions: [AlertAction]
    
    @State private var isShowing = true
    @State private var slideIn = false
    
    struct AlertAction {
        let title: String
        let style: ButtonVariant
        let action: () -> Void
    }
    
    init(
        title: String,
        message: String? = nil,
        type: AlertType = .info,
        showIcon: Bool = true,
        dismissible: Bool = true,
        onDismiss: (() -> Void)? = nil,
        actions: [AlertAction] = []
    ) {
        self.title = title
        self.message = message
        self.type = type
        self.showIcon = showIcon
        self.dismissible = dismissible
        self.onDismiss = onDismiss
        self.actions = actions
    }
    
    var body: some View {
        if isShowing {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                if showIcon {
                    Image(systemName: type.icon)
                        .font(.title3)
                        .foregroundColor(type.iconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.hsl(0, 0, 95))
                    
                    if let message = message {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(Color.hsl(240, 10, 75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Actions
                    if !actions.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(actions.indices, id: \.self) { index in
                                CyberpunkButton(
                                    actions[index].title,
                                    variant: actions[index].style,
                                    size: .small
                                ) {
                                    actions[index].action()
                                }
                                .frame(maxWidth: 120)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                
                Spacer()
                
                // Dismiss button
                if dismissible {
                    Button(action: dismissAlert) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Color.hsl(240, 10, 65))
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(Color.hsl(240, 10, 20))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(type.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(type.borderColor, lineWidth: 1)
                    )
            )
            .shadow(
                color: type.borderColor.opacity(0.2),
                radius: 8,
                x: 0,
                y: 2
            )
            .offset(x: slideIn ? 0 : 400)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    slideIn = true
                }
            }
        }
    }
    
    private func dismissAlert() {
        withAnimation(.spring(response: 0.3)) {
            slideIn = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isShowing = false
            onDismiss?()
        }
    }
}

/// Toast notification component
struct CyberpunkToast: View {
    let message: String
    let type: AlertType
    let duration: TimeInterval
    
    @State private var isShowing = false
    @State private var workItem: DispatchWorkItem?
    
    init(
        message: String,
        type: AlertType = .info,
        duration: TimeInterval = 3.0
    ) {
        self.message = message
        self.type = type
        self.duration = duration
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.body)
                .foregroundColor(type.iconColor)
            
            Text(message)
                .font(.body)
                .foregroundColor(Color.hsl(0, 0, 95))
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.hsl(240, 10, 12))
                .overlay(
                    Capsule()
                        .stroke(type.borderColor, lineWidth: 1)
                )
        )
        .shadow(
            color: type.borderColor.opacity(0.3),
            radius: 8,
            x: 0,
            y: 4
        )
        .scaleEffect(isShowing ? 1 : 0.8)
        .opacity(isShowing ? 1 : 0)
        .onAppear {
            showToast()
        }
    }
    
    private func showToast() {
        withAnimation(.spring(response: 0.3)) {
            isShowing = true
        }
        
        workItem?.cancel()
        
        let task = DispatchWorkItem {
            withAnimation(.spring(response: 0.3)) {
                isShowing = false
            }
        }
        
        workItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }
}

/// Modal alert dialog
struct CyberpunkModalAlert: View {
    let title: String
    let message: String
    let type: AlertType
    let primaryAction: AlertAction
    let secondaryAction: AlertAction?
    
    @Binding var isPresented: Bool
    @State private var scaleAnimation = false
    
    struct AlertAction {
        let title: String
        let style: ButtonVariant
        let action: () -> Void
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissing by tapping outside
                }
            
            // Alert content
            VStack(spacing: 20) {
                // Icon
                Image(systemName: type.icon)
                    .font(.system(size: 48))
                    .foregroundColor(type.iconColor)
                    .scaleEffect(scaleAnimation ? 1.1 : 1.0)
                
                // Title
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Color.hsl(0, 0, 95))
                    .multilineTextAlignment(.center)
                
                // Message
                Text(message)
                    .font(.body)
                    .foregroundColor(Color.hsl(240, 10, 75))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Actions
                HStack(spacing: 12) {
                    if let secondaryAction = secondaryAction {
                        CyberpunkButton(
                            secondaryAction.title,
                            variant: secondaryAction.style,
                            size: .medium
                        ) {
                            secondaryAction.action()
                            isPresented = false
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    CyberpunkButton(
                        primaryAction.title,
                        variant: primaryAction.style,
                        size: .medium
                    ) {
                        primaryAction.action()
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .themePadding(24)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.hsl(240, 10, 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(type.borderColor, lineWidth: 1)
                    )
            )
            .shadow(
                color: type.borderColor.opacity(0.3),
                radius: 20,
                x: 0,
                y: 10
            )
            .scaleEffect(isPresented ? 1 : 0.8)
            .opacity(isPresented ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scaleAnimation = true
                }
            }
        }
        .animation(.spring(response: 0.3), value: isPresented)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Alert banners
            VStack(spacing: 16) {
                Text("Alert Banners")
                    .font(.headline)
                    .foregroundColor(Color.hsl(0, 0, 95))
                
                CyberpunkAlert(
                    title: "Success!",
                    message: "Your changes have been saved successfully.",
                    type: .success
                )
                
                CyberpunkAlert(
                    title: "Error occurred",
                    message: "Failed to connect to the server. Please check your internet connection and try again.",
                    type: .error,
                    actions: [
                        .init(title: "Retry", style: .primary) {
                            print("Retry")
                        },
                        .init(title: "Cancel", style: .ghost) {
                            print("Cancel")
                        }
                    ]
                )
                
                CyberpunkAlert(
                    title: "Warning",
                    message: "Your session will expire in 5 minutes.",
                    type: .warning
                )
                
                CyberpunkAlert(
                    title: "New update available",
                    type: .info,
                    dismissible: false
                )
            }
            
            Divider()
                .background(Color.hsl(240, 10, 20))
            
            // Toast notifications
            VStack(spacing: 16) {
                Text("Toast Notifications")
                    .font(.headline)
                    .foregroundColor(Color.hsl(0, 0, 95))
                
                CyberpunkToast(
                    message: "File uploaded successfully",
                    type: .success
                )
                
                CyberpunkToast(
                    message: "Network error",
                    type: .error
                )
                
                CyberpunkToast(
                    message: "Low battery",
                    type: .warning
                )
                
                CyberpunkToast(
                    message: "3 new messages",
                    type: .info
                )
            }
        }
        .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.hsl(240, 10, 5))
    .overlay(
        // Modal alert preview
        CyberpunkModalAlert(
            title: "Delete Item?",
            message: "This action cannot be undone. Are you sure you want to continue?",
            type: .error,
            primaryAction: .init(title: "Delete", style: .destructive) {
                print("Deleted")
            },
            secondaryAction: .init(title: "Cancel", style: .secondary) {
                print("Cancelled")
            },
            isPresented: .constant(false)
        )
    )
}