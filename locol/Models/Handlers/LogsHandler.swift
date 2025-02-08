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
} 