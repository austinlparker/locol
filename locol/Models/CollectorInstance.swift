import Foundation

struct CollectorInstance: Codable, Identifiable {
    let id: UUID
    let name: String
    let version: String
    let binaryPath: String
    let configPath: String
    var commandLineFlags: String
    var isRunning: Bool
    
    init(id: UUID = UUID(), name: String, version: String, binaryPath: String, configPath: String, commandLineFlags: String = "", isRunning: Bool = false) {
        self.id = id
        self.name = name
        self.version = version
        self.binaryPath = binaryPath
        self.configPath = configPath
        self.commandLineFlags = commandLineFlags
        self.isRunning = isRunning
    }
} 