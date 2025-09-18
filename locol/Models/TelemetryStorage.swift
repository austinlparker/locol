import Foundation
import GRDB
import os

/// Actor responsible for all telemetry database operations
/// Uses a single SQLite database with proper isolation and performance
actor TelemetryStorage: TelemetryStorageProtocol {
    
    private let logger = Logger.database
    private let dbQueue: DatabaseQueue
    
    // Base directory for locol data
    private let baseDirectory: URL = {
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        return homeDir.appendingPathComponent(".locol")
    }()
    
    init() {
        do {
            // Ensure directory exists
            try FileManager.default.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true
            )
            
            // Create unified database
            let databaseURL = baseDirectory.appendingPathComponent("telemetry.db")
            self.dbQueue = try DatabaseQueue(path: databaseURL.path)
            
            // Run migrations
            try Self.migrator.migrate(dbQueue)
            
            logger.info("Initialized telemetry database at \(databaseURL.path)")
        } catch {
            logger.error("Failed to initialize telemetry database: \(error)")
            fatalError("Cannot initialize telemetry database: \(error)")
        }
    }
    
    // MARK: - Database Schema & Migrations
    
    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        // Migration 1: Create initial tables with comprehensive schemas
        migrator.registerMigration("v1_create_tables") { db in
            // Spans table for distributed tracing
            try db.create(table: "spans") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("collector_name", .text).notNull().indexed()
                t.column("trace_id", .text).notNull().indexed()
                t.column("span_id", .text).notNull()
                t.column("parent_span_id", .text)
                t.column("operation_name", .text).notNull()
                t.column("service_name", .text).indexed()
                t.column("start_time_nanos", .integer).notNull().indexed()
                t.column("end_time_nanos", .integer).notNull()
                t.column("duration_nanos", .integer).notNull()
                t.column("status_code", .integer)
                t.column("status_message", .text)
                t.column("kind", .integer)
                t.column("attributes", .text) // JSON
                t.column("events", .text) // JSON
                t.column("links", .text) // JSON
                t.column("resource_attributes", .text) // JSON
                t.column("scope_name", .text)
                t.column("scope_version", .text)
                t.column("scope_attributes", .text) // JSON
                t.column("created_at", .datetime).notNull().defaults(to: Date())
            }
            
            // Metrics table for time-series data
            try db.create(table: "metrics") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("collector_name", .text).notNull().indexed()
                t.column("metric_name", .text).notNull().indexed()
                t.column("description", .text)
                t.column("unit", .text)
                t.column("type", .text).notNull() // gauge, counter, histogram, etc.
                t.column("service_name", .text).indexed()
                t.column("timestamp_nanos", .integer).notNull().indexed()
                t.column("value", .double)
                t.column("attributes", .text) // JSON
                t.column("resource_attributes", .text) // JSON
                t.column("scope_name", .text)
                t.column("scope_version", .text)
                t.column("scope_attributes", .text) // JSON
                t.column("created_at", .datetime).notNull().defaults(to: Date())
            }
            
            // Logs table for structured logging
            try db.create(table: "logs") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("collector_name", .text).notNull().indexed()
                t.column("timestamp_nanos", .integer).notNull().indexed()
                t.column("severity_text", .text)
                t.column("severity_number", .integer).indexed()
                t.column("body", .text)
                t.column("service_name", .text).indexed()
                t.column("trace_id", .text).indexed()
                t.column("span_id", .text)
                t.column("attributes", .text) // JSON
                t.column("resource_attributes", .text) // JSON
                t.column("scope_name", .text)
                t.column("scope_version", .text)
                t.column("scope_attributes", .text) // JSON
                t.column("created_at", .datetime).notNull().defaults(to: Date())
            }
            
            // Performance indexes
            try db.create(index: "idx_spans_trace_time", on: "spans", columns: ["trace_id", "start_time_nanos"])
            try db.create(index: "idx_spans_service_time", on: "spans", columns: ["service_name", "start_time_nanos"])
            try db.create(index: "idx_metrics_name_time", on: "metrics", columns: ["metric_name", "timestamp_nanos"])
            try db.create(index: "idx_logs_severity_time", on: "logs", columns: ["severity_number", "timestamp_nanos"])
        }
        
        // Migration 2: Collectors and versioned configurations
        migrator.registerMigration("v2_collectors_and_configs") { db in
            // Collectors table
            try db.create(table: "collectors") { t in
                t.column("id", .text).primaryKey() // UUID string
                t.column("name", .text).notNull().unique()
                t.column("version", .text).notNull()
                t.column("binary_path", .text).notNull()
                t.column("command_line_flags", .text).notNull().defaults(to: "")
                t.column("is_running", .integer).notNull().defaults(to: 0)
                t.column("start_time_nanos", .integer)
                t.column("last_state_change_nanos", .integer)
                t.column("current_config_id", .text)
            }
            try db.create(index: "idx_collectors_name", on: "collectors", columns: ["name"], unique: true)
            try db.create(index: "idx_collectors_is_running", on: "collectors", columns: ["is_running"]) 

            // Config versions table
            try db.create(table: "config_versions") { t in
                t.column("id", .text).primaryKey() // UUID string
                t.column("collector_id", .text).notNull()
                t.column("rev", .integer).notNull()
                t.column("created_at", .datetime).notNull().defaults(to: Date())
                t.column("config_json", .blob).notNull()
                t.column("yaml", .text)
                t.column("is_valid", .integer).notNull().defaults(to: 1)
                t.column("autosave", .integer).notNull().defaults(to: 0)
            }
            try db.create(index: "idx_cfg_rev", on: "config_versions", columns: ["collector_id", "rev"], unique: true)
            try db.create(index: "idx_cfg_collector_id", on: "config_versions", columns: ["collector_id"]) 
        }
        
        return migrator
    }

    // Expose migrations so other stores using the same DB can stay in sync
    static func runMigrations(on dbQueue: DatabaseQueue) throws {
        try migrator.migrate(dbQueue)
    }
    
    // MARK: - Data Operations
    
    /// Store a batch of spans
    func storeSpans(_ spans: [StoredSpan]) async throws {
        guard !spans.isEmpty else { return }
        
        try await dbQueue.write { db in
            for span in spans {
                try span.insert(db)
            }
        }
        
        logger.debug("Stored \(spans.count) spans")
    }
    
    /// Store a batch of metrics
    func storeMetrics(_ metrics: [StoredMetric]) async throws {
        guard !metrics.isEmpty else { return }
        
        try await dbQueue.write { db in
            for metric in metrics {
                try metric.insert(db)
            }
        }
        
        logger.debug("Stored \(metrics.count) metrics")
    }
    
    /// Store a batch of logs
    func storeLogs(_ logs: [StoredLog]) async throws {
        guard !logs.isEmpty else { return }
        
        try await dbQueue.write { db in
            for log in logs {
                try log.insert(db)
            }
        }
        
        logger.debug("Stored \(logs.count) logs")
    }
    
    // MARK: - Query Operations
    
    /// Execute a read-only SQL query
    func executeQuery(_ sql: String) async throws -> QueryResult {
        try await dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: sql)
            
            guard let firstRow = rows.first else {
                return QueryResult(columns: [], rows: [])
            }
            
            let columns = Array(firstRow.columnNames)
            let rowData = rows.map { row in
                columns.map { columnName in
                    if let value = row[columnName] {
                        return "\(value)"
                    } else {
                        return ""
                    }
                }
            }
            
            return QueryResult(columns: columns, rows: rowData)
        }
    }
    
    /// Get database statistics for all collectors
    func getDatabaseStats() async throws -> [CollectorStats] {
        try await dbQueue.read { db in
            var stats: [CollectorStats] = []
            
            // Get all collectors that have data
            let collectors = try String.fetchAll(db, sql: """
                SELECT DISTINCT collector_name FROM (
                    SELECT collector_name FROM spans
                    UNION
                    SELECT collector_name FROM metrics
                    UNION
                    SELECT collector_name FROM logs
                )
                ORDER BY collector_name
                """)
            
            for collector in collectors {
                let spanCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM spans WHERE collector_name = ?", arguments: [collector]) ?? 0
                let metricCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM metrics WHERE collector_name = ?", arguments: [collector]) ?? 0
                let logCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM logs WHERE collector_name = ?", arguments: [collector]) ?? 0
                
                stats.append(CollectorStats(
                    collectorName: collector,
                    spanCount: spanCount,
                    metricCount: metricCount,
                    logCount: logCount
                ))
            }
            
            return stats
        }
    }
    
    func fetchRecentTraces(limit: Int, collector: String?) async throws -> [TraceSummary] {
        try await dbQueue.read { db in
            let trimmedLimit = max(1, min(limit, 500))
            let whereClause: String
            var arguments: [DatabaseValueConvertible] = []
            if let collector {
                whereClause = "WHERE collector_name = ?"
                arguments.append(collector)
            } else {
                whereClause = ""
            }
            arguments.append(trimmedLimit)
            let sql = """
            WITH filtered AS (
                SELECT * FROM spans
                \(whereClause)
            ),
            trace_bounds AS (
                SELECT
                    trace_id,
                    MIN(start_time_nanos) AS start_time_nanos,
                    MAX(end_time_nanos) AS end_time_nanos,
                    COUNT(*) AS span_count,
                    SUM(CASE WHEN status_code = \(SpanStatusCode.error.rawValue) THEN 1 ELSE 0 END) AS error_count
                FROM filtered
                GROUP BY trace_id
            ),
            root_spans AS (
                SELECT trace_id, operation_name, service_name
                FROM filtered
                WHERE parent_span_id IS NULL
            )
            SELECT
                t.trace_id,
                COALESCE(r.operation_name, 'Trace') AS root_operation,
                r.service_name,
                t.start_time_nanos,
                t.end_time_nanos,
                t.span_count,
                t.error_count
            FROM trace_bounds t
            LEFT JOIN root_spans r ON t.trace_id = r.trace_id
            ORDER BY t.start_time_nanos DESC
            LIMIT ?
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return rows.map { row in
                let traceId: String = row["trace_id"]
                let operation: String = row["root_operation"] ?? "Trace"
                let serviceName: String? = row["service_name"]
                let startNanos: Int64 = row["start_time_nanos"] ?? 0
                let endNanos: Int64 = row["end_time_nanos"] ?? startNanos
                let spanCount: Int = row["span_count"] ?? 0
                let errorCount: Int = row["error_count"] ?? 0
                let start = Date(timeIntervalSince1970: TimeInterval(startNanos) / 1_000_000_000)
                let end = Date(timeIntervalSince1970: TimeInterval(endNanos) / 1_000_000_000)
                let duration = max(0, end.timeIntervalSince(start))
                return TraceSummary(
                    traceId: traceId,
                    serviceName: serviceName,
                    rootOperation: operation,
                    startTime: start,
                    endTime: end,
                    duration: duration,
                    spanCount: spanCount,
                    errorCount: errorCount
                )
            }
        }
    }
    
    func fetchTraceSpans(traceId: String) async throws -> [TraceSpanDetail] {
        try await dbQueue.read { db in
            let sql = """
            SELECT
                span_id,
                parent_span_id,
                operation_name,
                service_name,
                start_time_nanos,
                end_time_nanos,
                status_code,
                status_message,
                attributes,
                events
            FROM spans
            WHERE trace_id = ?
            ORDER BY start_time_nanos ASC
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: [traceId])
            return rows.map { row in
                let spanId: String = row["span_id"]
                let parentSpanId: String? = row["parent_span_id"]
                let operationName: String = row["operation_name"] ?? "span"
                let serviceName: String? = row["service_name"]
                let startNanos: Int64 = row["start_time_nanos"] ?? 0
                let endNanos: Int64 = row["end_time_nanos"] ?? startNanos
                let statusCode: Int? = row["status_code"]
                let statusMessage: String? = row["status_message"]
                let attributesJSON: String = row["attributes"] ?? "{}"
                let eventsJSON: String = row["events"] ?? "[]"
                let start = Date(timeIntervalSince1970: TimeInterval(startNanos) / 1_000_000_000)
                let end = Date(timeIntervalSince1970: TimeInterval(endNanos) / 1_000_000_000)
                let duration = max(0, end.timeIntervalSince(start))
                let attributes = Self.decodeAttributes(from: attributesJSON)
                let events = Self.decodeEvents(from: eventsJSON)
                return TraceSpanDetail(
                    spanId: spanId,
                    parentSpanId: parentSpanId?.isEmpty == true ? nil : parentSpanId,
                    operationName: operationName,
                    serviceName: serviceName?.isEmpty == true ? nil : serviceName,
                    startTime: start,
                    endTime: end,
                    duration: duration,
                    statusCode: statusCode,
                    statusMessage: statusMessage,
                    attributes: attributes,
                    events: events
                )
            }
        }
    }
    
    func fetchMetricCatalog(collector: String?) async throws -> [MetricDescriptor] {
        try await dbQueue.read { db in
            let whereClause: String
            var arguments: [DatabaseValueConvertible] = []
            if let collector {
                whereClause = "WHERE collector_name = ?"
                arguments.append(collector)
            } else {
                whereClause = ""
            }
            let sql = """
            SELECT
                metric_name,
                type,
                unit,
                COUNT(*) AS sample_count,
                COUNT(DISTINCT service_name) AS service_count,
                MAX(timestamp_nanos) AS latest_timestamp
            FROM metrics
            \(whereClause)
            GROUP BY metric_name, type, unit
            ORDER BY latest_timestamp DESC
            LIMIT 200
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return rows.map { row in
                let metricName: String = row["metric_name"]
                let type: String = row["type"] ?? "gauge"
                let unit: String? = row["unit"]
                let sampleCount: Int = row["sample_count"] ?? 0
                let serviceCount: Int = row["service_count"] ?? 0
                let latestNanos: Int64? = row["latest_timestamp"]
                let latestDate = latestNanos.map { Date(timeIntervalSince1970: TimeInterval($0) / 1_000_000_000) }
                return MetricDescriptor(
                    metricName: metricName,
                    type: type,
                    unit: unit?.isEmpty == true ? nil : unit,
                    sampleCount: sampleCount,
                    serviceCount: serviceCount,
                    latestTimestamp: latestDate
                )
            }
        }
    }
    
    func fetchMetricSeries(
        metricName: String,
        collector: String?,
        start: Date,
        end: Date,
        bucketSeconds: Int
    ) async throws -> [MetricDataPoint] {
        try await dbQueue.read { db in
            let startNanos = Int64(start.timeIntervalSince1970 * 1_000_000_000)
            let endNanos = Int64(end.timeIntervalSince1970 * 1_000_000_000)
            let effectiveBucketSeconds = max(1, bucketSeconds)
            let bucketNanos = Int64(effectiveBucketSeconds) * 1_000_000_000
            let collectorClause: String
            var arguments: [DatabaseValueConvertible] = [metricName, startNanos, endNanos]
            if let collector {
                collectorClause = "AND collector_name = ?"
                arguments.append(collector)
            } else {
                collectorClause = ""
            }
            let sql = """
            SELECT
                COALESCE(service_name, '') AS service_name,
                (timestamp_nanos / \(bucketNanos)) * \(bucketNanos) AS bucket_start_nanos,
                AVG(value) AS avg_value,
                COUNT(*) AS sample_count
            FROM metrics
            WHERE metric_name = ?
              AND timestamp_nanos BETWEEN ? AND ?
              \(collectorClause)
              AND value IS NOT NULL
            GROUP BY service_name, bucket_start_nanos
            ORDER BY bucket_start_nanos ASC
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return rows.compactMap { row in
                guard let avgValue: Double = row["avg_value"] else { return nil }
                let serviceNameRaw: String = row["service_name"] ?? ""
                let timestampNanos: Int64 = row["bucket_start_nanos"] ?? startNanos
                let sampleCount: Int = row["sample_count"] ?? 0
                let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampNanos) / 1_000_000_000)
                return MetricDataPoint(
                    metricName: metricName,
                    serviceName: serviceNameRaw.isEmpty ? nil : serviceNameRaw,
                    timestamp: timestamp,
                    value: avgValue,
                    sampleCount: sampleCount
                )
            }
        }
    }

    func fetchRecentLogs(
        limit: Int,
        collector: String?,
        minimumSeverity: Int?
    ) async throws -> [LogEntry] {
        try await dbQueue.read { db in
            let trimmedLimit = max(1, min(limit, 500))
            var conditions: [String] = []
            var arguments: [DatabaseValueConvertible] = []

            if let collector {
                conditions.append("collector_name = ?")
                arguments.append(collector)
            }

            if let minimumSeverity {
                conditions.append("severity_number >= ?")
                arguments.append(minimumSeverity)
            }

            let whereClause: String
            if conditions.isEmpty {
                whereClause = ""
            } else {
                whereClause = "WHERE " + conditions.joined(separator: " AND ")
            }

            arguments.append(trimmedLimit)

            let sql = """
            SELECT
                timestamp_nanos,
                severity_text,
                severity_number,
                service_name,
                body,
                trace_id,
                span_id,
                attributes
            FROM logs
            \(whereClause)
            ORDER BY timestamp_nanos DESC
            LIMIT ?
            """

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return rows.map { row in
                let timestampNanos: Int64 = row["timestamp_nanos"] ?? 0
                let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampNanos) / 1_000_000_000)
                let severityText: String? = row["severity_text"]
                let severityNumber: Int? = row["severity_number"]
                let serviceName: String? = row["service_name"]
                let body: String? = row["body"]
                let traceId: String? = row["trace_id"]
                let spanId: String? = row["span_id"]
                let attributesJSON: String = row["attributes"] ?? "{}"
                let attributes = Self.decodeAttributes(from: attributesJSON)

                return LogEntry(
                    timestamp: timestamp,
                    severityText: severityText,
                    severityNumber: severityNumber,
                    serviceName: serviceName,
                    body: body,
                    traceId: traceId,
                    spanId: spanId,
                    attributes: attributes
                )
            }
        }
    }

    private static func decodeAttributes(from json: String) -> [String: String] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
        else { return [:] }

        guard let dictionary = object as? [String: Any] else {
            return [:]
        }

        var result: [String: String] = [:]
        for (key, value) in dictionary {
            result[key] = stringifyJSONValue(value)
        }
        return result
    }

    private static func decodeEvents(from json: String) -> [TraceSpanEvent] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
        else { return [] }

        guard let array = object as? [[String: Any]] else {
            return []
        }

        return array.compactMap { rawEvent in
            let name = (rawEvent["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "event"

            let timeValue = rawEvent["time_unix_nano"]
            let nanos: Int64
            if let number = timeValue as? NSNumber {
                nanos = number.int64Value
            } else if let string = timeValue as? String, let parsed = Int64(string) {
                nanos = parsed
            } else {
                nanos = 0
            }
            let timestamp = Date(timeIntervalSince1970: TimeInterval(nanos) / 1_000_000_000)

            let attributesDict = rawEvent["attributes"] as? [String: Any] ?? [:]
            var attributes: [String: String] = [:]
            for (key, value) in attributesDict {
                attributes[key] = stringifyJSONValue(value)
            }

            let droppedCount: Int
            if let number = rawEvent["dropped_attributes_count"] as? NSNumber {
                droppedCount = number.intValue
            } else if let string = rawEvent["dropped_attributes_count"] as? String,
                      let value = Int(string) {
                droppedCount = value
            } else {
                droppedCount = 0
            }

            return TraceSpanEvent(
                name: name,
                timestamp: timestamp,
                attributes: attributes,
                droppedAttributesCount: droppedCount
            )
        }
    }

    private static func stringifyJSONValue(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return NumberFormatter.localizedString(from: number, number: .decimal)
        }
        if let array = value as? [Any] {
            return "[" + array.map { stringifyJSONValue($0) }.joined(separator: ", ") + "]"
        }
        if let dict = value as? [String: Any] {
            let pairs = dict
                .map { "\($0.key): \(stringifyJSONValue($0.value))" }
                .sorted()
                .joined(separator: ", ")
            return "{" + pairs + "}"
        }
        return String(describing: value)
    }
    
    /// Clear all data for a specific collector
    func clearData(for collectorName: String) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM spans WHERE collector_name = ?", arguments: [collectorName])
            try db.execute(sql: "DELETE FROM metrics WHERE collector_name = ?", arguments: [collectorName])
            try db.execute(sql: "DELETE FROM logs WHERE collector_name = ?", arguments: [collectorName])
        }
        
        logger.info("Cleared all data for collector: \(collectorName)")
    }
    
    // MARK: - Data Retention
    
    /// Apply data retention policies
    func applyRetentionPolicy(
        spanRetentionHours: Int = 72,
        metricRetentionHours: Int = 168,
        logRetentionHours: Int = 48
    ) async throws {
        let now = Date()
        
        try await dbQueue.write { db in
            // Clean old spans
            let spanCutoff = now.addingTimeInterval(-Double(spanRetentionHours * 3600))
            let spanCutoffNanos = Int64(spanCutoff.timeIntervalSince1970 * 1_000_000_000)
            try db.execute(sql: "DELETE FROM spans WHERE start_time_nanos < ?", arguments: [spanCutoffNanos])
            
            // Clean old metrics
            let metricCutoff = now.addingTimeInterval(-Double(metricRetentionHours * 3600))
            let metricCutoffNanos = Int64(metricCutoff.timeIntervalSince1970 * 1_000_000_000)
            try db.execute(sql: "DELETE FROM metrics WHERE timestamp_nanos < ?", arguments: [metricCutoffNanos])
            
            // Clean old logs
            let logCutoff = now.addingTimeInterval(-Double(logRetentionHours * 3600))
            let logCutoffNanos = Int64(logCutoff.timeIntervalSince1970 * 1_000_000_000)
            try db.execute(sql: "DELETE FROM logs WHERE timestamp_nanos < ?", arguments: [logCutoffNanos])
            
            // Vacuum to reclaim space
            try db.execute(sql: "VACUUM")
        }
        
        logger.info("Applied data retention policy")
    }
}

