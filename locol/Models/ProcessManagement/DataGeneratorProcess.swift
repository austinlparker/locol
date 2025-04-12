import Foundation
import Subprocess

actor DataGeneratorProcess {
    static let shared = DataGeneratorProcess()
    private var activeSubprocess: Subprocess?
    private var terminationCallback: (() -> Void)?
    private var hasTerminated = false
    
    private init() {}
    
    var isRunning: Bool {
        activeSubprocess?.isRunning ?? false
    }
    
    func start(
        binary: String,
        arguments: [String],
        outputHandler: @escaping @Sendable (String) -> Void,
        onTermination: @escaping @Sendable () -> Void
    ) throws {
        // Reset state
        hasTerminated = false
        terminationCallback = onTermination
        
        // Build command array with binary as first argument
        var command = [binary]
        command.append(contentsOf: arguments)
        
        let process = Subprocess(command)
        
        // Launch process with output handling
        try process.launch(
            outputHandler: { data in
                if let output = String(data: data, encoding: .utf8) {
                    Task { @MainActor in
                        outputHandler(output)
                    }
                }
            },
            errorHandler: { data in
                if let output = String(data: data, encoding: .utf8) {
                    Task { @MainActor in
                        outputHandler(output)
                    }
                }
            },
            terminationHandler: { [weak self] _ in
                Task {
                    guard let self = self else { return }
                    await self.handleTermination()
                }
            }
        )
        
        self.activeSubprocess = process
    }
    
    func stop() {
        if let process = activeSubprocess {
            process.kill()
            activeSubprocess = nil
            callTerminationCallback()
        }
    }
    
    private func handleTermination() {
        activeSubprocess = nil
        callTerminationCallback()
    }
    
    private func callTerminationCallback() {
        if !hasTerminated {
            hasTerminated = true
            
            // Capture the callback before switching to main actor
            if let callback = terminationCallback {
                // Dispatch to main thread for UI updates
                Task { @MainActor in
                    callback()
                }
            }
        }
    }
} 
