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
    
    func getSpans(forResourceIds resourceIds: [String]) async throws -> [SpanRow] {
        let resourceList = resourceIds.map { "'\($0)'" }.joined(separator: ",")
        let query = """
            SELECT 
                trace_id,
                span_id,
                parent_span_id,
                name,
                kind,
                start_time,
                end_time,
                attributes,
                resource_id
            FROM spans
            WHERE resource_id IN (\(resourceList));
        """
        
        let result = try await database.executeQuery(query)
        var spans: [SpanRow] = []
        
        let traceIds = result["trace_id"] as? [String] ?? []
        let spanIds = result["span_id"] as? [String] ?? []
        let parentSpanIds = result["parent_span_id"] as? [String] ?? []
        let names = result["name"] as? [String] ?? []
        let kinds = result["kind"] as? [Int32] ?? []
        let startTimes = result["start_time"] as? [Foundation.Date] ?? []
        let endTimes = result["end_time"] as? [Foundation.Date] ?? []
        let attributes = result["attributes"] as? [String] ?? []
        let resourceIds = result["resource_id"] as? [String] ?? []
        
        // Find the minimum length to avoid index out of range
        let count = min(
            traceIds.count,
            spanIds.count,
            parentSpanIds.count,
            names.count,
            kinds.count,
            startTimes.count,
            endTimes.count,
            attributes.count,
            resourceIds.count
        )
        
        for i in 0..<count {
            spans.append(SpanRow(
                traceId: traceIds[i],
                spanId: spanIds[i],
                parentSpanId: parentSpanIds[i],
                name: names[i],
                kind: kinds[i],
                startTime: startTimes[i],
                endTime: endTimes[i],
                attributes: attributes[i],
                resourceId: resourceIds[i]
            ))
        }
        
        return spans
    }
} 