import Foundation
import GRPCCore
import GRPCProtobuf
import os

@available(macOS 15.0, *)
final class OTLPServices: Sendable {
    private let storage: TelemetryStorageProtocol
    private let server: OTLPServerProtocol
    
    init(storage: TelemetryStorageProtocol, server: OTLPServerProtocol) {
        self.storage = storage
        self.server = server
    }
    
    // MARK: - Trace Service Implementation
    
    struct TraceServiceImpl: Opentelemetry_Proto_Collector_Trace_V1_TraceService.ServiceProtocol, Sendable {
        private let logger = Logger.grpc
        private let storage: TelemetryStorageProtocol
        private let server: OTLPServerProtocol
        
        init(storage: TelemetryStorageProtocol, server: OTLPServerProtocol) {
            self.storage = storage
            self.server = server
        }
        
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
                
                // Update server statistics
                await server.incrementTraces(by: totalSpans)
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
        private let storage: TelemetryStorageProtocol
        private let server: OTLPServerProtocol
        
        init(storage: TelemetryStorageProtocol, server: OTLPServerProtocol) {
            self.storage = storage
            self.server = server
        }
        
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
                
                // Update server statistics
                await server.incrementMetrics(by: totalMetrics)
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
        private let storage: TelemetryStorageProtocol
        private let server: OTLPServerProtocol
        
        init(storage: TelemetryStorageProtocol, server: OTLPServerProtocol) {
            self.storage = storage
            self.server = server
        }
        
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
                
                // Update server statistics
                await server.incrementLogs(by: totalLogs)
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
        // Try explicit collector-name header
        if let first = metadata["collector-name"].first(where: { _ in true }) {
            return String(describing: first)
        }
        // Fallback to user-agent header
        if let ua = metadata["user-agent"].first(where: { _ in true }) {
            let userAgentString = String(describing: ua)
            if userAgentString.contains("opentelemetry-collector") { return "otelcol" }
            if userAgentString.contains("collector") { return "collector" }
            return userAgentString
        }
        return nil
    }
    
    // MARK: - Service Instances
    
    /// Get configured service instances as RegistrableRPCService
    var traceService: any RegistrableRPCService { TraceServiceImpl(storage: storage, server: server) }
    var metricsService: any RegistrableRPCService { MetricsServiceImpl(storage: storage, server: server) }
    var logsService: any RegistrableRPCService { LogsServiceImpl(storage: storage, server: server) }
}
