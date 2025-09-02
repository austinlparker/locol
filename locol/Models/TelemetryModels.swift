import Foundation
import GRDB

// MARK: - TelemetrySpan

struct TelemetrySpan: Codable, Hashable {
    let spanId: String
    let traceId: String
    let parentSpanId: String?
    let serviceName: String?
    let operationName: String?
    let startTime: Int64
    let endTime: Int64
    let duration: Int64
    let statusCode: Int32
    let statusMessage: String?
    let attributes: [String: AttributeValue]
    let events: [SpanEvent]
    let links: [SpanLink]
    let createdAt: Int64
    
    var durationNanos: Int64 {
        endTime - startTime
    }
}

// MARK: - TelemetryMetric

struct TelemetryMetric: Codable {
    let id: Int64?
    let name: String
    let type: MetricType
    let timestamp: Int64
    let value: Double?
    let labels: [String: String]
    let exemplars: [Exemplar]
    
    // For histogram/summary metrics
    let bucketCounts: [Int64]?
    let bucketBounds: [Double]?
    let sum: Double?
    let count: Int64?
    
    let createdAt: Int64
    
    enum MetricType: String, Codable, CaseIterable {
        case counter = "counter"
        case gauge = "gauge"
        case histogram = "histogram"
        case summary = "summary"
    }
}

// MARK: - TelemetryLog

struct TelemetryLog: Codable {
    let id: Int64?
    let timestamp: Int64
    let severityNumber: Int32?
    let severityText: String?
    let body: String
    let attributes: [String: AttributeValue]
    let resource: [String: AttributeValue]
    let traceId: String?
    let spanId: String?
    let createdAt: Int64
    
    var severity: LogSeverity {
        LogSeverity.from(number: severityNumber)
    }
}

// MARK: - Supporting Types

struct AttributeValue: Codable, Hashable {
    let stringValue: String?
    let intValue: Int64?
    let doubleValue: Double?
    let boolValue: Bool?
    let arrayValue: [AttributeValue]?
    let kvlistValue: [String: AttributeValue]?
    
    var displayValue: String {
        if let string = stringValue { return string }
        if let int = intValue { return String(int) }
        if let double = doubleValue { return String(double) }
        if let bool = boolValue { return String(bool) }
        if let array = arrayValue { return "[\(array.map(\.displayValue).joined(separator: ", "))]" }
        if let kvlist = kvlistValue {
            let pairs = kvlist.map { "\($0.key): \($0.value.displayValue)" }
            return "{\(pairs.joined(separator: ", "))}"
        }
        return ""
    }
}

struct SpanEvent: Codable, Hashable {
    let name: String
    let timestamp: Int64
    let attributes: [String: AttributeValue]
}

struct SpanLink: Codable, Hashable {
    let traceId: String
    let spanId: String
    let attributes: [String: AttributeValue]
}

struct Exemplar: Codable, Hashable {
    let value: Double
    let timestamp: Int64
    let traceId: String?
    let spanId: String?
    let labels: [String: String]
}

enum LogSeverity: Int32, CaseIterable {
    case trace = 1
    case debug = 5
    case info = 9
    case warn = 13
    case error = 17
    case fatal = 21
    
    static func from(number: Int32?) -> LogSeverity {
        guard let number = number else { return .info }
        return LogSeverity(rawValue: number) ?? .info
    }
    
    var displayName: String {
        switch self {
        case .trace: return "TRACE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warn: return "WARN"
        case .error: return "ERROR"
        case .fatal: return "FATAL"
        }
    }
    
    var color: String {
        switch self {
        case .trace: return "gray"
        case .debug: return "blue"
        case .info: return "green"
        case .warn: return "yellow"
        case .error: return "red"
        case .fatal: return "purple"
        }
    }
}

// MARK: - GRDB Record Conformance

extension TelemetrySpan: FetchableRecord, PersistableRecord {
    static let databaseTableName = "spans"
    
    enum Columns: String, ColumnExpression {
        case spanId = "span_id"
        case traceId = "trace_id"
        case parentSpanId = "parent_span_id"
        case serviceName = "service_name"
        case operationName = "operation_name"
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case statusCode = "status_code"
        case statusMessage = "status_message"
        case attributes
        case events
        case links
        case createdAt = "created_at"
    }
    
    init(row: Row) {
        spanId = row[Columns.spanId]
        traceId = row[Columns.traceId]
        parentSpanId = row[Columns.parentSpanId]
        serviceName = row[Columns.serviceName]
        operationName = row[Columns.operationName]
        startTime = row[Columns.startTime]
        endTime = row[Columns.endTime]
        duration = row[Columns.duration]
        statusCode = row[Columns.statusCode]
        statusMessage = row[Columns.statusMessage]
        createdAt = row[Columns.createdAt]
        
        // Decode JSON fields
        let attributesJSON: String? = row[Columns.attributes]
        attributes = Self.decodeJSON(attributesJSON) ?? [:]
        
        let eventsJSON: String? = row[Columns.events]
        events = Self.decodeJSON(eventsJSON) ?? []
        
        let linksJSON: String? = row[Columns.links]
        links = Self.decodeJSON(linksJSON) ?? []
    }
    
