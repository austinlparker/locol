import Foundation
import AppKit
import os
import Observation
import GRPCCore
import GRPCNIOTransportHTTP2

@available(macOS 15.0, *)
@Observable
class OTLPGRPCReceiver {
    static let shared = OTLPGRPCReceiver()
    
    private let logger = Logger.app
    private let settings = OTLPReceiverSettings.shared
    
    private(set) var isRunning: Bool = false
    private(set) var receivedTracesCount: Int = 0
    private(set) var receivedMetricsCount: Int = 0
    private(set) var receivedLogsCount: Int = 0
    
    // Internal methods for updating counts
    @MainActor
    func incrementTracesCount(by count: Int) {
        receivedTracesCount += count
    }
    
    @MainActor
    func incrementMetricsCount(by count: Int) {
        receivedMetricsCount += count
    }
    
    @MainActor
    func incrementLogsCount(by count: Int) {
        receivedLogsCount += count
    }
    
    private var serverTask: Task<Void, Never>?
    
    private init() {
        // Start the server automatically when the singleton is created
        Task {
            await startServerIfEnabled()
        }
        
        // Register for app termination to cleanup
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.stopServer()
            }
        }
    }
    
    @MainActor
    private func startServerIfEnabled() async {
        // Only start if settings indicate we should
        guard settings.tracesEnabled || settings.metricsEnabled || settings.logsEnabled else {
            logger.info("OTLP receiver disabled - no signals enabled")
            return
        }
        
        do {
            try await start()
        } catch {
            logger.error("Failed to auto-start OTLP receiver: \(error)")
        }
    }
    
    @MainActor
    func start() async throws {
        guard !isRunning else { return }
        
        logger.info("Starting gRPC OTLP receiver on \(self.settings.grpcEndpoint)")
        
        // Create gRPC server
        let server = GRPCServer(
            transport: .http2NIOPosix(
                address: .ipv4(host: self.settings.bindAddress, port: self.settings.grpcPort),
                transportSecurity: .plaintext,
                config: .defaults { config in
                    // Use default configuration
                }
            ),
            services: [
                OTLPTraceService(receiver: self),
                OTLPMetricsService(receiver: self),
                OTLPLogsService(receiver: self)
            ]
        )
        
        // Start server in background task
        serverTask = Task {
            do {
                try await server.serve()
                logger.info("gRPC OTLP receiver server finished")
            } catch {
                logger.error("gRPC OTLP receiver server error: \(error)")
            }
        }
        
        // Give the server a moment to start
        try await Task.sleep(for: .milliseconds(100))
        
        isRunning = true
        logger.info("gRPC OTLP receiver started successfully")
    }
    
    @MainActor
    func stopServer() async {
        guard isRunning else { return }
        
        logger.info("Stopping gRPC OTLP receiver")
        
        // Stop the server by canceling the task
        serverTask?.cancel()
        
        // Wait for server to stop
        _ = await serverTask?.result
        
        serverTask = nil
        isRunning = false
        
        logger.info("gRPC OTLP receiver stopped")
    }
    
    // Public method to restart server when settings change
    @MainActor
    func restart() async {
        await stopServer()
        await startServerIfEnabled()
    }
    
    deinit {
        serverTask?.cancel()
    }
}