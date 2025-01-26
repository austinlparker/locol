import Foundation

struct ComponentStability: Codable {
    let logs: String?
    let metrics: String?
    let traces: String?
}

struct Component: Codable {
    let name: String
    let module: String
    let stability: ComponentStability
}

struct ComponentList: Codable {
    let buildinfo: BuildInfo?
    let receivers: [Component]?
    let processors: [Component]?
    let exporters: [Component]?
    let connectors: [Component]?
    let extensions: [Component]?
}

struct BuildInfo: Codable {
    let command: String?
    let description: String?
    let version: String?
}

struct CollectorComponentConfig: Codable {
    let name: String
    let enabled: Bool
    let config: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case enabled
        case config
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        
        // Decode config as [String: Any] using JSONSerialization
        if let configData = try? container.decode(Data.self, forKey: .config),
           let configDict = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
            config = configDict
        } else {
            config = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(enabled, forKey: .enabled)
        
        // Encode config using JSONSerialization
        if let config = config,
           let configData = try? JSONSerialization.data(withJSONObject: config) {
            try container.encode(configData, forKey: .config)
        }
    }
}

struct CollectorComponentList: Codable {
    let receivers: [CollectorComponentConfig]
    let processors: [CollectorComponentConfig]
    let exporters: [CollectorComponentConfig]
    let extensions: [CollectorComponentConfig]
    let connectors: [CollectorComponentConfig]
} 
