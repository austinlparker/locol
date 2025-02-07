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
    
    func getMetrics(forResourceIds resourceIds: [String]) async throws -> [MetricRow] {
        let resourceList = resourceIds.map { "'\($0)'" }.joined(separator: ",")
        let query = """
            SELECT 
                metric_name,
                description,
                unit,
                type,
                time,
                value,
                attributes,
                resource_id
            FROM metric_points
            WHERE resource_id IN (\(resourceList));
        """
        
        let result = try await database.executeQuery(query)
        var metrics: [MetricRow] = []
        
        let names = result["metric_name"] as? [String] ?? []
        let descriptions = result["description"] as? [String] ?? []
        let units = result["unit"] as? [String] ?? []
        let types = result["type"] as? [String] ?? []
        let times = result["time"] as? [Foundation.Date] ?? []
        let values = result["value"] as? [Double] ?? []
        let attributes = result["attributes"] as? [String] ?? []
        let resourceIds = result["resource_id"] as? [String] ?? []
        
        // Find the minimum length to avoid index out of range
        let count = min(
            names.count,
            descriptions.count,
            units.count,
            types.count,
            times.count,
            values.count,
            attributes.count,
            resourceIds.count
        )
        
        for i in 0..<count {
            metrics.append(MetricRow(
                name: names[i],
                description_p: descriptions[i],
                unit: units[i],
                type: types[i],
                time: times[i],
                value: values[i],
                attributes: attributes[i],
                resourceId: resourceIds[i]
            ))
        }
        
        return metrics
    }
} 
