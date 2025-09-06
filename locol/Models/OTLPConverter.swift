import Foundation
import SwiftProtobuf
import GRDB

/// Pure functions for converting OTLP protocol types to database storage types
/// Handles proper attribute flattening and type conversion
enum OTLPConverter {
    
    // MARK: - Span Conversion
    
    /// Convert OTLP Span to StoredSpan with resource and scope attributes flattened
    static func convertSpan(
        _ span: Opentelemetry_Proto_Trace_V1_Span,
        resource: Opentelemetry_Proto_Resource_V1_Resource,
        scope: Opentelemetry_Proto_Common_V1_InstrumentationScope,
        collectorName: String
    ) -> StoredSpan {
        let startTime = timestampToNanos(span.startTimeUnixNano)
        let endTime = timestampToNanos(span.endTimeUnixNano)
        let duration = endTime - startTime
        
        return StoredSpan(
            collectorName: collectorName,
            traceId: span.traceID.hexString,
            spanId: span.spanID.hexString,
            parentSpanId: span.parentSpanID.isEmpty ? nil : span.parentSpanID.hexString,
            operationName: span.name,
            serviceName: extractServiceName(from: resource),
            startTimeNanos: startTime,
            endTimeNanos: endTime,
            durationNanos: duration,
            statusCode: Int(span.status.code.rawValue),
            statusMessage: span.status.message.isEmpty ? nil : span.status.message,
            kind: Int(span.kind.rawValue),
            attributes: convertAttributes(span.attributes),
            events: convertEvents(span.events),
            links: convertLinks(span.links),
            resourceAttributes: convertAttributes(resource.attributes),
            scopeName: scope.name.isEmpty ? nil : scope.name,
            scopeVersion: scope.version.isEmpty ? nil : scope.version,
            scopeAttributes: convertAttributes(scope.attributes)
        )
    }
    
    // MARK: - Metric Conversion
    
    /// Convert OTLP Metric to array of StoredMetrics (one per data point)
    static func convertMetric(
        _ metric: Opentelemetry_Proto_Metrics_V1_Metric,
        resource: Opentelemetry_Proto_Resource_V1_Resource,
        scope: Opentelemetry_Proto_Common_V1_InstrumentationScope,
        collectorName: String
    ) -> [StoredMetric] {
        let resourceAttrs = convertAttributes(resource.attributes)
        let scopeName = scope.name.isEmpty ? nil : scope.name
        let scopeVersion = scope.version.isEmpty ? nil : scope.version
        let scopeAttrs = convertAttributes(scope.attributes)
        let serviceName = extractServiceName(from: resource)
        let description = metric.description_p.isEmpty ? nil : metric.description_p
        let unit = metric.unit.isEmpty ? nil : metric.unit
        
        var storedMetrics: [StoredMetric] = []
        
        // Handle different metric types
        switch metric.data {
        case .gauge(let gauge):
            for dataPoint in gauge.dataPoints {
                storedMetrics.append(StoredMetric(
                    collectorName: collectorName,
                    metricName: metric.name,
                    description: description,
                    unit: unit,
                    type: "gauge",
                    serviceName: serviceName,
                    timestampNanos: timestampToNanos(dataPoint.timeUnixNano),
                    value: extractNumericValue(from: dataPoint),
                    attributes: convertAttributes(dataPoint.attributes),
                    resourceAttributes: resourceAttrs,
                    scopeName: scopeName,
                    scopeVersion: scopeVersion,
                    scopeAttributes: scopeAttrs
                ))
            }
            
        case .sum(let sum):
            for dataPoint in sum.dataPoints {
                storedMetrics.append(StoredMetric(
                    collectorName: collectorName,
                    metricName: metric.name,
                    description: description,
                    unit: unit,
                    type: sum.isMonotonic ? "counter" : "sum",
                    serviceName: serviceName,
                    timestampNanos: timestampToNanos(dataPoint.timeUnixNano),
                    value: extractNumericValue(from: dataPoint),
                    attributes: convertAttributes(dataPoint.attributes),
                    resourceAttributes: resourceAttrs,
                    scopeName: scopeName,
                    scopeVersion: scopeVersion,
                    scopeAttributes: scopeAttrs
                ))
            }
            
        case .histogram(let histogram):
            for dataPoint in histogram.dataPoints {
                storedMetrics.append(StoredMetric(
                    collectorName: collectorName,
                    metricName: metric.name,
                    description: description,
                    unit: unit,
                    type: "histogram",
                    serviceName: serviceName,
                    timestampNanos: timestampToNanos(dataPoint.timeUnixNano),
                    value: dataPoint.sum,
                    attributes: convertAttributes(dataPoint.attributes),
                    resourceAttributes: resourceAttrs,
                    scopeName: scopeName,
                    scopeVersion: scopeVersion,
                    scopeAttributes: scopeAttrs
                ))
            }
            
        case .exponentialHistogram(let expHistogram):
            for dataPoint in expHistogram.dataPoints {
                storedMetrics.append(StoredMetric(
                    collectorName: collectorName,
                    metricName: metric.name,
                    description: description,
                    unit: unit,
                    type: "exponential_histogram",
                    serviceName: serviceName,
                    timestampNanos: timestampToNanos(dataPoint.timeUnixNano),
                    value: dataPoint.sum,
                    attributes: convertAttributes(dataPoint.attributes),
                    resourceAttributes: resourceAttrs,
                    scopeName: scopeName,
                    scopeVersion: scopeVersion,
                    scopeAttributes: scopeAttrs
                ))
            }
            
        case .summary(let summary):
            for dataPoint in summary.dataPoints {
                storedMetrics.append(StoredMetric(
                    collectorName: collectorName,
                    metricName: metric.name,
                    description: description,
                    unit: unit,
                    type: "summary",
                    serviceName: serviceName,
                    timestampNanos: timestampToNanos(dataPoint.timeUnixNano),
                    value: dataPoint.sum,
                    attributes: convertAttributes(dataPoint.attributes),
                    resourceAttributes: resourceAttrs,
                    scopeName: scopeName,
                    scopeVersion: scopeVersion,
                    scopeAttributes: scopeAttrs
                ))
            }
            
        case nil:
            // Metric without data
            break
        }
        
        return storedMetrics
    }
    
