import Foundation
import Yams
import Subprocess
import System
import os
import Observation

// Protocol that defines process management contract
@MainActor
protocol ProcessManagementService {
    var activeCollectorId: UUID? { get }
    func startCollector(_ collector: CollectorInstance) async throws
    func stopCollector() async throws
    func isRunning(_ collector: CollectorInstance) -> Bool
    func getCollectorComponents(_ collector: CollectorInstance) async throws -> ComponentList
}

@MainActor
@Observable
class ProcessManager: ProcessManagementService {
    
    private let fileManager: CollectorFileManager
    @ObservationIgnored private var activeProcess: Process?
    private var activeCollectorInfo: (id: UUID, name: String)? = nil
    /// Callback invoked when the active collector process terminates
    var onCollectorTerminated: ((UUID) -> Void)? = nil
    
    private let logger = Logger.collectors
    // STDERR capture
    @ObservationIgnored private var stderrPipe: Pipe?
    @ObservationIgnored private var stderrTask: Task<Void, Never>?
    @ObservationIgnored private var stderrRemainder: String = ""
    @ObservationIgnored private var stderrLines: [String] = []
    private let stderrMaxLines = 200
    
    var activeCollectorId: UUID? {
        return activeCollectorInfo?.id
    }
    
    init(fileManager: CollectorFileManager) {
        self.fileManager = fileManager
    }
    
    // MARK: - STDERR helpers
    private func appendStderr(_ chunk: String) {
        let combined = stderrRemainder + chunk
        var lines = combined.components(separatedBy: .newlines)
        if let last = lines.last, !combined.hasSuffix("\n") {
            stderrRemainder = last
            lines.removeLast()
        } else {
            stderrRemainder = ""
        }
        if !lines.isEmpty {
            stderrLines.append(contentsOf: lines)
            if stderrLines.count > stderrMaxLines {
                stderrLines.removeFirst(stderrLines.count - stderrMaxLines)
            }
        }
    }
    
    private func appendStderrLine(_ line: String) {
        guard !line.isEmpty else { return }
        stderrLines.append(line)
        if stderrLines.count > stderrMaxLines {
            stderrLines.removeFirst(stderrLines.count - stderrMaxLines)
        }
    }
    
    func getRecentStderr(maxLines: Int = 50) -> String {
        let count = min(maxLines, stderrLines.count)
        guard count > 0 else { return "" }
        return stderrLines.suffix(count).joined(separator: "\n")
    }
    
    func startCollector(_ collector: CollectorInstance) async throws {
        logger.debug("→ startCollector(collector: \(collector.name), version: \(collector.version))")
        
        // Stop any currently running collector
        if activeProcess != nil {
            logger.notice("Stopping currently running collector before starting \(collector.name)")
            try await stopCollector()
        }
        
        // Build arguments array
        var arguments = ["--config", collector.configPath]
        if !collector.commandLineFlags.isEmpty {
            arguments.append(contentsOf: collector.commandLineFlags.components(separatedBy: " "))
        }
        
        logger.debug("Starting collector with arguments: \(arguments)")
        
        // Get working directory from collector's config path
        let workingDirectory = URL(fileURLWithPath: collector.configPath).deletingLastPathComponent().path
        
        // Set environment variables to properly identify this collector
        let resourceAttributes = "service.name=\(collector.name),service.version=\(collector.version)"
        
        // Create and configure process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: collector.binaryPath)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        
        // Set environment
        var env = ProcessInfo.processInfo.environment
        env["OTEL_SERVICE_NAME"] = collector.name
        env["OTEL_RESOURCE_ATTRIBUTES"] = resourceAttributes
        process.environment = env
        
        // Capture STDERR for diagnostics
        let errPipe = Pipe()
        self.stderrPipe = errPipe
        self.stderrRemainder = ""
        self.stderrLines.removeAll(keepingCapacity: true)
        process.standardError = errPipe
        // Prefer async line streaming over readability handler
        stderrTask?.cancel()
        stderrTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await line in errPipe.fileHandleForReading.bytes.lines {
                    await MainActor.run { [weak self] in
                        self?.appendStderrLine(line)
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.logger.error("stderr stream error: \(error.localizedDescription)")
                }
            }
        }
        
        // Discard STDOUT
        process.standardOutput = nil
        
        do {
            // Observe termination to keep UI and store in sync
            process.terminationHandler = { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let id = self.activeCollectorInfo?.id
                    self.activeProcess = nil
                    self.activeCollectorInfo = nil
                    // Stop capturing
                    self.stderrTask?.cancel()
                    self.stderrTask = nil
                    self.stderrPipe = nil
                    if let id { self.onCollectorTerminated?(id) }
                    self.logger.notice("Collector \(collector.name) terminated with status: \(process.terminationStatus)")
                    let tail = self.getRecentStderr(maxLines: 10)
                    if !tail.isEmpty {
                        self.logger.error("stderr tail for \(collector.name):\n\(tail)")
                    }
                }
            }
            try process.run()
            activeProcess = process
            activeCollectorInfo = (id: collector.id, name: collector.name)
            
            logger.notice("Successfully started collector: \(collector.name)")
            logger.debug("← startCollector")
            
        } catch {
            logger.error("Failed to start collector: \(error.localizedDescription)")
            throw ProcessError.startupError(error.localizedDescription)
        }
    }
    
    func stopCollector() async throws {
        logger.debug("→ stopCollector")
        
        guard let process = activeProcess else {
            logger.debug("No collector running to stop")
            throw ProcessError.notRunning
        }
        
        let collectorName = activeCollectorInfo?.name ?? "unknown"
        logger.notice("Stopping collector: \(collectorName)")
        
        // Terminate the process
        process.terminate()
        
        // Wait for it to exit
        process.waitUntilExit()
        
        // Clear state
        activeProcess = nil
        activeCollectorInfo = nil
        
        if process.terminationStatus == 0 {
            logger.notice("Collector \(collectorName) stopped successfully")
        } else {
            logger.notice("Collector \(collectorName) stopped with status: \(process.terminationStatus)")
        }
        
        logger.debug("← stopCollector")
    }
    
    func isRunning(_ collector: CollectorInstance) -> Bool {
        let running = (activeProcess?.isRunning == true) && activeCollectorInfo?.id == collector.id
        // Remove excessive logging that causes infinite loop during UI updates
        // logger.debug("Collector \(collector.name) running status: \(running)")
        return running
    }
    
    func getCollectorComponents(_ collector: CollectorInstance) async throws -> ComponentList {
        logger.debug("→ getCollectorComponents(collector: \(collector.name))")
        
        let startTime = DispatchTime.now()
        
        do {
            let result = try await run(
                .path(FilePath(collector.binaryPath)), 
                arguments: Arguments(["components"]), 
                output: .string(limit: 1024*1024)
            )
            
            guard let output = result.standardOutput else {
                logger.error("No output received from collector components command")
                throw ProcessError.componentsFailed
            }
            
            logger.debug("Retrieved \(output.count) bytes of component data")
            
            let componentList = try YAMLDecoder().decode(ComponentList.self, from: output)
            
            let endTime = DispatchTime.now()
            let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
            
            logger.debug("← getCollectorComponents → Found \(componentList.receivers?.count ?? 0) receivers, \(componentList.processors?.count ?? 0) processors, \(componentList.exporters?.count ?? 0) exporters in \(String(format: "%.3f", duration))s")
            
            return componentList
            
        } catch {
            logger.error("Failed to get collector components: \(error.localizedDescription)")
            throw ProcessError.componentsFailed
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
