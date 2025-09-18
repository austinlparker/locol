import Foundation

// MARK: - Telemetry Storage Abstraction

protocol TelemetryStorageProtocol: Sendable {
    func storeSpans(_ spans: [StoredSpan]) async throws
    func storeMetrics(_ metrics: [StoredMetric]) async throws
    func storeLogs(_ logs: [StoredLog]) async throws
    func executeQuery(_ sql: String) async throws -> QueryResult
    func getDatabaseStats() async throws -> [CollectorStats]
    func clearData(for collectorName: String) async throws
    func fetchRecentTraces(limit: Int, collector: String?) async throws -> [TraceSummary]
    func fetchTraceSpans(traceId: String) async throws -> [TraceSpanDetail]
    func fetchMetricCatalog(collector: String?) async throws -> [MetricDescriptor]
    func fetchMetricSeries(
        metricName: String,
        collector: String?,
        start: Date,
        end: Date,
        bucketSeconds: Int
    ) async throws -> [MetricDataPoint]
    func fetchRecentLogs(
        limit: Int,
        collector: String?,
        minimumSeverity: Int?
    ) async throws -> [LogEntry]
}

// MARK: - OTLP Server Abstraction

@available(macOS 15.0, *)
protocol OTLPServerProtocol: Sendable {
    func start() async throws
    func stop() async
    func restart() async throws
    func isRunning() async -> Bool
    func getStatistics() async -> ServerStatistics
    func resetStatistics() async
    func incrementTraces(by count: Int) async
    func incrementMetrics(by count: Int) async
    func incrementLogs(by count: Int) async
    func autoStartIfEnabled() async
    func stopOnAppTermination() async
}