    // MARK: - Log Conversion
    
    /// Convert OTLP LogRecord to StoredLog with resource and scope attributes flattened
    static func convertLog(
        _ logRecord: Opentelemetry_Proto_Logs_V1_LogRecord,
        resource: Opentelemetry_Proto_Resource_V1_Resource,
        scope: Opentelemetry_Proto_Common_V1_InstrumentationScope,
        collectorName: String
    ) -> StoredLog {
        return StoredLog(
            collectorName: collectorName,
            timestampNanos: timestampToNanos(logRecord.timeUnixNano),
            severityText: logRecord.severityText.isEmpty ? nil : logRecord.severityText,
            severityNumber: logRecord.severityNumber == Opentelemetry_Proto_Logs_V1_SeverityNumber.unspecified ? nil : Int(logRecord.severityNumber.rawValue),
            body: extractLogBody(from: logRecord.body),
            serviceName: extractServiceName(from: resource),
            traceId: logRecord.traceID.isEmpty ? nil : logRecord.traceID.hexString,
            spanId: logRecord.spanID.isEmpty ? nil : logRecord.spanID.hexString,
            attributes: convertAttributes(logRecord.attributes),
            resourceAttributes: convertAttributes(resource.attributes),
            scopeName: scope.name.isEmpty ? nil : scope.name,
            scopeVersion: scope.version.isEmpty ? nil : scope.version,
            scopeAttributes: convertAttributes(scope.attributes)
        )
    }
    
    // MARK: - Helper Functions
    
    private static func timestampToNanos(_ timestamp: UInt64) -> Int64 {
        // OTLP timestamps are already in nanoseconds since Unix epoch
        return Int64(timestamp)
    }
    
    private static func extractServiceName(from resource: Opentelemetry_Proto_Resource_V1_Resource) -> String? {
        for attribute in resource.attributes {
            if attribute.key == "service.name" {
                switch attribute.value.value {
                case .stringValue(let value):
                    return value.isEmpty ? nil : value
                default:
                    break
                }
            }
        }
        return nil
    }
    
