import Foundation
import DuckDB
import os

final class LogsHandler {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LogsHandler")
    private let database: DatabaseProtocol
    
    init(database: DatabaseProtocol) {
        self.database = database
    }
    
    func handleLog(_ log: Opentelemetry_Proto_Logs_V1_LogRecord, resourceId: UUID, scopeId: UUID) async throws {
        let appender = try database.createAppender(for: "log_records")

        let logId = UUID()
        let timestamp = Foundation.Date(timeIntervalSince1970: TimeInterval(log.timeUnixNano) / 1_000_000_000)
        let attributes = JSONUtils.attributesToJSON(log.attributes)
        
        try appender.append(logId.uuidString)
        try appender.append(resourceId.uuidString)
        try appender.append(scopeId.uuidString)
        try appender.append(log.severityText)
        try appender.append(Int32(log.severityNumber.rawValue))
        try appender.append(log.body.stringValue)
        try appender.append(attributes)
        try appender.append(Timestamp(timestamp))
        try appender.endRow()
        try appender.flush()
    }
    
    func getLogs(forResourceIds resourceIds: [String]) async throws -> [LogRow] {
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
        
        let result = try await database.executeQuery(query)
        var logs: [LogRow] = []
        
        let timestamps = result["timestamp"] as? [Foundation.Date] ?? []
        let severityTexts = result["severity_text"] as? [String] ?? []
        let severityNumbers = result["severity_number"] as? [Int32] ?? []
        let bodies = result["body"] as? [String] ?? []
        let attributes = result["attributes"] as? [String] ?? []
        let resourceIds = result["resource_id"] as? [String] ?? []
        
        // Find the minimum length to avoid index out of range
        let count = min(
            timestamps.count,
            severityTexts.count,
            severityNumbers.count,
            bodies.count,
            attributes.count,
            resourceIds.count
        )
        
        for i in 0..<count {
            logs.append(LogRow(
                timestamp: timestamps[i],
                severityText: severityTexts[i],
                severityNumber: severityNumbers[i],
                body: bodies[i],
                attributes: attributes[i],
                resourceId: resourceIds[i]
            ))
        }
        
        return logs
    }
} 