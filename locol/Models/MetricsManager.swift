import Foundation
import Combine

enum MetricType {
    case counter
    case histogram
    case gauge
}

struct MetricDefinition {
    let name: String
    let description: String
    let type: MetricType
}

struct PrometheusMetric {
    let name: String
    let labels: [String: String]
    let value: Double
    let timestamp: Date
}

struct TimeSeriesData {
    let name: String
    let labels: [String: String]
    var values: [(timestamp: Date, value: Double)]
    let definition: MetricDefinition?
    
    // Keep last hour of data by default
    let maxAge: TimeInterval = 3600
    
    mutating func addValue(_ value: Double, at timestamp: Date) {
        values.append((timestamp: timestamp, value: value))
        // Clean up old values
        let cutoff = Date().addingTimeInterval(-maxAge)
        values.removeAll { $0.timestamp < cutoff }
    }
}

struct HistogramData {
    var buckets: [(le: Double, count: Double)]
    var sum: Double
    var count: Double
    let timestamp: Date
    
    func percentile(_ p: Double) -> Double {
        guard !buckets.isEmpty && count > 0 else { return 0 }
        
        let rank = (p / 100.0) * count
        var prev = (le: -Double.infinity, count: 0.0)
        
        for bucket in buckets {
            if bucket.count >= rank {
                // Linear interpolation between bucket boundaries
                if bucket.count == prev.count {
                    return bucket.le
                }
                let fraction = (rank - prev.count) / (bucket.count - prev.count)
                return prev.le + fraction * (bucket.le - prev.le)
            }
            prev = bucket
        }
        
        // If we haven't found it yet, use the highest finite bucket
        return buckets.last(where: { !$0.le.isInfinite })?.le ?? 0
    }
    
    var average: Double {
        count > 0 ? sum / count : 0
    }
}

