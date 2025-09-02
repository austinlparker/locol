import Foundation
import GRDB
import os

/// Manages SQLite databases for storing OTLP telemetry data
/// Each collector gets its own database for data isolation
class TelemetryDatabase {
    static let shared = TelemetryDatabase()
    
    private let logger = Logger.app
    private let fileManager = CollectorFileManager.shared
    
    /// Cache of open database queues by collector name
    private var databases: [String: DatabaseQueue] = [:]
    private let databaseQueue = DispatchQueue(label: "telemetry.database", qos: .utility)
    
    private init() {}
    
    /// Gets or creates a database for the specified collector
    func database(for collectorName: String) throws -> DatabaseQueue {
        return try databaseQueue.sync {
            if let existing = databases[collectorName] {
                return existing
            }
            
            // Create database file path
            let databaseURL = fileManager.baseDirectory
                .appendingPathComponent("collectors")
                .appendingPathComponent(collectorName)
                .appendingPathComponent("telemetry.db")
            
            // Ensure directory exists
            try FileManager.default.createDirectory(
                at: databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            // Create and configure database
            let dbQueue = try DatabaseQueue(path: databaseURL.path)
            
            // Run migrations
            try migrator.migrate(dbQueue)
            
            // Cache the database
            databases[collectorName] = dbQueue
            
            logger.info("Created telemetry database for collector: \(collectorName)")
            return dbQueue
        }
    }
    
    /// Closes and removes database for a collector
    func removeDatabase(for collectorName: String) {
        databaseQueue.sync {
            // Close database connection
            databases.removeValue(forKey: collectorName)
            
            // Remove database file
            let databaseURL = fileManager.baseDirectory
                .appendingPathComponent("collectors")
                .appendingPathComponent(collectorName)
                .appendingPathComponent("telemetry.db")
            
            try? FileManager.default.removeItem(at: databaseURL)
            logger.info("Removed telemetry database for collector: \(collectorName)")
        }
    }
    
    /// Closes all database connections (for app termination)
    func closeAllConnections() {
        databaseQueue.sync {
            databases.removeAll()
            logger.info("Closed all telemetry database connections")
        }
    }
    
    /// Clears all data from a collector's database (keeps schema)
    func clearData(for collectorName: String) throws {
        let db = try database(for: collectorName)
        try db.write { db in
            try db.execute(sql: "DELETE FROM spans")
            try db.execute(sql: "DELETE FROM metrics")
            try db.execute(sql: "DELETE FROM logs")
            try db.execute(sql: "DELETE FROM logs_fts")
        }
        logger.info("Cleared telemetry data for collector: \(collectorName)")
    }
    
    // MARK: - Data Retention Management
    
    /// Default data retention policies
    struct RetentionPolicy {
        let spanRetentionHours: Int
        let metricRetentionHours: Int
        let logRetentionHours: Int
        let maxDatabaseSizeMB: Int
        
        static let `default` = RetentionPolicy(
            spanRetentionHours: 72,      // 3 days
            metricRetentionHours: 168,   // 7 days
            logRetentionHours: 48,       // 2 days
            maxDatabaseSizeMB: 500       // 500 MB per collector
        )
    }
    
    /// Applies data retention policies to remove old data
    func applyRetentionPolicy(for collectorName: String, policy: RetentionPolicy = .default) throws {
        let db = try database(for: collectorName)
        let nowNanos = Int64(Date().timeIntervalSince1970 * 1_000_000_000)
        
        try db.write { db in
            // Clean old spans
            let spanCutoff = nowNanos - Int64(policy.spanRetentionHours * 3600) * 1_000_000_000
            try db.execute(sql: "DELETE FROM spans WHERE start_time < ?", arguments: [spanCutoff])
            let deletedSpans = db.changesCount
            
            // Clean old metrics
            let metricCutoff = nowNanos - Int64(policy.metricRetentionHours * 3600) * 1_000_000_000
            try db.execute(sql: "DELETE FROM metrics WHERE timestamp < ?", arguments: [metricCutoff])
            let deletedMetrics = db.changesCount
            
            // Clean old logs
            let logCutoff = nowNanos - Int64(policy.logRetentionHours * 3600) * 1_000_000_000
            try db.execute(sql: "DELETE FROM logs WHERE timestamp < ?", arguments: [logCutoff])
            let deletedLogs = db.changesCount
            
            // Vacuum to reclaim space
            try db.execute(sql: "VACUUM")
            
            if deletedSpans > 0 || deletedMetrics > 0 || deletedLogs > 0 {
                logger.info("Applied retention policy for \(collectorName): deleted \(deletedSpans) spans, \(deletedMetrics) metrics, \(deletedLogs) logs")
            }
        }
    }
    
    /// Gets database statistics for a collector
    func getDatabaseStats(for collectorName: String) throws -> DatabaseStats {
        let db = try database(for: collectorName)
        return try db.read { db in
            let spanCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM spans") ?? 0
            let metricCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM metrics") ?? 0
            let logCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM logs") ?? 0
            
            // Get database file size
            let databaseURL = fileManager.baseDirectory
                .appendingPathComponent("collectors")
                .appendingPathComponent(collectorName)
                .appendingPathComponent("telemetry.db")
            
            let fileSize = try? FileManager.default.attributesOfItem(atPath: databaseURL.path)[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSize ?? 0) / (1024 * 1024)
            
            // Get oldest and newest timestamps
            let oldestSpan = try Int64.fetchOne(db, sql: "SELECT MIN(start_time) FROM spans")
            let newestSpan = try Int64.fetchOne(db, sql: "SELECT MAX(start_time) FROM spans")
            let oldestMetric = try Int64.fetchOne(db, sql: "SELECT MIN(timestamp) FROM metrics")
            let newestMetric = try Int64.fetchOne(db, sql: "SELECT MAX(timestamp) FROM metrics")
            let oldestLog = try Int64.fetchOne(db, sql: "SELECT MIN(timestamp) FROM logs")
            let newestLog = try Int64.fetchOne(db, sql: "SELECT MAX(timestamp) FROM logs")
            
            let allOldestTimes = [oldestSpan, oldestMetric, oldestLog].compactMap { $0 }
            let allNewestTimes = [newestSpan, newestMetric, newestLog].compactMap { $0 }
            
            return DatabaseStats(
                collectorName: collectorName,
                spanCount: spanCount,
                metricCount: metricCount,
                logCount: logCount,
                fileSizeMB: fileSizeMB,
                oldestTimestamp: allOldestTimes.min(),
                newestTimestamp: allNewestTimes.max()
            )
        }
    }
    
    /// Performs maintenance on all collector databases
    func performMaintenance(policy: RetentionPolicy = .default) {
        databaseQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Get list of all collector database directories
            let collectorsDir = self.fileManager.baseDirectory.appendingPathComponent("collectors")
            guard let collectorNames = try? FileManager.default.contentsOfDirectory(atPath: collectorsDir.path) else {
                return
            }
            
            var totalCleaned = 0
            for collectorName in collectorNames {
                do {
                    let statsBefore = try self.getDatabaseStats(for: collectorName)
                    
                    // Apply retention policy if database is getting large
                    if statsBefore.fileSizeMB > Double(policy.maxDatabaseSizeMB) ||
                       statsBefore.totalRecords > 100_000 {
                        try self.applyRetentionPolicy(for: collectorName, policy: policy)
                        totalCleaned += 1
                    }
                } catch {
                    self.logger.error("Failed to perform maintenance on database for \(collectorName): \(error)")
                }
            }
            
            if totalCleaned > 0 {
                self.logger.info("Database maintenance completed. Cleaned \(totalCleaned) databases.")
            }
        }
    }
    
