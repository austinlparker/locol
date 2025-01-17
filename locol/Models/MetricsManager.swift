import Foundation
import Combine
import os

class MetricsManager: ObservableObject {
    static let shared = MetricsManager()
    
    @Published private(set) var metrics: [String: [Metric]] = [:]
    @Published private(set) var lastError: String?
    
    private var timer: Timer?
    private var histogramComponents: [String: (
        buckets: [(le: Double, count: Double)],
        sum: Double?,
        count: Double?,
        labels: [String: String],
        timestamp: Date,
        help: String?
    )] = [:]
    private let scrapeInterval: TimeInterval = 15
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "io.aparker.locol", category: "MetricsManager")
    private let maxAge: TimeInterval = 3600  // Keep last hour of data
    
    var urlSession: URLSession {
        URLSession.shared
    }
    
    // MARK: - Public Interface
    
    func getRate(for metricKey: String, timeWindow: TimeInterval = 300) -> Double? {
        guard let values = metrics[metricKey],
              let type = values.first?.type,
              type == .counter else {
            return nil
        }
        
        // Calculate rate from last two values
        guard values.count >= 2 else { return nil }
        let recentValues = values.suffix(2)
        let first = recentValues.first!
        let last = recentValues.last!
        
        let timeDelta = last.timestamp.timeIntervalSince(first.timestamp)
        guard timeDelta > 0 else { return nil }
        
        return (last.value - first.value) / timeDelta
    }
    
    // MARK: - Initialization
    
    init() {
        logger.debug("MetricsManager initialized")
    }
    
    deinit {
        logger.debug("MetricsManager being deallocated")
        stopScraping()
    }
    
    // MARK: - Scraping Control
    
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
        logger.debug("Parsing metrics string of length: \(metricsString.count)")
        do {
            let metricGroups = try PrometheusParser.parse(metricsString)
            for metric in metricGroups {
                do {
                    try processMetric(metric)
                } catch let error as MetricError {
                    // Log the specific error but continue processing other metrics
                    logger.error("Error storing metric \(metric.name): \(error.localizedDescription)")
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
        } catch {
            logger.error("Error parsing metrics: \(error.localizedDescription)")
            handleError("Error parsing metrics: \(error.localizedDescription)")
        }
    }
    
    private func processMetric(_ metric: PrometheusMetric) throws {
        let baseName = MetricFilter.getBaseName(metric.name)
        let timestamp = Date()
        
        // Handle histogram components
        if MetricFilter.isHistogramComponent(metric.name) {
            try processHistogramComponent(metric, timestamp: timestamp)
            return
        }
        
        // Store regular metrics
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
            
            if metrics[key] == nil {
                metrics[key] = []
            }
            metrics[key]?.append(newMetric)
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
            
            // Update component based on metric name suffix
            switch true {
            case metric.name.hasSuffix("_bucket"):
                if let le = labels["le"]?.replacingOccurrences(of: "+Inf", with: "inf"),
                   let leValue = le == "inf" ? Double.infinity : Double(le) {
                    histogramComponents[key]?.buckets.append((le: leValue, count: value))
                }
            case metric.name.hasSuffix("_sum"):
                histogramComponents[key]?.sum = value
            case metric.name.hasSuffix("_count"):
                histogramComponents[key]?.count = value
            default:
                break
            }
            
            try finalizeHistogramIfComplete(key: key)
        }
    }
    
    private func finalizeHistogramIfComplete(key: String) throws {
        guard let components = histogramComponents[key] else { return }
        
        // Only proceed if we have all components
        guard let sum = components.sum,
              let count = components.count,
              !components.buckets.isEmpty else {
            return
        }
        
        // Create samples for histogram factory
        let samples = components.buckets.map { bucket in
            (labels: components.labels.merging(["le": bucket.le == Double.infinity ? "+Inf" : String(bucket.le)]) { (_, new) in new }, value: bucket.count)
        } + [
            (labels: components.labels, value: sum),
            (labels: components.labels, value: count)
        ]
        
        if let histogram = HistogramMetric.from(samples: samples, timestamp: components.timestamp) {
            let metric = Metric(
                name: MetricFilter.getBaseName(key),
                type: .histogram,
                help: components.help,
                labels: components.labels,
                timestamp: components.timestamp,
                value: sum,
                histogram: histogram
            )
            
            if metrics[key] == nil {
                metrics[key] = []
            }
            metrics[key]?.append(metric)
            histogramComponents.removeValue(forKey: key)
        }
    }
    
    private func cleanupOldValues() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        for (key, values) in metrics {
            metrics[key] = values.filter { $0.timestamp >= cutoff }
            if metrics[key]?.isEmpty == true {
                metrics.removeValue(forKey: key)
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
