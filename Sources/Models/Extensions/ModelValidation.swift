import Foundation

// MARK: - Task 177: Model Validation Logic

// MARK: - Validation Protocol
public protocol Validatable {
    func validate() throws
}

// MARK: - Validation Errors
public enum ValidationError: LocalizedError, Sendable {
    case missingRequiredField(String)
    case invalidValue(field: String, reason: String)
    case outOfRange(field: String, min: String?, max: String?)
    case invalidFormat(field: String, expected: String)
    case tooLong(field: String, maxLength: Int)
    case tooShort(field: String, minLength: Int)
    case invalidURL(String)
    case invalidEmail(String)
    case invalidPath(String)
    case custom(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "Required field '\(field)' is missing"
        case .invalidValue(let field, let reason):
            return "Invalid value for '\(field)': \(reason)"
        case .outOfRange(let field, let min, let max):
            if let min = min, let max = max {
                return "'\(field)' must be between \(min) and \(max)"
            } else if let min = min {
                return "'\(field)' must be at least \(min)"
            } else if let max = max {
                return "'\(field)' must be at most \(max)"
            } else {
                return "'\(field)' is out of range"
            }
        case .invalidFormat(let field, let expected):
            return "'\(field)' has invalid format. Expected: \(expected)"
        case .tooLong(let field, let maxLength):
            return "'\(field)' is too long (maximum \(maxLength) characters)"
        case .tooShort(let field, let minLength):
            return "'\(field)' is too short (minimum \(minLength) characters)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidEmail(let email):
            return "Invalid email: \(email)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .custom(let message):
            return message
        }
    }
}

// MARK: - ChatRequest Validation
extension ChatCompletionRequest: Validatable {
    public func validate() throws {
        // Validate model
        if model.isEmpty {
            throw ValidationError.missingRequiredField("model")
        }
        
        // Validate messages
        if messages.isEmpty {
            throw ValidationError.missingRequiredField("messages")
        }
        
        // Validate temperature
        if let temp = temperature {
            if temp < 0 || temp > 2 {
                throw ValidationError.outOfRange(field: "temperature", min: "0", max: "2")
            }
        }
        
        // Validate top_p
        if let topP = topP {
            if topP < 0 || topP > 1 {
                throw ValidationError.outOfRange(field: "top_p", min: "0", max: "1")
            }
        }
        
        // Validate max_tokens
        if let maxTokens = maxTokens {
            if maxTokens < 1 {
                throw ValidationError.outOfRange(field: "max_tokens", min: "1", max: nil)
            }
        }
        
        // Validate n
        if let n = n {
            if n < 1 || n > 10 {
                throw ValidationError.outOfRange(field: "n", min: "1", max: "10")
            }
        }
        
        // Validate presence_penalty
        if let penalty = presencePenalty {
            if penalty < -2 || penalty > 2 {
                throw ValidationError.outOfRange(field: "presence_penalty", min: "-2", max: "2")
            }
        }
        
        // Validate frequency_penalty
        if let penalty = frequencyPenalty {
            if penalty < -2 || penalty > 2 {
                throw ValidationError.outOfRange(field: "frequency_penalty", min: "-2", max: "2")
            }
        }
        
        // Validate messages
        try messages.forEach { try $0.validate() }
        
        // Validate tools
        try tools?.forEach { try $0.validate() }
    }
}

// MARK: - ChatMessage Validation
extension ChatMessage: Validatable {
    public func validate() throws {
        // Validate role-specific requirements
        switch role {
        case .system:
            if content == nil {
                throw ValidationError.missingRequiredField("content for system message")
            }
        case .user:
            if content == nil && toolCallId == nil {
                throw ValidationError.missingRequiredField("content or tool_call_id for user message")
            }
        case .assistant:
            if content == nil && toolCalls == nil {
                throw ValidationError.missingRequiredField("content or tool_calls for assistant message")
            }
        case .tool:
            if toolCallId == nil {
                throw ValidationError.missingRequiredField("tool_call_id for tool message")
            }
            if content == nil {
                throw ValidationError.missingRequiredField("content for tool message")
            }
        case .function:
            // Legacy function role - deprecated but still valid
            break
        }
        
        // Validate name if present
        if let name = name, name.isEmpty {
            throw ValidationError.invalidValue(field: "name", reason: "Cannot be empty")
        }
    }
}

// MARK: - ChatTool Validation
extension ChatTool: Validatable {
    public func validate() throws {
        try function.validate()
    }
}

extension ToolFunction: Validatable {
    public func validate() throws {
        // Validate name
        if name.isEmpty {
            throw ValidationError.missingRequiredField("function.name")
        }
        
        // Validate name format (alphanumeric, underscore, hyphen)
        let nameRegex = "^[a-zA-Z0-9_-]+$"
        let namePredicate = NSPredicate(format: "SELF MATCHES %@", nameRegex)
        if !namePredicate.evaluate(with: name) {
            throw ValidationError.invalidFormat(
                field: "function.name",
                expected: "alphanumeric characters, underscores, and hyphens only"
            )
        }
        
        // Validate parameters if present
        try parameters?.validate()
    }
}

extension ToolParameters: Validatable {
    public func validate() throws {
        // Validate type
        if type != "object" && type != "array" && type != "string" && type != "number" && type != "boolean" {
            throw ValidationError.invalidValue(
                field: "parameters.type",
                reason: "Must be one of: object, array, string, number, boolean"
            )
        }
        
        // Validate required fields exist in properties
        if let required = required, let properties = properties {
            for field in required {
                if properties[field] == nil {
                    throw ValidationError.invalidValue(
                        field: "required",
                        reason: "Field '\(field)' is listed as required but not defined in properties"
                    )
                }
            }
        }
    }
}

