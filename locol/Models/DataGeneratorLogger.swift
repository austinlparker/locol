import Foundation

class DataGeneratorLogger: ObservableObject {
    static let shared = DataGeneratorLogger()
    
    @Published private(set) var logs: [LogEntry] = []
    
    func log(_ message: String, level: LogLevel = .info) {
        DispatchQueue.main.async {
            self.logs.append(LogEntry(timestamp: Date(), level: level, message: message))
        }
    }
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
} 
