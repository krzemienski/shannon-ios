//
//  NetworkConfiguration.swift
//  ClaudeCode
//
//  Network configuration for localhost development and production
//

import Foundation
import Network
import OSLog

/// Network configuration manager for dynamic localhost resolution
@MainActor
public class NetworkConfiguration: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = NetworkConfiguration()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "NetworkConfiguration")
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.claudecode.network.monitor")
    
    @Published public var currentHostIP: String = "192.168.0.155"
    @Published public var isConnected: Bool = false
    @Published public var connectionType: ConnectionType = .unknown
    @Published public var backendStatus: BackendStatus = .unknown
    
    // Host machine IP detection
    private var detectedHostIP: String?
    private let defaultHostIP = "192.168.0.155"  // Fallback IP
    
    // MARK: - Types
    
    public enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    public enum BackendStatus {
        case running
        case notRunning
        case checking
        case unknown
    }
    
    public struct BackendEndpoint {
        let baseURL: String
        let healthURL: String
        let webSocketURL: String
        
        init(hostIP: String, port: Int = 8000) {
            self.baseURL = "http://\(hostIP):\(port)/v1"
            self.healthURL = "http://\(hostIP):\(port)/health"
            self.webSocketURL = "ws://\(hostIP):\(port)/ws"
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        setupNetworkMonitoring()
        detectHostMachineIP()
    }
    
    // MARK: - Public Methods
    
    /// Get the current backend endpoint configuration
    public func getCurrentEndpoint() -> BackendEndpoint {
        let ip = getActiveHostIP()
        return BackendEndpoint(hostIP: ip)
    }
    
    /// Get the appropriate host IP based on runtime environment
    public func getActiveHostIP() -> String {
        #if targetEnvironment(simulator)
        // iOS Simulator: Use detected or default host machine IP
        return detectedHostIP ?? currentHostIP
        #else
        // Physical device: Use the actual host IP or configured IP
        return currentHostIP
        #endif
    }
    
    /// Get all possible localhost URLs to try
    public func getLocalhostVariants() -> [String] {
        let hostIP = getActiveHostIP()
        return [
            "http://\(hostIP):8000/v1",      // Primary: Host machine IP
            "http://localhost:8000/v1",       // Localhost (simulator only)
            "http://127.0.0.1:8000/v1",       // Loopback
            "http://0.0.0.0:8000/v1"          // All interfaces
        ]
    }
    
    /// Test backend connectivity with multiple endpoints
    public func testBackendConnectivity() async -> (isReachable: Bool, workingEndpoint: String?) {
        backendStatus = .checking
        
        let endpoints = getLocalhostVariants()
        
        for endpoint in endpoints {
            let healthURL = endpoint.replacingOccurrences(of: "/v1", with: "/health")
            
            if await testEndpoint(healthURL) {
                logger.info("✅ Backend reachable at: \(endpoint)")
                backendStatus = .running
                
                // Update the current host IP if different
                if let url = URL(string: endpoint),
                   let host = url.host,
                   host != "localhost" && host != "0.0.0.0" {
                    await MainActor.run {
                        self.currentHostIP = host
                    }
                }
                
                return (true, endpoint)
            }
        }
        
        logger.error("❌ Backend not reachable at any endpoint")
        backendStatus = .notRunning
        return (false, nil)
    }
    
    /// Update host IP address manually
    public func updateHostIP(_ ip: String) {
        currentHostIP = ip
        detectedHostIP = ip
        logger.info("Host IP updated to: \(ip)")
        
        Task {
            _ = await testBackendConnectivity()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .ethernet
                } else {
                    self?.connectionType = .unknown
                }
                
                self?.logger.info("Network status: \(path.status == .satisfied ? "Connected" : "Disconnected") via \(self?.connectionType.description ?? "unknown")")
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func detectHostMachineIP() {
        // Try to detect the host machine IP automatically
        Task {
            if let ip = await getHostMachineIP() {
                await MainActor.run {
                    self.detectedHostIP = ip
                    self.currentHostIP = ip
                    self.logger.info("Detected host machine IP: \(ip)")
                }
            } else {
                logger.warning("Could not detect host IP, using default: \(self.defaultHostIP)")
            }
        }
    }
    
    private func getHostMachineIP() async -> String? {
        // For simulator, we need the Mac's local network IP
        #if targetEnvironment(simulator)
        // Try to get the IP from the en0 interface (usually WiFi)
        let interfaces = getNetworkInterfaces()
        
        // Prefer en0 (WiFi) but fallback to en1 or others
        for interface in ["en0", "en1", "en2"] {
            if let ip = interfaces[interface] {
                return ip
            }
        }
        
        // Return first available IP
        return interfaces.values.first
        #else
        // On device, return nil to use configured IP
        return nil
        #endif
    }
    
    private func getNetworkInterfaces() -> [String: String] {
        var interfaces: [String: String] = [:]
        
        // Get list of all interfaces on the local machine
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return interfaces }
        guard let firstAddr = ifaddr else { return interfaces }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 interface
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                
                // Get interface name
                let name = String(cString: interface.ifa_name)
                
                // Convert interface address to a human readable string
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                           &hostname, socklen_t(hostname.count),
                           nil, socklen_t(0), NI_NUMERICHOST)
                
                let address = String(cString: hostname)
                
                // Filter out loopback and link-local addresses
                if !address.starts(with: "127.") && !address.starts(with: "169.254.") {
                    interfaces[name] = address
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return interfaces
    }
    
    private func testEndpoint(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 3.0  // Quick timeout for testing
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            // Silently fail, we'll log at the higher level
            return false
        }
    }
}

// MARK: - Extensions

extension NetworkConfiguration.ConnectionType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - Health Response Model

struct HealthResponse: Codable {
    let status: String
    let version: String?
    let timestamp: Date?
    let services: [String: String]?
}