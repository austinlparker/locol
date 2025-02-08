import Foundation
import DuckDB
import os

final class SpansHandler {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SpansHandler")
    private let database: DatabaseProtocol
    
    init(database: DatabaseProtocol) {
        self.database = database
    }
    
    func handleSpan(_ span: Opentelemetry_Proto_Trace_V1_Span, resourceId: UUID, scopeId: UUID) async throws {
        let appender = try database.createAppender(for: "spans")
        
        let attributes = JSONUtils.attributesToJSON(span.attributes)
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
    }
} 