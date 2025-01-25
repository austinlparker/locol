import Foundation
import os
import Observation

@Observable
final class MetricsManager {
    static let shared = MetricsManager()
    
    private(set) var metrics: [String: [Metric]] = [:]
    private(set) var lastError: String?
    
    private var metricsCache: [String: [Metric]] = [:]
    private var updateTimer: Timer?
    private var scrapeTimer: Timer?
    private var histogramComponents: [String: (
        buckets: [(le: Double, count: Double)],
        sum: Double?,
        count: Double?,
        labels: [String: String],
        timestamp: Date,
        help: String?
    )] = [:]
    private let scrapeInterval: TimeInterval = 15
    private let updateInterval: TimeInterval = 1.0  // Update views every second
    private let logger = Logger.app
    private let maxAge: TimeInterval = 3600  // Keep last hour of data
    
    var urlSession: URLSession {
        URLSession.shared
    }
    
    // MARK: - Public Interface
    
    struct RateInfo {
        let rate: Double
        let timeWindow: TimeInterval
        let firstTimestamp: Date
        let lastTimestamp: Date
    }
    
    func startScraping() {
        stopScraping() // Stop any existing timers
        
        // Create a timer for scraping metrics
        scrapeTimer = Timer.scheduledTimer(withTimeInterval: scrapeInterval, repeats: true) { [weak self] _ in
            self?.scrapeMetrics()
        }
        scrapeTimer?.fire() // Initial scrape
        
        // Create a timer for updating the UI
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.publishUpdates()
        }
    }
    
    func stopScraping() {
        scrapeTimer?.invalidate()
        scrapeTimer = nil
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func getMetric(name: String, labels: [String: String]) -> [Metric]? {
        let key = metricKey(name: name, labels: labels)
        return metrics[key]
    }
    
    func calculateRate(for values: [Metric], preferredWindow: TimeInterval? = nil) -> RateInfo? {
        guard values.count >= 2,
              let first = values.first,
              let last = values.last else {
            return nil
        }
        
        // If a preferred window is specified, try to find values that span that window
        if let window = preferredWindow {
            let cutoff = last.timestamp.addingTimeInterval(-window)
            if let startIndex = values.firstIndex(where: { $0.timestamp >= cutoff }) {
                let first = values[max(startIndex - 1, 0)]  // Include one point before for accurate rate
                return calculateRateBetween(first: first, last: last)
            }
        }
        
        // Otherwise use all available data
        return calculateRateBetween(first: first, last: last)
    }
    
    private func calculateRateBetween(first: Metric, last: Metric) -> RateInfo? {
        let timeDelta = last.timestamp.timeIntervalSince(first.timestamp)
        guard timeDelta > 0 else {
            logger.error("Invalid time delta: \(timeDelta)")
            return nil
        }
        
        let rate = (last.value - first.value) / timeDelta
        return RateInfo(
            rate: rate,
            timeWindow: timeDelta,
            firstTimestamp: first.timestamp,
            lastTimestamp: last.timestamp
        )
    }
    
    // MARK: - Internal Methods
    
    func metricKey(name: String, labels: [String: String]) -> String {
        let sortedLabels = labels.sorted(by: { $0.key < $1.key })
        let labelString = sortedLabels.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        return "\(name){\(labelString)}"
    }
    
    // MARK: - Private Methods
    
    private func scrapeMetrics() {
        guard let url = URL(string: "http://localhost:8888/metrics") else {
            handleError("Invalid metrics URL")
            return
        }
        
        let task = urlSession.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                self?.handleError("Failed to fetch metrics: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self?.handleError("Invalid response type")
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                self?.handleError("HTTP error \(httpResponse.statusCode)")
                return
            }
            
            guard let data = data else {
                self?.handleError("No data received from metrics endpoint")
                return
            }
            
            guard let metricsString = String(data: data, encoding: .utf8) else {
                self?.handleError("Failed to decode metrics data as UTF-8")
                return
            }
            
            Task { @MainActor in
                self?.processMetrics(metricsString)
            }
        }
        task.resume()
    }
    
    func processMetrics(_ metricsString: String) {
        do {
            let metricGroups = try PrometheusParser.parse(metricsString)
            let timestamp = Date()
            for metric in metricGroups {
                do {
                    if metric.type == .histogram {
                        try processHistogramComponent(metric, timestamp: timestamp)
                    } else {
                        try processMetric(metric, timestamp: timestamp)
                    }
                } catch let error as MetricError {
                    logger.error("Error storing metric \(metric.name): \(error)")
                    handleError("Error storing metric \(metric.name): \(error.localizedDescription)")
                } catch {
                    logger.error("Unexpected error storing metric \(metric.name): \(error.localizedDescription)")
                    handleError("Unexpected error storing metric \(metric.name): \(error.localizedDescription)")
                }
            }
            // Only clear error if all metrics were processed successfully
            lastError = nil
            
            // Clean up old values
            cleanupOldValues()
            
            // Immediately publish updates
            publishUpdates()
        } catch {
            logger.error("Error parsing metrics: \(String(describing: error))")
            handleError("Error parsing metrics: \(error.localizedDescription)")
        }
    }
    
    private func processMetric(_ metric: PrometheusMetric, timestamp: Date) throws {
        let baseName = MetricFilter.getBaseName(metric.name)
        
        // Handle histogram components
        if MetricFilter.isHistogramComponent(metric.name) {
            try processHistogramComponent(metric, timestamp: timestamp)
            return
        }
        
        // Store regular metrics in cache
        for (labels, value) in metric.values {
            let key = metricKey(name: baseName, labels: labels)
            let newMetric = Metric(
                name: baseName,
                type: metric.type ?? .gauge,
                help: metric.help,
                labels: labels,
                timestamp: timestamp,
                value: value,
                histogram: nil
            )
            
            if metricsCache[key] == nil {
                metricsCache[key] = []
            }
            metricsCache[key]?.append(newMetric)
        }
    }
    
    private func processHistogramComponent(_ metric: PrometheusMetric, timestamp: Date) throws {
        let baseName = MetricFilter.getBaseName(metric.name)
        
        for (labels, value) in metric.values {
            let key = metricKey(name: baseName, labels: labels)
            
            if metric.name.hasSuffix("_bucket") {
                // Extract le value from labels
                guard let le = labels["le"] else {
                    throw MetricError.invalidHistogramBuckets("missing le label")
                }
                
                // Initialize histogram component if needed
                if histogramComponents[key] == nil {
                    histogramComponents[key] = (
                        buckets: [],
                        sum: nil,
                        count: nil,
                        labels: labels.filter { $0.key != "le" },
                        timestamp: timestamp,
                        help: metric.help
                    )
                }
                
                // Add bucket
                let leValue = le == "+Inf" ? Double.infinity : Double(le) ?? Double.infinity
                histogramComponents[key]?.buckets.append((le: leValue, count: value))
            } else if metric.name.hasSuffix("_sum") {
                histogramComponents[key]?.sum = value
            } else if metric.name.hasSuffix("_count") {
                histogramComponents[key]?.count = value
            }
            
            // If we have all components, create the histogram metric
            if let component = histogramComponents[key],
               let sum = component.sum,
               let count = component.count {
                // Create samples for histogram factory
                let samples = component.buckets.map { bucket in
                    let labels = component.labels.merging(["le": bucket.le == Double.infinity ? "+Inf" : String(bucket.le)]) { (_, new) in new }
                    return (labels: labels, value: bucket.count)
                } + [
                    (labels: component.labels, value: sum),
                    (labels: component.labels, value: count)
                ]
                
                if let histogram = HistogramMetric.from(samples: samples, timestamp: timestamp) {
                    let newMetric = Metric(
                        name: baseName,
                        type: .histogram,
                        help: component.help,
                        labels: component.labels,
                        timestamp: timestamp,
                        value: sum,
                        histogram: histogram
                    )
                    
                    if metricsCache[key] == nil {
                        metricsCache[key] = []
                    }
                    metricsCache[key]?.append(newMetric)
                    
                    // Clear the component
                    histogramComponents.removeValue(forKey: key)
                }
            }
        }
    }
    
    private func publishUpdates() {
        metrics = metricsCache
    }
    
    private func cleanupOldValues() {        
        let cutoff = Date().addingTimeInterval(-maxAge)
        
        for (key, values) in metricsCache {
            metricsCache[key] = values.filter { $0.timestamp >= cutoff }
            
            if metricsCache[key]?.isEmpty == true {
                metricsCache.removeValue(forKey: key)
            }
        }
    }
    
    private func handleError(_ message: String) {
        logger.error("\(message)")
        Task { @MainActor in
            self.lastError = message
        }
    }
} 
