import Foundation
import os
import Observation

/// Independent telemetry viewer for UI components
/// Provides read-only access to telemetry data stored in the database
@MainActor
@Observable
final class TelemetryViewer {
    private let logger = Logger.ui
    private let storage: TelemetryStorageProtocol
    
    // MARK: - Observable State
    
    /// Currently selected collector for filtering (or "all" for no filter)
    var selectedCollector: String = "all"
    
    /// Statistics for all collectors
    private(set) var collectorStats: [CollectorStats] = []
    
    /// Last executed query result
    private(set) var lastQueryResult: QueryResult?
    
    /// Whether a query is currently executing
    private(set) var isExecutingQuery = false
    
    /// Last query execution error
    private(set) var lastQueryError: Error?
    
    init(storage: TelemetryStorageProtocol) {
        self.storage = storage
        // Auto-refresh stats on initialization
        Task {
            await refreshCollectorStats()
        }
    }
    
    // MARK: - Data Operations
    
    /// Refresh collector statistics
    func refreshCollectorStats() async {
        do {
            let stats = try await storage.getDatabaseStats()
            await MainActor.run {
                self.collectorStats = stats
                self.logger.debug("Refreshed collector stats: \(stats.count) collectors")
            }
        } catch {
            await MainActor.run {
                self.logger.error("Failed to refresh collector stats: \(error)")
            }
        }
    }
    
    /// Execute a SQL query with optional collector filtering
    func executeQuery(_ sql: String) async {
        await MainActor.run {
            isExecutingQuery = true
            lastQueryError = nil
        }
        
        do {
            // Apply collector filtering if not "all"
            let filteredSQL = applyCollectorFilter(to: sql, collector: selectedCollector)
            
            let result = try await storage.executeQuery(filteredSQL)
            
            await MainActor.run {
                self.lastQueryResult = result
                self.isExecutingQuery = false
                self.logger.debug("Executed query successfully: \(result.rows.count) rows")
            }
        } catch {
            await MainActor.run {
                self.lastQueryError = error
                self.isExecutingQuery = false
                self.logger.error("Query execution failed: \(error)")
            }
        }
    }
    
    /// Clear data for a specific collector
    func clearCollectorData(_ collectorName: String) async {
        do {
            try await storage.clearData(for: collectorName)
            await refreshCollectorStats()
            logger.info("Cleared data for collector: \(collectorName)")
        } catch {
            logger.error("Failed to clear data for collector \(collectorName): \(error)")
        }
    }
    
    // MARK: - Query Templates
    
    /// Get predefined query templates
    var queryTemplates: [QueryTemplate] {
        return [
            // Traces
            QueryTemplate(
                name: "Recent Traces",
                description: "Show the most recent traces",
                category: .traces,
                sql: """
                SELECT 
                    trace_id,
                    service_name,
                    operation_name,
                    duration_nanos / 1000000 as duration_ms,
                    datetime(start_time_nanos / 1000000000, 'unixepoch') as start_time
                FROM spans 
                ORDER BY start_time_nanos DESC 
                LIMIT 50
                """
            ),
            QueryTemplate(
                name: "Slowest Traces",
                description: "Find the slowest traces in the last hour",
                category: .traces,
                sql: """
                SELECT 
                    trace_id,
                    service_name,
                    operation_name,
                    duration_nanos / 1000000 as duration_ms,
                    datetime(start_time_nanos / 1000000000, 'unixepoch') as start_time
                FROM spans 
                WHERE start_time_nanos > (strftime('%s', 'now') - 3600) * 1000000000
                ORDER BY duration_nanos DESC 
                LIMIT 20
                """
            ),
            QueryTemplate(
                name: "Error Traces",
                description: "Find traces with errors",
                category: .traces,
                sql: """
                SELECT 
                    trace_id,
                    service_name,
                    operation_name,
                    status_code,
                    status_message,
                    datetime(start_time_nanos / 1000000000, 'unixepoch') as start_time
                FROM spans 
                WHERE status_code = 2
                ORDER BY start_time_nanos DESC 
                LIMIT 50
                """
            ),
            
            // Metrics
            QueryTemplate(
                name: "Latest Metrics",
                description: "Show latest metrics by service",
                category: .metrics,
                sql: """
                SELECT 
                    service_name,
                    metric_name,
                    type,
                    value,
                    datetime(timestamp_nanos / 1000000000, 'unixepoch') as timestamp
                FROM metrics 
                WHERE timestamp_nanos > (strftime('%s', 'now') - 900) * 1000000000
                ORDER BY service_name, timestamp_nanos DESC
                LIMIT 100
                """
            ),
            
            // Logs
            QueryTemplate(
                name: "Recent Error Logs",
                description: "Show error and fatal logs from the last hour",
                category: .logs,
                sql: """
                SELECT 
                    datetime(timestamp_nanos / 1000000000, 'unixepoch') as timestamp,
                    severity_text,
                    service_name,
                    body,
                    trace_id
                FROM logs 
                WHERE severity_number >= 17
                AND timestamp_nanos > (strftime('%s', 'now') - 3600) * 1000000000
                ORDER BY timestamp_nanos DESC 
                LIMIT 100
                """
            ),
            
            // Analysis
            QueryTemplate(
                name: "Service Performance Summary",
                description: "Performance metrics by service",
                category: .analysis,
                sql: """
                SELECT 
                    service_name,
                    COUNT(*) as span_count,
                    AVG(duration_nanos) / 1000000 as avg_duration_ms,
                    MAX(duration_nanos) / 1000000 as max_duration_ms,
                    SUM(CASE WHEN status_code = 2 THEN 1 ELSE 0 END) as error_count,
                    (SUM(CASE WHEN status_code = 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) as error_rate_percent
                FROM spans 
                WHERE start_time_nanos > (strftime('%s', 'now') - 3600) * 1000000000
                GROUP BY service_name
                ORDER BY avg_duration_ms DESC
                """
            )
        ]
    }
    
