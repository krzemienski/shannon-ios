//
//  RealBackendConfig.swift
//  ClaudeCodeUITests
//
//  Backend configuration for functional testing with real backend
//

import Foundation

/// Configuration for connecting to real backend during functional testing
struct RealBackendConfig {
    
    // MARK: - Configuration Properties
    
    /// Base URL for the backend API
    static var baseURL: String {
        return ProcessInfo.processInfo.environment["BACKEND_URL"] ?? "http://localhost:8000"
    }
    
    /// API version path
    static var apiVersion: String {
        return "/v1"
    }
    
    /// Full API base URL
    static var apiBaseURL: String {
        return "\(baseURL)\(apiVersion)"
    }
    
    /// Network timeout for API requests
    static var networkTimeout: TimeInterval {
        return TimeInterval(ProcessInfo.processInfo.environment["NETWORK_TIMEOUT"] ?? "30") ?? 30.0
    }
    
    /// Maximum wait time for UI elements after network operations
    static var uiWaitTimeout: TimeInterval {
        return TimeInterval(ProcessInfo.processInfo.environment["UI_WAIT_TIMEOUT"] ?? "15") ?? 15.0
    }
    
    /// Authentication token for API requests (if required)
    static var authToken: String? {
        return ProcessInfo.processInfo.environment["AUTH_TOKEN"]
    }
    
    /// Whether to enable verbose logging for debugging
    static var verboseLogging: Bool {
        return ProcessInfo.processInfo.environment["VERBOSE_LOGGING"]?.lowercased() == "true"
    }
    
    /// Whether to clean up test data after each test
    static var cleanupAfterTests: Bool {
        return ProcessInfo.processInfo.environment["CLEANUP_AFTER_TESTS"]?.lowercased() != "false"
    }
    
    /// Test data prefix for easy identification and cleanup
    static var testDataPrefix: String {
        return ProcessInfo.processInfo.environment["TEST_DATA_PREFIX"] ?? "UITest_"
    }
    
    // MARK: - Endpoint URLs
    
    enum Endpoint {
        case projects
        case projectDetail(String)
        case sessions
        case sessionDetail(String)
        case chat(String)
        case models
        case health
        case stats
        
        var path: String {
            switch self {
            case .projects:
                return "/projects"
            case .projectDetail(let id):
                return "/projects/\(id)"
            case .sessions:
                return "/sessions"
            case .sessionDetail(let id):
                return "/sessions/\(id)"
            case .chat(let sessionId):
                return "/chat/\(sessionId)"
            case .models:
                return "/models"
            case .health:
                return "/health"
            case .stats:
                return "/sessions/stats"
            }
        }
        
        var fullURL: String {
            return "\(RealBackendConfig.apiBaseURL)\(path)"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if backend is available
    static func isBackendAvailable() async -> Bool {
        do {
            let url = URL(string: Endpoint.health.fullURL)!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            if verboseLogging {
                print("Backend availability check failed: \(error)")
            }
            return false
        }
    }
    
    /// Wait for backend to become available
    static func waitForBackend(maxAttempts: Int = 10, interval: TimeInterval = 2.0) async -> Bool {
        for attempt in 1...maxAttempts {
            if await isBackendAvailable() {
                if verboseLogging {
                    print("Backend available after \(attempt) attempts")
                }
                return true
            }
            
            if verboseLogging {
                print("Backend not available, attempt \(attempt)/\(maxAttempts)")
            }
            
            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
        
        print("Backend failed to become available after \(maxAttempts) attempts")
        return false
    }
    
    /// Clean up test data from backend
    static func cleanupTestData() async {
        guard cleanupAfterTests else { return }
        
        if verboseLogging {
            print("Cleaning up test data with prefix: \(testDataPrefix)")
        }
        
        // TODO: Implement cleanup logic
        // This would involve:
        // 1. List all projects with test prefix
        // 2. Delete sessions in those projects
        // 3. Delete the projects
        // 4. Clean up any other test artifacts
    }
    
    /// Generate unique test identifier
    static func generateTestId() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 1000...9999)
        return "\(testDataPrefix)\(timestamp)_\(random)"
    }
    
    /// Create launch configuration for real backend testing
    static func createLaunchConfiguration() -> LaunchConfiguration {
        var config = LaunchConfiguration.uiTesting
        
        // Add backend configuration
        config.environment["BACKEND_URL"] = baseURL
        config.environment["NETWORK_TIMEOUT"] = String(networkTimeout)
        config.environment["UI_WAIT_TIMEOUT"] = String(uiWaitTimeout)
        config.environment["REAL_BACKEND_MODE"] = "1"
        config.environment["DISABLE_MOCK_DATA"] = "1"
        
        if let token = authToken {
            config.environment["AUTH_TOKEN"] = token
        }
        
        if verboseLogging {
            config.environment["VERBOSE_LOGGING"] = "1"
        }
        
        // Disable offline mode and mocking
        config.arguments.append("--real-backend")
        config.arguments.append("--no-mock")
        
        return config
    }
}

// MARK: - Test Data Models

/// Test project data for backend testing
struct TestProjectData {
    let name: String
    let description: String
    let path: String?
    
