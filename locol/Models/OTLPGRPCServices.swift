import Foundation
import GRPCCore
import GRPCProtobuf
import SwiftProtobuf
import GRDB
import os

// MARK: - OTLP Trace Service Implementation

@available(macOS 15.0, *)
struct OTLPTraceService: Opentelemetry_Proto_Collector_Trace_V1_TraceService.ServiceProtocol, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.locol.otlp", category: "TraceService")
    private let receiver: OTLPGRPCReceiver
    private let telemetryDB = TelemetryDatabase.shared
    
    init(receiver: OTLPGRPCReceiver) {
        self.receiver = receiver
    }
    
    func export(
        request: ServerRequest<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse> {
        let message = request.message
        logger.info("Received trace export request with \(message.resourceSpans.count) resource spans")
        
        // Try to identify the collector from gRPC metadata and request
        let collectorName = extractCollectorName(from: request, context: context) ?? "unknown"
        
        var spans: [TelemetrySpan] = []
        var totalSpans = 0
        
        // Convert OTLP spans to our model
        for resourceSpan in message.resourceSpans {
            let resource = convertResource(resourceSpan.resource)
            
            for scopeSpan in resourceSpan.scopeSpans {
                for span in scopeSpan.spans {
                    let telemetrySpan = convertSpan(span, resource: resource)
                    spans.append(telemetrySpan)
                    totalSpans += 1
                }
            }
        }
        
        logger.info("Processing \(totalSpans) spans for collector: \(collectorName)")
        
        // Store spans in database
        var rejectedSpans = 0
        let localSpans = spans // Capture immutable copy for concurrent access
        do {
            try await telemetryDB.asyncWrite(for: collectorName) { db in
                for span in localSpans {
                    try span.insert(db)
                }
            }
            logger.debug("Successfully stored \(localSpans.count) spans")
        } catch {
            logger.error("Failed to store spans: \(error)")
            rejectedSpans = localSpans.count
        }
        
        // Update receiver statistics
        await receiver.incrementTracesCount(by: totalSpans - rejectedSpans)
        
        // Create successful response
        var response = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse()
        response.partialSuccess = Opentelemetry_Proto_Collector_Trace_V1_ExportTracePartialSuccess()
        response.partialSuccess.rejectedSpans = Int64(rejectedSpans)
        response.partialSuccess.errorMessage = rejectedSpans > 0 ? "Database storage error" : ""
        
        return ServerResponse(message: response)
    }
    
    private func extractCollectorName(from request: ServerRequest<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest>, context: ServerContext) -> String? {
        // First, try to identify the collector from gRPC metadata
        if let collectorName = identifyCollectorFromMetadata(request: request) {
            return collectorName
        }
        
        // Fallback: Extract service.name from telemetry data
        for resourceSpan in request.message.resourceSpans {
            let resource = resourceSpan.resource
            for attribute in resource.attributes {
                if attribute.key == "service.name" {
                    switch attribute.value.value {
                    case .stringValue(let stringValue):
                        return stringValue
                    default:
                        break
                    }
                }
            }
        }
        return "default"
    }
    
    private func identifyCollectorFromMetadata(request: ServerRequest<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest>) -> String? {
        // Check gRPC metadata for our custom collector-name header
        for (key, value) in request.metadata {
            if key.lowercased() == "collector-name" {
                // Convert metadata value to string
                let stringValue = String(describing: value)
                if !stringValue.isEmpty {
                    logger.debug("Found collector name in metadata: \(stringValue)")
                    return stringValue
                }
            }
        }
        
        return nil
    }
    
    private func mapPeerToCollector(_ peer: String) -> String? {
        // This would require tracking which collectors are running and their connection details
        // For now, let's see what peer information we get
        logger.debug("Attempting to map peer '\(peer)' to collector")
        
        // If there's only one running collector, we can assume it's that one
        let collectorsDir = CollectorFileManager.shared.baseDirectory.appendingPathComponent("collectors")
        
        do {
            let collectorNames = try FileManager.default.contentsOfDirectory(atPath: collectorsDir.path)
            if collectorNames.count == 1 {
                logger.debug("Only one collector directory found: \(collectorNames.first!)")
                return collectorNames.first!
            }
        } catch {
            logger.error("Failed to scan collectors directory: \(error)")
        }
        
        return nil
    }
    
    private func convertResource(_ resource: Opentelemetry_Proto_Resource_V1_Resource) -> [String: AttributeValue] {
        var attributes: [String: AttributeValue] = [:]
        for attribute in resource.attributes {
            attributes[attribute.key] = convertAttributeValue(attribute.value)
        }
        return attributes
    }
    
    private func convertSpan(_ span: Opentelemetry_Proto_Trace_V1_Span, resource: [String: AttributeValue]) -> TelemetrySpan {
        let spanId = Data(span.spanID).map { String(format: "%02x", $0) }.joined()
        let traceId = Data(span.traceID).map { String(format: "%02x", $0) }.joined()
        let parentSpanId = span.parentSpanID.isEmpty ? nil : Data(span.parentSpanID).map { String(format: "%02x", $0) }.joined()
        
        // Extract service name from resource
        let serviceName = resource["service.name"]?.stringValue
        
        // Convert attributes
        var attributes: [String: AttributeValue] = [:]
        for attribute in span.attributes {
            attributes[attribute.key] = convertAttributeValue(attribute.value)
        }
        
        // Convert events
        let events = span.events.map { event in
            var eventAttributes: [String: AttributeValue] = [:]
            for attribute in event.attributes {
                eventAttributes[attribute.key] = convertAttributeValue(attribute.value)
            }
            return SpanEvent(
                name: event.name,
                timestamp: Int64(event.timeUnixNano),
                attributes: eventAttributes
            )
        }
        
        // Convert links
        let links = span.links.map { link in
            var linkAttributes: [String: AttributeValue] = [:]
            for attribute in link.attributes {
                linkAttributes[attribute.key] = convertAttributeValue(attribute.value)
            }
            return SpanLink(
                traceId: Data(link.traceID).map { String(format: "%02x", $0) }.joined(),
                spanId: Data(link.spanID).map { String(format: "%02x", $0) }.joined(),
                attributes: linkAttributes
            )
        }
        
        let startTime = Int64(span.startTimeUnixNano)
        let endTime = Int64(span.endTimeUnixNano)
        
        return TelemetrySpan(
            spanId: spanId,
            traceId: traceId,
            parentSpanId: parentSpanId,
            serviceName: serviceName,
            operationName: span.name,
            startTime: startTime,
            endTime: endTime,
            duration: endTime - startTime,
            statusCode: Int32(span.status.code.rawValue),
            statusMessage: span.status.message.isEmpty ? nil : span.status.message,
            attributes: attributes,
            events: events,
            links: links,
            createdAt: Int64(Date().timeIntervalSince1970)
        )
    }
}

