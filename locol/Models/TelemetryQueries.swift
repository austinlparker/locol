import Foundation
import GRDB
import Combine
import os

// MARK: - Trace Queries

/// Request for fetching spans grouped by trace
struct TraceRequest {
    var collectorName: String
    var traceId: String?
    var serviceName: String?
    var timeRange: TelemetryDataTimeRange?
    var limit: Int = 100
    
    /// Creates a publisher for SwiftUI integration
    func publisher(in dbQueue: DatabaseQueue) -> AnyPublisher<[TelemetrySpan], Error> {
        ValueObservation.tracking { db -> [TelemetrySpan] in
            var request = TelemetrySpan.all()
            
            // Filter by trace ID if specified
            if let traceId = self.traceId {
                request = request.filter(TelemetrySpan.Columns.traceId == traceId)
            }
            
            // Filter by service name if specified
            if let serviceName = self.serviceName {
                request = request.filter(TelemetrySpan.Columns.serviceName == serviceName)
            }
            
            // Filter by time range if specified
            if let timeRange = self.timeRange {
                request = request.filter(
                    TelemetrySpan.Columns.startTime >= timeRange.startTime &&
                    TelemetrySpan.Columns.startTime <= timeRange.endTime
                )
            }
            
            // Order by start time (most recent first)
            request = request
                .order(TelemetrySpan.Columns.startTime.desc)
                .limit(self.limit)
            
            return try request.fetchAll(db)
        }
        .publisher(in: dbQueue, scheduling: .immediate)
        .eraseToAnyPublisher()
    }
}

/// Request for fetching a complete trace hierarchy
struct TraceHierarchyRequest {
    var collectorName: String
    var traceId: String
    
    /// Creates a publisher for SwiftUI integration
    func publisher(in dbQueue: DatabaseQueue) -> AnyPublisher<TraceHierarchy, Error> {
        ValueObservation.tracking { db -> TraceHierarchy in
            let spans = try TelemetrySpan
                .filter(TelemetrySpan.Columns.traceId == self.traceId)
                .order(TelemetrySpan.Columns.startTime)
                .fetchAll(db)
            
            return TraceHierarchy(spans: spans)
        }
        .publisher(in: dbQueue, scheduling: .immediate)
        .eraseToAnyPublisher()
    }
}

// MARK: - Metrics Queries

/// Request for fetching metrics time series data
struct MetricsTimeSeriesRequest {
    var collectorName: String
    var metricName: String?
    var labels: [String: String] = [:]
    var timeRange: TelemetryDataTimeRange?
    var limit: Int = 1000
    
    /// Creates a publisher for SwiftUI integration
    func publisher(in dbQueue: DatabaseQueue) -> AnyPublisher<[TelemetryMetric], Error> {
        ValueObservation.tracking { db -> [TelemetryMetric] in
            var request = TelemetryMetric.all()
            
            // Filter by metric name if specified
            if let metricName = self.metricName {
                request = request.filter(TelemetryMetric.Columns.name == metricName)
            }
            
            // Filter by time range if specified
            if let timeRange = self.timeRange {
                request = request.filter(
                    TelemetryMetric.Columns.timestamp >= timeRange.startTime &&
                    TelemetryMetric.Columns.timestamp <= timeRange.endTime
                )
            }
            
            // Order by timestamp
            request = request
                .order(TelemetryMetric.Columns.timestamp.desc)
                .limit(self.limit)
            
            let metrics = try request.fetchAll(db)
            
            // Filter by labels in memory (since labels are JSON)
            if !self.labels.isEmpty {
                return metrics.filter { metric in
                    self.labels.allSatisfy { (key, value) in
                        metric.labels[key] == value
                    }
                }
            }
            
            return metrics
        }
        .publisher(in: dbQueue, scheduling: .immediate)
        .eraseToAnyPublisher()
    }
}

/// Request for fetching metric names and their types
struct MetricNamesRequest {
    var collectorName: String
    
    /// Creates a publisher for SwiftUI integration
    func publisher(in dbQueue: DatabaseQueue) -> AnyPublisher<[MetricSummary], Error> {
        ValueObservation.tracking { db -> [MetricSummary] in
            let sql = """
                SELECT name, type, COUNT(*) as count, MIN(timestamp) as first_seen, MAX(timestamp) as last_seen
                FROM metrics 
                GROUP BY name, type 
                ORDER BY name
            """
            
            let rows = try Row.fetchAll(db, sql: sql)
            return rows.map { row in
                MetricSummary(
                    name: row["name"],
                    type: TelemetryMetric.MetricType(rawValue: row["type"]) ?? .gauge,
                    count: row["count"],
                    firstSeen: row["first_seen"],
                    lastSeen: row["last_seen"]
                )
            }
        }
        .publisher(in: dbQueue, scheduling: .immediate)
        .eraseToAnyPublisher()
    }
}

