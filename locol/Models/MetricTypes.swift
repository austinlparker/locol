import Foundation
import os

private let logger = Logger(subsystem: "io.aparker.locol", category: "MetricTypes")

enum MetricType: String {
    case counter = "counter"
    case histogram = "histogram"
    case gauge = "gauge"
}

// Metric filtering and categorization
struct MetricFilter {
    static let excludedMetrics = ["target_metadata", "target_info"]
    
    static func isExcluded(_ name: String) -> Bool {
        excludedMetrics.contains(name)
    }
    
    static func isHistogramComponent(_ name: String) -> Bool {
        name.hasSuffix("_sum") || name.hasSuffix("_count") || name.hasSuffix("_bucket")
    }
    
    static func getBaseName(_ name: String) -> String {
        name.replacingOccurrences(of: "_bucket", with: "")
            .replacingOccurrences(of: "_sum", with: "")
            .replacingOccurrences(of: "_count", with: "")
    }
    
    static func isHistogram(_ metric: TimeSeriesData) -> Bool {
        guard let type = metric.definition?.type else { return false }
        // A metric is a histogram if:
        // 1. It's of type histogram
        // 2. Either it's a base metric (no suffixes) or it's a bucket metric
        return type == .histogram && (
            metric.name == getBaseName(metric.name) ||
            metric.name.hasSuffix("_bucket")
        )
    }
}

// Metric definition
struct MetricDefinition {
    let name: String
    let description: String
    let type: MetricType
}

// Histogram specific types
struct HistogramData {
    var buckets: [(le: Double, count: Double)]
    var sum: Double
    var count: Double
    let timestamp: Date
    
    var average: Double {
        count > 0 ? sum / count : 0
    }
    
    func percentile(_ p: Double) -> Double {
        guard !buckets.isEmpty && count > 0 else { return 0 }
        
        // Sort buckets and ensure they're cumulative
        let sortedBuckets = buckets
            .filter { !$0.le.isInfinite }
            .sorted { $0.le < $1.le }
        
        guard !sortedBuckets.isEmpty else { return 0 }
        
        // Calculate target count for this percentile
        let targetCount = (p / 100.0) * count
        
        // Find the bucket containing our target percentile
        var prevCount: Double = 0
        for i in 0..<sortedBuckets.count {
            let bucket = sortedBuckets[i]
            
            if bucket.count >= targetCount {
                // Found the bucket containing our percentile
                if i == 0 {
                    // If it's the first bucket, assume linear distribution from 0
                    return bucket.le * (targetCount / bucket.count)
                }
                
                let prevBucket = sortedBuckets[i - 1]
                let bucketCount = bucket.count - prevCount
                
                if bucketCount == 0 {
                    // If bucket is empty, use lower bound
                    return prevBucket.le
                }
                
                // Calculate how far into this bucket our target lies
                let countFromPrev = targetCount - prevCount
                let fraction = countFromPrev / bucketCount
                
                // Interpolate within the bucket
                return prevBucket.le + (bucket.le - prevBucket.le) * fraction
            }
            prevCount = bucket.count
        }
        
        // If we get here, use the highest bucket's upper bound
        return sortedBuckets.last?.le ?? 0
    }
}

// Collection of metrics organized by type
struct MetricCollection {
    let histograms: [TimeSeriesData]
    let regular: [TimeSeriesData]
    
    init(metrics: [String: TimeSeriesData]) {
        let totalCount = metrics.count
        logger.debug("Creating MetricCollection with \(totalCount) metrics")
        
        // Log all metric names and types
        for (key, metric) in metrics {
            logger.debug("Metric: \(key) - Type: \(metric.definition?.type.rawValue ?? "unknown")")
        }
        
        let filtered = metrics.values.filter { !MetricFilter.isExcluded($0.name) }
        let filteredCount = filtered.count
        logger.debug("After exclusion filter: \(filteredCount) metrics")
        
        let histogramMetrics = filtered.filter(MetricFilter.isHistogram)
            .sorted { $0.name < $1.name }
        
        let regularMetrics = filtered.filter { metric in
            guard let type = metric.definition?.type else { return false }
            return type != .histogram && !MetricFilter.isHistogramComponent(metric.name)
        }.sorted { $0.name < $1.name }
        
        self.histograms = histogramMetrics
        self.regular = regularMetrics
        
        let histogramCount = histogramMetrics.count
        let regularCount = regularMetrics.count
        logger.debug("Final counts - Histograms: \(histogramCount), Regular: \(regularCount)")
        
        // Log details about each histogram metric
        for histogram in histogramMetrics {
            logger.debug("Histogram details for \(histogram.name):")
            logger.debug("- Labels: \(histogram.labels)")
            logger.debug("- Values count: \(histogram.values.count)")
        }
    }
} 
