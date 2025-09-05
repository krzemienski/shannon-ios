import Foundation
import Vapor
import Fluent

// Claude Code iOS Backend Server
// Production-ready API Gateway with all required endpoints

@main
struct ClaudeCodeAPIServer {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = Application(env)
        defer { app.shutdown() }
        
        // Configure server
        try configure(app)
        
        // Start server
        try await app.execute()
    }
}

func configure(_ app: Application) throws {
    // MARK: - Server Configuration
    
    // Production settings
    app.http.server.configuration.hostname = Environment.get("HOST") ?? "0.0.0.0"
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8000
    
    // Request size limits
    app.routes.defaultMaxBodySize = "10mb"
    
    // MARK: - CORS Configuration (for development)
    
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS, .PATCH],
        allowedHeaders: [
            .accept,
            .authorization,
            .contentType,
            .origin,
            .xRequestedWith,
            .userAgent,
            .init("X-API-Key"),
            .init("X-Client-Platform"),
            .init("X-Client-Version"),
            .init("X-Client-Environment"),
            .init("X-Client-Host-IP")
        ]
    )
    
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)
    
    // MARK: - Database Configuration (if needed)
    
    // Uncomment and configure for database support
    // app.databases.use(.postgres(
    //     hostname: Environment.get("DATABASE_HOST") ?? "localhost",
    //     port: Environment.get("DATABASE_PORT").flatMap(Int.init) ?? PostgresConfiguration.ianaPortNumber,
    //     username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
    //     password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
    //     database: Environment.get("DATABASE_NAME") ?? "vapor_database"
    // ), as: .psql)
    
    // MARK: - Middleware
    
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    // Custom auth middleware (if needed)
    // app.middleware.use(AuthenticationMiddleware())
    
    // MARK: - Routes Registration
    
    try routes(app)
    try registerAPIRoutes(app)
    try registerHealthRoutes(app)
    try registerMCPRoutes(app)
    
    print("🚀 Claude Code API Server starting on \(app.http.server.configuration.hostname):\(app.http.server.configuration.port)")
}

// MARK: - Routes Definition

func routes(_ app: Application) throws {
    app.get { req async in
        return ["status": "Claude Code API Server", "version": "1.0.0"]
    }
}

func registerAPIRoutes(_ app: Application) throws {
    let v1 = app.grouped("v1")
    
    // Chat endpoints
    let chatController = ChatController()
    let chat = v1.grouped("chat")
    chat.post("completions", use: chatController.createCompletion)
    chat.get("completions", ":sessionId", "status", use: chatController.getStatus)
    chat.delete("completions", ":sessionId", use: chatController.cancelSession)
    chat.post("completions", "debug", use: chatController.debug)
    
    // Models endpoints
    let modelsController = ModelsController()
    let models = v1.grouped("models")
    models.get(use: modelsController.list)
    models.get(":modelId", use: modelsController.get)
    models.get("capabilities", use: modelsController.capabilities)
    
    // Projects endpoints
    let projectsController = ProjectsController()
    let projects = v1.grouped("projects")
    projects.get(use: projectsController.list)
    projects.post(use: projectsController.create)
    projects.get(":projectId", use: projectsController.get)
    projects.delete(":projectId", use: projectsController.delete)
    
    // Sessions endpoints
    let sessionsController = SessionsController()
    let sessions = v1.grouped("sessions")
    sessions.get(use: sessionsController.list)
    sessions.post(use: sessionsController.create)
    sessions.get(":sessionId", use: sessionsController.get)
    sessions.delete(":sessionId", use: sessionsController.delete)
    sessions.get("stats", use: sessionsController.stats)
    
    // Tools endpoints
    let toolsController = ToolsController()
    let tools = v1.grouped("tools")
    tools.get(use: toolsController.list)
    tools.post("execute", use: toolsController.execute)
    
    // SSH endpoints
    let sshController = SSHController()
    let ssh = v1.grouped("ssh")
    ssh.get("sessions", use: sshController.listSessions)
    ssh.post("execute", use: sshController.executeCommand)
}

func registerHealthRoutes(_ app: Application) throws {
    // Health check endpoint (outside /v1)
    app.get("health") { req async -> HealthResponse in
        return HealthResponse(
            status: "healthy",
            version: "1.0.0",
            uptime: ProcessInfo.processInfo.systemUptime,
            environment: app.environment.name,
            timestamp: Date().ISO8601Format()
        )
    }
}

func registerMCPRoutes(_ app: Application) throws {
    let v1 = app.grouped("v1")
    let mcpController = MCPController()
    let mcp = v1.grouped("mcp")
    
    mcp.get("servers", use: mcpController.listServers)
    mcp.get("servers", ":serverId", "tools", use: mcpController.listTools)
    mcp.post("sessions", ":sessionId", "tools", use: mcpController.persistTools)
}

// MARK: - Response Models

struct HealthResponse: Content {
    let status: String
    let version: String
    let uptime: TimeInterval
    let environment: String
    let timestamp: String
}

// MARK: - Production Configuration

extension Application {
    static let productionConfig = ProductionConfig()
    
    struct ProductionConfig {
        // Database
        let databaseURL = Environment.get("DATABASE_URL") ?? "postgres://localhost/claudecode"
        
        // Redis (for caching/sessions)
        let redisURL = Environment.get("REDIS_URL") ?? "redis://localhost:6379"
        
        // API Keys
        let anthropicAPIKey = Environment.get("ANTHROPIC_API_KEY") ?? ""
        let openAIAPIKey = Environment.get("OPENAI_API_KEY") ?? ""
        
        // Rate Limiting
        let rateLimitPerMinute = Int(Environment.get("RATE_LIMIT_PER_MINUTE") ?? "60") ?? 60
        
        // SSL/TLS
        let useSSL = Environment.get("USE_SSL") == "true"
        let sslCertPath = Environment.get("SSL_CERT_PATH") ?? ""
        let sslKeyPath = Environment.get("SSL_KEY_PATH") ?? ""
        
        // Monitoring
        let sentryDSN = Environment.get("SENTRY_DSN") ?? ""
        let loggingLevel = Environment.get("LOG_LEVEL") ?? "info"
        
        // Feature Flags
        let enableMetrics = Environment.get("ENABLE_METRICS") == "true"
        let enableTracing = Environment.get("ENABLE_TRACING") == "true"
    }
}