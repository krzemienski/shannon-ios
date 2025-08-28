//
//  PerformanceProfiler.swift
//  ClaudeCode
//
//  Performance profiling and metrics collection for optimization tracking
//

import Foundation
import UIKit
import os.log
import QuartzCore

/// Performance profiler for tracking app metrics and optimizations
@MainActor
final class PerformanceProfiler: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PerformanceProfiler()
    
    // MARK: - Published Metrics
    @Published var currentFPS: Double = 60.0
    @Published var memoryUsageMB: Double = 0.0
    @Published var cpuUsagePercent: Double = 0.0
    @Published var appLaunchTime: TimeInterval = 0.0
    @Published var networkLatency: TimeInterval = 0.0
    @Published var cacheHitRate: Double = 0.0
    
    // MARK: - Performance Thresholds
    struct Thresholds {
        static let targetFPS: Double = 60.0
        static let maxMemoryMB: Double = 200.0
        static let maxCPUPercent: Double = 80.0
        static let targetLaunchTime: TimeInterval = 1.0
        static let maxNetworkLatency: TimeInterval = 0.5
    }
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.claudecode.ios", category: "Performance")
    private var displayLink: CADisplayLink?
    private var frameTimestamps: [TimeInterval] = []
    private var memoryTimer: Timer?
    private var cpuTimer: Timer?
    private var launchStartTime: Date?
    
    // Metrics collection
    private var performanceMetrics: [PerformanceMetric] = []
    private let metricsQueue = DispatchQueue(label: "com.claudecode.metrics", attributes: .concurrent)
    
    // MARK: - Initialization
    private init() {
        setupMonitoring()
    }
    
    private func setupMonitoring() {
        startFPSMonitoring()
        startMemoryMonitoring()
        startCPUMonitoring()
        recordLaunchTime()
    }
    
    // MARK: - Launch Time Tracking
    
    func markAppLaunchStart() {
        launchStartTime = Date()
    }
    
    func markAppLaunchComplete() {
        guard let startTime = launchStartTime else { return }
        appLaunchTime = Date().timeIntervalSince(startTime)
        
        logger.info("App launch time: \(self.appLaunchTime, format: .fixed(precision: 2))s")
        
        if appLaunchTime > Thresholds.targetLaunchTime {
            logger.warning("App launch time exceeds target: \(self.appLaunchTime, format: .fixed(precision: 2))s > \(Thresholds.targetLaunchTime)s")
        }
    }
    
    private func recordLaunchTime() {
        if launchStartTime == nil {
            markAppLaunchStart()
        }
    }
    
    // MARK: - FPS Monitoring
    
    private func startFPSMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateFPS(_ displayLink: CADisplayLink) {
        let timestamp = displayLink.timestamp
        frameTimestamps.append(timestamp)
        
        // Keep only last second of timestamps
        let oneSecondAgo = timestamp - 1.0
        frameTimestamps = frameTimestamps.filter { $0 > oneSecondAgo }
        
        // Calculate FPS
        currentFPS = Double(frameTimestamps.count)
        
        // Log if FPS drops below target
        if currentFPS < Thresholds.targetFPS - 5 {
            logger.warning("FPS dropped to \(self.currentFPS, format: .fixed(precision: 1))")
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            memoryUsageMB = usedMemoryMB
            
            if usedMemoryMB > Thresholds.maxMemoryMB {
                logger.warning("Memory usage exceeds threshold: \(usedMemoryMB, format: .fixed(precision: 1))MB > \(Thresholds.maxMemoryMB)MB")
            }
        }
    }
    
    // MARK: - CPU Monitoring
    
    private func startCPUMonitoring() {
        cpuTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCPUUsage()
        }
    }
    
    private func updateCPUUsage() {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                        PROCESSOR_CPU_LOAD_INFO,
                                        &numCpus,
                                        &cpuInfo,
                                        &numCpuInfo)
        
        guard result == KERN_SUCCESS else { return }
        
        var totalUsage: Double = 0
        let cpuLoadInfo = cpuInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(numCpus)) { ptr in
            return ptr
        }
        
        for i in 0..<Int(numCpus) {
            let cpu = cpuLoadInfo[i]
            let userTime = Double(cpu.cpu_ticks.0)
            let systemTime = Double(cpu.cpu_ticks.1)
            let idleTime = Double(cpu.cpu_ticks.2)
            let niceTime = Double(cpu.cpu_ticks.3)
            
            let total = userTime + systemTime + idleTime + niceTime
            if total > 0 {
                let usage = (userTime + systemTime) / total * 100
                totalUsage += usage
            }
        }
        
        cpuUsagePercent = totalUsage / Double(numCpus)
        
        if cpuUsagePercent > Thresholds.maxCPUPercent {
            logger.warning("CPU usage exceeds threshold: \(self.cpuUsagePercent, format: .fixed(precision: 1))% > \(Thresholds.maxCPUPercent)%")
        }
    }
    
    // MARK: - Network Performance
    
    func recordNetworkLatency(_ latency: TimeInterval) {
        networkLatency = latency
        
        if latency > Thresholds.maxNetworkLatency {
            logger.warning("Network latency exceeds threshold: \(latency, format: .fixed(precision: 3))s > \(Thresholds.maxNetworkLatency)s")
        }
    }
    
    // MARK: - Cache Performance
    
    func updateCacheMetrics(hitRate: Double) {
        cacheHitRate = hitRate
        
        if hitRate < 0.5 {
            logger.info("Low cache hit rate: \(hitRate * 100, format: .fixed(precision: 1))%")
        }
    }
    
    // MARK: - Performance Reports
    
    func generatePerformanceReport() -> PerformanceReport {
        PerformanceReport(
            timestamp: Date(),
            fps: currentFPS,
            memoryUsageMB: memoryUsageMB,
            cpuUsagePercent: cpuUsagePercent,
            appLaunchTime: appLaunchTime,
            networkLatency: networkLatency,
            cacheHitRate: cacheHitRate,
            metrics: performanceMetrics
        )
    }
    
    func logPerformanceReport() {
        let report = generatePerformanceReport()
        
        logger.info("""
        === Performance Report ===
        FPS: \(report.fps, format: .fixed(precision: 1)) (target: \(Thresholds.targetFPS))
        Memory: \(report.memoryUsageMB, format: .fixed(precision: 1))MB (max: \(Thresholds.maxMemoryMB)MB)
        CPU: \(report.cpuUsagePercent, format: .fixed(precision: 1))% (max: \(Thresholds.maxCPUPercent)%)
        Launch Time: \(report.appLaunchTime, format: .fixed(precision: 2))s (target: \(Thresholds.targetLaunchTime)s)
        Network Latency: \(report.networkLatency, format: .fixed(precision: 3))s
        Cache Hit Rate: \(report.cacheHitRate * 100, format: .fixed(precision: 1))%
        ========================
        """)
    }
    
    // MARK: - Cleanup
    
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        
        memoryTimer?.invalidate()
        memoryTimer = nil
        
        cpuTimer?.invalidate()
        cpuTimer = nil
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Supporting Types

struct PerformanceMetric {
    let name: String
    let value: Double
    let timestamp: Date
    let category: MetricCategory
    
    enum MetricCategory {
        case memory
        case cpu
        case network
        case ui
        case cache
    }
}

// PerformanceReport is defined in Core/Telemetry/PerformanceMonitor.swift
// Using the public PerformanceReport from PerformanceMonitor
typealias PerformanceReport = PerformanceMonitor.PerformanceReport