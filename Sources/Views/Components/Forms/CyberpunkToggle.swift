//
//  CyberpunkToggle.swift
//  ClaudeCode
//
//  Custom toggle switch with cyberpunk styling
//

import SwiftUI

/// Custom cyberpunk-styled toggle switch
struct CyberpunkToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let icon: String?
    let onChange: ((Bool) -> Void)?
    
    @State private var dragOffset: CGFloat = 0
    @State private var glowAnimation = false
    
    private let toggleWidth: CGFloat = 52
    private let toggleHeight: CGFloat = 32
    private let knobSize: CGFloat = 28
    
    init(
        _ title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        icon: String? = nil,
        onChange: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.icon = icon
        self.onChange = onChange
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isOn ? Color.hsl(142, 70, 45) : Color.hsl(240, 10, 45))
                    .frame(width: 24)
            }
            
            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.hsl(0, 0, 95))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color.hsl(240, 10, 65))
                }
            }
            
            Spacer()
            
            // Toggle Switch
            ZStack(alignment: isOn ? .trailing : .leading) {
                // Track
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: isOn ? [
                                Color.hsl(142, 70, 25),
                                Color.hsl(142, 70, 35)
                            ] : [
                                Color.hsl(240, 10, 15),
                                Color.hsl(240, 10, 20)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: toggleWidth, height: toggleHeight)
                    .overlay(
                        Capsule()
                            .stroke(
                                isOn ? Color.hsl(142, 70, 45) : Color.hsl(240, 10, 30),
                                lineWidth: 1
                            )
                    )
                
                // Knob
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isOn ? [
                                Color.hsl(142, 70, 55),
                                Color.hsl(142, 70, 45)
                            ] : [
                                Color.hsl(240, 10, 70),
                                Color.hsl(240, 10, 60)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Circle()
                            .stroke(
                                isOn ? Color.hsl(142, 70, 60) : Color.hsl(240, 10, 40),
                                lineWidth: 0.5
                            )
                    )
                    .overlay(
                        // Inner glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(isOn ? 0.3 : 0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: knobSize / 2
                                )
                            )
                            .scaleEffect(glowAnimation ? 1.1 : 1.0)
                    )
                    .offset(x: dragOffset)
                    .padding(2)
                
                // Status indicators
                HStack {
                    if !isOn {
                        Text("OFF")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.hsl(240, 10, 45))
                            .padding(.leading, 6)
                    }
                    
                    Spacer()
                    
                    if isOn {
                        Text("ON")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.hsl(142, 70, 70))
                            .padding(.trailing, 8)
                    }
                }
                .frame(width: toggleWidth - 4)
            }
            .shadow(
                color: isOn ? Color.hsl(142, 70, 45).opacity(0.4) : Color.clear,
                radius: 8,
                x: 0,
                y: 0
            )
            .onTapGesture {
                toggleState()
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        let maxOffset = toggleWidth - toggleHeight
                        
                        if isOn {
                            dragOffset = min(0, max(-maxOffset, translation))
                        } else {
                            dragOffset = max(0, min(maxOffset, translation))
                        }
                    }
                    .onEnded { value in
                        let threshold = toggleWidth / 4
                        
                        if abs(value.translation.width) > threshold {
                            if (isOn && value.translation.width < 0) ||
                               (!isOn && value.translation.width > 0) {
                                // Don't toggle, just reset
                                withAnimation(.spring(response: 0.3)) {
                                    dragOffset = 0
                                }
                            } else {
                                toggleState()
                            }
                        } else {
                            withAnimation(.spring(response: 0.3)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .animation(.spring(response: 0.3), value: isOn)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
    
    private func toggleState() {
        withAnimation(.spring(response: 0.3)) {
            isOn.toggle()
            dragOffset = 0
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        onChange?(isOn)
    }
}

/// Compact toggle for inline use
struct CyberpunkCompactToggle: View {
    @Binding var isOn: Bool
    let onChange: ((Bool) -> Void)?
    
    private let toggleWidth: CGFloat = 44
    private let toggleHeight: CGFloat = 24
    private let knobSize: CGFloat = 20
    
    init(
        isOn: Binding<Bool>,
        onChange: ((Bool) -> Void)? = nil
    ) {
        self._isOn = isOn
        self.onChange = onChange
    }
    
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(
                    isOn ? Color.hsl(142, 70, 35) : Color.hsl(240, 10, 20)
                )
                .frame(width: toggleWidth, height: toggleHeight)
            
            Circle()
                .fill(Color.white)
                .frame(width: knobSize, height: knobSize)
                .padding(2)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                isOn.toggle()
            }
            onChange?(isOn)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 32) {
        VStack(spacing: 20) {
            CyberpunkToggle(
                "Enable Notifications",
                subtitle: "Receive push notifications for updates",
                isOn: .constant(true),
                icon: "bell.fill"
            )
            
            CyberpunkToggle(
                "Dark Mode",
                subtitle: "Use dark theme throughout the app",
                isOn: .constant(false),
                icon: "moon.fill"
            )
            
            CyberpunkToggle(
                "Auto-save",
                isOn: .constant(true),
                icon: "square.and.arrow.down.fill"
            )
            
            CyberpunkToggle(
                "Developer Mode",
                subtitle: "Enable advanced features and debugging",
                isOn: .constant(false),
                icon: "hammer.fill"
            )
        }
        
        Divider()
            .background(Color.hsl(240, 10, 20))
        
        HStack {
            Text("Compact Toggle:")
                .foregroundColor(Color.hsl(240, 10, 65))
            CyberpunkCompactToggle(isOn: .constant(true))
            CyberpunkCompactToggle(isOn: .constant(false))
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.hsl(240, 10, 5))
}