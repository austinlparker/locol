import Foundation
import Subprocess

class DataGeneratorProcess {
    static let shared = DataGeneratorProcess()
    private var activeSubprocess: Subprocess?
    private var onTermination: (() -> Void)?
    
    private init() {}
    
    var isRunning: Bool {
        activeSubprocess?.isRunning ?? false
    }
    
    func start(
        binary: String,
        arguments: [String],
        outputHandler: @escaping (String) -> Void,
        onTermination: @escaping () -> Void
    ) throws {
        self.onTermination = onTermination
        
        // Build command array with binary as first argument
        var command = [binary]
        command.append(contentsOf: arguments)
        
        let process = Subprocess(command)
        
        // Launch process with output handling
        try process.launch(
            outputHandler: { data in
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        outputHandler(output)
                    }
                }
            },
            errorHandler: { data in
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        outputHandler(output)
                    }
                }
            },
            terminationHandler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.activeSubprocess = nil
                    self?.onTermination?()
                }
            }
        )
        
        self.activeSubprocess = process
    }
    
    func stop() {
        activeSubprocess?.kill()
        activeSubprocess = nil
        onTermination?()
    }
} 
