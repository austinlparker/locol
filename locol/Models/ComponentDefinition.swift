import Foundation
import SwiftUI
import GRDB
import GRDBQuery

// MARK: - Component System Models

/// Represents a component type in the OpenTelemetry collector
enum ComponentType: String, CaseIterable, Codable, Sendable {
    case receiver
    case processor
    case exporter
    case `extension`
    case connector

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .receiver:
            return .blue
        case .processor:
            return .orange
        case .exporter:
            return .green
        case .`extension`:
            return .purple
        case .connector:
            return .pink
        }
    }
}

/// UI control types for config fields
enum ConfigControlType: Sendable {
    case textField
    case numberField
    case toggle
    case durationPicker
    case arrayEditor
    case mapEditor
    case picker
}

// MARK: - Document Schema

/// Represents the document configuration (singleton)
struct Document: Codable, Identifiable {
    let id: Int
    let sections: [String]
    let signals: [String]
    let pipelineShape: PipelineShape
    let telemetryLevels: [String]
    let defaultLevel: String

    struct PipelineShape: Codable {
        let receivers: Bool
        let processors: Bool
        let exporters: Bool
        let connectors: Bool
    }
}

// GRDB mapping for Document
extension Document: FetchableRecord, TableRecord {
    static let databaseTableName = "document"

    init(row: Row) {
        self.id = row["id"]

        let sectionsJSON: String = row["sections_json"]
        self.sections = (try? JSONDecoder().decode([String].self, from: sectionsJSON.data(using: .utf8) ?? Data())) ?? []

        let signalsJSON: String = row["signals_json"]
        self.signals = (try? JSONDecoder().decode([String].self, from: signalsJSON.data(using: .utf8) ?? Data())) ?? []

        let pipelineJSON: String = row["pipeline_shape_json"]
        if let pipelineData = pipelineJSON.data(using: .utf8),
           let pipelineDict = try? JSONDecoder().decode([String: Bool].self, from: pipelineData) {
            self.pipelineShape = PipelineShape(
                receivers: pipelineDict["receivers"] ?? false,
                processors: pipelineDict["processors"] ?? false,
                exporters: pipelineDict["exporters"] ?? false,
                connectors: pipelineDict["connectors"] ?? false
            )
        } else {
            self.pipelineShape = PipelineShape(receivers: false, processors: false, exporters: false, connectors: false)
        }

        let levelsJSON: String = row["telemetry_levels_json"]
        self.telemetryLevels = (try? JSONDecoder().decode([String].self, from: levelsJSON.data(using: .utf8) ?? Data())) ?? []

        self.defaultLevel = row["default_level"]
    }
}

// MARK: - Database Columns

extension Document {
    enum Columns {
        static let id = Column("id")
        static let sectionsJSON = Column("sections_json")
        static let signalsJSON = Column("signals_json")
        static let pipelineShapeJSON = Column("pipeline_shape_json")
        static let telemetryLevelsJSON = Column("telemetry_levels_json")
        static let defaultLevel = Column("default_level")
    }
}

// MARK: - Component Models

/// Represents a component definition
struct CollectorComponent: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let type: ComponentType
    let description: String?
    let version: String

    var displayName: String {
        name.replacingOccurrences(of: type.rawValue, with: "").capitalized
    }

    var fullName: String {
        "\(type.displayName): \(displayName)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CollectorComponent, rhs: CollectorComponent) -> Bool {
        lhs.id == rhs.id
    }
}

// GRDB mapping for CollectorComponent
extension CollectorComponent: FetchableRecord, TableRecord {
    static let databaseTableName = "components"

    init(row: Row) {
        self.id = row["id"]
        self.name = row["name"]
        let typeString: String = row["type"]
        self.type = ComponentType(rawValue: typeString) ?? .receiver
        self.description = row["description"]
        self.version = row["version"]
    }
}

extension CollectorComponent {
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let type = Column("type")
        static let description = Column("description")
        static let version = Column("version")
    }
}

