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
                    ownedBy: "anthropic"
                ),
                APIModel(
                    id: "claude-opus-4",
                    object: "model",
                    created: Int(Date().timeIntervalSince1970),
                    ownedBy: "anthropic"
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
                        role: "assistant",
                        content: "This is a mock response for testing. The backend is not currently running.",
                        name: nil,
                        toolCalls: nil,
                        toolCallId: nil
                    ),
                    finishReason: "stop",
                    logprobs: nil
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
            title: "Mock Session",
            createdAt: Date(),
            updatedAt: Date(),
            messageCount: 3,
            model: "claude-sonnet-4",
            metadata: nil
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