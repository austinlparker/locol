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
        self.id = MetricKeyGenerator.generateKey(name: name, labels: labels)
    }
}

struct HistogramMetric {
    private static let logger = Logger(subsystem: "io.aparker.locol", category: "HistogramMetric")
    
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
    
    var p50: Double { quantile(0.5) }
    var p95: Double { quantile(0.95) }
    var p99: Double { quantile(0.99) }
    
    var nonInfiniteBuckets: [Bucket] {
        buckets.enumerated().compactMap { index, bucket in
            guard !bucket.upperBound.isInfinite else { return nil }
            
            let lowerBound = index > 0 ? buckets[index - 1].upperBound : 0
            let bucketValue = index > 0 ? bucket.count - buckets[index - 1].count : bucket.count
            let percentage = (bucketValue / Double(count)) * 100
            
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
    
    /// Calculate any quantile (0-1) from the histogram buckets
    func quantile(_ q: Double) -> Double {
        guard q >= 0 && q <= 1 else { return 0 }
        guard !buckets.isEmpty else { return 0 }
        
        let target = count * q
        var prevCount = 0.0
        var prevBound = 0.0
        
        for bucket in buckets.sorted() {
            if bucket.count >= target {
                // Linear interpolation between bucket boundaries
                let countDelta = bucket.count - prevCount
                if countDelta > 0 {
                    let fraction = (target - prevCount) / countDelta
                    
                    // If this is the infinity bucket, use the previous bound
                    if bucket.upperBound.isInfinite {
                        return prevBound
                    }
                    
                    // Linear interpolation between bucket boundaries
                    if prevCount == 0 {
                        // For the first bucket, interpolate from 0
                        return bucket.upperBound * fraction
                    }
                    
                    let scale = (bucket.upperBound - prevBound)
                    return prevBound + scale * fraction
                }
                return bucket.upperBound
            }
            prevCount = bucket.count
            prevBound = bucket.upperBound
        }
        
        // If we get here, return the highest finite bucket's upper bound
        return buckets.sorted().dropLast().last?.upperBound ?? 0
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
}
