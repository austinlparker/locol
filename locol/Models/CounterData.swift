import Foundation

struct CounterData {
    let timestamp: Date
    let value: Double
    let labels: [String: String]
    
    func calculateRate(previous: CounterData, handleReset: Bool = true) -> Double? {
        let timeDelta = timestamp.timeIntervalSince(previous.timestamp)
        guard timeDelta > 0 else { return nil }
        
        var valueDelta = value - previous.value
        
        // Handle counter resets
        if handleReset && valueDelta < 0 {
            // Assume counter reset to 0 and started counting up again
            valueDelta = value
        }
        
        return valueDelta / timeDelta
    }
    
    static func calculateRate(for values: [(timestamp: Date, value: Double, labels: [String: String])], timeWindow: TimeInterval = 300) -> Double? {
        guard let latest = values.last else { return nil }
        
        // Find the oldest sample within the time window
        guard let previous = values.first(where: {
            latest.timestamp.timeIntervalSince($0.timestamp) <= timeWindow
        }) else { return nil }
        
        let current = CounterData(timestamp: latest.timestamp, value: latest.value, labels: latest.labels)
        let prev = CounterData(timestamp: previous.timestamp, value: previous.value, labels: previous.labels)
        
        return current.calculateRate(previous: prev)
    }
} 