// MARK: - Log Queries

/// Request for searching logs with full-text search
struct LogSearchRequest {
    var collectorName: String
    var searchText: String?
    var severityLevels: Set<LogSeverity> = Set(LogSeverity.allCases)
    var traceId: String?
    var timeRange: TelemetryDataTimeRange?
    var limit: Int = 1000
    
    /// Creates a publisher for SwiftUI integration
    func publisher(in dbQueue: DatabaseQueue) -> AnyPublisher<[TelemetryLog], Error> {
        ValueObservation.tracking { db -> [TelemetryLog] in
            // Use FTS search if search text is provided
            if let searchText = self.searchText, !searchText.isEmpty {
                return try TelemetryLog.fetchAll(db, sql: """
                    SELECT logs.* FROM logs
                    JOIN logs_fts ON logs.id = logs_fts.rowid
                    WHERE logs_fts MATCH ?
                    ORDER BY logs.timestamp DESC
                    LIMIT ?
                """, arguments: [searchText, self.limit])
            } else {
                var request = TelemetryLog.all()
                
                // Filter by severity levels
                if self.severityLevels.count < LogSeverity.allCases.count {
                    let severityNumbers = self.severityLevels.map { $0.rawValue }
                    request = request.filter(severityNumbers.contains(TelemetryLog.Columns.severityNumber))
                }
                
                // Filter by trace ID if specified
                if let traceId = self.traceId {
                    request = request.filter(TelemetryLog.Columns.traceId == traceId)
                }
                
                // Filter by time range if specified
                if let timeRange = self.timeRange {
                    request = request.filter(
                        TelemetryLog.Columns.timestamp >= timeRange.startTime &&
                        TelemetryLog.Columns.timestamp <= timeRange.endTime
                    )
                }
                
                // Order by timestamp (most recent first)
                request = request
                    .order(TelemetryLog.Columns.timestamp.desc)
                    .limit(self.limit)
                
                return try request.fetchAll(db)
            }
        }
        .publisher(in: dbQueue, scheduling: .immediate)
        .eraseToAnyPublisher()
    }
}

/// Request for fetching log statistics
struct LogStatsRequest {
    var collectorName: String
    var timeRange: TelemetryDataTimeRange?
    
    /// Creates a publisher for SwiftUI integration
    func publisher(in dbQueue: DatabaseQueue) -> AnyPublisher<[LogSeverityStats], Error> {
        ValueObservation.tracking { db -> [LogSeverityStats] in
            var sql = """
                SELECT severity_number, COUNT(*) as count 
                FROM logs
            """
            var arguments: [DatabaseValueConvertible] = []
            
            if let timeRange = self.timeRange {
                sql += " WHERE timestamp >= ? AND timestamp <= ?"
                arguments = [timeRange.startTime, timeRange.endTime]
            }
            
            sql += " GROUP BY severity_number ORDER BY severity_number"
            
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return rows.map { row in
                LogSeverityStats(
                    severity: LogSeverity.from(number: row["severity_number"]),
                    count: row["count"]
                )
            }
        }
        .publisher(in: dbQueue, scheduling: .immediate)
        .eraseToAnyPublisher()
    }
}

// MARK: - Supporting Types

struct TelemetryDataTimeRange {
    let startTime: Int64
    let endTime: Int64
    
    static func recent(hours: Int) -> TelemetryDataTimeRange {
        let now = Int64(Date().timeIntervalSince1970 * 1_000_000_000) // nanoseconds
        let start = now - Int64(hours * 3600) * 1_000_000_000
        return TelemetryDataTimeRange(startTime: start, endTime: now)
    }
    
    static func recent(minutes: Int) -> TelemetryDataTimeRange {
        let now = Int64(Date().timeIntervalSince1970 * 1_000_000_000) // nanoseconds
        let start = now - Int64(minutes * 60) * 1_000_000_000
        return TelemetryDataTimeRange(startTime: start, endTime: now)
    }
}

struct TraceHierarchy: Hashable {
    let spans: [TelemetrySpan]
    
    var rootSpans: [TelemetrySpan] {
        spans.filter { $0.parentSpanId == nil }
    }
    
