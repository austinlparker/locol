import Foundation
import Yams
import Subprocess
import Observation

@Observable
final class ProcessManager {
    private(set) var activeCollector: (id: UUID, process: Subprocess)? = nil
    private let fileManager: CollectorFileManager
    
    init(fileManager: CollectorFileManager) {
        self.fileManager = fileManager
    }
    
    func startCollector(_ collector: CollectorInstance) throws {
        // Stop any running collector first
        if activeCollector != nil {
            try stopCollector()
        }
        
        // Build command array
        var command = [collector.binaryPath, "--config", collector.configPath]
        
        // Check for feature gates
        let featureGatesPath = collector.configPath.replacingOccurrences(of: ".yaml", with: ".featuregates")
        if let featureGates = try? String(contentsOfFile: featureGatesPath, encoding: .utf8), !featureGates.isEmpty {
            command.append(contentsOf: ["--feature-gates", featureGates])
        }
        
        let process = Subprocess(command)
        process.environment = ["OTEL_LOG_LEVEL": "debug"]
        
        // Launch process with output handling
        try process.launch(
            outputHandler: { data in
                if let output = String(data: data, encoding: .utf8) {
                    CollectorLogger.shared.debug("[\(collector.name)] \(output)")
                }
            },
            errorHandler: { data in
                if let output = String(data: data, encoding: .utf8) {
                    CollectorLogger.shared.debug("[\(collector.name)] \(output)")
                }
            },
            terminationHandler: { [weak self] process in
                Task { @MainActor in
                    self?.handleProcessTermination(process)
                }
            }
        )
        
        self.activeCollector = (id: collector.id, process: process)
        
        // Log success
        CollectorLogger.shared.info("[\(collector.name)] Started collector process")
    }
    
    func stopCollector() throws {
        guard let active = activeCollector else {
            throw ProcessError.notRunning
        }
        
        // Terminate process
        active.process.kill()
        
        // Wait for process to terminate
        if active.process.isRunning {
            Thread.sleep(forTimeInterval: 0.5) // Give it a moment to terminate gracefully
            if active.process.isRunning {
                // Force kill if still running
                kill(Int32(active.process.pid), SIGKILL)
            }
        }
        
        // Handle termination synchronously since we're already in a blocking call
        handleProcessTermination(active.process)
        
        // Log
        CollectorLogger.shared.info("Stopped collector process")
    }
    
    func isRunning(_ collector: CollectorInstance) -> Bool {
        guard let active = activeCollector, active.id == collector.id else { return false }
        return active.process.isRunning
    }
    
    func getActiveProcess() -> Subprocess? {
        return activeCollector?.process
    }
    
    func getCollectorComponents(_ collector: CollectorInstance) async throws -> ComponentList {
        let output = try await Subprocess.string(for: [collector.binaryPath, "components"])
        return try YAMLDecoder().decode(ComponentList.self, from: output)
    }
    
    private func handleProcessTermination(_ process: Subprocess) {
        activeCollector = nil
        
        // Log termination status
        if process.exitCode != 0 {
            CollectorLogger.shared.error("Process terminated with status: \(process.exitCode)")
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
