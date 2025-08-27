//
//  CyberpunkSlider.swift
//  ClaudeCode
//
//  Custom slider with cyberpunk styling
//

import SwiftUI

/// Custom cyberpunk-styled slider
struct CyberpunkSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    let label: String?
    let showValue: Bool
    let valueFormat: String
    let thumbSize: CGFloat
    let trackHeight: CGFloat
    let variant: BadgeVariant
    let onChange: ((Double) -> Void)?
    
    @State private var isDragging = false
    @State private var glowAnimation = false
    
    private var normalizedValue: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
    
    private var formattedValue: String {
        String(format: valueFormat, value)
    }
    
    init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...100,
        step: Double? = nil,
        label: String? = nil,
        showValue: Bool = true,
        valueFormat: String = "%.0f",
        thumbSize: CGFloat = 24,
        trackHeight: CGFloat = 6,
        variant: BadgeVariant = .primary,
        onChange: ((Double) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.label = label
        self.showValue = showValue
        self.valueFormat = valueFormat
        self.thumbSize = thumbSize
        self.trackHeight = trackHeight
        self.variant = variant
        self.onChange = onChange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label and value
            if label != nil || showValue {
                HStack {
                    if let label = label {
                        Text(label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.hsl(0, 0, 95))
                    }
                    
                    Spacer()
                    
                    if showValue {
                        Text(formattedValue)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(sliderColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(sliderColor.opacity(0.2))
                            )
                    }
                }
            }
            
            // Slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.hsl(240, 10, 15))
                        .frame(height: trackHeight)
                        .overlay(
                            Capsule()
                                .stroke(Color.hsl(240, 10, 25), lineWidth: 1)
                        )
                    
                    // Progress track
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    sliderColor.opacity(0.8),
                                    sliderColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(0, geometry.size.width * normalizedValue),
                            height: trackHeight
                        )
                        .shadow(
                            color: sliderColor.opacity(glowAnimation ? 0.6 : 0.3),
                            radius: 4,
                            x: 0,
                            y: 0
                        )
                    
                    // Thumb
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    sliderColor,
                                    sliderColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: thumbSize, height: thumbSize)
                        .overlay(
                            Circle()
                                .stroke(
                                    isDragging ? sliderColor.opacity(0.8) : Color.hsl(240, 10, 30),
                                    lineWidth: 2
                                )
                        )
                        .overlay(
                            // Inner dot
                            Circle()
                                .fill(Color.white)
                                .frame(width: thumbSize * 0.3, height: thumbSize * 0.3)
                        )
                        .scaleEffect(isDragging ? 1.2 : 1.0)
                        .shadow(
                            color: sliderColor.opacity(isDragging ? 0.6 : 0.3),
                            radius: isDragging ? 8 : 4,
                            x: 0,
                            y: 0
                        )
                        .offset(x: max(0, min(geometry.size.width - thumbSize, geometry.size.width * normalizedValue - thumbSize / 2)))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    isDragging = true
                                    updateValue(for: gesture.location.x, in: geometry.size.width)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                }
                .frame(height: thumbSize)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    updateValue(for: location.x, in: geometry.size.width)
                }
            }
            .frame(height: thumbSize)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
    
    private func updateValue(for location: CGFloat, in width: CGFloat) {
        let newNormalizedValue = max(0, min(1, location / width))
        var newValue = range.lowerBound + (range.upperBound - range.lowerBound) * newNormalizedValue
        
        // Apply step if specified
        if let step = step, step > 0 {
            newValue = round(newValue / step) * step
        }
        
        // Clamp to range
        newValue = max(range.lowerBound, min(range.upperBound, newValue))
        
        if newValue != value {
            value = newValue
            onChange?(newValue)
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private var sliderColor: Color {
        switch variant {
        case .primary, .success:
            return Color.hsl(142, 70, 45)
        case .warning:
            return Color.hsl(45, 80, 60)
        case .error:
            return Color.hsl(0, 80, 60)
        case .info:
            return Color.hsl(201, 70, 50)
        default:
            return Color.hsl(240, 10, 65)
        }
    }
}

/// Range slider with two thumbs
struct CyberpunkRangeSlider: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let range: ClosedRange<Double>
    let step: Double?
    let label: String?
    let showValues: Bool
    let valueFormat: String
    let variant: BadgeVariant
    
    @State private var isDraggingLower = false
    @State private var isDraggingUpper = false
    
    init(
        lowerValue: Binding<Double>,
        upperValue: Binding<Double>,
        in range: ClosedRange<Double> = 0...100,
        step: Double? = nil,
        label: String? = nil,
        showValues: Bool = true,
        valueFormat: String = "%.0f",
        variant: BadgeVariant = .primary
    ) {
        self._lowerValue = lowerValue
        self._upperValue = upperValue
        self.range = range
        self.step = step
        self.label = label
        self.showValues = showValues
        self.valueFormat = valueFormat
        self.variant = variant
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label and values
            if label != nil || showValues {
                HStack {
                    if let label = label {
                        Text(label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.hsl(0, 0, 95))
                    }
                    
                    Spacer()
                    
                    if showValues {
                        Text("\(String(format: valueFormat, lowerValue)) - \(String(format: valueFormat, upperValue))")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(sliderColor)
                    }
                }
            }
            
            // Range slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.hsl(240, 10, 15))
                        .frame(height: 6)
                    
                    // Selected range
                    Capsule()
                        .fill(sliderColor)
                        .frame(
                            width: max(0, (normalizedUpper - normalizedLower) * geometry.size.width),
                            height: 6
                        )
                        .offset(x: normalizedLower * geometry.size.width)
                    
                    // Lower thumb
                    SliderThumb(
                        color: sliderColor,
                        isDragging: isDraggingLower
                    )
                    .offset(x: max(0, min(geometry.size.width - 24, normalizedLower * geometry.size.width - 12)))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                isDraggingLower = true
                                updateLowerValue(for: gesture.location.x, in: geometry.size.width)
                            }
                            .onEnded { _ in
                                isDraggingLower = false
                            }
                    )
                    
                    // Upper thumb
                    SliderThumb(
                        color: sliderColor,
                        isDragging: isDraggingUpper
                    )
                    .offset(x: max(0, min(geometry.size.width - 24, normalizedUpper * geometry.size.width - 12)))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                isDraggingUpper = true
                                updateUpperValue(for: gesture.location.x, in: geometry.size.width)
                            }
                            .onEnded { _ in
                                isDraggingUpper = false
                            }
                    )
                }
                .frame(height: 24)
            }
            .frame(height: 24)
        }
    }
    
    private var normalizedLower: Double {
        (lowerValue - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
    
    private var normalizedUpper: Double {
        (upperValue - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
    
    private func updateLowerValue(for location: CGFloat, in width: CGFloat) {
        let newNormalizedValue = max(0, min(1, location / width))
        var newValue = range.lowerBound + (range.upperBound - range.lowerBound) * newNormalizedValue
        
        if let step = step, step > 0 {
            newValue = round(newValue / step) * step
        }
        
        lowerValue = min(newValue, upperValue)
    }
    
    private func updateUpperValue(for location: CGFloat, in width: CGFloat) {
        let newNormalizedValue = max(0, min(1, location / width))
        var newValue = range.lowerBound + (range.upperBound - range.lowerBound) * newNormalizedValue
        
        if let step = step, step > 0 {
            newValue = round(newValue / step) * step
        }
        
        upperValue = max(newValue, lowerValue)
    }
    
    private var sliderColor: Color {
        switch variant {
        case .primary, .success:
            return Color.hsl(142, 70, 45)
        default:
            return Color.hsl(240, 10, 65)
        }
    }
}

private struct SliderThumb: View {
    let color: Color
    let isDragging: Bool
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .stroke(Color.hsl(240, 10, 30), lineWidth: 2)
            )
            .overlay(
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
            )
            .scaleEffect(isDragging ? 1.2 : 1.0)
            .shadow(
                color: color.opacity(isDragging ? 0.6 : 0.3),
                radius: isDragging ? 8 : 4
            )
    }
}

// MARK: - Preview
#Preview {
    struct SliderPreview: View {
        @State private var value1: Double = 50
        @State private var value2: Double = 75
        @State private var value3: Double = 30
        @State private var value4: Double = 60
        @State private var rangeMin: Double = 25
        @State private var rangeMax: Double = 75
        
        var body: some View {
            ScrollView {
                VStack(spacing: 32) {
                    // Basic sliders
                    VStack(spacing: 24) {
                        Text("Basic Sliders")
                            .font(.headline)
                            .foregroundColor(Color.hsl(0, 0, 95))
                        
                        CyberpunkSlider(
                            value: $value1,
                            label: "Volume"
                        )
                        
                        CyberpunkSlider(
                            value: $value2,
                            in: 0...100,
                            step: 5,
                            label: "Brightness",
                            variant: .info
                        )
                        
                        CyberpunkSlider(
                            value: $value3,
                            in: 0...100,
                            label: "Battery",
                            variant: value3 < 20 ? .error : value3 < 50 ? .warning : .success
                        )
                        
                        CyberpunkSlider(
                            value: $value4,
                            in: 0...100,
                            label: "Progress",
                            valueFormat: "%.1f%%",
                            thumbSize: 28,
                            trackHeight: 10
                        )
                    }
                    
                    Divider()
                        .background(Color.hsl(240, 10, 20))
                    
                    // Range slider
                    VStack(spacing: 24) {
                        Text("Range Slider")
                            .font(.headline)
                            .foregroundColor(Color.hsl(0, 0, 95))
                        
                        CyberpunkRangeSlider(
                            lowerValue: $rangeMin,
                            upperValue: $rangeMax,
                            in: 0...100,
                            step: 1,
                            label: "Price Range"
                        )
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.hsl(240, 10, 5))
        }
    }
    
    return SliderPreview()
}