class MetricsManager: ObservableObject {
    @Published private(set) var metrics: [String: TimeSeriesData] = [:]
    private var metricDefinitions: [String: MetricDefinition] = [:]
    @Published private(set) var histogramData: [String: [HistogramData]] = [:] // Key -> time series of histogram data
    private var timer: Timer?
    private let scrapeInterval: TimeInterval = 15 // 15 seconds
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        startScraping()
    }
    
    private func startScraping() {
        timer = Timer.scheduledTimer(withTimeInterval: scrapeInterval, repeats: true) { [weak self] _ in
            self?.scrapeMetrics()
        }
    }
    
    private func scrapeMetrics() {
        guard let url = URL(string: "http://localhost:8888/metrics") else { return }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { String(data: $0.data, encoding: .utf8) }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        CollectorLogger.shared.error("Failed to scrape metrics: \(error)")
                    }
                },
                receiveValue: { [weak self] metricsData in
                    if let metricsString = metricsData {
                        self?.parseAndStoreMetrics(metricsString)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func parseAndStoreMetrics(_ metricsString: String) {
        let lines = metricsString.components(separatedBy: .newlines)
        let now = Date()
        
        var currentHelp: String?
        var currentType: MetricType?
        var currentName: String?
        
        // Temporary storage for histogram data being processed
        var currentHistogramBuckets: [(le: Double, count: Double)] = []
        var currentHistogramSum: Double?
        var currentHistogramCount: Double?
        var currentHistogramName: String?
        var currentHistogramLabels: [String: String]?
        
        for line in lines {
            if line.hasPrefix("# HELP ") {
                // Process any pending histogram data
                if let name = currentHistogramName,
                   let sum = currentHistogramSum,
                   let count = currentHistogramCount {
                    processHistogramData(name: name, 
                                      labels: currentHistogramLabels ?? [:],
                                      buckets: currentHistogramBuckets,
                                      sum: sum,
                                      count: count,
                                      timestamp: now)
                    
                    // Reset histogram collection
                    currentHistogramBuckets = []
                    currentHistogramSum = nil
                    currentHistogramCount = nil
                    currentHistogramName = nil
                    currentHistogramLabels = nil
                }
                
                let parts = line.dropFirst(7).split(separator: " ", maxSplits: 1)
                if parts.count == 2 {
                    currentName = String(parts[0])
                    currentHelp = String(parts[1])
                }
            } else if line.hasPrefix("# TYPE ") {
                let parts = line.dropFirst(7).split(separator: " ", maxSplits: 1)
                if parts.count == 2, let name = currentName {
                    currentType = parseMetricType(String(parts[1]))
                    if let help = currentHelp, let type = currentType {
                        metricDefinitions[name] = MetricDefinition(
                            name: name,
                            description: help,
                            type: type
                        )
                    }
                }
            } else if !line.isEmpty && !line.hasPrefix("#") {
                if let metric = parseMetricLine(line) {
                    if metric.name.hasSuffix("_bucket") {
                        // Extract the base name (remove _bucket suffix)
                        let baseName = String(metric.name.dropLast(7))
                        if let le = metric.labels["le"]?.replacingOccurrences(of: "+Inf", with: "inf"),
                           let leValue = Double(le) {
                            currentHistogramName = baseName
                            currentHistogramLabels = metric.labels
                            currentHistogramBuckets.append((le: leValue, count: metric.value))
                        }
                    } else if metric.name.hasSuffix("_sum") {
                        currentHistogramSum = metric.value
                    } else if metric.name.hasSuffix("_count") {
                        currentHistogramCount = metric.value
                    } else {
                        let key = metricKey(name: metric.name, labels: metric.labels)
                        if var timeSeriesData = metrics[key] {
                            timeSeriesData.addValue(metric.value, at: now)
                            metrics[key] = timeSeriesData
                        } else {
                            let definition = metricDefinitions[metric.name]
                            metrics[key] = TimeSeriesData(
                                name: metric.name,
                                labels: metric.labels,
                                values: [(timestamp: now, value: metric.value)],
                                definition: definition
                            )
                        }
                    }
                }
            }
        }
        
        // Process any remaining histogram data
        if let name = currentHistogramName,
           let sum = currentHistogramSum,
           let count = currentHistogramCount {
            processHistogramData(name: name,
                               labels: currentHistogramLabels ?? [:],
                               buckets: currentHistogramBuckets,
                               sum: sum,
                               count: count,
                               timestamp: now)
        }
    }
    
    private func processHistogramData(name: String, labels: [String: String], buckets: [(le: Double, count: Double)], sum: Double, count: Double, timestamp: Date) {
        // Get the base name for the histogram
        let baseName = name.hasSuffix("_bucket") ? String(name.dropLast(7)) : name
        let key = metricKey(name: baseName, labels: labels)
        
        // Sort buckets by le value and ensure +Inf is at the end
        let sortedBuckets = buckets.sorted { 
            if $0.le.isInfinite && !$1.le.isInfinite { return false }
            if !$0.le.isInfinite && $1.le.isInfinite { return true }
            return $0.le < $1.le 
        }
        
        let histData = HistogramData(buckets: sortedBuckets, sum: sum, count: count, timestamp: timestamp)
        
        // Store the raw histogram data
        if var series = histogramData[key] {
            series.append(histData)
            // Keep only recent data
            let cutoff = Date().addingTimeInterval(-3600) // 1 hour
            series.removeAll { $0.timestamp < cutoff }
            histogramData[key] = series
        } else {
            histogramData[key] = [histData]
        }
        
        // Store the base metric with the average value
        if var timeSeriesData = metrics[key] {
            timeSeriesData.addValue(histData.average, at: timestamp)
            metrics[key] = timeSeriesData
        } else {
            let definition = metricDefinitions[baseName] ?? MetricDefinition(
                name: baseName,
                description: "Histogram metric",
                type: .histogram
            )
            metrics[key] = TimeSeriesData(
                name: baseName,
                labels: labels,
                values: [(timestamp: timestamp, value: histData.average)],
                definition: definition
            )
        }
        
        // Calculate and store percentile values
        let percentiles = [50.0, 90.0, 99.0] // median, p90, p99
        for p in percentiles {
            let percentileName = "\(baseName)_p\(Int(p))"
            let percentileKey = metricKey(name: percentileName, labels: labels)
            let value = histData.percentile(p)
            
            if var timeSeriesData = metrics[percentileKey] {
                timeSeriesData.addValue(value, at: timestamp)
                metrics[percentileKey] = timeSeriesData
            } else {
                let definition = MetricDefinition(
                    name: percentileName,
                    description: "P\(Int(p)) percentile of \(baseName)",
                    type: .gauge
                )
                metrics[percentileKey] = TimeSeriesData(
                    name: percentileName,
                    labels: labels,
                    values: [(timestamp: timestamp, value: value)],
                    definition: definition
                )
            }
        }
    }
    
    private func parseMetricType(_ typeString: String) -> MetricType {
        switch typeString {
        case "counter":
            return .counter
        case "histogram":
            return .histogram
        case "gauge":
            return .gauge
        default:
            // Default to gauge for unknown types
            return .gauge
        }
    }
    
    private func parseMetricLine(_ line: String) -> PrometheusMetric? {
        let components = line.split(separator: " ")
        guard components.count >= 2,
              let value = Double(String(components.last!)) else { return nil }
        
        let nameAndLabels = String(components[0])
        let (name, labels) = parseNameAndLabels(nameAndLabels)
        
        return PrometheusMetric(
            name: name,
            labels: labels,
            value: value,
            timestamp: Date()
        )
    }
    
    private func parseNameAndLabels(_ nameAndLabels: String) -> (String, [String: String]) {
        if let openBrace = nameAndLabels.firstIndex(of: "{"),
           let closeBrace = nameAndLabels.lastIndex(of: "}") {
            let name = String(nameAndLabels[..<openBrace])
            let labelsString = String(nameAndLabels[openBrace...closeBrace])
            
            // Parse labels
            var labels: [String: String] = [:]
            let labelPairs = labelsString.dropFirst().dropLast().split(separator: ",")
            
            for pair in labelPairs {
                let parts = pair.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0].trimmingCharacters(in: .whitespaces))
                    var value = String(parts[1].trimmingCharacters(in: .whitespaces))
                    // Remove quotes if present
                    if value.hasPrefix("\"") && value.hasSuffix("\"") {
                        value = String(value.dropFirst().dropLast())
                    }
                    labels[key] = value
                }
            }
            
            return (name, labels)
        }
        
        return (nameAndLabels, [:])
    }
    
    func metricKey(name: String, labels: [String: String]) -> String {
        // Filter out service-related labels and "le" label
        let relevantLabels = labels.filter { key, _ in
            !key.hasPrefix("service.") && key != "le"
        }
        
        // If no relevant labels, return the base name
        if relevantLabels.isEmpty {
            return name
        }
        
        let sortedLabels = relevantLabels.sorted(by: { $0.key < $1.key })
        let labelString = sortedLabels.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        return "\(name){\(labelString)}"
    }
    
    func getMetricValues(name: String) -> [(timestamp: Date, value: Double)]? {
        // First try exact match
        if let metric = metrics[name] {
            return metric.values
        }
        
        // Then try with base name
        let baseName = name.hasSuffix("_bucket") ? String(name.dropLast(7)) : name
        return metrics.first { $0.value.name == baseName }?.value.values
    }
    
    deinit {
        timer?.invalidate()
    }
} 