    /// Starts periodic maintenance (call this during app startup)
    func startPeriodicMaintenance(intervalHours: Int = 24) {
        Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalHours * 3600), repeats: true) { [weak self] _ in
            self?.performMaintenance()
        }
        logger.info("Started periodic database maintenance (every \(intervalHours) hours)")
    }
    
    /// Database migrator that creates and updates schema
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        // Initial schema - v1.0
        migrator.registerMigration("createInitialSchema") { db in
            // Spans table for trace data
            try db.execute(sql: """
                CREATE TABLE spans (
                    span_id TEXT PRIMARY KEY,
                    trace_id TEXT NOT NULL,
                    parent_span_id TEXT,
                    service_name TEXT,
                    operation_name TEXT,
                    start_time INTEGER,
                    end_time INTEGER,
                    duration INTEGER,
                    status_code INTEGER,
                    status_message TEXT,
                    attributes TEXT,
                    events TEXT,
                    links TEXT,
                    created_at INTEGER DEFAULT (strftime('%s', 'now'))
                )
            """)
            
            // Indexes for efficient span queries
            try db.execute(sql: "CREATE INDEX idx_spans_trace_id ON spans(trace_id)")
            try db.execute(sql: "CREATE INDEX idx_spans_parent ON spans(parent_span_id)")
            try db.execute(sql: "CREATE INDEX idx_spans_service ON spans(service_name)")
            try db.execute(sql: "CREATE INDEX idx_spans_time ON spans(start_time)")
            
            // Metrics table for time-series data
            try db.execute(sql: """
                CREATE TABLE metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    type TEXT NOT NULL,
                    timestamp INTEGER NOT NULL,
                    value REAL,
                    labels TEXT,
                    exemplars TEXT,
                    bucket_counts TEXT,
                    bucket_bounds TEXT,
                    sum REAL,
                    count INTEGER,
                    created_at INTEGER DEFAULT (strftime('%s', 'now'))
                )
            """)
            
            // Indexes for efficient metric queries
            try db.execute(sql: "CREATE INDEX idx_metrics_name_time ON metrics(name, timestamp)")
            try db.execute(sql: "CREATE INDEX idx_metrics_type ON metrics(type)")
            
            // Logs table for log data
            try db.execute(sql: """
                CREATE TABLE logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp INTEGER NOT NULL,
                    severity_number INTEGER,
                    severity_text TEXT,
                    body TEXT,
                    attributes TEXT,
                    resource TEXT,
                    trace_id TEXT,
                    span_id TEXT,
                    created_at INTEGER DEFAULT (strftime('%s', 'now'))
                )
            """)
            
            // Indexes for efficient log queries
            try db.execute(sql: "CREATE INDEX idx_logs_timestamp ON logs(timestamp)")
            try db.execute(sql: "CREATE INDEX idx_logs_severity ON logs(severity_number)")
            try db.execute(sql: "CREATE INDEX idx_logs_trace ON logs(trace_id)")
            
            // Full-text search for log bodies
            try db.execute(sql: """
                CREATE VIRTUAL TABLE logs_fts USING fts5(
                    body,
                    content='logs',
                    content_rowid='id'
                )
            """)
            
            // Triggers to keep FTS table in sync
            try db.execute(sql: """
                CREATE TRIGGER logs_fts_insert AFTER INSERT ON logs BEGIN
                    INSERT INTO logs_fts(rowid, body) VALUES (new.id, new.body);
                END
            """)
            
            try db.execute(sql: """
                CREATE TRIGGER logs_fts_delete AFTER DELETE ON logs BEGIN
                    INSERT INTO logs_fts(logs_fts, rowid, body) VALUES('delete', old.id, old.body);
                END
            """)
            
            try db.execute(sql: """
                CREATE TRIGGER logs_fts_update AFTER UPDATE ON logs BEGIN
                    INSERT INTO logs_fts(logs_fts, rowid, body) VALUES('delete', old.id, old.body);
                    INSERT INTO logs_fts(rowid, body) VALUES (new.id, new.body);
                END
            """)
        }
        
        return migrator
    }
}

