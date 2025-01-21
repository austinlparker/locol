import Foundation
import Combine

// MARK: - Types

struct MetricSeries: Identifiable {
    let name: String
    let metrics: [Metric]
    let labels: [String: String]
    
    var id: String { name }
}

struct CounterSeries: Identifiable {
    let name: String
    let metrics: [Metric]
    let labels: [String: String]
    let rateInfo: MetricsManager.RateInfo
    
    var id: String { name }
}

enum MetricGroup: Identifiable {
    case counters(name: String, series: [CounterSeries])
    case gauge(metrics: [Metric])
    case histogram(metric: Metric, histogram: HistogramMetric)
    
    var id: String {
        switch self {
        case .counters(let name, _):
            return "counter-\(name)"
        case .gauge(let metrics):
            // Include labels in ID to make it unique
            let labels = metrics[0].labels.sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ",")
            return "gauge-\(metrics[0].name)-\(labels)"
        case .histogram(let metric, _):
            // Include labels in ID to make it unique
            let labels = metric.labels.sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ",")
            return "histogram-\(metric.name)-\(labels)"
        }
    }
    
    // For consistent ordering
    var sortKey: String {
        switch self {
        case .counters(let name, _):
            return "1-\(name)"
        case .gauge(let metrics):
            return "2-\(metrics[0].name)"
        case .histogram(let metric, _):
            return "3-\(metric.name)"
        }
    }
}

enum TimeRange: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .oneMinute: return "1 minute"
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        }
    }
}

@MainActor
class MetricsViewModel: ObservableObject {
    @Published private(set) var groupedMetrics: [MetricGroup] = []
    @Published var selectedTimeRange: TimeRange = .fiveMinutes
    
    private var cancellables = Set<AnyCancellable>()
    private let manager: MetricsManager
    
    init(manager: MetricsManager = .shared) {
        self.manager = manager
        
        // Observe metrics changes
        manager.$metrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.processMetrics(metrics)
            }
            .store(in: &cancellables)
    }
    
    private func processMetrics(_ metrics: [String: [Metric]]) {
        // Filter metrics by time range
        let cutoff = Date().addingTimeInterval(-Double(selectedTimeRange.rawValue))
        let filteredMetrics = metrics.mapValues { values in
            values.filter { $0.timestamp >= cutoff }
        }
        
        // Group metrics by type
        var counters: [CounterSeries] = []
        var gauges: [Metric] = []
        var histograms: [(metric: Metric, histogram: HistogramMetric)] = []
        
        for (key, values) in filteredMetrics {
            guard let lastValue = values.last else { continue }
            
            switch lastValue.type {
            case .counter:
                if let rateInfo = manager.calculateRate(for: values, preferredWindow: Double(selectedTimeRange.rawValue)) {
                    counters.append(CounterSeries(
                        name: key,
                        metrics: values,
                        labels: lastValue.labels,
                        rateInfo: rateInfo
                    ))
                }
            case .gauge:
                gauges.append(contentsOf: values)
            case .histogram:
                if let histogram = lastValue.histogram {
                    histograms.append((metric: lastValue, histogram: histogram))
                }
            }
        }
        
        // Group counters by base name
        let counterGroups = Dictionary(grouping: counters) { series in
            series.metrics[0].name
        }.map { name, series in
            MetricGroup.counters(name: name, series: series)
        }
        
        // Group gauges by name and labels
        let gaugeGroups = Dictionary(grouping: gauges) { metric in
            metricKey(name: metric.name, labels: metric.labels)
        }.map { _, metrics in
            MetricGroup.gauge(metrics: metrics.sorted(by: { $0.timestamp < $1.timestamp }))
        }
        
        // Group histograms
        let histogramGroups = histograms.map { metric, histogram in
            MetricGroup.histogram(metric: metric, histogram: histogram)
        }
                
        // Combine all groups and sort for consistent ordering
        groupedMetrics = (counterGroups + gaugeGroups + histogramGroups)
            .sorted(by: { $0.sortKey < $1.sortKey })
    }
    
    private func metricKey(name: String, labels: [String: String]) -> String {
        manager.metricKey(name: name, labels: labels)
    }
} 
