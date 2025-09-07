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
        
        return migrator
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
