import Foundation
import os

class MetricFilter {
    private static let logger = Logger(subsystem: "io.aparker.locol", category: "MetricFilter")
    private static let excludedMetrics = ["target_metadata", "target_info"]
    
    static func isExcluded(_ name: String) -> Bool {
        excludedMetrics.contains(name)
    }
    
    static func isHistogramComponent(_ name: String) -> Bool {
        name.hasSuffix("_bucket") || name.hasSuffix("_sum") || name.hasSuffix("_count")
    }
    
    static func getBaseName(_ name: String) -> String {
        if name.hasSuffix("_bucket") {
            return String(name.dropLast(7))
        } else if name.hasSuffix("_sum") {
            return String(name.dropLast(4))
        } else if name.hasSuffix("_count") {
            return String(name.dropLast(6))
        }
        return name
    }
    
    static func isHistogramMetric(_ name: String) -> Bool {
        name.hasSuffix("_bucket") || name.hasSuffix("_sum") || name.hasSuffix("_count")
    }
    
    static func getHistogramComponent(_ name: String) -> String? {
        if name.hasSuffix("_bucket") {
            return "bucket"
        } else if name.hasSuffix("_sum") {
            return "sum"
        } else if name.hasSuffix("_count") {
            return "count"
        }
        return nil
    }
    
    static func isHistogram(_ metric: Metric) -> Bool {
        metric.type == .histogram
    }
} 