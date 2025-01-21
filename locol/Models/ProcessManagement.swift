import Foundation

protocol ProcessManagement {
    func startProcess(binary: String, arguments: [String], outputHandler: @escaping (String) -> Void, terminationHandler: @escaping (Process) -> Void) throws
    func stopProcess() throws
    func getActiveProcess() -> Process?
    func isRunning() -> Bool
}

class BaseProcessManager: ProcessManagement {
    private var activeProcess: Process?
    private var outputPipe: Pipe?
    
    func startProcess(
        binary: String,
        arguments: [String],
        outputHandler: @escaping (String) -> Void,
        terminationHandler: @escaping (Process) -> Void
    ) throws {
        guard activeProcess == nil else {
            throw ProcessError.alreadyRunning
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        // Set up termination handler
        process.terminationHandler = { [weak self] process in
            self?.activeProcess = nil
            self?.outputPipe = nil
            terminationHandler(process)
        }
        
        // Handle process output
        Task {
            do {
                for try await line in pipe.fileHandleForReading.bytes.lines {
                    outputHandler(line)
                }
            } catch {
                outputHandler("Error reading output: \(error.localizedDescription)")
            }
        }
        
        try process.run()
        self.activeProcess = process
        self.outputPipe = pipe
    }
    
    func stopProcess() throws {
        guard let process = activeProcess else {
            throw ProcessError.notRunning
        }
        process.terminate()
    }
    
    func getActiveProcess() -> Process? {
        return activeProcess
    }
    
    func isRunning() -> Bool {
        return activeProcess != nil && activeProcess!.isRunning
    }
} 