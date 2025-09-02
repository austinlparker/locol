import Foundation
import SwiftUI
import Combine
import GRDB
import os

// MARK: - Telemetry View Model

@MainActor
@Observable
class TelemetryViewModel {
    // MARK: - State
    private(set) var spans: [TelemetrySpan] = []
    private(set) var metrics: [TelemetryMetric] = []
    private(set) var logs: [TelemetryLog] = []
    private(set) var metricSummaries: [MetricSummary] = []
    private(set) var logStats: [LogSeverityStats] = []
    
    private(set) var isLoading = false
    private(set) var error: Error?
    
    // MARK: - Filter State
    var selectedCollector = ""
    var selectedTimeRange = TelemetryTimeRange.last15Minutes
    var selectedMetricName: String?
    var searchText = ""
    var selectedSeverityLevels: Set<LogSeverity> = Set(LogSeverity.allCases)
    
    // MARK: - Dependencies
    private let telemetryDB = TelemetryDatabase.shared
    private let logger = Logger(subsystem: "com.locol.telemetry", category: "TelemetryViewModel")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Set the initial collector to the first available one
        if let firstCollector = availableCollectors.first {
            selectedCollector = firstCollector
        }
        startObservingData()
    }
    
    init(initialCollector: String) {
        selectedCollector = initialCollector
        startObservingData()
    }
    
    // MARK: - Data Observation
    private func startObservingData() {
        // Only observe if we have a valid collector selected
        guard !selectedCollector.isEmpty else {
            logger.info("No collector selected for telemetry observation")
            return
        }
        
        // Observe spans
        observeSpans()
        
        // Observe metrics
        observeMetrics()
        observeMetricSummaries()
        
        // Observe logs
        observeLogs()
        observeLogStats()
    }
    
    private func observeSpans() {
        let request = TraceRequest(
            collectorName: selectedCollector,
            timeRange: selectedTimeRange.grdbTimeRange,
            limit: 100
        )
        
        do {
            let db = try telemetryDB.database(for: selectedCollector)
            request.publisher(in: db)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.error = error
                            self?.logger.error("Failed to observe spans: \(error)")
                        }
                    },
                    receiveValue: { [weak self] spans in
                        self?.spans = spans
                    }
                )
                .store(in: &cancellables)
        } catch {
            self.error = error
            logger.error("Failed to setup spans observation: \(error)")
        }
    }
    
    private func observeMetrics() {
        let request = MetricsTimeSeriesRequest(
            collectorName: selectedCollector,
            metricName: selectedMetricName,
            timeRange: selectedTimeRange.grdbTimeRange,
            limit: 1000
        )
        
        do {
            let db = try telemetryDB.database(for: selectedCollector)
            request.publisher(in: db)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.error = error
                            self?.logger.error("Failed to observe metrics: \(error)")
                        }
                    },
                    receiveValue: { [weak self] metrics in
                        self?.metrics = metrics
                    }
                )
                .store(in: &cancellables)
        } catch {
            self.error = error
            logger.error("Failed to setup metrics observation: \(error)")
        }
    }
    
    private func observeMetricSummaries() {
        let request = MetricNamesRequest(collectorName: selectedCollector)
        
        do {
            let db = try telemetryDB.database(for: selectedCollector)
            request.publisher(in: db)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.error = error
                            self?.logger.error("Failed to observe metric summaries: \(error)")
                        }
                    },
                    receiveValue: { [weak self] summaries in
                        self?.metricSummaries = summaries
                    }
                )
                .store(in: &cancellables)
        } catch {
            self.error = error
            logger.error("Failed to setup metric summaries observation: \(error)")
        }
    }
    
    private func observeLogs() {
        let request = LogSearchRequest(
            collectorName: selectedCollector,
            searchText: searchText.isEmpty ? nil : searchText,
            severityLevels: selectedSeverityLevels,
            timeRange: selectedTimeRange.grdbTimeRange,
            limit: 1000
        )
        
        do {
            let db = try telemetryDB.database(for: selectedCollector)
            request.publisher(in: db)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.error = error
                            self?.logger.error("Failed to observe logs: \(error)")
                        }
                    },
                    receiveValue: { [weak self] logs in
                        self?.logs = logs
                    }
                )
                .store(in: &cancellables)
        } catch {
            self.error = error
            logger.error("Failed to setup logs observation: \(error)")
        }
    }
    
    private func observeLogStats() {
        let request = LogStatsRequest(
            collectorName: selectedCollector,
            timeRange: selectedTimeRange.grdbTimeRange
        )
        
        do {
            let db = try telemetryDB.database(for: selectedCollector)
            request.publisher(in: db)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.error = error
                            self?.logger.error("Failed to observe log stats: \(error)")
                        }
                    },
                    receiveValue: { [weak self] stats in
                        self?.logStats = stats
                    }
                )
                .store(in: &cancellables)
        } catch {
            self.error = error
            logger.error("Failed to setup log stats observation: \(error)")
        }
    }
    
    // MARK: - Filter Updates
    func updateCollector(_ collectorName: String) {
        selectedCollector = collectorName
        refreshObservations()
    }
    
    func updateTimeRange(_ timeRange: TelemetryTimeRange) {
        selectedTimeRange = timeRange
        refreshObservations()
    }
    
    func updateMetricName(_ metricName: String?) {
        selectedMetricName = metricName
        refreshObservations()
    }
    
    func updateSearchText(_ searchText: String) {
        self.searchText = searchText
        refreshObservations()
    }
    
    func updateSeverityLevels(_ severityLevels: Set<LogSeverity>) {
        selectedSeverityLevels = severityLevels
        refreshObservations()
    }
    
    private func refreshObservations() {
        cancellables.removeAll()
        startObservingData()
    }
    
    // MARK: - Computed Properties
    var traceHierarchies: [TraceHierarchy] {
        // Group spans by trace ID and create hierarchies
        let groupedSpans = Dictionary(grouping: spans) { $0.traceId }
        return groupedSpans.map { (traceId, spans) in
            TraceHierarchy(spans: spans.sorted(by: { $0.startTime < $1.startTime }))
        }.sorted(by: { $0.spans.first?.startTime ?? 0 > $1.spans.first?.startTime ?? 0 })
    }
    
    var groupedMetrics: [TelemetryMetricGroup] {
        let grouped = Dictionary(grouping: metrics) { metric in
            MetricGroupKey(name: metric.name, type: metric.type, labels: metric.labels)
        }
        
        return grouped.compactMap { (key, metrics) in
            let sortedMetrics = metrics.sorted(by: { $0.timestamp < $1.timestamp })
            return TelemetryMetricGroup(
                name: key.name,
                type: key.type,
                labels: key.labels,
                metrics: sortedMetrics
            )
        }.sorted(by: { $0.name < $1.name })
    }
    
    var recentLogs: [TelemetryLog] {
        logs.sorted(by: { $0.timestamp > $1.timestamp })
    }
}

