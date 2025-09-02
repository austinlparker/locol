import Foundation
import os
import Observation

struct DataGeneratorConfig: Codable, Identifiable {
    var id = UUID()
    var name: String = "Default Configuration"
    var endpoint: String = "127.0.0.1:14317"
    var insecure: Bool = true
    var duration: Int = 0 // 0 means run indefinitely
    var rate: Int = 5
    var transportProtocol: ProtocolType = .grpc
    var serviceName: String = "otelgen"
    var logLevel: LogLevel = .info
    var headers: [String: String] = [:]
    var dataType: DataType = .traces
    
    // Specific configurations for each data type
    var tracesConfig = TracesConfig()
    var metricsConfig = MetricsConfig()
    var logsConfig = LogsConfig()
    
    enum DataType: String, Codable, CaseIterable {
        case traces, metrics, logs
    }
    
    enum ProtocolType: String, Codable, CaseIterable {
        case grpc, http
    }
    
    enum LogLevel: String, Codable, CaseIterable {
        case debug, info, warn, error
    }
    
    // Helper to generate command line arguments
    func toArguments() -> [String] {
        var args = [String]()
        
        // Base arguments
        args.append(contentsOf: ["--otel-exporter-otlp-endpoint", endpoint])
        if insecure { args.append("--insecure") }
        if duration > 0 { args.append(contentsOf: ["--duration", String(duration)]) }
        args.append(contentsOf: [
            "--rate", String(rate),
            "--protocol", transportProtocol.rawValue,
            "--service-name", serviceName,
            "--log-level", logLevel.rawValue
        ])
        
        // Headers
        for (key, value) in headers {
            args.append(contentsOf: ["--header", "\(key)=\(value)"])
        }
        
        // Data type specific arguments
        args.append(dataType.rawValue)
        
        switch dataType {
        case .traces:
            args.append(contentsOf: tracesConfig.toArguments())
        case .metrics:
            args.append(contentsOf: metricsConfig.toArguments())
        case .logs:
            args.append(contentsOf: logsConfig.toArguments())
        }
        
        return args
    }
}

// Traces Configuration
struct TracesConfig: Codable {
    var mode: TraceMode = .single
    var singleConfig = SingleTraceConfig()
    var multiConfig = MultiTraceConfig()
    
    enum TraceMode: String, Codable, CaseIterable {
        case single, multi
    }
    
    func toArguments() -> [String] {
        var args = [String]()
        args.append(mode.rawValue)
        
        switch mode {
        case .single:
            args.append(contentsOf: singleConfig.toArguments())
        case .multi:
            args.append(contentsOf: multiConfig.toArguments())
        }
        
        return args
    }
}

struct SingleTraceConfig: Codable {
    var marshal: Bool = false
    var scenario: SingleTraceScenario = .basic
    
    enum SingleTraceScenario: String, Codable, CaseIterable {
        case basic, eventing, microservices, web_mobile
    }
    
    func toArguments() -> [String] {
        var args = [String]()
        if marshal { args.append("--marshal") }
        args.append(contentsOf: ["--scenario", scenario.rawValue])
        return args
    }
}

struct MultiTraceConfig: Codable {
    var scenarios: [MultiTraceScenario] = [.basic]
    var numberTraces: Int = 3
    var workers: Int = 1
    
    enum MultiTraceScenario: String, Codable, CaseIterable {
        case basic, web_request, mobile_request, event_driven
        case pub_sub, microservices, database_operation
    }
    
    func toArguments() -> [String] {
        var args = [String]()
        scenarios.forEach { args.append(contentsOf: ["--scenarios", $0.rawValue]) }
        args.append(contentsOf: [
            "--number-traces", String(numberTraces),
            "--workers", String(workers)
        ])
        return args
    }
}

// Metrics Configuration
struct MetricsConfig: Codable {
    var type: MetricType = .gauge
    var exponentialHistogramConfig = ExponentialHistogramConfig()
    var gaugeConfig = GaugeConfig()
    var histogramConfig = HistogramConfig()
    var sumConfig = SumConfig()
    
    enum MetricType: String, Codable, CaseIterable {
        case exponentialHistogram = "exponential-histogram"
        case gauge
        case histogram
        case sum
    }
    
    func toArguments() -> [String] {
        var args = [String]()
        args.append(type.rawValue)
        
        switch type {
        case .exponentialHistogram:
            args.append(contentsOf: exponentialHistogramConfig.toArguments())
        case .gauge:
            args.append(contentsOf: gaugeConfig.toArguments())
        case .histogram:
            args.append(contentsOf: histogramConfig.toArguments())
        case .sum:
            args.append(contentsOf: sumConfig.toArguments())
        }
        
        return args
    }
}

struct ExponentialHistogramConfig: Codable {
    var temporality: Temporality = .cumulative
    var unit: String = "ms"
    var attributes: [String: String] = [:]
    var scale: Int = 0
    var maxSize: Int = 1000
    var recordMinMax: Bool = true
    var zeroThreshold: Double = 0.000001
    