    init(name: String? = nil, description: String? = nil, path: String? = nil) {
        self.name = name ?? "\(RealBackendConfig.testDataPrefix)Project_\(Int.random(in: 1000...9999))"
        self.description = description ?? "Test project created by UI tests"
        self.path = path
    }
    
    var jsonData: [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "description": description
        ]
        
        if let path = path {
            data["path"] = path
        }
        
        return data
    }
}

/// Test session data for backend testing
struct TestSessionData {
    let title: String?
    let projectId: String
    let model: String
    let systemPrompt: String?
    
    init(projectId: String, title: String? = nil, model: String = "claude-3-haiku-20240307", systemPrompt: String? = nil) {
        self.projectId = projectId
        self.title = title ?? "\(RealBackendConfig.testDataPrefix)Session_\(Int.random(in: 1000...9999))"
        self.model = model
        self.systemPrompt = systemPrompt ?? "You are a helpful assistant for testing."
    }
    
    var jsonData: [String: Any] {
        var data: [String: Any] = [
            "project_id": projectId,
            "model": model
        ]
        
        if let title = title {
            data["title"] = title
        }
        
        if let systemPrompt = systemPrompt {
            data["system_prompt"] = systemPrompt
        }
        
        return data
    }
}

/// Test message data for backend testing
struct TestMessageData {
    let content: String
    let role: String
    
    init(content: String? = nil, role: String = "user") {
        self.content = content ?? "Test message from UI tests: \(Date().timeIntervalSince1970)"
        self.role = role
    }
    
    var jsonData: [String: Any] {
        return [
            "content": content,
            "role": role
        ]
    }
}

// MARK: - Backend API Helper

/// Helper class for making API requests during tests
class BackendAPIHelper {
    
    static let shared = BackendAPIHelper()
    private let session = URLSession.shared
    
    private init() {}
    
    /// Make API request
    private func makeRequest(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = RealBackendConfig.networkTimeout
        
        // Set default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add auth token if available
        if let token = RealBackendConfig.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InvalidResponse", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        if RealBackendConfig.verboseLogging {
            print("API Request: \(method) \(url)")
            print("Response: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response Body: \(responseString)")
            }
        }
        
        return (data, httpResponse)
    }
    
    /// Create project via API
    func createProject(_ projectData: TestProjectData) async throws -> [String: Any] {
        let url = URL(string: RealBackendConfig.Endpoint.projects.fullURL)!
        let body = try JSONSerialization.data(withJSONObject: projectData.jsonData)
        
        let (data, response) = try await makeRequest(url: url, method: "POST", body: body)
        
        guard response.statusCode == 200 || response.statusCode == 201 else {
            throw NSError(domain: "APIError", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create project"])
        }
        
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    /// Get projects via API
    func getProjects() async throws -> [[String: Any]] {
        let url = URL(string: RealBackendConfig.Endpoint.projects.fullURL)!
        
        let (data, response) = try await makeRequest(url: url)
        
        guard response.statusCode == 200 else {
            throw NSError(domain: "APIError", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to get projects"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["data"] as? [[String: Any]] ?? []
    }
    
    /// Create session via API
    func createSession(_ sessionData: TestSessionData) async throws -> [String: Any] {
        let url = URL(string: RealBackendConfig.Endpoint.sessions.fullURL)!
        let body = try JSONSerialization.data(withJSONObject: sessionData.jsonData)
        
        let (data, response) = try await makeRequest(url: url, method: "POST", body: body)
        
        guard response.statusCode == 200 || response.statusCode == 201 else {
            throw NSError(domain: "APIError", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create session"])
        }
        
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    /// Get sessions via API
    func getSessions(projectId: String? = nil) async throws -> [[String: Any]] {
        var urlString = RealBackendConfig.Endpoint.sessions.fullURL
        if let projectId = projectId {
            urlString += "?project_id=\(projectId)"
        }
        
        let url = URL(string: urlString)!
        let (data, response) = try await makeRequest(url: url)
        
        guard response.statusCode == 200 else {
            throw NSError(domain: "APIError", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to get sessions"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["data"] as? [[String: Any]] ?? []
    }
    
    /// Delete project via API
    func deleteProject(_ projectId: String) async throws {
        let url = URL(string: RealBackendConfig.Endpoint.projectDetail(projectId).fullURL)!
        
        let (_, response) = try await makeRequest(url: url, method: "DELETE")
        
        guard response.statusCode == 200 || response.statusCode == 204 else {
            throw NSError(domain: "APIError", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to delete project"])
        }
    }
    
    /// Delete session via API
    func deleteSession(_ sessionId: String) async throws {
        let url = URL(string: RealBackendConfig.Endpoint.sessionDetail(sessionId).fullURL)!
        
        let (_, response) = try await makeRequest(url: url, method: "DELETE")
        
        guard response.statusCode == 200 || response.statusCode == 204 else {
            throw NSError(domain: "APIError", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to delete session"])
        }
    }
}