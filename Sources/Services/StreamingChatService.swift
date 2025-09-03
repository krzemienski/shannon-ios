//
//  StreamingChatService.swift
//  ClaudeCode
//
//  Service for handling SSE streaming chat responses
//

import Foundation
import Combine
import OSLog

/// Service for handling streaming chat responses using Server-Sent Events
@MainActor
final class StreamingChatService {
    
    // MARK: - Properties
    
    private let baseURL: URL
    private let apiKey: String?
    private var sseClient: SSEClient?
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "StreamingChatService")
    
    @Published var error: Error?
    @Published var isStreaming = false
    
    // MARK: - Types
    
    struct StreamingMetrics {
        let totalDuration: TimeInterval
        let tokensReceived: Int
        let timeToFirstToken: TimeInterval
        let success: Bool
    }
    
    // MARK: - Initialization
    
    init(baseURL: URL, apiKey: String?) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
    
    // MARK: - Public Methods
    
    /// Start streaming a chat completion request
    func startStreaming(
        request: ChatCompletionRequest,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (StreamingMetrics) -> Void
    ) async {
        isStreaming = true
        error = nil
        
        let startTime = Date()
        var firstTokenTime: Date?
        var tokenCount = 0
        var accumulatedContent = ""
        
        do {
            // Prepare request URL
            let url = baseURL.appendingPathComponent("/v1/chat/completions")
            
            // Create request
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let apiKey = apiKey {
                urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            
            // Create a new request with streaming enabled
            let streamingRequest = ChatCompletionRequest(
                model: request.model,
                messages: request.messages,
                temperature: request.temperature,
                maxTokens: request.maxTokens,
                topP: request.topP,
                frequencyPenalty: request.frequencyPenalty,
                presencePenalty: request.presencePenalty,
                stream: true,  // Force streaming
                stop: request.stop,
                user: request.user,
                tools: request.tools,
                toolChoice: request.toolChoice
            )
            
            // Encode request body
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(streamingRequest)
            
            // Create SSE client with configuration
            let configuration = SSEConfiguration(
                timeoutInterval: 300,
                reconnectEnabled: true,
                maxReconnectAttempts: 3
            )
            
            sseClient = SSEClient(configuration: configuration)
            
            // Setup SSE event handlers
            sseClient?.onMessage = { [weak self] message in
                guard let self = self else { return }
                
                // Track first token time
                if firstTokenTime == nil {
                    firstTokenTime = Date()
                }
                
                // Parse the SSE message
                if let token = self.parseSSEMessage(message) {
                    tokenCount += 1
                    accumulatedContent += token
                    onToken(token)
                }
            }
            
            sseClient?.onError = { [weak self] error in
                guard let self = self else { return }
                
                self.logger.error("SSE error: \(error)")
                self.error = error
                self.isStreaming = false
                
                // Call completion with error metrics
                let metrics = StreamingMetrics(
                    totalDuration: Date().timeIntervalSince(startTime),
                    tokensReceived: tokenCount,
                    timeToFirstToken: firstTokenTime?.timeIntervalSince(startTime) ?? 0,
                    success: false
                )
                onComplete(metrics)
            }
            
            sseClient?.onComplete = { [weak self] in
                guard let self = self else { return }
                
                self.logger.info("SSE stream completed")
                self.isStreaming = false
                
                // Call completion with final metrics
                let metrics = StreamingMetrics(
                    totalDuration: Date().timeIntervalSince(startTime),
                    tokensReceived: tokenCount,
                    timeToFirstToken: firstTokenTime?.timeIntervalSince(startTime) ?? 0,
                    success: true
                )
                onComplete(metrics)
            }
            
            // Start connection
            await sseClient?.connect(request: urlRequest)
            
        } catch {
            self.error = error
            self.isStreaming = false
            logger.error("Failed to start streaming: \(error)")
            
            // Call completion with error metrics
            let metrics = StreamingMetrics(
                totalDuration: Date().timeIntervalSince(startTime),
                tokensReceived: tokenCount,
                timeToFirstToken: firstTokenTime?.timeIntervalSince(startTime) ?? 0,
                success: false
            )
            onComplete(metrics)
        }
    }
    
    /// Stop the current streaming session
    func stopStreaming() {
        sseClient?.disconnect()
        isStreaming = false
    }
    
    // MARK: - Private Methods
    
    private func parseSSEMessage(_ message: SSEMessage) -> String? {
        // SSE messages for chat completions come in the format:
        // data: {"choices":[{"delta":{"content":"token"},"index":0}],"id":"...","object":"chat.completion.chunk"}
        
        guard message.event == "message" || message.event.isEmpty else {
            return nil
        }
        
        let data = message.data
        guard !data.isEmpty else {
            return nil
        }
        
        // Handle special case for [DONE] message
        if data == "[DONE]" {
            sseClient?.disconnect()
            return nil
        }
        
        // Parse JSON data
        guard let jsonData = data.data(using: .utf8) else {
            return nil
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let delta = firstChoice["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                return content
            }
        } catch {
            logger.error("Failed to parse SSE message: \(error)")
        }
        
        return nil
    }
}

// Removed extension - ChatCompletionRequest now has proper stream property