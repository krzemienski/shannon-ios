import Foundation

// MARK: - Task 178: Model Factory Methods

// MARK: - ChatMessage Factory
extension ChatMessage {
    /// Create a system message
    public static func system(_ content: String) -> ChatMessage {
        ChatMessage(
            role: .system,
            content: .text(content)
        )
    }
    
    /// Create a user message
    public static func user(_ content: String, name: String? = nil) -> ChatMessage {
        ChatMessage(
            role: .user,
            content: .text(content),
            name: name
        )
    }
    
    /// Create an assistant message
    public static func assistant(_ content: String, name: String? = nil) -> ChatMessage {
        ChatMessage(
            role: .assistant,
            content: .text(content),
            name: name
        )
    }
    
    /// Create a tool message
    public static func tool(id: String, content: String) -> ChatMessage {
        ChatMessage(
            role: .tool,
            content: .text(content),
            toolCallId: id
        )
    }
    
    /// Create a message with images
    public static func userWithImages(text: String, imageUrls: [String]) -> ChatMessage {
        var parts: [MessagePart] = [
            MessagePart(
                type: .text,
                text: text,
                imageUrl: nil
            )
        ]
        
        for url in imageUrls {
            parts.append(
                MessagePart(
                    type: .imageUrl,
                    text: nil,
                    imageUrl: MessageImageUrl(
                        url: url,
                        detail: "auto"
                    )
                )
            )
        }
        
        return ChatMessage(
            role: .user,
            content: .array(parts)
        )
    }
}

// MARK: - ChatCompletionRequest Factory
extension ChatCompletionRequest {
    /// Create a simple chat request
    public static func simple(
        model: String = "gpt-4",
        messages: [ChatMessage],
        temperature: Double? = 0.7
    ) -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: temperature
        )
    }
    
    /// Create a streaming request
    public static func streaming(
        model: String = "gpt-4",
        messages: [ChatMessage],
        temperature: Double? = 0.7
    ) -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            stream: true
        )
    }
    
    /// Create a request with tools
    public static func withTools(
        model: String = "gpt-4",
        messages: [ChatMessage],
        tools: [ChatTool],
        toolChoice: ToolChoice? = .auto
    ) -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: model,
            messages: messages,
            tools: tools,
            toolChoice: toolChoice
        )
    }
    
    /// Create a test request
    public static func test(prompt: String = "Hello, world!") -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: "gpt-3.5-turbo",
            messages: [
                .system("You are a helpful assistant."),
                .user(prompt)
            ],
            temperature: 0.7,
            maxTokens: 100
        )
    }
}

// MARK: - ChatTool Factory
extension ChatTool {
    /// Create a function tool
    public static func function(
        name: String,
        description: String,
        parameters: ToolParameters? = nil
    ) -> ChatTool {
        ChatTool(
            type: "function",
            function: ToolFunction(
                name: name,
                description: description,
                parameters: parameters
            )
        )
    }
    
    /// Create a simple parameter-less tool
    public static func simple(name: String, description: String) -> ChatTool {
        ChatTool(
            type: "function",
            function: ToolFunction(
                name: name,
                description: description,
                parameters: nil
            )
        )
    }
    
    /// Create a tool with object parameters
    public static func withObjectParams(
        name: String,
        description: String,
        properties: [String: PropertySchema],
        required: [String]? = nil
    ) -> ChatTool {
        ChatTool(
            type: "function",
            function: ToolFunction(
                name: name,
                description: description,
                parameters: ToolParameters(
                    type: "object",
                    properties: properties,
                    required: required
                )
            )
        )
    }
}

// MARK: - ProjectInfo Factory
extension ProjectInfo {
    /// Create a new project
    public static func new(
        name: String,
        path: String,
        description: String? = nil
    ) -> ProjectInfo {
        let now = Date()
        return ProjectInfo(
            id: UUID().uuidString,
            name: name,
            path: path,
            description: description,
            createdAt: now,
            updatedAt: now,
            lastAccessedAt: now,
            settings: ProjectSettings.default,
            metadata: nil,
            isActive: true,
            isFavorite: false
        )
    }
    
    /// Create a test project
    public static func test() -> ProjectInfo {
        new(
            name: "Test Project",
            path: "/tmp/test-project",
            description: "A test project for unit testing"
        )
    }
}

