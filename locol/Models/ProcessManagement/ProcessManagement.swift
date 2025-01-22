import Foundation
import Subprocess

protocol ProcessManagement {
    func startProcess(binary: String, arguments: [String], outputHandler: @escaping (String) -> Void, terminationHandler: @escaping (Subprocess) -> Void) throws
    func stopProcess() throws
    func getActiveProcess() -> Subprocess?
    func isRunning() -> Bool
}

class BaseProcessManager: ProcessManagement {
    private var activeSubprocess: Subprocess?
    
    init() {}
    
    func startProcess(
        binary: String,
        arguments: [String],
        outputHandler: @escaping (String) -> Void,
        terminationHandler: @escaping (Subprocess) -> Void
    ) throws {
        guard activeSubprocess == nil else {
            throw ProcessError.alreadyRunning
        }
        
        // Build command array with binary as first argument
        var command = [binary]
        command.append(contentsOf: arguments)
        
        let process = Subprocess(command)
        
        // Launch process with output handling
        try process.launch(
            outputHandler: { data in
                if let output = String(data: data, encoding: .utf8) {
                    outputHandler(output)
                }
            },
            errorHandler: { data in
                if let output = String(data: data, encoding: .utf8) {
                    outputHandler(output)
                }
            },
            terminationHandler: { [weak self] process in
                self?.activeSubprocess = nil
                terminationHandler(process)
            }
        )
        
        self.activeSubprocess = process
    }
    
    func stopProcess() throws {
        guard let process = activeSubprocess else {
            throw ProcessError.notRunning
        }
        process.kill()
        activeSubprocess = nil
    }
    
    func getActiveProcess() -> Subprocess? {
        return activeSubprocess
    }
    
    func isRunning() -> Bool {
        return activeSubprocess?.isRunning ?? false
    }
} 