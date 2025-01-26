import Foundation
import DuckDB
import os
import Network

@Observable
final class DataExplorer {
    static let shared = DataExplorer()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DataExplorer")
    private var server: OTLPServer?
    private var database: Database?
    private var connection: Connection?
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
    
    // Table data
    var metrics: [MetricRow] = []
    var logs: [LogRow] = []
    var spans: [SpanRow] = []
    
    struct MetricRow: Identifiable {
        let id = UUID()
        let name: String
        let description_p: String
        let unit: String
        let type: String
        let time: Foundation.Date
        let value: Double
        let attributes: String
    }
    
    struct LogRow: Identifiable {
        let id = UUID()
        let timestamp: Foundation.Date
        let severityText: String
        let severityNumber: Int32
        let body: String
        let attributes: String
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
        // Create a listener on port 0 to let the kernel assign us a port
        guard let listener = try? NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: 0)!) else {
            return nil
        }
        
        // Set up a connection handler to avoid the "Started without setting handler" warning
        listener.newConnectionHandler = { connection in
            // Just cancel any incoming connections since we only want the port
            connection.cancel()
        }
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            listener.stateUpdateHandler = { state in
                // Only proceed if we haven't resumed yet
                guard !hasResumed else { return }
                
                switch state {
                case .ready:
                    if let port = listener.port?.rawValue {
                        hasResumed = true
                        listener.cancel()
                        continuation.resume(returning: port)
                    }
                case .failed, .cancelled:
                    hasResumed = true
                    listener.cancel()
                    continuation.resume(returning: nil)
                case .setup, .waiting:
                    // These are intermediate states, don't resume yet
                    break
                @unknown default:
                    hasResumed = true
                    listener.cancel()
                    continuation.resume(returning: nil)
                }
            }
            
            listener.start(queue: .main)
        }
    }
    
    private func setupDatabase() async {
        do {
            database = try Database(store: .inMemory)
            connection = try database?.connect()
            
            // Create tables for traces, metrics, and logs
            try connection?.execute("""
                CREATE TABLE IF NOT EXISTS spans (
                    trace_id VARCHAR,
                    span_id VARCHAR,
                    parent_span_id VARCHAR,
                    name VARCHAR,
                    kind INTEGER,
                    start_time TIMESTAMP,
                    end_time TIMESTAMP,
                    attributes JSON
                );
                
                CREATE TABLE IF NOT EXISTS metrics (
                    name VARCHAR,
                    description VARCHAR,
                    unit VARCHAR,
                    type VARCHAR,
                    time TIMESTAMP,
                    value DOUBLE,
                    attributes JSON
                );
                
                CREATE TABLE IF NOT EXISTS logs (
                    timestamp TIMESTAMP,
                    severity_text VARCHAR,
                    severity_number INTEGER,
                    body VARCHAR,
                    attributes JSON
                );
            """)
            
            // Create appenders
            if let conn = connection {
                spansAppender = try Appender(connection: conn, table: "spans")
                metricsAppender = try Appender(connection: conn, table: "metrics")
                logsAppender = try Appender(connection: conn, table: "logs")
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
                        for scopeSpans in resourceSpans.scopeSpans {
                            for span in scopeSpans.spans {
                                handleSpan(span)
                            }
                        }
                    }
                case .metrics(let metricsRequest):
                    for resourceMetrics in metricsRequest.resourceMetrics {
                        for scopeMetrics in resourceMetrics.scopeMetrics {
                            for metric in scopeMetrics.metrics {
                                handleMetric(metric)
                            }
                        }
                    }
                case .logs(let logsRequest):
                    self.logger.info("Processing logs request with \(logsRequest.resourceLogs.count) resource logs")
                    for resourceLogs in logsRequest.resourceLogs {
                        for scopeLogs in resourceLogs.scopeLogs {
                            self.logger.info("Processing scope logs with \(scopeLogs.logRecords.count) records")
                            for log in scopeLogs.logRecords {
                                handleLog(log)
                            }
                        }
                    }
                case .profiles(let profilesRequest):
                    self.logger.debug("Received profiles request")
                    // TODO: Implement profile handling if needed
                }
            }
        } catch {
            self.logger.error("Server error: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
                self.isRunning = false
                self.logger.info("Server error occurred, isRunning set to false")
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
    
    private func handleSpan(_ span: Opentelemetry_Proto_Trace_V1_Span) {
        do {
            let attributes = attributesToJSON(span.attributes)
            let startTime = Foundation.Date(timeIntervalSince1970: TimeInterval(span.startTimeUnixNano) / 1_000_000_000)
            let endTime = Foundation.Date(timeIntervalSince1970: TimeInterval(span.endTimeUnixNano) / 1_000_000_000)
            
            try spansAppender?.append(span.traceID.hexString)
            try spansAppender?.append(span.spanID.hexString)
            try spansAppender?.append(span.parentSpanID.hexString)
            try spansAppender?.append(span.name)
            try spansAppender?.append(Int32(span.kind.rawValue))
            try spansAppender?.append(Timestamp(startTime))
            try spansAppender?.append(Timestamp(endTime))
            try spansAppender?.append(attributes)
            try spansAppender?.endRow()
            
            refreshSpans()
        } catch {
            logger.error("Failed to insert span: \(error.localizedDescription)")
        }
    }
    
    private func handleMetric(_ metric: Opentelemetry_Proto_Metrics_V1_Metric) {
        do {
            let (value, timestamp) = extractMetricValue(metric)
            let attributes = [String: String]() // TODO: Extract attributes based on metric type
            
            try metricsAppender?.append(metric.name)
            try metricsAppender?.append(metric.description_p)
            try metricsAppender?.append(metric.unit)
            try metricsAppender?.append(String(describing: metric.data))
            try metricsAppender?.append(Timestamp(timestamp))
            try metricsAppender?.append(value)
            try metricsAppender?.append(attributesToJSON(attributes))
            try metricsAppender?.endRow()
            
            refreshMetrics()
        } catch {
            logger.error("Failed to insert metric: \(error.localizedDescription)")
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
    
    private func handleLog(_ log: Opentelemetry_Proto_Logs_V1_LogRecord) {
        do {
            self.logger.info("Processing log record")
            let attributes = attributesToJSON(log.attributes)
            let timestamp = Foundation.Date(timeIntervalSince1970: TimeInterval(log.timeUnixNano) / 1_000_000_000)
            
            // Log each field separately
            self.logger.info("Log timestamp: \(timestamp)")
            self.logger.info("Log severity: \(log.severityText)")
            self.logger.info("Log body length: \(log.body.stringValue.count)")
            
            try logsAppender?.append(Timestamp(timestamp))
            try logsAppender?.append(log.severityText)
            try logsAppender?.append(Int32(log.severityNumber.rawValue))
            try logsAppender?.append(log.body.stringValue)
            try logsAppender?.append(attributes)
            try logsAppender?.endRow()
            
            self.logger.info("Log record appended to database")
            refreshLogs()
            self.logger.info("Logs refreshed")
        } catch {
            self.logger.error("Failed to insert log: \(error.localizedDescription)")
        }
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
    
    // Add methods to refresh table data
    private func refreshMetrics() {
        guard let connection = connection else { return }
        do {
            let result = try connection.query("SELECT * FROM metrics ORDER BY time DESC")
            let names = result[0].cast(to: String.self)
            let descriptions = result[1].cast(to: String.self)
            let units = result[2].cast(to: String.self)
            let types = result[3].cast(to: String.self)
            let times = result[4].cast(to: Int64.self)
            let values = result[5].cast(to: Double.self)
            let attrs = result[6].cast(to: String.self)
            
            metrics = zip(names, zip(descriptions, zip(units, zip(types, zip(times, zip(values, attrs)))))).map { name, rest1 in
                let (description, rest2) = rest1
                let (unit, rest3) = rest2
                let (type, rest4) = rest3
                let (time, rest5) = rest4
                let (value, attributes) = rest5
                
                return MetricRow(
                    name: name ?? "",
                    description_p: description ?? "",
                    unit: unit ?? "",
                    type: type ?? "",
                    time: Foundation.Date(timeIntervalSince1970: TimeInterval(time ?? 0)),
                    value: value ?? 0.0,
                    attributes: attributes ?? "{}"
                )
            }
        } catch {
            logger.error("Failed to refresh metrics: \(error.localizedDescription)")
        }
    }
    
    private func refreshLogs() {
        guard let connection = connection else {
            self.logger.error("No database connection available")
            return
        }
        
        do {
            // First check if we have any records
            let countResult = try connection.query("SELECT COUNT(*) FROM logs")
            if let count = countResult[0].cast(to: Int64.self).first {
                self.logger.info("Found \(String(describing: count), privacy: .public) records in logs table")
            }
            
            // Get all records
            let result = try connection.query("SELECT * FROM logs ORDER BY timestamp DESC")
            self.logger.info("Query returned \(String(describing: result.count), privacy: .public) columns")
            
            // Check if we have any data
            if result.isEmpty {
                self.logger.error("Query returned no columns")
                return
            }
            
            // Get the data from each column
            let timestamps = result[0].cast(to: Int64.self)
            let severityTexts = result[1].cast(to: String.self)
            let severityNumbers = result[2].cast(to: Int32.self)
            let bodies = result[3].cast(to: String.self)
            let attrs = result[4].cast(to: String.self)
            
            self.logger.info("Column counts - timestamps: \(String(describing: timestamps.count), privacy: .public) severityTexts: \(String(describing: severityTexts.count), privacy: .public) bodies: \(String(describing: bodies.count), privacy: .public)")
            
            let newLogs = zip(timestamps, zip(severityTexts, zip(severityNumbers, zip(bodies, attrs)))).map { timestamp, rest1 in
                let (severityText, rest2) = rest1
                let (severityNumber, rest3) = rest2
                let (body, attributes) = rest3
                
                return LogRow(
                    timestamp: Foundation.Date(timeIntervalSince1970: TimeInterval(timestamp ?? 0)),
                    severityText: severityText ?? "",
                    severityNumber: severityNumber ?? 0,
                    body: body ?? "",
                    attributes: attributes ?? "{}"
                )
            }
            
            Task { @MainActor in
                self.logs = newLogs
                self.logger.info("Updated logs array with \(String(describing: newLogs.count), privacy: .public) records")
            }
        } catch {
            self.logger.error("Failed to refresh logs: \(error.localizedDescription)")
        }
    }
    
    private func refreshSpans() {
        guard let connection = connection else { return }
        do {
            let result = try connection.query("SELECT * FROM spans ORDER BY start_time DESC")
            let traceIds = result[0].cast(to: String.self)
            let spanIds = result[1].cast(to: String.self)
            let parentSpanIds = result[2].cast(to: String.self)
            let names = result[3].cast(to: String.self)
            let kinds = result[4].cast(to: Int32.self)
            let startTimes = result[5].cast(to: Int64.self)
            let endTimes = result[6].cast(to: Int64.self)
            let attrs = result[7].cast(to: String.self)
            
            spans = zip(traceIds, zip(spanIds, zip(parentSpanIds, zip(names, zip(kinds, zip(startTimes, zip(endTimes, attrs))))))).map { traceId, rest1 in
                let (spanId, rest2) = rest1
                let (parentSpanId, rest3) = rest2
                let (name, rest4) = rest3
                let (kind, rest5) = rest4
                let (startTime, rest6) = rest5
                let (endTime, attributes) = rest6
                
                return SpanRow(
                    traceId: traceId ?? "",
                    spanId: spanId ?? "",
                    parentSpanId: parentSpanId ?? "",
                    name: name ?? "",
                    kind: kind ?? 0,
                    startTime: Foundation.Date(timeIntervalSince1970: TimeInterval(startTime ?? 0)),
                    endTime: Foundation.Date(timeIntervalSince1970: TimeInterval(endTime ?? 0)),
                    attributes: attributes ?? "{}"
                )
            }
        } catch {
            logger.error("Failed to refresh spans: \(error.localizedDescription)")
        }
    }
}
