import Foundation
import GRDB
import os

// MARK: - SQL Query Results

struct SQLQueryResult {
    let columns: [String]
    let rows: [[String]]
    let executionTime: TimeInterval
    let rowCount: Int
    
    var isEmpty: Bool {
        rows.isEmpty
    }
}

// MARK: - SQL Query Templates

struct SQLQueryTemplate {
    let name: String
    let description: String
    let query: String
    let category: SQLQueryCategory
    
    static let templates: [SQLQueryTemplate] = [
        // Traces
        SQLQueryTemplate(
            name: "Slowest Traces",
            description: "Find the slowest traces in the last hour",
            query: """
            SELECT 
                trace_id,
                service_name,
                operation_name,
                duration_ms,
                start_time
            FROM telemetry_spans 
            WHERE start_time >= datetime('now', '-1 hour')
            ORDER BY duration_ms DESC 
            LIMIT 20
            """,
            category: .traces
        ),
        
        SQLQueryTemplate(
            name: "Error Traces",
            description: "Find traces with errors",
            query: """
            SELECT 
                trace_id,
                service_name,
                operation_name,
                status_code,
                status_message,
                start_time
            FROM telemetry_spans 
            WHERE status_code = 2
            ORDER BY start_time DESC 
            LIMIT 50
            """,
            category: .traces
        ),
        
        // Metrics
        SQLQueryTemplate(
            name: "Latest Metrics by Service",
            description: "Show latest metrics grouped by service",
            query: """
            SELECT 
                service_name,
                name as metric_name,
                type,
                value,
                timestamp
            FROM telemetry_metrics 
            WHERE timestamp >= datetime('now', '-15 minutes')
            ORDER BY service_name, timestamp DESC
            """,
            category: .metrics
        ),
        
        // Logs
        SQLQueryTemplate(
            name: "Recent Error Logs",
            description: "Show error and fatal logs from the last hour",
            query: """
            SELECT 
                timestamp,
                severity_text,
                service_name,
                body,
                trace_id
            FROM telemetry_logs 
            WHERE severity_number >= 17
            AND timestamp >= datetime('now', '-1 hour')
            ORDER BY timestamp DESC 
            LIMIT 100
            """,
            category: .logs
        ),
        
        // Performance Analysis
        SQLQueryTemplate(
            name: "Service Performance Summary",
            description: "Performance metrics by service",
            query: """
            SELECT 
                service_name,
                COUNT(*) as span_count,
                AVG(duration_ms) as avg_duration_ms,
                MAX(duration_ms) as max_duration_ms,
                SUM(CASE WHEN status_code = 2 THEN 1 ELSE 0 END) as error_count
            FROM telemetry_spans 
            WHERE start_time >= datetime('now', '-1 hour')
            GROUP BY service_name
            ORDER BY avg_duration_ms DESC
            """,
            category: .analysis
        )
    ]
}

enum SQLQueryCategory: String, CaseIterable {
    case traces = "Traces"
    case metrics = "Metrics"
    case logs = "Logs"
    case analysis = "Analysis"
    case custom = "Custom"
}

// MARK: - SQL Query Executor

@MainActor
@Observable
class SQLQueryExecutor {
    private let telemetryDB = TelemetryDatabase.shared
    private let logger = Logger(subsystem: "com.locol.telemetry", category: "SQLQueryExecutor")
    
    private(set) var isExecuting = false
    private(set) var lastResult: SQLQueryResult?
    private(set) var lastError: Error?
    
    // Query history
    private(set) var queryHistory: [String] = []
    private let maxHistoryCount = 50
    
    func executeQuery(_ query: String, collectorName: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            lastError = SQLQueryError.emptyQuery
            return
        }
        
        // Validate query is read-only
        guard isReadOnlyQuery(query) else {
            lastError = SQLQueryError.writeOperationNotAllowed
            return
        }
        
        isExecuting = true
        lastError = nil
        
        let startTime = Date()
        
