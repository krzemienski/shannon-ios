//
//  ErrorView.swift
//  ClaudeCode
//
//  Reusable error display component
//

import SwiftUI

struct ErrorView: View {
    let error: Error
    let retry: (() -> Void)?
    
    private var errorMessage: String {
        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? error.localizedDescription
        }
        return error.localizedDescription
    }
    
    private var recoverySuggestion: String? {
        if let localizedError = error as? LocalizedError {
            return localizedError.recoverySuggestion
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: ThemeSpacing.lg) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.destructive)
                .symbolRenderingMode(.hierarchical)
            
            // Error title
            Text("Something went wrong")
                .font(Theme.Typography.title3Font)
                .foregroundColor(Theme.foreground)
            
            // Error message
            Text(errorMessage)
                .font(Theme.Typography.bodyFont)
                .foregroundColor(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Recovery suggestion if available
            if let suggestion = recoverySuggestion {
                Text(suggestion)
                    .font(Theme.Typography.footnoteFont)
                    .foregroundColor(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ThemeSpacing.lg)
            }
            
            // Retry button if action provided
            if let retry = retry {
                Button(action: retry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(Theme.Typography.calloutFont)
                    .fontWeight(.medium)
                }
                .primaryButtonStyle()
                .padding(.top, ThemeSpacing.sm)
            }
        }
        .padding(ThemeSpacing.xl)
        .frame(maxWidth: 400)
    }
}

// MARK: - Empty State View

struct StandardEmptyStateView: View {
    let icon: String
    let title: String
    let message: String?
    let action: (title: String, handler: () -> Void)?
    
    var body: some View {
        VStack(spacing: ThemeSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(Theme.muted)
                .symbolRenderingMode(.hierarchical)
            
            Text(title)
                .font(Theme.Typography.title3Font)
                .foregroundColor(Theme.foreground)
            
            if let message = message {
                Text(message)
                    .font(Theme.Typography.bodyFont)
                    .foregroundColor(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if let action = action {
                Button(action: action.handler) {
                    Text(action.title)
                        .font(Theme.Typography.calloutFont)
                        .fontWeight(.medium)
                }
                .primaryButtonStyle()
                .padding(.top, ThemeSpacing.sm)
            }
        }
        .padding(ThemeSpacing.xl)
        .frame(maxWidth: 400)
    }
}

#Preview {
    ZStack {
        Theme.background
            .ignoresSafeArea()
        
        VStack(spacing: ThemeSpacing.xxl) {
            ErrorView(
                error: NSError(
                    domain: "Network",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to connect to the server",
                        NSLocalizedRecoverySuggestionErrorKey: "Please check your internet connection and try again."
                    ]
                ),
                retry: {}
            )
            
            Divider()
                .background(Theme.border)
            
            EmptyStateView(
                icon: "message.fill",
                title: "No Conversations",
                message: "Start a new chat to begin using Claude Code",
                action: ("New Chat", {})
            )
        }
    }
}