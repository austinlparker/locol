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
        self.content = content
        
        // Try to parse the YAML content
        do {
            if let yaml = try Yams.load(yaml: content) as? [String: Any] {
                self.parsedContent = yaml
            }
        } catch {
            Logger.app.error("Failed to parse YAML content for snippet \(name): \(error.localizedDescription)")
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ConfigSnippet, rhs: ConfigSnippet) -> Bool {
        lhs.id == rhs.id
    }
} 