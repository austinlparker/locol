import Foundation

// MARK: - Metric Types
struct MetricRow: Identifiable {
    let id = UUID()
    let name: String
    let description_p: String
    let unit: String
    let type: String
    let time: Foundation.Date
    let value: Double
    let attributes: String
    let resourceId: String
}

// MARK: - Log Types
struct LogRow: Identifiable {
    let id = UUID()
    let timestamp: Foundation.Date
    let severityText: String
    let severityNumber: Int32
    let body: String
    let attributes: String
    let resourceId: String
}

// MARK: - Span Types
struct SpanRow: Identifiable {
    let id = UUID()
    let traceId: String
    let spanId: String
    let parentSpanId: String
    let name: String
    let kind: Int32
    let startTime: Foundation.Date
    let endTime: Foundation.Date
    let attributes: String
    let resourceId: String
}

// MARK: - Resource Types
struct ResourceRow: Identifiable, Hashable {
    let id: String // Using resource_id as the identifier
    let timestamp: Foundation.Date
    let droppedAttributesCount: Int32
    let attributes: [(key: String, value: String)]
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(timestamp)
        hasher.combine(droppedAttributesCount)
    }
    
    // Implement Equatable (required by Hashable)
    static func == (lhs: ResourceRow, rhs: ResourceRow) -> Bool {
        lhs.id == rhs.id &&
        lhs.timestamp == rhs.timestamp &&
        lhs.droppedAttributesCount == rhs.droppedAttributesCount
    }
}

struct ResourceAttributeGroup: Identifiable, Hashable {
    let id = UUID()
    let key: String
    let value: String
    let resourceIds: [String]
    var count: Int { resourceIds.count }
    
    var displayName: String {
        if key == "service.name" {
            return value
        } else {
            return "\(key): \(value)"
        }
    }
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(value)
    }
    
    // Implement Equatable (required by Hashable)
    static func == (lhs: ResourceAttributeGroup, rhs: ResourceAttributeGroup) -> Bool {
        lhs.key == rhs.key && lhs.value == rhs.value
    }
} 