    // MARK: - Export Support
    
    /// Export query result to file
    func exportResult(to url: URL, format: ExportFormat) throws {
        guard let result = lastQueryResult else {
            throw TelemetryViewerError.noResultToExport
        }
        
        let content: String
        
        switch format {
        case .csv:
            content = formatAsCSV(result)
        case .json:
            content = try formatAsJSON(result)
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        logger.info("Exported query result to \(url.path)")
    }
    
    // MARK: - Private Methods
    
    private func applyCollectorFilter(to sql: String, collector: String) -> String {
        guard collector != "all" else { return sql }
        
        // Simple filter injection - in a production app, you'd want more sophisticated query rewriting
        let lowercaseSQL = sql.lowercased()
        
        if lowercaseSQL.contains("where") {
            return sql + " AND collector_name = '\(collector)'"
        } else if lowercaseSQL.contains("order by") || lowercaseSQL.contains("group by") || lowercaseSQL.contains("limit") {
            // Insert WHERE clause before ORDER BY, GROUP BY, or LIMIT
            let patterns = ["order by", "group by", "limit"]
            
            for pattern in patterns {
                if let range = lowercaseSQL.range(of: pattern) {
                    let insertionPoint = sql.index(sql.startIndex, offsetBy: lowercaseSQL.distance(from: lowercaseSQL.startIndex, to: range.lowerBound))
                    return String(sql[..<insertionPoint]) + "WHERE collector_name = '\(collector)' " + String(sql[insertionPoint...])
                }
            }
        }
        
        // Fallback: append WHERE clause at the end
        return sql + " WHERE collector_name = '\(collector)'"
    }
    
    private func formatAsCSV(_ result: QueryResult) -> String {
        var lines: [String] = []
        
        // Header
        lines.append(result.columns.joined(separator: ","))
        
        // Rows with CSV escaping
        for row in result.rows {
            let escapedRow = row.map { value in
                if value.contains(",") || value.contains("\"") || value.contains("\n") {
                    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
                } else {
                    return value
                }
            }
            lines.append(escapedRow.joined(separator: ","))
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func formatAsJSON(_ result: QueryResult) throws -> String {
        var jsonRows: [[String: String]] = []
        
        for row in result.rows {
            var jsonRow: [String: String] = [:]
            for (index, column) in result.columns.enumerated() {
                if index < row.count {
                    jsonRow[column] = row[index]
                }
            }
            jsonRows.append(jsonRow)
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonRows, options: .prettyPrinted)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
}

// MARK: - Supporting Types

struct QueryTemplate: Identifiable, Sendable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let category: QueryCategory
    let sql: String
}

enum QueryCategory: String, CaseIterable, Sendable, Hashable {
    case traces = "Traces"
    case metrics = "Metrics"
    case logs = "Logs"
    case analysis = "Analysis"
    case custom = "Custom"
}

public enum ExportFormat: String, CaseIterable, Sendable {
    case csv = "CSV"
    case json = "JSON"
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        }
    }
    
    var contentType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        }
    }
}

enum TelemetryViewerError: LocalizedError {
    case noResultToExport
    
    var errorDescription: String? {
        switch self {
        case .noResultToExport:
            return "No query result available to export"
        }
    }
}
