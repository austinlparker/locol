import Foundation
import Yams
import os

enum SnippetType: String, CaseIterable {
    case receivers
    case processors
    case exporters
    
    var displayName: String {
        rawValue.capitalized
    }
}

struct ConfigSnippet: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let type: SnippetType
    let content: String
    private(set) var parsedContent: [String: Any]?
    
    init(name: String, type: SnippetType, content: String) {
        self.name = name
        self.type = type
        
        // Resolve placeholders in content if this snippet contains them
        let resolvedContent = Self.resolvePlaceholders(in: content)
        self.content = resolvedContent
        
        // Try to parse the YAML content
        do {
            if let yaml = try Yams.load(yaml: resolvedContent) as? [String: Any] {
                self.parsedContent = yaml
            }
        } catch {
            Logger.app.error("Failed to parse YAML content for snippet \(name): \(error.localizedDescription)")
        }
    }
    
    private static func resolvePlaceholders(in content: String) -> String {
        // Only resolve placeholders if the content contains them
        guard content.contains("{{") && content.contains("}}") else {
            return content
        }
        
        let settings = OTLPReceiverSettings.shared
        
        return content
            .replacingOccurrences(of: "{{TRACES_ENDPOINT}}", with: settings.grpcEndpoint)
            .replacingOccurrences(of: "{{METRICS_ENDPOINT}}", with: settings.grpcEndpoint)
            .replacingOccurrences(of: "{{LOGS_ENDPOINT}}", with: settings.grpcEndpoint)
            .replacingOccurrences(of: "{{BIND_ADDRESS}}", with: settings.bindAddress)
            .replacingOccurrences(of: "{{TRACES_PORT}}", with: "\(settings.grpcPort)")
            .replacingOccurrences(of: "{{METRICS_PORT}}", with: "\(settings.grpcPort)")
            .replacingOccurrences(of: "{{LOGS_PORT}}", with: "\(settings.grpcPort)")
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ConfigSnippet, rhs: ConfigSnippet) -> Bool {
        lhs.id == rhs.id
    }
} 