    func toArguments() -> [String] {
        var args = [String]()
        args.append(contentsOf: ["--temporality", temporality.rawValue])
        args.append(contentsOf: ["--unit", unit])
        attributes.forEach { args.append(contentsOf: ["--attribute", "\($0)=\($1)"]) }
        args.append(contentsOf: [
            "--scale", String(scale),
            "--max-size", String(maxSize)
        ])
        if recordMinMax { args.append("--record-minmax") }
        args.append(contentsOf: ["--zero-threshold", String(zeroThreshold)])
        return args
    }
}

struct GaugeConfig: Codable {
    var temporality: Temporality = .cumulative
    var unit: String = "1"
    var attributes: [String: String] = [:]
    var min: Int = 0
    var max: Int = 100
    
    func toArguments() -> [String] {
        var args = [String]()
        args.append(contentsOf: ["--temporality", temporality.rawValue])
        args.append(contentsOf: ["--unit", unit])
        attributes.forEach { args.append(contentsOf: ["--attribute", "\($0)=\($1)"]) }
        args.append(contentsOf: [
            "--min", String(min),
            "--max", String(max)
        ])
        return args
    }
}

struct HistogramConfig: Codable {
    var temporality: Temporality = .cumulative
    var unit: String = "ms"
    var attributes: [String: String] = [:]
    var bounds: [Int] = [1, 5, 10, 25, 50, 100, 250, 500, 1000]
    var recordMinMax: Bool = true
    
    func toArguments() -> [String] {
        var args = [String]()
        args.append(contentsOf: ["--temporality", temporality.rawValue])
        args.append(contentsOf: ["--unit", unit])
        attributes.forEach { args.append(contentsOf: ["--attribute", "\($0)=\($1)"]) }
        bounds.forEach { args.append(contentsOf: ["--bounds", String($0)]) }
        if recordMinMax { args.append("--record-minmax") }
        return args
    }
}

struct SumConfig: Codable {
    var temporality: Temporality = .cumulative
    var unit: String = "1"
    var attributes: [String: String] = [:]
    var monotonic: Bool = true
    
    func toArguments() -> [String] {
        var args = [String]()
        args.append(contentsOf: ["--temporality", temporality.rawValue])
        args.append(contentsOf: ["--unit", unit])
        attributes.forEach { args.append(contentsOf: ["--attribute", "\($0)=\($1)"]) }
        if monotonic { args.append("--monotonic") }
        return args
    }
}

enum Temporality: String, Codable, CaseIterable {
    case delta, cumulative
}

// Logs Configuration
struct LogsConfig: Codable {
    var mode: LogMode = .single
    var multiConfig = MultiLogConfig()
    
    enum LogMode: String, Codable, CaseIterable {
        case single, multi
    }
    
    func toArguments() -> [String] {
        var args = [String]()
        args.append(mode.rawValue)
        
        if case .multi = mode {
            args.append(contentsOf: multiConfig.toArguments())
        }
        
        return args
    }
}

struct MultiLogConfig: Codable {
    var number: Int = 0
    var workers: Int = 1
    var duration: Int = 0
    
    func toArguments() -> [String] {
        var args = [String]()
        if number > 0 { args.append(contentsOf: ["--number", String(number)]) }
        args.append(contentsOf: ["--workers", String(workers)])
        if duration > 0 { args.append(contentsOf: ["--duration", String(duration)]) }
        return args
    }
}

@Observable
class DataGeneratorManager {
    static let shared = DataGeneratorManager()
    
    var config: DataGeneratorConfig {
        didSet {
            saveConfig()
        }
    }
    var isRunning = false
    var downloadProgress: Double = 0
    var status: String = ""
    var isDownloading = false
    var needsDownload = false
    
    private var process: Process?
    private let fileManager = CollectorFileManager.shared
    private let configKey = "DataGeneratorConfig"
    private let githubAPI = "https://api.github.com/repos/krzko/otelgen/releases/latest"
    
