import Foundation
import Combine
import os

struct PrometheusMetric {
    let name: String
    let labels: [String: String]
    let value: Double
    let timestamp: Date
}

class MetricsManager: ObservableObject {
    static let shared = MetricsManager()
    
    @Published private(set) var metrics: [String: TimeSeriesData] = [:] {
        willSet {
            logger.debug("Updating metrics dictionary")
            objectWillChange.send()
        }
    }
    private var metricDefinitions: [String: MetricDefinition] = [:]
    @Published private(set) var histogramData: [String: [HistogramData]] = [:]
    private var histogramBuckets: [String: [(le: Double, count: Double)]] = [:]
    private var histogramSums: [String: Double] = [:]
    private var timer: Timer?
    private let scrapeInterval: TimeInterval = 15
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "io.aparker.locol", category: "MetricsManager")
    
    private init() {
        logger.debug("MetricsManager initialized")
    }
    
    deinit {
        logger.debug("MetricsManager being deallocated")
        stopScraping()
    }
    
    func startScraping() {
        logger.debug("Starting metrics scraping")
        stopScraping() // Ensure we don't have multiple timers
        timer = Timer.scheduledTimer(withTimeInterval: scrapeInterval, repeats: true) { [weak self] _ in
            self?.scrapeMetrics()
        }
        // Do an initial scrape
        scrapeMetrics()
    }
    
    func stopScraping() {
        logger.debug("Stopping metrics scraping")
        timer?.invalidate()
        timer = nil
    }
    
    private func scrapeMetrics() {
        guard let url = URL(string: "http://localhost:8888/metrics") else {
            logger.error("Failed to create metrics URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                self?.logger.error("Network error while scraping metrics: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                self?.logger.error("No data received from metrics endpoint")
                return
            }
            
            guard let metricsString = String(data: data, encoding: .utf8) else {
                self?.logger.error("Failed to decode metrics data as UTF-8")
                return
            }
            
            DispatchQueue.main.async {
                self?.parseAndStoreMetrics(metricsString)
            }
        }
        task.resume()
    }
    
    private func parseAndStoreMetrics(_ metricsString: String) {
        logger.debug("Parsing metrics string of length: \(metricsString.count)")
        
        // Split into blocks separated by # HELP or # TYPE
        let lines = metricsString.components(separatedBy: .newlines)
        var currentMetric: (name: String, help: String?, type: MetricType?, values: [(labels: [String: String], value: Double)])? = nil
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }
            
            if trimmedLine.starts(with: "# HELP") {
                // Store previous metric if exists
                if let metric = currentMetric {
                    processMetric(metric)
                }
                
                // Start new metric
                let parts = trimmedLine.components(separatedBy: " ")
                guard parts.count >= 3 else { continue }
                let name = parts[2]
                let help = parts.dropFirst(3).joined(separator: " ")
                currentMetric = (name: name, help: help, type: nil, values: [])
                
            } else if trimmedLine.starts(with: "# TYPE") {
                let parts = trimmedLine.components(separatedBy: " ")
                guard parts.count >= 4 else { continue }
                let name = parts[2]
                let typeStr = parts[3]
                
                if currentMetric == nil || currentMetric?.name != name {
                    // Start new metric if no HELP line or if name doesn't match
                    currentMetric = (name: name, help: nil, type: nil, values: [])
                }
                
                // Update type
                if let type = MetricType(rawValue: typeStr) {
                    currentMetric?.type = type
                }
                
            } else if let metric = currentMetric {
                // Parse metric value line
                if let (labels, value) = parseMetricLine(trimmedLine) {
                    currentMetric?.values.append((labels: labels, value: value))
                }
            }
        }
        
        // Process last metric
        if let metric = currentMetric {
            processMetric(metric)
        }
    }
    
    private func processMetric(_ metric: (name: String, help: String?, type: MetricType?, values: [(labels: [String: String], value: Double)])) {
        guard let type = metric.type else { return }
        
        logger.debug("Processing metric: \(metric.name) of type \(type.rawValue)")
        
        // Create or update metric definition
        let definition = MetricDefinition(
            name: metric.name,
            description: metric.help ?? "",
            type: type
        )
        metricDefinitions[metric.name] = definition
        
        // For histograms, we need to process both the base metric and its components
        if type == .histogram {
            let baseName = MetricFilter.getBaseName(metric.name)
            
            // If this is a histogram component, process it
            if MetricFilter.isHistogramComponent(metric.name) {
                processHistogramComponent(metric: metric.name, values: metric.values)
                return
            }
            
            // For the base histogram metric or buckets, ensure we have a TimeSeriesData entry
            for (labels, value) in metric.values {
                let key = metricKey(name: baseName, labels: labels)
                if metrics[key] == nil {
                    metrics[key] = TimeSeriesData(
                        name: baseName,
                        labels: labels,
                        values: [],
                        definition: MetricDefinition(
                            name: baseName,
                            description: definition.description,
                            type: .histogram
                        )
                    )
                }
                // Add the value to the time series
                metrics[key]?.values.append((
                    timestamp: Date(),
                    value: value,
                    labels: labels
                ))
            }
        } else {
            // For counters and gauges, store values directly
            for (labels, value) in metric.values {
                let key = metricKey(name: metric.name, labels: labels)
                if metrics[key] == nil {
                    metrics[key] = TimeSeriesData(
                        name: metric.name,
                        labels: labels,
                        values: [],
                        definition: definition
                    )
                }
                metrics[key]?.values.append((
                    timestamp: Date(),
                    value: value,
                    labels: labels
                ))
            }
        }
    }
    
    private func processHistogramComponent(metric name: String, values: [(labels: [String: String], value: Double)]) {
        let baseName = MetricFilter.getBaseName(name)
        
        for (labels, value) in values {
            if name.hasSuffix("_bucket") {
                if let le = labels["le"]?.replacingOccurrences(of: "+Inf", with: "inf"),
                   let leValue = Double(le) {
                    let key = metricKey(name: baseName, labels: labels)
                    if histogramBuckets[key] == nil {
                        histogramBuckets[key] = []
                    }
                    histogramBuckets[key]?.append((le: leValue, count: value))
                    logger.debug("Added bucket for \(key): le=\(leValue), count=\(value)")
                }
            } else if name.hasSuffix("_sum") {
                let key = metricKey(name: baseName, labels: labels)
                histogramSums[key] = value
                logger.debug("Added sum for \(key): \(value)")
            } else if name.hasSuffix("_count") {
                let key = metricKey(name: baseName, labels: labels)
                processHistogramCount(baseKey: key, labels: labels, value: value)
                logger.debug("Processed count for \(key): \(value)")
            }
        }
    }
    
    private func processHistogramCount(baseKey: String, labels: [String: String], value: Double) {
        if let buckets = histogramBuckets[baseKey]?.sorted(by: { $0.le < $1.le }),
           let sum = histogramSums[baseKey] {
            let histogram = HistogramData(
                buckets: buckets,
                sum: sum,
                count: value,
                timestamp: Date()
            )
            
            if histogramData[baseKey] == nil {
                histogramData[baseKey] = []
            }
            histogramData[baseKey]?.append(histogram)
            
            // Update the base metric
            if let definition = metricDefinitions[baseKey] {
                if metrics[baseKey] == nil {
                    metrics[baseKey] = TimeSeriesData(
                        name: baseKey,
                        labels: labels,
                        values: [],
                        definition: definition
                    )
                }
                metrics[baseKey]?.values.append((
                    timestamp: histogram.timestamp,
                    value: histogram.average,
                    labels: labels
                ))
            }
        }
    }
    
    private func parseMetricLine(_ line: String) -> (labels: [String: String], value: Double)? {
        let parts = line.components(separatedBy: " ")
        guard parts.count >= 2,
              let value = Double(parts[parts.count - 1]) else { return nil }
        
        // Extract metric name and labels
        let nameAndLabels = parts[0]
        var labels: [String: String] = [:]
        
        if let openBrace = nameAndLabels.firstIndex(of: "{"),
           let closeBrace = nameAndLabels.lastIndex(of: "}"),
           openBrace < closeBrace {
            let labelsPart = nameAndLabels[nameAndLabels.index(after: openBrace)..<closeBrace]
            let labelPairs = labelsPart.components(separatedBy: ",")
            for pair in labelPairs {
                let keyValue = pair.components(separatedBy: "=")
                if keyValue.count == 2 {
                    let key = keyValue[0].trimmingCharacters(in: .whitespaces)
                    var value = keyValue[1].trimmingCharacters(in: .whitespaces)
                    if value.hasPrefix("\"") && value.hasSuffix("\"") {
                        value = String(value.dropFirst().dropLast())
                    }
                    labels[key] = value
                }
            }
        }
        
        return (labels: labels, value: value)
    }
    
    func metricKey(name: String, labels: [String: String]) -> String {
        // Filter out "le" label but keep service labels
        let relevantLabels = labels.filter { key, _ in
            key != "le"
        }
        
        // If no relevant labels, return the base name
        if relevantLabels.isEmpty {
            return name
        }
        
        let sortedLabels = relevantLabels.sorted(by: { $0.key < $1.key })
        let labelString = sortedLabels.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        return "\(name){\(labelString)}"
    }
    
    func getMetricValues(name: String) -> [(timestamp: Date, value: Double, labels: [String: String])]? {
        // First try exact match
        if let metric = metrics[name] {
            return metric.values
        }
        
        // Then try with base name
        let baseName = name.hasSuffix("_bucket") ? String(name.dropLast(7)) : name
        return metrics.first(where: { $0.value.name == baseName })?.value.values
    }
    
    private func createDefaultDefinition(for metricName: String) -> MetricDefinition {
        // Only infer type if we don't have an explicit type from # TYPE
        if let definition = metricDefinitions[metricName] {
            return definition
        }
        
        // Default to gauge for everything else
        logger.debug("No explicit type found for \(metricName), defaulting to gauge")
        return MetricDefinition(
            name: metricName,
            description: "Metric: \(metricName)",
            type: .gauge
        )
    }
    
    private func updateMetric(key: String, value: Double, at timestamp: Date) {
        var updatedMetrics = metrics
        if var timeSeriesData = updatedMetrics[key] {
            timeSeriesData.addValue(value, at: timestamp)
            updatedMetrics[key] = timeSeriesData
            metrics = updatedMetrics
        } else {
            // Extract base name and labels from key
            let baseName = key.split(separator: "{").first.map(String.init) ?? key
            let labels = parseLabelsFromKey(key)
            
            // Use the type from the TYPE metadata, or create a default definition if not found
            let definition = metricDefinitions[baseName] ?? createDefaultDefinition(for: baseName)
            updatedMetrics[key] = TimeSeriesData(
                name: baseName,
                labels: labels,
                values: [(timestamp: timestamp, value: value, labels: labels)],
                definition: definition
            )
            metrics = updatedMetrics
        }
    }
    
    // Add helper function to parse labels from key
    private func parseLabelsFromKey(_ key: String) -> [String: String] {
        guard let openBrace = key.firstIndex(of: "{"),
              let closeBrace = key.lastIndex(of: "}") else {
            return [:]
        }
        
        let labelsString = String(key[openBrace...closeBrace])
        return parseLabels(labelsString)
    }
    
    // Add helper function to parse labels string
    private func parseLabels(_ labelsString: String) -> [String: String] {
        var labels: [String: String] = [:]
        let trimmedString = labelsString.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
        let labelPairs = trimmedString.split(separator: ",")
        
        for pair in labelPairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                // Remove quotes if present
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                labels[key] = value
            }
        }
        
        return labels
    }
    
    private func processHistogramData(name: String, labels: [String: String], buckets: [(le: Double, count: Double)], sum: Double, count: Double, timestamp: Date) {
        let key = metricKey(name: name, labels: labels)
        
        // Get existing histogram data or create new
        var histogramSeries = histogramData[key] ?? []
        
        // Update or create histogram data
        if let lastIndex = histogramSeries.lastIndex(where: { $0.timestamp == timestamp }) {
            var updatedData = histogramSeries[lastIndex]
            if sum > 0 {
                updatedData.sum = sum
            }
            if count > 0 {
                updatedData.count = count
            }
            updatedData.buckets = buckets
            histogramSeries[lastIndex] = updatedData
        } else {
            histogramSeries.append(HistogramData(
                buckets: buckets,
                sum: sum,
                count: count,
                timestamp: timestamp
            ))
        }
        
        // Keep only recent data
        let cutoff = Date().addingTimeInterval(-3600) // 1 hour
        histogramSeries.removeAll { $0.timestamp < cutoff }
        
        // Update histogram data
        histogramData[key] = histogramSeries
        
        // Update base metric with average value
        if let lastHistogram = histogramSeries.last {
            let definition = metricDefinitions[name] ?? MetricDefinition(
                name: name,
                description: "Histogram metric",
                type: .histogram
            )
            
            if var timeSeriesData = metrics[key] {
                timeSeriesData.addValue(lastHistogram.average, at: timestamp)
                metrics[key] = timeSeriesData
            } else {
                metrics[key] = TimeSeriesData(
                    name: name,
                    labels: labels,
                    values: [(timestamp: timestamp, value: lastHistogram.average, labels: labels)],
                    definition: definition
                )
            }
            
            // Calculate and store percentile values
            let percentiles = [50.0, 90.0, 99.0] // median, p90, p99
            for p in percentiles {
                let percentileName = "\(name)_p\(Int(p))"
                let percentileKey = metricKey(name: percentileName, labels: labels)
                let value = lastHistogram.percentile(p)
                
                if var timeSeriesData = metrics[percentileKey] {
                    timeSeriesData.addValue(value, at: timestamp)
                    metrics[percentileKey] = timeSeriesData
                } else {
                    let definition = MetricDefinition(
                        name: percentileName,
                        description: "P\(Int(p)) percentile of \(name)",
                        type: .gauge
                    )
                    metrics[percentileKey] = TimeSeriesData(
                        name: percentileName,
                        labels: labels,
                        values: [(timestamp: timestamp, value: value, labels: labels)],
                        definition: definition
                    )
                }
            }
        }
    }
} 
