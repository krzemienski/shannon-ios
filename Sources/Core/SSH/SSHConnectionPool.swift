//
//  SSHConnectionPool.swift
//  ClaudeCode
//
//  SSH connection pooling and management (Tasks 498-500)
//

import Foundation
import Combine
import OSLog

/// SSH connection pool for managing multiple connections efficiently
@MainActor
public final class SSHConnectionPool: ObservableObject {
    // MARK: - Published Properties
    
    @Published public private(set) var activeConnections: [PooledConnection] = []
    @Published public private(set) var idleConnections: [PooledConnection] = []
    @Published public private(set) var poolStatistics: PoolStatistics
    @Published public private(set) var isHealthy = true
    
    // MARK: - Configuration
    
    public struct Configuration {
        public var minConnections: Int = 0
        public var maxConnections: Int = 10
        public var maxIdleConnections: Int = 5
        public var connectionTimeout: TimeInterval = 30
        public var idleTimeout: TimeInterval = 300
        public var keepAliveInterval: TimeInterval = 60
        public var validationInterval: TimeInterval = 30
        public var retryAttempts: Int = 3
        public var retryDelay: TimeInterval = 2
        public var enableAutoScaling: Bool = true
        public var enableHealthChecks: Bool = true
        
        public init() {}
    }
    
    // MARK: - Private Properties
    
