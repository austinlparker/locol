import Foundation

/// Represents the type of a Prometheus metric
enum MetricType: String {
    case counter = "counter"
    case gauge = "gauge"
    case histogram = "histogram"
}

/// Represents a metric definition from Prometheus HELP and TYPE metadata
struct MetricDefinition {
    let name: String
    let description: String
    let type: MetricType
}

/// Represents a histogram metric with buckets and calculated quantiles
struct HistogramMetric {
    /// Represents a single bucket in a histogram
    struct Bucket: Comparable {
        let upperBound: Double
        let count: Double
        
        static func < (lhs: Bucket, rhs: Bucket) -> Bool {
            lhs.upperBound < rhs.upperBound
        }
    }
    
    let timestamp: Date
    let labels: [String: String]  // Labels excluding 'le'
    let buckets: [Bucket]
    let sum: Double
    let count: Double
    
    /// The average value (sum/count)
    var average: Double? {
        guard count > 0 else { return nil }
        return sum / count
    }
    
    /// The median (50th percentile)
    var p50: Double? {
        return quantile(0.5)
    }
    
    /// The 95th percentile
    var p95: Double? {
        return quantile(0.95)
    }
    
    /// The 99th percentile
    var p99: Double? {
        return quantile(0.99)
    }
    
    /// Calculate any quantile from the histogram buckets
    /// - Parameter q: The quantile to calculate (0.0 to 1.0)
    /// - Returns: The calculated quantile value, or nil if it cannot be calculated
    private func quantile(_ q: Double) -> Double? {
        guard !buckets.isEmpty, count > 0 else { return nil }
        
        let target = count * q
        let sortedBuckets = buckets.sorted()
        
        // Handle special cases
        if target <= 0 {
            return sortedBuckets.first?.upperBound
        }
        if target >= count {
            return sortedBuckets.last?.upperBound
        }
        
        // Find the bucket containing our target
        var prevCount = 0.0
        for (i, bucket) in sortedBuckets.enumerated() {
            if bucket.count >= target {
                // If this is the first bucket, use its upper bound
                if i == 0 {
                    return bucket.upperBound
                }
                
                // Linear interpolation between bucket boundaries
                let prevBucket = sortedBuckets[i - 1]
                let countInBucket = bucket.count - prevCount
                if countInBucket <= 0 {
                    return bucket.upperBound
                }
                
                let position = (target - prevCount) / countInBucket
                return prevBucket.upperBound + position * (bucket.upperBound - prevBucket.upperBound)
            }
            prevCount = bucket.count
        }
        
        return sortedBuckets.last?.upperBound
    }
    
    /// Create a histogram metric from raw Prometheus samples
    /// - Parameters:
    ///   - samples: The raw samples from the parser
    ///   - timestamp: The timestamp for this metric
    /// - Returns: A new HistogramMetric, or nil if the samples are invalid
    static func from(samples: [(labels: [String: String], value: Double)], timestamp: Date) -> HistogramMetric? {
        var buckets: [Bucket] = []
        var sum: Double?
        var count: Double?
        var baseLabels: [String: String] = [:]
        
        // First bucket sample determines base labels (excluding 'le')
        if let firstBucketSample = samples.first(where: { $0.labels["le"] != nil }) {
            baseLabels = firstBucketSample.labels.filter { $0.key != "le" }
        }
        
        // Process each sample
        for sample in samples {
            if let le = sample.labels["le"] {
                let upperBound = le == "+Inf" || le == "inf" ? Double.infinity : Double(le) ?? Double.infinity
                buckets.append(Bucket(upperBound: upperBound, count: sample.value))
            } else {
                // Sample without 'le' is either sum or count
                let sampleLabels = sample.labels
                if sampleLabels == baseLabels {
                    // Check if this sample is from a _sum or _count suffix
                    if let name = sampleLabels["__name__"] {
                        if name.hasSuffix("_sum") {
                            sum = sample.value
                        } else if name.hasSuffix("_count") {
                            count = sample.value
                        }
                    }
                }
            }
        }
        
        // Validate we have all required components
        guard let finalSum = sum,
              let finalCount = count,
              !buckets.isEmpty else {
            return nil
        }
        
        return HistogramMetric(
            timestamp: timestamp,
            labels: baseLabels,
            buckets: buckets.sorted(),
            sum: finalSum,
            count: finalCount
        )
    }
}

/// Represents a time series of metric values
struct TimeSeriesData {
    let name: String
    let labels: [String: String]
    var values: [(timestamp: Date, value: Double, labels: [String: String], histogram: HistogramMetric?)]
    let definition: MetricDefinition?
    
    /// Keep last hour of data by default
    let maxAge: TimeInterval = 3600
    
    /// Add a new value to the time series
    /// - Parameters:
    ///   - value: The metric value
    ///   - timestamp: The timestamp for this value
    mutating func addValue(_ value: Double, at timestamp: Date) {
        values.append((timestamp: timestamp, value: value, labels: labels, histogram: nil))
        // Clean up old values
        let cutoff = Date().addingTimeInterval(-maxAge)
        values.removeAll { $0.timestamp < cutoff }
    }
}