/// Represents a configuration field
struct Field: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let componentId: Int
    let name: String
    let kind: String
    let required: Bool
    let defaultValue: String?
    let description: String?
    let format: String?
    let unit: String?
    let sensitive: Bool
    let itemType: String?
    let refKind: String?
    let refScope: String?
    let validationJson: String?

    /// Parsed default value
    var defaultParsed: Any? {
        guard let json = defaultValue,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    /// Parsed validation rules
    var validation: [String: String] {
        guard let json = validationJson,
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return dict
    }

    var displayName: String {
        name
    }

    var isRequired: Bool {
        required
    }

    /// UI control type based on field kind
    var controlType: ConfigControlType {
        switch kind.lowercased() {
        case "string":
            return .textField
        case "int", "int64", "float64":
            return .numberField
        case "bool":
            return .toggle
        case "duration":
            return .durationPicker
        case "[]string", "slice":
            return .arrayEditor
        case "map":
            return .mapEditor
        default:
            return .textField
        }
    }

    /// Get the full path for this field (e.g., "protocols.grpc.endpoint")
    @MainActor
    func getFullPath(database: ComponentDatabase) -> String {
        let paths = database.getFieldPaths(for: self)
        if paths.isEmpty {
            return name
        }
        let pathTokens = paths.map(\.token)
        return pathTokens.joined(separator: ".")
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Field, rhs: Field) -> Bool {
        lhs.id == rhs.id
    }
}

// GRDB mapping for Field
extension Field: FetchableRecord, TableRecord {
    static let databaseTableName = "fields"

    init(row: Row) {
        self.id = row["id"]
        self.componentId = row["component_id"]
        self.name = row["name"]
        self.kind = row["kind"]
        self.required = row["required"] != 0
        self.defaultValue = row["default_json"]
        self.description = row["description"]
        self.format = row["format"]
        self.unit = row["unit"]
        self.sensitive = row["sensitive"] != 0
        self.itemType = row["item_type"]
        self.refKind = row["ref_kind"]
        self.refScope = row["ref_scope"]
        self.validationJson = row["validation_json"]
    }
}

extension Field {
    enum Columns {
        static let id = Column("id")
        static let componentId = Column("component_id")
        static let name = Column("name")
        static let kind = Column("kind")
        static let required = Column("required")
        static let defaultJSON = Column("default_json")
        static let description = Column("description")
        static let format = Column("format")
        static let unit = Column("unit")
        static let sensitive = Column("sensitive")
        static let itemType = Column("item_type")
        static let refKind = Column("ref_kind")
        static let refScope = Column("ref_scope")
        static let validationJSON = Column("validation_json")
    }
}

/// Represents field path tokens for nested fields
struct FieldPath: Codable, Identifiable, Hashable, Sendable {
    let fieldId: Int
    let idx: Int
    let token: String

    // Generate a synthetic ID from fieldId and idx
    var id: String { "\(fieldId)-\(idx)" }

    func hash(into hasher: inout Hasher) {
        hasher.combine(fieldId)
        hasher.combine(idx)
    }

    static func == (lhs: FieldPath, rhs: FieldPath) -> Bool {
        lhs.fieldId == rhs.fieldId && lhs.idx == rhs.idx
    }
}

// GRDB mapping for FieldPath
extension FieldPath: FetchableRecord, TableRecord {
    static let databaseTableName = "field_paths"

    init(row: Row) {
        self.fieldId = row["field_id"]
        self.idx = row["idx"]
        self.token = row["token"]
    }
}

extension FieldPath {
    enum Columns {
        static let fieldId = Column("field_id")
        static let idx = Column("idx")
        static let token = Column("token")
    }
}

/// Represents field enum values
struct FieldEnum: Codable, Identifiable, Hashable, Sendable {
    let fieldId: Int
    let value: String

    // Generate a synthetic ID from fieldId and value
    var id: String { "\(fieldId)-\(value)" }

    func hash(into hasher: inout Hasher) {
        hasher.combine(fieldId)
        hasher.combine(value)
    }

    static func == (lhs: FieldEnum, rhs: FieldEnum) -> Bool {
        lhs.fieldId == rhs.fieldId && lhs.value == rhs.value
    }
}

// GRDB mapping for FieldEnum
extension FieldEnum: FetchableRecord {
    init(row: Row) {
        self.fieldId = row["field_id"]
        self.value = row["value"]
    }
}

extension FieldEnum {
    enum Columns {
        static let fieldId = Column("field_id")
        static let value = Column("value")
    }
}

/// Represents component-level validation constraints
struct Constraint: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let componentId: Int
    let kind: String  // anyOf, oneOf, allOf, atMostOne
    let keysJson: String
    let message: String?

    /// Parsed constraint keys
    var keys: [[String]] {
        guard let data = keysJson.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String]] else {
            return []
        }
        return arr
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Constraint, rhs: Constraint) -> Bool {
        lhs.id == rhs.id
    }
}

