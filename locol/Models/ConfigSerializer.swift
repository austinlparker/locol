import Foundation
import Yams

/// Serializes collector configurations to/from YAML
struct OverlaySettings: Sendable, Equatable {
    let grpcEndpoint: String
    let tracesEnabled: Bool
    let metricsEnabled: Bool
    let logsEnabled: Bool
}

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

    // Generate YAML with a runtime-only telemetry overlay injected into service.telemetry
    static func generateYAML(
        from config: CollectorConfiguration,
        overlayTelemetryFor collectorName: String,
        settings: OverlaySettings
    ) throws -> String {
        // Start from canonical YAML map
        var yamlDict: [String: Any] = [:]
        if !config.receivers.isEmpty { yamlDict["receivers"] = try serializeComponents(config.receivers) }
        if !config.processors.isEmpty { yamlDict["processors"] = try serializeComponents(config.processors) }
        if !config.exporters.isEmpty { yamlDict["exporters"] = try serializeComponents(config.exporters) }
        if !config.extensions.isEmpty { yamlDict["extensions"] = try serializeComponents(config.extensions) }
        if !config.connectors.isEmpty { yamlDict["connectors"] = try serializeComponents(config.connectors) }
        if !config.pipelines.isEmpty { yamlDict["service"] = ["pipelines": try serializePipelines(config.pipelines)] }

        // Build telemetry overlay via typed model for clarity and validation
        let exporterModel = OTLPTelemetryExporter(
            endpoint: settings.grpcEndpoint,
            insecure: true,
            protocolName: "grpc",
            headers: [TelemetryHeader(name: "collector-name", value: collectorName)]
        )

        var overlayModel = TelemetryOverlayModel(
            traces: nil,
            metrics: nil,
            logs: nil
        )

        // exporter dictionary keyed by exporter type
        let exporterDict: [String: Any] = ["otlp": exporterModel.asDictionary()]

        if settings.tracesEnabled {
            // processors -> [{ batch: { exporter: { otlp: {...} } } }]
            let batchWithExporter: [String: Any] = [
                "batch": ["exporter": exporterDict]
            ]
            overlayModel = TelemetryOverlayModel(
                traces: TelemetryTraces(processors: [batchWithExporter]),
                metrics: overlayModel.metrics,
                logs: overlayModel.logs
            )
        }
        if settings.metricsEnabled {
            let periodicReader: [String: Any] = [
                "periodic": ["exporter": exporterDict]
            ]
            overlayModel = TelemetryOverlayModel(
                traces: overlayModel.traces,
                metrics: TelemetryMetrics(level: "detailed", readers: [periodicReader]),
                logs: overlayModel.logs
            )
        }
        if settings.logsEnabled {
            let batchWithExporter: [String: Any] = [
                "batch": ["exporter": exporterDict]
            ]
            overlayModel = TelemetryOverlayModel(
                traces: overlayModel.traces,
                metrics: overlayModel.metrics,
                logs: TelemetryLogs(processors: [batchWithExporter])
            )
        }

        var service = (yamlDict["service"] as? [String: Any]) ?? [:]
        service["telemetry"] = overlayModel.asDictionary()
        yamlDict["service"] = service

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
            let serialized = try serializeConfigValue(value)
            // Support nested YAML keys using dot notation (e.g., protocols.http.endpoint)
            let parts = key.split(separator: ".").map(String.init)
            insertNested(into: &result, path: parts, value: serialized)
        }
        
        return result
    }

    private static func insertNested(into dict: inout [String: Any], path: [String], value: Any) {
        guard let first = path.first else { return }
        if path.count == 1 {
            dict[first] = value
            return
        }
        var child = dict[first] as? [String: Any] ?? [:]
        insertNested(into: &child, path: Array(path.dropFirst()), value: value)
        dict[first] = child
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
            
            // Find component definition by both name and expected type to avoid
            // picking the wrong component when names overlap across types (e.g., "otlp").
            guard let definition = await database.component(name: componentName, type: type, version: version) else {
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
        // Flatten nested dictionaries into dot paths so they can be matched to yamlKey
        let flat = flatten(config)
        for (key, value) in flat {
            if let field = definition.fields.first(where: { $0.yamlKey == key }) {
                result[key] = try parseConfigValue(value, expectedType: field.fieldType)
            } else {
                // Preserve unknown keys by inferring a reasonable ConfigValue.
                result[key] = inferConfigValue(value)
            }
        }
        return result
    }

    private static func flatten(_ dict: [String: Any], prefix: String = "") -> [String: Any] {
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

    // Heuristic conversion used for keys missing from the bundled schema
    private static func inferConfigValue(_ any: Any) -> ConfigValue {
        if let s = any as? String { return .string(s) }
        if let b = any as? Bool { return .bool(b) }
        if let i = any as? Int { return .int(i) }
        if let d = any as? Double { return .double(d) }
        if let arrS = any as? [String] { return .stringArray(arrS) }
        if let dictSS = any as? [String: String] { return .stringMap(dictSS) }
        if let dict = any as? [String: Any] {
            var out: [String: ConfigValue] = [:]
            for (k, v) in dict { out[k] = inferConfigValue(v) }
            return .map(out)
        }
        if let arr = any as? [Any] {
            return .array(arr.map { inferConfigValue($0) })
        }
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