// MARK: - ProjectSettings Factory
extension ProjectSettings {
    /// Default project settings
    public static var `default`: ProjectSettings {
        ProjectSettings(
            model: "gpt-4",
            temperature: 0.7,
            maxTokens: 2000,
            systemPrompt: nil,
            tools: [],
            autoSave: true,
            theme: "auto"
        )
    }
    
    /// Conservative settings for production
    public static var conservative: ProjectSettings {
        ProjectSettings(
            model: "gpt-3.5-turbo",
            temperature: 0.3,
            maxTokens: 1000,
            systemPrompt: "Be concise and accurate.",
            tools: [],
            autoSave: true,
            theme: "light"
        )
    }
    
    /// Creative settings for brainstorming
    public static var creative: ProjectSettings {
        ProjectSettings(
            model: "gpt-4",
            temperature: 0.9,
            maxTokens: 4000,
            systemPrompt: "Be creative and explore multiple possibilities.",
            tools: [],
            autoSave: false,
            theme: "dark"
        )
    }
}

// MARK: - SessionInfo Factory
extension SessionInfo {
    /// Create a new session
    public static func new(
        name: String,
        projectId: String? = nil
    ) -> SessionInfo {
        let now = Date()
        return SessionInfo(
            id: UUID().uuidString,
            name: name,
            projectId: projectId,
            messages: [],
            createdAt: now,
            updatedAt: now,
            metadata: SessionMetadata.default,
            context: nil,
            stats: nil
        )
    }
    
    /// Create a test session
    public static func test() -> SessionInfo {
        var session = new(name: "Test Session")
        session.messages = [
            .system("You are a helpful assistant."),
            .user("Hello!"),
            .assistant("Hi! How can I help you today?")
        ]
        return session
    }
}

// MARK: - SessionMetadata Factory
extension SessionMetadata {
    /// Default session metadata
    public static var `default`: SessionMetadata {
        SessionMetadata(
            model: "gpt-4",
            temperature: 0.7,
            maxTokens: 2000,
            tools: [],
            tags: []
        )
    }
}

// MARK: - APIModel Factory
extension APIModel {
    /// Create a GPT-4 model
    public static var gpt4: APIModel {
        APIModel(
            id: "gpt-4",
            name: "GPT-4",
            provider: "openai",
            description: "Most capable GPT-4 model",
            capabilities: ModelCapabilities(
                chat: true,
                completion: false,
                embeddings: false,
                vision: true,
                functionCalling: true,
                streaming: true,
                contextWindow: 8192,
                maxOutputTokens: 4096,
                supportsFunctions: true,
                supportsTools: true,
                supportsVision: true,
                supportsStreaming: true,
                supportsSystemMessage: true,
                supportsToolUse: true
            ),
            pricing: ModelPricing(
                promptTokenPrice: 0.03,
                completionTokenPrice: 0.06,
                currency: "USD",
                unit: "1K tokens"
            ),
            isAvailable: true,
            isDeprecated: false
        )
    }
    
    /// Create a GPT-3.5 Turbo model
    public static var gpt35Turbo: APIModel {
        APIModel(
            id: "gpt-3.5-turbo",
            name: "GPT-3.5 Turbo",
            provider: "openai",
            description: "Fast and efficient model",
            capabilities: ModelCapabilities(
                chat: true,
                completion: false,
                embeddings: false,
                vision: false,
                functionCalling: true,
                streaming: true,
                contextWindow: 4096,
                maxOutputTokens: 4096,
                supportsFunctions: true,
                supportsTools: true,
                supportsVision: false,
                supportsStreaming: true,
                supportsSystemMessage: true,
                supportsToolUse: true
            ),
            pricing: ModelPricing(
                promptTokenPrice: 0.0015,
                completionTokenPrice: 0.002,
                currency: "USD",
                unit: "1K tokens"
            ),
            isAvailable: true,
            isDeprecated: false
        )
    }
    
