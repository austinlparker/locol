import Foundation
import GRPCCore
import GRPCProtobuf
import os

@available(macOS 15.0, *)
final class OTLPServices: Sendable {
    
    // MARK: - Trace Service Implementation
    
    struct TraceServiceImpl: Opentelemetry_Proto_Collector_Trace_V1_TraceService.ServiceProtocol, Sendable {
        private let logger = Logger.grpc
        private let storage = TelemetryStorage.shared
        
        func export(
            request: GRPCCore.ServerRequest<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest>,
            context: GRPCCore.ServerContext
        ) async throws -> GRPCCore.ServerResponse<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse> {
            
            let collectorName = extractCollectorName(from: request.metadata) ?? "unknown"
            logger.info("Received trace export request from collector: \(collectorName)")
            
            var totalSpans = 0
            var storedSpans: [StoredSpan] = []
            
            // Process all resource spans
            for resourceSpans in request.message.resourceSpans {
                let resource = resourceSpans.resource
                
                // Process all scope spans within this resource
                for scopeSpans in resourceSpans.scopeSpans {
                    let scope = scopeSpans.scope
                    
                    // Convert each span
                    for span in scopeSpans.spans {
                        let storedSpan = OTLPConverter.convertSpan(
                            span,
                            resource: resource,
                            scope: scope,
                            collectorName: collectorName
                        )
                        storedSpans.append(storedSpan)
                        totalSpans += 1
                    }
                }
            }
            
            // Store all spans in database
            if !storedSpans.isEmpty {
                try await storage.storeSpans(storedSpans)
                logger.debug("Stored \(storedSpans.count) spans from collector \(collectorName)")
            }
            
            // Return success response
            let response = Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse.with { response in
                // Optionally set partial success info
                response.partialSuccess = Opentelemetry_Proto_Collector_Trace_V1_ExportTracePartialSuccess.with { partialSuccess in
                    partialSuccess.rejectedSpans = 0
                    partialSuccess.errorMessage = ""
                }
            }
            
            return GRPCCore.ServerResponse(message: response)
        }
    }
    
    // MARK: - Metrics Service Implementation
    
    struct MetricsServiceImpl: Opentelemetry_Proto_Collector_Metrics_V1_MetricsService.ServiceProtocol, Sendable {
        private let logger = Logger.grpc
        private let storage = TelemetryStorage.shared
        
        func export(
            request: GRPCCore.ServerRequest<Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest>,
            context: GRPCCore.ServerContext
        ) async throws -> GRPCCore.ServerResponse<Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse> {
            
            let collectorName = extractCollectorName(from: request.metadata) ?? "unknown"
            logger.info("Received metrics export request from collector: \(collectorName)")
            
            var totalMetrics = 0
            var storedMetrics: [StoredMetric] = []
            
            // Process all resource metrics
            for resourceMetrics in request.message.resourceMetrics {
                let resource = resourceMetrics.resource
                
                // Process all scope metrics within this resource
                for scopeMetrics in resourceMetrics.scopeMetrics {
                    let scope = scopeMetrics.scope
                    
                    // Convert each metric (which may produce multiple stored metrics)
                    for metric in scopeMetrics.metrics {
                        let convertedMetrics = OTLPConverter.convertMetric(
                            metric,
                            resource: resource,
                            scope: scope,
                            collectorName: collectorName
                        )
                        storedMetrics.append(contentsOf: convertedMetrics)
                        totalMetrics += convertedMetrics.count
                    }
                }
            }
            
            // Store all metrics in database
            if !storedMetrics.isEmpty {
                try await storage.storeMetrics(storedMetrics)
                logger.debug("Stored \(storedMetrics.count) metrics from collector \(collectorName)")
            }
            
            // Return success response
            let response = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceResponse.with { response in
                // Optionally set partial success info
                response.partialSuccess = Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsPartialSuccess.with { partialSuccess in
                    partialSuccess.rejectedDataPoints = 0
                    partialSuccess.errorMessage = ""
                }
            }
            
            return GRPCCore.ServerResponse(message: response)
        }
    }
    
    // MARK: - Logs Service Implementation
    
    struct LogsServiceImpl: Opentelemetry_Proto_Collector_Logs_V1_LogsService.ServiceProtocol, Sendable {
        private let logger = Logger.grpc
        private let storage = TelemetryStorage.shared
        
        func export(
            request: GRPCCore.ServerRequest<Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest>,
            context: GRPCCore.ServerContext
        ) async throws -> GRPCCore.ServerResponse<Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse> {
            
            let collectorName = extractCollectorName(from: request.metadata) ?? "unknown"
            logger.info("Received logs export request from collector: \(collectorName)")
            
            var totalLogs = 0
            var storedLogs: [StoredLog] = []
            
            // Process all resource logs
            for resourceLogs in request.message.resourceLogs {
                let resource = resourceLogs.resource
                
                // Process all scope logs within this resource
                for scopeLogs in resourceLogs.scopeLogs {
                    let scope = scopeLogs.scope
                    
                    // Convert each log record
                    for logRecord in scopeLogs.logRecords {
                        let storedLog = OTLPConverter.convertLog(
                            logRecord,
                            resource: resource,
                            scope: scope,
                            collectorName: collectorName
                        )
                        storedLogs.append(storedLog)
                        totalLogs += 1
                    }
                }
            }
            
            // Store all logs in database
            if !storedLogs.isEmpty {
                try await storage.storeLogs(storedLogs)
                logger.debug("Stored \(storedLogs.count) logs from collector \(collectorName)")
            }
            
            // Return success response
            let response = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceResponse.with { response in
                // Optionally set partial success info
                response.partialSuccess = Opentelemetry_Proto_Collector_Logs_V1_ExportLogsPartialSuccess.with { partialSuccess in
                    partialSuccess.rejectedLogRecords = 0
                    partialSuccess.errorMessage = ""
                }
            }
            
            return GRPCCore.ServerResponse(message: response)
        }
    }
    
    // MARK: - Helper Functions
    
    /// Extract collector name from request metadata headers
    private static func extractCollectorName(from metadata: GRPCCore.Metadata) -> String? {
        // Look for collector-name header
        do {
            let collectorName = try metadata["collector-name"].first { _ in true }
            if let collectorName = collectorName {
                return String(describing: collectorName)
            }
        } catch {
            // Ignore metadata access errors
        }
        
        // Look for user-agent header and try to parse collector info
        do {
            let userAgent = try metadata["user-agent"].first { _ in true }
            if let userAgent = userAgent {
                let userAgentString = String(describing: userAgent)
                // Handle common patterns like "opentelemetry-collector/0.89.0" or custom names
                if userAgentString.contains("opentelemetry-collector") {
                    return "otelcol"
                } else if userAgentString.contains("collector") {
                    return "collector"
                }
                return userAgentString
            }
        } catch {
            // Ignore metadata access errors
        }
        
        return nil
    }
    
    // MARK: - Service Instances
    
    /// Get a configured TraceService instance as RegistrableRPCService
    static let traceService: any RegistrableRPCService = TraceServiceImpl()
    
    /// Get a configured MetricsService instance as RegistrableRPCService
    static let metricsService: any RegistrableRPCService = MetricsServiceImpl()
    
    /// Get a configured LogsService instance as RegistrableRPCService
    static let logsService: any RegistrableRPCService = LogsServiceImpl()
}