import Foundation

struct HistogramBucket {
    let upperBound: Double
    let count: Double
    let cumulative: Bool
    
    var isInfinite: Bool {
        upperBound.isInfinite
    }
}

struct HistogramData {
    let buckets: [(le: Double, count: Double)]
    let sum: Double
    let count: Double
    let timestamp: Date
    
    var average: Double {
        count > 0 ? sum / count : 0
    }
    
    static func validate(_ buckets: [(le: Double, count: Double)]) -> Bool {
        // Ensure buckets are sorted
        let sortedBuckets = buckets.sorted(by: { $0.le < $1.le })
        guard buckets.count == sortedBuckets.count else { return false }
        
        for i in 0..<buckets.count {
            if buckets[i].le != sortedBuckets[i].le {
                return false
            }
        }
        
        // Ensure last bucket is +Inf
        guard let last = buckets.last, last.le.isInfinite else {
            return false
        }
        
        // Ensure counts are monotonically increasing (cumulative)
        for i in 1..<buckets.count {
            if buckets[i].count < buckets[i-1].count {
                return false
            }
        }
        
        return true
    }
    
    func percentile(_ p: Double) -> Double {
        guard !buckets.isEmpty, count > 0, p >= 0, p <= 100 else { return 0 }
        
        let target = (p / 100.0) * count
        var prev = (le: 0.0, count: 0.0)
        
        for bucket in buckets {
            if bucket.count >= target {
                // Linear interpolation between bucket boundaries
                let bucketRange = bucket.le - prev.le
                let countRange = bucket.count - prev.count
                let position = target - prev.count
                
                // Avoid division by zero
                if countRange == 0 {
                    return bucket.le
                }
                
                // If this is the first bucket or infinity, return the le value
                if prev.count == 0 || bucket.le.isInfinite {
                    return bucket.le
                }
                
                return prev.le + (bucketRange * (position / countRange))
            }
            prev = bucket
        }
        
        // If we get here, return the highest finite bucket's le
        return buckets.last?.le ?? 0
    }
    
    func bucketCount(upperBound: Double) -> Double {
        for bucket in buckets {
            if bucket.le >= upperBound {
                return bucket.count
            }
        }
        return buckets.last?.count ?? 0
    }
    
    var median: Double {
        percentile(50)
    }
    
    var p95: Double {
        percentile(95)
    }
    
    var p99: Double {
        percentile(99)
    }
} 