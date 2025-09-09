import Foundation
import Yams

/// Serializes collector configurations to/from YAML
class ConfigSerializer {
    
    // MARK: - YAML Generation
    
    /// Convert a collector configuration to YAML
    static func generateYAML(from config: CollectorConfiguration) throws -> String {
        var yamlDict: [String: Any] = [:]
        
        // Add receivers section
        if !config.receivers.isEmpty {
            yamlDict["receivers"] = try serializeComponents(config.receivers)
        }
        
        // Add processors section
        if !config.processors.isEmpty {
            yamlDict["processors"] = try serializeComponents(config.processors)
        }
        
        // Add exporters section
        if !config.exporters.isEmpty {
            yamlDict["exporters"] = try serializeComponents(config.exporters)
        }
        
        // Add extensions section
        if !config.extensions.isEmpty {
            yamlDict["extensions"] = try serializeComponents(config.extensions)
        }
        
        // Add connectors section
        if !config.connectors.isEmpty {
            yamlDict["connectors"] = try serializeComponents(config.connectors)
        }
        
        // Add service section with pipelines
        if !config.pipelines.isEmpty {
            yamlDict["service"] = [
                "pipelines": try serializePipelines(config.pipelines)
            ]
        }
        
        // Convert to YAML
        return try Yams.dump(object: yamlDict, indent: 2, width: 120)
    }
    
    private static func serializeComponents(_ components: [ComponentInstance]) throws -> [String: Any] {
        var result: [String: Any] = [:]
        
        for component in components {
            let componentConfig = try serializeComponentConfiguration(component.configuration)
            result[component.instanceName] = componentConfig.isEmpty ? [:] : componentConfig
        }
        
        return result
    }
    
    private static func serializeComponentConfiguration(_ config: [String: ConfigValue]) throws -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in config {
            result[key] = try serializeConfigValue(value)
        }
        
