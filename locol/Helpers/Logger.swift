//
//  Logger.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import Foundation
import os
import Observation

// MARK: - System Logger
extension Logger {
    static let app = Logger(subsystem: "io.aparker.locol", category: "app")
    
    static func configureLogging() {
        // Set environment variable to enable debug logging
        setenv("OS_ACTIVITY_MODE", "debug", 1)
    }
}

// MARK: - Log Types
enum LogLevel: String {
    case debug
    case info
    case error
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .error: return .error
        }
    }
}

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let collectorName: String
    
    static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        lhs.id == rhs.id
    }
}

enum LogSource {
    case app
    case collector(String) // collector name
    case generator(String) // generator name
}

// MARK: - High Volume Logger
@Observable
class HighVolumeLogger {
    private(set) var logs: CircularBuffer<LogEntry>
    private let source: LogSource
    
    init(capacity: Int = 1000, source: LogSource) {
        self.logs = CircularBuffer(capacity: capacity)
        self.source = source
    }
    
    func log(_ level: LogLevel, _ message: String) {
        logWithTimestamp(timestamp: Date(), level: level, message: message)
    }
    
    func logWithTimestamp(timestamp: Date, level: LogLevel, message: String, collectorName: String = "default") {
        let entry = LogEntry(
            timestamp: timestamp,
            level: level,
            message: message,
            collectorName: collectorName
        )
        logs.append(entry)
    }
    
    func logMultiline(timestamp: Date, level: LogLevel, lines: [String], collectorName: String = "default") {
        let message = lines.joined(separator: "\n")
        logWithTimestamp(timestamp: timestamp, level: level, message: message, collectorName: collectorName)
    }
    
    func debug(_ message: String) {
        log(.debug, message)
    }
    
    func info(_ message: String) {
        log(.info, message)
    }
    
    func warning(_ message: String) {
        log(.error, message)
    }
    
    func error(_ message: String) {
        log(.error, message)
    }
    
    func clearLogs() {
        logs = CircularBuffer(capacity: logs.capacity)
    }
    
    // Stub methods to maintain API compatibility
    var availableServices: Set<String> {
        return Set()
    }
}

// MARK: - Specific Loggers
class CollectorLogger: HighVolumeLogger {
    static let shared = CollectorLogger()
    
    private init() {
        super.init(capacity: 1000, source: .collector("default"))
    }
    
    func debug(_ message: String, collector: String? = nil) {
        log(.debug, message)
    }
    
    func info(_ message: String, collector: String? = nil) {
        log(.info, message)
    }
    
    func error(_ message: String, collector: String? = nil) {
        log(.error, message)
    }
}

class GeneratorLogger: HighVolumeLogger {
    static let shared = GeneratorLogger()
    
    private init() {
        super.init(capacity: 1000, source: .generator("default"))
    }
    
    func debug(_ message: String, generator: String? = nil) {
        log(.debug, message)
    }
    
    func info(_ message: String, generator: String? = nil) {
        log(.info, message)
    }
    
    func error(_ message: String, generator: String? = nil) {
        log(.error, message)
    }
}
