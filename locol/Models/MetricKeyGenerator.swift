import Foundation
import os

class MetricKeyGenerator {
    private static let logger = Logger(subsystem: "io.aparker.locol", category: "MetricKeyGenerator")
    
    static func generateKey(name: String, labels: [String: String]) -> String {
        // Filter out "le" and "__name__" labels but keep service labels
        let relevantLabels = labels.filter { key, _ in
            key != "le" && key != "__name__"
        }
        
        // If no relevant labels, return the base name
        if relevantLabels.isEmpty {
            return name
        }
        
        let sortedLabels = relevantLabels.sorted(by: { $0.key < $1.key })
        let labelString = sortedLabels.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: ",")
        let key = "\(name){\(labelString)}"
        
        return key
    }
    
    static func removeLabels(_ labels: [String: String], including: [String]) -> [String: String] {
        labels.filter { key, _ in
            !including.contains(key)
        }
    }
} 