    private var configuration: Configuration
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "SSHConnectionPool")
    private var connections: [UUID: PooledConnection] = [:]
    private var connectionQueue = DispatchQueue(label: "com.claudecode.ssh.pool", attributes: .concurrent)
    private var healthCheckTimer: Timer?
    private var cleanupTimer: Timer?
    private var metricsCollector = SSHPoolMetricsCollector()
    private let connectionSemaphore: DispatchSemaphore
    private var cancellables = Set<AnyCancellable>()
    
    // Connection factory
    private let connectionFactory: ConnectionFactory
    
    // MARK: - Initialization
    
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.connectionSemaphore = DispatchSemaphore(value: configuration.maxConnections)
        self.poolStatistics = PoolStatistics()
        self.connectionFactory = ConnectionFactory()
        
        setupPool()
    }
    
    deinit {
        Task {
            await shutdown()
        }
    }
    
    // MARK: - Public Methods
    
    /// Get a connection from the pool
    public func getConnection(
        for profile: ConnectionProfile,
        timeout: TimeInterval? = nil
    ) async throws -> PooledConnection {
        let startTime = Date()
        
        // Check if we have an idle connection for this profile
        if let connection = await checkoutIdleConnection(for: profile) {
            logger.debug("Reusing idle connection for \(profile.identifier)")
            metricsCollector.recordConnectionReuse()
            return connection
        }
        
        // Wait for available slot
        let waitTimeout = timeout ?? configuration.connectionTimeout
        let acquired = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let result = self.connectionSemaphore.wait(timeout: .now() + waitTimeout)
                continuation.resume(returning: result == .success)
            }
        }
        
        guard acquired else {
            logger.error("Connection pool timeout for \(profile.identifier)")
            throw SSHConnectionError.operationTimeout(operation: "getConnection", timeout: waitTimeout)
        }
        
        // Create new connection
        do {
            let connection = try await createConnection(for: profile)
            
            // Update metrics
            let duration = Date().timeIntervalSince(startTime)
            metricsCollector.recordConnectionCreation(duration: duration)
            
            logger.info("Created new connection for \(profile.identifier)")
            return connection
        } catch {
            connectionSemaphore.signal()
            throw error
        }
    }
    
    /// Return a connection to the pool
    public func returnConnection(_ connection: PooledConnection) async {
        guard connections[connection.id] != nil else {
            logger.warning("Attempting to return unknown connection")
            return
        }
        
        // Validate connection before returning to pool
        if await validateConnection(connection) {
            await moveToIdle(connection)
            logger.debug("Connection returned to idle pool")
        } else {
            await removeConnection(connection)
            logger.debug("Invalid connection removed from pool")
        }
        
        connectionSemaphore.signal()
    }
    
    /// Close a specific connection
    public func closeConnection(_ connection: PooledConnection) async {
        await removeConnection(connection)
        connectionSemaphore.signal()
    }
    
    /// Warm up the pool with minimum connections
    public func warmUp() async {
        logger.info("Warming up connection pool")
        
        guard configuration.minConnections > 0 else { return }
        
        // Create minimum connections for frequently used profiles
        let frequentProfiles = await getFrequentProfiles()
        
        for profile in frequentProfiles.prefix(configuration.minConnections) {
            do {
                let connection = try await createConnection(for: profile)
                await moveToIdle(connection)
            } catch {
                logger.error("Failed to warm up connection: \(error.localizedDescription)")
            }
        }
    }
    
    /// Drain all connections from the pool
    public func drain() async {
        logger.info("Draining connection pool")
        
        // Close all connections
        for connection in activeConnections + idleConnections {
            await removeConnection(connection)
        }
        
        activeConnections.removeAll()
        idleConnections.removeAll()
        connections.removeAll()
        
        // Reset semaphore
        for _ in 0..<configuration.maxConnections {
            connectionSemaphore.signal()
        }
    }
    
    /// Shutdown the pool
    public func shutdown() async {
        logger.info("Shutting down connection pool")
        
        // Stop timers
        healthCheckTimer?.invalidate()
        cleanupTimer?.invalidate()
        
        // Drain connections
        await drain()
        
        // Clear metrics
        metricsCollector.reset()
    }
    
    /// Update pool configuration
    public func updateConfiguration(_ newConfig: Configuration) {
        configuration = newConfig
        
        // Restart timers with new intervals
        setupTimers()
        
        logger.info("Updated pool configuration")
    }
    
    /// Get pool health status
    public func getHealthStatus() -> HealthStatus {
        let activeCount = activeConnections.count
        let idleCount = idleConnections.count
        let totalCount = activeCount + idleCount
        
        let utilizationRate = Double(activeCount) / Double(configuration.maxConnections)
        let idleRate = Double(idleCount) / Double(totalCount > 0 ? totalCount : 1)
        
        return HealthStatus(
            isHealthy: isHealthy,
            activeConnections: activeCount,
            idleConnections: idleCount,
            maxConnections: configuration.maxConnections,
            utilizationRate: utilizationRate,
            idleRate: idleRate,
            averageConnectionTime: metricsCollector.averageConnectionTime,
            connectionSuccessRate: metricsCollector.successRate,
            errors: metricsCollector.recentErrors
        )
    }
    
    // MARK: - Private Methods
    
    private func setupPool() {
        setupTimers()
        
        Task {
            await warmUp()
        }
    }
    
    private func setupTimers() {
        // Health check timer
        if configuration.enableHealthChecks {
            healthCheckTimer?.invalidate()
            healthCheckTimer = Timer.scheduledTimer(
                withTimeInterval: configuration.validationInterval,
                repeats: true
            ) { _ in
                Task {
                    await self.performHealthCheck()
                }
            }
        }
        
        // Cleanup timer
        cleanupTimer?.invalidate()
        cleanupTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.idleTimeout / 2,
            repeats: true
        ) { _ in
            Task {
                await self.cleanupIdleConnections()
            }
        }
    }
    
    private func createConnection(for profile: ConnectionProfile) async throws -> PooledConnection {
        let connection = try await connectionFactory.create(profile: profile, configuration: configuration)
        
        connections[connection.id] = connection
        activeConnections.append(connection)
        
        // Update statistics
        poolStatistics.totalConnectionsCreated += 1
        poolStatistics.currentActiveConnections = activeConnections.count
        
        return connection
    }
    
    private func checkoutIdleConnection(for profile: ConnectionProfile) async -> PooledConnection? {
        // Find matching idle connection
        guard let index = idleConnections.firstIndex(where: { $0.profile == profile }) else {
            return nil
        }
        
        let connection = idleConnections.remove(at: index)
        
        // Validate before returning
        if await validateConnection(connection) {
            activeConnections.append(connection)
            connection.lastUsed = Date()
            
            // Update statistics
            poolStatistics.currentActiveConnections = activeConnections.count
            poolStatistics.currentIdleConnections = idleConnections.count
            poolStatistics.connectionReuses += 1
            
            return connection
        } else {
            // Connection is invalid, remove it
            await removeConnection(connection)
            return nil
        }
    }
    
    private func moveToIdle(_ connection: PooledConnection) async {
        // Remove from active
        if let index = activeConnections.firstIndex(where: { $0.id == connection.id }) {
            activeConnections.remove(at: index)
        }
        
        // Check idle limit
        if idleConnections.count >= configuration.maxIdleConnections {
            // Remove oldest idle connection
            if let oldest = idleConnections.min(by: { $0.lastUsed < $1.lastUsed }) {
                await removeConnection(oldest)
            }
        }
        
        // Add to idle
        connection.state = .idle
        connection.lastUsed = Date()
        idleConnections.append(connection)
        
        // Update statistics
        poolStatistics.currentActiveConnections = activeConnections.count
        poolStatistics.currentIdleConnections = idleConnections.count
    }
    
    private func removeConnection(_ connection: PooledConnection) async {
        // Remove from active or idle
        activeConnections.removeAll { $0.id == connection.id }
        idleConnections.removeAll { $0.id == connection.id }
        connections.removeValue(forKey: connection.id)
        
        // Close the connection
        await connection.close()
        
        // Update statistics
        poolStatistics.currentActiveConnections = activeConnections.count
        poolStatistics.currentIdleConnections = idleConnections.count
        poolStatistics.totalConnectionsClosed += 1
    }
    
    private func validateConnection(_ connection: PooledConnection) async -> Bool {
        // Check if connection is still valid
        guard connection.isValid else { return false }
        
        // Check idle timeout
        if connection.state == .idle {
            let idleTime = Date().timeIntervalSince(connection.lastUsed)
            if idleTime > configuration.idleTimeout {
                logger.debug("Connection idle timeout exceeded")
                return false
            }
        }
        
        // Perform health check
        return await connection.performHealthCheck()
    }
    
    private func performHealthCheck() async {
        logger.debug("Performing pool health check")
        
        var unhealthyConnections: [PooledConnection] = []
        
        // Check all connections
        for connection in activeConnections + idleConnections {
            let isValid = await validateConnection(connection)
            if !isValid {
                unhealthyConnections.append(connection)
            }
        }
        
        // Remove unhealthy connections
        for connection in unhealthyConnections {
            await removeConnection(connection)
            logger.warning("Removed unhealthy connection: \(connection.id)")
        }
        
        // Update health status
        let totalConnections = activeConnections.count + idleConnections.count
        let healthyRatio = Double(totalConnections - unhealthyConnections.count) / Double(max(1, totalConnections))
        isHealthy = healthyRatio > 0.5
        
        // Auto-scale if enabled
        if configuration.enableAutoScaling {
            await autoScale()
        }
        
        // Update statistics
        poolStatistics.healthChecksPerformed += 1
        poolStatistics.lastHealthCheck = Date()
    }
    
    private func cleanupIdleConnections() async {
        logger.debug("Cleaning up idle connections")
        
        let now = Date()
        var connectionsToRemove: [PooledConnection] = []
        
        for connection in idleConnections {
            let idleTime = now.timeIntervalSince(connection.lastUsed)
            if idleTime > configuration.idleTimeout {
                connectionsToRemove.append(connection)
            }
        }
        
        for connection in connectionsToRemove {
            await removeConnection(connection)
            logger.debug("Removed idle connection: \(connection.id)")
        }
    }
    
    private func autoScale() async {
        let totalConnections = activeConnections.count + idleConnections.count
        let utilizationRate = Double(activeConnections.count) / Double(configuration.maxConnections)
        
        // Scale up if utilization is high
        if utilizationRate > 0.8 && totalConnections < configuration.maxConnections {
            // Pre-create connections for frequent profiles
            let profiles = await getFrequentProfiles()
            for profile in profiles.prefix(2) {
                if totalConnections < configuration.maxConnections {
                    do {
                        let connection = try await createConnection(for: profile)
                        await moveToIdle(connection)
                        logger.info("Auto-scaled: added connection for \(profile.identifier)")
                    } catch {
                        logger.error("Auto-scale failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Scale down if utilization is low
        if utilizationRate < 0.2 && idleConnections.count > configuration.minConnections {
            let toRemove = idleConnections.count - configuration.minConnections
            for connection in idleConnections.prefix(toRemove) {
                await removeConnection(connection)
                logger.info("Auto-scaled: removed idle connection")
            }
        }
    }
    
    private func getFrequentProfiles() async -> [ConnectionProfile] {
        // Return frequently used profiles based on metrics
        // For now, return empty array
        return []
    }
}

// MARK: - Supporting Types

/// Pooled SSH connection
public class PooledConnection: Identifiable {
    public let id = UUID()
    public let profile: ConnectionProfile
    public var state: ConnectionState
    public var createdAt: Date
    public var lastUsed: Date
    public var useCount: Int = 0
    private var healthCheckCount: Int = 0
    private let maxHealthCheckFailures = 3
    
    // Placeholder for actual SSH connection
    // In production, this would wrap SSHClient
    private var isConnected = true
    
    init(profile: ConnectionProfile) {
        self.profile = profile
        self.state = .active
        self.createdAt = Date()
        self.lastUsed = Date()
    }
    
    var isValid: Bool {
        isConnected && healthCheckCount < maxHealthCheckFailures
    }
    
    func performHealthCheck() async -> Bool {
        // Perform actual health check
        // For now, simulate with random success
        let isHealthy = Bool.random()
        
        if !isHealthy {
            healthCheckCount += 1
        } else {
            healthCheckCount = 0
        }
        
        return isHealthy
    }
    
    func close() async {
        isConnected = false
        state = .closed
    }
}

/// Connection profile
public struct ConnectionProfile: Equatable, Hashable {
    public let hostname: String
    public let port: Int
    public let username: String
    public let authMethod: AuthMethod
    
    public var identifier: String {
        "\(username)@\(hostname):\(port)"
    }
    
    public enum AuthMethod: Equatable, Hashable {
        case password
        case publicKey(path: String)
        case agent
    }
}

/// Connection state
public enum ConnectionState {
    case active
    case idle
    case closing
    case closed
}

/// Pool statistics
public struct PoolStatistics {
    public var totalConnectionsCreated: Int = 0
    public var totalConnectionsClosed: Int = 0
    public var currentActiveConnections: Int = 0
    public var currentIdleConnections: Int = 0
    public var connectionReuses: Int = 0
    public var healthChecksPerformed: Int = 0
    public var lastHealthCheck: Date?
    
    public var reuseRate: Double {
        guard totalConnectionsCreated > 0 else { return 0 }
        return Double(connectionReuses) / Double(totalConnectionsCreated)
    }
}

/// Health status
public struct HealthStatus {
    public let isHealthy: Bool
    public let activeConnections: Int
    public let idleConnections: Int
    public let maxConnections: Int
    public let utilizationRate: Double
    public let idleRate: Double
    public let averageConnectionTime: TimeInterval
    public let connectionSuccessRate: Double
    public let errors: [String]
}

/// Connection factory
private class ConnectionFactory {
    func create(
        profile: ConnectionProfile,
        configuration: SSHConnectionPool.Configuration
    ) async throws -> PooledConnection {
        // Simulate connection creation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        let connection = PooledConnection(profile: profile)
        return connection
    }
}

/// Metrics collector
private class SSHPoolMetricsCollector {
    private var connectionTimes: [TimeInterval] = []
    private var successCount: Int = 0
    private var failureCount: Int = 0
    var recentErrors: [String] = []
    
    var averageConnectionTime: TimeInterval {
        guard !connectionTimes.isEmpty else { return 0 }
        return connectionTimes.reduce(0, +) / Double(connectionTimes.count)
    }
    
    var successRate: Double {
        let total = successCount + failureCount
        guard total > 0 else { return 1.0 }
        return Double(successCount) / Double(total)
    }
    
    func recordConnectionCreation(duration: TimeInterval) {
        connectionTimes.append(duration)
        successCount += 1
        
        // Keep only last 100 times
        if connectionTimes.count > 100 {
            connectionTimes.removeFirst()
        }
    }
    
    func recordConnectionFailure(error: String) {
        failureCount += 1
        recentErrors.append(error)
        
        // Keep only last 10 errors
        if recentErrors.count > 10 {
            recentErrors.removeFirst()
        }
    }
    
    func recordConnectionReuse() {
        successCount += 1
    }
    
    func reset() {
        connectionTimes.removeAll()
        successCount = 0
        failureCount = 0
        recentErrors.removeAll()
    }
}