// MARK: - Supporting Types

struct QueryResult: Sendable {
    let columns: [String]
    let rows: [[String]]
}

struct CollectorStats: Sendable {
    let collectorName: String
    let spanCount: Int
    let metricCount: Int
    let logCount: Int
    
    var totalItems: Int {
        spanCount + metricCount + logCount
    }
}

struct TraceSummary: Identifiable, Sendable {
    var id: String { traceId }
    let traceId: String
    let serviceName: String?
    let rootOperation: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let spanCount: Int
    let errorCount: Int

    var durationMilliseconds: Double {
        duration * 1000
    }

    var hasErrors: Bool {
        errorCount > 0
    }
}

struct TraceSpanDetail: Identifiable, Sendable {
    var id: String { spanId }
    let spanId: String
    let parentSpanId: String?
    let operationName: String
    let serviceName: String?
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let statusCode: Int?
    let statusMessage: String?
    let attributes: [String: String]
    let events: [TraceSpanEvent]

    var durationMilliseconds: Double {
        duration * 1000
    }

    var isError: Bool {
        statusCode == SpanStatusCode.error.rawValue
    }
}

struct TraceSpanEvent: Identifiable, Sendable, Equatable {
    var id: String { "\(name)-\(timestamp.timeIntervalSince1970)" }
    let name: String
    let timestamp: Date
    let attributes: [String: String]
    let droppedAttributesCount: Int

