import Foundation

// MARK: - Task 179: Model Factory Extensions

// MARK: - Message Factory
extension ChatMessage {
    /// Create a system message
    public static func system(_ content: String) -> ChatMessage {
        return ChatMessage(
            role: "system",
            content: content
        )
    }
    
    /// Create a user message
    public static func user(_ content: String) -> ChatMessage {
        return ChatMessage(
            role: "user",
            content: content
        )
    }
    
    /// Create an assistant message
    public static func assistant(_ content: String) -> ChatMessage {
        return ChatMessage(
            role: "assistant",
            content: content
        )
    }
    
    /// Create a tool call result message
    public static func toolResult(_ result: String, toolCallId: String) -> ChatMessage {
        return ChatMessage(
            role: "tool",
            content: result,
            toolCallId: toolCallId
        )
    }
}

// MARK: - Session Factory
extension ChatSession {
    /// Create a new session with an initial system message
    public static func withSystemPrompt(_ prompt: String) -> ChatSession {
        return ChatSession(
            id: UUID().uuidString,
            title: "New Session",
            lastMessage: prompt,
            timestamp: Date(),
            icon: "message.circle.fill",
            tags: ["system"]
        )
    }
    
    /// Create a quick chat session
    public static func quickChat() -> ChatSession {
        return ChatSession(
            id: UUID().uuidString,
            title: "Quick Chat",
            lastMessage: "Start a conversation...",
            timestamp: Date(),
            icon: "bubble.left.and.bubble.right.fill",
            tags: ["quick"]
        )
    }
}

// MARK: - Project Factory
extension Project {
    /// Create a new Swift project
    public static func swiftProject(name: String, path: String) -> Project {
        return Project(
            id: UUID().uuidString,
            name: name,
            path: path,
            type: .ios,
            description: "Swift iOS project",
            isActive: false,
            sshConfig: nil,
            environmentVariables: nil,
            createdAt: Date(),
            lastAccessedAt: Date()
        )
    }
    
    /// Create a new JavaScript project
    public static func javascriptProject(name: String, path: String) -> Project {
        return Project(
            id: UUID().uuidString,
            name: name,
            path: path,
            type: .web,
            description: "JavaScript web project",
            isActive: false,
            sshConfig: nil,
            environmentVariables: nil,
            createdAt: Date(),
            lastAccessedAt: Date()
        )
    }
    
    /// Create a new Python project
    public static func pythonProject(name: String, path: String) -> Project {
        return Project(
            id: UUID().uuidString,
            name: name,
            path: path,
            type: .backend,
            description: "Python backend project",
            isActive: false,
            sshConfig: nil,
            environmentVariables: nil,
            createdAt: Date(),
            lastAccessedAt: Date()
        )
    }
}

// MARK: - Tool Factory
extension Tool {
    /// Create a file system tool
    public static func fileSystem() -> Tool {
        return Tool(
            id: "file_system",
            name: "File System",
            description: "Access and modify project files",
            category: .fileSystem,
            icon: "folder",
            parameters: []
        )
    }
    
    /// Create a terminal tool
    public static func terminal() -> Tool {
        return Tool(
            id: "terminal",
            name: "Terminal",
            description: "Execute shell commands",
            category: .shell,
            icon: "terminal",
            parameters: []
        )
    }
    
    /// Create an analysis tool
    public static func codeAnalyzer() -> Tool {
        return Tool(
            id: "analyzer",
            name: "Code Analyzer",
            description: "Analyze code quality and metrics",
            category: .search,
            icon: "magnifyingglass",
            parameters: []
        )
    }
}

// MARK: - Model Config Factory
extension ModelConfig {
    /// Create a GPT-4 model configuration
    public static func gpt4() -> ModelConfig {
        return ModelConfig(
            id: "gpt-4",
            name: "GPT-4",
            provider: "OpenAI",
            status: .available,
            contextWindow: 8192,
            maxTokens: 4096,
            supportedFeatures: ["chat", "functions"],
            capabilities: ["streaming", "function_calling", "code_generation"]
        )
    }
    
    /// Create a Claude model configuration
    public static func claude3() -> ModelConfig {
        return ModelConfig(
            id: "claude-3",
            name: "Claude 3",
            provider: "Anthropic",
            status: .available,
            contextWindow: 100000,
            maxTokens: 4096,
            supportedFeatures: ["chat", "vision"],
            capabilities: ["streaming", "vision", "code_generation"]
        )
    }
}

// MARK: - Error Factory
extension APIError {
    /// Create a network error
    public static func networkError(_ message: String = "Network connection failed") -> APIError {
        return .networkError(NSError(
            domain: "Network",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        ))
    }
    
    /// Create an authentication error
    public static func authenticationError(_ message: String = "Authentication failed") -> APIError {
        return .authenticationFailed
    }
    
    /// Create a rate limit error
    public static func rateLimitError() -> APIError {
        return .rateLimitExceeded
    }
}

// MARK: - File Tree Factory
extension FileTreeNode {
    /// Create a mock file tree for testing
    public static func mockTree() -> FileTreeNode {
        return FileTreeNode(
            name: "Project",
            path: "/",
            isDirectory: true,
            children: [
                FileTreeNode(
                    name: "src",
                    path: "/src",
                    isDirectory: true,
                    children: [
                        FileTreeNode(
                            name: "main.swift",
                            path: "/src/main.swift",
                            isDirectory: false,
                            size: 1024
                        ),
                        FileTreeNode(
                            name: "utils.swift",
                            path: "/src/utils.swift",
                            isDirectory: false,
                            size: 512
                        )
                    ]
                ),
                FileTreeNode(
                    name: "README.md",
                    path: "/README.md",
                    isDirectory: false,
                    size: 2048
                ),
                FileTreeNode(
                    name: "Package.swift",
                    path: "/Package.swift",
                    isDirectory: false,
                    size: 256
                )
            ]
        )
    }
}

// MARK: - Usage Stats Factory
extension UsageStats {
    /// Create empty usage stats
    public static func empty() -> UsageStats {
        return UsageStats(
            totalTokens: 0,
            totalCost: 0.0,
            sessionsCount: 0,
            averageTokensPerSession: 0.0,
            periodStart: nil,
            periodEnd: nil
        )
    }
    
    /// Create sample usage stats
    public static func sample() -> UsageStats {
        return UsageStats(
            totalTokens: 2000,
            totalCost: 0.04,
            sessionsCount: 10,
            averageTokensPerSession: 200.0,
            periodStart: Date().addingTimeInterval(-86400 * 7), // 7 days ago
            periodEnd: Date()
        )
    }
}