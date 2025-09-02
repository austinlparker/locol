import Foundation
import Subprocess
import System
import os

/// Configuration for process execution
struct ProcessExecutionConfig {
    let binaryPath: String
    let arguments: [String]
    let workingDirectory: String?
    let environment: [String: String]
    let outputHandler: (String) -> Void
    let terminationHandler: () -> Void
    
    init(
        binaryPath: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        outputHandler: @escaping (String) -> Void = { _ in },
        terminationHandler: @escaping () -> Void = {}
    ) {
        self.binaryPath = binaryPath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.outputHandler = outputHandler
        self.terminationHandler = terminationHandler
    }
}

/// Unified process execution service
actor ProcessExecutor {
    private var activeTask: Task<Void, Never>?
    private var terminationCallback: (() -> Void)?
    private var hasTerminated = false
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "locol", category: "ProcessExecutor")
    
    var isRunning: Bool {
        activeTask?.isCancelled == false && !hasTerminated
    }
    
    /// Start a process with the given configuration
    func start(config: ProcessExecutionConfig) async throws {
        // Stop any existing process first
        if activeTask != nil {
            await stop()
        }
        
        // Reset state
        hasTerminated = false
        terminationCallback = config.terminationHandler
        
        // Validate binary path
        guard FileManager.default.fileExists(atPath: config.binaryPath) else {
            throw ProcessExecutionError.binaryNotFound(config.binaryPath)
        }
        
        logger.info("Starting process: \(config.binaryPath) \(config.arguments.joined(separator: " "))")
        
        // Start process using Subprocess
        activeTask = Task {
            do {
                // Build environment
                var processEnvironment = Environment.inherit
                for (key, value) in config.environment {
                    processEnvironment = processEnvironment.updating([key: value])
                }
                
                // Determine working directory
                let workingDir: FilePath?
                if let workingDirectory = config.workingDirectory {
                    workingDir = FilePath(workingDirectory)
                } else {
                    workingDir = nil
                }
                
                let result = try await run(
                    .path(FilePath(config.binaryPath)),
                    arguments: Arguments(config.arguments),
                    environment: processEnvironment,
                    workingDirectory: workingDir,
                    error: .discarded
                ) { execution, standardOutput in
                    // Process stdout lines
                    for try await line in standardOutput.lines(encoding: UTF8.self) {
                        await MainActor.run {
                            config.outputHandler(line)
                        }
                    }
                }
                
                // Handle successful termination
                await self.handleTermination(exitCode: extractExitCode(from: result))
                
            } catch {
                self.logger.error("Process execution failed: \(error)")
                await self.handleTermination(exitCode: -1)
            }
        }
    }
    
    /// Stop the running process
    func stop() async {
        if let task = activeTask {
            logger.info("Stopping process...")
            task.cancel()
            activeTask = nil
            await callTerminationCallback()
        }
    }
    
    /// Execute a command and return its output (for short-lived commands)
    func execute(config: ProcessExecutionConfig) async throws -> String {
        logger.info("Executing command: \(config.binaryPath) \(config.arguments.joined(separator: " "))")
        
        // Build environment
        var processEnvironment = Environment.inherit
        for (key, value) in config.environment {
            processEnvironment = processEnvironment.updating([key: value])
        }
        
        // Determine working directory
        let workingDir: FilePath?
        if let workingDirectory = config.workingDirectory {
            workingDir = FilePath(workingDirectory)
        } else {
            workingDir = nil
        }
        
        let result = try await run(
            .path(FilePath(config.binaryPath)),
            arguments: Arguments(config.arguments),
            environment: processEnvironment,
            workingDirectory: workingDir,
            output: .string(limit: 1024*1024)
        )
        
        return result.standardOutput ?? ""
    }
    
    private func handleTermination(exitCode: Int32) async {
        logger.info("Process terminated with exit code: \(exitCode)")
        activeTask = nil
        await callTerminationCallback()
    }
    
    private func callTerminationCallback() async {
        if !hasTerminated {
            hasTerminated = true
            
            // Call termination callback on main actor
            if let callback = terminationCallback {
                await MainActor.run {
                    callback()
                }
            }
        }
    }
    
    private func extractExitCode(from result: ExecutionResult<()>) -> Int32 {
        switch result.terminationStatus {
        case .exited(let code):
            return code
        default:
            return -1
        }
    }
}

/// Errors that can occur during process execution
enum ProcessExecutionError: LocalizedError, Equatable {
    case binaryNotFound(String)
    case executionFailed(String)
    case notRunning
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path):
            return "Binary not found at path: \(path)"
        case .executionFailed(let reason):
            return "Process execution failed: \(reason)"
        case .notRunning:
            return "No process is currently running"
        }
    }
}