    func encode(to container: inout PersistenceContainer) {
        container[Columns.spanId] = spanId
        container[Columns.traceId] = traceId
        container[Columns.parentSpanId] = parentSpanId
        container[Columns.serviceName] = serviceName
        container[Columns.operationName] = operationName
        container[Columns.startTime] = startTime
        container[Columns.endTime] = endTime
        container[Columns.duration] = duration
        container[Columns.statusCode] = statusCode
        container[Columns.statusMessage] = statusMessage
        container[Columns.createdAt] = createdAt
        
        // Encode JSON fields
        container[Columns.attributes] = Self.encodeJSON(attributes)
        container[Columns.events] = Self.encodeJSON(events)
        container[Columns.links] = Self.encodeJSON(links)
    }
}

extension TelemetryMetric: FetchableRecord, PersistableRecord {
    static let databaseTableName = "metrics"
    
    enum Columns: String, ColumnExpression {
        case id
        case name
        case type
        case timestamp
        case value
        case labels
        case exemplars
        case bucketCounts = "bucket_counts"
        case bucketBounds = "bucket_bounds"
        case sum
        case count
        case createdAt = "created_at"
    }
    
    init(row: Row) {
        id = row[Columns.id]
        name = row[Columns.name]
        type = MetricType(rawValue: row[Columns.type]) ?? .gauge
        timestamp = row[Columns.timestamp]
        value = row[Columns.value]
        sum = row[Columns.sum]
        count = row[Columns.count]
        createdAt = row[Columns.createdAt]
        
        // Decode JSON fields
        let labelsJSON: String? = row[Columns.labels]
        labels = Self.decodeJSON(labelsJSON) ?? [:]
        
        let exemplarsJSON: String? = row[Columns.exemplars]
        exemplars = Self.decodeJSON(exemplarsJSON) ?? []
        
        let countsJSON: String? = row[Columns.bucketCounts]
        bucketCounts = Self.decodeJSON(countsJSON)
        
        let boundsJSON: String? = row[Columns.bucketBounds]
        bucketBounds = Self.decodeJSON(boundsJSON)
    }
    
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.name] = name
        container[Columns.type] = type.rawValue
        container[Columns.timestamp] = timestamp
        container[Columns.value] = value
        container[Columns.sum] = sum
        container[Columns.count] = count
        container[Columns.createdAt] = createdAt
        
        // Encode JSON fields
        container[Columns.labels] = Self.encodeJSON(labels)
        container[Columns.exemplars] = Self.encodeJSON(exemplars)
        container[Columns.bucketCounts] = Self.encodeJSON(bucketCounts)
        container[Columns.bucketBounds] = Self.encodeJSON(bucketBounds)
    }
}

extension TelemetryLog: FetchableRecord, PersistableRecord {
    static let databaseTableName = "logs"
    
    enum Columns: String, ColumnExpression {
        case id
        case timestamp
        case severityNumber = "severity_number"
        case severityText = "severity_text"
        case body
        case attributes
        case resource
        case traceId = "trace_id"
        case spanId = "span_id"
        case createdAt = "created_at"
    }
    
    init(row: Row) {
        id = row[Columns.id]
        timestamp = row[Columns.timestamp]
        severityNumber = row[Columns.severityNumber]
        severityText = row[Columns.severityText]
        body = row[Columns.body]
        traceId = row[Columns.traceId]
        spanId = row[Columns.spanId]
        createdAt = row[Columns.createdAt]
        
        // Decode JSON fields
        let attributesJSON: String? = row[Columns.attributes]
        attributes = Self.decodeJSON(attributesJSON) ?? [:]
        
        let resourceJSON: String? = row[Columns.resource]
        resource = Self.decodeJSON(resourceJSON) ?? [:]
    }
    
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.timestamp] = timestamp
        container[Columns.severityNumber] = severityNumber
        container[Columns.severityText] = severityText
        container[Columns.body] = body
        container[Columns.traceId] = traceId
        container[Columns.spanId] = spanId
        container[Columns.createdAt] = createdAt
        
        // Encode JSON fields
        container[Columns.attributes] = Self.encodeJSON(attributes)
        container[Columns.resource] = Self.encodeJSON(resource)
    }
}

// MARK: - JSON Helpers

extension FetchableRecord {
    static func decodeJSON<T: Codable>(_ jsonString: String?) -> T? {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    static func encodeJSON<T: Codable>(_ value: T?) -> String? {
        guard let value = value,
              let data = try? JSONEncoder().encode(value) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Identifiable Conformance

extension TelemetrySpan: Identifiable {
    var id: String { spanId }
}

extension TelemetryMetric: Identifiable {
    var identifier: String {
        return "\(name)_\(timestamp)_\(id ?? 0)"
    }
}

extension TelemetryLog: Identifiable {
    var identifier: String {
        return "\(timestamp)_\(id ?? 0)"
    }
}