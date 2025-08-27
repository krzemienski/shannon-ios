//
//  SplitViews.swift
//  ClaudeCode
//
//  Split view components for terminal multiplexing
//

import SwiftUI

/// Horizontal split view for terminal sessions
public struct HSplitView<Content: View>: View {
    let content: Content
    @State private var splitRatio: CGFloat = 0.5
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // First pane
                content
                    .frame(width: geometry.size.width * splitRatio)
                
                // Divider
                Divider()
                    .frame(width: 2)
                    .background(Theme.border)
                    .overlay(
                        Image(systemName: "line.3.horizontal")
                            .font(.caption)
                            .foregroundColor(Theme.muted)
                            .rotationEffect(.degrees(90))
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newRatio = value.location.x / geometry.size.width
                                splitRatio = max(0.2, min(0.8, newRatio))
                            }
                    )
                
                // Second pane
                content
                    .frame(width: geometry.size.width * (1 - splitRatio))
            }
        }
    }
}

/// Vertical split view for terminal sessions
public struct VSplitView<Content: View>: View {
    let content: Content
    @State private var splitRatio: CGFloat = 0.5
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // First pane
                content
                    .frame(height: geometry.size.height * splitRatio)
                
                // Divider
                Divider()
                    .frame(height: 2)
                    .background(Theme.border)
                    .overlay(
                        Image(systemName: "line.3.horizontal")
                            .font(.caption)
                            .foregroundColor(Theme.muted)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newRatio = value.location.y / geometry.size.height
                                splitRatio = max(0.2, min(0.8, newRatio))
                            }
                    )
                
                // Second pane
                content
                    .frame(height: geometry.size.height * (1 - splitRatio))
            }
        }
    }
}