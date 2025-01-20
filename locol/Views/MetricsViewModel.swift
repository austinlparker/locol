import Foundation
import Combine

struct CounterSeries {
    let name: String
    let metrics: [Metric]
    let labels: [String: String]
    let currentRate: Double
    let rates: [(timestamp: Date, rate: Double)]
    
    init(name: String, metrics: [Metric], labels: [String: String], currentRate: Double) {
        self.name = name
        self.metrics = metrics
        self.labels = labels
        self.currentRate = currentRate
        
        // Precompute rates for all points
        var computedRates: [(timestamp: Date, rate: Double)] = []
        for i in 0..<metrics.count - 1 {
            let current = CounterData(timestamp: metrics[i].timestamp, value: metrics[i].value, labels: metrics[i].labels)
            let next = CounterData(timestamp: metrics[i + 1].timestamp, value: metrics[i + 1].value, labels: metrics[i + 1].labels)
            if let rate = next.calculateRate(previous: current) {
                computedRates.append((timestamp: current.timestamp, rate: rate))
            }
        }
        self.rates = computedRates
    }
}

class MetricsViewModel: ObservableObject {
    typealias RegularMetrics = [(name: String, series: [CounterSeries])]
    typealias GaugeMetrics = [(String, [Metric])]
    typealias HistogramMetrics = [(String, [Metric])]
    
    @Published private(set) var groupedMetrics: (regular: RegularMetrics, gauges: GaugeMetrics, histograms: HistogramMetrics)
    private var cancellables = Set<AnyCancellable>()
    private let metricsManager: MetricsManager
    
    init(metricsManager: MetricsManager = .shared) {
        self.metricsManager = metricsManager
        self.groupedMetrics = (regular: [], gauges: [], histograms: [])
        
        // Subscribe to metrics changes
        metricsManager.$metrics
            .map { [weak self] metrics -> (regular: RegularMetrics, gauges: GaugeMetrics, histograms: HistogramMetrics) in
                guard let self = self else { return (regular: [], gauges: [], histograms: []) }
                
                // Group metrics by name first
                let metricsByName = Dictionary(grouping: metrics.map { $0 }) { entry in
                    entry.key.components(separatedBy: "{").first ?? entry.key
                }
                
                // Split metrics by type
                let regular: [(String, [CounterSeries])] = metricsByName.compactMap { name, entries in
                    let counterMetrics = entries.filter { entry in
                        guard let type = entry.value.first?.type else { return false }
                        return type == .counter
                    }
                    
                    if counterMetrics.isEmpty { return nil }
                    
                    let series = counterMetrics.map { entry in
                        let rate = self.metricsManager.getRate(for: entry.key, timeWindow: 60) ?? 0
                        return CounterSeries(
                            name: entry.key,
                            metrics: entry.value,
                            labels: entry.value.first?.labels ?? [:],
                            currentRate: rate
                        )
                    }
                    
                    return (name, series)
                }
                .sorted { $0.0 < $1.0 }
                
                let gauges: GaugeMetrics = metrics.filter { _, values in
                    guard let type = values.first?.type else { return false }
                    return type == .gauge
                }
                .sorted { $0.0 < $1.0 }
                
                let histograms: HistogramMetrics = metrics.filter { _, values in
                    guard let type = values.first?.type else { return false }
                    return type == .histogram
                }
                .sorted { $0.0 < $1.0 }
                
                return (
                    regular: regular,
                    gauges: gauges,
                    histograms: histograms
                )
            }
            .assign(to: &$groupedMetrics)
    }
    
    func startScraping() {
        metricsManager.startScraping()
    }
    
    func stopScraping() {
        metricsManager.stopScraping()
    }
} 