// MARK: - Supporting Types

enum TelemetryTimeRange: CaseIterable, Identifiable {
    case last5Minutes
    case last15Minutes
    case last30Minutes
    case last1Hour
    case last6Hours
    case last24Hours
    
    var id: String { displayName }
    
    var displayName: String {
        switch self {
        case .last5Minutes: return "Last 5 minutes"
        case .last15Minutes: return "Last 15 minutes"
        case .last30Minutes: return "Last 30 minutes"
        case .last1Hour: return "Last hour"
        case .last6Hours: return "Last 6 hours"
        case .last24Hours: return "Last 24 hours"
        }
    }
    
    var grdbTimeRange: TelemetryDataTimeRange {
        switch self {
        case .last5Minutes: return TelemetryDataTimeRange.recent(minutes: 5)
        case .last15Minutes: return TelemetryDataTimeRange.recent(minutes: 15)
        case .last30Minutes: return TelemetryDataTimeRange.recent(minutes: 30)
        case .last1Hour: return TelemetryDataTimeRange.recent(hours: 1)
        case .last6Hours: return TelemetryDataTimeRange.recent(hours: 6)
        case .last24Hours: return TelemetryDataTimeRange.recent(hours: 24)
        }
    }
}

struct TelemetryMetricGroup: Identifiable {
    let name: String
    let type: TelemetryMetric.MetricType
    let labels: [String: String]
    let metrics: [TelemetryMetric]
    
    var id: String {
        let labelString = labels.sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        return "\(name)_\(type.rawValue)_\(labelString)"
    }
    
    var latestValue: Double? {
        metrics.last?.value
    }
    
    var latestTimestamp: Int64? {
        metrics.last?.timestamp
    }
}

private struct MetricGroupKey: Hashable {
    let name: String
    let type: TelemetryMetric.MetricType
    let labels: [String: String]
}

// MARK: - Database Availability Check

extension TelemetryViewModel {
    var hasTelemetryData: Bool {
        !spans.isEmpty || !metrics.isEmpty || !logs.isEmpty
    }
    
    var availableCollectors: [String] {
        // Scan for available collector databases
        let collectorsDir = CollectorFileManager.shared.baseDirectory.appendingPathComponent("collectors")
        
        do {
            let collectorNames = try FileManager.default.contentsOfDirectory(atPath: collectorsDir.path)
            return collectorNames.filter { collectorName in
                let dbPath = collectorsDir.appendingPathComponent(collectorName).appendingPathComponent("telemetry.db")
                return FileManager.default.fileExists(atPath: dbPath.path)
            }.sorted()
        } catch {
            logger.error("Failed to scan for available collectors: \(error)")
            return []
        }
    }
}