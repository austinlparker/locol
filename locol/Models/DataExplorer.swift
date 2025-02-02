import Foundation
import DuckDB
import os
import Network
import TabularData

enum DatabaseError: Error {
    case connectionFailed
    case queryFailed(String)
    case appenderFailedToInitialize(reason: String?)
    case appenderFailedToAppendItem(reason: String?)
}

@Observable
final class DataExplorer {
    static let shared = DataExplorer()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DataExplorer")
    private var server: OTLPServer?
    private var database: Database?
    private var connection: Connection?
    private var resourcesAppender: Appender?
    private var resourceAttributesAppender: Appender?
    private var resourceAttributeMappingsAppender: Appender?
    private var scopesAppender: Appender?
    private var spansAppender: Appender?
    private var metricsAppender: Appender?
    private var logsAppender: Appender?
    
    private(set) var serverPort: UInt16
    @MainActor var isRunning: Bool = false {
        didSet {
            logger.info("DataExplorer isRunning changed to: \(self.isRunning)")
        }
    }
    var error: Error?
    
    // Model data
    @MainActor private(set) var metrics: [MetricRow] = []
    @MainActor private(set) var logs: [LogRow] = []
    @MainActor private(set) var spans: [SpanRow] = []
    @MainActor private(set) var resources: [ResourceRow] = []
    
    // Helper computed properties for column names
    @MainActor var metricColumns: [String] { metrics.map(\.name) }
    @MainActor var logColumns: [String] { logs.map { $0.timestamp.formatted() } }
    @MainActor var spanColumns: [String] { spans.map(\.name) }
    @MainActor var resourceColumns: [String] { resources.map(\.id) }
    
    struct MetricRow: Identifiable {
        let id = UUID()
        let name: String
        let description_p: String
        let unit: String
        let type: String
        let time: Foundation.Date
        let value: Double
        let attributes: String
        let resourceId: String
    }
    
    struct LogRow: Identifiable {
        let id = UUID()
        let timestamp: Foundation.Date
        let severityText: String
        let severityNumber: Int32
        let body: String
        let attributes: String
        let resourceId: String
    }
    
    struct SpanRow: Identifiable {
        let id = UUID()
        let traceId: String
        let spanId: String
        let parentSpanId: String
        let name: String
        let kind: Int32
        let startTime: Foundation.Date
        let endTime: Foundation.Date
        let attributes: String
        let resourceId: String
    }
    
    struct ResourceRow: Identifiable, Hashable {
        let id: String // Using resource_id as the identifier
        let timestamp: Foundation.Date
        let droppedAttributesCount: Int32
        let attributes: [(key: String, value: String)]
        
        // Implement Hashable
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(timestamp)
            hasher.combine(droppedAttributesCount)
        }
        