    func children(of span: TelemetrySpan) -> [TelemetrySpan] {
        spans.filter { $0.parentSpanId == span.spanId }
    }
    
    var duration: Int64 {
        guard !spans.isEmpty else { return 0 }
        let minStart = spans.map { $0.startTime }.min() ?? 0
        let maxEnd = spans.map { $0.endTime }.max() ?? 0
        return maxEnd - minStart
    }
}

struct MetricSummary: Identifiable {
    let name: String
    let type: TelemetryMetric.MetricType
    let count: Int
    let firstSeen: Int64
    let lastSeen: Int64
    
    var id: String { name }
}

struct LogSeverityStats: Identifiable {
    let severity: LogSeverity
    let count: Int
    
    var id: Int32 { severity.rawValue }
}

// MARK: - Database Query Extensions

extension TelemetryDatabase {
    /// Creates a queryable database connection for SwiftUI @Query
    func queryableDatabase(for collectorName: String) throws -> DatabaseQueue {
        return try database(for: collectorName)
    }
    
    /// Executes a trace request
    func traces(for request: TraceRequest) throws -> [TelemetrySpan] {
        let db = try database(for: request.collectorName)
        return try db.read { database in
            var query = TelemetrySpan.all()
            
            if let traceId = request.traceId {
                query = query.filter(TelemetrySpan.Columns.traceId == traceId)
            }
            
            if let serviceName = request.serviceName {
                query = query.filter(TelemetrySpan.Columns.serviceName == serviceName)
            }
            
            if let timeRange = request.timeRange {
                query = query.filter(
                    TelemetrySpan.Columns.startTime >= timeRange.startTime &&
                    TelemetrySpan.Columns.startTime <= timeRange.endTime
                )
            }
            
            return try query
                .order(TelemetrySpan.Columns.startTime.desc)
                .limit(request.limit)
                .fetchAll(database)
        }
    }
    
    /// Executes a metrics request
    func metrics(for request: MetricsTimeSeriesRequest) throws -> [TelemetryMetric] {
        let db = try database(for: request.collectorName)
        return try db.read { database in
            var query = TelemetryMetric.all()
            
            if let metricName = request.metricName {
                query = query.filter(TelemetryMetric.Columns.name == metricName)
            }
            
            if let timeRange = request.timeRange {
                query = query.filter(
                    TelemetryMetric.Columns.timestamp >= timeRange.startTime &&
                    TelemetryMetric.Columns.timestamp <= timeRange.endTime
                )
            }
            
            let metrics = try query
                .order(TelemetryMetric.Columns.timestamp.desc)
                .limit(request.limit)
                .fetchAll(database)
            
            // Filter by labels in memory
            if !request.labels.isEmpty {
                return metrics.filter { metric in
                    request.labels.allSatisfy { (key, value) in
                        metric.labels[key] == value
                    }
                }
            }
            
            return metrics
        }
    }
    
    /// Executes a logs search request
    func searchLogs(for request: LogSearchRequest) throws -> [TelemetryLog] {
        let db = try database(for: request.collectorName)
        return try db.read { database in
            // Use FTS search if search text is provided
            if let searchText = request.searchText, !searchText.isEmpty {
                return try TelemetryLog.fetchAll(database, sql: """
                    SELECT logs.* FROM logs
                    JOIN logs_fts ON logs.id = logs_fts.rowid
                    WHERE logs_fts MATCH ?
                    ORDER BY logs.timestamp DESC
                    LIMIT ?
                """, arguments: [searchText, request.limit])
            } else {
                var query = TelemetryLog.all()
                
                // Filter by severity levels
                if request.severityLevels.count < LogSeverity.allCases.count {
                    let severityNumbers = request.severityLevels.map { $0.rawValue }
                    query = query.filter(severityNumbers.contains(TelemetryLog.Columns.severityNumber))
                }
                
                // Filter by trace ID if specified
                if let traceId = request.traceId {
                    query = query.filter(TelemetryLog.Columns.traceId == traceId)
                }
                
                // Filter by time range if specified
                if let timeRange = request.timeRange {
                    query = query.filter(
                        TelemetryLog.Columns.timestamp >= timeRange.startTime &&
                        TelemetryLog.Columns.timestamp <= timeRange.endTime
                    )
                }
                
                return try query
                    .order(TelemetryLog.Columns.timestamp.desc)
                    .limit(request.limit)
                    .fetchAll(database)
            }
        }
    }
}