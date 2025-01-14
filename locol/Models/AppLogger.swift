import Foundation
import os

enum LogLevel {
    case debug
    case info
    case error
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
}

class CollectorLogger: ObservableObject {
    static let shared = CollectorLogger()
    @Published private(set) var logs: [LogEntry] = []
    private let maxLogs = 1000
    private let systemLogger = Logger(subsystem: "io.aparker.locol", category: "collector")
    
    private init() {}
    
    func debug(_ message: String) {
        systemLogger.debug("\(message)")
        addLog(level: .debug, message: message)
    }
    
    func info(_ message: String) {
        systemLogger.info("\(message)")
        addLog(level: .info, message: message)
    }
    
    func error(_ message: String) {
        systemLogger.error("\(message)")
        addLog(level: .error, message: message)
    }
    
    private func addLog(level: LogLevel, message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let entry = LogEntry(timestamp: Date(), level: level, message: message)
            self.logs.append(entry)
            
            // Trim old logs if we exceed maxLogs
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst(self.logs.count - self.maxLogs)
            }
        }
    }
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
} 