import Foundation
import GRDB

// MARK: - Database Storage Models

/// Database model for storing distributed tracing spans
struct StoredSpan: Sendable {
    let id: Int64?
    let collectorName: String
    let traceId: String
    let spanId: String
    let parentSpanId: String?
    let operationName: String
    let serviceName: String?
    let startTimeNanos: Int64
    let endTimeNanos: Int64
    let durationNanos: Int64
    let statusCode: Int?
    let statusMessage: String?
    let kind: Int?
    let attributes: String // JSON
    let events: String // JSON
    let links: String // JSON
    let resourceAttributes: String // JSON
    let scopeName: String?
    let scopeVersion: String?
    let scopeAttributes: String // JSON
    let createdAt: Date
    
    init(
        id: Int64? = nil,
        collectorName: String,
        traceId: String,
        spanId: String,
        parentSpanId: String? = nil,
        operationName: String,
        serviceName: String? = nil,
        startTimeNanos: Int64,
        endTimeNanos: Int64,
        durationNanos: Int64,
        statusCode: Int? = nil,
        statusMessage: String? = nil,
        kind: Int? = nil,
        attributes: [String: Any] = [:],
        events: [[String: Any]] = [],
        links: [[String: Any]] = [],
        resourceAttributes: [String: Any] = [:],
        scopeName: String? = nil,
        scopeVersion: String? = nil,
        scopeAttributes: [String: Any] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.collectorName = collectorName
        self.traceId = traceId
        self.spanId = spanId
        self.parentSpanId = parentSpanId
        self.operationName = operationName
        self.serviceName = serviceName
        self.startTimeNanos = startTimeNanos
        self.endTimeNanos = endTimeNanos
        self.durationNanos = durationNanos
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.kind = kind
        self.attributes = Self.encodeJSON(attributes)
        self.events = Self.encodeJSON(events)
        self.links = Self.encodeJSON(links)
        self.resourceAttributes = Self.encodeJSON(resourceAttributes)
        self.scopeName = scopeName
        self.scopeVersion = scopeVersion
        self.scopeAttributes = Self.encodeJSON(scopeAttributes)
        self.createdAt = createdAt
    }
    
