import Foundation
import os

class MetricKeyGenerator {
    private static let logger = Logger(subsystem: "io.aparker.locol", category: "MetricKeyGenerator")
    
    static func generateKey(name: String, labels: [String: String]) -> String {
        // Filter out "le" label but keep service labels
        let relevantLabels = labels.filter { key, _ in
            key != "le"
        }
        
        // If no relevant labels, return the base name
        if relevantLabels.isEmpty {
            logger.debug("Generated key for \(name) with no labels")
            return name
        }
        
        let sortedLabels = relevantLabels.sorted(by: { $0.key < $1.key })
        let labelString = sortedLabels.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: ",")
        let key = "\(name){\(labelString)}"
        
        logger.debug("Generated key: \(key)")
        logger.debug("- From name: \(name)")
        logger.debug("- Original labels: \(labels)")
        logger.debug("- Filtered labels: \(relevantLabels)")
        
        return key
    }
    
    static func removeLabels(_ labels: [String: String], including: [String]) -> [String: String] {
        labels.filter { key, _ in
            !including.contains(key)
        }
    }
} 