// MARK: - OTLP Metrics Service Implementation

@available(macOS 15.0, *)
struct OTLPMetricsService: Opentelemetry_Proto_Collector_Metrics_V1_MetricsService.ServiceProtocol, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.locol.otlp", category: "MetricsService")
    private let receiver: OTLPGRPCReceiver
    private let telemetryDB = TelemetryDatabase.shared
    
    init(receiver: OTLPGRPCReceiver) {
        self.receiver = receiver
    }
    
    func export(
        request: ServerRequest<Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse> {
        let message = request.message
        logger.info("Received metrics export request with \(message.resourceMetrics.count) resource metrics")
        
        // Try to identify the collector from gRPC metadata and request
        let collectorName = extractCollectorName(from: request, context: context) ?? "unknown"
        
        var metrics: [TelemetryMetric] = []
        var totalDataPoints = 0
        
        // Convert OTLP metrics to our model
        for resourceMetric in message.resourceMetrics {
            let resource = convertResource(resourceMetric.resource)
            
            for scopeMetric in resourceMetric.scopeMetrics {
                for metric in scopeMetric.metrics {
                    let telemetryMetrics = convertMetric(metric, resource: resource)
                    metrics.append(contentsOf: telemetryMetrics)
                    totalDataPoints += telemetryMetrics.count
                }
            }
        }
        
        logger.info("Processing \(totalDataPoints) data points for collector: \(collectorName)")
        
        // Store metrics in database
        var rejectedDataPoints = 0
        let localMetrics = metrics // Capture immutable copy for concurrent access
        do {
            try await telemetryDB.asyncWrite(for: collectorName) { db in
                for metric in localMetrics {
                    try metric.insert(db)
                }
            }
            logger.debug("Successfully stored \(localMetrics.count) metrics")
        } catch {
            logger.error("Failed to store metrics: \(error)")
            rejectedDataPoints = localMetrics.count
        }
        
        // Update receiver statistics
        await receiver.incrementMetricsCount(by: totalDataPoints - rejectedDataPoints)
        
        // Create successful response
        var response = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse()
        response.partialSuccess = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsPartialSuccess()
        response.partialSuccess.rejectedDataPoints = Int64(rejectedDataPoints)
        response.partialSuccess.errorMessage = rejectedDataPoints > 0 ? "Database storage error" : ""
        
        return ServerResponse(message: response)
    }
    
    private func extractCollectorName(from request: ServerRequest<Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest>, context: ServerContext) -> String? {
        // First, try to identify the collector from gRPC metadata
        if let collectorName = identifyCollectorFromMetadata(request: request) {
            return collectorName
        }
        
        // Fallback: Extract service.name from telemetry data
        for resourceMetric in request.message.resourceMetrics {
            let resource = resourceMetric.resource
            for attribute in resource.attributes {
                if attribute.key == "service.name" {
                    switch attribute.value.value {
                    case .stringValue(let stringValue):
                        return stringValue
                    default:
                        break
                    }
                }
            }
        }
        return "default"
    }
    
    private func identifyCollectorFromMetadata(request: ServerRequest<Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest>) -> String? {
        // Check gRPC metadata for our custom collector-name header
        for (key, value) in request.metadata {
            if key.lowercased() == "collector-name" {
                // Convert metadata value to string
                let stringValue = String(describing: value)
                if !stringValue.isEmpty {
                    logger.debug("Found collector name in metadata: \(stringValue)")
                    return stringValue
                }
            }
        }
        
        return nil
    }
    
    private func convertResource(_ resource: Opentelemetry_Proto_Resource_V1_Resource) -> [String: AttributeValue] {
        var attributes: [String: AttributeValue] = [:]
        for attribute in resource.attributes {
            attributes[attribute.key] = convertAttributeValue(attribute.value)
        }
        return attributes
    }
    
    private func convertMetric(_ metric: Opentelemetry_Proto_Metrics_V1_Metric, resource: [String: AttributeValue]) -> [TelemetryMetric] {
        var results: [TelemetryMetric] = []
        let createdAt = Int64(Date().timeIntervalSince1970)
        
        // Handle different metric types
        switch metric.data {
        case .gauge(let gauge):
            for dataPoint in gauge.dataPoints {
                var labels: [String: String] = [:]
                for attribute in dataPoint.attributes {
                    switch attribute.value.value {
                    case .stringValue(let stringValue):
                        labels[attribute.key] = stringValue
                    case .intValue(let intValue):
                        labels[attribute.key] = "\(intValue)"
                    case .doubleValue(let doubleValue):
                        labels[attribute.key] = "\(doubleValue)"
                    case .boolValue(let boolValue):
                        labels[attribute.key] = "\(boolValue)"
                    default:
                        break
                    }
                }
                
                let value = switch dataPoint.value {
                case .asDouble(let doubleValue): doubleValue
                case .asInt(let intValue): Double(intValue)
                default: 0.0
                }
                
                results.append(TelemetryMetric(
                    id: nil,
                    name: metric.name,
                    type: .gauge,
                    timestamp: Int64(dataPoint.timeUnixNano),
                    value: value,
                    labels: labels,
                    exemplars: [],
                    bucketCounts: nil,
                    bucketBounds: nil,
                    sum: nil,
                    count: nil,
                    createdAt: createdAt
                ))
            }
        case .sum(let sum):
            for dataPoint in sum.dataPoints {
                var labels: [String: String] = [:]
                for attribute in dataPoint.attributes {
                    switch attribute.value.value {
                    case .stringValue(let stringValue):
                        labels[attribute.key] = stringValue
                    case .intValue(let intValue):
                        labels[attribute.key] = "\(intValue)"
                    case .doubleValue(let doubleValue):
                        labels[attribute.key] = "\(doubleValue)"
                    case .boolValue(let boolValue):
                        labels[attribute.key] = "\(boolValue)"
                    default:
                        break
                    }
                }
                
                let value = switch dataPoint.value {
                case .asDouble(let doubleValue): doubleValue
                case .asInt(let intValue): Double(intValue)
                default: 0.0
                }
                
                results.append(TelemetryMetric(
                    id: nil,
                    name: metric.name,
                    type: .counter,
                    timestamp: Int64(dataPoint.timeUnixNano),
                    value: value,
                    labels: labels,
                    exemplars: [],
                    bucketCounts: nil,
                    bucketBounds: nil,
                    sum: nil,
                    count: nil,
                    createdAt: createdAt
                ))
            }
        case .histogram(let histogram):
            for dataPoint in histogram.dataPoints {
                var labels: [String: String] = [:]
                for attribute in dataPoint.attributes {
                    switch attribute.value.value {
                    case .stringValue(let stringValue):
                        labels[attribute.key] = stringValue
                    case .intValue(let intValue):
                        labels[attribute.key] = "\(intValue)"
                    case .doubleValue(let doubleValue):
                        labels[attribute.key] = "\(doubleValue)"
                    case .boolValue(let boolValue):
                        labels[attribute.key] = "\(boolValue)"
                    default:
                        break
                    }
                }
                
                results.append(TelemetryMetric(
                    id: nil,
                    name: metric.name,
                    type: .histogram,
                    timestamp: Int64(dataPoint.timeUnixNano),
                    value: nil,
                    labels: labels,
                    exemplars: [],
                    bucketCounts: dataPoint.bucketCounts.map { Int64($0) },
                    bucketBounds: dataPoint.explicitBounds,
                    sum: dataPoint.sum,
                    count: Int64(dataPoint.count),
                    createdAt: createdAt
                ))
            }
        default:
            // Skip unknown metric types
            break
        }
        
        return results
    }
}

