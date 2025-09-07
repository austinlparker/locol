import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCNIOTransportHTTP2Posix
import NIOPosix
import os

/// Manages the lifecycle of the OTLP gRPC server
/// Isolated from MainActor for better performance
@available(macOS 15.0, *)
actor OTLPServer: OTLPServerProtocol {
    private let logger = Logger.grpc
    private var server: GRPCServer<HTTP2ServerTransport.Posix>?
    private let storage: TelemetryStorageProtocol
    @MainActor private let settings: OTLPReceiverSettings
    
    // Statistics tracking
    private(set) var receivedTraces = 0
    private(set) var receivedMetrics = 0  
    private(set) var receivedLogs = 0
    private(set) var startTime: Date?
    
    init(storage: TelemetryStorageProtocol, settings: OTLPReceiverSettings) {
        self.storage = storage
        self.settings = settings
    }
    
    // MARK: - Settings Access
    
    @MainActor
    private func getSettings() -> (bindAddress: String, grpcPort: Int, tracesEnabled: Bool, metricsEnabled: Bool, logsEnabled: Bool) {
        return (
            bindAddress: settings.bindAddress,
            grpcPort: settings.grpcPort,
            tracesEnabled: settings.tracesEnabled,
            metricsEnabled: settings.metricsEnabled,
            logsEnabled: settings.logsEnabled
        )
    }
    
    // MARK: - Server Lifecycle
    
    /// Start the OTLP gRPC server
    func start() async throws {
        guard server == nil else {
            logger.warning("OTLP server is already running")
            return
        }
        
        let settings = await getSettings()
        
        logger.info("Starting OTLP gRPC server on \(settings.bindAddress):\(settings.grpcPort)")
        
        // Configure the server
        let server = GRPCServer(
            transport: .http2NIOPosix(
                address: .ipv4(host: settings.bindAddress, port: settings.grpcPort),
                transportSecurity: .plaintext
            ),
            services: await configureServices()
        )
        
        // Start the server
        try await server.serve()
        
        self.server = server
        self.startTime = Date()
        
        logger.info("OTLP gRPC server started successfully")
    }
    
    /// Stop the OTLP gRPC server
    func stop() async {
        guard let server = server else {
            logger.warning("OTLP server is not running")
            return
        }
        
        logger.info("Stopping OTLP gRPC server")
        
        server.beginGracefulShutdown()
        
        self.server = nil
        self.startTime = nil
        
        logger.info("OTLP gRPC server stopped")
    }
    
    /// Restart the OTLP gRPC server
    func restart() async throws {
        await stop()
        try await start()
    }
    
    /// Check if the server is currently running
    func isRunning() async -> Bool { server != nil }
    
    // MARK: - Statistics
    
    /// Get current server statistics
    func getStatistics() async -> ServerStatistics {
        let settings = await getSettings()
        return ServerStatistics(
            isRunning: server != nil,
            startTime: startTime,
            receivedTraces: receivedTraces,
            receivedMetrics: receivedMetrics,
            receivedLogs: receivedLogs,
            bindAddress: settings.bindAddress,
            grpcPort: settings.grpcPort
        )
    }
    
    /// Reset statistics counters
    func resetStatistics() async {
        receivedTraces = 0
        receivedMetrics = 0
        receivedLogs = 0
    }
    
    /// Increment trace counter
    func incrementTraces(by count: Int) async {
        receivedTraces += count
    }
    
    /// Increment metrics counter
    func incrementMetrics(by count: Int) async {
        receivedMetrics += count
    }
    
    /// Increment logs counter
    func incrementLogs(by count: Int) async {
        receivedLogs += count
    }
    
    // MARK: - Configuration
    
    private func configureServices() async -> [any RegistrableRPCService] {
        var services: [any RegistrableRPCService] = []
        let settings = await getSettings()
        let servicesFactory = OTLPServices(storage: storage, server: self)
        
        // Add trace service if enabled
        if settings.tracesEnabled {
            services.append(servicesFactory.traceService)
            logger.debug("Enabled OTLP Trace service")
        }
        
        // Add metrics service if enabled  
        if settings.metricsEnabled {
            services.append(servicesFactory.metricsService)
            logger.debug("Enabled OTLP Metrics service")
        }
        
        // Add logs service if enabled
        if settings.logsEnabled {
            services.append(servicesFactory.logsService)
            logger.debug("Enabled OTLP Logs service")
        }
        
        if services.isEmpty {
            logger.warning("No OTLP services are enabled - server will start but accept no requests")
        }
        
        return services
    }
}

// MARK: - Statistics Model

@available(macOS 15.0, *)
struct ServerStatistics: Sendable {
    let isRunning: Bool
    let startTime: Date?
    let receivedTraces: Int
    let receivedMetrics: Int
    let receivedLogs: Int
    let bindAddress: String
    let grpcPort: Int
    
    var uptime: TimeInterval? {
        guard let startTime = startTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }
    
    var totalRequests: Int {
        receivedTraces + receivedMetrics + receivedLogs
    }
}

// MARK: - Auto-Start Support

@available(macOS 15.0, *)
extension OTLPServer {
    
    /// Auto-start the server if enabled in settings
    func autoStartIfEnabled() async {
        // Check if auto-start is enabled (we could add this to settings)
        // For now, we'll start if any services are enabled
        let settings = await getSettings()
        if settings.tracesEnabled || settings.metricsEnabled || settings.logsEnabled {
            do {
                try await start()
                logger.info("OTLP server auto-started")
            } catch {
                logger.error("Failed to auto-start OTLP server: \(error)")
            }
        }
    }
    
    /// Stop server on app termination
    func stopOnAppTermination() async {
        if server != nil {
            await stop()
            logger.info("OTLP server stopped due to app termination")
        }
    }
}
