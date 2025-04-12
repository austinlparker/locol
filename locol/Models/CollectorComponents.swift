import Foundation

struct ComponentStability: Codable, Hashable {
    let logs: String?
    let metrics: String?
    let traces: String?
}

struct Component: Codable, Hashable {
    let name: String
    let module: String
    let stability: ComponentStability
}

struct ComponentList: Codable, Hashable {
    let buildinfo: BuildInfo?
    let receivers: [Component]?
    let processors: [Component]?
    let exporters: [Component]?
    let connectors: [Component]?
    let extensions: [Component]?
}

struct BuildInfo: Codable, Hashable {
    let command: String?
    let description: String?
    let version: String?
} 