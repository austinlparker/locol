import Foundation
import os

class MetricStore {
    private let logger = Logger(subsystem: "io.aparker.locol", category: "MetricStore")
    
    // MARK: - Storage
    private(set) var metrics: [String: TimeSeriesData] = [:]
    private(set) var histogramData: [String: [HistogramData]] = [:]
    private var metricDefinitions: [String: MetricDefinition] = [:]
    private var histogramComponents: [String: (
        buckets: [(le: Double, count: Double)],
        sum: Double?,
        count: Double?,
        labels: [String: String],
        timestamp: Date
    )] = [:]
    
    // MARK: - Public Methods
    
    func store(_ metric: PrometheusMetric) throws {
        let baseName = MetricFilter.getBaseName(metric.name)
        
        // Handle histogram components
        if MetricFilter.isHistogramComponent(metric.name) || metric.type == .histogram {
            try processHistogramComponent(metric)
            return
        }
        
        // Handle regular metrics
        try storeRegularMetric(metric)
    }
    
    func getRate(for metricKey: String, timeWindow: TimeInterval = 300) -> Double? {
        guard let metric = metrics[metricKey],
              let type = metric.definition?.type,
              type == .counter else {
            return nil
        }
        
        return CounterData.calculateRate(for: metric.values, timeWindow: timeWindow)
    }
    
    // MARK: - Private Methods
    
    private func storeRegularMetric(_ metric: PrometheusMetric) throws {
        guard let type = metric.type else {
            throw MetricError.malformedMetricLine("Missing metric type for \(metric.name)")
        }
        
        // Create or update metric definition
        let definition = MetricDefinition(
            name: metric.name,
            description: metric.help ?? "",
            type: type
        )
        metricDefinitions[metric.name] = definition
        
        // Store values
        for (labels, value) in metric.values {
            let key = MetricKeyGenerator.generateKey(name: metric.name, labels: labels)
            
            // For counters, check for resets
            if type == .counter,
               let lastValue = metrics[key]?.values.last?.value,
               value < lastValue {
                logger.warning("Counter reset detected for metric: \(metric.name)")
            }
            
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
    
    private func processHistogramComponent(_ metric: PrometheusMetric) throws {
        let baseName = MetricFilter.getBaseName(metric.name)
        let timestamp = Date()
        
        logger.debug("Processing histogram component: \(metric.name)")
        logger.debug("Base name: \(baseName)")
        
        for (labels, value) in metric.values {
            // Create base labels without 'le'
            var baseLabels = labels
            baseLabels.removeValue(forKey: "le")
            let key = MetricKeyGenerator.generateKey(name: baseName, labels: baseLabels)
            
            // Initialize component tracking if needed
            if histogramComponents[key] == nil {
                histogramComponents[key] = (
                    buckets: [],
                    sum: nil,
                    count: nil,
                    labels: baseLabels,
                    timestamp: timestamp
                )
            }
            
            // Update the appropriate component
            if metric.name.hasSuffix("_bucket"),
               let le = labels["le"]?.replacingOccurrences(of: "+Inf", with: "inf"),
               let leValue = Double(le) {
                histogramComponents[key]?.buckets.append((le: leValue, count: value))
            } else if metric.name.hasSuffix("_sum") {
                histogramComponents[key]?.sum = value
            } else if metric.name.hasSuffix("_count") {
                histogramComponents[key]?.count = value
            }
            
            // Check if we have all components
            if let components = histogramComponents[key],
               let sum = components.sum,
               let count = components.count,
               !components.buckets.isEmpty {
                try finalizeHistogram(key: key, components: components)
            }
        }
    }
    
    private func finalizeHistogram(key: String, components: (buckets: [(le: Double, count: Double)], sum: Double?, count: Double?, labels: [String: String], timestamp: Date)) throws {
        guard let sum = components.sum,
              let count = components.count else {
            throw MetricError.invalidHistogramBuckets("Missing sum or count for histogram: \(key)")
        }
        
        // Validate buckets
        let sortedBuckets = components.buckets.sorted(by: { $0.le < $1.le })
        guard HistogramData.validate(sortedBuckets) else {
            throw MetricError.invalidHistogramBuckets("Invalid bucket configuration for histogram: \(key)")
        }
        
        // Create HistogramData
        let histogramData = HistogramData(
            buckets: sortedBuckets,
            sum: sum,
            count: count,
            timestamp: components.timestamp
        )
        
        // Update histogramData collection
        if self.histogramData[key] == nil {
            self.histogramData[key] = []
        }
        self.histogramData[key]?.append(histogramData)
        
        // Clean up old data
        let cutoff = Date().addingTimeInterval(-3600)
        self.histogramData[key]?.removeAll { $0.timestamp < cutoff }
        
        // Remove processed components
        histogramComponents.removeValue(forKey: key)
    }
} 
