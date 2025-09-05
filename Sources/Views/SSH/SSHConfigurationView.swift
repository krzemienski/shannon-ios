// MVP: Simplified SSH configuration view to avoid compilation errors
import SwiftUI

struct SSHConfigurationView: View {
    var onConnect: ((String) -> Void)?
    var onSave: ((String) -> Void)?
    
    @State private var hostname = ""
    @State private var username = ""
    @State private var password = ""
    @State private var port = "22"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Connection Details") {
                    TextField("Hostname", text: $hostname)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                    
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }
                
                Section("Actions") {
                    Button {
                        let config = "\(username)@\(hostname):\(port)"
                        onConnect?(config)
                        dismiss()
                    } label: {
                        Label("Connect", systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(hostname.isEmpty || username.isEmpty)
                    
                    Button {
                        let config = "\(username)@\(hostname):\(port)"
                        onSave?(config)
                        dismiss()
                    } label: {
                        Label("Save Configuration", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(hostname.isEmpty || username.isEmpty)
                }
            }
            .navigationTitle("SSH Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}