    /// Create a Claude model
    public static func claude(version: String = "claude-3-opus-20240229") -> APIModel {
        APIModel(
            id: version,
            name: "Claude 3 Opus",
            provider: "anthropic",
            description: "Most capable Claude model",
            capabilities: ModelCapabilities(
                chat: true,
                completion: false,
                embeddings: false,
                vision: true,
                functionCalling: true,
                streaming: true,
                contextWindow: 200000,
                maxOutputTokens: 4096,
                supportsFunctions: true,
                supportsTools: true,
                supportsVision: true,
                supportsStreaming: true,
                supportsSystemMessage: true,
                supportsToolUse: true
            ),
            pricing: ModelPricing(
                promptTokenPrice: 0.015,
                completionTokenPrice: 0.075,
                currency: "USD",
                unit: "1K tokens"
            ),
            isAvailable: true,
            isDeprecated: false
        )
    }
}

// MARK: - SSHConfig Factory
extension SSHConfig {
    /// Create a password-based SSH config
    public static func withPassword(
        name: String,
        host: String,
        username: String,
        password: String,
        port: Int = 22
    ) -> SSHConfig {
        SSHConfig(
            name: name,
            host: host,
            port: port,
            username: username,
            authMethod: .password,
            password: password
        )
    }
    
    /// Create a key-based SSH config
    public static func withKey(
        name: String,
        host: String,
        username: String,
        privateKeyPath: String,
        passphrase: String? = nil,
        port: Int = 22
    ) -> SSHConfig {
        SSHConfig(
            name: name,
            host: host,
            port: port,
            username: username,
            authMethod: .publicKey,
            privateKeyPath: privateKeyPath,
            passphrase: passphrase
        )
    }
    
    /// Create a test SSH config
    public static func test() -> SSHConfig {
        withPassword(
            name: "Test Server",
            host: "localhost",
            username: "testuser",
            password: "testpass"
        )
    }
}

// MARK: - MCPConfig Factory
extension MCPConfig {
    /// Create a default MCP configuration
    public static var `default`: MCPConfig {
        MCPConfig(
            name: "Default Configuration",
            servers: []
        )
    }
    
    /// Create a test MCP configuration
    public static func test() -> MCPConfig {
        MCPConfig(
            name: "Test Configuration",
            servers: [
                MCPServer(
                    name: "Test Server",
                    command: "node",
                    args: ["server.js"],
                    capabilities: MCPCapabilities(
                        tools: true,
                        resources: true,
                        prompts: false,
                        sampling: false,
                        logging: true
                    )
                )
            ]
        )
    }
}

// MARK: - ToolExecutionRequest Factory
extension ToolExecutionRequest {
    /// Create a simple tool execution request
    public static func simple(
        toolId: String,
        arguments: [String: Any]? = nil
    ) -> ToolExecutionRequest {
        ToolExecutionRequest(
            toolId: toolId,
            arguments: arguments,
            timeout: 30
        )
    }
    
    /// Create a test tool execution request
    public static func test() -> ToolExecutionRequest {
        simple(
            toolId: "test_tool",
            arguments: ["input": "test"]
        )
    }
}

// MARK: - FilterCriteria Factory
extension FilterCriteria {
    /// Create date range filter
    public static func dateRange(from: Date, to: Date) -> FilterCriteria {
        FilterCriteria(
            dateRange: DateRange(startDate: from, endDate: to)
        )
    }
    
    /// Create search filter
    public static func search(_ text: String) -> FilterCriteria {
        FilterCriteria(searchText: text)
    }
    
    /// Create tag filter
    public static func tags(_ tags: [String]) -> FilterCriteria {
        FilterCriteria(tags: tags)
    }
}

// MARK: - Pagination Factory
extension Pagination {
    /// Default pagination
    public static var `default`: Pagination {
        Pagination(page: 1, pageSize: 20)
    }
    
    /// Large page size
    public static var large: Pagination {
        Pagination(page: 1, pageSize: 50)
    }
    
    /// Small page size
    public static var small: Pagination {
        Pagination(page: 1, pageSize: 10)
    }
}

// MARK: - UserPreferences Factory
extension UserPreferences {
    /// Default user preferences
    public static var `default`: UserPreferences {
        UserPreferences()
    }
    
    /// Dark mode preferences
    public static var darkMode: UserPreferences {
        UserPreferences(theme: .dark)
    }
    
