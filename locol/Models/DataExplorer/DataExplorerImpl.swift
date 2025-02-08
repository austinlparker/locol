import Foundation
import DuckDB
import os
import Network

@Observable
final class DataExplorer: DataExplorerProtocol {
    static let shared = DataExplorer()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DataExplorer")
    private var server: OTLPServer?
    private let database: DatabaseProtocol
    private let resourceHandler: ResourceHandler
    private let metricsHandler: MetricsHandler
    private let logsHandler: LogsHandler
    private let spansHandler: SpansHandler
    
    private(set) var serverPort: UInt16
    @MainActor private(set) var isRunning: Bool = false {
        didSet {
            logger.info("DataExplorer isRunning changed to: \(self.isRunning)")
        }
    }
    var error: Error?
    
    private init() {
        // Initialize with default port
        serverPort = 49152
        
        // Initialize database and handlers
        database = DatabaseManager()
        resourceHandler = ResourceHandler(database: database)
        metricsHandler = MetricsHandler(database: database)
        logsHandler = LogsHandler(database: database)
        spansHandler = SpansHandler(database: database)
        
        // Find an available port after initialization
        Task {
            if let port = await Self.findAvailablePort() {
                serverPort = port
                logger.info("DataExplorer initialized with port \(self.serverPort)")
            }
        }
    }
    
    private static func findAvailablePort() async -> UInt16? {
        // Try to find an available port starting from 49152 (first dynamic port)
        for _ in 0..<100 { // Limit retries to avoid infinite loop
            guard let listener = try? NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: 0)!) else {
                continue
            }
            
            // Set up a connection handler to avoid the "Started without setting handler" warning
            listener.newConnectionHandler = { connection in
                connection.cancel()
            }
            
            let port = await withCheckedContinuation { continuation in
                var hasResumed = false
                
                listener.stateUpdateHandler = { state in
                    guard !hasResumed else { return }
                    
                    switch state {
                    case .ready:
                        if let port = listener.port?.rawValue {
                            hasResumed = true
                            // First stop accepting new connections
                            listener.stateUpdateHandler = nil
                            listener.newConnectionHandler = nil
                            
                            // Then cancel the listener and wait a brief moment for cleanup
                            listener.cancel()
                            
                            // Return the port
                            continuation.resume(returning: port)
                        }
                    case .failed, .cancelled:
                        hasResumed = true
                        listener.cancel()
                        continuation.resume(returning: 0)  // Return 0 to indicate failure
                    case .setup, .waiting:
                        // These are intermediate states, don't resume yet
                        break
                    @unknown default:
                        hasResumed = true
                        listener.cancel()
                        continuation.resume(returning: 0)  // Return 0 to indicate failure
                    }
                }
                
                listener.start(queue: .main)
            }
            
