import Foundation

// MARK: - Response Models for API Client (Tasks 301-500)
// Note: Most response models are defined in their respective model files:
// - SessionModels.swift: SessionsResponse, CreateSessionRequest
// - ProjectModels.swift: ProjectsResponse, CreateProjectRequest, DeleteResponse
// - ToolModels.swift: ToolsResponse, ToolExecutionRequest, ToolExecutionResponse
// - SSHModels.swift: SSHSessionsResponse, SSHSessionRequest, SSHCommandRequest, SSHCommandResponse

// This file contains mock data support and any missing response models

// MARK: - Mock Data Support for Testing (Task 332)

/// Mock response provider for testing without backend
public struct MockResponseProvider {
    public static func mockModelsResponse() -> ModelsResponse {
        ModelsResponse(
            object: "list",
            data: [
                APIModel(
                    id: "claude-sonnet-4",
                    object: "model",
                    created: Int(Date().timeIntervalSince1970),
                    ownedBy: "anthropic",
                    capabilities: ModelCapabilities(
                        contextWindow: 200000,
                        maxOutputTokens: 8192,
                        supportsFunctions: true,
                        supportsVision: true,
                        supportsStreaming: true,
                        supportsSystemMessage: true,
                        supportsToolUse: true
                    )
                ),
                APIModel(
                    id: "claude-opus-4",
                    object: "model",
                    created: Int(Date().timeIntervalSince1970),
                    ownedBy: "anthropic",
                    capabilities: ModelCapabilities(
                        contextWindow: 200000,
                        maxOutputTokens: 8192,
                        supportsFunctions: true,
                        supportsVision: true,
                        supportsStreaming: true,
                        supportsSystemMessage: true,
                        supportsToolUse: true
                    )
                )
            ]
        )
    }
    
    public static func mockChatCompletionResponse(for request: ChatCompletionRequest) -> ChatCompletionResponse {
        ChatCompletionResponse(
            id: "chatcmpl-\(UUID().uuidString)",
            object: "chat.completion",
            created: Int(Date().timeIntervalSince1970),
            model: request.model,
            choices: [
                ChatChoice(
                    index: 0,
                    message: ChatMessage(
                        role: .assistant,
                        content: "This is a mock response for testing. The backend is not currently running."
                    ),
                    logprobs: nil,
                    finishReason: "stop"
                )
            ],
            usage: Usage(
                promptTokens: 10,
                completionTokens: 15,
                totalTokens: 25
            ),
            systemFingerprint: "mock-fingerprint"
        )
    }
    
    public static func mockSessionInfo() -> SessionInfo {
        SessionInfo(
            id: UUID().uuidString,
            name: "Mock Session",
            messages: [
                ChatMessage(role: .system, content: "You are a helpful assistant."),
                ChatMessage(role: .user, content: "Hello!"),
                ChatMessage(role: .assistant, content: "Hello! How can I help you today?")
            ],
            metadata: SessionMetadata(
                model: "claude-sonnet-4",
                temperature: 0.7,
                maxTokens: 2048
            ),
            stats: SessionStats(
                messageCount: 3,
                totalTokens: 25,
                inputTokens: 10,
                outputTokens: 15,
                totalCost: 0.0001
            )
        )
    }
    
    public static func mockSSEChunks() -> [String] {
        [
            "data: {\"id\":\"chatcmpl-test\",\"object\":\"chat.completion.chunk\",\"created\":1234567890,\"model\":\"claude-sonnet-4\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\",\"content\":\"Hello\"},\"finish_reason\":null}]}\n\n",
            "data: {\"id\":\"chatcmpl-test\",\"object\":\"chat.completion.chunk\",\"created\":1234567890,\"model\":\"claude-sonnet-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" world\"},\"finish_reason\":null}]}\n\n",
            "data: {\"id\":\"chatcmpl-test\",\"object\":\"chat.completion.chunk\",\"created\":1234567890,\"model\":\"claude-sonnet-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"!\"},\"finish_reason\":null}]}\n\n",
            "data: {\"id\":\"chatcmpl-test\",\"object\":\"chat.completion.chunk\",\"created\":1234567890,\"model\":\"claude-sonnet-4\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n",
            "data: [DONE]\n\n"
        ]
    }
}