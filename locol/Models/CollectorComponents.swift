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