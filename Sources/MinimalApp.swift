//
//  MinimalApp.swift
//  ClaudeCode
//
//  Minimal app for functional UI testing
//

import SwiftUI

@main
struct ClaudeCodeApp: App {
    var body: some Scene {
        WindowGroup {
            MainTestView()
        }
    }
}

struct MainTestView: View {
    @State private var apiResponse: String = "Not tested"
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Claude Code iOS")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Functional UI Test")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // API Test Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Backend Connection Test")
                        .font(.headline)
                    
                    Text("Status: \(apiResponse)")
                        .font(.body)
                        .foregroundColor(apiResponse.contains("Success") ? .green : .orange)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    
                    Button(action: testBackendConnection) {
                        Label("Test Backend", systemImage: "network")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    Button(action: testChatEndpoint) {
                        Label("Test Chat API", systemImage: "message")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Test Suite")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func testBackendConnection() {
        isLoading = true
        apiResponse = "Testing..."
        
        guard let url = URL(string: "http://localhost:8000/v1/health") else {
            apiResponse = "Invalid URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    apiResponse = "Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        apiResponse = "✅ Success: Backend is running!"
                    } else {
                        apiResponse = "❌ HTTP \(httpResponse.statusCode)"
                    }
                } else {
                    apiResponse = "Invalid response"
                }
            }
        }.resume()
    }
    
    func testChatEndpoint() {
        isLoading = true
        apiResponse = "Testing chat..."
        
        guard let url = URL(string: "http://localhost:8000/v1/chat/completions") else {
            apiResponse = "Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer test-key", forHTTPHeaderField: "Authorization")
        
        let body = [
            "model": "claude-3-5-sonnet-20241022",
            "messages": [
                ["role": "user", "content": "Say hello"]
            ],
            "stream": false
        ] as [String : Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            apiResponse = "JSON error: \(error)"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    apiResponse = "Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        apiResponse = "✅ Chat API working!"
                    } else {
                        apiResponse = "❌ Chat API: HTTP \(httpResponse.statusCode)"
                    }
                } else {
                    apiResponse = "Invalid response"
                }
            }
        }.resume()
    }
}

struct MainTestView_Previews: PreviewProvider {
    static var previews: some View {
        MainTestView()
    }
}