        return result
    }
    
    private static func serializeConfigValue(_ value: ConfigValue) throws -> Any {
        switch value {
        case .string(let str):
            return str
        case .int(let int):
            return int
        case .bool(let bool):
            return bool
        case .double(let double):
            return double
        case .duration(let duration):
            return formatDuration(duration)
        case .stringArray(let array):
            return array
        case .array(let array):
            return try array.map { try serializeConfigValue($0) }
        case .stringMap(let map):
            return map
        case .map(let map):
            var result: [String: Any] = [:]
            for (key, val) in map {
                result[key] = try serializeConfigValue(val)
            }
            return result
        case .null:
            return NSNull()
        }
    }
    
    private static func serializePipelines(_ pipelines: [PipelineConfiguration]) throws -> [String: Any] {
        var result: [String: Any] = [:]
        
        for pipeline in pipelines {
            var pipelineConfig: [String: Any] = [:]
            
            if !pipeline.receivers.isEmpty {
                pipelineConfig["receivers"] = pipeline.receivers.map { $0.instanceName }
            }
            
            if !pipeline.processors.isEmpty {
                pipelineConfig["processors"] = pipeline.processors.map { $0.instanceName }
            }
            
            if !pipeline.exporters.isEmpty {
                pipelineConfig["exporters"] = pipeline.exporters.map { $0.instanceName }
            }
            
            result[pipeline.name] = pipelineConfig
        }
        
        return result
    }
    
    private static func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return "\(Int(duration * 1000))ms"
        } else if duration < 60 {
            return "\(Int(duration))s"
        } else if duration < 3600 {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return seconds == 0 ? "\(minutes)m" : "\(minutes)m\(seconds)s"
        } else {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            return minutes == 0 ? "\(hours)h" : "\(hours)h\(minutes)m"
        }
    }
    
    // MARK: - YAML Parsing
    
    /// Parse a YAML string into a collector configuration
    static func parseYAML(_ yamlString: String, version: String) async throws -> CollectorConfiguration {
        guard let yamlDict = try Yams.load(yaml: yamlString) as? [String: Any] else {
            throw ConfigSerializationError.invalidYAML
        }
        
        var config = CollectorConfiguration(version: version)
        
        // Parse receivers
        if let receivers = yamlDict["receivers"] as? [String: Any] {
            config.receivers = try await parseComponentsSection(receivers, type: .receiver, version: version)
        }
        
        // Parse processors
        if let processors = yamlDict["processors"] as? [String: Any] {
            config.processors = try await parseComponentsSection(processors, type: .processor, version: version)
        }
        
        // Parse exporters
        if let exporters = yamlDict["exporters"] as? [String: Any] {
            config.exporters = try await parseComponentsSection(exporters, type: .exporter, version: version)
        }
        
        // Parse extensions
        if let extensions = yamlDict["extensions"] as? [String: Any] {
            config.extensions = try await parseComponentsSection(extensions, type: .`extension`, version: version)
        }
        
        // Parse connectors
        if let connectors = yamlDict["connectors"] as? [String: Any] {
            config.connectors = try await parseComponentsSection(connectors, type: .connector, version: version)
        }
        
        // Parse service/pipelines
        if let service = yamlDict["service"] as? [String: Any],
           let pipelines = service["pipelines"] as? [String: Any] {
            config.pipelines = try parsePipelines(pipelines, from: config)
        }
        
        return config
    }
    
    private static func parseComponentsSection(
        _ section: [String: Any], 
        type: ComponentType, 
        version: String
    ) async throws -> [ComponentInstance] {
        
        let database = ComponentDatabase()
        var instances: [ComponentInstance] = []
        
        for (instanceName, instanceConfig) in section {
            // Parse component name (before any '/')
            let componentName = instanceName.components(separatedBy: "/").first ?? instanceName
            
            // Find component definition
            guard let definition = await database.component(name: componentName + type.rawValue, version: version) else {
                // Skip unknown components for now
                continue
            }
            
            var instance = ComponentInstance(
                definition: definition,
                instanceName: instanceName
            )
            
            // Parse configuration
            if let config = instanceConfig as? [String: Any] {
                instance.configuration = try parseComponentConfiguration(config, for: definition)
            }
            
            instances.append(instance)
        }
        
        return instances
    }
    
    private static func parseComponentConfiguration(
        _ config: [String: Any], 
        for definition: ComponentDefinition
    ) throws -> [String: ConfigValue] {
        
        var result: [String: ConfigValue] = [:]
        
        for (key, value) in config {
            // Find the field definition
            guard let field = definition.fields.first(where: { $0.yamlKey == key }) else {
                // Skip unknown fields
                continue
            }
            
            result[key] = try parseConfigValue(value, expectedType: field.fieldType)
        }
        
        return result
    }
    
    private static func parseConfigValue(_ value: Any, expectedType: ConfigFieldType) throws -> ConfigValue {
        switch expectedType {
        case .string, .custom:
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
            } else if let str = value as? String {
                return .bool(str.lowercased() == "true")
            }
            
        case .double:
            if let double = value as? Double {
                return .double(double)
            } else if let int = value as? Int {
                return .double(Double(int))
            } else if let str = value as? String, let double = Double(str) {
                return .double(double)
            }
            
        case .duration:
            if let str = value as? String {
                return .duration(parseDuration(str))
            } else if let double = value as? Double {
                return .duration(double)
            }
            
        case .stringArray:
            if let array = value as? [String] {
                return .stringArray(array)
            } else if let array = value as? [Any] {
                let stringArray = array.compactMap { $0 as? String }
                return .stringArray(stringArray)
            }
            
        case .array:
            if let array = value as? [Any] {
                let configArray = try array.map { try parseConfigValue($0, expectedType: .custom) }
                return .array(configArray)
            }
            
        case .stringMap:
            if let dict = value as? [String: String] {
                return .stringMap(dict)
            }
            
        case .map:
            if let dict = value as? [String: Any] {
                var configMap: [String: ConfigValue] = [:]
                for (k, v) in dict {
                    configMap[k] = try parseConfigValue(v, expectedType: .custom)
                }
                return .map(configMap)
            }
            
        case .enum:
            if let str = value as? String {
                return .string(str) // Enums are stored as strings
            }
        }
        
        // Return null for unparseable values
        return .null
    }
    
    private static func parseDuration(_ str: String) -> TimeInterval {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        
        // Parse patterns like "10s", "5m", "1h30m", "500ms"
        let regex = try! NSRegularExpression(pattern: "(\\d+)(ms|s|m|h)", options: [])
        let matches = regex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.count))
        
        var totalSeconds: TimeInterval = 0
        
        for match in matches {
            let numberRange = Range(match.range(at: 1), in: trimmed)!
            let unitRange = Range(match.range(at: 2), in: trimmed)!
            
            guard let number = Double(String(trimmed[numberRange])) else { continue }
            let unit = String(trimmed[unitRange])
            
            switch unit {
            case "ms":
                totalSeconds += number / 1000
            case "s":
                totalSeconds += number
            case "m":
                totalSeconds += number * 60
            case "h":
                totalSeconds += number * 3600
            default:
                break
            }
        }
        
        return totalSeconds == 0 ? Double(trimmed) ?? 0 : totalSeconds
    }
    
    private static func parsePipelines(
        _ pipelinesDict: [String: Any],
        from config: CollectorConfiguration
    ) throws -> [PipelineConfiguration] {
        
        var pipelines: [PipelineConfiguration] = []
        
        for (pipelineName, pipelineData) in pipelinesDict {
            guard let pipelineConfig = pipelineData as? [String: Any] else { continue }
            
            var pipeline = PipelineConfiguration(name: pipelineName)
            
            // Parse receivers
            if let receiverNames = pipelineConfig["receivers"] as? [String] {
                pipeline.receivers = receiverNames.compactMap { name in
                    config.receivers.first { $0.instanceName == name }
                }
            }
            
            // Parse processors
            if let processorNames = pipelineConfig["processors"] as? [String] {
                pipeline.processors = processorNames.compactMap { name in
                    config.processors.first { $0.instanceName == name }
                }
            }
            
            // Parse exporters
            if let exporterNames = pipelineConfig["exporters"] as? [String] {
                pipeline.exporters = exporterNames.compactMap { name in
                    config.exporters.first { $0.instanceName == name }
                }
            }
            
            pipelines.append(pipeline)
        }
        
        return pipelines
    }
}

// MARK: - Errors

enum ConfigSerializationError: Error, LocalizedError {
    case invalidYAML
    case unsupportedType
    case missingComponent(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidYAML:
            return "Invalid YAML format"
        case .unsupportedType:
            return "Unsupported configuration type"
        case .missingComponent(let name):
            return "Component '\(name)' not found in database"
        }
    }
}