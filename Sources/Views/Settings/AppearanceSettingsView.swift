// MVP: Simplified appearance settings view to avoid compilation errors
import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var selectedTheme = "Dark"
    @State private var selectedAccentColor = "Blue"
    @State private var fontSize: Double = 14
    
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme", selection: $selectedTheme) {
                    Text("Dark").tag("Dark")
                    Text("Light").tag("Light")
                    Text("System").tag("System")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section("Accent Color") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(["Blue", "Purple", "Green", "Orange", "Red"], id: \.self) { color in
                            Button {
                                selectedAccentColor = color
                            } label: {
                                Circle()
                                    .fill(Color(color.lowercased()))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                selectedAccentColor == color ? Color.white : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section("Font Size") {
                HStack {
                    Text("Size: \(Int(fontSize))pt")
                        .foregroundColor(Theme.mutedForeground)
                    Spacer()
                    Slider(value: $fontSize, in: 12...20, step: 1)
                        .frame(width: 150)
                }
            }
            
            Section("Preview") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sample Text")
                        .font(.system(size: CGFloat(fontSize)))
                    Text("This is how your text will appear")
                        .font(.system(size: CGFloat(fontSize)))
                        .foregroundColor(Theme.mutedForeground)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.large)
    }
}