import Foundation
import DuckDB
import os

final class MetricsHandler {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MetricsHandler")
    private let database: DatabaseProtocol
    
    init(database: DatabaseProtocol) {
        self.database = database
    }
    
    func handleMetric(_ metric: Opentelemetry_Proto_Metrics_V1_Metric, resourceId: UUID, scopeId: UUID) async throws {
        let appender = try database.createAppender(for: "metric_points")
        
        let (value, time) = extractMetricValue(metric)
        let metricPointId = UUID()
        let attributes = JSONUtils.attributesToJSON(metric.metadata)
        
        try appender.append(metricPointId.uuidString)
        try appender.append(resourceId.uuidString)
        try appender.append(scopeId.uuidString)
        try appender.append(metric.name)
        try appender.append(metric.description_p)
        try appender.append(metric.unit)
        try appender.append(metric.data.debugDescription)
        try appender.append(value)
        try appender.append(attributes)
        try appender.append(Timestamp(time))
        try appender.endRow()
        try appender.flush()
    }
    
    private func extractMetricValue(_ metric: Opentelemetry_Proto_Metrics_V1_Metric) -> (Double, Foundation.Date) {
        switch metric.data {
        case .gauge(let gauge):
            if let point = gauge.dataPoints.first {
                return (point.toDouble, Foundation.Date(timeIntervalSince1970: TimeInterval(point.timeUnixNano) / 1_000_000_000))
            }
        case .sum(let sum):
            if let point = sum.dataPoints.first {
                return (point.toDouble, Foundation.Date(timeIntervalSince1970: TimeInterval(point.timeUnixNano) / 1_000_000_000))
            }
        default:
            break
        }
        return (0.0, Foundation.Date())
    }
} 