        do {
            let db = try telemetryDB.database(for: collectorName)
            let result = try await executeReadOnlyQuery(query, in: db)
            
            lastResult = SQLQueryResult(
                columns: result.columns,
                rows: result.rows,
                executionTime: Date().timeIntervalSince(startTime),
                rowCount: result.rows.count
            )
            
            // Add to history
            addToHistory(query)
            
            logger.info("Executed SQL query successfully: \(result.rows.count) rows in \(Date().timeIntervalSince(startTime))s")
            
        } catch {
            lastError = error
            logger.error("Failed to execute SQL query: \(error)")
        }
        
        isExecuting = false
    }
    
    private func executeReadOnlyQuery(_ query: String, in dbQueue: DatabaseQueue) async throws -> (columns: [String], rows: [[String]]) {
        return try await withCheckedThrowingContinuation { continuation in
            dbQueue.asyncRead { result in
                switch result {
                case .success(let db):
                    do {
                        // Use GRDB's Row.fetchAll for raw SQL queries
                        let rows = try Row.fetchAll(db, sql: query)
                        
                        // Get column names from the first row if available
                        guard let firstRow = rows.first else {
                            continuation.resume(returning: (columns: [], rows: []))
                            return
                        }
                        
                        let columns = Array(firstRow.columnNames)
                        
                        // Convert rows to string arrays
                        let stringRows: [[String]] = rows.map { row in
                            columns.map { columnName in
                                if let value: String = row[columnName] {
                                    return value
                                } else if let value: Int = row[columnName] {
                                    return String(value)
                                } else if let value: Double = row[columnName] {
                                    return String(value)
                                } else if let value: Bool = row[columnName] {
                                    return value ? "true" : "false"
                                } else if row[columnName] != nil {
                                    return String(describing: row[columnName])
                                } else {
                                    return "NULL"
                                }
                            }
                        }
                        
                        continuation.resume(returning: (columns: columns, rows: stringRows))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func isReadOnlyQuery(_ query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Allow SELECT, WITH (for CTEs), and EXPLAIN
        let allowedStartPatterns = ["select", "with", "explain"]
        let startsWithAllowed = allowedStartPatterns.contains { pattern in
            normalizedQuery.hasPrefix(pattern)
        }
        
        // Explicitly deny write operations
        let writeOperations = ["insert", "update", "delete", "drop", "create", "alter", "truncate", "replace"]
        let containsWriteOp = writeOperations.contains { operation in
            normalizedQuery.contains(operation)
        }
        
        return startsWithAllowed && !containsWriteOp
    }
    
    private func addToHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove from history if it already exists
        queryHistory.removeAll { $0 == trimmedQuery }
        
        // Add to beginning of history
        queryHistory.insert(trimmedQuery, at: 0)
        
        // Keep only the most recent queries
        if queryHistory.count > maxHistoryCount {
            queryHistory = Array(queryHistory.prefix(maxHistoryCount))
        }
    }
    
    func clearHistory() {
        queryHistory.removeAll()
    }
    
    func exportResult(to url: URL, format: ExportFormat) throws {
        guard let result = lastResult else {
            throw SQLQueryError.noResultToExport
        }
        
        let content: String
        
        switch format {
        case .csv:
            content = formatAsCSV(result)
        case .json:
            content = try formatAsJSON(result)
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func formatAsCSV(_ result: SQLQueryResult) -> String {
        var lines: [String] = []
        
        // Header
        lines.append(result.columns.joined(separator: ","))
        
        // Rows
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
    
    private func formatAsJSON(_ result: SQLQueryResult) throws -> String {
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

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        }
    }
}

// MARK: - Errors

enum SQLQueryError: LocalizedError {
    case emptyQuery
    case writeOperationNotAllowed
    case noResultToExport
    
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Query cannot be empty"
        case .writeOperationNotAllowed:
            return "Write operations (INSERT, UPDATE, DELETE, etc.) are not allowed"
        case .noResultToExport:
            return "No query result available to export"
        }
    }
}