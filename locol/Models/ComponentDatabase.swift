import Foundation
import GRDB
import GRDBQuery
import os

/// Database manager for component definitions and schemas
@MainActor
class ComponentDatabase: ObservableObject {
    private let dbQueue: DatabaseQueue?
    private let logger = Logger.components

    init() {
        // Initialize database synchronously in init
        guard let dbPath = Bundle.main.path(forResource: "components", ofType: "db") else {
            logger.error("Components database not found in bundle")
            self.dbQueue = nil
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

    /// Provides database context for GRDBQuery
    var databaseContext: DatabaseContext? {
        guard let dbQueue = dbQueue else { return nil }
        return DatabaseContext.readOnly { dbQueue }
    }

    // MARK: - Direct Access Methods (for compatibility)

    /// Get all components (synchronous fallback)
    func getAllComponents() -> [CollectorComponent] {
        guard let dbQueue = dbQueue else { return [] }
        do {
            return try dbQueue.read { db in
                try CollectorComponent.fetchAll(db)
            }
        } catch {
            logger.error("Failed to fetch all components: \(String(describing: error))")
            return []
        }
    }

    /// Get components by type (synchronous fallback)
    func getComponents(ofType type: ComponentType) -> [CollectorComponent] {
        guard let dbQueue = dbQueue else { return [] }
        do {
            return try dbQueue.read { db in
                try CollectorComponent
                    .filter(CollectorComponent.Columns.type == type.rawValue)
                    .fetchAll(db)
            }
        } catch {
            logger.error("Failed to fetch components of type \(type.rawValue): \(String(describing: error))")
            return []
        }
    }

    /// Get a specific component by name and type
    func getComponent(name: String, type: ComponentType) -> CollectorComponent? {
        guard let dbQueue = dbQueue else { return nil }
        do {
            return try dbQueue.read { db in
                try CollectorComponent
                    .filter(CollectorComponent.Columns.name == name && CollectorComponent.Columns.type == type.rawValue)
                    .fetchOne(db)
            }
        } catch {
            logger.error("Failed to fetch component \(name) of type \(type.rawValue): \(String(describing: error))")
            return nil
        }
    }

    /// Get fields for a component
    func getFields(for component: CollectorComponent) -> [Field] {
        guard let dbQueue = dbQueue else { return [] }
        do {
            return try dbQueue.read { db in
                try Field
                    .filter(Field.Columns.componentId == component.id)
                    .fetchAll(db)
            }
        } catch {
            logger.error("Failed to fetch fields for component \(component.name): \(String(describing: error))")
            return []
        }
    }

    /// Get constraints for a component
    func getConstraints(for component: CollectorComponent) -> [Constraint] {
        guard let dbQueue = dbQueue else { return [] }
        do {
            return try dbQueue.read { db in
                try Constraint
                    .filter(Constraint.Columns.componentId == component.id)
                    .fetchAll(db)
            }
        } catch {
            logger.error("Failed to fetch constraints for component \(component.name): \(String(describing: error))")
            return []
        }
    }

    /// Get examples for a component
    func getExamples(for component: CollectorComponent) -> [Example] {
        guard let dbQueue = dbQueue else { return [] }
        do {
            return try dbQueue.read { db in
                try Example
                    .filter(Example.Columns.componentId == component.id)
                    .fetchAll(db)
            }
        } catch {
            logger.error("Failed to fetch examples for component \(component.name): \(String(describing: error))")
            return []
        }
    }

    /// Get field paths for a field
    func getFieldPaths(for field: Field) -> [FieldPath] {
        guard let dbQueue = dbQueue else { return [] }
        do {
            return try dbQueue.read { db in
                try FieldPath
                    .filter(FieldPath.Columns.fieldId == field.id)
                    .order(FieldPath.Columns.idx)
                    .fetchAll(db)
            }
        } catch {
            logger.error("Failed to fetch field paths for field \(field.name): \(String(describing: error))")
            return []
        }
    }

    /// Build hierarchical configuration structure for a component
    func buildConfigStructure(for component: CollectorComponent) -> ConfigSection {
        let fields = getFields(for: component)
        let rootSection = ConfigSection(name: component.name)

        for field in fields {
            let paths = getFieldPaths(for: field)
            if paths.isEmpty {
                // Field has no path structure, add to root
                rootSection.addField(field, at: [])
            } else {
                // Build path from field paths
                let pathTokens = paths.map(\.token)
                let pathWithoutFieldName = Array(pathTokens.dropLast()) // Remove field name itself
                rootSection.addField(field, at: pathWithoutFieldName)
            }
        }

        return rootSection
    }

    /// Get the document configuration
    func getDocument() -> Document? {
        guard let dbQueue = dbQueue else { return nil }
        do {
            return try dbQueue.read { db in
                try Document.fetchOne(db)
            }
        } catch {
            logger.error("Failed to fetch document: \(String(describing: error))")
            return nil
        }
    }

    /// Search components by name or description
    func searchComponents(query: String) -> [CollectorComponent] {
        guard let dbQueue = dbQueue else { return [] }
        let lowercaseQuery = query.lowercased()

        do {
            return try dbQueue.read { db in
                try CollectorComponent.fetchAll(db).filter { component in
                    component.name.lowercased().contains(lowercaseQuery) ||
                    component.description?.lowercased().contains(lowercaseQuery) == true
                }
            }
        } catch {
            logger.error("Failed to search components: \(String(describing: error))")
            return []
        }
    }

    /// Get database statistics
    func getStatistics() -> ComponentDatabaseStatistics {
        guard let dbQueue = dbQueue else {
            return ComponentDatabaseStatistics(components: 0, fields: 0, constraints: 0, examples: 0)
        }
        do {
            return try dbQueue.read { db in
                let components = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM components") ?? 0
                let fields = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM fields") ?? 0
                let constraints = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM constraints") ?? 0
                let examples = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM examples") ?? 0
                return ComponentDatabaseStatistics(components: components, fields: fields, constraints: constraints, examples: examples)
            }
        } catch {
            logger.error("Failed to get database statistics: \(String(describing: error))")
            return ComponentDatabaseStatistics(components: 0, fields: 0, constraints: 0, examples: 0)
        }
    }

    /// Get available collector version from the database
    func getCollectorVersion() -> String? {
        guard let dbQueue = dbQueue else { return nil }
        do {
            return try dbQueue.read { db in
                try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = 'collector_version'")
            }
        } catch {
            logger.error("Failed to get collector version: \(String(describing: error))")
            return nil
        }
    }
}

/// Database statistics
struct ComponentDatabaseStatistics {
    let components: Int
    let fields: Int
    let constraints: Int
    let examples: Int
}

/// Logger extension for components
extension Logger {
    static let components = Logger(subsystem: Bundle.main.bundleIdentifier ?? "io.aparker.locol", category: "components")
}