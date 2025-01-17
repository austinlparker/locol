import Foundation
import os

class MetricStore {
    private let logger = Logger(subsystem: "io.aparker.locol", category: "MetricStore")
    
    // MARK: - Storage
    private(set) var metrics: [String: TimeSeriesData] = [:]
    private var histogramComponents: [String: (
        buckets: [(le: Double, count: Double)],
        sum: Double?,
        count: Double?,
        labels: [String: String],
        timestamp: Date,
        help: String?
    )] = [:]
    
    // MARK: - Public Methods
    
    func store(_ metric: PrometheusMetric) throws {
        let baseName = MetricFilter.getBaseName(metric.name)
        
        // Handle histogram components and complete histograms
        if metric.type == .histogram || MetricFilter.isHistogramComponent(metric.name) {
            try processHistogram(metric)
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
    
    func getHistogram(for key: String) -> HistogramMetric? {
        guard let metric = metrics[key],
              let type = metric.definition?.type,
              type == .histogram,
              let lastValue = metric.values.last else {
            return nil
        }
        return lastValue.histogram
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
                labels: labels,
                histogram: nil
            ))
        }
    }
    
    private func processHistogram(_ metric: PrometheusMetric) throws {
        let baseName = MetricFilter.getBaseName(metric.name)
        let timestamp = Date()
        
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
                    timestamp: timestamp,
                    help: metric.help
                )
            }
            
            // Update the appropriate component
            if let le = labels["le"]?.replacingOccurrences(of: "+Inf", with: "inf"),
               let leValue = le == "inf" ? Double.infinity : Double(le) {
                histogramComponents[key]?.buckets.append((le: leValue, count: value))
            } else if metric.name.hasSuffix("_sum") || (metric.type == .histogram && histogramComponents[key]?.sum == nil) {
                histogramComponents[key]?.sum = value
            } else if metric.name.hasSuffix("_count") || (metric.type == .histogram && histogramComponents[key]?.count == nil) {
                histogramComponents[key]?.count = value
            }
            
            // Check if we have all components
            if let components = histogramComponents[key],
               let sum = components.sum,
               let count = components.count,
               !components.buckets.isEmpty {
                // Create histogram using factory method
                let samples = components.buckets.map { bucket in
                    var labels = components.labels
                    labels["le"] = String(bucket.le)
                    return (labels: labels, value: bucket.count)
                } + [
                    (labels: components.labels, value: sum),
                    (labels: components.labels, value: count)
                ]
                
                if let histogram = HistogramMetric.from(samples: samples, timestamp: components.timestamp) {
                    // Store histogram in metrics
                    let definition = MetricDefinition(
                        name: baseName,
                        description: components.help ?? "",
                        type: .histogram
                    )
                    
                    if metrics[key] == nil {
                        metrics[key] = TimeSeriesData(
                            name: baseName,
                            labels: components.labels,
                            values: [],
                            definition: definition
                        )
                    }
                    
                    metrics[key]?.values.append((
                        timestamp: components.timestamp,
                        value: sum,  // Use sum as the main value
                        labels: components.labels,
                        histogram: histogram
                    ))
                    
                } else {
                    throw MetricError.invalidHistogramBuckets("Failed to create histogram from components: \(baseName)")
                }
                
                histogramComponents.removeValue(forKey: key)
            }
        }
    }
} 
