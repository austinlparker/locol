import Foundation
import os

enum MetricType: String {
    case counter
    case gauge
    case histogram
}

struct Metric: Identifiable {
    let id: String  // Generated from name + labels
    let name: String
    let type: MetricType
    let help: String?
    let labels: [String: String]
    let timestamp: Date
    let value: Double
    let histogram: HistogramMetric?
    
    init(name: String, type: MetricType, help: String?, labels: [String: String], timestamp: Date, value: Double, histogram: HistogramMetric? = nil) {
        self.name = name
        self.type = type
        self.help = help
        self.labels = labels
        self.timestamp = timestamp
        self.value = value
        self.histogram = histogram
        // Generate unique ID from name and labels
        let labelString = labels.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ",")
        self.id = labelString.isEmpty ? name : "\(name){\(labelString)}"
    }
    
    func formatValueWithInferredUnit(_ value: Double) -> String {
        // Check for byte-based metrics
        let byteSuffixes = ["_bytes", "_byte", "_size"]
        let timeSuffixes = ["_seconds", "_second", "_duration", "_time", "_latency"]
        
        let isBytes = byteSuffixes.contains { name.hasSuffix($0) }
        let isTime = timeSuffixes.contains { name.hasSuffix($0) }
        
        if value == 0 {
            return isTime ? "0s" : "0"
        }
        
        if isBytes {
            let kb = 1024.0
            let mb = kb * 1024.0
            let gb = mb * 1024.0
            
            if value < kb {
                return String(format: "%.0fB", value)
            } else if value < mb {
                return String(format: "%.1fKB", value / kb)
            } else if value < gb {
                return String(format: "%.1fMB", value / mb)
            } else {
                return String(format: "%.1fGB", value / gb)
            }
        } else if isTime {
            if value < 0.001 {
                return String(format: "%.0fµs", value * 1_000_000)
            } else if value < 1 {
                return String(format: "%.1fms", value * 1_000)
            } else if value < 60 {
                return String(format: "%.1fs", value)
            } else if value < 3600 {
                return String(format: "%.1fm", value / 60)
            } else {
                return String(format: "%.1fh", value / 3600)
            }
        } else {
            // For non-byte values, use K/M/G suffixes based on magnitude
            if abs(value) < 1000 {
                return String(format: "%.1f", value)
            } else if abs(value) < 1_000_000 {
                return String(format: "%.1fK", value / 1000)
            } else if abs(value) < 1_000_000_000 {
                return String(format: "%.1fM", value / 1_000_000)
            } else {
                return String(format: "%.1fG", value / 1_000_000_000)
            }
        }
    }
}

struct HistogramMetric {
    private static let logger = Logger.app
    
    struct Bucket: Identifiable, Comparable {
        let id: Int
        let upperBound: Double
        let count: Double
        
        var bucketValue: Double = 0
        var lowerBound: Double = 0
        var percentage: Double = 0
        
        static func < (lhs: Bucket, rhs: Bucket) -> Bool {
            if lhs.upperBound == .infinity { return false }
            if rhs.upperBound == .infinity { return true }
            return lhs.upperBound < rhs.upperBound
        }
    }
    
    let buckets: [Bucket]
    let sum: Double
    let count: Double
    let timestamp: Date
    let labels: [String: String]
    
    var average: Double { sum / count }
    var totalCount: Double { count }  // Alias for count to match Prometheus terminology
    
    var p50: Double { quantile(0.5) }
    var p95: Double { quantile(0.95) }
    var p99: Double { quantile(0.99) }
    
    var nonInfiniteBuckets: [Bucket] {
        buckets.enumerated().compactMap { index, bucket in
            guard !bucket.upperBound.isInfinite else { return nil }
            
            let lowerBound = index > 0 ? buckets[index - 1].upperBound : 0
            let previousCount = index > 0 ? buckets[index - 1].count : 0
            let bucketValue = bucket.count - previousCount
            let percentage = count > 0 ? (bucketValue / count) * 100 : 0
            
            return Bucket(
                id: bucket.id,
                upperBound: bucket.upperBound,
                count: bucket.count,
                bucketValue: bucketValue,
                lowerBound: lowerBound,
                percentage: percentage
            )
        }
    }
    
