import Foundation

struct CollectorInstance: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let version: String
    let binaryPath: String
    let configPath: String
    var commandLineFlags: String
    var isRunning: Bool
    var pid: Int?
    var startTime: Date?
    var components: ComponentList?
    
    var localPath: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".locol/collectors/\(name)").path
    }
    
    init(id: UUID = UUID(), name: String, version: String, binaryPath: String, configPath: String, commandLineFlags: String = "", isRunning: Bool = false, pid: Int? = nil, startTime: Date? = nil, components: ComponentList? = nil) {
        self.id = id
        self.name = name
        self.version = version
        self.binaryPath = binaryPath
        self.configPath = configPath
        self.commandLineFlags = commandLineFlags
        self.isRunning = isRunning
        self.pid = pid
        self.startTime = startTime
        self.components = components
    }
    
    // MARK: - Equatable & Hashable
    
    static func == (lhs: CollectorInstance, rhs: CollectorInstance) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 