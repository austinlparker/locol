import Foundation
import Yams
import Subprocess
import os

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
class ProcessManager: ObservableObject, ProcessManagementService {
    @Published private(set) var activeProcess: Subprocess? = nil
    
    private let fileManager: CollectorFileManager
    private let logger = Logger.app
    private var activeCollectorInfo: (id: UUID, name: String)? = nil
    
    var activeCollectorId: UUID? {
        return activeCollectorInfo?.id
    }
    
    init(fileManager: CollectorFileManager) {
        self.fileManager = fileManager
    }
    
    func startCollector(_ collector: CollectorInstance) async throws {
        // Check if we already have an active collector
        if activeProcess != nil {
            // Stop the currently running collector first
            try await stopCollector()
        }
        
        // Build command array
        var command = [collector.binaryPath, "--config", collector.configPath]
        if !collector.commandLineFlags.isEmpty {
            command.append(contentsOf: collector.commandLineFlags.components(separatedBy: " "))
        }
        
        // Launch process
        let process = Subprocess(command)
        process.environment = ["OTEL_LOG_LEVEL": "debug"]
        
        // Capture collector name to avoid reference cycle
        let collectorName = collector.name
        
        do {
            try process.launch(
                outputHandler: { [weak self] data in
                    if let output = String(data: data, encoding: .utf8) {
                        self?.logger.debug("[\(collectorName)] \(output)")
                        CollectorLogger.shared.debug("[\(collectorName)] \(output)")
                    }
                },
                errorHandler: { [weak self] data in
                    if let output = String(data: data, encoding: .utf8) {
                        self?.logger.debug("[\(collectorName)] \(output)")
                        CollectorLogger.shared.debug("[\(collectorName)] \(output)")
                    }
                },
                terminationHandler: { [weak self] process in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.handleProcessTermination(process)
                    }
                }
            )
            
            // Update state on main thread
            // We're already on the main actor
            self.activeProcess = process
            self.activeCollectorInfo = (id: collector.id, name: collector.name)
            
            // Log success 
            self.logger.info("[\(collectorName)] Started collector process")
            
        } catch {
            throw error
        }
    }
    
    func stopCollector() async throws {
        guard let process = activeProcess else {
            throw ProcessError.notRunning
        }
        
        // Terminate process
        process.kill()
        
        // Give it a moment to terminate gracefully
        let timeout = DispatchTime.now() + .milliseconds(500)
        
        var isRunning = process.isRunning
        while isRunning && DispatchTime.now() < timeout {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            isRunning = process.isRunning
        }
        
        if isRunning {
            // Force kill if still running
            kill(Int32(process.pid), SIGKILL)
        }
        
        // Handle termination on main thread for UI updates
        // We're already on the main actor
        handleProcessTermination(process)
        logger.info("Stopped collector process")
    }
    
    func isRunning(_ collector: CollectorInstance) -> Bool {
        guard let process = activeProcess, activeCollectorInfo?.id == collector.id else { 
            return false 
        }
        return process.isRunning
    }
    
    func getActiveProcess() -> Subprocess? {
        return activeProcess
    }
    
    func getCollectorComponents(_ collector: CollectorInstance) async throws -> ComponentList {
        // Use string(for:) convenience method for simple command execution
        let output = try await Subprocess.string(for: [collector.binaryPath, "components"])
        return try YAMLDecoder().decode(ComponentList.self, from: output)
    }
    
    private func handleProcessTermination(_ process: Subprocess) {
        // We're already on the main actor
        activeProcess = nil
        activeCollectorInfo = nil
        
        // Log termination status
        if process.exitCode != 0 {
            logger.error("Process terminated with status: \(process.exitCode)")
            CollectorLogger.shared.error("Process terminated with status: \(process.exitCode)")
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