    var xAxisDomain: ClosedRange<Double> {
        guard let max = nonInfiniteBuckets.map(\.upperBound).max() else {
            return 0...1 // Fallback range if no buckets
        }
        return 0...max
    }
    
    func bucketIndex(for value: Double) -> Int? {
        return nonInfiniteBuckets.firstIndex(where: { $0.upperBound >= value })
    }
    
    var p50Index: Int {
        nonInfiniteBuckets.firstIndex(where: { $0.upperBound >= p50 })!
    }
    
    var p95Index: Int {
        nonInfiniteBuckets.firstIndex(where: { $0.upperBound >= p95 })!
    }
    
    var p99Index: Int {
        nonInfiniteBuckets.firstIndex(where: { $0.upperBound >= p99 })!
    }
    
    func findClosestBucket(to index: Double) -> Bucket? {
        guard index >= 0, index < Double(nonInfiniteBuckets.count) else { return nil }
        let roundedIndex = Int(round(index))
        return nonInfiniteBuckets[roundedIndex]
    }
    
    /// Get the lower bound for a bucket at a given index
    func lowerBoundForBucket(at index: Int) -> Double {
        guard index > 0, index < nonInfiniteBuckets.count else { return 0 }
        return nonInfiniteBuckets[index - 1].upperBound
    }
    
    /// Get the bucket value (non-cumulative count) for a bucket at a given index
    func bucketValue(at index: Int) -> Double {
        guard index < nonInfiniteBuckets.count else { return 0 }
        let bucket = nonInfiniteBuckets[index]
        let previousCount = index > 0 ? nonInfiniteBuckets[index - 1].count : 0
        return bucket.count - previousCount
    }
    
    /// Calculate any quantile (0-1) from the histogram buckets using Prometheus's algorithm
    /// See: https://github.com/prometheus/prometheus/blob/main/promql/quantile.go
    func quantile(_ q: Double) -> Double {
        guard q >= 0 && q <= 1 else { return 0 }
        guard !buckets.isEmpty else { return 0 }
        
        let sortedBuckets = buckets.sorted()
        
        // Handle edge cases
        if q <= 0 {
            return 0
        }
        if q >= 1 {
            return sortedBuckets.dropLast().last?.upperBound ?? 0
        }
        
        // Find the bucket containing our target rank
        for (i, bucket) in sortedBuckets.enumerated() {
            if bucket.upperBound.isInfinite {
                continue
            }
            
            let nextRank = bucket.count / count
            if nextRank >= q {
                // Found the bucket containing our quantile
                let prevCount = i > 0 ? sortedBuckets[i-1].count : 0
                let prevRank = prevCount / count
                let prevBound = i > 0 ? sortedBuckets[i-1].upperBound : 0
                
                // Use linear interpolation between bucket boundaries
                if bucket.count == prevCount {
                    return bucket.upperBound
                }
                
                let bucketRank = (q - prevRank) / (nextRank - prevRank)
                return prevBound + (bucket.upperBound - prevBound) * bucketRank
            }
        }
        
        // If we get here, return the highest finite bucket
        return sortedBuckets.dropLast().last?.upperBound ?? 0
    }
    
