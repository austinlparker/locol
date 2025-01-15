import Foundation
import os
import Yams

class ConfigSnippetManager: ObservableObject {
    @Published private(set) var snippets: [SnippetType: [ConfigSnippet]] = [:]
    @Published var currentConfig: [String: Any]?
    @Published var previewConfig: String?
    @Published var previewHighlightRange: Range<String.Index>?
    
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "io.aparker.locol", category: "snippets")
    
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
            currentConfig = try Yams.load(yaml: content) as? [String: Any]
            // Generate preview
            if let config = currentConfig {
                previewConfig = try formatConfig(config)
            }
        } catch {
            logger.error("Failed to load config: \(error.localizedDescription, privacy: .public)")
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
    
    func previewSnippetMerge(_ snippet: ConfigSnippet, into config: [String: Any]) -> String {
        do {
            var updatedConfig = config
            if let snippetConfig = snippet.parsedContent {
                let typeKey = snippet.type.rawValue
                let originalYaml = try formatConfig(config)
                
                // Handle both map and array values
                if var existingSection = config[typeKey] as? [String: Any] {
                    // Merge maps
                    if let newSection = snippetConfig[typeKey] as? [String: Any] {
                        for (key, value) in newSection {
                            existingSection[key] = value
                        }
                        updatedConfig[typeKey] = existingSection
                    }
                } else if var existingArray = config[typeKey] as? [[String: Any]] {
                    // Merge arrays
                    if let newArray = snippetConfig[typeKey] as? [[String: Any]] {
                        existingArray.append(contentsOf: newArray)
                        updatedConfig[typeKey] = existingArray
                    }
                } else {
                    // No existing value, just set it
                    updatedConfig[typeKey] = snippetConfig[typeKey]
                }
                
                let updatedYaml = try formatConfig(updatedConfig)
                
                // Find the range of the changed section
                if let range = findChangedRange(original: originalYaml, updated: updatedYaml) {
                    previewHighlightRange = range
                }
            }
            return try formatConfig(updatedConfig)
        } catch {
            logger.error("Failed to preview snippet merge: \(error.localizedDescription, privacy: .public)")
            previewHighlightRange = nil
            return try! formatConfig(config)  // Use original config on error
        }
    }
    
    private func findChangedRange(original: String, updated: String) -> Range<String.Index>? {
        let originalLines = original.components(separatedBy: .newlines)
        let updatedLines = updated.components(separatedBy: .newlines)
        
        // Find the first different line
        var startIdx = 0
        while startIdx < min(originalLines.count, updatedLines.count) && originalLines[startIdx] == updatedLines[startIdx] {
            startIdx += 1
        }
        
        // Find the last different line
        var endIdx = 0
        while endIdx < min(originalLines.count, updatedLines.count) && 
              originalLines[originalLines.count - 1 - endIdx] == updatedLines[updatedLines.count - 1 - endIdx] {
            endIdx += 1
        }
        
        // Convert line indices to string range
        if startIdx < updatedLines.count {
            let prefix = updatedLines[..<startIdx].joined(separator: "\n")
            let changedSection = updatedLines[startIdx..<(updatedLines.count - endIdx)].joined(separator: "\n")
            
            let start = updated.index(updated.startIndex, offsetBy: prefix.count + (prefix.isEmpty ? 0 : 1))
            let end = updated.index(start, offsetBy: changedSection.count)
            return start..<end
        }
        
        return nil
    }
    
    func mergeSnippet(_ snippet: ConfigSnippet) throws {
        guard var config = currentConfig else { return }
        
        if let snippetConfig = snippet.parsedContent {
            let typeKey = snippet.type.rawValue
            
            // Handle both map and array values
            if var existingSection = config[typeKey] as? [String: Any] {
                // Merge maps
                if let newSection = snippetConfig[typeKey] as? [String: Any] {
                    for (key, value) in newSection {
                        existingSection[key] = value
                    }
                    config[typeKey] = existingSection
                }
            } else if var existingArray = config[typeKey] as? [[String: Any]] {
                // Merge arrays
                if let newArray = snippetConfig[typeKey] as? [[String: Any]] {
                    existingArray.append(contentsOf: newArray)
                    config[typeKey] = existingArray
                }
            } else {
                // No existing value, just set it
                config[typeKey] = snippetConfig[typeKey]
            }
            
            currentConfig = config
            previewConfig = try formatConfig(config)
        }
    }
    
    private func formatConfig(_ config: [String: Any]) throws -> String {
        // Convert null values to empty maps
        func convertNulls(_ dict: [String: Any]) -> [String: Any] {
            var result: [String: Any] = [:]
            for (key, value) in dict {
                if let dict = value as? [String: Any] {
                    result[key] = convertNulls(dict)
                } else if let array = value as? [[String: Any]] {
                    result[key] = array.map(convertNulls)
                } else if value is NSNull || String(describing: value) == "null" {
                    result[key] = [String: Any]()
                } else {
                    result[key] = value
                }
            }
            return result
        }
        
        let convertedConfig = convertNulls(config)
        let node = try Yams.Node(convertedConfig)
        return try Yams.serialize(node: node, indent: 2, sortKeys: false)
    }
} 