    private var architecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "amd64"
        #endif
    }
    
    private let processManager = DataGeneratorProcess.shared
    private let logger = DataGeneratorLogger.shared
    
    init() {
        if let savedConfig = UserDefaults.standard.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(DataGeneratorConfig.self, from: savedConfig) {
            self.config = decoded
        } else {
            self.config = DataGeneratorConfig()
        }
        
        // Check if we need to download the binary
        if !FileManager.default.fileExists(atPath: fileManager.dataGeneratorPath.path) {
            needsDownload = true
        }
    }
    
    private func saveConfig() {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: configKey)
        }
    }
    
    func downloadGenerator() async throws {
        // Add cleanup before checking if binary exists
        if FileManager.default.fileExists(atPath: fileManager.dataGeneratorPath.path) {
            Logger.app.info("Removing existing binary before download")
            try? FileManager.default.removeItem(at: fileManager.dataGeneratorPath)
        }
        
        Logger.app.info("Starting data generator download")
        await MainActor.run {
            isDownloading = true
            status = "Fetching latest release..."
        }
        
        // Create URL request with GitHub API headers
        var request = URLRequest(url: URL(string: githubAPI)!)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        // Fetch latest release info
        let (data, _) = try await URLSession.shared.data(for: request)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        
        // Find the appropriate asset for macOS/architecture
        guard let asset = release.assets.first(where: { 
            $0.name.contains("darwin") && $0.name.contains(architecture)
        }) else {
            Logger.app.error("No compatible binary found for darwin/\(self.architecture)")
            throw DownloadError.noCompatibleBinary
        }
        
        Logger.app.info("Found compatible binary: \(asset.name)")
        
        await MainActor.run {
            status = "Downloading otelgen binary..."
        }
        
        // Download to a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(asset.name)
        
        // Download the binary
        let (binaryData, _) = try await URLSession.shared.data(from: URL(string: asset.browserDownloadUrl)!)
        try binaryData.write(to: tempFile)
        
        Logger.app.info("Downloaded archive to \(tempFile.path)")
        
        // Extract to a temporary directory
        let extractedPath = try fileManager.extractTarGz(at: tempFile)
        Logger.app.info("Extracted to \(extractedPath.path)")
        
        // List contents of extracted directory
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: extractedPath,
                includingPropertiesForKeys: nil
            )
            Logger.app.info("Extracted contents: \(contents)")
            
            // List contents of the subdirectory
            if let subdir = contents.first(where: { $0.lastPathComponent.contains("otelgen_darwin") }) {
                let subdirContents = try FileManager.default.contentsOfDirectory(
                    at: subdir,
                    includingPropertiesForKeys: nil
                )
                Logger.app.info("Subdirectory contents: \(subdirContents)")
            }
        } catch {
            Logger.app.error("Failed to list directory contents: \(error)")
        }
        
        // The binary is inside a subdirectory with the same name as the tar.gz (without extension)
        let archiveName = asset.name.replacingOccurrences(of: ".tar.gz", with: "")
        let binaryPath = extractedPath
            .appendingPathComponent(archiveName)
            .appendingPathComponent("otelgen")
            .path
        
        Logger.app.info("Looking for binary at \(binaryPath)")
        
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw DownloadError.extractedBinaryNotFound
        }
        
        // Ensure the destination directory exists
        let destinationDir = fileManager.dataGeneratorPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        
        // If the destination file exists, remove it first
        if FileManager.default.fileExists(atPath: fileManager.dataGeneratorPath.path) {
            try FileManager.default.removeItem(at: fileManager.dataGeneratorPath)
        }
        
        // Move the binary to its final location
        try FileManager.default.moveItem(
            atPath: binaryPath,
            toPath: fileManager.dataGeneratorPath.path
        )
        
        Logger.app.info("Moved binary to final location: \(self.fileManager.dataGeneratorPath.path)")
        
        // Ensure the binary is executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: fileManager.dataGeneratorPath.path
        )
        
        // Clean up temporary files
        try? FileManager.default.removeItem(at: tempFile)
        try? FileManager.default.removeItem(at: extractedPath)
        
        await MainActor.run {
            isDownloading = false
            status = "Download complete"
        }
    }
    
    func startGenerator() async {
        guard !isRunning else {
            Logger.app.warning("Attempted to start generator while already running")
            return
        }
        
        let binary = fileManager.dataGeneratorPath.path
        
        // Check if binary exists and is executable
        guard FileManager.default.fileExists(atPath: binary) else {
            Logger.app.error("Data generator binary not found at \(binary)")
            await MainActor.run {
                status = "Error: Data generator binary not found"
                needsDownload = true
            }
            return
        }
        
        let arguments = config.toArguments()
        
        Logger.app.info("Starting data generator with arguments: \(arguments)")
        
        await processManager.start(
            binary: binary,
            arguments: arguments,
            outputHandler: { [weak self] output in
                guard let self = self else { return }
                Task { @MainActor in
                    self.status = output
                    self.logger.info(output)
                }
            },
            onTermination: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    self.isRunning = false
                    self.status = "Generator stopped"
                    Logger.app.info("Data generator terminated")
                }
            }
        )
        
        await MainActor.run {
            isRunning = true
        }
        Logger.app.info("Data generator started successfully")
    }
    
    func stopGenerator() async {
        guard isRunning else {
            Logger.app.warning("Attempted to stop generator while not running")
            return
        }
        
        await processManager.stop()
        
        await MainActor.run {
            isRunning = false
            status = "Generator stopped"
        }
        Logger.app.info("Data generator stopped")
    }
    
    func cleanup() {
        // Don't stop the generator on cleanup anymore
        // This allows it to keep running when the window is closed
    }
    
    deinit {
        if isRunning {
            // We can't use async in deinit, so we'll detach a separate task
            // Avoid capturing self in the task to prevent Swift 6 errors
            let localProcessManager = processManager
            Task.detached {
                await localProcessManager.stop()
            }
        }
    }
    
    enum DownloadError: LocalizedError {
        case noCompatibleBinary
        case extractedBinaryNotFound
        
        var errorDescription: String? {
            switch self {
            case .noCompatibleBinary:
                return "No compatible binary found for your system"
            case .extractedBinaryNotFound:
                return "Could not find binary in extracted archive"
            }
        }
    }
} 
