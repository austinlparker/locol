import Foundation
import GRDB
import os

/// Database manager for component definitions and schemas
actor ComponentDatabase {
    private var dbQueue: DatabaseQueue?
    private let logger = Logger.components
    
    init() {
        // Initialize database synchronously in init
        guard let dbPath = Bundle.main.path(forResource: "components", ofType: "db") else {
            logger.error("Components database not found in bundle")
            return
        }
        
        do {
            var config = Configuration()
            config.readonly = true
            self.dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
            logger.info("Components database opened successfully")
        } catch {
            logger.error("Failed to open components database: \(String(describing: error))")
            self.dbQueue = nil
        }
    }
    
    deinit {
        // DatabaseQueue cleans up on deinit
    }
    
    // MARK: - Database Operations
    // All DB access occurs on the actor; no nonisolated accessors.
    
    // MARK: - Version Queries
    
    /// Get all available collector versions
    func availableVersions() -> [ComponentVersion] {
        guard let dbQueue = dbQueue else { return [] }
        let query = """
            SELECT id, version, is_contrib, extracted_at
            FROM collector_versions
            ORDER BY version DESC
        """
        do {
            return try dbQueue.read { db in
                try ComponentVersion.fetchAll(db, sql: query)
            }
        } catch {
            logger.error("Failed to query versions: \(String(describing: error))")
            return []
        }
    }
    
    /// Check if a specific version exists in the database
    func hasVersion(_ version: String) -> Bool {
        guard let dbQueue = dbQueue else { return false }
        do {
            return try dbQueue.read { db in
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM collector_versions WHERE version = ?", arguments: [version]) ?? 0
                return count > 0
            }
        } catch {
            return false
        }
    }
    
    // MARK: - Component Queries
    
    /// Get all components for a specific version
    func components(for version: String) -> [ComponentDefinition] {
        guard let dbQueue = dbQueue else { return [] }
        let query = """
            SELECT c.id, c.name, c.type, c.module, c.description, c.struct_name, c.version_id
            FROM components c
            JOIN collector_versions v ON c.version_id = v.id
            WHERE v.version = ?
            ORDER BY c.type, c.name
        """
        do {
            return try dbQueue.read { db in
                var list = try ComponentDefinition.fetchAll(db, sql: query, arguments: [version])
                for i in 0..<list.count {
                    let id = list[i].id
                    list[i].fields = try ConfigField.fetchAll(db, sql: "SELECT * FROM config_fields WHERE component_id = ? ORDER BY field_name", arguments: [id])
                    list[i].defaults = try DefaultValue.fetchAll(db, sql: "SELECT * FROM default_values WHERE component_id = ?", arguments: [id])
                    list[i].examples = try ConfigExample.fetchAll(db, sql: "SELECT * FROM config_examples WHERE component_id = ?", arguments: [id])
                    list[i].constraints = try ComponentConstraint.fetchAll(db, sql: "SELECT * FROM component_constraints WHERE component_id = ?", arguments: [id])
                }
                return list
            }
        } catch {
            logger.error("Failed to query components: \(String(describing: error))")
            return []
        }
    }
    
    /// Get components by type for a specific version
    func components(for version: String, type: ComponentType) -> [ComponentDefinition] {
        return components(for: version).filter { $0.type == type }
    }
    
    /// Get a specific component by name and version
    func component(name: String, version: String) -> ComponentDefinition? {
        return components(for: version).first { $0.name == name }
    }

    /// Get a specific component by name, type, and version.
    /// Useful when the same short name exists across multiple types (e.g., "otlp").
    func component(name: String, type: ComponentType, version: String) -> ComponentDefinition? {
        return components(for: version).first { $0.name == name && $0.type == type }
    }
    
    /// Search components by name or description
    func searchComponents(for version: String, query: String) -> [ComponentDefinition] {
        let allComponents = components(for: version)
        let lowercaseQuery = query.lowercased()
        
        return allComponents.filter { component in
            component.name.lowercased().contains(lowercaseQuery) ||
            component.description?.lowercased().contains(lowercaseQuery) == true ||
            component.module.lowercased().contains(lowercaseQuery)
        }
    }
    
    // MARK: - Configuration Field Queries
    
    private func configFields(for componentId: Int) -> [ConfigField] {
        guard let dbQueue = dbQueue else { return [] }
        let query = """
            SELECT id, component_id, field_name, yaml_key, field_type, go_type,
                   description, required, validation_json
            FROM config_fields
            WHERE component_id = ?
            ORDER BY field_name
        """
        do {
            return try dbQueue.read { db in
                try ConfigField.fetchAll(db, sql: query, arguments: [componentId])
            }
        } catch {
            return []
        }
    }
    
    private func defaultValues(for componentId: Int) -> [DefaultValue] {
        guard let dbQueue = dbQueue else { return [] }
        let query = """
            SELECT id, component_id, field_name, default_value
            FROM default_values
            WHERE component_id = ?
        """
        do {
            return try dbQueue.read { db in
                try DefaultValue.fetchAll(db, sql: query, arguments: [componentId])
            }
        } catch {
            return []
        }
    }
    
    private func configExamples(for componentId: Int) -> [ConfigExample] {
        guard let dbQueue = dbQueue else { return [] }
        let query = """
            SELECT id, component_id, example_yaml, description
            FROM config_examples
            WHERE component_id = ?
        """
        do {
            return try dbQueue.read { db in
                try ConfigExample.fetchAll(db, sql: query, arguments: [componentId])
            }
        } catch {
            return []
        }
    }
    
    // MARK: - Statistics
    
    /// Get database statistics
    func statistics() -> ComponentDatabaseStatistics {
        guard let dbQueue = dbQueue else {
            return ComponentDatabaseStatistics(versions: 0, components: 0, fields: 0, defaults: 0)
        }
        do {
            return try dbQueue.read { db in
                let versions = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM collector_versions") ?? 0
                let components = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM components") ?? 0
                let fields = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM config_fields") ?? 0
                let defaults = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM default_values") ?? 0
                return ComponentDatabaseStatistics(versions: versions, components: components, fields: fields, defaults: defaults)
            }
        } catch {
            return ComponentDatabaseStatistics(versions: 0, components: 0, fields: 0, defaults: 0)
        }
    }
}

/// Database statistics
struct ComponentDatabaseStatistics {
    let versions: Int
    let components: Int
    let fields: Int
    let defaults: Int
}

/// Logger extension for components
extension Logger {
    static let components = Logger(subsystem: Bundle.main.bundleIdentifier ?? "io.aparker.locol", category: "components")
}