    var formattedTimestamp: String {
        timestamp.formatted(date: .omitted, time: .standard)
    }
}

struct MetricDescriptor: Identifiable, Sendable, Hashable {
    var id: String { metricName + (unit ?? "") + type }
    let metricName: String
    let type: String
    let unit: String?
    let sampleCount: Int
    let serviceCount: Int
    let latestTimestamp: Date?
}

struct MetricDataPoint: Identifiable, Sendable {
    var id: String { "\(serviceKey)-\(timestamp.timeIntervalSince1970)" }
    let metricName: String
    let serviceName: String?
    let timestamp: Date
    let value: Double
    let sampleCount: Int

    private var serviceKey: String {
        serviceName ?? "(unknown)"
    }
}

struct LogEntry: Identifiable, Sendable, Equatable {
    let id = UUID()
    let timestamp: Date
    let severityText: String?
    let severityNumber: Int?
    let serviceName: String?
    let body: String?
    let traceId: String?
    let spanId: String?
    let attributes: [String: String]

    var formattedTimestamp: String {
        timestamp.formatted(date: .omitted, time: .standard)
    }

    var severityDisplay: String {
        if let severityText, !severityText.isEmpty {
            return severityText.uppercased()
        }
        if let severityNumber {
            return "Severity \(severityNumber)"
        }
        return "unknown"
    }
}
