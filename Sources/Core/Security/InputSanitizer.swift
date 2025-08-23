//
//  InputSanitizer.swift
//  ClaudeCode
//
//  Input validation and sanitization to prevent injection attacks
//

import Foundation
import UIKit
import OSLog

/// Comprehensive input sanitization and validation
public final class InputSanitizer {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "InputSanitizer")
    
    // Validation patterns
    private let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
    private let urlRegex = #"^(https?|ftp)://[^\s/$.?#].[^\s]*$"#
    private let phoneRegex = #"^\+?[1-9]\d{1,14}$"#
    private let alphanumericRegex = #"^[a-zA-Z0-9]+$"#
    
    // SQL injection patterns
    private let sqlInjectionPatterns = [
        #"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE|UNION|FROM|WHERE|JOIN|OR|AND|NOT|NULL|LIKE|INTO|VALUES|TABLE|DATABASE|INDEX|HAVING|GROUP BY|ORDER BY)\b)"#,
        #"(--|#|/\*|\*/|;|'|"|`|\\x00|\\n|\\r|\\x1a)"#,
        #"(\b(sys|information_schema|mysql|performance_schema)\b\.\w+)"#,
        #"(CAST\s*\(|CONVERT\s*\(|CHAR\s*\()"#,
        #"(xp_cmdshell|sp_executesql|sp_addlogin|sp_password)"#
    ]
    
    // XSS patterns
    private let xssPatterns = [
        #"<script[^>]*>.*?</script>"#,
        #"javascript\s*:"#,
        #"on\w+\s*="#,
        #"<iframe[^>]*>"#,
        #"<embed[^>]*>"#,
        #"<object[^>]*>"#,
        #"<applet[^>]*>"#,
        #"<meta[^>]*>"#,
        #"<link[^>]*>"#,
        #"<style[^>]*>.*?</style>"#,
        #"expression\s*\("#,
        #"vbscript\s*:"#,
        #"data:text/html"#,
        #"<svg[^>]*on\w+=[^>]*>"#
    ]
    
    // Command injection patterns
    private let commandInjectionPatterns = [
        #"[;&|`$]"#,
        #"\$\([^)]*\)"#,
        #"`[^`]*`"#,
        #">\s*[^\s]+"#,
        #"<\s*[^\s]+"#,
        #"\|\s*[^\s]+"#,
        #"&&\s*[^\s]+"#,
        #"\|\|\s*[^\s]+"#
    ]
    
    // Path traversal patterns
    private let pathTraversalPatterns = [
        #"\.\./+"#,
        #"\.\.\\+"#,
        #"%2e%2e[/\\]"#,
        #"%252e%252e[/\\]"#,
        #"\.\./\.\."#,
        #"^\~/"#,
        #"^/etc/"#,
        #"^/var/"#,
        #"^/usr/"#,
        #"^/proc/"#,
        #"^C:\\"#,
        #"^D:\\"#
    ]
    
    // Maximum lengths for different input types
    private let maxLengths: [InputType: Int] = [
        .username: 50,
        .password: 128,
        .email: 254,
        .url: 2048,
        .apiKey: 256,
        .sshKey: 4096,
        .filename: 255,
        .path: 4096,
        .command: 1024,
        .generalText: 10000,
        .searchQuery: 200,
        .sqlQuery: 5000
    ]
    
    // MARK: - Singleton
    
    public static let shared = InputSanitizer()
    
    private init() {}
    
    // MARK: - Input Types
    
    public enum InputType {
        case username
        case password
        case email
        case url
        case apiKey
        case sshKey
        case filename
        case path
        case command
        case generalText
        case searchQuery
        case sqlQuery
    }
    
    // MARK: - Main Validation Method
    
    /// Validate and sanitize input based on type
    public func sanitize(_ input: String, type: InputType) -> SanitizationResult {
        logger.debug("Sanitizing input of type: \(String(describing: type))")
        
        // Check for empty input
        guard !input.isEmpty else {
            return SanitizationResult(
                isValid: false,
                sanitizedValue: "",
                errors: ["Input cannot be empty"],
                warnings: []
            )
        }
        
        // Check length
        if let maxLength = maxLengths[type], input.count > maxLength {
            return SanitizationResult(
                isValid: false,
                sanitizedValue: String(input.prefix(maxLength)),
                errors: ["Input exceeds maximum length of \(maxLength) characters"],
                warnings: []
            )
        }
        
        // Type-specific validation
        switch type {
        case .username:
            return sanitizeUsername(input)
        case .password:
            return sanitizePassword(input)
        case .email:
            return sanitizeEmail(input)
        case .url:
            return sanitizeURL(input)
        case .apiKey:
            return sanitizeAPIKey(input)
        case .sshKey:
            return sanitizeSSHKey(input)
        case .filename:
            return sanitizeFilename(input)
        case .path:
            return sanitizePath(input)
        case .command:
            return sanitizeCommand(input)
        case .generalText:
            return sanitizeGeneralText(input)
        case .searchQuery:
            return sanitizeSearchQuery(input)
        case .sqlQuery:
            return sanitizeSQLQuery(input)
        }
    }
    
    // MARK: - Specific Sanitizers
    
    private func sanitizeUsername(_ input: String) -> SanitizationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Remove whitespace
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for valid characters (alphanumeric, underscore, dash)
        let validPattern = #"^[a-zA-Z0-9_-]+$"#
        if !matches(trimmed, pattern: validPattern) {
            errors.append("Username can only contain letters, numbers, underscore, and dash")
        }
        
        // Check for SQL injection
        if containsSQLInjection(trimmed) {
            errors.append("Potential SQL injection detected")
        }
        
        // Check minimum length
        if trimmed.count < 3 {
            errors.append("Username must be at least 3 characters")
        }
        
        // Sanitize by removing invalid characters
        let sanitized = trimmed.replacingOccurrences(
            of: "[^a-zA-Z0-9_-]",
            with: "",
            options: .regularExpression
        )
        
        return SanitizationResult(
            isValid: errors.isEmpty,
            sanitizedValue: sanitized,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func sanitizePassword(_ input: String) -> SanitizationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Don't trim passwords - spaces might be intentional
        let password = input
        
        // Check minimum length
        if password.count < 8 {
            errors.append("Password must be at least 8 characters")
        }
        
        // Check complexity
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil
        
        if !hasUppercase || !hasLowercase || !hasNumber || !hasSpecial {
            warnings.append("Password should contain uppercase, lowercase, numbers, and special characters")
        }
        
        // Check for common passwords
        if isCommonPassword(password) {
            errors.append("Password is too common")
        }
        
        // Don't sanitize passwords - return as-is if valid
        return SanitizationResult(
            isValid: errors.isEmpty,
            sanitizedValue: password,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func sanitizeEmail(_ input: String) -> SanitizationResult {
        var errors: [String] = []
        let warnings: [String] = []
        
        // Convert to lowercase and trim
        let email = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate format
        if !matches(email, pattern: emailRegex) {
            errors.append("Invalid email format")
        }
        
        // Check for SQL injection
        if containsSQLInjection(email) {
            errors.append("Potential SQL injection detected")
        }
        
        // Check for XSS
        if containsXSS(email) {
            errors.append("Potential XSS attack detected")
        }
        
        return SanitizationResult(
            isValid: errors.isEmpty,
            sanitizedValue: email,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func sanitizeURL(_ input: String) -> SanitizationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Trim whitespace
        let url = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate format
        guard let urlObj = URL(string: url) else {
            errors.append("Invalid URL format")
            return SanitizationResult(
                isValid: false,
                sanitizedValue: url,
                errors: errors,
                warnings: warnings
            )
        }
        
        // Check scheme
        if let scheme = urlObj.scheme {
            if !["http", "https", "ftp", "ftps"].contains(scheme.lowercased()) {
                errors.append("URL scheme must be http, https, ftp, or ftps")
            }
        } else {
            errors.append("URL must have a scheme")
        }
        
        // Check for JavaScript URLs
        if url.lowercased().contains("javascript:") {
            errors.append("JavaScript URLs are not allowed")
        }
        
        // Check for data URLs
        if url.lowercased().starts(with: "data:") {
            warnings.append("Data URLs may pose security risks")
        }
        
        // Check for local file URLs
        if url.lowercased().starts(with: "file://") {
            errors.append("Local file URLs are not allowed")
        }
        
        return SanitizationResult(
            isValid: errors.isEmpty,
            sanitizedValue: url,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func sanitizeAPIKey(_ input: String) -> SanitizationResult {
        var errors: [String] = []
        let warnings: [String] = []
        
        // Remove whitespace
        let key = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check format (usually base64 or hex)
        let base64Pattern = #"^[A-Za-z0-9+/]+=*$"#
        let hexPattern = #"^[A-Fa-f0-9]+$"#
        let validCharsPattern = #"^[A-Za-z0-9_\-]+=*$"#
        
        if !matches(key, pattern: base64Pattern) &&
           !matches(key, pattern: hexPattern) &&
           !matches(key, pattern: validCharsPattern) {
            errors.append("API key contains invalid characters")
        }
        
        // Check minimum length
        if key.count < 16 {
            warnings.append("API key seems unusually short")
        }
        
        return SanitizationResult(
            isValid: errors.isEmpty,
            sanitizedValue: key,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func sanitizeSSHKey(_ input: String) -> SanitizationResult {
        var errors: [String] = []
        let warnings: [String] = []
        
        let key = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for SSH key markers
        let hasSSHMarkers = key.contains("-----BEGIN") || key.contains("ssh-rsa") || key.contains("ssh-ed25519")
        
        if !hasSSHMarkers {
            errors.append("Invalid SSH key format")
        }
        
        // Check for potential injection in key content
        if containsCommandInjection(key) {
            errors.append("Potential command injection detected")
        }
        
        return SanitizationResult(
            isValid: errors.isEmpty,
            sanitizedValue: key,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func sanitizeFilename(_ input: String) -> SanitizationResult {
        var errors: [String] = []
        let warnings: [String] = []
        
        // Remove path components
        let filename = (input as NSString).lastPathComponent
        
        // Check for invalid characters
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        if filename.rangeOfCharacter(from: invalidChars) != nil {
            errors.append("Filename contains invalid characters")
        }
        
        // Check for path traversal
        if containsPathTraversal(filename) {
            errors.append("Potential path traversal detected")
        }
        
        // Check for hidden files
        if filename.starts(with: ".") {
            warnings.append("Hidden file detected")
        }
        
        // Sanitize
        let sanitized = filename
            .replacingOccurrences(of: "[/\\\\:*?\"<>|]", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "\\.\\.", with: "_")
        
        return SanitizationResult(
            isValid: errors.isEmpty,
            sanitizedValue: sanitized,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func sanitizePath(_ input: String) -> SanitizationResult {
        var errors: [String] = []
        let warnings: [String] = []
        
        let path = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for path traversal
        if containsPathTraversal(path) {
            errors.append("Path traversal detected")
        }
        
        // Check for command injection
        if containsCommandInjection(path) {
            errors.append("Potential command injection in path")
        }
        
        // Check for absolute paths to sensitive directories
        let sensitivePaths = ["/etc", "/var", "/usr/bin", "/usr/sbin", "C:\\Windows", "C:\\System"]
        for sensitive in sensitivePaths {
            if path.starts(with: sensitive) {
                warnings.append("Path points to sensitive directory")
            }
        }
        
        // Sanitize by resolving path
        let sanitized = (path as NSString).standardizingPath
        
        return SanitizationResult(
            isValid: errors.isEmpty,
            sanitizedValue: sanitized,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func sanitizeCommand(_ input: String) -> SanitizationResult {
        var errors: [String] = []
        let warnings: [String] = []
        
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for command injection
        if containsCommandInjection(command) {
            errors.append("Command injection detected")
        }
        
        // Check for dangerous commands
        let dangerousCommands = ["rm -rf", "format", "del /f", "dd if=", ":(){ :|:& };:", "wget", "curl", "nc "]
        for dangerous in dangerousCommands {
            if command.lowercased().contains(dangerous) {
                errors.append("Dangerous command detected: \(dangerous)")
            }
        }
        
        // Escape special characters
        let escaped = command
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "&", with: "\\&")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        
        return SanitizationResult(
            isValid: errors.isEmpty,
            sanitizedValue: escaped,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func sanitizeGeneralText(_ input: String) -> SanitizationResult {
        var errors: [String] = []
        let warnings: [String] = []
        
        var sanitized = input
        
        // Check for XSS
        if containsXSS(sanitized) {
            warnings.append("Potential XSS content detected and removed")
            sanitized = removeXSS(from: sanitized)
        }
        
        // Check for SQL injection
        if containsSQLInjection(sanitized) {
            warnings.append("Potential SQL injection detected")
        }
        
        // HTML encode special characters
        sanitized = htmlEncode(sanitized)
        
        return SanitizationResult(
            isValid: errors.isEmpty,
            sanitizedValue: sanitized,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func sanitizeSearchQuery(_ input: String) -> SanitizationResult {
        var errors: [String] = []
        let warnings: [String] = []
        
        var query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove SQL operators
        let sqlOperators = ["SELECT", "INSERT", "UPDATE", "DELETE", "DROP", "CREATE", "ALTER", "UNION", "--", ";"]
        for op in sqlOperators {
            query = query.replacingOccurrences(of: op, with: "", options: .caseInsensitive)
        }
        
        // Escape special characters for search
        query = query
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
            .replacingOccurrences(of: "'", with: "''")
        
        return SanitizationResult(
            isValid: errors.isEmpty,
            sanitizedValue: query,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func sanitizeSQLQuery(_ input: String) -> SanitizationResult {
        var errors: [String] = []
        let warnings: [String] = []
        
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // This should use parameterized queries instead
        warnings.append("Use parameterized queries instead of direct SQL")
        
        // Check for multiple statements
        if query.contains(";") && !query.hasSuffix(";") {
            errors.append("Multiple SQL statements detected")
        }
        
        // Check for dangerous operations
        let dangerousOps = ["DROP", "DELETE", "TRUNCATE", "ALTER", "CREATE", "GRANT", "REVOKE"]
        for op in dangerousOps {
            if query.uppercased().contains(op) {
                warnings.append("Dangerous SQL operation: \(op)")
            }
        }
        
        return SanitizationResult(
            isValid: errors.isEmpty,
            sanitizedValue: query,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Detection Methods
    
    private func containsSQLInjection(_ input: String) -> Bool {
        for pattern in sqlInjectionPatterns {
            if matches(input.uppercased(), pattern: pattern) {
                logger.warning("SQL injection pattern detected: \(pattern)")
                return true
            }
        }
        return false
    }
    
    private func containsXSS(_ input: String) -> Bool {
        for pattern in xssPatterns {
            if matches(input.lowercased(), pattern: pattern) {
                logger.warning("XSS pattern detected: \(pattern)")
                return true
            }
        }
        return false
    }
    
    private func containsCommandInjection(_ input: String) -> Bool {
        for pattern in commandInjectionPatterns {
            if matches(input, pattern: pattern) {
                logger.warning("Command injection pattern detected: \(pattern)")
                return true
            }
        }
        return false
    }
    
    private func containsPathTraversal(_ input: String) -> Bool {
        for pattern in pathTraversalPatterns {
            if matches(input.lowercased(), pattern: pattern) {
                logger.warning("Path traversal pattern detected: \(pattern)")
                return true
            }
        }
        return false
    }
    
    // MARK: - Helper Methods
    
    private func matches(_ string: String, pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(location: 0, length: string.utf16.count)
            return regex.firstMatch(in: string, options: [], range: range) != nil
        } catch {
            logger.error("Regex error: \(error)")
            return false
        }
    }
    
    private func removeXSS(from input: String) -> String {
        var sanitized = input
        
        // Remove script tags
        sanitized = sanitized.replacingOccurrences(
            of: "<script[^>]*>.*?</script>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove event handlers
        sanitized = sanitized.replacingOccurrences(
            of: "on\\w+\\s*=\\s*[\"'][^\"']*[\"']",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove javascript: protocol
        sanitized = sanitized.replacingOccurrences(
            of: "javascript:",
            with: "",
            options: .caseInsensitive
        )
        
        return sanitized
    }
    
    private func htmlEncode(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    private func isCommonPassword(_ password: String) -> Bool {
        // Check against common passwords
        let commonPasswords = [
            "password", "123456", "password123", "admin", "letmein",
            "qwerty", "abc123", "111111", "123123", "welcome"
        ]
        
        return commonPasswords.contains(password.lowercased())
    }
}

// MARK: - Sanitization Result

public struct SanitizationResult {
    public let isValid: Bool
    public let sanitizedValue: String
    public let errors: [String]
    public let warnings: [String]
    
    public var hasErrors: Bool { !errors.isEmpty }
    public var hasWarnings: Bool { !warnings.isEmpty }
}