// GRDB mapping for Constraint
extension Constraint: FetchableRecord, TableRecord {
    static let databaseTableName = "constraints"

    init(row: Row) {
        self.id = row["id"]
        self.componentId = row["component_id"]
        self.kind = row["kind"]
        self.keysJson = row["keys_json"]
        self.message = row["message"]
    }
}

extension Constraint {
    enum Columns {
        static let id = Column("id")
        static let componentId = Column("component_id")
        static let kind = Column("kind")
        static let keysJSON = Column("keys_json")
        static let message = Column("message")
    }
}

/// Represents a configuration example
struct Example: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let componentId: Int
    let yaml: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Example, rhs: Example) -> Bool {
        lhs.id == rhs.id
    }
}

// GRDB mapping for Example
extension Example: FetchableRecord, TableRecord {
    static let databaseTableName = "examples"

    init(row: Row) {
        self.id = row["id"]
        self.componentId = row["component_id"]
        self.yaml = row["yaml"]
    }
}

extension Example {
    enum Columns {
        static let id = Column("id")
        static let componentId = Column("component_id")
        static let yaml = Column("yaml")
    }
}

// MARK: - Configuration Structure Types

/// Represents a nested configuration section
class ConfigSection: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    var fields: [Field] = []
    var subsections: [String: ConfigSection] = [:]
    @Published var isExpanded: Bool = true

    init(name: String) {
        self.name = name
    }

    /// Add a field to this section at the given path
    func addField(_ field: Field, at path: [String]) {
        if path.isEmpty {
            fields.append(field)
        } else {
            let nextSection = path[0]
            let remainingPath = Array(path.dropFirst())

            if subsections[nextSection] == nil {
                subsections[nextSection] = ConfigSection(name: nextSection)
            }
            subsections[nextSection]?.addField(field, at: remainingPath)
        }
    }

    /// Get all fields from this section and all subsections
    func getAllFields() -> [Field] {
        var allFields = fields
        for (_, subsection) in subsections {
            allFields.append(contentsOf: subsection.getAllFields())
        }
        return allFields
    }

    /// Calculate the maximum depth of this configuration section
    func maxDepth() -> Int {
        if subsections.isEmpty {
            return 1
        }
        let maxSubsectionDepth = subsections.values.map { $0.maxDepth() }.max() ?? 0
        return maxSubsectionDepth + 1
    }
}

// MARK: - Configuration Value Types

