import Foundation
import Yams
import Subprocess
import System
import os
import Observation

// Protocol that defines process management contract
// This allows us to replace direct process execution with XPC in the future
@MainActor
protocol ProcessManagementService {
    var activeCollectorId: UUID? { get }
    func startCollector(_ collector: CollectorInstance) async throws
    func stopCollector() async throws
    func isRunning(_ collector: CollectorInstance) -> Bool
    func getCollectorComponents(_ collector: CollectorInstance) async throws -> ComponentList
}

@MainActor
@Observable
class ProcessManager: ProcessManagementService {
    
    private let fileManager: CollectorFileManager
    private let logger = Logger.app
    private var activeCollectorInfo: (id: UUID, name: String)? = nil
    
    // Background task for processing output
    private var outputTask: Task<Void, Never>? = nil
    
    var activeCollectorId: UUID? {
        return activeCollectorInfo?.id
    }
    
    init(fileManager: CollectorFileManager) {
        self.fileManager = fileManager
    }
    
    private func processCollectorLines(collectorName: String) -> (String) -> Void {
        // State for multiline grouping - captured in closure
        var pendingLogLines: [String] = []
        
        func flushPendingLogs() {
            guard !pendingLogLines.isEmpty else { return }
            
            // Log output is now handled by OTLP telemetry system
            // No need to log collector output to in-memory buffer
            
            // Clear pending state
            pendingLogLines = []
        }
        
        return { [self] line in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { return }
            
            // Check if this line has a timestamp (indicates new entry)
            let (parsedTimestamp, _) = self.parseTimestampAndLevel(from: trimmedLine)
            let hasTimestamp = parsedTimestamp != nil
            
            if hasTimestamp {
                // This line starts a new entry - flush any pending entry
                flushPendingLogs()
                
                // Start new pending entry
                pendingLogLines = [trimmedLine]
                
            } else {
                // This is a continuation line (no timestamp)
                if !pendingLogLines.isEmpty {
                    // Add to current pending entry
                    pendingLogLines.append(trimmedLine)
                } else {
                    // No pending entry to append to, ignore standalone log lines
                    // Telemetry system handles actual logging
                }
            }
        }
    }
    
    
    private nonisolated func parseTimestampAndLevel(from line: String) -> (Date?, LogLevel?) {
        // Collector log format: YYYY-MM-DDTHH:MM:SS.fff±HHMM    level    ...
        // Example: 2025-08-29T23:23:23.370-0400    info    Traces    {...}
        
        let components = line.components(separatedBy: "    ").filter { !$0.isEmpty }
        
        guard components.count >= 2 else {
            // Not a standard collector log line, treat as continuation
            return (nil, nil)
        }
        
        // Parse timestamp
        let timestampString = components[0].trimmingCharacters(in: .whitespaces)
        let timestamp = parseTimestamp(timestampString)
        
        // Parse level  
        let levelString = components[1].trimmingCharacters(in: .whitespaces).lowercased()
        let level = LogLevel(rawValue: levelString) ?? .info
        
        return (timestamp, level)
    }
    
    private nonisolated func parseTimestamp(_ timestampString: String) -> Date? {
        // Handle collector timestamp format: 2025-08-29T23:23:23.370-0400
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return formatter.date(from: timestampString)
    }
    
    func startCollector(_ collector: CollectorInstance) async throws {
        // Check if we already have an active collector
        if outputTask != nil {
            // Stop the currently running collector first
            try await stopCollector()
        }
        
        // Build arguments array
        var arguments = ["--config", collector.configPath]
        if !collector.commandLineFlags.isEmpty {
            arguments.append(contentsOf: collector.commandLineFlags.components(separatedBy: " "))
        }
        
        // Create line processor
        let collectorName = collector.name
        let lineProcessor = processCollectorLines(collectorName: collectorName)
        
        // Get working directory from collector's config path
        let workingDirectory = URL(fileURLWithPath: collector.configPath).deletingLastPathComponent().path
        
        // Start collector using async let for long-running process
        outputTask = Task {
            do {
                // Set environment variables to properly identify this collector
                let resourceAttributes = "service.name=\(collector.name),service.version=\(collector.version)"
                
                let result = try await run(
                    .path(FilePath(collector.binaryPath)),
                    arguments: Arguments(arguments),
                    environment: .inherit.updating([
                        "OTEL_SERVICE_NAME": collector.name,
                        "OTEL_RESOURCE_ATTRIBUTES": resourceAttributes
                    ]),
                    workingDirectory: FilePath(workingDirectory),
                    error: .discarded
                ) { execution, standardOutput in
                    // Process stdout lines
                    for try await line in standardOutput.lines(encoding: UTF8.self) {
                        lineProcessor(line)
                    }
                }
                
                // Handle termination
                await MainActor.run {
                    // Extract exit code from termination status
                    let exitCode: Int32
                    switch result.terminationStatus {
                    case .exited(let code):
                        exitCode = code
                    default:
                        exitCode = -1
                    }
                    self.handleProcessTermination(exitCode: exitCode)
                }
                
            } catch {
                logger.error("Collector process failed: \(error)")
                await MainActor.run {
                    self.handleProcessTermination(exitCode: -1)
                }
            }
        }
        
        // Update state
        self.activeCollectorInfo = (id: collector.id, name: collector.name)
        
        // Log success 
        self.logger.info("Started collector process: \(collectorName)")
    }
    
    func stopCollector() async throws {
        guard let task = outputTask else {
            throw ProcessError.notRunning
        }
        
        // Cancel the task
        task.cancel()
        outputTask = nil
        
        // Clear state
        activeCollectorInfo = nil
        
        logger.info("Stopped collector process")
    }
    
    func isRunning(_ collector: CollectorInstance) -> Bool {
        guard let task = outputTask, activeCollectorInfo?.id == collector.id else { 
            return false 
        }
        return !task.isCancelled
    }
    
    func getActiveTask() -> Task<Void, Never>? {
        return outputTask
    }
    
    func getCollectorComponents(_ collector: CollectorInstance) async throws -> ComponentList {
        // Use run() for simple command execution
        let result = try await run(.path(FilePath(collector.binaryPath)), arguments: Arguments(["components"]), output: .string(limit: 1024*1024))
        guard let output = result.standardOutput else {
            throw ProcessError.componentsFailed
        }
        return try YAMLDecoder().decode(ComponentList.self, from: output)
    }
    
    private func handleProcessTermination(exitCode: Int32) {
        // Clear state
        outputTask = nil
        activeCollectorInfo = nil
        
        // Log termination status
        if exitCode != 0 {
            logger.error("Process terminated with status: \(exitCode)")
        }
    }
}

enum ProcessError: Error, Equatable {
    case alreadyRunning
    case notRunning
    case configurationError(String)
    case startupError(String)
    case componentsFailed
    
    static func == (lhs: ProcessError, rhs: ProcessError) -> Bool {
        switch (lhs, rhs) {
        case (.alreadyRunning, .alreadyRunning),
             (.notRunning, .notRunning),
             (.componentsFailed, .componentsFailed):
            return true
        case let (.configurationError(lhsMsg), .configurationError(rhsMsg)):
            return lhsMsg == rhsMsg
        case let (.startupError(lhsMsg), .startupError(rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
