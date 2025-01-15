import Foundation

struct CollectorInstance: Codable, Identifiable {
    let id: UUID
    let name: String
    let version: String
    let binaryPath: String
    let configPath: String
    var commandLineFlags: String
    var isRunning: Bool
    var pid: Int?
    var startTime: Date?
    
    var localPath: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".locol/collectors/\(name)").path
    }
    
    init(id: UUID = UUID(), name: String, version: String, binaryPath: String, configPath: String, commandLineFlags: String = "", isRunning: Bool = false, pid: Int? = nil, startTime: Date? = nil) {
        self.id = id
        self.name = name
        self.version = version
        self.binaryPath = binaryPath
        self.configPath = configPath
        self.commandLineFlags = commandLineFlags
        self.isRunning = isRunning
        self.pid = pid
        self.startTime = startTime
    }
} 