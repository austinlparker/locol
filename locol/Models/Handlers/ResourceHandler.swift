import Foundation
import DuckDB
import os

final class ResourceHandler {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ResourceHandler")
    private let database: DatabaseProtocol
    
    init(database: DatabaseProtocol) {
        self.database = database
    }
    
    func handleResource(_ resource: Opentelemetry_Proto_Resource_V1_Resource) async throws -> UUID {
        let resourceId = UUID()
        let now = Foundation.Date()
        
        let appender = try database.createAppender(for: "resources")
        
        // First, insert the resource
        try appender.append(resourceId.uuidString)
        try appender.append(Timestamp(now))
        try appender.append(Int32(resource.droppedAttributesCount))
        try appender.endRow()
        try appender.flush()
        
        // Then handle each attribute
        for attr in resource.attributes {
            try await handleAttribute(attr, resourceId: resourceId, timestamp: now)
        }
        
        return resourceId
    }
    
    private func handleAttribute(_ attr: Opentelemetry_Proto_Common_V1_KeyValue, resourceId: UUID, timestamp: Foundation.Date) async throws {
        // Try to find existing attribute with same key-value pair
        let query = """
            SELECT attribute_id 
            FROM resource_attributes 
            WHERE key = '\(attr.key)' AND value = '\(attr.value.stringValue)'
        """
        
        let result = try await database.executeQuery(query)
        let existingIds = result["attribute_id"] as? [String] ?? []
        
        let attributeId: String
        if let existingId = existingIds.first {
            // Use existing attribute
            attributeId = existingId
        } else {
            // Create new attribute
            attributeId = UUID().uuidString
            let attrAppender = try database.createAppender(for: "resource_attributes")
            
            try attrAppender.append(attributeId)
            try attrAppender.append(attr.key)
            try attrAppender.append(attr.value.stringValue)
            try attrAppender.append(Timestamp(timestamp))
            try attrAppender.endRow()
            try attrAppender.flush()
        }
        
        // Create mapping
        let mappingAppender = try database.createAppender(for: "resource_attribute_mappings")
        
        try mappingAppender.append(resourceId.uuidString)
        try mappingAppender.append(attributeId)
        try mappingAppender.endRow()
        try mappingAppender.flush()
    }
    
    func getResourceGroups() async throws -> [ResourceAttributeGroup] {
        var groups: [ResourceAttributeGroup] = []
        
        // First get service.name entries
        let serviceQuery = """
            SELECT DISTINCT key, value
            FROM resource_attributes
            WHERE key = 'service.name';
        """
        
        let serviceResult = try await database.executeQuery(serviceQuery)
        let serviceKeys = serviceResult["key"] as? [String] ?? []
        let serviceValues = serviceResult["value"] as? [String] ?? []
        
        for i in 0..<serviceKeys.count {
            let key = serviceKeys[i]
            let value = serviceValues[i]
            
            let resourceIds = try await getResourceIds(forKey: key, value: value)
            groups.append(ResourceAttributeGroup(
                key: key,
                value: value,
                resourceIds: resourceIds
            ))
        }
        
        // Then get all other attributes
        let otherQuery = """
            SELECT DISTINCT key, value
            FROM resource_attributes
            WHERE key != 'service.name';
        """
        
        let otherResult = try await database.executeQuery(otherQuery)
        let otherKeys = otherResult["key"] as? [String] ?? []
        let otherValues = otherResult["value"] as? [String] ?? []
        
        for i in 0..<otherKeys.count {
            let key = otherKeys[i]
            let value = otherValues[i]
            
            let resourceIds = try await getResourceIds(forKey: key, value: value)
            groups.append(ResourceAttributeGroup(
                key: key,
                value: value,
                resourceIds: resourceIds
            ))
        }
        
        // Sort the groups in memory
        return groups.sorted { g1, g2 in
            if g1.key == "service.name" && g2.key != "service.name" {
                return true
            }
            if g1.key != "service.name" && g2.key == "service.name" {
                return false
            }
            if g1.key == g2.key {
                return g1.value < g2.value
            }
            return g1.key < g2.key
        }
    }
    
    private func getResourceIds(forKey key: String, value: String) async throws -> [String] {
        let query = """
            SELECT DISTINCT resource_id
            FROM resource_attribute_mappings
            WHERE attribute_id IN (
                SELECT attribute_id
                FROM resource_attributes
                WHERE key = '\(key)' AND value = '\(value)'
            );
        """
        
        let result = try await database.executeQuery(query)
        return (result["resource_id"] as? [String]) ?? []
    }
} 