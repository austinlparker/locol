import Foundation

class DataGeneratorLogger: HighVolumeLogger {
    static let shared = DataGeneratorLogger()
    
    private init() {
        super.init(capacity: 1000, source: .generator("default"))
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        log(level, message)
    }
    
    override func debug(_ message: String) {
        log(.debug, message)
    }
    
    override func info(_ message: String) {
        log(.info, message)
    }
    
    override func error(_ message: String) {
        log(.error, message)
    }
} 
