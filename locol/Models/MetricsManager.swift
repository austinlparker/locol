import Foundation
import Combine
import os

class MetricsManager: ObservableObject {
    static let shared = MetricsManager()
    
    @Published private(set) var store = MetricStore()
    @Published private(set) var lastError: String?
    
    private var timer: Timer?
    private let scrapeInterval: TimeInterval = 15
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "io.aparker.locol", category: "MetricsManager")
    
    var urlSession: URLSession {
        URLSession.shared
    }
    
    // MARK: - Public Interface
    
    var metrics: [String: TimeSeriesData] {
        store.metrics
    }
        
    func getRate(for metricKey: String, timeWindow: TimeInterval = 300) -> Double? {
        store.getRate(for: metricKey, timeWindow: timeWindow)
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
        do {
            let metricGroups = try PrometheusParser.parse(metricsString)
            for metric in metricGroups {
                try store.store(metric)
            }
            // Clear any previous error on success
            lastError = nil
        } catch {
            handleError("Error processing metrics: \(error.localizedDescription)")
        }
    }
    
    private func handleError(_ message: String) {
        logger.error("\(message)")
        DispatchQueue.main.async {
            self.lastError = message
        }
    }
} 
