import Foundation
import SwiftUI
import GRDB

// MARK: - Component System Models

/// Represents a component type in the OpenTelemetry collector
enum ComponentType: String, CaseIterable, Codable {
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

/// Field type mapping from Go types to Swift representation
enum ConfigFieldType: String, Codable, CaseIterable {
    case string
    case int
    case bool
    case double
    case duration
    case stringArray
    case array
    case stringMap
    case map
    case `enum`
    case custom
    
    var displayName: String {
        switch self {
        case .string: return "String"
        case .int: return "Integer"
        case .bool: return "Boolean"
        case .double: return "Number"
        case .duration: return "Duration"
        case .stringArray: return "String Array"
        case .array: return "Array"
        case .stringMap: return "String Map"
        case .map: return "Map"
        case .`enum`: return "Enum"
        case .custom: return "Custom"
        }
    }
    
    /// Default UI control for this field type
    var controlType: ConfigControlType {
        switch self {
        case .string, .custom:
            return .textField
        case .int, .double:
            return .numberField
        case .bool:
            return .toggle
        case .duration:
            return .durationPicker
        case .stringArray, .array:
            return .arrayEditor
        case .stringMap, .map:
            return .mapEditor
        case .`enum`:
            return .picker
        }
    }
}

/// UI control types for config fields
enum ConfigControlType {
    case textField
    case numberField
    case toggle
    case durationPicker
    case arrayEditor
    case mapEditor
    case picker
}

/// Represents a collector version
struct ComponentVersion: Codable, Identifiable, Hashable {
    let id: Int
    let version: String
    let isContrib: Bool
    let extractedAt: Date
    
    var displayName: String {
        version + (isContrib ? " (contrib)" : " (core)")
    }
}

// GRDB mapping
extension ComponentVersion: FetchableRecord {
    init(row: Row) {
        self.id = row["id"]
        self.version = row["version"]
        self.isContrib = row["is_contrib"]
        let extractedAtStr: String = row["extracted_at"]
        let formatter = ISO8601DateFormatter()
        self.extractedAt = formatter.date(from: extractedAtStr) ?? Date()
    }
}

/// Represents a component definition with its configuration schema
struct ComponentDefinition: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let type: ComponentType
    let module: String
    let description: String?
    let structName: String?
    let versionId: Int
    
    // Configuration schema
    var fields: [ConfigField] = []
    var defaults: [DefaultValue] = []
    var examples: [ConfigExample] = []
    
    var displayName: String {
        name.replacingOccurrences(of: type.rawValue, with: "").capitalized
    }
    
    var fullName: String {
        "\(type.displayName): \(displayName)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ComponentDefinition, rhs: ComponentDefinition) -> Bool {
        lhs.id == rhs.id
    }
}

extension ComponentDefinition: FetchableRecord {
    init(row: Row) {
        self.id = row["id"]
        self.name = row["name"]
        let typeString: String = row["type"]
        self.type = ComponentType(rawValue: typeString) ?? .receiver
        self.module = row["module"]
        self.description = row["description"]
        self.structName = row["struct_name"]
        self.versionId = row["version_id"]
        // Initialize empty collections; caller may populate
        self.fields = []
        self.defaults = []
        self.examples = []
    }
}

/// Represents a configuration field
struct ConfigField: Codable, Identifiable, Hashable {
    let id: Int
    let componentId: Int
    let fieldName: String
    let yamlKey: String
    let fieldType: ConfigFieldType
    let goType: String
    let description: String?
    let required: Bool
    let validationJson: String?
    
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
        fieldName
    }
    
    var isRequired: Bool {
        required
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ConfigField, rhs: ConfigField) -> Bool {
        lhs.id == rhs.id
    }
}

extension ConfigField: FetchableRecord {
    init(row: Row) {
        self.id = row["id"]
        self.componentId = row["component_id"]
        self.fieldName = row["field_name"]
        self.yamlKey = row["yaml_key"]
        let fieldTypeString: String = row["field_type"]
        self.fieldType = ConfigFieldType(rawValue: fieldTypeString) ?? .custom
        self.goType = row["go_type"]
        self.description = row["description"]
        self.required = row["required"]
        self.validationJson = row["validation_json"]
    }
}

/// Represents a default value for a configuration field
struct DefaultValue: Codable, Identifiable, Hashable {
    let id: Int
    let componentId: Int
    let fieldName: String
    let defaultValueJson: String
    
    /// Parsed default value
    var defaultValue: Any? {
        guard let data = defaultValueJson.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DefaultValue, rhs: DefaultValue) -> Bool {
        lhs.id == rhs.id
    }
}

extension DefaultValue: FetchableRecord {
    init(row: Row) {
        self.id = row["id"]
        self.componentId = row["component_id"]
        self.fieldName = row["field_name"]
        self.defaultValueJson = row["default_value"]
    }
}

/// Represents a configuration example
struct ConfigExample: Codable, Identifiable, Hashable {
    let id: Int
    let componentId: Int
    let exampleYaml: String
    let description: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ConfigExample, rhs: ConfigExample) -> Bool {
        lhs.id == rhs.id
    }
}

extension ConfigExample: FetchableRecord {
    init(row: Row) {
        self.id = row["id"]
        self.componentId = row["component_id"]
        self.exampleYaml = row["example_yaml"]
        self.description = row["description"]
    }
}

// MARK: - Configuration Value Types

/// Represents a value for a configuration field
enum ConfigValue: Codable, Equatable {
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
    
    var stringMapValue: [String: String]? {
        if case .stringMap(let value) = self { return value }
        return nil
    }
    
    var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}

// MARK: - Component Instance Configuration

/// Represents a configured component instance in a pipeline
struct ComponentInstance: Codable, Identifiable, Hashable {
    let id = UUID()
    let definition: ComponentDefinition
    var instanceName: String // e.g., "otlp/internal", "batch/traces"
    var configuration: [String: ConfigValue] = [:]
    
    var displayName: String {
        if instanceName != definition.name {
            return "\(definition.displayName) (\(instanceName))"
        }
        return definition.displayName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ComponentInstance, rhs: ComponentInstance) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents a pipeline configuration
struct PipelineConfiguration: Codable, Identifiable, Hashable {
    let id = UUID()
    var name: String // traces, metrics, logs
    var receivers: [ComponentInstance] = []
    var processors: [ComponentInstance] = []
    var exporters: [ComponentInstance] = []
    
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

/// Complete collector configuration
struct CollectorConfiguration: Codable, Identifiable, Hashable {
    let id = UUID()
    var version: String
    var receivers: [ComponentInstance] = []
    var processors: [ComponentInstance] = []
    var exporters: [ComponentInstance] = []
    var extensions: [ComponentInstance] = []
    var connectors: [ComponentInstance] = []
    var pipelines: [PipelineConfiguration] = []
    
    var allComponents: [ComponentInstance] {
        receivers + processors + exporters + extensions + connectors
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CollectorConfiguration, rhs: CollectorConfiguration) -> Bool {
        lhs.id == rhs.id
    }
}