    /// Developer preferences
    public static var developer: UserPreferences {
        UserPreferences(
            theme: .auto,
            language: "en",
            notifications: NotificationPreferences(
                enabled: true,
                sound: true,
                badge: true,
                alerts: true
            ),
            privacy: PrivacyPreferences(
                analytics: false,
                crashReporting: true,
                personalization: false,
                dataSharingr: false
            ),
            accessibility: AccessibilityPreferences(),
            advanced: AdvancedPreferences(
                developerMode: true,
                debugLogging: true,
                experimentalFeatures: true
            )
        )
    }
}

// MARK: - AppNotification Factory
extension AppNotification {
    /// Create an info notification
    public static func info(
        title: String,
        body: String,
        actionUrl: String? = nil
    ) -> AppNotification {
        AppNotification(
            title: title,
            body: body,
            category: .info,
            priority: .normal,
            actionUrl: actionUrl
        )
    }
    
    /// Create an error notification
    public static func error(
        title: String,
        body: String
    ) -> AppNotification {
        AppNotification(
            title: title,
            body: body,
            category: .error,
            priority: .high
        )
    }
    
    /// Create a success notification
    public static func success(
        title: String,
        body: String
    ) -> AppNotification {
        AppNotification(
            title: title,
            body: body,
            category: .success,
            priority: .normal
        )
    }
    
    /// Create an urgent alert
    public static func urgent(
        title: String,
        body: String,
        actionUrl: String? = nil
    ) -> AppNotification {
        AppNotification(
            title: title,
            body: body,
            category: .alert,
            priority: .urgent,
            actionUrl: actionUrl
        )
    }
}

// MARK: - TraceEvent Factory
extension TraceEvent {
    /// Create an info trace event
    public static func info(
        category: String,
        message: String,
        metadata: [String: String]? = nil
    ) -> TraceEvent {
        TraceEvent(
            level: .info,
            category: category,
            message: message,
            metadata: metadata
        )
    }
    
    /// Create an error trace event
    public static func error(
        category: String,
        message: String,
        source: TraceSource? = nil,
        metadata: [String: String]? = nil
    ) -> TraceEvent {
        TraceEvent(
            level: .error,
            category: category,
            message: message,
            source: source,
            metadata: metadata
        )
    }
    
    /// Create a debug trace event
    public static func debug(
        category: String,
        message: String,
        metadata: [String: String]? = nil
    ) -> TraceEvent {
        TraceEvent(
            level: .debug,
            category: category,
            message: message,
            metadata: metadata
        )
    }
}

// MARK: - Test Data Factories
public struct TestDataFactory {
    /// Create a sample conversation
    public static func sampleConversation() -> [ChatMessage] {
        [
            .system("You are a helpful coding assistant."),
            .user("How do I implement a singleton in Swift?"),
            .assistant("Here's how to implement a singleton in Swift:\n\n```swift\nclass MySingleton {\n    static let shared = MySingleton()\n    private init() {}\n}\n```"),
            .user("Can you explain why the initializer is private?"),
            .assistant("The private initializer prevents other parts of your code from creating additional instances of the singleton class.")
        ]
    }
    
    /// Create sample tools
    public static func sampleTools() -> [ChatTool] {
        [
            .function(
                name: "get_weather",
                description: "Get the current weather for a location",
                parameters: ToolParameters(
                    type: "object",
                    properties: [
                        "location": PropertySchema(
                            type: "string",
                            description: "The city and state, e.g. San Francisco, CA"
                        ),
                        "unit": PropertySchema(
                            type: "string",
                            description: "Temperature unit",
                            enum: ["celsius", "fahrenheit"]
                        )
                    ],
                    required: ["location"]
                )
            ),
            .simple(
                name: "get_time",
                description: "Get the current time"
            )
        ]
    }
    
    /// Create a sample project with sessions
    public static func sampleProject() -> ProjectInfo {
        var project = ProjectInfo.new(
            name: "Sample Project",
            path: "/Users/test/sample-project",
            description: "A sample project for testing"
        )
        
        project.metadata = ProjectMetadata(
            language: "Swift",
            framework: "SwiftUI",
            version: "1.0.0",
            dependencies: ["Alamofire", "SwiftyJSON"],
            statistics: ProjectStatistics(
                files: 42,
                lines: 1337,
                size: 1024 * 1024 * 5, // 5MB
                lastCommit: Date()
            )
        )
        
        return project
    }
}