        // Implement Equatable (required by Hashable)
        static func == (lhs: ResourceRow, rhs: ResourceRow) -> Bool {
            lhs.id == rhs.id &&
            lhs.timestamp == rhs.timestamp &&
            lhs.droppedAttributesCount == rhs.droppedAttributesCount
        }
    }
    
    struct ResourceAttributeGroup: Identifiable, Hashable {
        let id = UUID()
        let key: String
        let value: String
        let resourceIds: [String]
        var count: Int { resourceIds.count }
        
        var displayName: String {
            if key == "service.name" {
                return value
            } else {
                return "\(key): \(value)"
            }
        }
        
        // Implement Hashable
        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
            hasher.combine(value)
        }
        
        // Implement Equatable (required by Hashable)
        static func == (lhs: ResourceAttributeGroup, rhs: ResourceAttributeGroup) -> Bool {
            lhs.key == rhs.key && lhs.value == rhs.value
        }
    }
    
    private init() {
        // Find an available port first
        serverPort = 49152 // Default port as fallback
        Task {
            if let port = await Self.findAvailablePort() {
                serverPort = port
                logger.info("DataExplorer initialized with port \(self.serverPort)")
            }
        }
        
        // Defer database setup to avoid blocking initialization
        Task {
            await setupDatabase()
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
    
    private func setupDatabase() async {
        do {
            database = try Database(store: .inMemory)
            connection = try database?.connect()
            
            // Create tables for resources, scopes, and signals
            try connection?.execute("""
                CREATE TABLE resource_attributes (
                    attribute_id VARCHAR PRIMARY KEY,
                    key VARCHAR,
                    value VARCHAR,
                    timestamp TIMESTAMP,
                    UNIQUE(key, value)
                );

                CREATE TABLE resource_attribute_mappings (
                    resource_id VARCHAR,
                    attribute_id VARCHAR,
                    PRIMARY KEY (resource_id, attribute_id)
                );

                CREATE TABLE resources (
                    resource_id VARCHAR PRIMARY KEY,
                    timestamp TIMESTAMP,
                    dropped_attributes_count INTEGER
                );

                CREATE TABLE instrumentation_scopes (
                    timestamp TIMESTAMP,
                    scope_id VARCHAR PRIMARY KEY,
                    resource_id VARCHAR,
                    name VARCHAR,
                    version VARCHAR,
                    attributes JSON,
                    dropped_attributes_count INTEGER
                );

                CREATE TABLE spans (
                    trace_id VARCHAR,
                    span_id VARCHAR,
                    parent_span_id VARCHAR,
                    resource_id VARCHAR,
                    scope_id VARCHAR,
                    name VARCHAR,
                    kind INTEGER,
                    attributes JSON,
                    start_time TIMESTAMP,
                    end_time TIMESTAMP,
                    PRIMARY KEY (trace_id, span_id)
                );
                
                CREATE TABLE metric_points (
                    metric_point_id VARCHAR PRIMARY KEY,
                    resource_id VARCHAR,
                    scope_id VARCHAR,
                    metric_name VARCHAR,
                    description VARCHAR,
                    unit VARCHAR,
                    type VARCHAR,
                    value DOUBLE,
                    attributes JSON,
                    time TIMESTAMP
                );
                
                CREATE TABLE log_records (
                    log_id VARCHAR PRIMARY KEY,
                    resource_id VARCHAR,
                    scope_id VARCHAR,
                    severity_text VARCHAR,
                    severity_number INTEGER,
                    body TEXT,
                    attributes JSON,
                    timestamp TIMESTAMP
                );

                -- Indexes for common query patterns
                CREATE INDEX idx_spans_resource ON spans(resource_id);
                CREATE INDEX idx_spans_time ON spans(start_time);
                CREATE INDEX idx_metric_points_resource ON metric_points(resource_id);
                CREATE INDEX idx_metric_points_time ON metric_points(time);
                CREATE INDEX idx_log_records_resource ON log_records(resource_id);
                CREATE INDEX idx_log_records_time ON log_records(timestamp);
                CREATE INDEX idx_resource_attributes_key ON resource_attributes(key);
                CREATE INDEX idx_resource_attributes_value ON resource_attributes(value);
                CREATE INDEX idx_resource_attribute_mappings_resource ON resource_attribute_mappings(resource_id);
                CREATE INDEX idx_resource_attribute_mappings_attribute ON resource_attribute_mappings(attribute_id);
            """)
            
            // Create appenders for each table
            if let conn = connection {
                resourcesAppender = try Appender(connection: conn, table: "resources")
                resourceAttributesAppender = try Appender(connection: conn, table: "resource_attributes")
                resourceAttributeMappingsAppender = try Appender(connection: conn, table: "resource_attribute_mappings")
                scopesAppender = try Appender(connection: conn, table: "instrumentation_scopes")
                spansAppender = try Appender(connection: conn, table: "spans")
                metricsAppender = try Appender(connection: conn, table: "metric_points")
                logsAppender = try Appender(connection: conn, table: "log_records")
            }
            
            logger.info("Database setup completed successfully")
        } catch {
            logger.error("Failed to setup database: \(error.localizedDescription)")
            self.error = error
        }
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
            
            // Initial refresh of all data
            await refreshAll()
            
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
                        for scopeSpans in resourceSpans.scopeSpans {
                            let scope = scopeSpans.scope
                            for span in scopeSpans.spans {
                                await handleSpan(span, resource: resource, scope: scope)
                            }
                        }
                    }
                    await refreshResources()
                case .metrics(let metricsRequest):
                    for resourceMetrics in metricsRequest.resourceMetrics {
                        let resource = resourceMetrics.resource
                        for scopeMetrics in resourceMetrics.scopeMetrics {
                            let scope = scopeMetrics.scope
                            for metric in scopeMetrics.metrics {
                                await handleMetric(metric, resource: resource, scope: scope)
                            }
                        }
                    }
                    await refreshResources()
                case .logs(let logsRequest):
                    for resourceLogs in logsRequest.resourceLogs {
                        let resource = resourceLogs.resource
                        for scopeLogs in resourceLogs.scopeLogs {
                            let scope = scopeLogs.scope
                            for log in scopeLogs.logRecords {
                                await handleLog(log, resource: resource, scope: scope)
                            }
                        }
                    }
                    await refreshResources()
                case .profiles(let profilesRequest):
                    self.logger.debug("Received profiles request")
                    // TODO: Implement profile handling if needed
                }
            }
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
        
        // Flush and close appenders
        try? resourcesAppender?.flush()
        try? resourceAttributesAppender?.flush()
        try? resourceAttributeMappingsAppender?.flush()
        try? scopesAppender?.flush()
        try? spansAppender?.flush()
        try? metricsAppender?.flush()
        try? logsAppender?.flush()
        
        // Stop the server
        if let server = server {
            await server.stop()
            self.server = nil
            logger.info("Server instance stopped and cleared")
        }
        
        isRunning = false
        logger.info("Server stopped and isRunning set to false")
    }
    
    private func handleResource(_ resource: Opentelemetry_Proto_Resource_V1_Resource) throws -> UUID {
        guard let connection = connection,
              let resourcesAppender = resourcesAppender,
              let resourceAttributesAppender = resourceAttributesAppender,
              let resourceAttributeMappingsAppender = resourceAttributeMappingsAppender else {
            throw DatabaseError.appenderFailedToInitialize(reason: "One or more appenders are nil")
        }
        
        let resourceId = UUID()
        let now = Foundation.Date()
        
        // First, insert the resource
        try resourcesAppender.append(resourceId.uuidString)
        try resourcesAppender.append(Timestamp(now))
        try resourcesAppender.append(Int32(resource.droppedAttributesCount))
        try resourcesAppender.endRow()
        try resourcesAppender.flush()
        
        // Then handle each attribute
        for attr in resource.attributes {
            // Try to find existing attribute with same key-value pair
            let result = try connection.query("""
                SELECT attribute_id 
                FROM resource_attributes 
                WHERE key = '\(attr.key)' AND value = '\(attr.value.stringValue)'
            """)
            
            let attributeId: String
            let existingIds = result[0].cast(to: String.self)
            if !existingIds.isEmpty, let existingId = existingIds[0] {
                // Use existing attribute
                attributeId = existingId
            } else {
                // Create new attribute
                attributeId = UUID().uuidString
                try resourceAttributesAppender.append(attributeId)
                try resourceAttributesAppender.append(attr.key)
                try resourceAttributesAppender.append(attr.value.stringValue)
                try resourceAttributesAppender.append(Timestamp(now))
                try resourceAttributesAppender.endRow()
                try resourceAttributesAppender.flush()
            }
            
            // Create mapping
            try resourceAttributeMappingsAppender.append(resourceId.uuidString)
            try resourceAttributeMappingsAppender.append(attributeId)
            try resourceAttributeMappingsAppender.endRow()
            try resourceAttributeMappingsAppender.flush()
        }
        
        return resourceId
    }
    
    private func handleScope(_ scope: Opentelemetry_Proto_Common_V1_InstrumentationScope, resourceId: UUID) throws -> UUID {
        guard let appender = scopesAppender else {
            throw DatabaseError.appenderFailedToInitialize(reason: "Scopes appender is nil")
        }
        
        let scopeId = UUID()
        let attributes = attributesToJSON(scope.attributes)
        
        // Append in column order: timestamp, scope_id, resource_id, name, version, attributes, dropped_attributes_count
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
    
    private func handleSpan(_ span: Opentelemetry_Proto_Trace_V1_Span, resource: Opentelemetry_Proto_Resource_V1_Resource? = nil, scope: Opentelemetry_Proto_Common_V1_InstrumentationScope? = nil) async {
        do {
            let resourceId = try resource.map { try handleResource($0) } ?? UUID()
            let scopeId = try scope.map { try handleScope($0, resourceId: resourceId) } ?? UUID()
            
            guard let appender = spansAppender else {
                logger.error("Spans appender is nil")
                return
            }
            
            let attributes = attributesToJSON(span.attributes)
            let startTime = Foundation.Date(timeIntervalSince1970: TimeInterval(span.startTimeUnixNano) / 1_000_000_000)
            let endTime = Foundation.Date(timeIntervalSince1970: TimeInterval(span.endTimeUnixNano) / 1_000_000_000)
            
            try appender.append(span.traceID.hexString)
            try appender.append(span.spanID.hexString)
            try appender.append(span.parentSpanID.hexString)
            try appender.append(resourceId.uuidString)
            try appender.append(scopeId.uuidString)
            try appender.append(span.name)
            try appender.append(Int32(span.kind.rawValue))
            try appender.append(attributes)
            try appender.append(Timestamp(startTime))
            try appender.append(Timestamp(endTime))
            try appender.endRow()
            try appender.flush()
            
            await refreshSpans()
        } catch {
            logger.error("Failed to insert span: \(error.localizedDescription)")
        }
    }
    
    private func handleMetric(_ metric: Opentelemetry_Proto_Metrics_V1_Metric, resource: Opentelemetry_Proto_Resource_V1_Resource? = nil, scope: Opentelemetry_Proto_Common_V1_InstrumentationScope? = nil) async {
        do {
            let resourceId = try resource.map { try handleResource($0) } ?? UUID()
            let scopeId = try scope.map { try handleScope($0, resourceId: resourceId) } ?? UUID()
            
            guard let appender = metricsAppender else {
                logger.error("Metrics appender is nil")
                return
            }
            
            let (value, time) = extractMetricValue(metric)
            let metricPointId = UUID()
            
            // Append in column order: metric_point_id, resource_id, scope_id, metric_name, description, unit, type, value, attributes, time
            try appender.append(metricPointId.uuidString)
            try appender.append(resourceId.uuidString)
            try appender.append(scopeId.uuidString)
            try appender.append(metric.name)
            try appender.append(metric.description_p)
            try appender.append(metric.unit)
            try appender.append(metric.data.debugDescription)
            try appender.append(value)
            try appender.append(attributesToJSON(metric.metadata))
            try appender.append(Timestamp(time))
            try appender.endRow()
            try appender.flush()
            
            await refreshMetrics()
        } catch {
            logger.error("Failed to insert metric: \(error.localizedDescription)")
        }
    }
    
    private func handleLog(_ log: Opentelemetry_Proto_Logs_V1_LogRecord, resource: Opentelemetry_Proto_Resource_V1_Resource? = nil, scope: Opentelemetry_Proto_Common_V1_InstrumentationScope? = nil) async {
        do {
            let resourceId = try resource.map { try handleResource($0) } ?? UUID()
            let scopeId = try scope.map { try handleScope($0, resourceId: resourceId) } ?? UUID()
            
            guard let appender = logsAppender else {
                logger.error("Logs appender is nil")
                return
            }
            
            let logId = UUID()
            let timestamp = Foundation.Date(timeIntervalSince1970: TimeInterval(log.timeUnixNano) / 1_000_000_000)
            
            // Append in column order: log_id, resource_id, scope_id, severity_text, severity_number, body, attributes, timestamp
            try appender.append(logId.uuidString)
            try appender.append(resourceId.uuidString)
            try appender.append(scopeId.uuidString)
            try appender.append(log.severityText)
            try appender.append(Int32(log.severityNumber.rawValue))
            try appender.append(log.body.stringValue)
            try appender.append(attributesToJSON(log.attributes))
            try appender.append(Timestamp(timestamp))
            try appender.endRow()
            try appender.flush()
            
            await refreshLogs()
        } catch {
            logger.error("Failed to insert log: \(error.localizedDescription)")
        }
    }
    
    private func extractMetricValue(_ metric: Opentelemetry_Proto_Metrics_V1_Metric) -> (Double, Foundation.Date) {
        switch metric.data {
        case .gauge(let gauge):
            if let point = gauge.dataPoints.first {
                return (point.toDouble, Foundation.Date(timeIntervalSince1970: TimeInterval(point.timeUnixNano) / 1_000_000_000))
            }
        case .sum(let sum):
            if let point = sum.dataPoints.first {
                return (point.toDouble, Foundation.Date(timeIntervalSince1970: TimeInterval(point.timeUnixNano) / 1_000_000_000))
            }
        default:
            break
        }
        return (0.0, Foundation.Date())
    }
    
    private func attributesToJSON(_ attributes: [Opentelemetry_Proto_Common_V1_KeyValue]) -> String {
        var dict: [String: Any] = [:]
        for attr in attributes {
            dict[attr.key] = attr.value.stringValue
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
    
    private func attributesToJSON(_ attributes: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: attributes),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
    
    @MainActor
    private func refreshMetrics() async {
        guard let connection = connection else { return }
        do {
            let result = try connection.query("""
                SELECT 
                    m.metric_name,
                    m.description,
                    m.unit,
                    m.type,
                    m.time,
                    m.value,
                    m.attributes,
                    m.resource_id
                FROM metric_points m
            """)
            
            let rowCount = result.rowCount
            var newMetrics: [MetricRow] = []
            
            for i in 0..<rowCount {
                let name = result[0].cast(to: String.self)[i] ?? ""
                let description = result[1].cast(to: String.self)[i] ?? ""
                let unit = result[2].cast(to: String.self)[i] ?? ""
                let type = result[3].cast(to: String.self)[i] ?? ""
                let time = result[4].cast(to: Date.self)[i] ?? Date()
                let value = result[5].cast(to: Double.self)[i] ?? 0.0
                let attributes = result[6].cast(to: String.self)[i] ?? "{}"
                let resourceId = result[7].cast(to: String.self)[i] ?? ""
                
                newMetrics.append(MetricRow(
                    name: name,
                    description_p: description,
                    unit: unit,
                    type: type,
                    time: time,
                    value: value,
                    attributes: attributes,
                    resourceId: resourceId
                ))
            }
            
            self.metrics = newMetrics
        } catch {
            logger.error("Failed to refresh metrics: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func refreshLogs() async {
        guard let connection = connection else {
            self.logger.error("No database connection available")
            return
        }
        
        do {
            let result = try connection.query("""
                SELECT 
                    l.timestamp,
                    l.severity_text,
                    l.severity_number,
                    l.body,
                    l.attributes,
                    l.resource_id
                FROM log_records l
            """)
            
            let rowCount = result.rowCount
            var newLogs: [LogRow] = []
            
            for i in 0..<rowCount {
                let timestamp = result[0].cast(to: Date.self)[i] ?? Date()
                let severityText = result[1].cast(to: String.self)[i] ?? ""
                let severityNumber = result[2].cast(to: Int32.self)[i] ?? 0
                let body = result[3].cast(to: String.self)[i] ?? ""
                let attributes = result[4].cast(to: String.self)[i] ?? "{}"
                let resourceId = result[5].cast(to: String.self)[i] ?? ""
                
                newLogs.append(LogRow(
                    timestamp: timestamp,
                    severityText: severityText,
                    severityNumber: severityNumber,
                    body: body,
                    attributes: attributes,
                    resourceId: resourceId
                ))
            }
            
            self.logs = newLogs
        } catch {
            self.logger.error("Failed to refresh logs: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func refreshSpans() async {
        guard let connection = connection else { return }
        do {
            let result = try connection.query("""
                SELECT 
                    s.trace_id,
                    s.span_id,
                    s.parent_span_id,
                    s.name,
                    s.kind,
                    s.start_time,
                    s.end_time,
                    s.attributes,
                    s.resource_id
                FROM spans s
            """)
            
            let rowCount = result.rowCount
            var newSpans: [SpanRow] = []
            
            for i in 0..<rowCount {
                let traceId = result[0].cast(to: String.self)[i] ?? ""
                let spanId = result[1].cast(to: String.self)[i] ?? ""
                let parentSpanId = result[2].cast(to: String.self)[i] ?? ""
                let name = result[3].cast(to: String.self)[i] ?? ""
                let kind = result[4].cast(to: Int32.self)[i] ?? 0
                let startTime = result[5].cast(to: Date.self)[i] ?? Date()
                let endTime = result[6].cast(to: Date.self)[i] ?? Date()
                let attributes = result[7].cast(to: String.self)[i] ?? "{}"
                let resourceId = result[8].cast(to: String.self)[i] ?? ""
                
                newSpans.append(SpanRow(
                    traceId: traceId,
                    spanId: spanId,
                    parentSpanId: parentSpanId,
                    name: name,
                    kind: kind,
                    startTime: startTime,
                    endTime: endTime,
                    attributes: attributes,
                    resourceId: resourceId
                ))
            }
            
            self.spans = newSpans
        } catch {
            logger.error("Failed to refresh spans: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func refreshResources() async {
        guard let connection = connection else { return }
        do {
            let result = try connection.query("""
                SELECT 
                    r.resource_id,
                    r.timestamp,
                    r.dropped_attributes_count,
                    GROUP_CONCAT(ra.key || ':' || ra.value, ';') as attributes
                FROM resources r
                LEFT JOIN resource_attribute_mappings ram ON r.resource_id = ram.resource_id
                LEFT JOIN resource_attributes ra ON ram.attribute_id = ra.attribute_id
                GROUP BY r.resource_id, r.timestamp, r.dropped_attributes_count
            """)
            
            let rowCount = result.rowCount
            var newResources: [ResourceRow] = []
            
            for i in 0..<rowCount {
                let resourceId = result[0].cast(to: String.self)[i] ?? ""
                let timestamp = result[1].cast(to: Date.self)[i] ?? Date()
                let droppedCount = result[2].cast(to: Int32.self)[i] ?? 0
                let attributesStr = result[3].cast(to: String.self)[i] ?? ""
                
                // Parse attributes from the concatenated string
                let attributes: [(key: String, value: String)] = attributesStr.split(separator: ";")
                    .compactMap { pair in
                        let parts = pair.split(separator: ":")
                        guard parts.count == 2 else { return nil }
                        return (key: String(parts[0]), value: String(parts[1]))
                    }
                
                newResources.append(ResourceRow(
                    id: resourceId,
                    timestamp: timestamp,
                    droppedAttributesCount: droppedCount,
                    attributes: attributes
                ))
            }
            
            self.resources = newResources
        } catch {
            logger.error("Failed to refresh resources: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func refreshAll() async {
        await refreshMetrics()
        await refreshLogs()
        await refreshSpans()
        await refreshResources()
    }
    
    // Add method to execute custom queries
    private func parseJsonColumn(_ jsonString: String) -> [String: String] {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        
        return json.reduce(into: [:]) { result, pair in
            // Convert any value to string representation
            let stringValue: String
            switch pair.value {
            case let num as NSNumber:
                stringValue = num.stringValue
            case let str as String:
                stringValue = str
            case let bool as Bool:
                stringValue = bool ? "true" : "false"
            case let array as [Any]:
                stringValue = array.map { "\($0)" }.joined(separator: ", ")
            case is NSNull:
                stringValue = "null"
            default:
                stringValue = "\(pair.value)"
            }
            result[pair.key] = stringValue
        }
    }
    
    private func expandJsonColumns(_ columns: [DuckDB.Column<String>]) -> [(name: String, values: [String], isJsonExpanded: Bool)] {
        var expandedColumns: [(name: String, values: [String], isJsonExpanded: Bool)] = []
        
        for column in columns {
            let columnName = column.name
            let dbType = column.underlyingDatabaseType
            
            // Check if this is a potential JSON column (all JSON is stored as varchar)
            if dbType == .varchar {
                let values = column.cast(to: String.self)
                let sampleValue = values.prefix(5).compactMap { $0 }.first ?? ""
                
                // Check if this looks like a JSON object
                if sampleValue.starts(with: "{") && sampleValue.hasSuffix("}") {
                    // Get all unique keys from the JSON objects
                    var jsonKeys = Set<String>()
                    let parsedRows = values.map { jsonStr -> [String: String] in
                        let parsed = parseJsonColumn(jsonStr ?? "{}")
                        jsonKeys.formUnion(parsed.keys)
                        return parsed
                    }
                    
                    // Create a column for each JSON key
                    for key in jsonKeys.sorted() {
                        let columnValues = parsedRows.map { row in
                            row[key] ?? "null"
                        }
                        expandedColumns.append((
                            name: "\(columnName).\(key)",
                            values: columnValues,
                            isJsonExpanded: true
                        ))
                    }
                    continue
                }
            }
            
            // Handle non-JSON columns as before
            let values: [String]
            switch dbType {
            case .date, .timestamp, .timestampS, .timestampMS, .timestampNS, .time, .timeTz:
                values = column.cast(to: Date.self).map { $0?.formatted() ?? "null" }
            case .double, .float:
                values = column.cast(to: Double.self).map { $0.map { String(format: "%.6f", $0) } ?? "null" }
            case .integer:
                values = column.cast(to: Int32.self).map { $0.map(String.init) ?? "null" }
            case .bigint:
                values = column.cast(to: Int64.self).map { $0.map(String.init) ?? "null" }
            case .decimal:
                values = column.cast(to: Decimal.self).map { $0.map(String.init) ?? "null" }
            case .boolean:
                values = column.cast(to: Bool.self).map { $0.map(String.init) ?? "null" }
            case .varchar, .uuid:
                values = column.cast(to: String.self).map { $0 ?? "null" }
            default:
                values = column.cast(to: String.self).map { $0 ?? "null" }
            }
            
            expandedColumns.append((name: columnName, values: values, isJsonExpanded: false))
        }
        
        return expandedColumns
    }
    
    func executeQuery(_ query: String) async throws -> [String: [Any]] {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed
        }
        
        let result = try connection.query(query)
        var data: [String: [Any]] = [:]
        
        // Get column names and data
        for i in 0..<result.columnCount {
            let column = result[i]
            let name = column.name
            let dbType = column.underlyingDatabaseType

            switch dbType {
            case .date, .timestamp, .timestampS, .timestampMS, .timestampNS:
                data[name] = column.cast(to: Foundation.Date.self).compactMap { $0 }
            case .double, .float:
                data[name] = column.cast(to: Double.self).compactMap { $0 }
            case .integer:
                data[name] = column.cast(to: Int32.self).compactMap { $0 }
            case .bigint:
                data[name] = column.cast(to: Int64.self).compactMap { $0 }
            case .boolean:
                data[name] = column.cast(to: Bool.self).compactMap { $0 }
            default:
                data[name] = column.cast(to: String.self).compactMap { $0 }
            }
        }
        
        return data
    }
    
    @MainActor
    func getResourceGroups() async -> [ResourceAttributeGroup] {
        guard let connection = connection else {
            logger.error("No database connection available")
            return []
        }
        
        do {
            // Get all key-value pairs without any ordering
            var groups: [ResourceAttributeGroup] = []
            
            // First get service.name entries
            let serviceQuery = """
                SELECT DISTINCT key, value
                FROM resource_attributes
                WHERE key = 'service.name';
            """
            
            let serviceResult = try connection.query(serviceQuery)
            for i in 0..<serviceResult.rowCount {
                guard let key = serviceResult[0].cast(to: String.self)[i],
                      let value = serviceResult[1].cast(to: String.self)[i] else {
                    continue
                }
                
                // Get resource IDs using a simpler query
                let resourceQuery = """
                    SELECT DISTINCT resource_id
                    FROM resource_attribute_mappings
                    WHERE attribute_id IN (
                        SELECT attribute_id
                        FROM resource_attributes
                        WHERE key = '\(key)' AND value = '\(value)'
                    );
                """
                
                let resourceResult = try connection.query(resourceQuery)
                let resourceIds = resourceResult[0].cast(to: String.self).compactMap { $0 }
                
                groups.append(ResourceAttributeGroup(
                    key: key,
                    value: value,
                    resourceIds: resourceIds
                ))
            }
            
            // Then get all other attributes
            let otherQuery = """
                SELECT DISTINCT key, value
                FROM resource_attributes
                WHERE key != 'service.name';
            """
            
            let otherResult = try connection.query(otherQuery)
            for i in 0..<otherResult.rowCount {
                guard let key = otherResult[0].cast(to: String.self)[i],
                      let value = otherResult[1].cast(to: String.self)[i] else {
                    continue
                }
                
                // Get resource IDs using a simpler query
                let resourceQuery = """
                    SELECT DISTINCT resource_id
                    FROM resource_attribute_mappings
                    WHERE attribute_id IN (
                        SELECT attribute_id
                        FROM resource_attributes
                        WHERE key = '\(key)' AND value = '\(value)'
                    );
                """
                
                let resourceResult = try connection.query(resourceQuery)
                let resourceIds = resourceResult[0].cast(to: String.self).compactMap { $0 }
                
                groups.append(ResourceAttributeGroup(
                    key: key,
                    value: value,
                    resourceIds: resourceIds
                ))
            }
            
            // Sort the groups in memory instead of in SQL
            return groups.sorted { g1, g2 in
                if g1.key == "service.name" && g2.key != "service.name" {
                    return true
                }
                if g1.key != "service.name" && g2.key == "service.name" {
                    return false
                }
                if g1.key == g2.key {
                    return g1.value < g2.value
                }
                return g1.key < g2.key
            }
        } catch {
            logger.error("Failed to get resource groups: \(error)")
            return []
        }
    }
    
    // Add methods to get resource IDs for a group
    @MainActor
    func getResourceIds(forGroup group: ResourceAttributeGroup) async -> [String] {
        guard let connection = connection else {
            logger.error("No database connection available")
            return []
        }
        
        do {
            let query = """
                SELECT DISTINCT resource_id
                FROM resource_attribute_mappings
                WHERE attribute_id IN (
                    SELECT attribute_id
                    FROM resource_attributes
                    WHERE key = '\(group.key)' AND value = '\(group.value)'
                );
            """
            
            let result = try connection.query(query)
            return result[0].cast(to: String.self).compactMap { $0 }
        } catch {
            logger.error("Failed to get resource IDs: \(error)")
            return []
        }
    }
    
    // Helper function to convert DuckDB.Date to Foundation.Date
    private func convertDate(_ duckDate: DuckDB.Date?) -> Foundation.Date? {
        guard let duckDate = duckDate else { return nil }
        // DuckDB.Date stores microseconds since Unix epoch
        return Foundation.Date(duckDate)
    }
    
    @MainActor
    func getMetrics(forResourceIds resourceIds: [String]) async -> [MetricRow] {
        guard let connection = connection else {
            logger.error("No database connection available")
            return []
        }
        
        do {
            let resourceList = resourceIds.map { "'\($0)'" }.joined(separator: ",")
            let query = """
                SELECT 
                    metric_name,
                    description,
                    unit,
                    type,
                    time,
                    value,
                    attributes,
                    resource_id
                FROM metric_points
                WHERE resource_id IN (\(resourceList));
            """
            
            let result = try connection.query(query)
            var metrics: [MetricRow] = []
            
            let rowCount = result.rowCount
            for i in 0..<rowCount {
                guard let name = result[0].cast(to: String.self)[i],
                      let description = result[1].cast(to: String.self)[i],
                      let unit = result[2].cast(to: String.self)[i],
                      let type = result[3].cast(to: String.self)[i],
                      let duckTime = result[4].cast(to: DuckDB.Date.self)[i],
                      let time = convertDate(duckTime),
                      let value = result[5].cast(to: Double.self)[i],
                      let attributes = result[6].cast(to: String.self)[i],
                      let resourceId = result[7].cast(to: String.self)[i] else {
                    continue
                }
                
                metrics.append(MetricRow(
                    name: name,
                    description_p: description,
                    unit: unit,
                    type: type,
                    time: time,
                    value: value,
                    attributes: attributes,
                    resourceId: resourceId
                ))
            }
            
            return metrics
        } catch {
            logger.error("Failed to get metrics: \(error)")
            return []
        }
    }
    
    @MainActor
    func getLogs(forResourceIds resourceIds: [String]) async -> [LogRow] {
        guard let connection = connection else {
            logger.error("No database connection available")
            return []
        }
        
        do {
            let resourceList = resourceIds.map { "'\($0)'" }.joined(separator: ",")
            let query = """
                SELECT 
                    timestamp,
                    severity_text,
                    severity_number,
                    body,
                    attributes,
                    resource_id
                FROM log_records
                WHERE resource_id IN (\(resourceList));
            """
            
            let result = try connection.query(query)
            var logs: [LogRow] = []
            
            let rowCount = result.rowCount
            for i in 0..<rowCount {
                guard let duckTimestamp = result[0].cast(to: DuckDB.Date.self)[i],
                      let timestamp = convertDate(duckTimestamp),
                      let severityText = result[1].cast(to: String.self)[i],
                      let severityNumber = result[2].cast(to: Int32.self)[i],
                      let body = result[3].cast(to: String.self)[i],
                      let attributes = result[4].cast(to: String.self)[i],
                      let resourceId = result[5].cast(to: String.self)[i] else {
                    continue
                }
                
                logs.append(LogRow(
                    timestamp: timestamp,
                    severityText: severityText,
                    severityNumber: severityNumber,
                    body: body,
                    attributes: attributes,
                    resourceId: resourceId
                ))
            }
            
            return logs
        } catch {
            logger.error("Failed to get logs: \(error)")
            return []
        }
    }
    
    @MainActor
    func getSpans(forResourceIds resourceIds: [String]) async -> [SpanRow] {
        guard let connection = connection else {
            logger.error("No database connection available")
            return []
        }
        
        do {
            let resourceList = resourceIds.map { "'\($0)'" }.joined(separator: ",")
            let query = """
                SELECT 
                    trace_id,
                    span_id,
                    parent_span_id,
                    name,
                    kind,
                    start_time,
                    end_time,
                    attributes,
                    resource_id
                FROM spans
                WHERE resource_id IN (\(resourceList));
            """
            
            let result = try connection.query(query)
            var spans: [SpanRow] = []
            
            let rowCount = result.rowCount
            for i in 0..<rowCount {
                guard let traceId = result[0].cast(to: String.self)[i],
                      let spanId = result[1].cast(to: String.self)[i],
                      let parentSpanId = result[2].cast(to: String.self)[i],
                      let name = result[3].cast(to: String.self)[i],
                      let kind = result[4].cast(to: Int32.self)[i],
                      let duckStartTime = result[5].cast(to: DuckDB.Date.self)[i],
                      let startTime = convertDate(duckStartTime),
                      let duckEndTime = result[6].cast(to: DuckDB.Date.self)[i],
                      let endTime = convertDate(duckEndTime),
                      let attributes = result[7].cast(to: String.self)[i],
                      let resourceId = result[8].cast(to: String.self)[i] else {
                    continue
                }
                
                spans.append(SpanRow(
                    traceId: traceId,
                    spanId: spanId,
                    parentSpanId: parentSpanId,
                    name: name,
                    kind: kind,
                    startTime: startTime,
                    endTime: endTime,
                    attributes: attributes,
                    resourceId: resourceId
                ))
            }
            
            return spans
        } catch {
            logger.error("Failed to get spans: \(error)")
            return []
        }
    }
}