            if port > 0 {  // Only use non-zero ports
                // Add a small delay to ensure proper socket cleanup
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                return port
            }
        }
        
        return nil
    }
    
    @MainActor
    func start() async throws {
        guard !isRunning else {
            self.logger.info("Start called but server is already running")
            return
        }
        
        self.logger.info("Starting server on port \(self.serverPort)...")
        
        // If we have an existing server instance, clean it up first
        if server != nil {
            self.logger.info("Found existing server instance, cleaning up first")
            await stop()
        }
        
        do {
            // Reset error state
            error = nil
            
            // Create new server instance
            let newServer = OTLPServer(port: self.serverPort)
            
            self.logger.info("Created new server instance on port \(self.serverPort), attempting to start...")
            
            // Start the server and wait for it to be ready
            try await newServer.start()
            
            // Check if the server is actually running
            guard await newServer.isRunning else {
                throw OTLPError.serverNotRunning
            }
            
            // If we get here, the server started successfully
            self.server = newServer
            self.isRunning = true
            self.logger.info("Server started successfully on port \(self.serverPort) and isRunning set to true")
            
            // Start processing requests in the background
            Task {
                await processRequests(server: newServer)
            }
        } catch {
            self.logger.error("Failed to start server on port \(self.serverPort): \(error.localizedDescription)")
            self.error = error
            self.isRunning = false
            self.server = nil
            throw error
        }
    }
    
    private enum OTLPError: Error {
        case serverNotRunning
        
        var localizedDescription: String {
            switch self {
            case .serverNotRunning:
                return "Server failed to start"
            }
        }
    }
    
    private func processRequests(server: OTLPServer) async {
        do {
            self.logger.info("Starting to process requests")
            for try await request in await server.requests {
                switch request {
                case .traces(let tracesRequest):
                    for resourceSpans in tracesRequest.resourceSpans {
                        let resource = resourceSpans.resource
                        let resourceId = try await resourceHandler.handleResource(resource)
                        for scopeSpans in resourceSpans.scopeSpans {
                            let scope = scopeSpans.scope
                            let scopeId = try handleScope(scope, resourceId: resourceId)
                            for span in scopeSpans.spans {
                                try await spansHandler.handleSpan(span, resourceId: resourceId, scopeId: scopeId)
                            }
                        }
                    }
                case .metrics(let metricsRequest):
                    for resourceMetrics in metricsRequest.resourceMetrics {
                        let resource = resourceMetrics.resource
                        let resourceId = try await resourceHandler.handleResource(resource)
                        for scopeMetrics in resourceMetrics.scopeMetrics {
                            let scope = scopeMetrics.scope
                            let scopeId = try handleScope(scope, resourceId: resourceId)
                            for metric in scopeMetrics.metrics {
                                try await metricsHandler.handleMetric(metric, resourceId: resourceId, scopeId: scopeId)
                            }
                        }
                    }
                case .logs(let logsRequest):
                    for resourceLogs in logsRequest.resourceLogs {
                        let resource = resourceLogs.resource
                        let resourceId = try await resourceHandler.handleResource(resource)
                        for scopeLogs in resourceLogs.scopeLogs {
                            let scope = scopeLogs.scope
                            let scopeId = try handleScope(scope, resourceId: resourceId)
                            for log in scopeLogs.logRecords {
                                try await logsHandler.handleLog(log, resourceId: resourceId, scopeId: scopeId)
                            }
                        }
                    }
                case .profiles(let profilesRequest):
                    self.logger.debug("Received profiles request")
                    // TODO: Implement profile handling if needed
                }
            }
        } catch {
            self.logger.error("Error processing requests: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    @MainActor
    func stop() async {
        // If we're not running and have no server, nothing to do
        guard isRunning || server != nil else {
            logger.info("Stop called but server is not running and no server instance exists")
            return
        }
        
        logger.info("Stopping server...")
        
        // Stop the server
        if let server = server {
            await server.stop()
            self.server = nil
            logger.info("Server instance stopped and cleared")
        }
        
        isRunning = false
        logger.info("Server stopped and isRunning set to false")
    }
    
    private func handleScope(_ scope: Opentelemetry_Proto_Common_V1_InstrumentationScope, resourceId: UUID) throws -> UUID {
        let scopeId = UUID()
        let attributes = JSONUtils.attributesToJSON(scope.attributes)
        
        let appender = try database.createAppender(for: "instrumentation_scopes")
        
        try appender.append(Timestamp(Foundation.Date()))
        try appender.append(scopeId.uuidString)
        try appender.append(resourceId.uuidString)
        try appender.append(scope.name)
        try appender.append(scope.version)
        try appender.append(attributes)
        try appender.append(Int32(scope.droppedAttributesCount))
        try appender.endRow()
        try appender.flush()
        
        return scopeId
    }
    
    // MARK: - DataExplorerProtocol
    
    var metrics: [MetricRow] { [] }
    var logs: [LogRow] { [] }
    var spans: [SpanRow] { [] }
    var resources: [ResourceRow] { [] }
    
    var metricColumns: [String] { [] }
    var logColumns: [String] { [] }
    var spanColumns: [String] { [] }
    var resourceColumns: [String] { [] }
    
    func getResourceGroups() async -> [ResourceAttributeGroup] {
        []
    }
    
    func getResourceIds(forGroup group: ResourceAttributeGroup) async -> [String] {
        group.resourceIds
    }
    
    func getMetrics(forResourceIds resourceIds: [String]) async -> [MetricRow] {
        []
    }
    
    func getLogs(forResourceIds resourceIds: [String]) async -> [LogRow] {
        []
    }
    
    func getSpans(forResourceIds resourceIds: [String]) async -> [SpanRow] {
        []
    }
    
    func executeQuery(_ query: String) async throws -> ResultSet {
        try await database.executeQuery(query)
    }
} 