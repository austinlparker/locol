import Foundation
import Combine
import SwiftUI
import Observation

@Observable
final class MetricsViewModel {
    private let manager: MetricsManager
    private var timer: Timer?
    
    var groupedMetrics: [MetricGroup] = []
    var selectedTimeRange: TimeRange = .oneMinute
    var error: String?
    
    init(manager: MetricsManager = .shared) {
        self.manager = manager
        
        // Start timer to update metrics periodically
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
        timer?.fire()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func updateMetrics() {
        processMetrics(manager.metrics)
        error = manager.lastError
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
        let sortedLabels = labels.sorted(by: { $0.key < $1.key })
        let labelString = sortedLabels.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        return "\(name){\(labelString)}"
    }
} 
