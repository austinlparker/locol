import SwiftUI
import Yams
import AppKit
import STTextViewSwiftUI

struct ComponentInspectorView: View {
    @Binding var component: ComponentInstance
    let onConfigChanged: (ComponentInstance) -> Void
    
    @State private var instanceName: String
    @State private var fieldValues: [String: ConfigValue] = [:]
    @State private var expandedSections: Set<String> = ["basic"]
    
    init(component: Binding<ComponentInstance>, onConfigChanged: @escaping (ComponentInstance) -> Void) {
        self._component = component
        self.onConfigChanged = onConfigChanged
        self._instanceName = State(initialValue: component.wrappedValue.instanceName)
        self._fieldValues = State(initialValue: component.wrappedValue.configuration)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Component header
                componentHeader

                // Instance name
                instanceNameSection

                // Validation summary
                validationSection

                // Configuration fields
                configurationFieldsSection
            }
            .padding()
        }
        .onChange(of: instanceName) { _, newValue in
            let base = component.definition.name
            var corrected = newValue
            if newValue == base {
                corrected = base
            } else if newValue.hasPrefix(base + "/") {
                corrected = newValue
            } else {
                // Force prefix to base, preserve suffix if provided
                let parts = newValue.split(separator: "/", maxSplits: 1).map(String.init)
                let suffix = parts.count > 1 ? parts[1] : (parts.first ?? "")
                corrected = suffix.isEmpty ? base : base + "/" + suffix
            }
            var updatedComponent = component
            updatedComponent.instanceName = corrected
            component = updatedComponent
            onConfigChanged(updatedComponent)
        }
        .onChange(of: fieldValues) { _, newValues in
            var updatedComponent = component
            updatedComponent.configuration = newValues
            component = updatedComponent
            onConfigChanged(updatedComponent)
        }
    }

    // MARK: - Validation Summary

    private var validationSection: some View {
        let issues = computeConstraintIssues()
        return VStack(alignment: .leading, spacing: 8) {
            Text("Validation")
                .font(.headline)
            if issues.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text("No component-level validation issues detected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(issues, id: \.self) { msg in
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func computeConstraintIssues() -> [String] {
        var messages: [String] = []
        let values = fieldValues
        func isSet(_ key: String) -> Bool {
            guard let v = values[key] else { return false }
            switch v {
            case .null:
                return false
            case .string(let s):
                return !s.isEmpty
            case .int(_), .bool(_), .double(_), .duration(_):
                return true
            case .stringArray(let arr):
                return !arr.isEmpty
            case .stringMap(let m):
                return !m.isEmpty
            case .array(let arr):
                return !arr.isEmpty
            case .map(let m):
                return !m.isEmpty
            }
        }
        for c in component.definition.constraints {
            let count = c.keys.filter { isSet($0) }.count
            switch c.kind {
            case "anyOf":
                if count == 0 {
                    messages.append("At least one of [\(c.keys.joined(separator: ", "))] must be set.")
                }
            case "oneOf":
                if count != 1 {
                    messages.append("Exactly one of [\(c.keys.joined(separator: ", "))] must be set (currently \(count)).")
                }
            case "atMostOne":
                if count > 1 {
                    messages.append("At most one of [\(c.keys.joined(separator: ", "))] may be set (currently \(count)).")
                }
            case "allOf":
                if count != c.keys.count {
                    messages.append("All of [\(c.keys.joined(separator: ", "))] must be set (currently \(count)/\(c.keys.count)).")
                }
            default:
                break
            }
        }
        return messages
    }

    // MARK: - Component Header
    
    private var componentHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(component.definition.type.color)
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(component.definition.displayName)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(component.definition.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            if let description = component.definition.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Text("Module: `\(component.definition.module)`")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fontDesign(.monospaced)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Instance Name Section
    
    private var instanceNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Component ID")
                .font(.headline)
            HStack(spacing: 4) {
                Text("\(component.definition.name)/")
                    .fontDesign(.monospaced)
                TextField("amusing-walrus", text: suffixBinding, prompt: Text("amusing-walrus"))
                    .textFieldStyle(.roundedBorder)
                    .fontDesign(.monospaced)
            }
            Text("This becomes the YAML key (e.g., receivers: { \(component.definition.name)/suffix: … }).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var suffixBinding: Binding<String> {
        Binding<String>(
            get: {
                let base = component.definition.name
                if instanceName == base { return "" }
                if instanceName.hasPrefix(base + "/") { return String(instanceName.dropFirst(base.count + 1)) }
                // Fallback: if external code set a different base, preserve suffix portion after first '/'
                if let range = instanceName.firstIndex(of: "/") {
                    return String(instanceName[instanceName.index(after: range)...])
                }
                return ""
            },
            set: { newSuffix in
                let base = component.definition.name
                let trimmed = newSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
                let combined = trimmed.isEmpty ? base : base + "/" + trimmed
                if combined != instanceName {
                    instanceName = combined
                }
            }
        )
    }
    
    // MARK: - Configuration Fields
    
    private var configurationFieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuration")
                .font(.headline)
            
            // Merge DB-defined fields with inferred ones from constraints and current config
            let tree = buildFieldTree(from: mergedFields())
            FieldTreeView(node: tree, expandedSections: $expandedSections) { field in
                ConfigFieldEditorView(
                    field: field,
                    value: binding(for: field),
                    defaultValue: defaultValue(for: field)
                )
            }
            .onAppear { seedExpansion(for: tree) }
            .onChange(of: component.definition.id) { _, _ in seedExpansion(for: tree) }
        }
    }
    
    private var noConfigurationSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("No Configuration Options")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("This component doesn't have configurable properties.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Properties
    
    // Build a hierarchical tree from dotted yaml keys
    private func buildFieldTree(from fields: [ConfigField]) -> FieldTreeNode {
        var root = FieldTreeNode(name: "root")
        for f in fields.sorted(by: { $0.yamlKey < $1.yamlKey }) {
            let parts = f.yamlKey.split(separator: ".").map(String.init)
            root.insert(parts: parts, field: f)
        }
        return root
    }

    // Merge schema fields with synthetic fields inferred from constraints and existing config.
    // This makes advanced/nested groups (e.g., protocols.grpc, tls, http) visible even when
    // the bundled schema lacks explicit leaf entries.
    private func mergedFields() -> [ConfigField] {
        var result = component.definition.fields
        var seen = Set(result.map { $0.yamlKey })

        // 1) Add constraint keys as virtual map groups when missing
        for constraint in component.definition.constraints {
            for key in constraint.keys where !seen.contains(key) {
                result.append(makeVirtualField(yamlKey: key, preferred: .map, description: "Advanced configuration group"))
                seen.insert(key)
            }
        }

        // 2) Add any keys present in current configuration but absent in schema
        for (key, value) in fieldValues where !seen.contains(key) {
            let inferredType = inferFieldType(from: value)
            result.append(makeVirtualField(yamlKey: key, preferred: inferredType, description: "Imported or custom field"))
            seen.insert(key)
        }

        // 3) Add keys from defaults as typed leaves when missing
        for d in component.definition.defaults {
            let key = d.yamlKey
            guard !key.isEmpty, !seen.contains(key), let any = d.defaultValue else { continue }
            let t = inferFieldType(fromAny: any)
            result.append(makeVirtualField(yamlKey: key, preferred: t, description: "Defaulted field"))
            seen.insert(key)
        }

        // 4) Mine examples for additional nested leaves
        for ex in component.definition.examples {
            guard let any = try? Yams.load(yaml: ex.exampleYaml), let dict = any as? [String: Any] else { continue }
            let flat = flatten(dict)
            for (key, val) in flat where !seen.contains(key) {
                result.append(makeVirtualField(yamlKey: key, preferred: inferFieldType(fromAny: val), description: "Example-derived field"))
                seen.insert(key)
            }
        }

        return result
    }

    private func makeVirtualField(yamlKey: String, preferred: ConfigFieldType, description: String) -> ConfigField {
        let name = yamlKey.split(separator: ".").last.map(String.init) ?? yamlKey
        return ConfigField(
            id: Int.random(in: -2_000_000..<0),
            componentId: component.definition.id,
            fieldName: name,
            yamlKey: yamlKey,
            fieldType: preferred,
            goType: "any",
            description: description,
            required: false,
            validationJson: nil
        )
    }

    private func inferFieldType(from value: ConfigValue) -> ConfigFieldType {
        switch value {
        case .string(_): return .string
        case .int(_): return .int
        case .bool(_): return .bool
        case .double(_): return .double
        case .duration(_): return .duration
        case .stringArray(_): return .stringArray
        case .array(_): return .array
        case .stringMap(_): return .stringMap
        case .map(_): return .map
        case .null: return .map
        }
    }

    private func inferFieldType(fromAny any: Any) -> ConfigFieldType {
        if let s = any as? String { return isDurationString(s) ? .duration : .string }
        if any is Bool { return .bool }
        if any is Int { return .int }
        if any is Double { return .double }
        if any is [String] { return .stringArray }
        if any is [String: String] { return .stringMap }
        if any is [Any] { return .array }
        if any is [String: Any] { return .map }
        return .custom
    }

    private func isDurationString(_ s: String) -> Bool {
        let pattern = "^(?:\\d+)(?:ms|s|m|h)$"
        if let _ = s.range(of: pattern, options: .regularExpression) { return true }
        return false
    }

    private func flatten(_ dict: [String: Any], prefix: String = "") -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in dict {
            let key = prefix.isEmpty ? k : "\(prefix).\(k)"
            if let sub = v as? [String: Any] {
                let nested = flatten(sub, prefix: key)
                for (nk, nv) in nested { out[nk] = nv }
            } else {
                out[key] = v
            }
        }
        return out
    }

    private func seedExpansion(for tree: FieldTreeNode) {
        // If there are no root-level leaves, auto-expand first-level groups for discoverability
        let hasRootLeaves = !tree.fields.isEmpty
        if !hasRootLeaves {
            let top = tree.children.keys
            // Expand common groups first
            let preferred: Set<String> = ["protocols", "tls", "http", "grpc"]
            let toExpand = top.filter { preferred.contains($0) } + top.filter { !preferred.contains($0) }
            for key in toExpand { expandedSections.insert(key) }
        }
    }
    
    private func binding(for field: ConfigField) -> Binding<ConfigValue> {
        Binding(
            get: { fieldValues[field.yamlKey] ?? .null },
            set: { newValue in
                fieldValues[field.yamlKey] = newValue
            }
        )
    }
    
    private func defaultValue(for field: ConfigField) -> ConfigValue? {
        // Prefer matching by YAML key to support nested fields
        guard let defaultVal = component.definition.defaults.first(where: { $0.yamlKey == field.yamlKey || $0.fieldName == field.fieldName }),
              let value = defaultVal.defaultValue else {
            return nil
        }
        
        // Convert default value to ConfigValue based on field type
        switch field.fieldType {
        case .string, .custom, .enum:
            if let str = value as? String {
                return .string(str)
            }
        case .int:
            if let int = value as? Int {
                return .int(int)
            } else if let str = value as? String, let int = Int(str) {
                return .int(int)
            }
        case .bool:
            if let bool = value as? Bool {
                return .bool(bool)
            }
        case .double:
            if let double = value as? Double {
                return .double(double)
            } else if let int = value as? Int {
                return .double(Double(int))
            }
        case .duration:
            if let str = value as? String {
                return .duration(parseDuration(str))
            }
        case .stringArray:
            if let array = value as? [String] {
                return .stringArray(array)
            }
        case .stringMap:
            if let dict = value as? [String: String] {
                return .stringMap(dict)
            }
        case .array, .map:
            // Complex types - would need more sophisticated parsing
            break
        }
        
        return nil
    }
    
    private func parseDuration(_ str: String) -> TimeInterval {
        // Basic duration parsing - could be enhanced
        if str.hasSuffix("s") {
            return Double(String(str.dropLast())) ?? 0
        } else if str.hasSuffix("ms") {
            return (Double(String(str.dropLast(2))) ?? 0) / 1000
        } else if str.hasSuffix("m") {
            return (Double(String(str.dropLast())) ?? 0) * 60
        } else if str.hasSuffix("h") {
            return (Double(String(str.dropLast())) ?? 0) * 3600
        }
        return Double(str) ?? 0
    }
}

// MARK: - Config Field Editor

struct ConfigFieldEditorView: View {
    let field: ConfigField
    @Binding var value: ConfigValue
    let defaultValue: ConfigValue?
    
    @State private var isUsingDefault = true
    @State private var showComplexEditor = false
    @State private var complexEditorText: String = ""
    @State private var complexEditorError: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Field header
            HStack {
                Text(field.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                if field.required {
                    Text("required")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(3)
                }
                
                Spacer()
                
                // Default value toggle
                if defaultValue != nil && !field.required {
                    Toggle("Use default", isOn: $isUsingDefault)
                        .font(.caption)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
            }
            
            // Field description
            if let description = field.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // YAML key for nested context
            Text("Key: \(field.yamlKey)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fontDesign(.monospaced)
            // Field validation notes
            if let notes = validationNotes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            // Field editor
            if isUsingDefault, let defaultVal = defaultValue {
                HStack {
                    Text("Default: ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(formatConfigValue(defaultVal))
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill))
                        .cornerRadius(4)
                    
                    Spacer()
                }
            } else {
                fieldEditor
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .onChange(of: isUsingDefault) { _, newValue in
            if newValue, let defaultVal = defaultValue {
                value = defaultVal
            } else if !newValue && value.isNull {
                // Set to appropriate empty value for the field type
                value = emptyValue(for: field.fieldType)
            }
        }
        .onAppear {
            // Initialize with default if value is null
            if value.isNull, let defaultVal = defaultValue {
                value = defaultVal
                isUsingDefault = true
            } else {
                isUsingDefault = false
            }
        }
        // Complex editor modal
        .sheet(isPresented: $showComplexEditor) {
            ComplexValueEditor(
                title: field.displayName,
                yamlKey: field.yamlKey,
                initialValue: value,
                expectedType: field.fieldType,
                onSave: { newVal in
                    value = newVal
                    showComplexEditor = false
                },
                onCancel: { showComplexEditor = false }
            )
            .frame(minWidth: 520, minHeight: 420)
        }
    }
    
    @ViewBuilder
    private var fieldEditor: some View {
        switch field.fieldType {
        case .string, .custom:
            TextField("Enter value", text: stringBinding)
                .textFieldStyle(.roundedBorder)
                
        case .int:
            HStack {
                TextField("0", value: intBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                
                Stepper("", value: intBinding)
                    .labelsHidden()
            }
            
        case .bool:
            Toggle(isOn: boolBinding) {
                Text("Enabled")
                    .font(.caption)
            }
            
        case .double:
            TextField("0.0", value: doubleBinding, format: .number)
                .textFieldStyle(.roundedBorder)
                
        case .duration:
            DurationPicker(duration: durationBinding)
            
        case .stringArray:
            StringArrayEditor(values: stringArrayBinding)
            
        case .stringMap:
            StringMapEditor(values: stringMapBinding)
            
        case .enum:
            // Could be enhanced with actual enum values from validation
            TextField("Select value", text: stringBinding)
                .textFieldStyle(.roundedBorder)
                
        case .array, .map:
            HStack(spacing: 8) {
                Text("Complex value")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Edit…") { showComplexEditor = true }
            }
        }
    }
    
    // MARK: - Value Bindings
    
    private var stringBinding: Binding<String> {
        Binding(
            get: { value.stringValue ?? "" },
            set: { value = .string($0) }
        )
    }
    
    private var intBinding: Binding<Int> {
        Binding(
            get: { value.intValue ?? 0 },
            set: { value = .int($0) }
        )
    }
    
    private var boolBinding: Binding<Bool> {
        Binding(
            get: { value.boolValue ?? false },
            set: { value = .bool($0) }
        )
    }
    
    private var doubleBinding: Binding<Double> {
        Binding(
            get: { value.doubleValue ?? 0.0 },
            set: { value = .double($0) }
        )
    }
    
    private var durationBinding: Binding<TimeInterval> {
        Binding(
            get: { value.durationValue ?? 0 },
            set: { value = .duration($0) }
        )
    }
    
    private var stringArrayBinding: Binding<[String]> {
        Binding(
            get: { value.stringArrayValue ?? [] },
            set: { value = .stringArray($0) }
        )
    }
    
    private var stringMapBinding: Binding<[String: String]> {
        Binding(
            get: { value.stringMapValue ?? [:] },
            set: { value = .stringMap($0) }
        )
    }
    
    // MARK: - Helper Functions
    
    private func emptyValue(for type: ConfigFieldType) -> ConfigValue {
        switch type {
        case .string, .custom, .enum: return .string("")
        case .int: return .int(0)
        case .bool: return .bool(false)
        case .double: return .double(0.0)
        case .duration: return .duration(0)
        case .stringArray: return .stringArray([])
        case .array: return .array([])
        case .stringMap: return .stringMap([:])
        case .map: return .map([:])
        }
    }
    
    private func formatConfigValue(_ value: ConfigValue) -> String {
        switch value {
        case .string(let str): return "\"\(str)\""
        case .int(let int): return "\(int)"
        case .bool(let bool): return "\(bool)"
        case .double(let double): return "\(double)"
        case .duration(let duration): return formatDuration(duration)
        case .stringArray(let array): return "[\(array.joined(separator: ", "))]"
        case .stringMap(let map): return "{\(map.count) items}"
        case .array(let array): return "[\(array.count) items]"
        case .map(let map): return "{\(map.count) items}"
        case .null: return "null"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return "\(Int(duration * 1000))ms"
        } else if duration < 60 {
            return "\(Int(duration))s"
        } else {
            let minutes = Int(duration / 60)
            return "\(minutes)m"
        }
    }
}

// Field-level validation rendering helpers
private extension ConfigFieldEditorView {
    var validationNotes: String? {
        let v = field.validation
        var parts: [String] = []
        if let min = v["min"], !min.isEmpty { parts.append(">= \(min)") }
        if let minEx = v["minExclusive"], !minEx.isEmpty { parts.append("> \(minEx)") }
        if let max = v["max"], !max.isEmpty { parts.append("<= \(max)") }
        if let maxEx = v["maxExclusive"], !maxEx.isEmpty { parts.append("< \(maxEx)") }
        if let anyOf = v["anyOf"], !anyOf.isEmpty { parts.append("Group: anyOf(\(anyOf))") }
        guard !parts.isEmpty else { return nil }
        return "Constraints: " + parts.joined(separator: ", ")
    }
}

// MARK: - Field Tree

private struct FieldTreeNode: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var children: [String: FieldTreeNode] = [:]
    var fields: [ConfigField] = []
    
    mutating func insert(parts: [String], field: ConfigField) {
        guard let first = parts.first else {
            fields.append(field)
            return
        }
        if parts.count == 1 {
            fields.append(field)
            return
        }
        var child = children[first] ?? FieldTreeNode(name: first)
        child.insert(parts: Array(parts.dropFirst()), field: field)
        children[first] = child
    }
}

private struct FieldTreeView<Leaf: View>: View {
    let node: FieldTreeNode
    @Binding var expandedSections: Set<String>
    let leafView: (ConfigField) -> Leaf
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Render leaves at this level
            ForEach(node.fields, id: \.id) { field in
                leafView(field)
            }
            // Render children
            ForEach(node.children.keys.sorted(), id: \.self) { key in
                if let child = node.children[key] {
                    DisclosureGroup(isExpanded: .init(
                        get: { expandedSections.contains(pathKey(child)) },
                        set: { isExpanded in
                            if isExpanded { expandedSections.insert(pathKey(child)) }
                            else { expandedSections.remove(pathKey(child)) }
                        }
                    )) {
                        FieldTreeView(node: child, expandedSections: $expandedSections, leafView: leafView)
                            .padding(.leading, 6)
                    } label: {
                        Text(key)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
    
    private func pathKey(_ n: FieldTreeNode) -> String {
        // Compose a stable path from the first leaf's yamlKey up to node name
        if let f = n.fields.first {
            let parts = f.yamlKey.split(separator: ".").map(String.init)
            if let idx = parts.firstIndex(of: n.name) {
                return parts.prefix(idx+1).joined(separator: ".")
            }
        }
        // Fallback to node name
        return n.name
    }
}

// MARK: - Specialized Editors

struct DurationPicker: View {
    @Binding var duration: TimeInterval
    @State private var value: Double = 0
    @State private var unit: DurationUnit = .seconds
    
    enum DurationUnit: String, CaseIterable {
        case milliseconds = "ms"
        case seconds = "s"
        case minutes = "m"
        case hours = "h"
        
        var multiplier: Double {
            switch self {
            case .milliseconds: return 0.001
            case .seconds: return 1.0
            case .minutes: return 60.0
            case .hours: return 3600.0
            }
        }
    }
    
    var body: some View {
        HStack {
            TextField("Value", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            
            Picker("Unit", selection: $unit) {
                ForEach(DurationUnit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 60)
        }
        .onAppear {
            updateFromDuration()
        }
        .onChange(of: value) { _, _ in
            duration = value * unit.multiplier
        }
        .onChange(of: unit) { _, _ in
            duration = value * unit.multiplier
        }
        .onChange(of: duration) { _, _ in
            updateFromDuration()
        }
    }
    
    private func updateFromDuration() {
        if duration >= 3600 {
            unit = .hours
            value = duration / 3600
        } else if duration >= 60 {
            unit = .minutes
            value = duration / 60
        } else if duration >= 1 {
            unit = .seconds
            value = duration
        } else {
            unit = .milliseconds
            value = duration * 1000
        }
    }
}

struct StringArrayEditor: View {
    @Binding var values: [String]
    @State private var newValue: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Add item", text: $newValue)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addItem()
                    }
                
                Button("Add", action: addItem)
                    .disabled(newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            ForEach(Array(values.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Button {
                        values.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func addItem() {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !values.contains(trimmed) {
            values.append(trimmed)
            newValue = ""
        }
    }
}

struct StringMapEditor: View {
    @Binding var values: [String: String]
    @State private var newKey: String = ""
    @State private var newValue: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Key", text: $newKey)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Value", text: $newValue)
                    .textFieldStyle(.roundedBorder)
                
                Button("Add") {
                    addItem()
                }
                .disabled(newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            ForEach(Array(values.keys.sorted()), id: \.self) { key in
                HStack {
                    Text("\(key): \(values[key] ?? "")")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Button {
                        values.removeValue(forKey: key)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func addItem() {
        let trimmedKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedKey.isEmpty {
            values[trimmedKey] = trimmedValue
            newKey = ""
            newValue = ""
        }
    }
}

// MARK: - Complex Value Editor

struct ComplexValueEditor: View {
    let title: String
    let yamlKey: String
    let initialValue: ConfigValue
    let expectedType: ConfigFieldType
    let onSave: (ConfigValue) -> Void
    let onCancel: () -> Void
    
    @State private var text: String = ""
    @State private var error: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Configure \(title)")
                        .font(.headline)
                    Text("Key: \(yamlKey)")
                        .font(.caption2)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            
            Text("Enter YAML for this value. Nested structures are supported.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            YAMLCodeEditor(text: $text)
                .frame(minHeight: 260)
            
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Save") { save() }
                    .keyboardShortcut(.return)
            }
        }
        .padding()
        .onAppear { text = encodeYAML(from: initialValue) }
    }
    
    private func save() {
        do {
            let any = try Yams.load(yaml: text)
            guard let anyVal = any else {
                error = "YAML is empty"
                return
            }
            if let newVal = convertAnyToConfigValue(anyVal, expected: expectedType) {
                onSave(newVal)
            } else {
                error = "Value does not match expected type (\(expectedType.rawValue))"
            }
        } catch {
            self.error = "Parse error: \(error.localizedDescription)"
        }
    }
    
    private func encodeYAML(from value: ConfigValue) -> String {
        let any = toAny(value)
        if let y = try? Yams.dump(object: any, indent: 2, width: 120) { return y }
        return ""
    }
    
    private func toAny(_ value: ConfigValue) -> Any {
        switch value {
        case .string(let s): return s
        case .int(let i): return i
        case .bool(let b): return b
        case .double(let d): return d
        case .duration(let t): return t
        case .stringArray(let a): return a
        case .array(let a): return a.map { toAny($0) }
        case .stringMap(let m): return m
        case .map(let m):
            var out: [String: Any] = [:]
            for (k, v) in m { out[k] = toAny(v) }
            return out
        case .null: return ""
        }
    }
    
    private func convertAnyToConfigValue(_ any: Any, expected: ConfigFieldType) -> ConfigValue? {
        switch expected {
        case .map:
            if let dict = any as? [String: Any] {
                var out: [String: ConfigValue] = [:]
                for (k, v) in dict { out[k] = convertAnyToConfigValue(v, expected: .custom) ?? .null }
                return .map(out)
            } else if let dict = any as? [String: String] {
                return .stringMap(dict)
            }
        case .array:
            if let arr = any as? [Any] {
                let out = arr.map { convertAnyToConfigValue($0, expected: .custom) ?? .null }
                return .array(out)
            } else if let arr = any as? [String] {
                return .stringArray(arr)
            }
        case .custom:
            // Heuristic mapping
            if let s = any as? String { return .string(s) }
            if let b = any as? Bool { return .bool(b) }
            if let i = any as? Int { return .int(i) }
            if let d = any as? Double { return .double(d) }
            if let dict = any as? [String: String] { return .stringMap(dict) }
            if let dict = any as? [String: Any] {
                var out: [String: ConfigValue] = [:]
                for (k, v) in dict { out[k] = convertAnyToConfigValue(v, expected: .custom) ?? .null }
                return .map(out)
            }
            if let arr = any as? [String] { return .stringArray(arr) }
            if let arr = any as? [Any] {
                let out = arr.map { convertAnyToConfigValue($0, expected: .custom) ?? .null }
                return .array(out)
            }
        default:
            // Not a complex type; try scalar cast
            if case .string = expected, let s = any as? String { return .string(s) }
            if case .bool = expected, let b = any as? Bool { return .bool(b) }
            if case .int = expected, let i = any as? Int { return .int(i) }
            if case .double = expected, let d = any as? Double { return .double(d) }
        }
        return nil
    }
}

// MARK: - STTextView-backed YAML editor (with fallback)

private struct YAMLCodeEditor: View {
    @Binding var text: String
    @State private var richText: AttributedString = AttributedString("")
    @State private var selection: NSRange? = nil
    var body: some View {
        TextView(
            text: $richText,
            selection: $selection,
            options: [.wrapLines, .highlightSelectedLine],
            plugins: []
        )
        .textViewFont(.monospacedSystemFont(ofSize: 12, weight: .regular))
        .onAppear { richText = AttributedString(text) }
        .onChange(of: text) { _, newValue in
            let current = String(richText.characters)
            if current != newValue { richText = AttributedString(newValue) }
        }
        .onChange(of: richText) { _, newValue in
            let s = String(newValue.characters)
            if s != text { text = s }
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2)))
    }
}

#Preview {
    @State var component = ComponentInstance(
        definition: ComponentDefinition(
            id: 1,
            name: "debug",
            type: .exporter,
            module: "go.opentelemetry.io/collector/exporter/debugexporter",
            description: "Debug exporter for testing",
            structName: "Config",
            versionId: 1
        ),
        instanceName: "debug/test"
    )
    
    return ComponentInspectorView(
        component: $component,
        onConfigChanged: { _ in }
    )
    .frame(width: 350, height: 600)
}