// MARK: - Project Validation
extension CreateProjectRequest: Validatable {
    public func validate() throws {
        // Validate name
        if name.isEmpty {
            throw ValidationError.missingRequiredField("name")
        }
        
        if name.count > 255 {
            throw ValidationError.tooLong(field: "name", maxLength: 255)
        }
        
        // Validate path
        if path.isEmpty {
            throw ValidationError.missingRequiredField("path")
        }
        
        // Validate path format
        if !FileManager.default.fileExists(atPath: path) {
            throw ValidationError.invalidPath(path)
        }
        
        // Validate git repository URL if present
        if let gitRepo = gitRepository, !gitRepo.isEmpty {
            if !gitRepo.hasPrefix("http://") && !gitRepo.hasPrefix("https://") && !gitRepo.hasPrefix("git@") {
                throw ValidationError.invalidURL(gitRepo)
            }
        }
        
        // Validate settings
        try settings?.validate()
    }
}

extension ProjectSettings: Validatable {
    public func validate() throws {
        // Validate temperature
        if let temp = temperature {
            if temp < 0 || temp > 2 {
                throw ValidationError.outOfRange(field: "temperature", min: "0", max: "2")
            }
        }
        
        // Validate max tokens
        if let maxTokens = maxTokens {
            if maxTokens < 1 {
                throw ValidationError.outOfRange(field: "maxTokens", min: "1", max: nil)
            }
        }
    }
}

// MARK: - Session Validation
extension CreateSessionRequest: Validatable {
    public func validate() throws {
        // Validate name
        if name.isEmpty {
            throw ValidationError.missingRequiredField("name")
        }
        
        if name.count > 255 {
            throw ValidationError.tooLong(field: "name", maxLength: 255)
        }
        
        // Validate metadata
        try metadata?.validate()
    }
}

extension SessionMetadata: Validatable {
    public func validate() throws {
        // Validate temperature
        if let temp = temperature {
            if temp < 0 || temp > 2 {
                throw ValidationError.outOfRange(field: "temperature", min: "0", max: "2")
            }
        }
        
        // Validate max tokens
        if let maxTokens = maxTokens {
            if maxTokens < 1 {
                throw ValidationError.outOfRange(field: "maxTokens", min: "1", max: nil)
            }
        }
    }
}

// MARK: - SSH Validation
extension SSHConfig: Validatable {
    public func validate() throws {
        // Validate name
        if name.isEmpty {
            throw ValidationError.missingRequiredField("name")
        }
        
        // Validate host
        if host.isEmpty {
            throw ValidationError.missingRequiredField("host")
        }
        
        // Validate port
        if port < 1 || port > 65535 {
            throw ValidationError.outOfRange(field: "port", min: "1", max: "65535")
        }
        
        // Validate username
        if username.isEmpty {
            throw ValidationError.missingRequiredField("username")
        }
        
        // Validate auth method requirements
        switch authMethod {
        case .password:
            if password == nil || password!.isEmpty {
                throw ValidationError.missingRequiredField("password for password auth")
            }
        case .publicKey:
            if privateKeyPath == nil || privateKeyPath!.isEmpty {
                throw ValidationError.missingRequiredField("privateKeyPath for public key auth")
            }
        default:
            break
        }
    }
}

// MARK: - Tool Execution Validation
extension ToolExecutionRequest: Validatable {
    public func validate() throws {
        // Validate tool ID
        if toolId.isEmpty {
            throw ValidationError.missingRequiredField("toolId")
        }
        
        // Validate timeout
        if let timeout = timeout {
            if timeout < 0 || timeout > 300 {
                throw ValidationError.outOfRange(field: "timeout", min: "0", max: "300")
            }
        }
    }
}

// MARK: - Filter Validation
extension FilterCriteria: Validatable {
    public func validate() throws {
        // Validate date range
        if let dateRange = dateRange {
            if dateRange.startDate > dateRange.endDate {
                throw ValidationError.invalidValue(
                    field: "dateRange",
                    reason: "Start date must be before end date"
                )
            }
        }
        
        // Validate search text length
        if let searchText = searchText {
            if searchText.count > 1000 {
                throw ValidationError.tooLong(field: "searchText", maxLength: 1000)
            }
        }
    }
}

// MARK: - Pagination Validation
extension Pagination: Validatable {
    public func validate() throws {
        // Validate page
        if page < 1 {
            throw ValidationError.outOfRange(field: "page", min: "1", max: nil)
        }
        
        // Validate page size
        if pageSize < 1 || pageSize > 100 {
            throw ValidationError.outOfRange(field: "pageSize", min: "1", max: "100")
        }
    }
}

// MARK: - Validation Helpers
public struct Validator {
    /// Validate email format
    public static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// Validate URL format
    public static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    /// Validate file path
    public static func isValidPath(_ path: String) -> Bool {
        return !path.isEmpty && !path.contains("\0")
    }
    
    /// Validate UUID format
    public static func isValidUUID(_ uuid: String) -> Bool {
        return UUID(uuidString: uuid) != nil
    }
    
    /// Validate JSON string
    public static func isValidJSON(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            return false
        }
    }
}