// MARK: - OTLP Logs Service Implementation

@available(macOS 15.0, *)
struct OTLPLogsService: Opentelemetry_Proto_Collector_Logs_V1_LogsService.ServiceProtocol, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.locol.otlp", category: "LogsService")
    private let receiver: OTLPGRPCReceiver
    private let telemetryDB = TelemetryDatabase.shared
    
    init(receiver: OTLPGRPCReceiver) {
        self.receiver = receiver
    }
    
    func export(
        request: ServerRequest<Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse> {
        let message = request.message
        logger.info("Received logs export request with \(message.resourceLogs.count) resource logs")
        
        // Try to identify the collector from gRPC metadata and request
        let collectorName = extractCollectorName(from: request, context: context) ?? "unknown"
        
        var logs: [TelemetryLog] = []
        var totalLogRecords = 0
        
        // Convert OTLP logs to our model
        for resourceLog in message.resourceLogs {
            let resource = convertResource(resourceLog.resource)
            
            for scopeLog in resourceLog.scopeLogs {
                for logRecord in scopeLog.logRecords {
                    let telemetryLog = convertLogRecord(logRecord, resource: resource)
                    logs.append(telemetryLog)
                    totalLogRecords += 1
                }
            }
        }
        
        logger.info("Processing \(totalLogRecords) log records for collector: \(collectorName)")
        
        // Store logs in database
        var rejectedLogRecords = 0
        let localLogs = logs // Capture immutable copy for concurrent access
        do {
            try await telemetryDB.asyncWrite(for: collectorName) { db in
                for log in localLogs {
                    try log.insert(db)
                }
            }
            logger.debug("Successfully stored \(localLogs.count) logs")
        } catch {
            logger.error("Failed to store logs: \(error)")
            rejectedLogRecords = localLogs.count
        }
        
        // Update receiver statistics
        await receiver.incrementLogsCount(by: totalLogRecords - rejectedLogRecords)
        
        // Create successful response
        var response = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse()
        response.partialSuccess = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsPartialSuccess()
        response.partialSuccess.rejectedLogRecords = Int64(rejectedLogRecords)
        response.partialSuccess.errorMessage = rejectedLogRecords > 0 ? "Database storage error" : ""
        
        return ServerResponse(message: response)
    }
    
    private func extractCollectorName(from request: ServerRequest<Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest>, context: ServerContext) -> String? {
        // First, try to identify the collector from gRPC metadata
        if let collectorName = identifyCollectorFromMetadata(request: request) {
            return collectorName
        }
        
        // Fallback: Extract service.name from telemetry data
        for resourceLog in request.message.resourceLogs {
            let resource = resourceLog.resource
            for attribute in resource.attributes {
                if attribute.key == "service.name" {
                    switch attribute.value.value {
                    case .stringValue(let stringValue):
                        return stringValue
                    default:
                        break
                    }
                }
            }
        }
        return "default"
    }
    
    private func identifyCollectorFromMetadata(request: ServerRequest<Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest>) -> String? {
        // Check gRPC metadata for our custom collector-name header
        for (key, value) in request.metadata {
            if key.lowercased() == "collector-name" {
                // Convert metadata value to string
                let stringValue = String(describing: value)
                if !stringValue.isEmpty {
                    logger.debug("Found collector name in metadata: \(stringValue)")
                    return stringValue
                }
            }
        }
        
        return nil
    }
    
    private func convertResource(_ resource: Opentelemetry_Proto_Resource_V1_Resource) -> [String: AttributeValue] {
        var attributes: [String: AttributeValue] = [:]
        for attribute in resource.attributes {
            attributes[attribute.key] = convertAttributeValue(attribute.value)
        }
        return attributes
    }
    
    private func convertLogRecord(_ logRecord: Opentelemetry_Proto_Logs_V1_LogRecord, resource: [String: AttributeValue]) -> TelemetryLog {
        // Convert attributes
        var attributes: [String: AttributeValue] = [:]
        for attribute in logRecord.attributes {
            attributes[attribute.key] = convertAttributeValue(attribute.value)
        }
        
        // Extract trace/span IDs
        let traceId = logRecord.traceID.isEmpty ? nil : Data(logRecord.traceID).map { String(format: "%02x", $0) }.joined()
        let spanId = logRecord.spanID.isEmpty ? nil : Data(logRecord.spanID).map { String(format: "%02x", $0) }.joined()
        
        // Extract log body
        let body = convertLogBody(logRecord.body)
        
        return TelemetryLog(
            id: nil,
            timestamp: Int64(logRecord.timeUnixNano),
            severityNumber: Int32(logRecord.severityNumber.rawValue),
            severityText: logRecord.severityText.isEmpty ? nil : logRecord.severityText,
            body: body,
            attributes: attributes,
            resource: resource,
            traceId: traceId,
            spanId: spanId,
            createdAt: Int64(Date().timeIntervalSince1970)
        )
    }
    
    private func convertLogBody(_ body: Opentelemetry_Proto_Common_V1_AnyValue) -> String {
        switch body.value {
        case .stringValue(let stringValue):
            return stringValue
        case .intValue(let intValue):
            return String(intValue)
        case .doubleValue(let doubleValue):
            return String(doubleValue)
        case .boolValue(let boolValue):
            return String(boolValue)
        default:
            return ""
        }
    }
}