// MARK: - Database Access Extensions

extension TelemetryDatabase {
    /// Performs a read operation on a collector's database
    func read<T>(for collectorName: String, _ operation: (Database) throws -> T) throws -> T {
        let db = try database(for: collectorName)
        return try db.read(operation)
    }
    
    /// Performs a write operation on a collector's database
    func write<T>(for collectorName: String, _ operation: (Database) throws -> T) throws -> T {
        let db = try database(for: collectorName)
        return try db.write(operation)
    }
    
    /// Performs an async read operation on a collector's database
    func asyncRead<T>(for collectorName: String, _ operation: @escaping @Sendable (Database) throws -> T) async throws -> T {
        let db = try database(for: collectorName)
        return try await db.read(operation)
    }
    
    /// Performs an async write operation on a collector's database
    func asyncWrite<T>(for collectorName: String, _ operation: @escaping @Sendable (Database) throws -> T) async throws -> T {
        let db = try database(for: collectorName)
        return try await db.write(operation)
    }
}

// MARK: - Database Statistics

struct DatabaseStats {
    let collectorName: String
    let spanCount: Int
    let metricCount: Int
    let logCount: Int
    let fileSizeMB: Double
    let oldestTimestamp: Int64?
    let newestTimestamp: Int64?
    
    var totalRecords: Int {
        spanCount + metricCount + logCount
    }
    
    var oldestDate: Date? {
        guard let oldestTimestamp = oldestTimestamp else { return nil }
        return Date(timeIntervalSince1970: Double(oldestTimestamp) / 1_000_000_000)
    }
    
    var newestDate: Date? {
        guard let newestTimestamp = newestTimestamp else { return nil }
        return Date(timeIntervalSince1970: Double(newestTimestamp) / 1_000_000_000)
    }
    
    var dataTimeSpan: TimeInterval? {
        guard let oldest = oldestTimestamp, let newest = newestTimestamp else { return nil }
        return Double(newest - oldest) / 1_000_000_000
    }
}