    /// Infer the unit type from a metric name and format the value accordingly
    func formatValueWithInferredUnit(_ value: Double, metricName: String) -> String {
        // Common suffixes that indicate byte values
        let byteSuffixes = ["_bytes", "_byte", "_size"]
        let timeSuffixes = ["_seconds", "_second", "_duration", "_time", "_latency"]
        
        let isBytes = byteSuffixes.contains { metricName.hasSuffix($0) }
        let isTime = timeSuffixes.contains { metricName.hasSuffix($0) }
        
        if isBytes {
            // Format as bytes with appropriate unit
            if value == 0 { return "0 B" }
            if value < 1024 { return String(format: "%.0f B", value) }
            if value < 1024 * 1024 { return String(format: "%.1f KB", value / 1024) }
            if value < 1024 * 1024 * 1024 { return String(format: "%.1f MB", value / (1024 * 1024)) }
            return String(format: "%.1f GB", value / (1024 * 1024 * 1024))
        }
        
        if isTime {
            // Format as time duration
            if value == 0 { return "0s" }
            if value < 0.001 { return String(format: "%.0f µs", value * 1_000_000) }
            if value < 1 { return String(format: "%.0f ms", value * 1_000) }
            if value < 60 { return String(format: "%.1f s", value) }
            if value < 3600 { return String(format: "%.1f m", value / 60) }
            return String(format: "%.1f h", value / 3600)
        }
        
        // Default formatting for non-byte values
        if value == 0 { return "0" }
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        if value < 0.01 { return String(format: "%.2e", value) }
        if value >= 100 { return String(format: "%.0f", value) }
        if value >= 10 { return String(format: "%.1f", value) }
        return String(format: "%.2f", value)
    }
    
    /// Create a histogram from a set of samples that include buckets, sum, and count
    static func from(samples: [(labels: [String: String], value: Double)], timestamp: Date) -> HistogramMetric? {
        // Extract base labels (excluding 'le')
        let baseLabels = samples.first?.labels.filter { $0.key != "le" } ?? [:]
        logger.debug("Base labels: \(baseLabels.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))")
        
        // Collect buckets
        var buckets: [Bucket] = []
        var sum: Double?
        var count: Double?
        var bucketId = 0
        
        for (labels, value) in samples {
            if let le = labels["le"] {
                let upperBound = le == "+Inf" ? Double.infinity : Double(le) ?? Double.infinity
                buckets.append(Bucket(id: bucketId, upperBound: upperBound, count: value))
                bucketId += 1
                logger.debug("Added bucket: le=\(le), count=\(value)")
            } else if labels.isEmpty || labels == baseLabels {
                // This must be either sum or count
                // We'll determine which by checking if we already have a value
                // The first one we see is sum, the second is count
                if sum == nil {
                    sum = value
                    logger.debug("Found sum: \(value)")
                } else {
                    count = value
                    logger.debug("Found count: \(value)")
                }
            } else {
                logger.debug("Skipping sample with labels: \(labels.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))")
            }
        }
        
        // Validate we have all components
        guard let sum = sum,
              let count = count,
              !buckets.isEmpty else {
            logger.error("Missing required components: sum=\(String(describing: sum)), count=\(String(describing: count)), buckets=\(buckets.count)")
            return nil
        }
        
        // Sort buckets and validate monotonicity
        let sortedBuckets = buckets.sorted()
        var prevCount = 0.0
        for bucket in sortedBuckets {
            guard bucket.count >= prevCount else {
                logger.error("Non-monotonic bucket detected: previous count \(prevCount), current count \(bucket.count)")
                return nil
            }
            prevCount = bucket.count
        }
        
        logger.debug("Successfully created histogram with \(buckets.count) buckets")
        return HistogramMetric(
            buckets: sortedBuckets,
            sum: sum,
            count: count,
            timestamp: timestamp,
            labels: baseLabels
        )
    }
    
    var chartDomain: ClosedRange<Double> {
        -0.5...Double(nonInfiniteBuckets.count - 1) + 0.5
    }
    
    var maxBucketValue: Double {
        nonInfiniteBuckets.map(\.bucketValue).max() ?? 0
    }
    
    func bucketAtIndex(_ index: Int) -> Bucket? {
        guard index >= 0 && index < nonInfiniteBuckets.count else { return nil }
        return nonInfiniteBuckets[index]
    }
    
    func findBucketIndex(forQuantile q: Double) -> Int {
        var rank = 0.0
        for (i, bucket) in nonInfiniteBuckets.enumerated() {
            rank += bucket.count / Double(totalCount)
            if rank >= q {
                return i
            }
        }
        return nonInfiniteBuckets.count - 1
    }
}
