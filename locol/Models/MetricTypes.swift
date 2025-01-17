import Foundation

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
    struct Bucket: Comparable {
        let upperBound: Double
        let count: Double
        
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
                    return prevBound + fraction * (bucket.upperBound - prevBound)
                }
                return bucket.upperBound
            }
            prevCount = bucket.count
            prevBound = bucket.upperBound
        }
        
        return buckets.last?.upperBound ?? 0
    }
    
    /// Create a histogram from a set of samples that include buckets, sum, and count
    static func from(samples: [(labels: [String: String], value: Double)], timestamp: Date) -> HistogramMetric? {
        // Extract base labels (excluding 'le')
        let baseLabels = samples.first?.labels.filter { $0.key != "le" } ?? [:]
        
        // Collect buckets
        var buckets: [Bucket] = []
        var sum: Double?
        var count: Double?
        
        for (labels, value) in samples {
            if let le = labels["le"] {
                let upperBound = le == "+Inf" ? Double.infinity : Double(le) ?? Double.infinity
                buckets.append(Bucket(upperBound: upperBound, count: value))
            } else if labels == baseLabels {
                // This is either sum or count - determine by looking at other samples
                if samples.contains(where: { $0.labels == labels && $0.value != value }) {
                    // If there's another sample with same labels but different value,
                    // this must be the sum (since count should match bucket count)
                    sum = value
                } else {
                    count = value
                }
            }
        }
        
        // Validate we have all components
        guard let sum = sum,
              let count = count,
              !buckets.isEmpty else {
            return nil
        }
        
        // Sort buckets and validate monotonicity
        let sortedBuckets = buckets.sorted()
        var prevCount = 0.0
        for bucket in sortedBuckets {
            guard bucket.count >= prevCount else { return nil }
            prevCount = bucket.count
        }
        
        return HistogramMetric(
            buckets: sortedBuckets,
            sum: sum,
            count: count,
            timestamp: timestamp,
            labels: baseLabels
        )
    }
}
