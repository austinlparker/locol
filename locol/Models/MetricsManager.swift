import Foundation
import Combine
import os

class MetricsManager: ObservableObject {
    static let shared = MetricsManager()
    
    @Published private(set) var metrics: [String: [Metric]] = [:]
    @Published private(set) var lastError: String?
    
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
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "io.aparker.locol", category: "MetricsManager")
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
        let firstValue: Double
        let lastValue: Double
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
            lastTimestamp: last.timestamp,
            firstValue: first.value,
            lastValue: last.value
        )
    }
    
    func getRate(for metricKey: String, timeWindow: TimeInterval? = nil) -> Double? {
        guard let values = metrics[metricKey],
              let type = values.first?.type,
              type == .counter else {
            return nil
        }
        
        return calculateRate(for: values, preferredWindow: timeWindow)?.rate
    }
    
    // MARK: - Scraping Control
    
    func startScraping() {
        stopScraping() // Ensure we don't have multiple timers
        
        // Start the scrape timer
        scrapeTimer = Timer.scheduledTimer(withTimeInterval: scrapeInterval, repeats: true) { [weak self] _ in
            self?.scrapeMetrics()
        }
        
        // Start the update timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.publishUpdates()
        }
        
        // Do an initial scrape
        scrapeMetrics()
    }
    
    func stopScraping() {
        scrapeTimer?.invalidate()
        scrapeTimer = nil
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - Metric Key Generation
    
    func metricKey(name: String, labels: [String: String]) -> String {
        MetricKeyGenerator.generateKey(name: name, labels: labels)
    }
    
    // MARK: - Private Methods
    
    private func scrapeMetrics() {
        guard let url = URL(string: "http://localhost:8888/metrics") else {
            handleError("Failed to create metrics URL")
            return
        }
        
        let task = urlSession.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                self?.handleError("Network error while scraping metrics: \(error.localizedDescription)")
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
            
            DispatchQueue.main.async {
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
            let baseLabels = labels.filter { $0.key != "le" }
            let key = metricKey(name: baseName, labels: baseLabels)
            
            // Initialize if needed
            if histogramComponents[key] == nil {
                histogramComponents[key] = (
                    buckets: [],
                    sum: nil,
                    count: nil,
                    labels: baseLabels,
                    timestamp: timestamp,
                    help: metric.help
                )
            }
            
            let originalName = labels["__name__"] ?? metric.name
            
            // Update component based on metric name suffix
            if let le = labels["le"] {
                // This is a bucket
                let leValue = le == "+Inf" ? Double.infinity : Double(le) ?? Double.infinity
                // Remove any existing bucket with the same le value
                self.histogramComponents[key]?.buckets.removeAll { $0.le == leValue }
                // Add the new bucket
                self.histogramComponents[key]?.buckets.append((le: leValue, count: value))
                // Sort buckets by le value
                self.histogramComponents[key]?.buckets.sort { $0.le < $1.le }
            } else if originalName.hasSuffix("_sum") {
                histogramComponents[key]?.sum = value
            } else if originalName.hasSuffix("_count") {
                histogramComponents[key]?.count = value
            }
            
            // Try to finalize after each component update
            try finalizeHistogramIfComplete(key: key)
        }
    }
    
    private func finalizeHistogramIfComplete(key: String) throws {
        guard let components = histogramComponents[key] else {
            return
        }
        
        // Only proceed if we have all components
        guard let sum = components.sum,
              let count = components.count,
              !components.buckets.isEmpty else {
            return
        }
        
        // Ensure buckets are properly sorted
        let sortedBuckets = components.buckets.sorted { $0.le < $1.le }
        
        // Create samples for histogram factory
        let samples = sortedBuckets.map { bucket in
            let labels = components.labels.merging(["le": bucket.le == Double.infinity ? "+Inf" : String(bucket.le)]) { (_, new) in new }
            return (labels: labels, value: bucket.count)
        } + [
            (labels: components.labels, value: sum),
            (labels: components.labels, value: count)
        ]
        
        if let histogram = HistogramMetric.from(samples: samples, timestamp: components.timestamp) {
            let baseName = key.components(separatedBy: "{").first ?? key
            let metric = Metric(
                name: baseName,
                type: .histogram,
                help: components.help,
                labels: components.labels,
                timestamp: components.timestamp,
                value: sum,
                histogram: histogram
            )
            
            if metricsCache[key] == nil {
                metricsCache[key] = []
            }
            metricsCache[key]?.append(metric)
            histogramComponents.removeValue(forKey: key)
        } else {
            logger.error("Failed to create histogram from samples")
            throw MetricError.invalidHistogramBuckets(key)
        }
    }
    
    private func publishUpdates() {
        // Since we're already on the main thread in processMetrics, 
        // we don't need to dispatch again
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
        DispatchQueue.main.async {
            self.lastError = message
        }
    }
} 