/// Represents a value for a configuration field
enum ConfigValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case double(Double)
    case duration(TimeInterval)
    case stringArray([String])
    case array([ConfigValue])
    case stringMap([String: String])
    case map([String: ConfigValue])
    case null

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }

    var durationValue: TimeInterval? {
        if case .duration(let value) = self { return value }
        return nil
    }

    var stringArrayValue: [String]? {
        if case .stringArray(let value) = self { return value }
        return nil
    }

    var arrayValue: [ConfigValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var stringMapValue: [String: String]? {
        if case .stringMap(let value) = self { return value }
        return nil
    }

    var mapValue: [String: ConfigValue]? {
        if case .map(let value) = self { return value }
        return nil
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// Check if the ConfigValue is considered "empty" for validation purposes
    var isEmpty: Bool {
        switch self {
        case .null:
            return true
        case .string(let value):
            return value.isEmpty
        case .int(_), .bool(_), .double(_), .duration(_):
            return false // Numeric and boolean values are never considered "empty"
        case .stringArray(let array):
            return array.isEmpty
        case .array(let array):
            return array.isEmpty
        case .stringMap(let map):
            return map.isEmpty
        case .map(let map):
            return map.isEmpty
        }
    }
}

/// Represents a component instance with its configuration
struct ComponentInstance: Codable, Identifiable, Hashable, Sendable {
    let id = UUID()
    let component: CollectorComponent
    var name: String
    var configuration: [String: ConfigValue]

    init(component: CollectorComponent, name: String? = nil) {
        self.component = component
        self.name = name ?? component.name
        self.configuration = [:]
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ComponentInstance, rhs: ComponentInstance) -> Bool {
        lhs.id == rhs.id
    }
}

extension ConfigValue {
    static func from(any value: Any) -> ConfigValue {
        if let str = value as? String {
            return .string(str)
        } else if let int = value as? Int {
            return .int(int)
        } else if let bool = value as? Bool {
            return .bool(bool)
        } else if let double = value as? Double {
            return .double(double)
        } else if let array = value as? [String] {
            return .stringArray(array)
        } else if let map = value as? [String: String] {
            return .stringMap(map)
        } else if let array = value as? [Any] {
            return .array(array.map { ConfigValue.from(any: $0) })
        } else if let map = value as? [String: Any] {
            let configMap = map.mapValues { ConfigValue.from(any: $0) }
            return .map(configMap)
        } else {
            return .null
        }
    }
}

// MARK: - Configuration Models

/// Represents a complete collector configuration
struct CollectorConfiguration: Codable, Sendable {
    var version: String
    var receivers: [ComponentInstance] = []
    var processors: [ComponentInstance] = []
    var exporters: [ComponentInstance] = []
    var extensions: [ComponentInstance] = []
    var connectors: [ComponentInstance] = []
    var service: ServiceConfiguration?
    var pipelines: [PipelineConfiguration] = []

    init(version: String) {
        self.version = version
    }

    /// All component instances combined
    var allComponents: [ComponentInstance] {
        receivers + processors + exporters + extensions + connectors
    }
}

/// Represents a pipeline configuration
struct PipelineConfiguration: Codable, Identifiable, Sendable, Hashable, Equatable {
    let id = UUID()
    var name: String = ""
    var receivers: [ComponentInstance] = []
    var processors: [ComponentInstance] = []
    var exporters: [ComponentInstance] = []

    init(name: String = "", receivers: [ComponentInstance] = [], processors: [ComponentInstance] = [], exporters: [ComponentInstance] = []) {
        self.name = name
        self.receivers = receivers
        self.processors = processors
        self.exporters = exporters
    }

    /// Check if the pipeline has at least one receiver and one exporter
    var isValid: Bool {
        !receivers.isEmpty && !exporters.isEmpty
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PipelineConfiguration, rhs: PipelineConfiguration) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents service configuration for telemetry, etc.
struct ServiceConfiguration: Codable, Sendable {
    var telemetry: TelemetryConfiguration?
    var pipelines: [String: PipelineConfiguration] = [:]

    init() {}
}

/// Represents telemetry configuration
struct TelemetryConfiguration: Codable, Sendable {
    var logs: LogsConfiguration?
    var metrics: MetricsConfiguration?
    var traces: TracesConfiguration?

    init() {}
}

/// Basic telemetry component configurations
struct LogsConfiguration: Codable, Sendable {
    var level: String = "info"
    var development: Bool = false
}

struct MetricsConfiguration: Codable, Sendable {
    var level: String = "basic"
    var address: String = ":8888"
}

struct TracesConfiguration: Codable, Sendable {
    var level: String = "basic"
}

// MARK: - GRDBQuery Requests

/// Request to fetch the document configuration
struct DocumentRequest: ValueObservationQueryable {
    static var defaultValue: Document? { nil }

    func fetch(_ db: Database) throws -> Document? {
        try Document.fetchOne(db)
    }
}

/// Request to fetch all components
struct ComponentsRequest: ValueObservationQueryable {
    static var defaultValue: [CollectorComponent] { [] }

    func fetch(_ db: Database) throws -> [CollectorComponent] {
        try CollectorComponent.fetchAll(db)
    }
}

/// Request to fetch components by type
struct ComponentsByTypeRequest: ValueObservationQueryable {
    let componentType: ComponentType

    static var defaultValue: [CollectorComponent] { [] }

    func fetch(_ db: Database) throws -> [CollectorComponent] {
        try CollectorComponent
            .filter(CollectorComponent.Columns.type == componentType.rawValue)
            .fetchAll(db)
    }
}

/// Request to fetch fields for a component
struct FieldsForComponentRequest: ValueObservationQueryable {
    let componentId: Int

    static var defaultValue: [Field] { [] }

    func fetch(_ db: Database) throws -> [Field] {
        try Field
            .filter(Field.Columns.componentId == componentId)
            .fetchAll(db)
    }
}

/// Request to fetch constraints for a component
struct ConstraintsForComponentRequest: ValueObservationQueryable {
    let componentId: Int

    static var defaultValue: [Constraint] { [] }

    func fetch(_ db: Database) throws -> [Constraint] {
        try Constraint
            .filter(Constraint.Columns.componentId == componentId)
            .fetchAll(db)
    }
}

/// Request to fetch examples for a component
struct ExamplesForComponentRequest: ValueObservationQueryable {
    let componentId: Int

    static var defaultValue: [Example] { [] }

    func fetch(_ db: Database) throws -> [Example] {
        try Example
            .filter(Example.Columns.componentId == componentId)
            .fetchAll(db)
    }
}