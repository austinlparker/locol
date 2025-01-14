import Foundation

class ProcessManager: ObservableObject {
    @Published private(set) var runningProcesses: [UUID: Process] = [:]
    private let fileManager: CollectorFileManager
    private var outputPipes: [UUID: Pipe] = [:]
    
    init(fileManager: CollectorFileManager) {
        self.fileManager = fileManager
    }
    
    func startCollector(_ collector: CollectorInstance) throws {
        guard runningProcesses[collector.id] == nil else {
            throw ProcessError.alreadyRunning
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
        outputPipes[collector.id] = outputPipe
        
        // Handle process termination
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.handleProcessTermination(collector.id, process)
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
        runningProcesses[collector.id] = process
        CollectorLogger.shared.info("[\(collector.name)] Started collector process")
    }
    
    func stopCollector(_ collector: CollectorInstance) {
        guard let process = runningProcesses[collector.id] else { return }
        
        // Clean up pipe first
        if let pipe = outputPipes[collector.id] {
            pipe.fileHandleForReading.readabilityHandler = nil
            outputPipes.removeValue(forKey: collector.id)
        }
        
        // Terminate process
        process.terminate()
        
        // Wait for process to terminate
        if process.isRunning {
            Thread.sleep(forTimeInterval: 0.5) // Give it a moment to terminate gracefully
            if process.isRunning {
                // Force kill if still running
                kill(process.processIdentifier, SIGKILL)
            }
        }
        
        handleProcessTermination(collector.id, process)
        CollectorLogger.shared.info("[\(collector.name)] Stopped collector process")
    }
    
    func isRunning(_ collector: CollectorInstance) -> Bool {
        guard let process = runningProcesses[collector.id] else { return false }
        return process.isRunning
    }
    
    func getProcess(forCollector collector: CollectorInstance) -> Process? {
        return runningProcesses[collector.id]
    }
    
    private func handleProcessTermination(_ id: UUID, _ process: Process) {
        // Clean up pipe if it wasn't already
        if let pipe = outputPipes[id] {
            pipe.fileHandleForReading.readabilityHandler = nil
            outputPipes.removeValue(forKey: id)
        }
        
        runningProcesses.removeValue(forKey: id)
        
        // Log termination status
        if process.terminationStatus != 0 {
            CollectorLogger.shared.error("Process terminated with status: \(process.terminationStatus)")
        }
    }
}

enum ProcessError: Error {
    case alreadyRunning
    case configurationError(String)
    case startupError(String)
} 