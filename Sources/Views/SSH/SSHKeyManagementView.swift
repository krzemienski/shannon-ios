// MVP: Simplified SSH key management view to avoid compilation errors
import SwiftUI

struct SSHKeyManagementView: View {
    @State private var keys: [String] = ["Default Key", "Server Key"]
    @State private var showAddKey = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(keys, id: \.self) { key in
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(Theme.primary)
                        
                        VStack(alignment: .leading) {
                            Text(key)
                                .font(.headline)
                            Text("RSA 2048-bit")
                                .font(.caption)
                                .foregroundColor(Theme.mutedForeground)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Theme.mutedForeground)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    keys.remove(atOffsets: indexSet)
                }
            }
            .navigationTitle("SSH Keys")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddKey = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddKey) {
                NavigationStack {
                    Form {
                        Section("Key Details") {
                            TextField("Key Name", text: .constant(""))
                            TextEditor(text: .constant(""))
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 100)
                        }
                    }
                    .navigationTitle("Add SSH Key")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showAddKey = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                keys.append("New Key \(keys.count + 1)")
                                showAddKey = false
                            }
                        }
                    }
                }
            }
        }
    }
}