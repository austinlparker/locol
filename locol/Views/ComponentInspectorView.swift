import SwiftUI

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
                
                // Configuration fields
                if !component.definition.fields.isEmpty {
                    configurationFieldsSection
                } else {
                    noConfigurationSection
                }
            }
            .padding()
        }
        .onChange(of: instanceName) { _, newValue in
            var updatedComponent = component
            updatedComponent.instanceName = newValue
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
            Text("Instance Name")
                .font(.headline)
            
            TextField("Instance name", text: $instanceName)
                .textFieldStyle(.roundedBorder)
            
            Text("This name is used in pipeline configurations and must be unique.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Configuration Fields
    
    private var configurationFieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuration")
                .font(.headline)
            
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(groupedFields.keys.sorted(), id: \.self) { group in
                    DisclosureGroup(isExpanded: .init(
                        get: { expandedSections.contains(group) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedSections.insert(group)
                            } else {
                                expandedSections.remove(group)
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(groupedFields[group] ?? [], id: \.id) { field in
                                ConfigFieldEditorView(
                                    field: field,
                                    value: binding(for: field),
                                    defaultValue: defaultValue(for: field)
                                )
                            }
                        }
                    } label: {
                        HStack {
                            Text(group.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(groupedFields[group]?.count ?? 0)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
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
    
    private var groupedFields: [String: [ConfigField]] {
        let fields = component.definition.fields
        
        // Group fields by category (could be enhanced with better categorization)
        var groups: [String: [ConfigField]] = [:]
        
        for field in fields {
            let group = fieldGroup(for: field)
            if groups[group] == nil {
                groups[group] = []
            }
            groups[group]?.append(field)
        }
        
        return groups
    }
    
    private func fieldGroup(for field: ConfigField) -> String {
        let fieldName = field.fieldName.lowercased()
        let yamlKey = field.yamlKey.lowercased()
        
        if fieldName.contains("tls") || fieldName.contains("ssl") || yamlKey.contains("tls") {
            return "security"
        } else if fieldName.contains("timeout") || fieldName.contains("interval") || fieldName.contains("duration") {
            return "timing"
        } else if fieldName.contains("endpoint") || fieldName.contains("address") || fieldName.contains("host") || fieldName.contains("port") {
            return "networking"
        } else if fieldName.contains("auth") || fieldName.contains("token") || fieldName.contains("key") {
            return "authentication"
        } else {
            return "basic"
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
        guard let defaultVal = component.definition.defaults.first(where: { $0.fieldName == field.fieldName }),
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
            Text("Complex type - edit in YAML mode")
                .font(.caption)
                .foregroundStyle(.secondary)
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