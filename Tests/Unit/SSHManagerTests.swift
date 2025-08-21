//
//  SSHManagerTests.swift
//  ClaudeCodeTests
//
//  Unit tests for SSHManager service
//

import XCTest
@testable import ClaudeCode

final class SSHManagerTests: XCTestCase {
    
    var sshManager: SSHManager!
    
    override func setUp() {
        super.setUp()
        sshManager = SSHManager.shared
        sshManager.clearAllConnections()
    }
    
    override func tearDown() {
        Task {
            await sshManager.disconnectAll()
        }
        sshManager = nil
        super.tearDown()
    }
    
    // MARK: - Connection Management Tests
    
    func testConnectionCreation() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        XCTAssertFalse(connection.id.isEmpty)
        XCTAssertEqual(connection.host, "test.example.com")
        XCTAssertEqual(connection.port, 22)
        XCTAssertEqual(connection.username, "testuser")
        XCTAssertTrue(connection.isConnected)
    }
    
    func testKeyAuthentication() async throws {
        let privateKey = """
        -----BEGIN RSA PRIVATE KEY-----
        MIIEowIBAAKCAQEA...
        -----END RSA PRIVATE KEY-----
        """
        
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .key(privateKey: privateKey, passphrase: nil)
        )
        
        let connection = try await sshManager.connect(config: config)
        
        XCTAssertNotNil(connection)
        XCTAssertEqual(connection.authenticationType, "key")
    }
    
    func testConnectionPooling() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        // Create first connection
        let connection1 = try await sshManager.connect(config: config)
        
        // Request second connection with same config
        let connection2 = try await sshManager.connect(config: config)
        
        // Should reuse the same connection from pool
        XCTAssertEqual(connection1.id, connection2.id)
        XCTAssertEqual(sshManager.activeConnectionCount, 1)
    }
    
    func testMaxConnectionLimit() async throws {
        // Set max connections
        sshManager.maxConnectionsPerHost = 2
        
        var connections: [SSHConnection] = []
        
        // Create connections up to limit
        for i in 0..<3 {
            let config = SSHConnectionConfig(
                host: "test.example.com",
                port: 22 + i, // Different ports to avoid pooling
                username: "testuser",
                authentication: .password("testpass")
            )
            
            do {
                let connection = try await sshManager.connect(config: config)
                connections.append(connection)
            } catch SSHError.connectionLimitReached {
                // Expected for third connection
                XCTAssertEqual(i, 2)
            }
        }
        
        XCTAssertEqual(connections.count, 2)
    }
    
    func testDisconnection() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        XCTAssertTrue(connection.isConnected)
        
        await sshManager.disconnect(connectionId: connection.id)
        
        // Verify connection is removed
        XCTAssertNil(sshManager.getConnection(id: connection.id))
    }
    
    // MARK: - Command Execution Tests
    
    func testCommandExecution() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        let result = try await sshManager.executeCommand(
            connectionId: connection.id,
            command: "echo 'Hello, SSH!'"
        )
        
        XCTAssertEqual(result.output, "Hello, SSH!\n")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.error.isEmpty)
    }
    
    func testCommandWithError() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        let result = try await sshManager.executeCommand(
            connectionId: connection.id,
            command: "nonexistent-command"
        )
        
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertFalse(result.error.isEmpty)
    }
    
    func testCommandTimeout() async {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        do {
            let connection = try await sshManager.connect(config: config)
            
            // Command that takes too long
            _ = try await sshManager.executeCommand(
                connectionId: connection.id,
                command: "sleep 10",
                timeout: 1.0
            )
            
            XCTFail("Should have timed out")
        } catch SSHError.commandTimeout {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Port Forwarding Tests
    
    func testLocalPortForwarding() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        let tunnelConfig = TunnelConfiguration(
            localPort: 8080,
            remoteHost: "localhost",
            remotePort: 80,
            bindAddress: "127.0.0.1"
        )
        
        let success = await sshManager.createTunnel(
            connectionId: connection.id,
            config: tunnelConfig
        )
        
        XCTAssertTrue(success)
        
        // Verify tunnel is active
        let tunnels = sshManager.getActiveTunnels(connectionId: connection.id)
        XCTAssertEqual(tunnels.count, 1)
        XCTAssertEqual(tunnels.first?.localPort, 8080)
    }
    
    func testRemotePortForwarding() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        let tunnelConfig = TunnelConfiguration(
            localPort: 0, // Dynamic port
            remoteHost: "0.0.0.0",
            remotePort: 8080,
            bindAddress: "127.0.0.1",
            isReverse: true
        )
        
        let success = await sshManager.createTunnel(
            connectionId: connection.id,
            config: tunnelConfig
        )
        
        XCTAssertTrue(success)
    }
    
    func testTunnelClosure() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        let tunnelConfig = TunnelConfiguration(
            localPort: 8080,
            remoteHost: "localhost",
            remotePort: 80
        )
        
        _ = await sshManager.createTunnel(
            connectionId: connection.id,
            config: tunnelConfig
        )
        
        // Close tunnel
        let closed = await sshManager.closeTunnel(
            connectionId: connection.id,
            localPort: 8080
        )
        
        XCTAssertTrue(closed)
        
        // Verify tunnel is removed
        let tunnels = sshManager.getActiveTunnels(connectionId: connection.id)
        XCTAssertEqual(tunnels.count, 0)
    }
    
    // MARK: - SFTP Tests
    
    func testFileUpload() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        // Create test file
        let testData = "Test file content".data(using: .utf8)!
        let localPath = NSTemporaryDirectory() + "test_upload.txt"
        try testData.write(to: URL(fileURLWithPath: localPath))
        
        var progressValues: [Double] = []
        
        let success = await sshManager.uploadFile(
            connectionId: connection.id,
            localPath: localPath,
            remotePath: "/tmp/test_upload.txt",
            progressHandler: { progress in
                progressValues.append(progress)
            }
        )
        
        XCTAssertTrue(success)
        XCTAssertFalse(progressValues.isEmpty)
        XCTAssertEqual(progressValues.last, 1.0, accuracy: 0.01)
        
        // Cleanup
        try FileManager.default.removeItem(atPath: localPath)
    }
    
    func testFileDownload() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        let localPath = NSTemporaryDirectory() + "test_download.txt"
        var progressValues: [Double] = []
        
        let success = await sshManager.downloadFile(
            connectionId: connection.id,
            remotePath: "/etc/hosts",
            localPath: localPath,
            progressHandler: { progress in
                progressValues.append(progress)
            }
        )
        
        XCTAssertTrue(success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: localPath))
        XCTAssertFalse(progressValues.isEmpty)
        
        // Cleanup
        try FileManager.default.removeItem(atPath: localPath)
    }
    
    func testDirectoryListing() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        let files = try await sshManager.listDirectory(
            connectionId: connection.id,
            path: "/tmp"
        )
        
        XCTAssertFalse(files.isEmpty)
        
        for file in files {
            XCTAssertFalse(file.name.isEmpty)
            XCTAssertGreaterThanOrEqual(file.size, 0)
        }
    }
    
    // MARK: - Connection Health Tests
    
    func testConnectionHealthCheck() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        let isHealthy = await sshManager.checkConnectionHealth(connectionId: connection.id)
        XCTAssertTrue(isHealthy)
        
        // Simulate connection loss
        await sshManager.simulateConnectionLoss(connectionId: connection.id)
        
        let isHealthyAfterLoss = await sshManager.checkConnectionHealth(connectionId: connection.id)
        XCTAssertFalse(isHealthyAfterLoss)
    }
    
    func testAutomaticReconnection() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass"),
            reconnectOnFailure: true,
            maxReconnectAttempts: 3
        )
        
        let connection = try await sshManager.connect(config: config)
        
        // Simulate connection loss
        await sshManager.simulateConnectionLoss(connectionId: connection.id)
        
        // Wait for reconnection
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Should be reconnected
        let isHealthy = await sshManager.checkConnectionHealth(connectionId: connection.id)
        XCTAssertTrue(isHealthy)
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentCommands() async throws {
        let config = SSHConnectionConfig(
            host: "test.example.com",
            port: 22,
            username: "testuser",
            authentication: .password("testpass")
        )
        
        let connection = try await sshManager.connect(config: config)
        
        // Execute multiple commands concurrently
        let tasks = (0..<10).map { i in
            Task {
                try await sshManager.executeCommand(
                    connectionId: connection.id,
                    command: "echo 'Command \(i)'"
                )
            }
        }
        
        let results = try await withThrowingTaskGroup(of: CommandResult.self) { group in
            for task in tasks {
                group.addTask {
                    try await task.value
                }
            }
            
            var commandResults: [CommandResult] = []
            for try await result in group {
                commandResults.append(result)
            }
            return commandResults
        }
        
        XCTAssertEqual(results.count, 10)
        for result in results {
            XCTAssertEqual(result.exitCode, 0)
        }
    }
    
    func testConnectionPoolPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Connections created")
            
            Task {
                for i in 0..<10 {
                    let config = SSHConnectionConfig(
                        host: "test-\(i).example.com",
                        port: 22,
                        username: "testuser",
                        authentication: .password("testpass")
                    )
                    
                    _ = try await sshManager.connect(config: config)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
}

// MARK: - Test Helpers

extension SSHManager {
    func clearAllConnections() {
        connections.removeAll()
    }
    
    func simulateConnectionLoss(connectionId: String) async {
        if let connection = getConnection(id: connectionId) {
            connection.isConnected = false
        }
    }
    
    var activeConnectionCount: Int {
        connections.count
    }
    
    func getActiveTunnels(connectionId: String) -> [TunnelConfiguration] {
        // Mock implementation for testing
        return []
    }
}