import Foundation

struct CollectorInstance: Identifiable, Codable {
    let id: UUID
    let name: String
    let version: String
    let binaryPath: String
    let configPath: String
    var isRunning: Bool
    var pid: Int?
    var startTime: Date?
    var components: ComponentList?
    
    var localPath: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".locol/collectors/\(name)").path
    }
    
    init(id: UUID = UUID(), name: String, version: String, binaryPath: String, configPath: String, isRunning: Bool = false, pid: Int? = nil, startTime: Date? = nil, components: ComponentList? = nil) {
        self.id = id
        self.name = name
        self.version = version
        self.binaryPath = binaryPath
        self.configPath = configPath
        self.isRunning = isRunning
        self.pid = pid
        self.startTime = startTime
        self.components = components
    }
}

extension CollectorInstance: Equatable {
    static func == (lhs: CollectorInstance, rhs: CollectorInstance) -> Bool {
        lhs.id == rhs.id
    }
}

extension CollectorInstance: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 