    private static func extractLogBody(from body: Opentelemetry_Proto_Common_V1_AnyValue) -> String? {
        switch body.value {
        case .stringValue(let value):
            return value.isEmpty ? nil : value
        case .intValue(let value):
            return String(value)
        case .doubleValue(let value):
            return String(value)
        case .boolValue(let value):
            return String(value)
        case .bytesValue(let data):
            return String(data: data, encoding: .utf8)
        case .arrayValue(let array):
            let values = array.values.map { convertAnyValueToJSON($0) }
            return "[\(values.joined(separator: ", "))]"
        case .kvlistValue(let kvlist):
            let pairs = kvlist.values.map { "\($0.key): \(convertAnyValueToJSON($0.value))" }
            return "{\(pairs.joined(separator: ", "))}"
        case nil:
            return nil
        }
    }
    
    private static func extractNumericValue(from dataPoint: Opentelemetry_Proto_Metrics_V1_NumberDataPoint) -> Double? {
        switch dataPoint.value {
        case .asDouble(let value):
            return value
        case .asInt(let value):
            return Double(value)
        case nil:
            return nil
        }
    }
    
    private static func convertAttributes(_ attributes: [Opentelemetry_Proto_Common_V1_KeyValue]) -> [String: Any] {
        var result: [String: Any] = [:]
        for attribute in attributes {
            result[attribute.key] = convertAnyValue(attribute.value)
        }
        return result
    }
    
    private static func convertAnyValue(_ value: Opentelemetry_Proto_Common_V1_AnyValue) -> Any {
        switch value.value {
        case .stringValue(let val):
            return val
        case .boolValue(let val):
            return val
        case .intValue(let val):
            return val
        case .doubleValue(let val):
            return val
        case .bytesValue(let data):
            return data.base64EncodedString()
        case .arrayValue(let array):
            return array.values.map { convertAnyValue($0) }
        case .kvlistValue(let kvlist):
            var dict: [String: Any] = [:]
            for kv in kvlist.values {
                dict[kv.key] = convertAnyValue(kv.value)
            }
            return dict
        case nil:
            return NSNull()
        }
    }
    
    private static func convertAnyValueToJSON(_ value: Opentelemetry_Proto_Common_V1_AnyValue) -> String {
        switch value.value {
        case .stringValue(let val):
            return "\"\(val)\""
        case .boolValue(let val):
            return String(val)
        case .intValue(let val):
            return String(val)
        case .doubleValue(let val):
            return String(val)
        case .bytesValue(let data):
            return "\"\(data.base64EncodedString())\""
        case .arrayValue(let array):
            let values = array.values.map { convertAnyValueToJSON($0) }
            return "[\(values.joined(separator: ", "))]"
        case .kvlistValue(let kvlist):
            let pairs = kvlist.values.map { "\"\($0.key)\": \(convertAnyValueToJSON($0.value))" }
            return "{\(pairs.joined(separator: ", "))}"
        case nil:
            return "null"
        }
    }
    
    private static func convertEvents(_ events: [Opentelemetry_Proto_Trace_V1_Span.Event]) -> [[String: Any]] {
        return events.map { event in
            var eventDict: [String: Any] = [
                "time_unix_nano": event.timeUnixNano,
                "name": event.name
            ]
            
            if !event.attributes.isEmpty {
                eventDict["attributes"] = convertAttributes(event.attributes)
            }
            
            if event.droppedAttributesCount > 0 {
                eventDict["dropped_attributes_count"] = event.droppedAttributesCount
            }
            
            return eventDict
        }
    }
    
    private static func convertLinks(_ links: [Opentelemetry_Proto_Trace_V1_Span.Link]) -> [[String: Any]] {
        return links.map { link in
            var linkDict: [String: Any] = [
                "trace_id": link.traceID.hexString,
                "span_id": link.spanID.hexString
            ]
            
            if !link.traceState.isEmpty {
                linkDict["trace_state"] = link.traceState
            }
            
            if !link.attributes.isEmpty {
                linkDict["attributes"] = convertAttributes(link.attributes)
            }
            
            if link.droppedAttributesCount > 0 {
                linkDict["dropped_attributes_count"] = link.droppedAttributesCount
            }
            
            return linkDict
        }
    }
}

// MARK: - Data Extension for Hex String

private extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}