    private static func encodeJSON(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

/// Database model for storing metrics data
struct StoredMetric: Sendable {
    let id: Int64?
    let collectorName: String
    let metricName: String
    let description: String?
    let unit: String?
    let type: String
    let serviceName: String?
    let timestampNanos: Int64
    let value: Double?
    let attributes: String // JSON
    let resourceAttributes: String // JSON
    let scopeName: String?
    let scopeVersion: String?
    let scopeAttributes: String // JSON
    let createdAt: Date
    
    init(
        id: Int64? = nil,
        collectorName: String,
        metricName: String,
        description: String? = nil,
        unit: String? = nil,
        type: String,
        serviceName: String? = nil,
        timestampNanos: Int64,
        value: Double? = nil,
        attributes: [String: Any] = [:],
        resourceAttributes: [String: Any] = [:],
        scopeName: String? = nil,
        scopeVersion: String? = nil,
        scopeAttributes: [String: Any] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.collectorName = collectorName
        self.metricName = metricName
        self.description = description
        self.unit = unit
        self.type = type
        self.serviceName = serviceName
        self.timestampNanos = timestampNanos
        self.value = value
        self.attributes = Self.encodeJSON(attributes)
        self.resourceAttributes = Self.encodeJSON(resourceAttributes)
        self.scopeName = scopeName
        self.scopeVersion = scopeVersion
        self.scopeAttributes = Self.encodeJSON(scopeAttributes)
        self.createdAt = createdAt
    }
    
    private static func encodeJSON(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

/// Database model for storing log entries
struct StoredLog: Sendable {
    let id: Int64?
    let collectorName: String
    let timestampNanos: Int64
    let severityText: String?
    let severityNumber: Int?
    let body: String?
    let serviceName: String?
    let traceId: String?
    let spanId: String?
    let attributes: String // JSON
    let resourceAttributes: String // JSON
    let scopeName: String?
    let scopeVersion: String?
    let scopeAttributes: String // JSON
    let createdAt: Date
    
    init(
        id: Int64? = nil,
        collectorName: String,
        timestampNanos: Int64,
        severityText: String? = nil,
        severityNumber: Int? = nil,
        body: String? = nil,
        serviceName: String? = nil,
        traceId: String? = nil,
        spanId: String? = nil,
        attributes: [String: Any] = [:],
        resourceAttributes: [String: Any] = [:],
        scopeName: String? = nil,
        scopeVersion: String? = nil,
        scopeAttributes: [String: Any] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.collectorName = collectorName
        self.timestampNanos = timestampNanos
        self.severityText = severityText
        self.severityNumber = severityNumber
        self.body = body
        self.serviceName = serviceName
        self.traceId = traceId
        self.spanId = spanId
        self.attributes = Self.encodeJSON(attributes)
        self.resourceAttributes = Self.encodeJSON(resourceAttributes)
        self.scopeName = scopeName
        self.scopeVersion = scopeVersion
        self.scopeAttributes = Self.encodeJSON(scopeAttributes)
        self.createdAt = createdAt
    }
    
    private static func encodeJSON(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

// MARK: - GRDB Conformance

extension StoredSpan: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "spans"
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let collectorName = Column(CodingKeys.collectorName)
        static let traceId = Column(CodingKeys.traceId)
        static let spanId = Column(CodingKeys.spanId)
        static let parentSpanId = Column(CodingKeys.parentSpanId)
        static let operationName = Column(CodingKeys.operationName)
        static let serviceName = Column(CodingKeys.serviceName)
        static let startTimeNanos = Column(CodingKeys.startTimeNanos)
        static let endTimeNanos = Column(CodingKeys.endTimeNanos)
        static let durationNanos = Column(CodingKeys.durationNanos)
        static let statusCode = Column(CodingKeys.statusCode)
        static let statusMessage = Column(CodingKeys.statusMessage)
        static let kind = Column(CodingKeys.kind)
        static let attributes = Column(CodingKeys.attributes)
        static let events = Column(CodingKeys.events)
        static let links = Column(CodingKeys.links)
        static let resourceAttributes = Column(CodingKeys.resourceAttributes)
        static let scopeName = Column(CodingKeys.scopeName)
        static let scopeVersion = Column(CodingKeys.scopeVersion)
        static let scopeAttributes = Column(CodingKeys.scopeAttributes)
        static let createdAt = Column(CodingKeys.createdAt)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case collectorName = "collector_name"
        case traceId = "trace_id"
        case spanId = "span_id"
        case parentSpanId = "parent_span_id"
        case operationName = "operation_name"
        case serviceName = "service_name"
        case startTimeNanos = "start_time_nanos"
        case endTimeNanos = "end_time_nanos"
        case durationNanos = "duration_nanos"
        case statusCode = "status_code"
        case statusMessage = "status_message"
        case kind = "kind"
        case attributes = "attributes"
        case events = "events"
        case links = "links"
        case resourceAttributes = "resource_attributes"
        case scopeName = "scope_name"
        case scopeVersion = "scope_version"
        case scopeAttributes = "scope_attributes"
        case createdAt = "created_at"
    }
}

extension StoredMetric: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "metrics"
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let collectorName = Column(CodingKeys.collectorName)
        static let metricName = Column(CodingKeys.metricName)
        static let description = Column(CodingKeys.description)
        static let unit = Column(CodingKeys.unit)
        static let type = Column(CodingKeys.type)
        static let serviceName = Column(CodingKeys.serviceName)
        static let timestampNanos = Column(CodingKeys.timestampNanos)
        static let value = Column(CodingKeys.value)
        static let attributes = Column(CodingKeys.attributes)
        static let resourceAttributes = Column(CodingKeys.resourceAttributes)
        static let scopeName = Column(CodingKeys.scopeName)
        static let scopeVersion = Column(CodingKeys.scopeVersion)
        static let scopeAttributes = Column(CodingKeys.scopeAttributes)
        static let createdAt = Column(CodingKeys.createdAt)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case collectorName = "collector_name"
        case metricName = "metric_name"
        case description = "description"
        case unit = "unit"
        case type = "type"
        case serviceName = "service_name"
        case timestampNanos = "timestamp_nanos"
        case value = "value"
        case attributes = "attributes"
        case resourceAttributes = "resource_attributes"
        case scopeName = "scope_name"
        case scopeVersion = "scope_version"
        case scopeAttributes = "scope_attributes"
        case createdAt = "created_at"
    }
}

extension StoredLog: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "logs"
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let collectorName = Column(CodingKeys.collectorName)
        static let timestampNanos = Column(CodingKeys.timestampNanos)
        static let severityText = Column(CodingKeys.severityText)
        static let severityNumber = Column(CodingKeys.severityNumber)
        static let body = Column(CodingKeys.body)
        static let serviceName = Column(CodingKeys.serviceName)
        static let traceId = Column(CodingKeys.traceId)
        static let spanId = Column(CodingKeys.spanId)
        static let attributes = Column(CodingKeys.attributes)
        static let resourceAttributes = Column(CodingKeys.resourceAttributes)
        static let scopeName = Column(CodingKeys.scopeName)
        static let scopeVersion = Column(CodingKeys.scopeVersion)
        static let scopeAttributes = Column(CodingKeys.scopeAttributes)
        static let createdAt = Column(CodingKeys.createdAt)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case collectorName = "collector_name"
        case timestampNanos = "timestamp_nanos"
        case severityText = "severity_text"
        case severityNumber = "severity_number"
        case body = "body"
        case serviceName = "service_name"
        case traceId = "trace_id"
        case spanId = "span_id"
        case attributes = "attributes"
        case resourceAttributes = "resource_attributes"
        case scopeName = "scope_name"
        case scopeVersion = "scope_version"
        case scopeAttributes = "scope_attributes"
        case createdAt = "created_at"
    }
}

// MARK: - Helper Types

/// OTLP Span Status codes
enum SpanStatusCode: Int, Sendable {
    case unset = 0
    case ok = 1
    case error = 2
}

/// OTLP Span Kinds
enum SpanKind: Int, Sendable {
    case unspecified = 0
    case `internal` = 1
    case server = 2
    case client = 3
    case producer = 4
    case consumer = 5
}

/// OTLP Log Severity Numbers (based on SysLog)
enum LogSeverityNumber: Int, Sendable {
    case unspecified = 0
    case trace = 1
    case trace2 = 2
    case trace3 = 3
    case trace4 = 4
    case debug = 5
    case debug2 = 6
    case debug3 = 7
    case debug4 = 8
    case info = 9
    case info2 = 10
    case info3 = 11
    case info4 = 12
    case warn = 13
    case warn2 = 14
    case warn3 = 15
    case warn4 = 16
    case error = 17
    case error2 = 18
    case error3 = 19
    case error4 = 20
    case fatal = 21
    case fatal2 = 22
    case fatal3 = 23
    case fatal4 = 24
}