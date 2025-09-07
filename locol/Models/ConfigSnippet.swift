import Foundation
import Yams
import os
import CoreTransferable

enum SnippetType: String, CaseIterable, Codable {
    case receivers
    case processors
    case exporters
    
    var displayName: String {
        rawValue.capitalized
    }
}

struct ConfigSnippet: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let type: SnippetType
    let content: String
    private(set) var parsedContent: [String: Any]?
    
    init(name: String, type: SnippetType, content: String) {
        self.id = UUID()
        self.name = name
        self.type = type
        let resolvedContent = Self.resolvePlaceholders(in: content)
        self.content = resolvedContent
        self.parsedContent = (try? Yams.load(yaml: resolvedContent) as? [String: Any])
    }

    private static func resolvePlaceholders(in content: String) -> String {
        // Leave placeholders as-is; the manager can resolve when merging
        return content
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ConfigSnippet, rhs: ConfigSnippet) -> Bool {
        lhs.id == rhs.id
    }
}

extension ConfigSnippet: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .locolSnippet)
    }
}

// MARK: - Codable
extension ConfigSnippet {
    enum CodingKeys: String, CodingKey { case id, name, type, content }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try c.decode(String.self, forKey: .name)
        self.type = try c.decode(SnippetType.self, forKey: .type)
        let rawContent = try c.decode(String.self, forKey: .content)
        self.content = Self.resolvePlaceholders(in: rawContent)
        self.parsedContent = (try? Yams.load(yaml: self.content) as? [String: Any])
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(type, forKey: .type)
        try c.encode(content, forKey: .content)
    }
}