// MARK: - Shared Helper Functions

/// Converts an OTLP AnyValue to our AttributeValue model
func convertAttributeValue(_ value: Opentelemetry_Proto_Common_V1_AnyValue) -> AttributeValue {
    switch value.value {
    case .stringValue(let stringValue):
        return AttributeValue(
            stringValue: stringValue,
            intValue: nil,
            doubleValue: nil,
            boolValue: nil,
            arrayValue: nil,
            kvlistValue: nil
        )
    case .intValue(let intValue):
        return AttributeValue(
            stringValue: nil,
            intValue: intValue,
            doubleValue: nil,
            boolValue: nil,
            arrayValue: nil,
            kvlistValue: nil
        )
    case .doubleValue(let doubleValue):
        return AttributeValue(
            stringValue: nil,
            intValue: nil,
            doubleValue: doubleValue,
            boolValue: nil,
            arrayValue: nil,
            kvlistValue: nil
        )
    case .boolValue(let boolValue):
        return AttributeValue(
            stringValue: nil,
            intValue: nil,
            doubleValue: nil,
            boolValue: boolValue,
            arrayValue: nil,
            kvlistValue: nil
        )
    case .arrayValue(let arrayValue):
        let arrayValues = arrayValue.values.map { convertAttributeValue($0) }
        return AttributeValue(
            stringValue: nil,
            intValue: nil,
            doubleValue: nil,
            boolValue: nil,
            arrayValue: arrayValues,
            kvlistValue: nil
        )
    case .kvlistValue(let kvlistValue):
        var kvlist: [String: AttributeValue] = [:]
        for kv in kvlistValue.values {
            kvlist[kv.key] = convertAttributeValue(kv.value)
        }
        return AttributeValue(
            stringValue: nil,
            intValue: nil,
            doubleValue: nil,
            boolValue: nil,
            arrayValue: nil,
            kvlistValue: kvlist
        )
    default:
        // Fallback for empty/unknown values
        return AttributeValue(
            stringValue: "",
            intValue: nil,
            doubleValue: nil,
            boolValue: nil,
            arrayValue: nil,
            kvlistValue: nil
        )
    }
}
