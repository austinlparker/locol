import Foundation

struct TimeSeriesData {
    let name: String
    let labels: [String: String]
    var values: [(timestamp: Date, value: Double, labels: [String: String])]
    let definition: MetricDefinition?
    
    // Keep last hour of data by default
    let maxAge: TimeInterval = 3600
    
    mutating func addValue(_ value: Double, at timestamp: Date) {
        values.append((timestamp: timestamp, value: value, labels: labels))
        // Clean up old values
        let cutoff = Date().addingTimeInterval(-maxAge)
        values.removeAll { $0.timestamp < cutoff }
    }
} 