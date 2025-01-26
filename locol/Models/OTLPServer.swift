import Foundation
import FlyingFox
import SwiftProtobuf
import os

enum OTLPRequest {
    case traces(Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest)
    case metrics(Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest)
    case logs(Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest)
    case profiles(Opentelemetry_Proto_Collector_Profiles_V1development_ExportProfilesServiceRequest)
}

actor OTLPServer {
    private var httpServer: HTTPServer?
    private let port: UInt16
    private let protobufContentType = "application/x-protobuf"
    private var continuation: AsyncStream<OTLPRequest>.Continuation?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "OTLPServer")
    
    private(set) var isRunning: Bool = false {
        didSet {
            logger.info("OTLPServer isRunning changed to: \(self.isRunning)")
        }
    }
    var lastError: String?
    
    var requests: AsyncStream<OTLPRequest> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.stop()
                }
            }
        }
    }
    
    init(port: UInt16 = 9999) {
        self.port = port
        logger.info("OTLPServer initialized with port \(self.port)")
    }
    
    func start() async throws {
        logger.info("Starting OTLPServer on port \(self.port)...")
        
        // Create a new server instance
        let server = HTTPServer(port: port)
        
        // Set up routes
        await server.appendRoute("POST /v1/traces") { [weak self] (request: HTTPRequest) async throws -> HTTPResponse in
            guard let self else {
                return HTTPResponse(statusCode: .internalServerError)
            }
            
            return try await self.handleTraces(request)
        }
        
        await server.appendRoute("POST /v1/metrics") { [weak self] (request: HTTPRequest) async throws -> HTTPResponse in
            guard let self else {
                return HTTPResponse(statusCode: .internalServerError)
            }
            
            return try await self.handleMetrics(request)
        }
        
        await server.appendRoute("POST /v1/logs") { [weak self] (request: HTTPRequest) async throws -> HTTPResponse in
            guard let self else {
                return HTTPResponse(statusCode: .internalServerError)
            }
            
            return try await self.handleLogs(request)
        }
        
        await server.appendRoute("POST /v1/profiles") { [weak self] (request: HTTPRequest) async throws -> HTTPResponse in
            guard let self else {
                return HTTPResponse(statusCode: .internalServerError)
            }
            
            return try await self.handleProfiles(request)
        }
        
        logger.info("Routes configured, starting HTTP server...")
        
        // Start the server in a background task
        Task.detached { [weak self] in
            do {
                try await server.start()
            } catch {
                await self?.handleServerError(error)
            }
        }
        
        // Set state after starting the server
        httpServer = server
        isRunning = true
        logger.info("OTLPServer started successfully on port \(self.port)")
    }
    
    func stop() async {
        logger.info("Stopping OTLPServer...")
        await httpServer?.stop()
        httpServer = nil
        isRunning = false
        continuation?.finish()
        continuation = nil
        logger.info("OTLPServer stopped")
    }
    
    private func handleTraces(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard request.headers[.contentType] == protobufContentType else {
            return HTTPResponse(statusCode: .unsupportedMediaType)
        }
        
        do {
            let data = try await request.bodyData
            let tracesRequest = try Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest(serializedData: data)
            continuation?.yield(.traces(tracesRequest))
            
            return HTTPResponse(
                statusCode: .ok,
                headers: [.contentType: protobufContentType],
                body: Data()
            )
        } catch {
            lastError = error.localizedDescription
            return HTTPResponse(statusCode: .internalServerError)
        }
    }
    
    private func handleMetrics(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard request.headers[.contentType] == protobufContentType else {
            return HTTPResponse(statusCode: .unsupportedMediaType)
        }
        
        do {
            let data = try await request.bodyData
            let metricsRequest = try Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest(serializedData: data)
            continuation?.yield(.metrics(metricsRequest))
            
            return HTTPResponse(
                statusCode: .ok,
                headers: [.contentType: protobufContentType],
                body: Data()
            )
        } catch {
            lastError = error.localizedDescription
            return HTTPResponse(statusCode: .internalServerError)
        }
    }
    
    private func handleLogs(_ request: HTTPRequest) async throws -> HTTPResponse {
        logger.info("Received logs request")
        
        guard request.headers[.contentType] == protobufContentType else {
            logger.error("Invalid content type: \(request.headers[.contentType] ?? "none")")
            return HTTPResponse(statusCode: .unsupportedMediaType)
        }
        
        do {
            let data = try await request.bodyData
            logger.info("Parsing \(data.count) bytes of log data")
            
            let logsRequest = try Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest(serializedData: data)
            logger.info("Parsed logs request with \(logsRequest.resourceLogs.count) resource logs")
            
            continuation?.yield(.logs(logsRequest))
            logger.info("Yielded logs to continuation")
            
            return HTTPResponse(
                statusCode: .ok,
                headers: [.contentType: protobufContentType],
                body: Data()
            )
        } catch {
            logger.error("Failed to handle logs: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return HTTPResponse(statusCode: .internalServerError)
        }
    }
    
    private func handleProfiles(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard request.headers[.contentType] == protobufContentType else {
            return HTTPResponse(statusCode: .unsupportedMediaType)
        }
        
        do {
            let data = try await request.bodyData
            let profilesRequest = try Opentelemetry_Proto_Collector_Profiles_V1development_ExportProfilesServiceRequest(serializedData: data)
            continuation?.yield(.profiles(profilesRequest))
            
            return HTTPResponse(
                statusCode: .ok,
                headers: [.contentType: protobufContentType],
                body: Data()
            )
        } catch {
            lastError = error.localizedDescription
            return HTTPResponse(statusCode: .internalServerError)
        }
    }
    
    private func handleServerError(_ error: Error) async {
        logger.error("Server error: \(error.localizedDescription)")
        isRunning = false
        httpServer = nil
        lastError = error.localizedDescription
    }
    
    private enum OTLPError: Error {
        case serverCreationFailed
        
        var localizedDescription: String {
            switch self {
            case .serverCreationFailed:
                return "Failed to create HTTP server instance"
            }
        }
    }
}
