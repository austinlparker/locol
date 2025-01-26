import Foundation

// Helper extension for metric data points
extension Opentelemetry_Proto_Metrics_V1_NumberDataPoint {
    var toDouble: Double {
        switch value {
        case .asDouble(let value):
            return value
        case .asInt(let value):
            return Double(value)
        default:
            return 0.0
        }
    }
}

// Helper extension for byte arrays
extension Data {
    var hexString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
    
    func toString() -> String {
        String(data: self, encoding: .utf8) ?? "{}"
    }
} 