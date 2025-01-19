import Foundation
import os
import Yams

class ConfigSnippetManager: ObservableObject {
    @Published private(set) var snippets: [SnippetType: [ConfigSnippet]] = [:]
    @Published var currentConfig: [String: Any]?
    @Published var previewConfig: String?
    @Published var previewHighlightRange: Range<String.Index>?
    
    // Track the order of keys at each level of the YAML
    private var keyOrder: [String: [String]] = [:]
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "io.aparker.locol", category: "snippets")
    
    let defaultTemplate = """
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: localhost:4317
          http:
            endpoint: localhost:4318

    processors:
      batch:

    exporters:
      debug:
        verbosity: detailed

    service:
      pipelines:
        traces:
          receivers:
            - otlp
          processors:
            - batch
          exporters:
            - debug
    """
    
    init() {
        loadSnippets()
    }
    
    private func loadSnippets() {
        logger.notice("Starting snippet loading...")
        
        if let resourcePath = Bundle.main.resourcePath {
            let resourceURL = URL(fileURLWithPath: resourcePath)
            logger.notice("Resource path: \(resourcePath, privacy: .public)")
            do {
                // We know the exact path structure now
                let resourceDir = resourceURL
                
                // Load snippets from each type's directory
                for type in SnippetType.allCases {
                    var foundSnippets: [ConfigSnippet] = []
                    
                    let typeDir = resourceDir.appendingPathComponent(type.rawValue)
                    logger.notice("Looking for snippets in \(typeDir.path, privacy: .public)")
                    
                    guard let contents = try? FileManager.default.contentsOfDirectory(at: typeDir, includingPropertiesForKeys: nil) else {
                        logger.notice("No contents found in \(typeDir.path, privacy: .public)")
                        continue
                    }
                    
                    let yamlFiles = contents.filter { $0.pathExtension == "yaml" }
                    logger.notice("Found \(yamlFiles.count) YAML files in \(typeDir.path, privacy: .public)")
                    
                    let snippetsForPath = try yamlFiles.compactMap { url -> ConfigSnippet? in
                        let content = try String(contentsOf: url, encoding: .utf8)
                        logger.notice("Loading snippet from \(url.path, privacy: .public)")
                        
                        // Try to parse and validate the snippet has content for this type
                        if let yaml = try? Yams.load(yaml: content) as? [String: Any],
                           yaml[type.rawValue] != nil {
                            return ConfigSnippet(name: url.lastPathComponent, type: type, content: content)
                        } else {
                            logger.notice("Failed to parse YAML or missing \(type.rawValue) key in \(url.path, privacy: .public)")
                        }
                        return nil
                    }
                    
                    foundSnippets.append(contentsOf: snippetsForPath)
                    
                    if !foundSnippets.isEmpty {
                        snippets[type] = foundSnippets
                        logger.notice("Loaded \(foundSnippets.count) total snippets for \(type.rawValue, privacy: .public)")
                    } else {
                        logger.notice("No snippets found for \(type.rawValue, privacy: .public)")
                    }
                }
            } catch {
                logger.error("Failed to list contents: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            logger.error("Could not get resource path from bundle")
        }
    }
    
    func loadConfig(from path: String) {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            // Store the key order when loading the config
            if let yaml = try Yams.compose(yaml: content) {
                updateKeyOrder(from: yaml, path: "root")
            }
            currentConfig = try Yams.load(yaml: content) as? [String: Any]
            // Generate preview
            if let config = currentConfig {
                previewConfig = try formatConfig(config)
            }
        } catch {
            logger.error("Failed to load config: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func updateKeyOrder(from node: Yams.Node, path: String) {
        switch node {
        case .mapping(let mapping):
            // Store the order of keys at this level
            keyOrder[path] = mapping.keys.compactMap { $0.string }
            // Recursively process nested mappings
            for (key, value) in mapping {
                if let keyString = key.string {
                    updateKeyOrder(from: value, path: "\(path).\(keyString)")
                }
            }
        case .sequence(let sequence):
            // Process items in sequences
            for (index, item) in sequence.enumerated() {
                updateKeyOrder(from: item, path: "\(path)[\(index)]")
            }
        case .scalar:
            break
        }
    }
    
    func saveConfig(to path: String) throws {
        guard let config = currentConfig else {
            throw NSError(domain: "io.aparker.locol", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No config to save"
            ])
        }
        
        let yamlString = try formatConfig(config)
        try yamlString.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }
    
    private func ensureServicePipelines(in config: inout [String: Any]) {
        if config["service"] == nil {
            config["service"] = [String: Any]()
        }
        if var serviceConfig = config["service"] as? [String: Any] {
            if serviceConfig["pipelines"] == nil {
                serviceConfig["pipelines"] = [String: Any]()
                config["service"] = serviceConfig
            }
        }
    }
    
    private func mergeConfigs(base: [String: Any], with new: [String: Any], typeKey: String) throws -> [String: Any] {
        var result = base
        
        // Recursive merge function to handle nested structures
        func merge(_ existing: Any, with new: Any, path: String) -> Any {
            logger.info("Merging at path: \(path, privacy: .public)")
            
            if let existingDict = existing as? [String: Any],
               let newDict = new as? [String: Any] {
                var result = existingDict
                
                // Get or create ordered keys for this level
                var orderedKeys = keyOrder[path] ?? Array(existingDict.keys)
                
                // Add any new keys
                for key in newDict.keys where !orderedKeys.contains(key) {
                    orderedKeys.append(key)
                }
                
                keyOrder[path] = orderedKeys
                
                // Merge all keys recursively
                for (key, newValue) in newDict {
                    let newPath = "\(path).\(key)"
                    if let existingValue = existingDict[key] {
                        result[key] = merge(existingValue, with: newValue, path: newPath)
                    } else {
                        result[key] = newValue
                    }
                }
                
                return result
            } else if let existingArray = existing as? [Any],
                      let newArray = new as? [Any] {
                return existingArray + newArray
            } else {
                return new
            }
        }
        
        // Just merge everything in the snippet
        for (key, value) in new {
            let path = "root.\(key)"
            if let existing = result[key] {
                result[key] = merge(existing, with: value, path: path)
            } else {
                result[key] = value
                // Add to root key order if new
                if var rootKeys = keyOrder["root"] {
                    if !rootKeys.contains(key) {
                        rootKeys.append(key)
                        keyOrder["root"] = rootKeys
                    }
                } else {
                    keyOrder["root"] = [key]
                }
            }
        }
        
        return result
    }
    
    func previewSnippetMerge(_ snippet: ConfigSnippet, into config: [String: Any]) -> String {
        do {
            if let snippetConfig = snippet.parsedContent {
                let merged = try mergeConfigs(base: config, with: snippetConfig, typeKey: snippet.type.rawValue)
                return try formatConfig(merged)
            }
            return try formatConfig(config)
        } catch {
            logger.error("Failed to preview snippet merge: \(error.localizedDescription, privacy: .public)")
            return try! formatConfig(config)  // Use original config on error
        }
    }
    
    func mergeSnippet(_ snippet: ConfigSnippet) throws {
        guard var config = currentConfig,
              let snippetConfig = snippet.parsedContent else { return }
        
        config = try mergeConfigs(base: config, with: snippetConfig, typeKey: snippet.type.rawValue)
        logger.info("Final key order state: \(self.keyOrder, privacy: .public)")
        
        currentConfig = config
        previewConfig = try formatConfig(config)
    }
    
    private func getPipelineType(for componentType: String) -> String? {
        switch componentType {
        case "receivers": return "receivers"
        case "processors": return "processors"
        case "exporters": return "exporters"
        default: return nil
        }
    }
    
    private func formatConfig(_ config: [String: Any]) throws -> String {
        func convertToNode(_ value: Any, path: String = "root") throws -> Node {
            if let dict = value as? [String: Any] {
                // Get the ordered keys for this path, falling back to dictionary keys if no order is stored
                let orderedKeys = keyOrder[path] ?? Array(dict.keys)
                
                var mappings: [(Node, Node)] = []
                for key in orderedKeys {
                    if let value = dict[key] {
                        let newPath = "\(path).\(key)"
                        mappings.append((try Node(key), try convertToNode(value, path: newPath)))
                    }
                }
                
                // Add any new keys that weren't in the original order
                let remainingKeys = Set(dict.keys).subtracting(orderedKeys)
                for key in remainingKeys.sorted() {
                    if let value = dict[key] {
                        let newPath = "\(path).\(key)"
                        mappings.append((try Node(key), try convertToNode(value, path: newPath)))
                    }
                }
                
                return try Node(mappings)
            } else if let array = value as? [Any] {
                var sequence = try Node(array.map { try convertToNode($0, path: "\(path)[]") })
                // Only use flow style for arrays under 'service'
                if path.contains(".service") || path.hasPrefix("service.") {
                    sequence.sequence?.style = .flow
                }
                return sequence
            } else if let string = value as? String {
                return try Node(string)
            } else if let number = value as? Int {
                return try Node(number)
            } else if let bool = value as? Bool {
                return try Node(bool)
            } else if value is NSNull || String(describing: value) == "null" {
                return try Node([:])
            }
            return try Node(String(describing: value))
        }
        
        let node = try convertToNode(config)
        return try Yams.serialize(node: node, indent: 2, sortKeys: false)
    }
    
    // Helper function to handle YAML parsing errors
    private func parseYAML(_ content: String) throws -> [String: Any]? {
        do {
            return try Yams.load(yaml: content) as? [String: Any]
        } catch {
            logger.error("Failed to parse YAML: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
    
    // Helper function to handle YAML serialization errors
    private func serializeYAML(_ node: Node) throws -> String {
        do {
            return try Yams.serialize(node: node, indent: 2, sortKeys: false)
        } catch {
            logger.error("Failed to serialize YAML: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
} 
