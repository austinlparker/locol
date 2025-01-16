import Foundation

enum MetricType: String {
    case counter = "counter"
    case gauge = "gauge"
    case histogram = "histogram"
}

struct MetricDefinition {
    let name: String
    let description: String
    let type: MetricType
} 