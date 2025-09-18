import XCTest
@testable import locol

final class TelemetryViewerTests: XCTestCase {
  actor FakeStorage: TelemetryStorageProtocol {
    private(set) var lastSQL: String = ""
    var statsToReturn: [CollectorStats] = []
    var tracesToReturn: [TraceSummary] = []
    var traceSpansToReturn: [TraceSpanDetail] = []
    var metricCatalogToReturn: [MetricDescriptor] = []
    var metricSeriesToReturn: [MetricDataPoint] = []
    var logsToReturn: [LogEntry] = []
    private(set) var lastTraceRequest: (limit: Int, collector: String?)?
    private(set) var lastMetricCatalogCollector: String?
    private(set) var metricSeriesRequests: [(name: String, collector: String?, start: Date, end: Date, bucket: Int)] = []
    private(set) var lastLogRequest: (limit: Int, collector: String?, severity: Int?)?
    func configureTraces(_ traces: [TraceSummary]) {
      tracesToReturn = traces
    }
    func configureTraceSpans(_ spans: [TraceSpanDetail]) {
      traceSpansToReturn = spans
    }
    func configureMetricCatalog(_ catalog: [MetricDescriptor]) {
      metricCatalogToReturn = catalog
    }
    func configureMetricSeries(_ series: [MetricDataPoint]) {
      metricSeriesToReturn = series
    }
    func configureLogs(_ logs: [LogEntry]) {
      logsToReturn = logs
    }
    func storeSpans(_ spans: [StoredSpan]) async throws {}
    func storeMetrics(_ metrics: [StoredMetric]) async throws {}
    func storeLogs(_ logs: [StoredLog]) async throws {}
    func executeQuery(_ sql: String) async throws -> QueryResult {
      lastSQL = sql
      return QueryResult(columns: [], rows: [])
    }
    func getDatabaseStats() async throws -> [CollectorStats] { statsToReturn }
    func clearData(for collectorName: String) async throws {}
    func fetchRecentTraces(limit: Int, collector: String?) async throws -> [TraceSummary] {
      lastTraceRequest = (limit, collector)
      return tracesToReturn
    }
    func fetchTraceSpans(traceId: String) async throws -> [TraceSpanDetail] { traceSpansToReturn }
    func fetchMetricCatalog(collector: String?) async throws -> [MetricDescriptor] {
      lastMetricCatalogCollector = collector
      return metricCatalogToReturn
    }
    func fetchMetricSeries(
      metricName: String,
      collector: String?,
      start: Date,
      end: Date,
      bucketSeconds: Int
    ) async throws -> [MetricDataPoint] {
      metricSeriesRequests.append((metricName, collector, start, end, bucketSeconds))
      return metricSeriesToReturn
    }
    func fetchRecentLogs(
      limit: Int,
      collector: String?,
      minimumSeverity: Int?
    ) async throws -> [LogEntry] {
      lastLogRequest = (limit, collector, minimumSeverity)
      logsToReturn
    }
  }

  func testCollectorFilterInjection() async throws {
    let storage = FakeStorage()
    let viewer = await MainActor.run { TelemetryViewer(storage: storage) }

    await MainActor.run { viewer.selectedCollector = "my-collector" }
    await viewer.executeQuery("SELECT * FROM spans ORDER BY start_time_nanos DESC LIMIT 10")

    let lastSQL = await storage.lastSQL
    XCTAssertTrue(lastSQL.lowercased().contains("where collector_name = 'my-collector'"))
    XCTAssertTrue(lastSQL.lowercased().contains("order by"))
  }

  func testRefreshTraceSummariesSetsSelection() async throws {
    let storage = FakeStorage()
    let summary = TraceSummary(
      traceId: "trace-1",
      serviceName: "frontend",
      rootOperation: "GET /home",
      startTime: Date(),
      endTime: Date().addingTimeInterval(0.25),
      duration: 0.25,
      spanCount: 3,
      errorCount: 0
    )
    await storage.configureTraces([summary])
    let viewer = await MainActor.run { TelemetryViewer(storage: storage) }

    await viewer.refreshTraceSummaries(limit: 25)

    await MainActor.run {
      XCTAssertEqual(viewer.traceSummaries.count, 1)
      XCTAssertEqual(viewer.selectedTraceId, summary.traceId)
      XCTAssertFalse(viewer.traceSummaries.isEmpty)
    }
    let request = await storage.lastTraceRequest
    XCTAssertEqual(request?.limit, 25)
  }

  func testMetricSeriesUsesCollectorFilter() async throws {
    let storage = FakeStorage()
    let descriptor = MetricDescriptor(
      metricName: "request_latency",
      type: "gauge",
      unit: "ms",
      sampleCount: 10,
      serviceCount: 2,
      latestTimestamp: Date()
    )
    await storage.configureMetricCatalog([descriptor])
    let point = MetricDataPoint(
      metricName: "request_latency",
      serviceName: "frontend",
      timestamp: Date(),
      value: 42.0,
      sampleCount: 1
    )
    await storage.configureMetricSeries([point])

    let viewer = await MainActor.run { TelemetryViewer(storage: storage) }
    await MainActor.run { viewer.selectedCollector = "collector-a" }

    await viewer.refreshMetricCatalog()

    await MainActor.run {
      XCTAssertEqual(viewer.metricCatalog.count, 1)
      XCTAssertEqual(viewer.metricSeries.count, 1)
    }
    let catalogCollector = await storage.lastMetricCatalogCollector
    XCTAssertEqual(catalogCollector, "collector-a")
    let seriesRequest = await storage.metricSeriesRequests.last
    XCTAssertEqual(seriesRequest?.collector, "collector-a")
    XCTAssertEqual(seriesRequest?.bucket, MetricTimeRange.lastHour.bucketSeconds)
  }

  func testRefreshLogsRespectsSeverityFilter() async throws {
    let storage = FakeStorage()
    let now = Date()
    let log1 = LogEntry(
      timestamp: now,
      severityText: "INFO",
      severityNumber: LogSeverityNumber.info.rawValue,
      serviceName: "frontend",
      body: "info message",
      traceId: nil,
      spanId: nil,
      attributes: [:]
    )
    let log2 = LogEntry(
      timestamp: now,
      severityText: "ERROR",
      severityNumber: LogSeverityNumber.error.rawValue,
      serviceName: "frontend",
      body: "error message",
      traceId: nil,
      spanId: nil,
      attributes: [:]
    )
    await storage.configureLogs([log1, log2])

    let viewer = await MainActor.run { TelemetryViewer(storage: storage) }

    await viewer.refreshLogs()
    let firstRequest = await storage.lastLogRequest
    XCTAssertEqual(firstRequest?.severity, nil)

    await MainActor.run { viewer.logSeverity = .errorAndAbove }
    await viewer.refreshLogs()
    let secondRequest = await storage.lastLogRequest
    XCTAssertEqual(secondRequest?.severity, LogSeverityNumber.error.rawValue)
  }
}
