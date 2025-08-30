import SwiftUI
import OSLog

/// Debug view for testing backend connectivity
struct BackendTestView: View {
    @State private var healthStatus = "Not checked"
    @State private var modelsStatus = "Not checked"
    @State private var chatStatus = "Not checked"
    @State private var isLoading = false
    @State private var lastError: String?
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "BackendTest")
    private let apiClient = APIClient.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Backend Info
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Backend URL", systemImage: "server.rack")
                                .font(.headline)
                            Text(APIConfig.baseURL.absoluteString)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Health Check
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Health Check", systemImage: "heart.fill")
                                    .font(.headline)
                                Spacer()
                                statusIcon(for: healthStatus)
                            }
                            
                            Text("/health endpoint")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Test Health") {
                                Task {
                                    await testHealthEndpoint()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading)
                            
                            if healthStatus != "Not checked" {
                                Text(healthStatus)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Models Check
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Models Endpoint", systemImage: "cpu")
                                    .font(.headline)
                                Spacer()
                                statusIcon(for: modelsStatus)
                            }
                            
                            Text("/models endpoint")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Test Models") {
                                Task {
                                    await testModelsEndpoint()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading)
                            
                            if modelsStatus != "Not checked" {
                                Text(modelsStatus)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Chat Test
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Chat Streaming", systemImage: "message.fill")
                                    .font(.headline)
                                Spacer()
                                statusIcon(for: chatStatus)
                            }
                            
                            Text("/chat/completions SSE endpoint")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Test Chat Stream") {
                                Task {
                                    await testChatStream()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading)
                            
                            if chatStatus != "Not checked" {
                                Text(chatStatus)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Error Display
                    if let error = lastError {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Last Error", systemImage: "exclamationmark.triangle.fill")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                
                                Text(error)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.red)
                                    .padding(8)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Instructions
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Backend Setup", systemImage: "info.circle")
                                .font(.headline)
                            
                            Text("""
                            1. Clone: git clone https://github.com/ruvnet/claude-code-api
                            2. Setup: cd claude-code-api && make install
                            3. Start: make start
                            4. The backend should be running at http://localhost:8000
                            """)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("Backend Test")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                    }
                }
            }
        }
    }
    
    private func statusIcon(for status: String) -> some View {
        Group {
            if status.contains("✅") || status.lowercased().contains("success") || status.lowercased().contains("healthy") {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if status.contains("❌") || status.lowercased().contains("error") || status.lowercased().contains("fail") {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            } else if status == "Not checked" {
                Image(systemName: "minus.circle")
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.orange)
            }
        }
    }
    
    private func testHealthEndpoint() async {
        isLoading = true
        lastError = nil
        
        do {
            logger.info("Testing health endpoint...")
            let healthy = await apiClient.checkHealth()
            
            if healthy {
                healthStatus = "✅ Backend is healthy"
                logger.info("Backend is healthy")
            } else {
                healthStatus = "❌ Backend unhealthy"
                logger.error("Backend is not healthy")
            }
        } catch {
            healthStatus = "❌ Error: \(error.localizedDescription)"
            lastError = error.localizedDescription
            logger.error("Health check failed: \(error)")
        }
        
        isLoading = false
    }
    
    private func testModelsEndpoint() async {
        isLoading = true
        lastError = nil
        
        do {
            logger.info("Testing models endpoint...")
            let models = try await apiClient.fetchModels()
            
            if !models.isEmpty {
                modelsStatus = "✅ Found \(models.count) models:\n" + models.map { "• \($0.id)" }.joined(separator: "\n")
                logger.info("Found \(models.count) models")
            } else {
                modelsStatus = "⚠️ No models returned"
                logger.warning("No models returned from API")
            }
        } catch {
            modelsStatus = "❌ Error: \(error.localizedDescription)"
            lastError = error.localizedDescription
            logger.error("Models fetch failed: \(error)")
        }
        
        isLoading = false
    }
    
    private func testChatStream() async {
        isLoading = true
        lastError = nil
        chatStatus = "🔄 Testing..."
        
        do {
            logger.info("Testing chat stream...")
            
            let request = ChatCompletionRequest(
                model: "claude-3-5-sonnet-20241022",
                messages: [
                    ChatMessage(role: "user", content: "Say 'Hello, Claude Code!' in 5 words or less.")
                ],
                stream: true,
                maxTokens: 50
            )
            
            var chunks: [String] = []
            var completed = false
            
            let sseClient = SSEClient()
            
            await apiClient.streamChatCompletion(
                request: request,
                onChunk: { chunk in
                    if let content = chunk.choices.first?.delta.content {
                        chunks.append(content)
                        logger.info("Received chunk: \(content)")
                    }
                },
                onComplete: {
                    completed = true
                    logger.info("Stream completed")
                },
                onError: { error in
                    chatStatus = "❌ Stream error: \(error.localizedDescription)"
                    lastError = error.localizedDescription
                    logger.error("Stream error: \(error)")
                }
            )
            
            // Wait a bit for streaming to complete
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            if completed && !chunks.isEmpty {
                let response = chunks.joined()
                chatStatus = "✅ Stream successful!\nResponse: \(response)"
                logger.info("Chat stream successful: \(response)")
            } else if chunks.isEmpty {
                chatStatus = "⚠️ No response received"
                logger.warning("No chunks received from stream")
            }
            
        } catch {
            chatStatus = "❌ Error: \(error.localizedDescription)"
            lastError = error.localizedDescription
            logger.error("Chat stream test failed: \(error)")
        }
        
        isLoading = false
    }
}

#Preview {
    BackendTestView()
}