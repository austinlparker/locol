import Foundation
import Subprocess
import System

actor DataGeneratorProcess {
    static let shared = DataGeneratorProcess()
    private var activeTask: Task<Void, Never>?
    private var terminationCallback: (() -> Void)?
    private var hasTerminated = false
    
    private init() {}
    
    var isRunning: Bool {
        activeTask?.isCancelled == false && !hasTerminated
    }
    
    func start(
        binary: String,
        arguments: [String],
        outputHandler: @escaping @Sendable (String) -> Void,
        onTermination: @escaping @Sendable () -> Void
    ) {
        // Reset state
        hasTerminated = false
        terminationCallback = onTermination
        
        // Start process using new API
        activeTask = Task {
            do {
                _ = try await run(.path(FilePath(binary)), arguments: Arguments(arguments)) { execution, standardOutput in
                    // Process stdout lines
                    for try await line in standardOutput.lines(encoding: UTF8.self) {
                        await MainActor.run {
                            outputHandler(line)
                        }
                    }
                }
                
                // Handle termination
                self.handleTermination()
                
            } catch {
                // Handle error and terminate
                self.handleTermination()
            }
        }
    }
    
    func stop() {
        if let task = activeTask {
            task.cancel()
            activeTask = nil
            callTerminationCallback()
        }
    }
    
    private func handleTermination() {
        activeTask = nil
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
