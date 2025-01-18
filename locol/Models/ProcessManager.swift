import Foundation
import Yams

class ProcessManager: ObservableObject {
    @Published private(set) var activeCollector: (id: UUID, process: Process)? = nil
    private let fileManager: CollectorFileManager
    private var outputPipe: Pipe? = nil
    
    init(fileManager: CollectorFileManager) {
        self.fileManager = fileManager
    }
    
    func startCollector(_ collector: CollectorInstance) throws {
        if activeCollector != nil {
            // Stop the currently running collector first
            try stopCollector()
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: collector.binaryPath)
        
        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["OTEL_LOG_LEVEL"] = "debug"  // Enable debug logging by default
        process.environment = environment
        
        // Set up arguments
        var arguments = ["--config", collector.configPath]
        if !collector.commandLineFlags.isEmpty {
            arguments.append(contentsOf: collector.commandLineFlags.components(separatedBy: " "))
        }
        process.arguments = arguments
        
        // Set up stdout/stderr pipes for logging
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        self.outputPipe = outputPipe
        
        // Handle process termination
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.handleProcessTermination(process)
            }
        }
        
        // Start reading output
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let output = String(data: data, encoding: .utf8) {
                    CollectorLogger.shared.debug("[\(collector.name)] \(output)")
                }
            }
        }
        
        try process.run()
        activeCollector = (id: collector.id, process: process)
        CollectorLogger.shared.info("[\(collector.name)] Started collector process")
    }
    
    func stopCollector() throws {
        guard let active = activeCollector else {
            throw ProcessError.notRunning
        }
        
        // Clean up pipe first
        if let pipe = outputPipe {
            pipe.fileHandleForReading.readabilityHandler = nil
            self.outputPipe = nil
        }
        
        // Terminate process
        active.process.terminate()
        
        // Wait for process to terminate
        if active.process.isRunning {
            Thread.sleep(forTimeInterval: 0.5) // Give it a moment to terminate gracefully
            if active.process.isRunning {
                // Force kill if still running
                kill(active.process.processIdentifier, SIGKILL)
            }
        }
        
        handleProcessTermination(active.process)
        CollectorLogger.shared.info("Stopped collector process")
    }
    
    func isRunning(_ collector: CollectorInstance) -> Bool {
        guard let active = activeCollector, active.id == collector.id else { return false }
        return active.process.isRunning
    }
    
    func getActiveProcess() -> Process? {
        return activeCollector?.process
    }
    
    func getCollectorComponents(_ collector: CollectorInstance) async throws -> ComponentList {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: collector.binaryPath)
        process.arguments = ["components"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe() // Redirect stderr to avoid mixing with stdout
        
        try process.run()
        
        let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        let outputString = String(data: outputData, encoding: .utf8) ?? ""
        
        // Wait for process to finish
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ProcessError.componentsFailed
        }
        
        // Parse YAML output using Yams
        return try YAMLDecoder().decode(ComponentList.self, from: outputString)
    }
    
    private func handleProcessTermination(_ process: Process) {
        // Clean up pipe if it wasn't already
        if let pipe = outputPipe {
            pipe.fileHandleForReading.readabilityHandler = nil
            self.outputPipe = nil
        }
        
        activeCollector = nil
        
        // Log termination status
        if process.terminationStatus != 0 {
            CollectorLogger.shared.error("Process terminated with status: \(process.terminationStatus)")
        }
    }
}

enum ProcessError: Error {
    case alreadyRunning
    case notRunning
    case configurationError(String)
    case startupError(String)
    case componentsFailed
} 
